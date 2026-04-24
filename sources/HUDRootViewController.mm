//
//  HUDRootViewController.mm
//  TrollSpeed - Final Compiler-Safe Edition
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

static BOOL needsBaselineReset = YES;
static BOOL needsFPSBaselineReset = YES;

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

#define KILOBITS 1000
#define MEGABITS 1000000
#define GIGABITS 1000000000
#define KILOBYTES (1 << 10)
#define MEGABYTES (1 << 20)
#define GIGABYTES (1 << 30)
#define UPDATE_INTERVAL 1.0
#define SHOW_ALWAYS 1
#define INLINE_SEPARATOR "  "
#define IDLE_INTERVAL 3.0

static const double HUD_MIN_FONT_SIZE = 9.0;
static const double HUD_MAX_FONT_SIZE = 10.0;
static const double HUD_MIN_CORNER_RADIUS = 4.5;
static const double HUD_MAX_CORNER_RADIUS = 5.0;
static double HUD_FONT_SIZE = 8.0;
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

static NSString *formattedSpeed(uint64_t bytes, BOOL isFocused) {
    if (isFocused) {
        if (0 == HUD_DATA_UNIT) {
            if (bytes < KILOBYTES) { static NSString *_string = nil; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ _string = NSLocalizedString(@"0 KB", @"formattedSpeed"); }); return _string; }
            else if (bytes < MEGABYTES) { static NSString *_string = nil; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ _string = NSLocalizedString(@"%.0f KB", @"formattedSpeed"); }); return [NSString stringWithFormat:_string, (double)bytes / KILOBYTES]; }
            else if (bytes < GIGABYTES) { static NSString *_string = nil; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ _string = NSLocalizedString(@"%.2f MB", @"formattedSpeed"); }); return [NSString stringWithFormat:_string, (double)bytes / MEGABYTES]; }
            else { static NSString *_string = nil; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ _string = NSLocalizedString(@"%.2f GB", @"formattedSpeed"); }); return [NSString stringWithFormat:_string, (double)bytes / GIGABYTES]; }
        } else {
            if (bytes < KILOBITS) { static NSString *_string = nil; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ _string = NSLocalizedString(@"0 Kb", @"formattedSpeed"); }); return _string; }
            else if (bytes < MEGABITS) { static NSString *_string = nil; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ _string = NSLocalizedString(@"%.0f Kb", @"formattedSpeed"); }); return [NSString stringWithFormat:_string, (double)bytes / KILOBITS]; }
            else if (bytes < GIGABITS) { static NSString *_string = nil; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ _string = NSLocalizedString(@"%.2f Mb", @"formattedSpeed"); }); return [NSString stringWithFormat:_string, (double)bytes / MEGABITS]; }
            else { static NSString *_string = nil; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ _string = NSLocalizedString(@"%.2f Gb", @"formattedSpeed"); }); return [NSString stringWithFormat:_string, (double)bytes / GIGABITS]; }
        }
    } else {
        if (0 == HUD_DATA_UNIT) {
            if (bytes < KILOBYTES) { static NSString *_string = nil; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ _string = NSLocalizedString(@"0 KB/s", @"formattedSpeed"); }); return _string; }
            else if (bytes < MEGABYTES) { static NSString *_string = nil; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ _string = NSLocalizedString(@"%.0f KB/s", @"formattedSpeed"); }); return [NSString stringWithFormat:_string, (double)bytes / KILOBYTES]; }
            else if (bytes < GIGABYTES) { static NSString *_string = nil; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ _string = NSLocalizedString(@"%.2f MB/s", @"formattedSpeed"); }); return [NSString stringWithFormat:_string, (double)bytes / MEGABYTES]; }
            else { static NSString *_string = nil; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ _string = NSLocalizedString(@"%.2f GB/s", @"formattedSpeed"); }); return [NSString stringWithFormat:_string, (double)bytes / GIGABYTES]; }
        } else {
            if (bytes < KILOBITS) { static NSString *_string = nil; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ _string = NSLocalizedString(@"0 Kb/s", @"formattedSpeed"); }); return _string; }
            else if (bytes < MEGABITS) { static NSString *_string = nil; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ _string = NSLocalizedString(@"%.0f Kb/s", @"formattedSpeed"); }); return [NSString stringWithFormat:_string, (double)bytes / KILOBITS]; }
            else if (bytes < GIGABITS) { static NSString *_string = nil; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ _string = NSLocalizedString(@"%.2f Mb/s", @"formattedSpeed"); }); return [NSString stringWithFormat:_string, (double)bytes / MEGABITS]; }
            else { static NSString *_string = nil; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ _string = NSLocalizedString(@"%.2f Gb/s", @"formattedSpeed"); }); return [NSString stringWithFormat:_string, (double)bytes / GIGABITS]; }
        }
    }
}

