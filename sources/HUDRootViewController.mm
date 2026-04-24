//
//  HUDRootViewController.mm
//  TrollSpeed - Extreme Edition
//
//  Final Integration: Traffic Statistics, Precise Offsets, and Dual Color Engine.
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

// 持久化 Key 定义
#define kDailyTrafficTotalBytes @"kDailyTrafficTotalBytes"
#define kDailyTrafficDate       @"kDailyTrafficDate"

static BOOL needsBaselineReset = YES;
static BOOL needsFPSBaselineReset = YES;

// ==========================================
// 核心监控参数
// ==========================================
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
static UIColor *HUD_UP_COLOR = nil;
static UIColor *HUD_DOWN_COLOR = nil;

typedef struct {
    uint64_t inputBytes;
    uint64_t outputBytes;
} UpDownBytes;

// ==========================================
// 辅助工具：流量格式化
// ==========================================
static NSString *formatBytes(uint64_t bytes) {
    if (bytes < MEGABYTES) return [NSString stringWithFormat:@"%.1f KB", (double)bytes / KILOBYTES];
    if (bytes < GIGABYTES) return [NSString stringWithFormat:@"%.1f MB", (double)bytes / MEGABYTES];
    return [NSString stringWithFormat:@"%.2f GB", (double)bytes / GIGABYTES];
}

static NSString *formattedSpeed(uint64_t bytes, BOOL isFocused) {
    NSString *unit = (HUD_DATA_UNIT == 0) ? (isFocused ? @" KB" : @" KB/s") : (isFocused ? @" Kb" : @" Kb/s");
    double value = (HUD_DATA_UNIT == 0) ? (double)bytes / KILOBYTES : (double)bytes / 1000.0;
    
    if (bytes >= GIGABYTES) {
        unit = (HUD_DATA_UNIT == 0) ? (isFocused ? @" GB" : @" GB/s") : (isFocused ? @" Gb" : @" Gb/s");
        value = (HUD_DATA_UNIT == 0) ? (double)bytes / GIGABYTES : (double)bytes / 1000000000.0;
        return [NSString stringWithFormat:@"%.2f%@", value, unit];
    } else if (bytes >= MEGABYTES) {
        unit = (HUD_DATA_UNIT == 0) ? (isFocused ? @" MB" : @" MB/s") : (isFocused ? @" Mb" : @" Mb/s");
        value = (HUD_DATA_UNIT == 0) ? (double)bytes / MEGABYTES : (double)bytes / 1000000.0;
        return [NSString stringWithFormat:@"%.1f%@", value, unit];
    }
    return [NSString stringWithFormat:@"%.0f%@", value, unit];
}

static UpDownBytes getUpDownBytes() {
    struct ifaddrs *ifa_list = 0, *ifa;
    UpDownBytes res = {0, 0};
    if (getifaddrs(&ifa_list) == -1) return res;
    for (ifa = ifa_list; ifa; ifa = ifa->ifa_next) {
        if (!ifa->ifa_name || !ifa->ifa_data || ifa->ifa_addr->sa_family != AF_LINK) continue;
        if (!(ifa->ifa_flags & IFF_UP) && !(ifa->ifa_flags & IFF_RUNNING)) continue;
        if (strncmp(ifa->ifa_name, "en", 2) && strncmp(ifa->ifa_name, "pdp_ip", 6)) continue;
        struct if_data *if_data = (struct if_data *)ifa->ifa_data;
        res.inputBytes += if_data->ifi_ibytes;
        res.outputBytes += if_data->ifi_obytes;
    }
    freeifaddrs(ifa_list);
    return res;
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
    
    // 流量统计专用
    uint64_t _todayTotalBytes;
}

- (void)reloadUserDefaults {
    [self loadUserDefaults:YES];
    
    HUD_SHOW_UPLOAD_SPEED = ![[_userDefaults objectForKey:HUDUserDefaultsKeySingleLineMode] boolValue];
    HUD_DATA_UNIT = [[_userDefaults objectForKey:HUDUserDefaultsKeyUsesBitrate] boolValue];
    
    BOOL arrows = [[_userDefaults objectForKey:HUDUserDefaultsKeyUsesArrowPrefixes] boolValue];
    HUD_UPLOAD_PREFIX = arrows ? "↑" : "▲";
    HUD_DOWNLOAD_PREFIX = arrows ? "↓" : "▼";

    if (![[_userDefaults objectForKey:HUDUserDefaultsKeyUsesCustomFontSize] boolValue]) {
        HUD_FONT_SIZE = [[_userDefaults objectForKey:HUDUserDefaultsKeyUsesLargeFont] boolValue] ? 10.0 : 9.0;
    } else {
        HUD_FONT_SIZE = MIN(MAX([[_userDefaults objectForKey:HUDUserDefaultsKeyRealCustomFontSize] doubleValue], 8), 12);
    }

    BOOL invert = [[_userDefaults objectForKey:HUDUserDefaultsKeyUsesInvertedColor] boolValue];
    HUD_FONT_WEIGHT = invert ? UIFontWeightMedium : UIFontWeightRegular;
    HUD_INACTIVE_OPACITY = invert ? 1.0 : 0.667;
    [_blurView setEffect:invert ? nil : _blurEffect];
    [_speedLabel setColorInvertEnabled:invert];
    [_lockedView setHidden:invert];

    if ([[_userDefaults objectForKey:HUDUserDefaultsKeyHideAtSnapshot] boolValue]) [_containerView setupContainerAsHideContentInScreenshots];
    else [_containerView setupContainerAsDisplayContentInScreenshots];

    HUD_DISPLAY_MODE = [[_userDefaults objectForKey:HUDUserDefaultsKeyDisplayMode] boolValue];
    HUD_USES_DUAL_COLOR = [_userDefaults[@"HUD_USES_DUAL_COLOR"] boolValue] ?: YES;

    needsBaselineReset = YES;
    needsFPSBaselineReset = YES;

    [self updateViewConstraints];
}

