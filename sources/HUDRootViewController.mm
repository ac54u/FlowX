//
//  HUDRootViewController.mm
//  TrollSpeed - The Absolute Complete Edition (Compiler Fixed)
//
//  修复：iOS 14 色彩兼容性问题，补全 passthroughMode 穿透接口
//

#import <notify.h>
#import <net/if.h>
#import <ifaddrs.h>
#import <objc/runtime.h>
#import <mach/vm_param.h>
#import <Foundation/Foundation.h>

#import "HUDPresetPosition.h"
#import "HUDRootViewController.h"
#import "HUDBackdropLabel.h"
#import "TrollSpeed-Swift.h"

#ifdef __cplusplus
extern "C" {
#endif
CFIndex CARenderServerGetDirtyFrameCount(void *);
#ifdef __cplusplus
}
#endif

#import "FBSOrientationUpdate.h"
#import "FBSOrientationObserver.h"
#import "UIApplication+Private.h"
#import "LSApplicationProxy.h"
#import "LSApplicationWorkspace.h"
#import "SpringBoardServices.h"

#define NOTIFY_UI_LOCKSTATE    "com.apple.springboard.lockstate"
#define NOTIFY_LS_APP_CHANGED  "com.apple.LaunchServices.ApplicationsChanged"

// 持久化 Key
#define kDailyTrafficTotalBytes @"kDailyTrafficTotalBytes"
#define kDailyTrafficDate       @"kDailyTrafficDate"

static BOOL needsBaselineReset = YES;
static BOOL needsFPSBaselineReset = YES;

#pragma mark - 核心监控参数
#define KILOBYTES (1 << 10)
#define MEGABYTES (1 << 20)
#define GIGABYTES (1 << 30)
#define UPDATE_INTERVAL 1.0
#define IDLE_INTERVAL 3.0

static double HUD_FONT_SIZE = 9.0;
static UIFontWeight HUD_FONT_WEIGHT = UIFontWeightRegular;
static CGFloat HUD_INACTIVE_OPACITY = 0.667;
static uint8_t HUD_DATA_UNIT = 0;
static uint8_t HUD_SHOW_UPLOAD_SPEED = 1;
static uint8_t HUD_SHOW_DOWNLOAD_SPEED = 1;
static uint8_t HUD_SHOW_DOWNLOAD_SPEED_FIRST = 1;
static uint8_t HUD_SHOW_SECOND_SPEED_IN_NEW_LINE = 0;
static const char *HUD_UPLOAD_PREFIX = "▲";
static const char *HUD_DOWNLOAD_PREFIX = "▼";
static uint8_t HUD_DISPLAY_MODE = 0;
static BOOL HUD_USES_DUAL_COLOR = YES;

typedef struct { uint64_t inputBytes; uint64_t outputBytes; } UpDownBytes;

#pragma mark - 系统监听逻辑

static void LaunchServicesApplicationStateChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    BOOL isAppInstalled = NO;
    for (LSApplicationProxy *app in [[objc_getClass("LSApplicationWorkspace") defaultWorkspace] allApplications]) {
        if ([app.applicationIdentifier isEqualToString:@"ch.xxtou.hudapp"]) {
            isAppInstalled = YES; break;
        }
    }
    if (!isAppInstalled) { [UIApplication.sharedApplication terminateWithSuccess]; }
}

static void SpringBoardLockStatusChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    HUDRootViewController *rvc = (__bridge HUDRootViewController *)observer;
    mach_port_t sbsPort = SBSSpringBoardServerPort();
    if (sbsPort == MACH_PORT_NULL) return;
    BOOL isLocked, isPasscodeSet;
    SBGetScreenLockStatus(sbsPort, &isLocked, &isPasscodeSet);
    if (!isLocked) {
        needsBaselineReset = YES; needsFPSBaselineReset = YES;
        [rvc.view setHidden:NO]; [rvc resetLoopTimer];
    } else {
        [rvc stopLoopTimer]; [rvc.view setHidden:YES];
    }
}

#pragma mark - 网速渲染与抓取引擎

