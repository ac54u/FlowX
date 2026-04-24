//
//  RootViewController.mm
//  TrollSpeed - Final Compiler-Safe Edition
//

#import <notify.h>
#import <objc/runtime.h>
#import "HUDHelper.h"
#import "MainButton.h"
#import "MainApplication.h"
#import "HUDPresetPosition.h"
#import "RootViewController.h"
#import "UIApplication+Private.h"
#import "HUDRootViewController.h"

#define HUD_TRANSITION_DURATION 0.25

@interface TSTileButton : UIControl
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, assign) BOOL isOn;
- (void)setOn:(BOOL)on animated:(BOOL)animated;
@end

@implementation TSTileButton
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.layer.cornerRadius = 14;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.backgroundColor = [UIColor secondarySystemFillColor];
        
        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.tintColor = [UIColor labelColor];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_iconView];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.textColor = [UIColor secondaryLabelColor];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_titleLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [_iconView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_iconView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:-8],
            [_iconView.widthAnchor constraintEqualToConstant:24],
            [_iconView.heightAnchor constraintEqualToConstant:24],
            [_titleLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_titleLabel.topAnchor constraintEqualToAnchor:_iconView.bottomAnchor constant:6],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:2],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-2]
        ]];
        
        [self addTarget:self action:@selector(touchDown) forControlEvents:UIControlEventTouchDown];
        [self addTarget:self action:@selector(touchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    }
    return self;
}
- (void)touchDown { [UIView animateWithDuration:0.15 animations:^{ self.transform = CGAffineTransformMakeScale(0.9, 0.9); }]; }
- (void)touchUp { [UIView animateWithDuration:0.15 animations:^{ self.transform = CGAffineTransformIdentity; }]; }
- (void)setOn:(BOOL)on animated:(BOOL)animated {
    _isOn = on;
    void (^updateBlock)(void) = ^{
        if (on) {
            self.backgroundColor = [UIColor systemBlueColor];
            self.iconView.tintColor = [UIColor whiteColor];
            self.titleLabel.textColor = [UIColor whiteColor];
        } else {
            self.backgroundColor = [UIColor secondarySystemFillColor];
            self.iconView.tintColor = [UIColor labelColor];
            self.titleLabel.textColor = [UIColor secondaryLabelColor];
        }
    };
    if (animated) [UIView transitionWithView:self duration:0.2 options:UIViewAnimationOptionTransitionCrossDissolve animations:updateBlock completion:nil];
    else updateBlock();
}
@end

@interface TSMainCard : UIControl
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *trafficLabel;
@property (nonatomic, assign) BOOL isOn;
- (void)setOn:(BOOL)on animated:(BOOL)animated;
@end