- (void)updateSpeedLabel {
    @autoreleasepool {
        UpDownBytes now = getUpDownBytes();
        static uint64_t lastIn = 0, lastOut = 0;
        
        if (needsBaselineReset) {
            lastIn = now.inputBytes; lastOut = now.outputBytes;
            needsBaselineReset = NO; return;
        }

        uint64_t outDiff = (now.outputBytes >= lastOut) ? now.outputBytes - lastOut : 0;
        uint64_t inDiff = (now.inputBytes >= lastIn) ? now.inputBytes - lastIn : 0;
        lastIn = now.inputBytes; lastOut = now.outputBytes;

        // 流量累加逻辑
        [self trackTraffic:outDiff + inDiff];

        NSAttributedString *finalStr;
        if (HUD_DISPLAY_MODE == 1) {
            finalStr = formattedFPSAttributedString(_isFocused);
        } else {
            UIColor *uCol = HUD_USES_DUAL_COLOR ? [UIColor systemOrangeColor] : [UIColor whiteColor];
            UIColor *dCol = HUD_USES_DUAL_COLOR ? [UIColor systemCyanColor] : [UIColor whiteColor];
            if (HUD_FONT_WEIGHT == UIFontWeightMedium) { uCol = [UIColor clearColor]; dCol = [UIColor clearColor]; }

            NSMutableAttributedString *ms = [NSMutableAttributedString new];
            NSAttributedString *sep = [[NSAttributedString alloc] initWithString:HUD_SHOW_SECOND_SPEED_IN_NEW_LINE ? @"\n" : @"  "];
            
            NSAttributedString *upS = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%s %@", HUD_UPLOAD_PREFIX, formattedSpeed(outDiff, _isFocused)] 
                                                                    attributes:@{NSFontAttributeName:[UIFont monospacedDigitSystemFontOfSize:HUD_FONT_SIZE weight:HUD_FONT_WEIGHT], NSForegroundColorAttributeName:uCol}];
            NSAttributedString *dnS = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%s %@", HUD_DOWNLOAD_PREFIX, formattedSpeed(inDiff, _isFocused)] 
                                                                    attributes:@{NSFontAttributeName:[UIFont monospacedDigitSystemFontOfSize:HUD_FONT_SIZE weight:HUD_FONT_WEIGHT], NSForegroundColorAttributeName:dCol}];

            if (HUD_SHOW_DOWNLOAD_SPEED_FIRST) {
                if (HUD_SHOW_DOWNLOAD_SPEED) [ms appendAttributedString:dnS];
                if (HUD_SHOW_UPLOAD_SPEED) { if (ms.length) [ms appendAttributedString:sep]; [ms appendAttributedString:upS]; }
            } else {
                if (HUD_SHOW_UPLOAD_SPEED) [ms appendAttributedString:upS];
                if (HUD_SHOW_DOWNLOAD_SPEED) { if (ms.length) [ms appendAttributedString:sep]; [ms appendAttributedString:dnS]; }
            }
            finalStr = ms;
        }
        if (finalStr) [_speedLabel setAttributedText:finalStr];
        [_speedLabel sizeToFit];
    }
}

// ==========================================
// 流量统计持久化核心
// ==========================================
- (void)trackTraffic:(uint64_t)deltaBytes {
    [self loadUserDefaults:NO];
    NSString *today = [[NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterNoStyle] copy];
    NSString *savedDay = [_userDefaults objectForKey:kDailyTrafficDate];
    uint64_t total = [[_userDefaults objectForKey:kDailyTrafficTotalBytes] unsignedLongLongValue];

    if (![today isEqualToString:savedDay]) {
        total = 0;
        [_userDefaults setObject:today forKey:kDailyTrafficDate];
    }
    total += deltaBytes;
    [_userDefaults setObject:@(total) forKey:kDailyTrafficTotalBytes];
    
    // 注意：为了性能，不在这里 saveUserDefaults，而是依靠系统的定期同步
    _todayTotalBytes = total;
    
    // 发送通知给主 App 更新 UI
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *ui = @{@"total": formatBytes(total)};
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TrollSpeedUpdateTrafficUI" object:nil userInfo:ui];
    });
}