static UpDownBytes getUpDownBytes() {
    struct ifaddrs *ifa_list = 0, *ifa; UpDownBytes upDownBytes; upDownBytes.inputBytes = 0; upDownBytes.outputBytes = 0;
    if (getifaddrs(&ifa_list) == -1) return upDownBytes;
    for (ifa = ifa_list; ifa; ifa = ifa->ifa_next) {
        if (ifa->ifa_name == NULL || ifa->ifa_addr == NULL || ifa->ifa_data == NULL) continue;
        if (AF_LINK != ifa->ifa_addr->sa_family) continue;
        if (!(ifa->ifa_flags & IFF_UP) && !(ifa->ifa_flags & IFF_RUNNING)) continue;
        if (strncmp(ifa->ifa_name, "en", 2) && strncmp(ifa->ifa_name, "pdp_ip", 6)) continue;
        struct if_data *if_data = (struct if_data *)ifa->ifa_data;
        upDownBytes.inputBytes += if_data->ifi_ibytes; upDownBytes.outputBytes += if_data->ifi_obytes;
    }
    freeifaddrs(ifa_list); return upDownBytes;
}

static NSAttributedString *formattedFPSAttributedString(BOOL isFocused) {
    @autoreleasepool {
        static CFIndex prevDirtyFrameCount = 0;
        CFIndex dirtyFrameCount = CARenderServerGetDirtyFrameCount(NULL);
        if (needsFPSBaselineReset) { prevDirtyFrameCount = dirtyFrameCount; needsFPSBaselineReset = NO; return [[NSAttributedString alloc] initWithString:@"0 FPS" attributes:@{NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:HUD_FONT_SIZE weight:HUD_FONT_WEIGHT], NSForegroundColorAttributeName: [UIColor whiteColor]}]; }
        CFIndex frameDiff = dirtyFrameCount - prevDirtyFrameCount;
        prevDirtyFrameCount = dirtyFrameCount;
        if (frameDiff < 0) frameDiff = 0;
        double fps = (double)frameDiff / UPDATE_INTERVAL;
        double maxFPS = (double)[UIScreen mainScreen].maximumFramesPerSecond;
        if (fps > maxFPS) fps = maxFPS;
        NSString *fpsString = [NSString stringWithFormat:@"%.0f FPS", fps];
        return [[NSAttributedString alloc] initWithString:fpsString attributes:@{NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:HUD_FONT_SIZE weight:HUD_FONT_WEIGHT], NSForegroundColorAttributeName: [UIColor whiteColor]}];
    }
}

@interface HUDRootViewController (Troll)
- (void)updateOrientation:(UIInterfaceOrientation)orientation animateWithDuration:(NSTimeInterval)duration;
@end

static const CACornerMask kCornerMaskBottom = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
static const CACornerMask kCornerMaskAll = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;

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
    UITapGestureRecognizer *_tapGestureRecognizer;
    UIPanGestureRecognizer *_panGestureRecognizer;
    UIImpactFeedbackGenerator *_impactFeedbackGenerator;
    UINotificationFeedbackGenerator *_notificationFeedbackGenerator;
    BOOL _isFocused;
    NSLayoutConstraint *_topConstraint;
    NSLayoutConstraint *_centerXConstraint;
    NSLayoutConstraint *_leadingConstraint;
    NSLayoutConstraint *_trailingConstraint;
    NSLayoutConstraint *_contentLeadingConstraint;
    NSLayoutConstraint *_contentTrailingConstraint;
    NSLayoutConstraint *_centerTopConstraint;
    UIInterfaceOrientation _orientation;
    FBSOrientationObserver *_orientationObserver;
}

- (void)registerNotifications {
    int token;
    notify_register_dispatch(NOTIFY_RELOAD_HUD, &token, dispatch_get_main_queue(), ^(int token) { [self reloadUserDefaults]; });
    CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(darwinCenter, (__bridge const void *)self, LaunchServicesApplicationStateChanged, CFSTR(NOTIFY_LS_APP_CHANGED), NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(darwinCenter, (__bridge const void *)self, SpringBoardLockStatusChanged, CFSTR(NOTIFY_UI_LOCKSTATE), NULL, CFNotificationSuspensionBehaviorCoalesce);
    NSUserDefaults *userDefaults = GetStandardUserDefaults();
    [userDefaults addObserver:self forKeyPath:HUDUserDefaultsKeyUsesCustomFontSize options:NSKeyValueObservingOptionNew context:nil];
    [userDefaults addObserver:self forKeyPath:HUDUserDefaultsKeyRealCustomFontSize options:NSKeyValueObservingOptionNew context:nil];
    [userDefaults addObserver:self forKeyPath:HUDUserDefaultsKeyUsesCustomOffset options:NSKeyValueObservingOptionNew context:nil];
    [userDefaults addObserver:self forKeyPath:HUDUserDefaultsKeyRealCustomOffsetX options:NSKeyValueObservingOptionNew context:nil];
    [userDefaults addObserver:self forKeyPath:HUDUserDefaultsKeyRealCustomOffsetY options:NSKeyValueObservingOptionNew context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:HUDUserDefaultsKeyUsesCustomFontSize] || [keyPath isEqualToString:HUDUserDefaultsKeyRealCustomFontSize] || [keyPath isEqualToString:HUDUserDefaultsKeyUsesCustomOffset] || [keyPath isEqualToString:HUDUserDefaultsKeyRealCustomOffsetX] || [keyPath isEqualToString:HUDUserDefaultsKeyRealCustomOffsetY]) { [self reloadUserDefaults]; }
}

- (void)loadUserDefaults:(BOOL)forceReload {
    if (forceReload || !_userDefaults) _userDefaults = [[NSDictionary dictionaryWithContentsOfFile:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH))] mutableCopy] ?: [NSMutableDictionary dictionary];
}