@implementation TSMainCard
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.layer.cornerRadius = 24;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        
        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_iconView];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightHeavy];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_titleLabel];
        
        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_subtitleLabel];
        
        _trafficLabel = [[UILabel alloc] init];
        _trafficLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightMedium];
        _trafficLabel.textColor = [UIColor systemGrayColor];
        _trafficLabel.text = @"📊 今日已用: 等待底层抓取...";
        _trafficLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_trafficLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [_iconView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_iconView.topAnchor constraintEqualToAnchor:self.topAnchor constant:20],
            [_iconView.widthAnchor constraintEqualToConstant:40],
            [_iconView.heightAnchor constraintEqualToConstant:40],
            [_titleLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_titleLabel.topAnchor constraintEqualToAnchor:_iconView.bottomAnchor constant:8],
            [_subtitleLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4],
            [_trafficLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_trafficLabel.topAnchor constraintEqualToAnchor:_subtitleLabel.bottomAnchor constant:12]
        ]];
        
        [self addTarget:self action:@selector(touchDown) forControlEvents:UIControlEventTouchDown];
        [self addTarget:self action:@selector(touchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    }
    return self;
}
- (void)touchDown { [UIView animateWithDuration:0.15 animations:^{ self.transform = CGAffineTransformMakeScale(0.95, 0.95); }]; }
- (void)touchUp { [UIView animateWithDuration:0.15 animations:^{ self.transform = CGAffineTransformIdentity; }]; }
- (void)setOn:(BOOL)on animated:(BOOL)animated {
    _isOn = on;
    void (^updateBlock)(void) = ^{
        if (on) {
            self.backgroundColor = [UIColor systemGreenColor];
            self.iconView.image = [UIImage systemImageNamed:@"speedometer"];
            self.iconView.tintColor = [UIColor whiteColor];
            self.titleLabel.text = @"监控运行中";
            self.titleLabel.textColor = [UIColor whiteColor];
            self.subtitleLabel.text = @"您可以在屏幕上自由拖动悬浮窗";
            self.subtitleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
            self.trafficLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.9];
        } else {
            self.backgroundColor = [UIColor secondarySystemFillColor];
            self.iconView.image = [UIImage systemImageNamed:@"speedometer"];
            self.iconView.tintColor = [UIColor systemGrayColor];
            self.titleLabel.text = @"悬浮窗已关闭";
            self.titleLabel.textColor = [UIColor labelColor];
            self.subtitleLabel.text = @"点击卡片启动服务";
            self.subtitleLabel.textColor = [UIColor secondaryLabelColor];
            self.trafficLabel.textColor = [UIColor systemGrayColor];
        }
    };
    if (animated) [UIView transitionWithView:self duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:updateBlock completion:nil];
    else updateBlock();
}
@end

@implementation RootViewController {
    NSMutableDictionary *_userDefaults;
    BOOL _isRemoteHUDActive;
    TSMainCard *_mainCard;
    NSArray<TSTileButton *> *_posButtons;
    NSArray<TSTileButton *> *_settingButtons;
    UIImpactFeedbackGenerator *_impactFeedbackGenerator;
}

+ (void)setShouldToggleHUDAfterLaunch:(BOOL)flag { _gShouldToggleHUDAfterLaunch = flag; }
+ (BOOL)shouldToggleHUDAfterLaunch { return _gShouldToggleHUDAfterLaunch; }
- (BOOL)isHUDEnabled { return IsHUDEnabled(); }
- (void)setHUDEnabled:(BOOL)enabled { SetHUDEnabled(enabled); }
- (BOOL)prefersStatusBarHidden { return NO; }
- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures { return UIRectEdgeNone; }

- (void)registerNotifications {
    int token;
    notify_register_dispatch(NOTIFY_RELOAD_APP, &token, dispatch_get_main_queue(), ^(int token) {
        [self loadUserDefaults:YES];
        [self reloadAllStatesAnimated:YES];
    });
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(toggleHUDNotificationReceived:) name:kToggleHUDAfterLaunchNotificationName object:nil];
    
    int trafficToken;
    notify_register_dispatch("ch.xxtou.hudapp.traffic_update", &trafficToken, dispatch_get_main_queue(), ^(int t) {
        [self updateTrafficUI];
    });
}