static NSString *formatTrafficUI(uint64_t bytes) {
    if (bytes < MEGABYTES) return [NSString stringWithFormat:@"%.1f KB", (double)bytes / KILOBYTES];
    if (bytes < GIGABYTES) return [NSString stringWithFormat:@"%.1f MB", (double)bytes / MEGABYTES];
    return [NSString stringWithFormat:@"%.2f GB", (double)bytes / GIGABYTES];
}

static NSString *formattedSpeedValue(uint64_t bytes, BOOL isFocused) {
    NSString *unit = (HUD_DATA_UNIT == 0) ? (isFocused ? @" KB" : @" KB/s") : (isFocused ? @" Kb" : @" Kb/s");
    double val = (HUD_DATA_UNIT == 0) ? (double)bytes / KILOBYTES : (double)bytes / 1000.0;
    if (bytes >= GIGABYTES) {
        unit = (HUD_DATA_UNIT == 0) ? (isFocused ? @" GB" : @" GB/s") : (isFocused ? @" Gb" : @" Gb/s");
        val = (HUD_DATA_UNIT == 0) ? (double)bytes / GIGABYTES : (double)bytes / 1000000000.0;
        return [NSString stringWithFormat:@"%.2f%@", val, unit];
    } else if (bytes >= MEGABYTES) {
        unit = (HUD_DATA_UNIT == 0) ? (isFocused ? @" MB" : @" MB/s") : (isFocused ? @" Mb" : @" Mb/s");
        val = (HUD_DATA_UNIT == 0) ? (double)bytes / MEGABYTES : (double)bytes / 1000000.0;
        return [NSString stringWithFormat:@"%.1f%@", val, unit];
    }
    return [NSString stringWithFormat:@"%.0f%@", val, unit];
}

static NSAttributedString *getFPSString() {
    static CFIndex lastFC = 0;
    CFIndex now = CARenderServerGetDirtyFrameCount(NULL);
    if (needsFPSBaselineReset) { lastFC = now; needsFPSBaselineReset = NO; return [[NSAttributedString alloc] initWithString:@"0 FPS"]; }
    CFIndex diff = (now >= lastFC) ? now - lastFC : 0;
    lastFC = now;
    return [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%.0f FPS", (double)diff] attributes:@{NSFontAttributeName:[UIFont monospacedDigitSystemFontOfSize:HUD_FONT_SIZE weight:HUD_FONT_WEIGHT], NSForegroundColorAttributeName:[UIColor whiteColor]}];
}

static UpDownBytes fetchNetBytes() {
    struct ifaddrs *ifa_list = 0, *ifa; UpDownBytes res = {0, 0};
    if (getifaddrs(&ifa_list) == -1) return res;
    for (ifa = ifa_list; ifa; ifa = ifa->ifa_next) {
        if (!ifa->ifa_name || !ifa->ifa_data || ifa->ifa_addr->sa_family != AF_LINK) continue;
        if (!(ifa->ifa_flags & IFF_UP) && !(ifa->ifa_flags & IFF_RUNNING)) continue;
        if (strncmp(ifa->ifa_name, "en", 2) && strncmp(ifa->ifa_name, "pdp_ip", 6)) continue;
        struct if_data *ifd = (struct if_data *)ifa->ifa_data;
        res.inputBytes += ifd->ifi_ibytes; res.outputBytes += ifd->ifi_obytes;
    }
    freeifaddrs(ifa_list); return res;
}

#pragma mark - HUDRootViewController Implementation

@implementation HUDRootViewController {
    NSMutableDictionary *_userDefaults;
    NSMutableArray <NSLayoutConstraint *> *_constraints;
    UIBlurEffect *_blurEffect;
    UIVisualEffectView *_blurView;
    ScreenshotInvisibleContainer *_containerView;
    UIView *_contentView;
    HUDBackdropLabel *_speedLabel;
    UIImageView *_lockedView;
    NSTimer *_timer;
    BOOL _isFocused;
    NSLayoutConstraint *_topConstraint;
    UIInterfaceOrientation _orientation;
    FBSOrientationObserver *_orientationObserver;
}

// 补全由于精简被误删的核心类方法，底层 Hook 需要用到它
+ (BOOL)passthroughMode {
    return [[[NSDictionary dictionaryWithContentsOfFile:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH))] objectForKey:HUDUserDefaultsKeyPassthroughMode] boolValue];
}