- (void)saveUserDefaults {
    BOOL wroteSucceed = [_userDefaults writeToFile:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH)) atomically:YES];
    if (wroteSucceed) {
        [[NSFileManager defaultManager] setAttributes:@{ NSFileOwnerAccountID: @501, NSFileGroupOwnerAccountID: @501 } ofItemAtPath:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH)) error:nil];
        notify_post(NOTIFY_RELOAD_APP);
    }
}

- (void)reloadUserDefaults {
    [self loadUserDefaults:YES];
    BOOL singleLineMode = [self singleLineMode];
    HUD_SHOW_UPLOAD_SPEED = !singleLineMode;
    BOOL usesBitrate = [self usesBitrate];
    HUD_DATA_UNIT = usesBitrate;
    BOOL usesArrowPrefixes = [self usesArrowPrefixes];
    HUD_UPLOAD_PREFIX = (usesArrowPrefixes ? "↑" : "▲");
    HUD_DOWNLOAD_PREFIX = (usesArrowPrefixes ? "↓" : "▼");
    BOOL usesCustomFontSize = [self usesCustomFontSize];
    if (!usesCustomFontSize) {
        BOOL usesLargeFont = [self usesLargeFont];
        HUD_FONT_SIZE = (usesLargeFont ? HUD_MAX_FONT_SIZE : HUD_MIN_FONT_SIZE);
        [_blurView.layer setCornerRadius:(usesLargeFont ? HUD_MAX_CORNER_RADIUS : HUD_MIN_CORNER_RADIUS)];
    } else {
        CGFloat realCustomFontSize = MIN(MAX([self realCustomFontSize], 8), 12);
        HUD_FONT_SIZE = realCustomFontSize;
        [_blurView.layer setCornerRadius:realCustomFontSize / 2.0];
    }
    BOOL usesInvertedColor = [self usesInvertedColor];
    HUD_FONT_WEIGHT = (usesInvertedColor ? UIFontWeightMedium : UIFontWeightRegular);
    HUD_INACTIVE_OPACITY = (usesInvertedColor ? 1.0 : 0.667);
    [_blurView setEffect:(usesInvertedColor ? nil : _blurEffect)];
    [_speedLabel setColorInvertEnabled:usesInvertedColor];
    [_lockedView setHidden:usesInvertedColor];
    BOOL hideAtSnapshot = [self hideAtSnapshot];
    if (hideAtSnapshot) { [_containerView setupContainerAsHideContentInScreenshots]; } else { [_containerView setupContainerAsDisplayContentInScreenshots]; }
    BOOL displayMode = [self displayMode];
    HUD_DISPLAY_MODE = displayMode;
    HUD_USES_DUAL_COLOR = [_userDefaults[@"HUD_USES_DUAL_COLOR"] boolValue] ?: YES;
    needsBaselineReset = YES; needsFPSBaselineReset = YES;
    [self removeAllAnimations]; [self resetGestureRecognizers]; [self updateViewConstraints];
    if (!_isFocused) { [self onFocus:_contentView]; } else { [self keepFocus:_contentView]; }
    [self performSelector:@selector(onBlur:) withObject:_contentView afterDelay:IDLE_INTERVAL];
}

+ (BOOL)passthroughMode { return [[[NSDictionary dictionaryWithContentsOfFile:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH))] objectForKey:HUDUserDefaultsKeyPassthroughMode] boolValue]; }

- (BOOL)isLandscapeOrientation {
    BOOL isLandscape;
    if (_orientation == UIInterfaceOrientationUnknown) { isLandscape = CGRectGetWidth(self.view.bounds) > CGRectGetHeight(self.view.bounds); } else { isLandscape = UIInterfaceOrientationIsLandscape(_orientation); }
    return isLandscape;
}

