//
//  RootViewController.mm
//  TrollSpeed - Extreme Edition (Final Implementation)
//
//  设计风格：现代极简、磁贴化、固定单页（无滚动）
//  功能点：流量统计展示、X/Y 坐标微调、双色渲染支持、修复系统手势拦截
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

// ==========================================
// 组件 1：现代磁贴按钮 (TSTileButton)
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

// ==========================================
// 组件 2：偏移调节卡片 (TSOffsetCard)
// ==========================================
@interface TSOffsetCard : UIView
@property (nonatomic, strong) UISlider *xSlider;
@property (nonatomic, strong) UISlider *ySlider;
@end

@implementation TSOffsetCard
- (instancetype)init {
    if (self = [super init]) {
        self.layer.cornerRadius = 20;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.backgroundColor = [UIColor secondarySystemFillColor];
        
        UILabel *xL = [UILabel new]; xL.text = @"横向 X"; xL.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold]; xL.textColor = [UIColor secondaryLabelColor]; xL.translatesAutoresizingMaskIntoConstraints = NO;
        _xSlider = [UISlider new]; _xSlider.minimumValue = -150; _xSlider.maximumValue = 150; _xSlider.translatesAutoresizingMaskIntoConstraints = NO;
        
        UILabel *yL = [UILabel new]; yL.text = @"纵向 Y"; yL.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold]; yL.textColor = [UIColor secondaryLabelColor]; yL.translatesAutoresizingMaskIntoConstraints = NO;
        _ySlider = [UISlider new]; _ySlider.minimumValue = -100; _ySlider.maximumValue = 200; _ySlider.translatesAutoresizingMaskIntoConstraints = NO;
        
        [self addSubview:xL]; [self addSubview:_xSlider]; [self addSubview:yL]; [self addSubview:_ySlider];
        
        [NSLayoutConstraint activateConstraints:@[
            [xL.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
            [xL.topAnchor constraintEqualToAnchor:self.topAnchor constant:16],
            [xL.widthAnchor constraintEqualToConstant:40],
            [_xSlider.leadingAnchor constraintEqualToAnchor:xL.trailingAnchor constant:10],
            [_xSlider.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
            [_xSlider.centerYAnchor constraintEqualToAnchor:xL.centerYAnchor],
            
            [yL.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
            [yL.topAnchor constraintEqualToAnchor:xL.bottomAnchor constant:20],
            [yL.widthAnchor constraintEqualToConstant:40],
            [_ySlider.leadingAnchor constraintEqualToAnchor:yL.trailingAnchor constant:10],
            [_ySlider.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
            [_ySlider.centerYAnchor constraintEqualToAnchor:yL.centerYAnchor],
        ]];
    }
    return self;
}
@end

// ==========================================
// 组件 3：主状态大卡片 (TSMainCard)
// ==========================================
@interface TSMainCard : UIControl
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *trafficLabel;
@property (nonatomic, assign) BOOL isOn;
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
        _trafficLabel.text = @"📊 今日已用: 0.00 KB";
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
- (void)setOn:(BOOL)on {
    _isOn = on;
    [UIView transitionWithView:self duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        if (on) {
            self.backgroundColor = [UIColor systemGreenColor];
            self.iconView.image = [UIImage systemImageNamed:@"speedometer"];
            self.iconView.tintColor = [UIColor whiteColor];
            self.titleLabel.text = @"监控运行中";
            self.titleLabel.textColor = [UIColor whiteColor];
            self.subtitleLabel.text = @"底层服务已注入，可退至桌面";
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
    } completion:nil];
}
@end

// ==========================================
// RootViewController 主类实现
// ==========================================
static BOOL _gShouldToggleHUDAfterLaunch = NO;

@implementation RootViewController {
    NSMutableDictionary *_userDefaults;
    BOOL _isRemoteHUDActive;
    
    TSMainCard *_mainCard;
    TSOffsetCard *_offsetCard;
    NSArray<TSTileButton *> *_posButtons;
    NSArray<TSTileButton *> *_settingButtons;
    UIImpactFeedbackGenerator *_impactFeedbackGenerator;
}

+ (void)setShouldToggleHUDAfterLaunch:(BOOL)flag { _gShouldToggleHUDAfterLaunch = flag; }
+ (BOOL)shouldToggleHUDAfterLaunch { return _gShouldToggleHUDAfterLaunch; }
- (BOOL)isHUDEnabled { return IsHUDEnabled(); }
- (void)setHUDEnabled:(BOOL)enabled { SetHUDEnabled(enabled); }

// 解决无法下拉菜单的核心逻辑
- (BOOL)prefersStatusBarHidden { return NO; }
- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures { return UIRectEdgeNone; }

- (void)registerNotifications {
    int token;
    notify_register_dispatch(NOTIFY_RELOAD_APP, &token, dispatch_get_main_queue(), ^(int token) { [self loadUserDefaults:YES]; [self reloadAllStatesAnimated:YES]; });
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(toggleHUDNotificationReceived:) name:kToggleHUDAfterLaunchNotificationName object:nil];
    
    // 监听流量更新通知
    [[NSNotificationCenter defaultCenter] addObserverForName:@"TrollSpeedUpdateTrafficUI" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        NSString *totalStr = note.userInfo[@"total"];
        self->_mainCard.trafficLabel.text = [NSString stringWithFormat:@"📊 今日已用: %@", totalStr];
    }];
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    UIStackView *mainStack = [[UIStackView alloc] init];
    mainStack.axis = UILayoutConstraintAxisVertical;
    mainStack.spacing = 15;
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:mainStack];
    
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [mainStack.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:10],
        [mainStack.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:24],
        [mainStack.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-24]
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

    _offsetCard = [[TSOffsetCard alloc] init];
    [_offsetCard.heightAnchor constraintEqualToConstant:90].active = YES;
    [_offsetCard.xSlider addTarget:self action:@selector(sliderMoved:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [_offsetCard.ySlider addTarget:self action:@selector(sliderMoved:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [mainStack addArrangedSubview:_offsetCard];

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
            if (btn.tag == 111) { btn.iconView.tintColor = [UIColor systemRedColor]; btn.titleLabel.textColor = [UIColor systemRedColor]; }
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
    [self reloadAllStatesAnimated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self toggleHUDAfterLaunch];
}

- (void)mainSwitchToggled {
    [_impactFeedbackGenerator prepare]; [_impactFeedbackGenerator impactOccurred];
    BOOL now = [self isHUDEnabled];
    [self setHUDEnabled:!now];
    if (!now) {
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        int tok;
        notify_register_dispatch(NOTIFY_LAUNCHED_HUD, &tok, dispatch_get_main_queue(), ^(int t) { notify_cancel(t); dispatch_semaphore_signal(sem); });
        self.view.userInteractionEnabled = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)));
            dispatch_async(dispatch_get_main_queue(), ^{ [self reloadAllStatesAnimated:YES]; self.view.userInteractionEnabled = YES; });
        });
    } else {
        self.view.userInteractionEnabled = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self reloadAllStatesAnimated:YES]; self.view.userInteractionEnabled = YES; });
    }
}