- (instancetype)init {
    if (self = [super init]) {
        _constraints = [NSMutableArray array];
        int tok;
        notify_register_dispatch(NOTIFY_RELOAD_HUD, &tok, dispatch_get_main_queue(), ^(int t) { [self reloadUserDefaults]; });
        
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)self, LaunchServicesApplicationStateChanged, CFSTR(NOTIFY_LS_APP_CHANGED), NULL, CFNotificationSuspensionBehaviorCoalesce);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)self, SpringBoardLockStatusChanged, CFSTR(NOTIFY_UI_LOCKSTATE), NULL, CFNotificationSuspensionBehaviorCoalesce);

        _orientationObserver = [[objc_getClass("FBSOrientationObserver") alloc] init];
        __weak typeof(self) w = self;
        [_orientationObserver setHandler:^(FBSOrientationUpdate *u) {
            dispatch_async(dispatch_get_main_queue(), ^{ [w updateOrientation:(UIInterfaceOrientation)u.orientation animateWithDuration:u.duration]; });
        }];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _contentView = [UIView new]; _contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_contentView];
    
    _blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    _blurView = [[UIVisualEffectView alloc] initWithEffect:_blurEffect];
    _blurView.layer.cornerRadius = 5; _blurView.layer.masksToBounds = YES;
    _blurView.translatesAutoresizingMaskIntoConstraints = NO;
    
    _containerView = [[ScreenshotInvisibleContainer alloc] initWithContent:_blurView];
    [_contentView addSubview:_containerView.hiddenContainer];
    
    _speedLabel = [HUDBackdropLabel new]; _speedLabel.numberOfLines = 0;
    _speedLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_blurView.contentView addSubview:_speedLabel];
    
    _lockedView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"lock.fill"]];
    _lockedView.translatesAutoresizingMaskIntoConstraints = NO; _lockedView.alpha = 0;
    [_blurView.contentView addSubview:_lockedView];
    
    [self reloadUserDefaults];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    notify_post(NOTIFY_LAUNCHED_HUD);
    [self resetLoopTimer];
}

- (void)reloadUserDefaults {
    [self loadUserDefaults:YES];
    HUD_SHOW_UPLOAD_SPEED = ![[_userDefaults objectForKey:HUDUserDefaultsKeySingleLineMode] boolValue];
    HUD_DATA_UNIT = [[_userDefaults objectForKey:HUDUserDefaultsKeyUsesBitrate] boolValue];
    BOOL arrows = [[_userDefaults objectForKey:HUDUserDefaultsKeyUsesArrowPrefixes] boolValue];
    HUD_UPLOAD_PREFIX = arrows ? "↑" : "▲"; HUD_DOWNLOAD_PREFIX = arrows ? "↓" : "▼";
    HUD_FONT_SIZE = [[_userDefaults objectForKey:HUDUserDefaultsKeyUsesLargeFont] boolValue] ? 10.0 : 9.0;
    
    BOOL invert = [[_userDefaults objectForKey:HUDUserDefaultsKeyUsesInvertedColor] boolValue];
    HUD_FONT_WEIGHT = invert ? UIFontWeightMedium : UIFontWeightRegular;
    HUD_INACTIVE_OPACITY = invert ? 1.0 : 0.667;
    [_blurView setEffect:invert ? nil : _blurEffect];
    [_speedLabel setColorInvertEnabled:invert];
    
    HUD_DISPLAY_MODE = [[_userDefaults objectForKey:HUDUserDefaultsKeyDisplayMode] boolValue];
    HUD_USES_DUAL_COLOR = [_userDefaults[@"HUD_USES_DUAL_COLOR"] boolValue] ?: YES;
    
    if ([[_userDefaults objectForKey:HUDUserDefaultsKeyHideAtSnapshot] boolValue]) [_containerView setupContainerAsHideContentInScreenshots];
    else [_containerView setupContainerAsDisplayContentInScreenshots];

    needsBaselineReset = YES; needsFPSBaselineReset = YES;
    [self updateViewConstraints];
}

