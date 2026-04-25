//
//  RootViewController.mm
//  TrollSpeed
//
//  Restored Original Architecture with Control Center UI
//

#import <notify.h>

#import "HUDHelper.h"
#import "MainButton.h"
#import "MainApplication.h"
#import "HUDPresetPosition.h"
#import "RootViewController.h"
#import "UIApplication+Private.h"
#import "HUDRootViewController.h"
#import "TrollSpeed-Swift.h"

#define HUD_TRANSITION_DURATION 0.25

// ==========================================
// 控制中心风格 UI 组件
// ==========================================
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
        _titleLabel.adjustsFontSizeToFitWidth = YES;
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
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

- (void)touchDown {
    [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.transform = CGAffineTransformMakeScale(0.88, 0.88);
    } completion:nil];
}

- (void)touchUp {
    [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.transform = CGAffineTransformIdentity;
    } completion:nil];
}

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
    if (animated) {
        [UIView transitionWithView:self duration:0.2 options:UIViewAnimationOptionTransitionCrossDissolve animations:updateBlock completion:nil];
    } else {
        updateBlock();
    }
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
            [_iconView.topAnchor constraintEqualToAnchor:self.topAnchor constant:24],
            [_iconView.widthAnchor constraintEqualToConstant:46],
            [_iconView.heightAnchor constraintEqualToConstant:46],
            
            [_titleLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_titleLabel.topAnchor constraintEqualToAnchor:_iconView.bottomAnchor constant:12],
            
            [_subtitleLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:6],
            
            [_trafficLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_trafficLabel.topAnchor constraintEqualToAnchor:_subtitleLabel.bottomAnchor constant:12]
        ]];
        
        [self addTarget:self action:@selector(touchDown) forControlEvents:UIControlEventTouchDown];
        [self addTarget:self action:@selector(touchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    }
    return self;
}

- (void)touchDown {
    [UIView animateWithDuration:0.15 animations:^{ self.transform = CGAffineTransformMakeScale(0.95, 0.95); }];
}
- (void)touchUp {
    [UIView animateWithDuration:0.15 animations:^{ self.transform = CGAffineTransformIdentity; }];
}

- (void)setOn:(BOOL)on animated:(BOOL)animated {
    _isOn = on;
    void (^updateBlock)(void) = ^{
        if (on) {
            self.backgroundColor = [UIColor systemGreenColor];
            self.iconView.tintColor = [UIColor whiteColor];
            self.iconView.image = [UIImage systemImageNamed:@"speedometer"];
            self.titleLabel.textColor = [UIColor whiteColor];
            self.titleLabel.text = @"监控运行中";
            self.subtitleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
            self.subtitleLabel.text = @"底层服务已注入，可退至桌面";
            self.trafficLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.9];
        } else {
            self.backgroundColor = [UIColor secondarySystemFillColor];
            self.iconView.tintColor = [UIColor systemGrayColor];
            self.iconView.image = [UIImage systemImageNamed:@"speedometer"];
            self.titleLabel.textColor = [UIColor labelColor];
            self.titleLabel.text = @"悬浮窗已关闭";
            self.subtitleLabel.textColor = [UIColor secondaryLabelColor];
            self.subtitleLabel.text = @"点击启动悬浮窗";
            self.trafficLabel.textColor = [UIColor systemGrayColor];
        }
    };
    if (animated) {
        [UIView transitionWithView:self duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:updateBlock completion:nil];
    } else {
        updateBlock();
    }
}
@end


// ==========================================
// RootViewController 原始类
// ==========================================
#pragma mark - TSAppConfig
static BOOL _gShouldToggleHUDAfterLaunch = NO;

@implementation RootViewController {
    NSMutableDictionary *_userDefaults;
    UILabel *_authorLabel;
    BOOL _supportsCenterMost;
    BOOL _isRemoteHUDActive;
    
    UIScrollView *_scrollView; // 恢复 ScrollView 以防内容挤出屏幕
    TSMainCard *_mainCard;
    NSArray<TSTileButton *> *_posButtons;
    NSArray<TSTileButton *> *_settingButtons;
    
    UIImpactFeedbackGenerator *_impactFeedbackGenerator;
}