- (void)positionToggled:(TSTileButton *)sender {
    [_impactFeedbackGenerator prepare]; [_impactFeedbackGenerator impactOccurred];
    HUDPresetPosition cur = [self selectedModeForCurrentOrientation];
    HUDPresetPosition next = cur;
    if (sender.tag == 0) next = HUDPresetPositionTopLeft;
    if (sender.tag == 2) next = HUDPresetPositionTopRight;
    if (sender.tag == 1) next = (cur == HUDPresetPositionTopCenterMost) ? HUDPresetPositionTopCenter : HUDPresetPositionTopCenterMost;
    [self setSelectedModeForCurrentOrientation:next];
    [self reloadAllStatesAnimated:YES];
}

- (void)sliderMoved:(UISlider *)sender {
    [_impactFeedbackGenerator prepare]; [_impactFeedbackGenerator impactOccurred];
    [self loadUserDefaults:NO];
    [_userDefaults setObject:@YES forKey:HUDUserDefaultsKeyUsesCustomOffset];
    [_userDefaults setObject:@(_offsetCard.xSlider.value) forKey:HUDUserDefaultsKeyRealCustomOffsetX];
    [_userDefaults setObject:@(_offsetCard.ySlider.value) forKey:HUDUserDefaultsKeyRealCustomOffsetY];
    [self saveUserDefaults];
}

- (void)settingToggled:(TSTileButton *)sender {
    [_impactFeedbackGenerator prepare]; [_impactFeedbackGenerator impactOccurred];
    if (sender.tag == 111) {
        [self loadUserDefaults:NO];
        [_userDefaults setObject:@NO forKey:HUDUserDefaultsKeyUsesCustomOffset];
        [_userDefaults setObject:@0 forKey:HUDUserDefaultsKeyRealCustomOffsetX];
        [_userDefaults setObject:@0 forKey:HUDUserDefaultsKeyRealCustomOffsetY];
        [self saveUserDefaults]; [self reloadAllStatesAnimated:YES]; return;
    }
    BOOL next = !sender.isOn;
    switch (sender.tag) {
        case 100: [self setPassthroughMode:next]; break;
        case 101: [self setSingleLineMode:next]; break;
        case 102: [self setUsesBitrate:next]; break;
        case 103: [self setUsesArrowPrefixes:next]; break;
        case 104: [self setUsesLargeFont:next]; break;
        case 105: [self setUsesRotation:next]; break;
        case 106: [self setUsesInvertedColor:next]; break;
        case 107: [self setKeepInPlace:next]; break;
        case 108: [self setHideAtSnapshot:next]; break;
        case 109: [self setDisplayMode:next]; break;
        case 110: [self setUsesDualColor:next]; break;
    }
    [self reloadAllStatesAnimated:YES];
}