- (void)updateSpeedLabel {
    @autoreleasepool {
        UpDownBytes now = fetchNetBytes(); static uint64_t lastIn = 0, lastOut = 0;
        if (needsBaselineReset) { lastIn = now.inputBytes; lastOut = now.outputBytes; needsBaselineReset = NO; return; }
        uint64_t outDiff = (now.outputBytes >= lastOut) ? now.outputBytes - lastOut : 0;
        uint64_t inDiff = (now.inputBytes >= lastIn) ? now.inputBytes - lastIn : 0;
        lastIn = now.inputBytes; lastOut = now.outputBytes;

        // 流量统计记录与分发
        [self trackTraffic:outDiff + inDiff];

        if (HUD_DISPLAY_MODE == 1) {
            [_speedLabel setAttributedText:getFPSString()];
        } else {
            UIColor *uCol = HUD_USES_DUAL_COLOR ? [UIColor systemOrangeColor] : [UIColor whiteColor];
            // 使用 systemTealColor 替代 systemCyanColor 以兼容 iOS 14
            UIColor *dCol = HUD_USES_DUAL_COLOR ? [UIColor systemTealColor] : [UIColor whiteColor];
            if (HUD_FONT_WEIGHT == UIFontWeightMedium) { uCol = [UIColor clearColor]; dCol = [UIColor clearColor]; }

            NSMutableAttributedString *ms = [NSMutableAttributedString new];
            NSAttributedString *sep = [[NSAttributedString alloc] initWithString:HUD_SHOW_SECOND_SPEED_IN_NEW_LINE ? @"\n" : @"  "];
            NSAttributedString *upS = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%s %@", HUD_UPLOAD_PREFIX, formattedSpeedValue(outDiff, _isFocused)] attributes:@{NSFontAttributeName:[UIFont monospacedDigitSystemFontOfSize:HUD_FONT_SIZE weight:HUD_FONT_WEIGHT], NSForegroundColorAttributeName:uCol}];
            NSAttributedString *dnS = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%s %@", HUD_DOWNLOAD_PREFIX, formattedSpeedValue(inDiff, _isFocused)] attributes:@{NSFontAttributeName:[UIFont monospacedDigitSystemFontOfSize:HUD_FONT_SIZE weight:HUD_FONT_WEIGHT], NSForegroundColorAttributeName:dCol}];

            if (HUD_SHOW_DOWNLOAD_SPEED_FIRST) {
                if (HUD_SHOW_DOWNLOAD_SPEED) [ms appendAttributedString:dnS];
                if (HUD_SHOW_UPLOAD_SPEED) { if (ms.length) [ms appendAttributedString:sep]; [ms appendAttributedString:upS]; }
            } else {
                if (HUD_SHOW_UPLOAD_SPEED) [ms appendAttributedString:upS];
                if (HUD_SHOW_DOWNLOAD_SPEED) { if (ms.length) [ms appendAttributedString:sep]; [ms appendAttributedString:dnS]; }
            }
            [_speedLabel setAttributedText:ms];
        }
        [_speedLabel sizeToFit];
    }
}

- (void)trackTraffic:(uint64_t)delta {
    [self loadUserDefaults:NO];
    NSString *today = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterNoStyle];
    uint64_t total = [[_userDefaults objectForKey:kDailyTrafficTotalBytes] unsignedLongLongValue];
    if (![today isEqualToString:[_userDefaults objectForKey:kDailyTrafficDate]]) { total = 0; [_userDefaults setObject:today forKey:kDailyTrafficDate]; }
    total += delta; [_userDefaults setObject:@(total) forKey:kDailyTrafficTotalBytes];
    
    // 向主 UI 发送流量数据
    dispatch_async(dispatch_get_main_queue(), ^{ [[NSNotificationCenter defaultCenter] postNotificationName:@"TrollSpeedUpdateTrafficUI" object:nil userInfo:@{@"total": formatTrafficUI(total)}]; });
}