+ (void)setShouldToggleHUDAfterLaunch:(BOOL)flag {
    _gShouldToggleHUDAfterLaunch = flag;
}

+ (BOOL)shouldToggleHUDAfterLaunch {
    return _gShouldToggleHUDAfterLaunch;
}

- (BOOL)isHUDEnabled {
    return IsHUDEnabled();
}

- (void)setHUDEnabled:(BOOL)enabled {
    SetHUDEnabled(enabled);
}

- (BOOL)prefersStatusBarHidden {
    return NO;
}

- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures {
    return UIRectEdgeNone;
}

- (void)registerNotifications
{
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

- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    _scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:_scrollView];

    UIStackView *mainStack = [[UIStackView alloc] init];
    mainStack.axis = UILayoutConstraintAxisVertical;
    mainStack.spacing = 24;
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    [_scrollView addSubview:mainStack];
    
    [NSLayoutConstraint activateConstraints:@[
        [mainStack.topAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.topAnchor constant:20],
        [mainStack.leadingAnchor constraintEqualToAnchor:_scrollView.frameLayoutGuide.leadingAnchor constant:24],
        [mainStack.trailingAnchor constraintEqualToAnchor:_scrollView.frameLayoutGuide.trailingAnchor constant:-24],
        [mainStack.bottomAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.bottomAnchor constant:-40]
    ]];

    // 1. 核心大卡片
    _mainCard = [[TSMainCard alloc] init];
    [_mainCard.heightAnchor constraintEqualToConstant:150].active = YES;
    [_mainCard addTarget:self action:@selector(mainSwitchToggled) forControlEvents:UIControlEventTouchUpInside];
    [mainStack addArrangedSubview:_mainCard];

    // 2. 位置控制区 (横向 3 个大磁贴)
    UIStackView *posStack = [[UIStackView alloc] init];
    posStack.axis = UILayoutConstraintAxisHorizontal;
    posStack.distribution = UIStackViewDistributionFillEqually;
    posStack.spacing = 12;
    [posStack.heightAnchor constraintEqualToConstant:80].active = YES;
    
    NSArray *posIcons = @[@"arrow.up.left", @"capsule.portrait", @"arrow.up.right"];
    NSArray *posTitles = @[@"左侧", @"居中", @"右侧"];
    NSMutableArray *tempPosBtns = [NSMutableArray array];
    
    for (int i = 0; i < 3; i++) {
        TSTileButton *btn = [[TSTileButton alloc] init];
        btn.iconView.image = [UIImage systemImageNamed:posIcons[i]];
        btn.titleLabel.text = posTitles[i];
        btn.tag = i;
        [btn addTarget:self action:@selector(positionToggled:) forControlEvents:UIControlEventTouchUpInside];
        [posStack addArrangedSubview:btn];
        [tempPosBtns addObject:btn];
    }
    _posButtons = tempPosBtns;
    [mainStack addArrangedSubview:posStack];

    // 3. 高级设置网格 (3行 x 4列，保证和原版功能一致，且布局不会拥挤)
    UIStackView *gridStack = [[UIStackView alloc] init];
    gridStack.axis = UILayoutConstraintAxisVertical;
    gridStack.spacing = 12;
    
    NSArray *settingTags = @[@100, @101, @102, @103, @104, @105, @106, @107, @108, @109, @110, @111];
    NSArray *settingIcons = @[@"hand.tap.slash", @"minus", @"chart.bar.fill", @"arrow.up.arrow.down", 
                              @"textformat.size", @"crop.rotate", @"moon.circle.fill", @"lock.fill", 
                              @"eye.slash.fill", @"speedometer", @"paintpalette.fill", @"arrow.counterclockwise"];
    NSArray *settingTitles = @[@"穿透", @"单行", @"单位", @"箭头", 
                               @"大字", @"旋转", @"反色", @"原位", 
                               @"防截", @"模式", @"双色", @"复位"];
    NSMutableArray *tempSettingBtns = [NSMutableArray array];
    
    for (int row = 0; row < 3; row++) {
        UIStackView *rowStack = [[UIStackView alloc] init];
        rowStack.axis = UILayoutConstraintAxisHorizontal;
        rowStack.distribution = UIStackViewDistributionFillEqually;
        rowStack.spacing = 12;
        [rowStack.heightAnchor constraintEqualToConstant:75].active = YES;
        
        for (int col = 0; col < 4; col++) {
            int index = row * 4 + col;
            TSTileButton *btn = [[TSTileButton alloc] init];
            btn.iconView.image = [UIImage systemImageNamed:settingIcons[index]];
            btn.titleLabel.text = settingTitles[index];
            btn.tag = [settingTags[index] integerValue];
            if (btn.tag == 111) {
                btn.iconView.tintColor = [UIColor systemRedColor];
                btn.titleLabel.textColor = [UIColor systemRedColor];
            }
            [btn addTarget:self action:@selector(advancedOptionToggled:) forControlEvents:UIControlEventTouchUpInside];
            [rowStack addArrangedSubview:btn];
            [tempSettingBtns addObject:btn];
        }
        [gridStack addArrangedSubview:rowStack];
    }
    _settingButtons = tempSettingBtns;
    [mainStack addArrangedSubview:gridStack];

    // 4. 底部版权信息
    _authorLabel = [[UILabel alloc] init];
    _authorLabel.numberOfLines = 0;
    _authorLabel.textAlignment = NSTextAlignmentCenter;
    _authorLabel.textColor = [UIColor tertiaryLabelColor];
    _authorLabel.font = [UIFont systemFontOfSize:12.0];
    [mainStack addArrangedSubview:_authorLabel];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapAuthorLabel:)];
    _authorLabel.userInteractionEnabled = YES;
    [_authorLabel addGestureRecognizer:tap];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    _supportsCenterMost = CGRectGetMinY(self.view.window.safeAreaLayoutGuide.layoutFrame) >= 51;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _impactFeedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [self registerNotifications];
    [self updateTrafficUI];
    [self reloadAllStatesAnimated:NO];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self toggleHUDAfterLaunch];
}