- (HUDUserDefaultsKey)selectedModeKeyForCurrentOrientation { return [self isLandscapeOrientation] ? HUDUserDefaultsKeySelectedModeLandscape : HUDUserDefaultsKeySelectedMode; }
- (HUDPresetPosition)selectedModeForCurrentOrientation { [self loadUserDefaults:NO]; NSNumber *mode = [_userDefaults objectForKey:[self selectedModeKeyForCurrentOrientation]]; return mode != nil ? (HUDPresetPosition)[mode integerValue] : HUDPresetPositionTopCenter; }
- (BOOL)singleLineMode { [self loadUserDefaults:NO]; NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeySingleLineMode]; return mode != nil ? [mode boolValue] : NO; }
- (BOOL)displayMode { [self loadUserDefaults:NO]; NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyDisplayMode]; return mode != nil ? [mode boolValue] : NO; }
- (BOOL)usesBitrate { [self loadUserDefaults:NO]; NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesBitrate]; return mode != nil ? [mode boolValue] : NO; }
- (BOOL)usesArrowPrefixes { [self loadUserDefaults:NO]; NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesArrowPrefixes]; return mode != nil ? [mode boolValue] : NO; }
- (BOOL)usesLargeFont { [self loadUserDefaults:NO]; NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesLargeFont]; return mode != nil ? [mode boolValue] : NO; }
- (BOOL)usesRotation { [self loadUserDefaults:NO]; NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesRotation]; return mode != nil ? [mode boolValue] : NO; }
- (BOOL)usesInvertedColor { [self loadUserDefaults:NO]; NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesInvertedColor]; return mode != nil ? [mode boolValue] : NO; }
- (BOOL)keepInPlace { [self loadUserDefaults:NO]; NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyKeepInPlace]; return mode != nil ? [mode boolValue] : NO; }
- (BOOL)hideAtSnapshot { [self loadUserDefaults:NO]; NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyHideAtSnapshot]; return mode != nil ? [mode boolValue] : NO; }
- (CGFloat)currentPositionY { [self loadUserDefaults:NO]; NSNumber *positionY = [_userDefaults objectForKey:HUDUserDefaultsKeyCurrentPositionY]; return positionY != nil ? [positionY doubleValue] : CGFLOAT_MAX; }
- (void)setCurrentPositionY:(CGFloat)positionY { [self loadUserDefaults:NO]; [_userDefaults setObject:[NSNumber numberWithDouble:positionY] forKey:HUDUserDefaultsKeyCurrentPositionY]; [self saveUserDefaults]; }
- (CGFloat)currentLandscapePositionY { [self loadUserDefaults:NO]; NSNumber *positionY = [_userDefaults objectForKey:HUDUserDefaultsKeyCurrentLandscapePositionY]; return positionY != nil ? [positionY doubleValue] : CGFLOAT_MAX; }
- (void)setCurrentLandscapePositionY:(CGFloat)positionY { [self loadUserDefaults:NO]; [_userDefaults setObject:[NSNumber numberWithDouble:positionY] forKey:HUDUserDefaultsKeyCurrentLandscapePositionY]; [self saveUserDefaults]; }

#define PREFS_PATH "/var/mobile/Library/Preferences/ch.xxtou.hudapp.prefs.plist"
- (NSDictionary *)extraUserDefaultsDictionary {
    static BOOL isJailbroken = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ isJailbroken = [[NSFileManager defaultManager] fileExistsAtPath:JBROOT_PATH_NSSTRING(@"/Library/PreferenceBundles/TrollSpeedPrefs.bundle")]; });
    if (!isJailbroken) { return nil; } return [NSDictionary dictionaryWithContentsOfFile:JBROOT_PATH_NSSTRING(@PREFS_PATH)];
}
- (BOOL)usesCustomFontSize { NSDictionary *extraUserDefaults = [self extraUserDefaultsDictionary]; if (extraUserDefaults) { return [extraUserDefaults[HUDUserDefaultsKeyUsesCustomFontSize] boolValue]; } return [GetStandardUserDefaults() boolForKey:HUDUserDefaultsKeyUsesCustomFontSize]; }
- (CGFloat)realCustomFontSize { NSDictionary *extraUserDefaults = [self extraUserDefaultsDictionary]; if (extraUserDefaults) { return [extraUserDefaults[HUDUserDefaultsKeyRealCustomFontSize] doubleValue]; } return [GetStandardUserDefaults() doubleForKey:HUDUserDefaultsKeyRealCustomFontSize]; }
- (BOOL)usesCustomOffset { NSDictionary *extraUserDefaults = [self extraUserDefaultsDictionary]; if (extraUserDefaults) { return [extraUserDefaults[HUDUserDefaultsKeyUsesCustomOffset] boolValue]; } return [GetStandardUserDefaults() boolForKey:HUDUserDefaultsKeyUsesCustomOffset]; }
- (CGFloat)realCustomOffsetX { NSDictionary *extraUserDefaults = [self extraUserDefaultsDictionary]; if (extraUserDefaults) { return [extraUserDefaults[HUDUserDefaultsKeyRealCustomOffsetX] doubleValue]; } return [GetStandardUserDefaults() doubleForKey:HUDUserDefaultsKeyRealCustomOffsetX]; }
- (CGFloat)realCustomOffsetY { NSDictionary *extraUserDefaults = [self extraUserDefaultsDictionary]; if (extraUserDefaults) { return [extraUserDefaults[HUDUserDefaultsKeyRealCustomOffsetY] doubleValue]; } return [GetStandardUserDefaults() doubleForKey:HUDUserDefaultsKeyRealCustomOffsetY]; }

- (instancetype)init {
    self = [super init];
    if (self) {
        _constraints = [NSMutableArray array];
        [self registerNotifications];
        _orientationObserver = [[objc_getClass("FBSOrientationObserver") alloc] init];
        __weak HUDRootViewController *weakSelf = self;
        [_orientationObserver setHandler:^(FBSOrientationUpdate *orientationUpdate) {
            HUDRootViewController *strongSelf = weakSelf;
            dispatch_async(dispatch_get_main_queue(), ^{ [strongSelf updateOrientation:(UIInterfaceOrientation)orientationUpdate.orientation animateWithDuration:orientationUpdate.duration]; });
        }];
    }
    return self;
}
- (void)dealloc { [_orientationObserver invalidate]; }