- (void)updateTrafficUI {
    [self loadUserDefaults:NO];
    NSString *today = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterNoStyle];
    NSString *savedDay = [_userDefaults objectForKey:@"kDailyTrafficDate"];
    
    if ([today isEqualToString:savedDay]) {
        uint64_t total = [[_userDefaults objectForKey:@"kDailyTrafficTotalBytes"] unsignedLongLongValue];
        NSString *totalStr = @"0 KB";
        if (total < (1ULL << 20)) totalStr = [NSString stringWithFormat:@"%.1f KB", (double)total / (1ULL << 10)];
        else if (total < (1ULL << 30)) totalStr = [NSString stringWithFormat:@"%.1f MB", (double)total / (1ULL << 20)];
        else totalStr = [NSString stringWithFormat:@"%.2f GB", (double)total / (1ULL << 30)];
        
        _mainCard.trafficLabel.text = [NSString stringWithFormat:@"📊 今日已用: %@", totalStr];
    } else {
        _mainCard.trafficLabel.text = @"📊 今日已用: 0.0 KB";
    }
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scrollView.alwaysBounceVertical = YES;
    scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:scrollView];

    UIStackView *mainStack = [[UIStackView alloc] init];
    mainStack.axis = UILayoutConstraintAxisVertical;
    mainStack.spacing = 15;
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:mainStack];
    
    [NSLayoutConstraint activateConstraints:@[
        [mainStack.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor constant:15],
        [mainStack.leadingAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.leadingAnchor constant:20],
        [mainStack.trailingAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.trailingAnchor constant:-20],
        [mainStack.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor constant:-40]
    ]];

    _mainCard = [[TSMainCard alloc] init];
    [_mainCard.heightAnchor constraintEqualToConstant:150].active = YES;
    [_mainCard addTarget:self action:@selector(mainSwitchToggled) forControlEvents:UIControlEventTouchUpInside];
    [mainStack addArrangedSubview:_mainCard];

    UIStackView *posStack = [[UIStackView alloc] init];
    posStack.axis = UILayoutConstraintAxisHorizontal;
    posStack.distribution = UIStackViewDistributionFillEqually;
    posStack.spacing = 10;
    [posStack.heightAnchor constraintEqualToConstant:70].active = YES;
    
    NSArray *posIcons = @[@"arrow.up.left", @"capsule.portrait", @"arrow.up.right"];
    NSArray *posTitles = @[@"左侧", @"居中", @"右侧"];
    NSMutableArray *tmpPos = [NSMutableArray array];
    for (int i = 0; i < 3; i++) {
        TSTileButton *btn = [[TSTileButton alloc] init];
        btn.iconView.image = [UIImage systemImageNamed:posIcons[i]];
        btn.titleLabel.text = posTitles[i];
        btn.tag = i;
        [btn addTarget:self action:@selector(positionToggled:) forControlEvents:UIControlEventTouchUpInside];
        [posStack addArrangedSubview:btn];
        [tmpPos addObject:btn];
    }
    _posButtons = tmpPos;
    [mainStack addArrangedSubview:posStack];

    UIStackView *gridStack = [[UIStackView alloc] init];
    gridStack.axis = UILayoutConstraintAxisVertical;
    gridStack.spacing = 10;
    
    NSArray *tags = @[@100, @101, @110, @103, @102, @104, @106, @109, @105, @107, @108, @111];
    NSArray *icons = @[@"cursorarrow.rays", @"minus", @"paintpalette.fill", @"arrow.up.arrow.down", @"chart.bar.fill", @"textformat.size", @"circle.lefthalf.filled", @"speedometer", @"crop.rotate", @"lock.rotation", @"camera.viewfinder", @"arrow.counterclockwise"];
    NSArray *titles = @[@"穿透", @"单行", @"双色", @"箭头", @"单位", @"大字", @"反色", @"帧率", @"旋转", @"原位", @"防截", @"复位"];
    NSMutableArray *tmpSetting = [NSMutableArray array];
    
    for (int r = 0; r < 3; r++) {
        UIStackView *row = [[UIStackView alloc] init];
        row.axis = UILayoutConstraintAxisHorizontal;
        row.distribution = UIStackViewDistributionFillEqually;
        row.spacing = 10;
        [row.heightAnchor constraintEqualToConstant:65].active = YES;
        for (int c = 0; c < 4; c++) {
            int idx = r * 4 + c;
            TSTileButton *btn = [[TSTileButton alloc] init];
            btn.iconView.image = [UIImage systemImageNamed:icons[idx]];
            btn.titleLabel.text = titles[idx];
            btn.tag = [tags[idx] integerValue];
            if (btn.tag == 111) {
                btn.iconView.tintColor = [UIColor systemRedColor];
                btn.titleLabel.textColor = [UIColor systemRedColor];
            }
            [btn addTarget:self action:@selector(settingToggled:) forControlEvents:UIControlEventTouchUpInside];
            [row addArrangedSubview:btn];
            [tmpSetting addObject:btn];
        }
        [gridStack addArrangedSubview:row];
    }
    _settingButtons = tmpSetting;
    [mainStack addArrangedSubview:gridStack];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _impactFeedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [self registerNotifications];
    [self updateTrafficUI];
    [self reloadAllStatesAnimated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self toggleHUDAfterLaunch];
}