#pragma mark - Actions

- (void)mainSwitchToggled {
    [_impactFeedbackGenerator prepare];
    [_impactFeedbackGenerator impactOccurred];
    
    BOOL isNowEnabled = [self isHUDEnabled];
    [self setHUDEnabled:!isNowEnabled];
    isNowEnabled = !isNowEnabled;

    if (isNowEnabled) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        int anyToken;
        notify_register_dispatch(NOTIFY_LAUNCHED_HUD, &anyToken, dispatch_get_main_queue(), ^(int token) {
            notify_cancel(token);
            dispatch_semaphore_signal(semaphore);
        });

        self.view.userInteractionEnabled = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)));
            dispatch_async(dispatch_get_main_queue(), ^{
                [self reloadAllStatesAnimated:YES];
                self.view.userInteractionEnabled = YES;
            });
        });
    } else {
        self.view.userInteractionEnabled = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self reloadAllStatesAnimated:YES];
            self.view.userInteractionEnabled = YES;
        });
    }
}

- (void)positionToggled:(TSTileButton *)sender {
    [_impactFeedbackGenerator prepare];
    [_impactFeedbackGenerator impactOccurred];
    
    HUDPresetPosition currentMode = [self selectedModeForCurrentOrientation];
    HUDPresetPosition newMode = currentMode;
    
    if (sender.tag == 0) newMode = HUDPresetPositionTopLeft;
    if (sender.tag == 2) newMode = HUDPresetPositionTopRight;
    if (sender.tag == 1) {
        if (currentMode == HUDPresetPositionTopCenter || currentMode == HUDPresetPositionTopCenterMost) {
            newMode = (currentMode == HUDPresetPositionTopCenterMost) ? HUDPresetPositionTopCenter : HUDPresetPositionTopCenterMost;
        } else {
            newMode = HUDPresetPositionTopCenter;
        }
    }
    
    // 清理手动拖拽位置
    [self loadUserDefaults:NO];
    [_userDefaults setObject:@(NO) forKey:HUDUserDefaultsKeyUsesCustomOffset];
    [_userDefaults setObject:@(0) forKey:HUDUserDefaultsKeyRealCustomOffsetX];
    [_userDefaults setObject:@(0) forKey:HUDUserDefaultsKeyRealCustomOffsetY];
    [self saveUserDefaults];
    
    [self setSelectedModeForCurrentOrientation:newMode];
    [self reloadAllStatesAnimated:YES];
}