- (void)trackTraffic:(uint64_t)deltaBytes {
    static uint64_t uncommittedBytes = 0;
    static int tick = 0;
    uncommittedBytes += deltaBytes;
    
    if (++tick >= 3) {
        [self loadUserDefaults:NO];
        NSString *today = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterNoStyle];
        uint64_t total = [[_userDefaults objectForKey:@"kDailyTrafficTotalBytes"] unsignedLongLongValue];
        if (![today isEqualToString:[_userDefaults objectForKey:@"kDailyTrafficDate"]]) {
            total = 0;
            [_userDefaults setObject:today forKey:@"kDailyTrafficDate"];
        }
        total += uncommittedBytes;
        uncommittedBytes = 0;
        [_userDefaults setObject:@(total) forKey:@"kDailyTrafficTotalBytes"];
        [_userDefaults writeToFile:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH)) atomically:YES];
        notify_post("ch.xxtou.hudapp.traffic_update");
        tick = 0;
    }
}

- (void)updateSpeedLabel {
    @autoreleasepool {
        static uint64_t prevOutputBytes = 0, prevInputBytes = 0;
        UpDownBytes upDownBytes = getUpDownBytes();
        uint64_t upDiff = 0, downDiff = 0;

        if (needsBaselineReset && !_isFocused) {
            prevOutputBytes = upDownBytes.outputBytes;
            prevInputBytes = upDownBytes.inputBytes;
            needsBaselineReset = NO;
            return;
        }

        if (_isFocused) {
            upDiff = upDownBytes.outputBytes;
            downDiff = upDownBytes.inputBytes;
        } else {
            if (upDownBytes.outputBytes > prevOutputBytes) upDiff = upDownBytes.outputBytes - prevOutputBytes;
            if (upDownBytes.inputBytes > prevInputBytes) downDiff = upDownBytes.inputBytes - prevInputBytes;
        }

        prevOutputBytes = upDownBytes.outputBytes;
        prevInputBytes = upDownBytes.inputBytes;

        [self trackTraffic:upDiff + downDiff];

        if (HUD_DISPLAY_MODE == 1) {
            [_speedLabel setAttributedText:formattedFPSAttributedString(_isFocused)];
        } else {
            UIColor *uCol = HUD_USES_DUAL_COLOR ? [UIColor systemOrangeColor] : [UIColor whiteColor];
            UIColor *dCol = HUD_USES_DUAL_COLOR ? [UIColor systemTealColor] : [UIColor whiteColor];
            if (HUD_FONT_WEIGHT == UIFontWeightMedium) { uCol = [UIColor clearColor]; dCol = [UIColor clearColor]; }

            NSMutableAttributedString *mutableString = [[NSMutableAttributedString alloc] init];
            NSAttributedString *attributedInlineSeparator = [[NSAttributedString alloc] initWithString:[NSString stringWithUTF8String:INLINE_SEPARATOR] attributes:@{ NSFontAttributeName: [UIFont boldSystemFontOfSize:HUD_FONT_SIZE] }];
            NSAttributedString *attributedLineSeparator = [[NSAttributedString alloc] initWithString:@"\n" attributes:@{ NSFontAttributeName: [UIFont boldSystemFontOfSize:HUD_FONT_SIZE] }];

            if (HUD_DATA_UNIT == 1) { upDiff *= 8; downDiff *= 8; }
            
            NSString *upStrRaw = [NSString stringWithFormat:@"%s %@", HUD_UPLOAD_PREFIX, formattedSpeed(upDiff, _isFocused)];
            NSString *dnStrRaw = [NSString stringWithFormat:@"%s %@", HUD_DOWNLOAD_PREFIX, formattedSpeed(downDiff, _isFocused)];
            NSAttributedString *upStr = [[NSAttributedString alloc] initWithString:upStrRaw attributes:@{NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:HUD_FONT_SIZE weight:HUD_FONT_WEIGHT], NSForegroundColorAttributeName: uCol}];
            NSAttributedString *dnStr = [[NSAttributedString alloc] initWithString:dnStrRaw attributes:@{NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:HUD_FONT_SIZE weight:HUD_FONT_WEIGHT], NSForegroundColorAttributeName: dCol}];

            if (HUD_SHOW_DOWNLOAD_SPEED_FIRST) {
                if (HUD_SHOW_DOWNLOAD_SPEED) [mutableString appendAttributedString:dnStr];
                if (HUD_SHOW_UPLOAD_SPEED) {
                    if ([mutableString length] > 0) {
                        if (HUD_SHOW_SECOND_SPEED_IN_NEW_LINE) [mutableString appendAttributedString:attributedLineSeparator];
                        else [mutableString appendAttributedString:attributedInlineSeparator];
                    }
                    [mutableString appendAttributedString:upStr];
                }
            } else {
                if (HUD_SHOW_UPLOAD_SPEED) [mutableString appendAttributedString:upStr];
                if (HUD_SHOW_DOWNLOAD_SPEED) {
                    if ([mutableString length] > 0) {
                        if (HUD_SHOW_SECOND_SPEED_IN_NEW_LINE) [mutableString appendAttributedString:attributedLineSeparator];
                        else [mutableString appendAttributedString:attributedInlineSeparator];
                    }
                    [mutableString appendAttributedString:dnStr];
                }
            }
            [_speedLabel setAttributedText:mutableString];
        }
        [_speedLabel sizeToFit];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _contentView = [[UIView alloc] init];
    _contentView.backgroundColor = [UIColor clearColor];
    _contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_contentView];

    _blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    _blurView = [[UIVisualEffectView alloc] initWithEffect:_blurEffect];
    _blurView.layer.cornerRadius = HUD_MIN_CORNER_RADIUS;
    _blurView.layer.masksToBounds = YES;
    _blurView.translatesAutoresizingMaskIntoConstraints = NO;
    
    _containerView = [[ScreenshotInvisibleContainer alloc] initWithContent:_blurView];
    _containerView.hiddenContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentView addSubview:_containerView.hiddenContainer];

    _speedLabel = [[HUDBackdropLabel alloc] initWithFrame:CGRectZero];
    _speedLabel.numberOfLines = 0;
    _speedLabel.textAlignment = NSTextAlignmentCenter;
    _speedLabel.textColor = [UIColor whiteColor];
    _speedLabel.font = [UIFont systemFontOfSize:HUD_FONT_SIZE];
    _speedLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_speedLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisVertical];
    [_blurView.contentView addSubview:_speedLabel];

    _lockedView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"lock.fill"]];
    _lockedView.tintColor = [UIColor whiteColor];
    _lockedView.translatesAutoresizingMaskIntoConstraints = NO;
    _lockedView.contentMode = UIViewContentModeScaleAspectFit;
    _lockedView.alpha = 0.0;
    [_lockedView setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
    [_lockedView setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
    [_blurView.contentView addSubview:_lockedView];

    _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureRecognized:)];
    _tapGestureRecognizer.numberOfTapsRequired = 1;
    _tapGestureRecognizer.numberOfTouchesRequired = 1;
    [_contentView addGestureRecognizer:_tapGestureRecognizer];

    _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognized:)];
    _panGestureRecognizer.minimumNumberOfTouches = 1;
    _panGestureRecognizer.maximumNumberOfTouches = 1;
    [_contentView addGestureRecognizer:_panGestureRecognizer];

    [_contentView setUserInteractionEnabled:YES];

    [self reloadUserDefaults];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    notify_post(NOTIFY_LAUNCHED_HUD);
    [self resetLoopTimer];
}