- (void)reloadAllStatesAnimated:(BOOL)animated {
    _isRemoteHUDActive = [self isHUDEnabled];
    [_mainCard setOn:_isRemoteHUDActive];
    HUDPresetPosition mode = [self selectedModeForCurrentOrientation];
    [_posButtons[0] setOn:(mode == HUDPresetPositionTopLeft) animated:animated];
    [_posButtons[2] setOn:(mode == HUDPresetPositionTopRight) animated:animated];
    BOOL center = (mode == HUDPresetPositionTopCenter || mode == HUDPresetPositionTopCenterMost);
    [_posButtons[1] setOn:center animated:animated];
    _posButtons[1].iconView.image = [UIImage systemImageNamed:(mode == HUDPresetPositionTopCenterMost ? @"capsule.inset.filled" : @"capsule.portrait")];
    _offsetCard.xSlider.value = [self usesCustomOffset] ? [self realCustomOffsetX] : 0;
    _offsetCard.ySlider.value = [self usesCustomOffset] ? [self realCustomOffsetY] : 0;
    for (TSTileButton *b in _settingButtons) {
        if (b.tag == 111) continue;
        BOOL on = NO;
        switch (b.tag) {
            case 100: on = [self passthroughMode]; break;
            case 101: on = [self singleLineMode]; break;
            case 102: on = [self usesBitrate]; break;
            case 103: on = [self usesArrowPrefixes]; break;
            case 104: on = [self usesLargeFont]; break;
            case 105: on = [self usesRotation]; break;
            case 106: on = [self usesInvertedColor]; break;
            case 107: on = [self keepInPlace]; break;
            case 108: on = [self hideAtSnapshot]; break;
            case 109: on = [self displayMode]; break;
            case 110: on = [self usesDualColor]; break;
        }
        [b setOn:on animated:animated];
    }
}