- (void)advancedOptionToggled:(TSTileButton *)sender {
    [_impactFeedbackGenerator prepare];
    [_impactFeedbackGenerator impactOccurred];
    
    if (sender.tag == 111) { // 复位拖拽坐标
        [self loadUserDefaults:NO];
        [_userDefaults setObject:@(NO) forKey:HUDUserDefaultsKeyUsesCustomOffset];
        [_userDefaults setObject:@(0) forKey:HUDUserDefaultsKeyRealCustomOffsetX];
        [_userDefaults setObject:@(0) forKey:HUDUserDefaultsKeyRealCustomOffsetY];
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

- (void)reloadMainButtonState {
    [self reloadAllStatesAnimated:YES];
}

- (void)reloadAllStatesAnimated:(BOOL)animated {
    _isRemoteHUDActive = [self isHUDEnabled];
    [_mainCard setOn:_isRemoteHUDActive animated:animated];
    
    HUDPresetPosition mode = [self selectedModeForCurrentOrientation];
    [_posButtons[0] setOn:(mode == HUDPresetPositionTopLeft) animated:animated];
    [_posButtons[2] setOn:(mode == HUDPresetPositionTopRight) animated:animated];
    
    BOOL isCenter = (mode == HUDPresetPositionTopCenter || mode == HUDPresetPositionTopCenterMost);
    [_posButtons[1] setOn:isCenter animated:animated];
    
    if (isCenter) {
        _posButtons[1].iconView.image = [UIImage systemImageNamed:(mode == HUDPresetPositionTopCenterMost ? @"capsule.inset.filled" : @"capsule.portrait")];
    } else {
        _posButtons[1].iconView.image = [UIImage systemImageNamed:@"capsule.portrait"];
    }

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
    
    NSString *credits = @"Made with ♥ by Lessica & jmpews\nDesign Reimagined by AI";
    _authorLabel.text = credits;
}

#pragma mark - TSSettingsControllerDelegate

- (BOOL)settingHighlightedWithKey:(NSString * _Nonnull)key
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:key];
    return mode != nil ? [mode boolValue] : NO;
}

- (void)settingDidSelectWithKey:(NSString * _Nonnull)key
{
    BOOL highlighted = [self settingHighlightedWithKey:key];
    [_userDefaults setObject:@(!highlighted) forKey:key];
    [self saveUserDefaults];
    [self reloadAllStatesAnimated:YES];
}

#pragma mark - State Toggle

- (void)toggleHUDNotificationReceived:(NSNotification *)notification
{
    NSString *toggleAction = notification.userInfo[kToggleHUDAfterLaunchNotificationActionKey];
    if (!toggleAction)
    {
        [self toggleHUDAfterLaunch];
    }
    else if ([toggleAction isEqualToString:kToggleHUDAfterLaunchNotificationActionToggleOn])
    {
        [self toggleOnHUDAfterLaunch];
    }
    else if ([toggleAction isEqualToString:kToggleHUDAfterLaunchNotificationActionToggleOff])
    {
        [self toggleOffHUDAfterLaunch];
    }
}

- (void)toggleHUDAfterLaunch
{
    if ([RootViewController shouldToggleHUDAfterLaunch])
    {
        [RootViewController setShouldToggleHUDAfterLaunch:NO];
        if (!_isRemoteHUDActive)
        {
            [self mainSwitchToggled];
        }
        [[UIApplication sharedApplication] suspend];
    }
}