- (void)updateViewConstraints {
    [NSLayoutConstraint deactivateConstraints:_constraints]; [_constraints removeAllObjects];
    HUDPresetPosition mode = [self selectedModeForCurrentOrientation]; BOOL isCentered = (mode == HUDPresetPositionTopCenter || mode == HUDPresetPositionTopCenterMost);
    
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    CGFloat offX = [defs doubleForKey:@"realCustomOffsetX"];
    CGFloat offY = [defs doubleForKey:@"realCustomOffsetY"];
    
    UILayoutGuide *lg = self.view.safeAreaLayoutGuide;
    [_constraints addObjectsFromArray:@[[_contentView.leadingAnchor constraintEqualToAnchor:lg.leadingAnchor constant:offX],[_contentView.trailingAnchor constraintEqualToAnchor:lg.trailingAnchor constant:offX]]];
    
    if (mode == HUDPresetPositionTopCenterMost) {
        [_constraints addObject:[_contentView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:offY]];
    } else {
        _topConstraint = [_contentView.topAnchor constraintEqualToAnchor:lg.topAnchor constant:20+offY]; _topConstraint.priority = 250; [_constraints addObject:_topConstraint];
    }
    
    if (isCentered) [_constraints addObject:[_speedLabel.centerXAnchor constraintEqualToAnchor:lg.centerXAnchor]];
    else if (mode == HUDPresetPositionTopLeft) [_constraints addObject:[_speedLabel.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:10]];
    else [_constraints addObject:[_speedLabel.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-10]];
    
    [_constraints addObjectsFromArray:@[
        [_speedLabel.topAnchor constraintEqualToAnchor:_contentView.topAnchor],
        [_speedLabel.bottomAnchor constraintEqualToAnchor:_contentView.bottomAnchor],
        [_blurView.topAnchor constraintEqualToAnchor:_speedLabel.topAnchor constant:-2],
        [_blurView.leadingAnchor constraintEqualToAnchor:_speedLabel.leadingAnchor constant:-4],
        [_blurView.trailingAnchor constraintEqualToAnchor:_speedLabel.trailingAnchor constant:4],
        [_blurView.bottomAnchor constraintEqualToAnchor:_speedLabel.bottomAnchor constant:2],
        [_lockedView.centerXAnchor constraintEqualToAnchor:_blurView.centerXAnchor],
        [_lockedView.centerYAnchor constraintEqualToAnchor:_blurView.centerYAnchor]
    ]];
    [NSLayoutConstraint activateConstraints:_constraints];
}

// 基础辅助方法
- (void)resetLoopTimer { [_timer invalidate]; _timer = [NSTimer scheduledTimerWithTimeInterval:UPDATE_INTERVAL target:self selector:@selector(updateSpeedLabel) userInfo:nil repeats:YES]; }
- (void)stopLoopTimer { [_timer invalidate]; _timer = nil; }
- (void)loadUserDefaults:(BOOL)f { if (f || !_userDefaults) _userDefaults = [[NSDictionary dictionaryWithContentsOfFile:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH))] mutableCopy] ?: [NSMutableDictionary dictionary]; }
- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures { return UIRectEdgeNone; }
- (BOOL)prefersStatusBarHidden { return NO; }
- (HUDPresetPosition)selectedModeForCurrentOrientation { [self loadUserDefaults:NO]; NSNumber *m = [_userDefaults objectForKey:[self selectedModeKeyForCurrentOrientation]]; return m ? (HUDPresetPosition)[m integerValue] : HUDPresetPositionTopCenter; }
- (HUDUserDefaultsKey)selectedModeKeyForCurrentOrientation { UIInterfaceOrientation o = self.view.window.windowScene.interfaceOrientation; return UIInterfaceOrientationIsLandscape(o) ? HUDUserDefaultsKeySelectedModeLandscape : HUDUserDefaultsKeySelectedMode; }
- (void)updateOrientation:(UIInterfaceOrientation)o animateWithDuration:(NSTimeInterval)d { [self updateViewConstraints]; }
@end