// 补全必要的底层方法和协议
- (void)reloadMainButtonState { [self reloadAllStatesAnimated:YES]; }
- (BOOL)settingHighlightedWithKey:(NSString *)key { [self loadUserDefaults:NO]; return [[_userDefaults objectForKey:key] boolValue]; }
- (void)settingDidSelectWithKey:(NSString *)key { BOOL h = [self settingHighlightedWithKey:key]; [_userDefaults setObject:@(!h) forKey:key]; [self saveUserDefaults]; [self reloadAllStatesAnimated:YES]; }
- (void)toggleHUDNotificationReceived:(NSNotification *)note { [self toggleHUDAfterLaunch]; }
- (void)toggleHUDAfterLaunch { if ([RootViewController shouldToggleHUDAfterLaunch]) { [RootViewController setShouldToggleHUDAfterLaunch:NO]; [self mainSwitchToggled]; [[UIApplication sharedApplication] suspend]; } }
- (void)loadUserDefaults:(BOOL)f { if (f || !_userDefaults) _userDefaults = [[NSDictionary dictionaryWithContentsOfFile:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH))] mutableCopy] ?: [NSMutableDictionary dictionary]; }
- (void)saveUserDefaults { [_userDefaults writeToFile:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH)) atomically:YES]; notify_post(NOTIFY_RELOAD_HUD); }
- (HUDPresetPosition)selectedModeForCurrentOrientation { [self loadUserDefaults:NO]; NSNumber *m = [_userDefaults objectForKey:[self selectedModeKeyForCurrentOrientation]]; return m ? (HUDPresetPosition)[m integerValue] : HUDPresetPositionTopCenter; }
- (HUDUserDefaultsKey)selectedModeKeyForCurrentOrientation { UIInterfaceOrientation o = self.view.window.windowScene.interfaceOrientation; return UIInterfaceOrientationIsLandscape(o) ? HUDUserDefaultsKeySelectedModeLandscape : HUDUserDefaultsKeySelectedMode; }
- (void)setSelectedModeForCurrentOrientation:(HUDPresetPosition)m { [self loadUserDefaults:NO]; [_userDefaults setObject:@(m) forKey:[self selectedModeKeyForCurrentOrientation]]; [self saveUserDefaults]; }
- (BOOL)passthroughMode { [self loadUserDefaults:NO]; return [_userDefaults[HUDUserDefaultsKeyPassthroughMode] boolValue]; }
- (void)setPassthroughMode:(BOOL)p { [self loadUserDefaults:NO]; [_userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyPassthroughMode]; [self saveUserDefaults]; }
- (BOOL)singleLineMode { [self loadUserDefaults:NO]; return [_userDefaults[HUDUserDefaultsKeySingleLineMode] boolValue]; }
- (void)setSingleLineMode:(BOOL)p { [self loadUserDefaults:NO]; [_userDefaults setObject:@(p) forKey:HUDUserDefaultsKeySingleLineMode]; [self saveUserDefaults]; }
- (BOOL)usesBitrate { [self loadUserDefaults:NO]; return [_userDefaults[HUDUserDefaultsKeyUsesBitrate] boolValue]; }
- (void)setUsesBitrate:(BOOL)p { [self loadUserDefaults:NO]; [_userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyUsesBitrate]; [self saveUserDefaults]; }
- (BOOL)usesArrowPrefixes { [self loadUserDefaults:NO]; return [_userDefaults[HUDUserDefaultsKeyUsesArrowPrefixes] boolValue]; }
- (void)setUsesArrowPrefixes:(BOOL)p { [self loadUserDefaults:NO]; [_userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyUsesArrowPrefixes]; [self saveUserDefaults]; }
- (BOOL)usesLargeFont { [self loadUserDefaults:NO]; return [_userDefaults[HUDUserDefaultsKeyUsesLargeFont] boolValue]; }
- (void)setUsesLargeFont:(BOOL)p { [self loadUserDefaults:NO]; [_userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyUsesLargeFont]; [self saveUserDefaults]; }
- (BOOL)usesRotation { [self loadUserDefaults:NO]; return [_userDefaults[HUDUserDefaultsKeyUsesRotation] boolValue]; }
- (void)setUsesRotation:(BOOL)p { [self loadUserDefaults:NO]; [_userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyUsesRotation]; [self saveUserDefaults]; }
- (BOOL)usesInvertedColor { [self loadUserDefaults:NO]; return [_userDefaults[HUDUserDefaultsKeyUsesInvertedColor] boolValue]; }
- (void)setUsesInvertedColor:(BOOL)p { [self loadUserDefaults:NO]; [_userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyUsesInvertedColor]; [self saveUserDefaults]; }
- (BOOL)keepInPlace { [self loadUserDefaults:NO]; return [_userDefaults[HUDUserDefaultsKeyKeepInPlace] boolValue]; }
- (void)setKeepInPlace:(BOOL)p { [self loadUserDefaults:NO]; [_userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyKeepInPlace]; [self saveUserDefaults]; }
- (BOOL)hideAtSnapshot { [self loadUserDefaults:NO]; return [_userDefaults[HUDUserDefaultsKeyHideAtSnapshot] boolValue]; }
- (void)setHideAtSnapshot:(BOOL)p { [self loadUserDefaults:NO]; [_userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyHideAtSnapshot]; [self saveUserDefaults]; }
- (BOOL)displayMode { [self loadUserDefaults:NO]; return [_userDefaults[HUDUserDefaultsKeyDisplayMode] boolValue]; }
- (void)setDisplayMode:(BOOL)p { [self loadUserDefaults:NO]; [_userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyDisplayMode]; [self saveUserDefaults]; }
- (BOOL)usesDualColor { [self loadUserDefaults:NO]; NSNumber *m = [_userDefaults objectForKey:@"HUD_USES_DUAL_COLOR"]; return m ? [m boolValue] : YES; }
- (void)setUsesDualColor:(BOOL)p { [self loadUserDefaults:NO]; [_userDefaults setObject:@(p) forKey:@"HUD_USES_DUAL_COLOR"]; [self saveUserDefaults]; }
- (BOOL)usesCustomOffset { return [[NSUserDefaults standardUserDefaults] boolForKey:HUDUserDefaultsKeyUsesCustomOffset]; }
- (CGFloat)realCustomOffsetX { return [[NSUserDefaults standardUserDefaults] doubleForKey:HUDUserDefaultsKeyRealCustomOffsetX]; }
- (CGFloat)realCustomOffsetY { return [[NSUserDefaults standardUserDefaults] doubleForKey:HUDUserDefaultsKeyRealCustomOffsetY]; }
- (void)tapAuthorLabel:(UITapGestureRecognizer *)s { if (_isRemoteHUDActive) return; [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://trollspeed.app"] options:@{} completionHandler:nil]; }
@end