- (void)resetLoopTimer { [_timer invalidate]; _timer = [NSTimer scheduledTimerWithTimeInterval:UPDATE_INTERVAL target:self selector:@selector(updateSpeedLabel) userInfo:nil repeats:YES]; }
- (void)stopLoopTimer { [_timer invalidate]; _timer = nil; }
- (void)viewSafeAreaInsetsDidChange { [super viewSafeAreaInsetsDidChange]; [self removeAllAnimations]; [self resetGestureRecognizers]; [self updateViewConstraints]; }

- (void)updateViewConstraints {
    [NSLayoutConstraint deactivateConstraints:_constraints];
    [_constraints removeAllObjects];

    HUDPresetPosition selectedMode = [self selectedModeForCurrentOrientation];
    BOOL isCentered = (selectedMode == HUDPresetPositionTopCenter || selectedMode == HUDPresetPositionTopCenterMost);
    BOOL isCenteredMost = (selectedMode == HUDPresetPositionTopCenterMost);
    
    HUD_SHOW_DOWNLOAD_SPEED_FIRST = isCentered;
    HUD_SHOW_SECOND_SPEED_IN_NEW_LINE = !isCentered;
    [_speedLabel setTextAlignment:(isCentered ? NSTextAlignmentCenter : NSTextAlignmentLeft)];
    [_lockedView setImage:[UIImage systemImageNamed:(isCentered ? @"hand.raised.slash.fill" : @"lock.fill")]];

    CGFloat realCustomOffsetX = [self usesCustomOffset] ? [self realCustomOffsetX] : 0;
    CGFloat realCustomOffsetY = [self usesCustomOffset] ? [self realCustomOffsetY] : 0;

    UILayoutGuide *layoutGuide = self.view.safeAreaLayoutGuide;
    
    _contentLeadingConstraint = [_contentView.leadingAnchor constraintEqualToAnchor:layoutGuide.leadingAnchor constant:realCustomOffsetX];
    _contentTrailingConstraint = [_contentView.trailingAnchor constraintEqualToAnchor:layoutGuide.trailingAnchor constant:realCustomOffsetX];
    [_constraints addObjectsFromArray:@[_contentLeadingConstraint, _contentTrailingConstraint]];

    if (isCenteredMost) {
        _centerTopConstraint = [_contentView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:realCustomOffsetY];
        [_constraints addObject:_centerTopConstraint];
        _topConstraint = nil;
    } else {
        CGFloat minimumTopConstraintConstant = 20; 
        _topConstraint = [_contentView.topAnchor constraintEqualToAnchor:layoutGuide.topAnchor constant:minimumTopConstraintConstant + realCustomOffsetY];
        _topConstraint.priority = UILayoutPriorityDefaultLow;
        [_constraints addObject:_topConstraint];
        _centerTopConstraint = nil;
    }

    if (isCentered) {
        _centerXConstraint = [_speedLabel.centerXAnchor constraintEqualToAnchor:layoutGuide.centerXAnchor];
        [_constraints addObject:_centerXConstraint];
    }
    if (selectedMode == HUDPresetPositionTopLeft) {
        _leadingConstraint = [_speedLabel.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:10];
        [_constraints addObject:_leadingConstraint];
    }
    if (selectedMode == HUDPresetPositionTopRight) {
        _trailingConstraint = [_speedLabel.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-10];
        [_constraints addObject:_trailingConstraint];
    }

    [_constraints addObjectsFromArray:@[
        [_speedLabel.topAnchor constraintEqualToAnchor:_contentView.topAnchor],
        [_speedLabel.bottomAnchor constraintEqualToAnchor:_contentView.bottomAnchor],
        [_blurView.topAnchor constraintEqualToAnchor:_speedLabel.topAnchor constant:-2],
        [_blurView.leadingAnchor constraintEqualToAnchor:_speedLabel.leadingAnchor constant:-4],
        [_blurView.trailingAnchor constraintEqualToAnchor:_speedLabel.trailingAnchor constant:4],
        [_blurView.bottomAnchor constraintEqualToAnchor:_speedLabel.bottomAnchor constant:2],
        [_lockedView.topAnchor constraintGreaterThanOrEqualToAnchor:_blurView.topAnchor constant:2],
        [_lockedView.centerXAnchor constraintEqualToAnchor:_blurView.centerXAnchor],
        [_lockedView.centerYAnchor constraintEqualToAnchor:_blurView.centerYAnchor],
    ]];

    [NSLayoutConstraint activateConstraints:_constraints];
    [super updateViewConstraints];
}