- (void)toggleOnHUDAfterLaunch
{
    if ([RootViewController shouldToggleHUDAfterLaunch])
    {
        [RootViewController setShouldToggleHUDAfterLaunch:NO];
        if (!_isRemoteHUDActive)
        {
            [self mainSwitchToggled];
        }
        [[UIApplication sharedApplication] suspend];
    }
}

- (void)toggleOffHUDAfterLaunch
{
    if ([RootViewController shouldToggleHUDAfterLaunch])
    {
        [RootViewController setShouldToggleHUDAfterLaunch:NO];
        if (_isRemoteHUDActive)
        {
            [self mainSwitchToggled];
        }
        [[UIApplication sharedApplication] suspend];
    }
}

- (void)tapAuthorLabel:(UITapGestureRecognizer *)sender {
    if (_isRemoteHUDActive) {
        return;
    }
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://trollspeed.app"] options:@{} completionHandler:nil];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self reloadAllStatesAnimated:NO];
    } completion:nil];
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if (motion == UIEventSubtypeMotionShake)
    {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"开发者选项" message:@"请选择操作" preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [alertController addAction:[UIAlertAction actionWithTitle:@"重置所有设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self resetUserDefaults];
        }]];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)resetUserDefaults
{
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    if (bundleIdentifier) {
        [GetStandardUserDefaults() removePersistentDomainForName:bundleIdentifier];
        [GetStandardUserDefaults() synchronize];
    }

    if ([[NSFileManager defaultManager] removeItemAtPath:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH)) error:nil]) {
        [self setHUDEnabled:NO];
        [[UIApplication sharedApplication] terminateWithSuccess];
    }
}

#pragma mark - User Defaults

- (void)loadUserDefaults:(BOOL)forceReload
{
    if (forceReload || !_userDefaults)
    {
        _userDefaults = [[NSDictionary dictionaryWithContentsOfFile:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH))] mutableCopy] ?: [NSMutableDictionary dictionary];
    }
}

- (void)saveUserDefaults
{
    [_userDefaults writeToFile:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH)) atomically:YES];
    notify_post(NOTIFY_RELOAD_HUD);
}

- (BOOL)isLandscapeOrientation
{
    UIInterfaceOrientation orientation = self.view.window.windowScene.interfaceOrientation;
    if (orientation == UIInterfaceOrientationUnknown) {
        return CGRectGetWidth(self.view.bounds) > CGRectGetHeight(self.view.bounds);
    }
    return UIInterfaceOrientationIsLandscape(orientation);
}

- (HUDUserDefaultsKey)selectedModeKeyForCurrentOrientation
{
    return [self isLandscapeOrientation] ? HUDUserDefaultsKeySelectedModeLandscape : HUDUserDefaultsKeySelectedMode;
}

- (HUDPresetPosition)selectedModeForCurrentOrientation
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:[self selectedModeKeyForCurrentOrientation]];
    return mode != nil ? (HUDPresetPosition)[mode integerValue] : HUDPresetPositionTopCenter;
}

- (void)setSelectedModeForCurrentOrientation:(HUDPresetPosition)selectedMode
{
    [self loadUserDefaults:NO];

    if ([self isLandscapeOrientation])
    {
        [_userDefaults removeObjectForKey:HUDUserDefaultsKeyCurrentLandscapePositionY];
    }
    else
    {
        [_userDefaults removeObjectForKey:HUDUserDefaultsKeyCurrentPositionY];
    }

    [_userDefaults setObject:@(selectedMode) forKey:[self selectedModeKeyForCurrentOrientation]];
    [self saveUserDefaults];
}

- (BOOL)passthroughMode
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyPassthroughMode];
    return mode != nil ? [mode boolValue] : NO;
}

- (void)setPassthroughMode:(BOOL)passthroughMode
{
    [self loadUserDefaults:NO];
    [_userDefaults setObject:@(passthroughMode) forKey:HUDUserDefaultsKeyPassthroughMode];
    [self saveUserDefaults];
}