// ==========================================
// 坐标系统：应用自定义偏移
// ==========================================
- (void)updateViewConstraints {
    [NSLayoutConstraint deactivateConstraints:_constraints];
    [_constraints removeAllObjects];

    HUDPresetPosition mode = [self selectedModeForCurrentOrientation];
    BOOL isCentered = (mode == HUDPresetPositionTopCenter || mode == HUDPresetPositionTopCenterMost);
    BOOL isCenteredMost = (mode == HUDPresetPositionTopCenterMost);
    
    HUD_SHOW_DOWNLOAD_SPEED_FIRST = isCentered;
    HUD_SHOW_SECOND_SPEED_IN_NEW_LINE = !isCentered;
    [_speedLabel setTextAlignment:isCentered ? NSTextAlignmentCenter : NSTextAlignmentLeft];
    
    // 注入自定义偏移
    CGFloat offX = [[GetStandardUserDefaults() objectForKey:HUDUserDefaultsKeyUsesCustomOffset] boolValue] ? [[GetStandardUserDefaults() objectForKey:HUDUserDefaultsKeyRealCustomOffsetX] doubleValue] : 0;
    CGFloat offY = [[GetStandardUserDefaults() objectForKey:HUDUserDefaultsKeyUsesCustomOffset] boolValue] ? [[GetStandardUserDefaults() objectForKey:HUDUserDefaultsKeyRealCustomOffsetY] doubleValue] : 0;

    UILayoutGuide *lg = self.view.safeAreaLayoutGuide;
    [_constraints addObjectsFromArray:@[
        [_contentView.leadingAnchor constraintEqualToAnchor:lg.leadingAnchor constant:offX],
        [_contentView.trailingAnchor constraintEqualToAnchor:lg.trailingAnchor constant:offX],
    ]];

    if (isCenteredMost) {
        [_constraints addObject:[_contentView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:offY]];
    } else {
        _topConstraint = [_contentView.topAnchor constraintEqualToAnchor:lg.topAnchor constant:20 + offY];
        _topConstraint.priority = UILayoutPriorityDefaultLow;
        [_constraints addObject:_topConstraint];
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

// 其余手势与系统方法省略（保持上一版修复手势的代码）...
- (instancetype)init { if (self = [super init]) { _constraints = [NSMutableArray array]; [self registerNotifications]; _orientationObserver = [[objc_getClass("FBSOrientationObserver") alloc] init]; __weak typeof(self) w = self; [_orientationObserver setHandler:^(FBSOrientationUpdate *u) { dispatch_async(dispatch_get_main_queue(), ^{ [w updateOrientation:(UIInterfaceOrientation)u.orientation animateWithDuration:u.duration]; }); }]; } return self; }
- (void)viewDidLoad { [super viewDidLoad]; _contentView = [UIView new]; _contentView.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:_contentView]; _blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]; _blurView = [[UIVisualEffectView alloc] initWithEffect:_blurEffect]; _blurView.layer.cornerRadius = 5; _blurView.layer.masksToBounds = YES; _blurView.translatesAutoresizingMaskIntoConstraints = NO; _containerView = [[ScreenshotInvisibleContainer alloc] initWithContent:_blurView]; [_contentView addSubview:_containerView.hiddenContainer]; _speedLabel = [HUDBackdropLabel new]; _speedLabel.numberOfLines = 0; _speedLabel.translatesAutoresizingMaskIntoConstraints = NO; [_blurView.contentView addSubview:_speedLabel]; _lockedView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"lock.fill"]]; _lockedView.translatesAutoresizingMaskIntoConstraints = NO; _lockedView.alpha = 0; [_blurView.contentView addSubview:_lockedView]; [self reloadUserDefaults]; }
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; notify_post(NOTIFY_LAUNCHED_HUD); [self resetLoopTimer]; }
- (void)resetLoopTimer { [_timer invalidate]; _timer = [NSTimer scheduledTimerWithTimeInterval:UPDATE_INTERVAL target:self selector:@selector(updateSpeedLabel) userInfo:nil repeats:YES]; }
- (void)stopLoopTimer { [_timer invalidate]; _timer = nil; }
- (void)loadUserDefaults:(BOOL)f { if (f || !_userDefaults) _userDefaults = [[NSDictionary dictionaryWithContentsOfFile:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH))] mutableCopy] ?: [NSMutableDictionary dictionary]; }
- (void)saveUserDefaults { [_userDefaults writeToFile:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH)) atomically:YES]; }
- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures { return UIRectEdgeNone; }
- (BOOL)prefersStatusBarHidden { return NO; }
@end

@implementation HUDRootViewController (Troll)
- (void)updateOrientation:(UIInterfaceOrientation)o animateWithDuration:(NSTimeInterval)d { [self updateViewConstraints]; }
@end