- (void)keepFocus:(UIView *)view { [self onFocus:view duration:0]; }
- (void)onFocus:(UIView *)view { [self onFocus:view duration:0.2]; }
- (void)onFocus:(UIView *)view duration:(NSTimeInterval)duration { [self onFocus:view scaleFactor:0.1 duration:duration beginFromInitialState:YES blurWhenDone:YES]; }

- (void)onFocus:(UIView *)view scaleFactor:(CGFloat)scaleFactor duration:(NSTimeInterval)duration beginFromInitialState:(BOOL)beginFromInitialState blurWhenDone:(BOOL)blurWhenDone {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onBlur:) object:view];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onFocus:) object:view];

    _isFocused = YES;
    [self updateSpeedLabel];
    [self resetLoopTimer];

    if (beginFromInitialState)
        [view setTransform:CGAffineTransformIdentity];

    [UIView animateWithDuration:duration delay:0.0 usingSpringWithDamping:1.0 initialSpringVelocity:1.0 options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState animations:^{
        view.transform = CGAffineTransformMakeScale(1.0 + scaleFactor, 1.0 + scaleFactor);
        view.alpha = 1.0;
    } completion:^(BOOL finished) {
        if (blurWhenDone) {
            [self performSelector:@selector(onBlur:) withObject:view afterDelay:IDLE_INTERVAL];
        }
    }];
}

- (void)onBlur:(UIView *)view { [self onBlur:view duration:0.6]; }
- (void)onBlur:(UIView *)view duration:(NSTimeInterval)duration {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onBlur:) object:view];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onFocus:) object:view];

    _isFocused = NO;
    [self updateSpeedLabel];
    [self resetLoopTimer];

    [UIView animateWithDuration:duration delay:0.0 usingSpringWithDamping:1.0 initialSpringVelocity:1.0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        view.transform = CGAffineTransformIdentity;
        view.alpha = HUD_INACTIVE_OPACITY;
    } completion:nil];
}

- (void)removeAllAnimations { [_contentView.layer removeAllAnimations]; }
- (void)resetGestureRecognizers { for (UIGestureRecognizer *recognizer in _contentView.gestureRecognizers) { [recognizer setEnabled:NO]; [recognizer setEnabled:YES]; } }

- (void)tapGestureRecognized:(UITapGestureRecognizer *)sender {
    if (!_isFocused) {
        [self onFocus:sender.view];
    } else {
        [self keepFocus:sender.view];
    }
}

- (void)cancelPreviousPerformRequestsWithTarget:(UIView *)view {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onBlur:) object:view];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onFocus:) object:view];
}

- (void)flashLockedViewWithDuration:(NSTimeInterval)duration {
    [_lockedView.layer removeAllAnimations];
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    animation.fromValue = [NSNumber numberWithFloat:0.0];
    animation.toValue = [NSNumber numberWithFloat:1.0];
    animation.duration = duration;
    animation.autoreverses = YES;
    animation.repeatCount = 1;
    animation.removedOnCompletion = YES;
    animation.fillMode = kCAFillModeForwards;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [_lockedView.layer addAnimation:animation forKey:@"opacity"];

    [_speedLabel.layer removeAllAnimations];
    CABasicAnimation *animationReverse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    animationReverse.fromValue = [NSNumber numberWithFloat:1.0];
    animationReverse.toValue = [NSNumber numberWithFloat:0.0];
    animationReverse.duration = duration;
    animationReverse.autoreverses = YES;
    animationReverse.repeatCount = 1;
    animationReverse.removedOnCompletion = YES;
    animationReverse.fillMode = kCAFillModeForwards;
    animationReverse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [_speedLabel.layer addAnimation:animationReverse forKey:@"opacity"];
}