- (void)mainSwitchToggled {
    [_impactFeedbackGenerator prepare];
    [_impactFeedbackGenerator impactOccurred];
    [self toggleMainHUDState];
}

- (void)toggleMainHUDState {
    BOOL isNowEnabled = [self isHUDEnabled];
    [self setHUDEnabled:!isNowEnabled];
    isNowEnabled = !isNowEnabled;

    if (isNowEnabled) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        int anyToken;
        notify_register_dispatch(NOTIFY_LAUNCHED_HUD, &anyToken, dispatch_get_main_queue(), ^(int token) {
            notify_cancel(token); dispatch_semaphore_signal(semaphore);
        });
        self.view.userInteractionEnabled = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)));
            dispatch_async(dispatch_get_main_queue(), ^{ [self reloadAllStatesAnimated:YES]; self.view.userInteractionEnabled = YES; });
        });
    } else {
        self.view.userInteractionEnabled = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self reloadAllStatesAnimated:YES]; self.view.userInteractionEnabled = YES; });
    }
}

- (void)positionToggled:(TSTileButton *)sender {
    [_impactFeedbackGenerator prepare]; [_impactFeedbackGenerator impactOccurred];
    HUDPresetPosition currentMode = [self selectedModeForCurrentOrientation];
    HUDPresetPosition newMode = currentMode;
    if (sender.tag == 0) newMode = HUDPresetPositionTopLeft;
    if (sender.tag == 2) newMode = HUDPresetPositionTopRight;
    if (sender.tag == 1) newMode = (currentMode == HUDPresetPositionTopCenterMost) ? HUDPresetPositionTopCenter : HUDPresetPositionTopCenterMost;
    
    [self loadUserDefaults:NO];
    [_userDefaults setObject:@(NO) forKey:@"HUDUserDefaultsKeyUsesCustomOffset"];
    [_userDefaults setObject:@(0) forKey:@"HUDUserDefaultsKeyRealCustomOffsetX"];
    [_userDefaults setObject:@(0) forKey:@"HUDUserDefaultsKeyRealCustomOffsetY"];
    [self saveUserDefaults];
    
    [self setSelectedModeForCurrentOrientation:newMode];
    [self reloadAllStatesAnimated:YES];
}

- (void)settingToggled:(TSTileButton *)sender {
    [_impactFeedbackGenerator prepare]; [_impactFeedbackGenerator impactOccurred];
    
    if (sender.tag == 111) { // 复位
        [self loadUserDefaults:NO];
        [_userDefaults setObject:@(NO) forKey:@"HUDUserDefaultsKeyUsesCustomOffset"];
        [_userDefaults setObject:@(0) forKey:@"HUDUserDefaultsKeyRealCustomOffsetX"];
        [_userDefaults setObject:@(0) forKey:@"HUDUserDefaultsKeyRealCustomOffsetY"];
        [self saveUserDefaults];
        [self reloadAllStatesAnimated:YES];
        return;
    }
    
    BOOL newState = !sender.isOn;
    switch (sender.tag) {
        case 100: [self setPassthroughMode:newState]; break;
        case 101: [self setSingleLineMode:newState]; break;
        case 102: [self setUsesBitrate:newState]; break;
        case 103: [self setUsesArrowPrefixes:newState]; break;
        case 104: [self setUsesLargeFont:newState]; break;
        case 105: [self setUsesRotation:newState]; break;
        case 106: [self setUsesInvertedColor:newState]; break;
        case 107: [self setKeepInPlace:newState]; break;
        case 108: [self setHideAtSnapshot:newState]; break;
        case 109: [self setDisplayMode:newState]; break;
        case 110: [self setUsesDualColor:newState]; break;
    }
    [sender setOn:newState animated:YES];
}