- (BOOL)singleLineMode
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeySingleLineMode];
    return mode != nil ? [mode boolValue] : NO;
}

- (void)setSingleLineMode:(BOOL)singleLineMode
{
    [self loadUserDefaults:NO];
    [_userDefaults setObject:@(singleLineMode) forKey:HUDUserDefaultsKeySingleLineMode];
    [self saveUserDefaults];
}

- (BOOL)usesBitrate
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesBitrate];
    return mode != nil ? [mode boolValue] : NO;
}

- (void)setUsesBitrate:(BOOL)usesBitrate
{
    [self loadUserDefaults:NO];
    [_userDefaults setObject:@(usesBitrate) forKey:HUDUserDefaultsKeyUsesBitrate];
    [self saveUserDefaults];
}

- (BOOL)usesArrowPrefixes
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesArrowPrefixes];
    return mode != nil ? [mode boolValue] : NO;
}

- (void)setUsesArrowPrefixes:(BOOL)usesArrowPrefixes
{
    [self loadUserDefaults:NO];
    [_userDefaults setObject:@(usesArrowPrefixes) forKey:HUDUserDefaultsKeyUsesArrowPrefixes];
    [self saveUserDefaults];
}

- (BOOL)usesLargeFont
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesLargeFont];
    return mode != nil ? [mode boolValue] : NO;
}

- (void)setUsesLargeFont:(BOOL)usesLargeFont
{
    [self loadUserDefaults:NO];
    [_userDefaults setObject:@(usesLargeFont) forKey:HUDUserDefaultsKeyUsesLargeFont];
    [self saveUserDefaults];
}

- (BOOL)usesRotation
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesRotation];
    return mode != nil ? [mode boolValue] : NO;
}

- (void)setUsesRotation:(BOOL)usesRotation
{
    [self loadUserDefaults:NO];
    [_userDefaults setObject:@(usesRotation) forKey:HUDUserDefaultsKeyUsesRotation];
    [self saveUserDefaults];
}

- (BOOL)usesInvertedColor
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesInvertedColor];
    return mode != nil ? [mode boolValue] : NO;
}

- (void)setUsesInvertedColor:(BOOL)usesInvertedColor
{
    [self loadUserDefaults:NO];
    [_userDefaults setObject:@(usesInvertedColor) forKey:HUDUserDefaultsKeyUsesInvertedColor];
    [self saveUserDefaults];
}

- (BOOL)keepInPlace
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyKeepInPlace];
    return mode != nil ? [mode boolValue] : NO;
}

- (void)setKeepInPlace:(BOOL)keepInPlace
{
    [self loadUserDefaults:NO];
    [_userDefaults setObject:@(keepInPlace) forKey:HUDUserDefaultsKeyKeepInPlace];
    [self saveUserDefaults];
}

- (BOOL)hideAtSnapshot
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyHideAtSnapshot];
    return mode != nil ? [mode boolValue] : NO;
}

- (void)setHideAtSnapshot:(BOOL)hideAtSnapshot
{
    [self loadUserDefaults:NO];
    [_userDefaults setObject:@(hideAtSnapshot) forKey:HUDUserDefaultsKeyHideAtSnapshot];
    [self saveUserDefaults];
}

- (BOOL)displayMode
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyDisplayMode];
    return mode != nil ? [mode boolValue] : NO;
}

- (void)setDisplayMode:(BOOL)displayMode
{
    [self loadUserDefaults:NO];
    [_userDefaults setObject:@(displayMode) forKey:HUDUserDefaultsKeyDisplayMode];
    [self saveUserDefaults];
}

- (BOOL)usesDualColor
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:@"HUD_USES_DUAL_COLOR"];
    return mode != nil ? [mode boolValue] : YES;
}

- (void)setUsesDualColor:(BOOL)usesDualColor
{
    [self loadUserDefaults:NO];
    [_userDefaults setObject:@(usesDualColor) forKey:@"HUD_USES_DUAL_COLOR"];
    [self saveUserDefaults];
}

@end