- (void)panGestureRecognized:(UIPanGestureRecognizer *)sender {
    if (!_isFocused) return;

    HUDPresetPosition selectedMode = [self selectedModeForCurrentOrientation];
    BOOL isCentered = (selectedMode == HUDPresetPositionTopCenter || selectedMode == HUDPresetPositionTopCenterMost);

    if (isCentered || [self keepInPlace]) {
        if (sender.state == UIGestureRecognizerStateBegan)
            [self cancelPreviousPerformRequestsWithTarget:sender.view];
        else if (sender.state == UIGestureRecognizerStateFailed || sender.state == UIGestureRecognizerStateEnded || sender.state == UIGestureRecognizerStateCancelled)
            [self performSelector:@selector(onBlur:) withObject:sender.view afterDelay:IDLE_INTERVAL];

        if (sender.state == UIGestureRecognizerStateBegan) {
            if (!_notificationFeedbackGenerator)
                _notificationFeedbackGenerator = [[UINotificationFeedbackGenerator alloc] init];
            [_notificationFeedbackGenerator prepare];
            [_notificationFeedbackGenerator notificationOccurred:UINotificationFeedbackTypeError];
            [self flashLockedViewWithDuration:0.2];
        }
        return;
    }

    static CGFloat beginX = 0.0;
    static CGFloat beginY = 0.0;

    if (sender.state == UIGestureRecognizerStatePossible || sender.state == UIGestureRecognizerStateBegan) {
        [self cancelPreviousPerformRequestsWithTarget:sender.view];
        beginX = [self realCustomOffsetX];
        beginY = _topConstraint ? _topConstraint.constant : _centerTopConstraint.constant;
        [self onFocus:sender.view scaleFactor:0.2 duration:0.1 beginFromInitialState:NO blurWhenDone:NO];
    } else {
        if (sender.state == UIGestureRecognizerStateChanged || sender.state == UIGestureRecognizerStateEnded) {
            CGPoint trans = [sender translationInView:sender.view.superview];
            CGFloat newX = beginX + trans.x;
            CGFloat newY = beginY + trans.y;
            
            _contentLeadingConstraint.constant = newX;
            _contentTrailingConstraint.constant = newX;
            if (_topConstraint) _topConstraint.constant = newY;
            if (_centerTopConstraint) _centerTopConstraint.constant = newY;
            [self.view layoutIfNeeded];
        }

        if (sender.state == UIGestureRecognizerStateEnded) {
            CGPoint trans = [sender translationInView:sender.view.superview];
            CGFloat newX = beginX + trans.x;
            CGFloat newY = beginY + trans.y - 20;
            
            [self loadUserDefaults:NO];
            [_userDefaults setObject:@(YES) forKey:@"HUDUserDefaultsKeyUsesCustomOffset"];
            [_userDefaults setObject:@(newX) forKey:@"HUDUserDefaultsKeyRealCustomOffsetX"];
            [_userDefaults setObject:@(newY) forKey:@"HUDUserDefaultsKeyRealCustomOffsetY"];
            [self saveUserDefaults];
        }

        if (sender.state != UIGestureRecognizerStateChanged) {
            [self onFocus:sender.view scaleFactor:0.1 duration:0.1 beginFromInitialState:NO blurWhenDone:NO];
            [self reloadUserDefaults];
        }
    }

    if (!_impactFeedbackGenerator) {
        _impactFeedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    }

    if (sender.state == UIGestureRecognizerStateBegan || sender.state == UIGestureRecognizerStateEnded || sender.state == UIGestureRecognizerStateCancelled) {
        [_impactFeedbackGenerator prepare];
        [_impactFeedbackGenerator impactOccurred];
    }
}
@end

@implementation HUDRootViewController (Troll)

static inline CGFloat orientationAngle(UIInterfaceOrientation orientation) {
    switch (orientation) {
        case UIInterfaceOrientationPortraitUpsideDown: return M_PI;
        case UIInterfaceOrientationLandscapeLeft: return -M_PI_2;
        case UIInterfaceOrientationLandscapeRight: return M_PI_2;
        default: return 0;
    }
}

static inline CGRect orientationBounds(UIInterfaceOrientation orientation, CGRect bounds) {
    switch (orientation) {
        case UIInterfaceOrientationLandscapeLeft:
        case UIInterfaceOrientationLandscapeRight: return CGRectMake(0, 0, bounds.size.height, bounds.size.width);
        default: return bounds;
    }
}

- (void)updateOrientation:(UIInterfaceOrientation)orientation animateWithDuration:(NSTimeInterval)duration {
    BOOL usesRotation = [self usesRotation];

    if (!usesRotation) {
        [self onBlur:_contentView duration:0];
        if (orientation == UIInterfaceOrientationPortrait) {
            __weak typeof(self) weakSelf = self;
            [UIView animateWithDuration:duration animations:^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                strongSelf->_contentView.alpha = strongSelf->_isFocused ? 1.0 : HUD_INACTIVE_OPACITY;
            }];
        } else {
            __weak typeof(self) weakSelf = self;
            [UIView animateWithDuration:duration animations:^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                strongSelf->_contentView.alpha = 0.0;
            }];
        }
        return;
    }

    if (orientation == _orientation) { return; }

    _orientation = orientation;
    [self cancelPreviousPerformRequestsWithTarget:_contentView];

    CGRect bounds = orientationBounds(orientation, [UIScreen mainScreen].bounds);
    [self.view setNeedsUpdateConstraints];
    [self.view setHidden:YES];
    [self.view setBounds:bounds];

    [self resetGestureRecognizers];
    [self onBlur:_contentView duration:duration];

    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:duration animations:^{
        [weakSelf.view setTransform:CGAffineTransformMakeRotation(orientationAngle(orientation))];
    } completion:^(BOOL finished) {
        [weakSelf.view setHidden:NO];
    }];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskPortrait; }

@end