- (void)reloadAllStatesAnimated:(BOOL)animated {
    _isRemoteHUDActive = [self isHUDEnabled];
    [_mainCard setOn:_isRemoteHUDActive animated:animated];
    
    HUDPresetPosition mode = [self selectedModeForCurrentOrientation];
    [_posButtons[0] setOn:(mode == HUDPresetPositionTopLeft) animated:animated];
    [_posButtons[2] setOn:(mode == HUDPresetPositionTopRight) animated:animated];
    BOOL isCenter = (mode == HUDPresetPositionTopCenter || mode == HUDPresetPositionTopCenterMost);
    [_posButtons[1] setOn:isCenter animated:animated];
    _posButtons[1].iconView.image = [UIImage systemImageNamed:(mode == HUDPresetPositionTopCenterMost ? @"capsule.inset.filled" : @"capsule.portrait")];

    for (TSTileButton *btn in _settingButtons) {
        if (btn.tag == 111) continue;
        BOOL isOn = NO;
        switch (btn.tag) {
            case 100: isOn = [self passthroughMode]; break;
            case 101: isOn = [self singleLineMode]; break;
            case 102: isOn = [self usesBitrate]; break;
            case 103: isOn = [self usesArrowPrefixes]; break;
            case 104: isOn = [self usesLargeFont]; break;
            case 105: isOn = [self usesRotation]; break;
            case 106: isOn = [self usesInvertedColor]; break;
            case 107: isOn = [self keepInPlace]; break;
            case 108: isOn = [self hideAtSnapshot]; break;
            case 109: isOn = [self displayMode]; break;
            case 110: isOn = [self usesDualColor]; break;
        }
        [btn setOn:isOn animated:animated];
    }
}

// ==========================================
// 兼容协议方法的“空壳”实现 (防报错核心)
// ==========================================
#pragma mark - Dummy TableView Delegates
- (NSInteger)numberOfSectionsInTableView:(id)tableView { return 0; }
- (NSInteger)tableView:(id)tableView numberOfRowsInSection:(NSInteger)section { return 0; }
- (id)tableView:(id)tableView titleForHeaderInSection:(NSInteger)section { return nil; }
- (id)tableView:(id)tableView cellForRowAtIndexPath:(id)indexPath { return nil; }
- (void)tableView:(id)tableView didSelectRowAtIndexPath:(id)indexPath {}

#pragma mark - Legacy Method Stubs
- (void)reloadModeButtonState { [self reloadAllStatesAnimated:YES]; }
- (void)presentTopCenterMostHints {}
- (void)verticalSizeClassUpdated {}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {}
- (void)reloadMainButtonState { [self reloadAllStatesAnimated:YES]; }
- (BOOL)settingHighlightedWithKey:(NSString *)key { [self loadUserDefaults:NO]; NSNumber *mode = [_userDefaults objectForKey:key]; return mode != nil ? [mode boolValue] : NO; }
- (void)settingDidSelectWithKey:(NSString *)key { BOOL highlighted = [self settingHighlightedWithKey:key]; [_userDefaults setObject:@(!highlighted) forKey:key]; [self saveUserDefaults]; [self reloadAllStatesAnimated:YES]; }
- (void)toggleHUDNotificationReceived:(NSNotification *)notification { NSString *toggleAction = notification.userInfo[kToggleHUDAfterLaunchNotificationActionKey]; if (!toggleAction) [self toggleHUDAfterLaunch]; else if ([toggleAction isEqualToString:kToggleHUDAfterLaunchNotificationActionToggleOn]) [self toggleOnHUDAfterLaunch]; else if ([toggleAction isEqualToString:kToggleHUDAfterLaunchNotificationActionToggleOff]) [self toggleOffHUDAfterLaunch]; }
- (void)toggleHUDAfterLaunch { if ([RootViewController shouldToggleHUDAfterLaunch]) { [RootViewController setShouldToggleHUDAfterLaunch:NO]; if (!_isRemoteHUDActive) [self mainSwitchToggled]; [[UIApplication sharedApplication] suspend]; } }
- (void)toggleOnHUDAfterLaunch { if ([RootViewController shouldToggleHUDAfterLaunch]) { [RootViewController setShouldToggleHUDAfterLaunch:NO]; if (!_isRemoteHUDActive) [self mainSwitchToggled]; [[UIApplication sharedApplication] suspend]; } }
- (void)toggleOffHUDAfterLaunch { if ([RootViewController shouldToggleHUDAfterLaunch]) { [RootViewController setShouldToggleHUDAfterLaunch:NO]; if (_isRemoteHUDActive) [self mainSwitchToggled]; [[UIApplication sharedApplication] suspend]; } }
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator { [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator]; [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) { [self reloadAllStatesAnimated:NO]; } completion:nil]; }
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event { if (motion == UIEventSubtypeMotionShake) { UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"开发者选项" message:@"请选择操作" preferredStyle:UIAlertControllerStyleAlert]; [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]]; [alert addAction:[UIAlertAction actionWithTitle:@"重置所有设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) { NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier]; if (bundleIdentifier) { [GetStandardUserDefaults() removePersistentDomainForName:bundleIdentifier]; [GetStandardUserDefaults() synchronize]; } if ([[NSFileManager defaultManager] removeItemAtPath:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH)) error:nil]) { [self setHUDEnabled:NO]; [[UIApplication sharedApplication] terminateWithSuccess]; } }]]; [self presentViewController:alert animated:YES completion:nil]; } }

// ==========================================
// 属性持久化逻辑
// ==========================================
- (void)loadUserDefaults:(BOOL)forceReload { if (forceReload || !_userDefaults) { _userDefaults = [[NSDictionary dictionaryWithContentsOfFile:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH))] mutableCopy] ?: [NSMutableDictionary dictionary]; } }
- (void)saveUserDefaults { [_userDefaults writeToFile:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH)) atomically:YES]; notify_post(NOTIFY_RELOAD_HUD); }
- (BOOL)isLandscapeOrientation { UIInterfaceOrientation orientation = self.view.window.windowScene.interfaceOrientation; if (orientation == UIInterfaceOrientationUnknown) { return CGRectGetWidth(self.view.bounds) > CGRectGetHeight(self.view.bounds); } return UIInterfaceOrientationIsLandscape(orientation); }
- (HUDUserDefaultsKey)selectedModeKeyForCurrentOrientation { return [self isLandscapeOrientation] ? HUDUserDefaultsKeySelectedModeLandscape : HUDUserDefaultsKeySelectedMode; }
- (HUDPresetPosition)selectedModeForCurrentOrientation { [self loadUserDefaults:NO]; NSNumber *mode = [_userDefaults objectForKey:[self selectedModeKeyForCurrentOrientation]]; return mode != nil ? (HUDPresetPosition)[mode integerValue] : HUDPresetPositionTopCenter; }
- (void)setSelectedModeForCurrentOrientation:(HUDPresetPosition)selectedMode { [self loadUserDefaults:NO]; if ([self isLandscapeOrientation]) { [_userDefaults removeObjectForKey:HUDUserDefaultsKeyCurrentLandscapePositionY]; } else { [_userDefaults removeObjectForKey:HUDUserDefaultsKeyCurrentPositionY]; } [_userDefaults setObject:@(selectedMode) forKey:[self selectedModeKeyForCurrentOrientation]]; [self saveUserDefaults]; }
- (BOOL)passthroughMode { [self loadUserDefaults:NO]; NSNumber *m = [_userDefaults objectForKey:HUDUserDefaultsKeyPassthroughMode]; return m != nil ? [m boolValue] : NO; }
- (void)setPassthroughMode:(BOOL)p { [self loadUserDefaults:NO]; [_userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyPassthroughMode]; [self saveUserDefaults]; }
- (BOOL)singleLineMode { [self loadUserDefaults:NO]; NSNumber *m = [_userDefaults objectForKey:HUDUserDefaultsKeySingleLineMode]; return m != nil ? [m boolValue] : NO; }
- (void)setSingleLineMode:(BOOL)p { [self loadUserDefaults:NO]; [_userDefaults setObject:@(p) forKey:HUDUserDefaultsKeySingleLineMode]; [self saveUserDefaults]; }
- (BOOL)usesBitrate { [self loadUserDefaults:NO]; NSNumber *m = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesBitrate]; return m != nil ? [m boolValue] : NO; }
- (void)setUsesBitrate:(BOOL)p { [self loadUserDefaults:NO]; [_userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyUsesBitrate]; [self saveUserDefaults]; }
- (BOOL)usesArrowPrefixes { [self loadUserDefaults:NO]; NSNumber *m = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesArrowPrefixes]; return m != nil ? [m boolValue] : NO; }
- (void)setUsesArrowPrefixes:(BOOL)p { [self loadUserDefaults:NO]; [_userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyUsesArrowPrefixes]; [self saveUserDefaults]; }
- (BOOL)usesLargeFont { [self loadUserDefaults:NO]; NSNumber *m = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesLargeFont]; return m != nil ? [m boolValue] : NO; }
- (void)setUsesLargeFont:(BOOL)p { [self loadUserDefaults:NO]; [_userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyUsesLargeFont]; [self saveUserDefaults]; }
- (BOOL)usesRotation { [self loadUserDefaults:NO]; NSNumber *m = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesRotation]; return m != nil ? [m boolValue] : NO; }
- (void)setUsesRotation:(BOOL)p { [self loadUserDefaults:NO]; [_userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyUsesRotation]; [self saveUserDefaults]; }
- (BOOL)usesInvertedColor { [self loadUserDefaults:NO]; NSNumber *m = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesInvertedColor]; return m != nil ? [m boolValue] : NO; }
- (void)setUsesInvertedColor:(BOOL)p { [self loadUserDefaults:NO]; [_userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyUsesInvertedColor]; [self saveUserDefaults]; }
- (BOOL)keepInPlace { [self loadUserDefaults:NO]; NSNumber *m = [_userDefaults objectForKey:HUDUserDefaultsKeyKeepInPlace]; return m != nil ? [m boolValue] : NO; }
- (void)setKeepInPlace:(BOOL)p { [self loadUserDefaults:NO]; [_userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyKeepInPlace]; [self saveUserDefaults]; }
- (BOOL)hideAtSnapshot { [self loadUserDefaults:NO]; NSNumber *m = [_userDefaults objectForKey:HUDUserDefaultsKeyHideAtSnapshot]; return m != nil ? [m boolValue] : NO; }
- (void)setHideAtSnapshot:(BOOL)p { [self loadUserDefaults:NO]; [_userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyHideAtSnapshot]; [self saveUserDefaults]; }
- (BOOL)displayMode { [self loadUserDefaults:NO]; NSNumber *m = [_userDefaults objectForKey:HUDUserDefaultsKeyDisplayMode]; return m != nil ? [m boolValue] : NO; }
- (void)setDisplayMode:(BOOL)p { [self loadUserDefaults:NO]; [_userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyDisplayMode]; [self saveUserDefaults]; }
- (BOOL)usesDualColor { [self loadUserDefaults:NO]; NSNumber *m = [_userDefaults objectForKey:@"HUD_USES_DUAL_COLOR"]; return m != nil ? [m boolValue] : YES; }
- (void)setUsesDualColor:(BOOL)p { [self loadUserDefaults:NO]; [_userDefaults setObject:@(p) forKey:@"HUD_USES_DUAL_COLOR"]; [self saveUserDefaults]; }
- (BOOL)usesCustomOffset { return [[NSUserDefaults standardUserDefaults] boolForKey:@"HUDUserDefaultsKeyUsesCustomOffset"]; }
- (CGFloat)realCustomOffsetX { return [[NSUserDefaults standardUserDefaults] doubleForKey:@"HUDUserDefaultsKeyRealCustomOffsetX"]; }
- (CGFloat)realCustomOffsetY { return [[NSUserDefaults standardUserDefaults] doubleForKey:@"HUDUserDefaultsKeyRealCustomOffsetY"]; }
- (void)tapAuthorLabel:(UITapGestureRecognizer *)s { if (_isRemoteHUDActive) return; [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://trollspeed.app"] options:@{} completionHandler:nil]; }
@end