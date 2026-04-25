//
//  RootViewController.mm
//  TrollSpeed - Modern Premium UI Edition
//
//  打破九宫格，采用 iOS 15+ 现代原生分组列表 (Inset Grouped) 设计
//  注重呼吸感、色彩层级与专业交互逻辑。
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
#import "TrollSpeed-Swift.h"

#define HUD_TRANSITION_DURATION 0.25

// ==========================================
// 组件 1：顶部高级状态卡片 (Hero Dashboard)
// ==========================================
@interface TSHeroCard : UIControl
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *trafficLabel;
@property (nonatomic, assign) BOOL isOn;
- (void)setOn:(BOOL)on animated:(BOOL)animated;
@end

@implementation TSHeroCard
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.layer.cornerRadius = 24;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        
        UIView *contentContainer = [UIView new];
        contentContainer.translatesAutoresizingMaskIntoConstraints = NO;
        contentContainer.userInteractionEnabled = NO;
        [self addSubview:contentContainer];
        
        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [contentContainer addSubview:_iconView];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBlack];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [contentContainer addSubview:_titleLabel];
        
        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [contentContainer addSubview:_subtitleLabel];
        
        _trafficLabel = [[UILabel alloc] init];
        _trafficLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightBold];
        _trafficLabel.textColor = [UIColor systemGrayColor];
        _trafficLabel.text = @"📊 今日已用: 等待底层抓取...";
        _trafficLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_trafficLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [contentContainer.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:-10],
            [contentContainer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:24],
            [contentContainer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-24],
            [contentContainer.heightAnchor constraintEqualToConstant:60],
            
            [_iconView.leadingAnchor constraintEqualToAnchor:contentContainer.leadingAnchor],
            [_iconView.centerYAnchor constraintEqualToAnchor:contentContainer.centerYAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:48],
            [_iconView.heightAnchor constraintEqualToConstant:48],
            
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:16],
            [_titleLabel.topAnchor constraintEqualToAnchor:contentContainer.topAnchor constant:6],
            
            [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_subtitleLabel.bottomAnchor constraintEqualToAnchor:contentContainer.bottomAnchor constant:-6],
            
            [_trafficLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:24],
            [_trafficLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-20]
        ]];
        
        [self addTarget:self action:@selector(touchDown) forControlEvents:UIControlEventTouchDown];
        [self addTarget:self action:@selector(touchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    }
    return self;
}
- (void)touchDown { [UIView animateWithDuration:0.15 animations:^{ self.transform = CGAffineTransformMakeScale(0.96, 0.96); }]; }
- (void)touchUp { [UIView animateWithDuration:0.15 animations:^{ self.transform = CGAffineTransformIdentity; }]; }
- (void)setOn:(BOOL)on animated:(BOOL)animated {
    _isOn = on;
    void (^updateBlock)(void) = ^{
        if (on) {
            self.backgroundColor = [UIColor systemBlueColor];
            self.iconView.tintColor = [UIColor whiteColor];
            self.iconView.image = [UIImage systemImageNamed:@"speedometer"];
            self.titleLabel.textColor = [UIColor whiteColor];
            self.titleLabel.text = @"悬浮窗运行中";
            self.subtitleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
            self.subtitleLabel.text = @"轻触卡片关闭 · 可在屏幕任意拖动";
            self.trafficLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.9];
        } else {
            self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
            self.iconView.tintColor = [UIColor systemGrayColor];
            self.iconView.image = [UIImage systemImageNamed:@"speedometer"];
            self.titleLabel.textColor = [UIColor labelColor];
            self.titleLabel.text = @"服务已暂停";
            self.subtitleLabel.textColor = [UIColor secondaryLabelColor];
            self.subtitleLabel.text = @"轻触卡片启动引擎";
            self.trafficLabel.textColor = [UIColor systemGrayColor];
        }
    };
    if (animated) [UIView transitionWithView:self duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:updateBlock completion:nil];
    else updateBlock();
}
@end

// ==========================================
// 组件 2：现代分段选择器 (Segmented Position)
// ==========================================
@interface TSModernSegmentButton : UIControl
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, assign) BOOL isOn;
- (void)setOn:(BOOL)on animated:(BOOL)animated;
@end

@implementation TSModernSegmentButton
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.layer.cornerRadius = 10;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_titleLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [_titleLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_titleLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
        ]];
        
        [self addTarget:self action:@selector(touchDown) forControlEvents:UIControlEventTouchDown];
        [self addTarget:self action:@selector(touchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    }
    return self;
}
- (void)touchDown { [UIView animateWithDuration:0.1 animations:^{ self.transform = CGAffineTransformMakeScale(0.92, 0.92); }]; }
- (void)touchUp { [UIView animateWithDuration:0.1 animations:^{ self.transform = CGAffineTransformIdentity; }]; }
- (void)setOn:(BOOL)on animated:(BOOL)animated {
    _isOn = on;
    void (^updateBlock)(void) = ^{
        if (on) {
            self.backgroundColor = [UIColor systemBackgroundColor];
            self.titleLabel.textColor = [UIColor labelColor];
            self.layer.shadowColor = [UIColor blackColor].CGColor;
            self.layer.shadowOffset = CGSizeMake(0, 1);
            self.layer.shadowOpacity = 0.1;
            self.layer.shadowRadius = 2;
        } else {
            self.backgroundColor = [UIColor clearColor];
            self.titleLabel.textColor = [UIColor secondaryLabelColor];
            self.layer.shadowOpacity = 0;
        }
    };
    if (animated) [UIView transitionWithView:self duration:0.2 options:UIViewAnimationOptionTransitionCrossDissolve animations:updateBlock completion:nil];
    else updateBlock();
}
@end

// ==========================================
// 组件 3：原生风格系统列表行 (Settings Row)
// ==========================================
@interface TSSettingRowView : UIView
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UIView *iconContainer;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UISwitch *toggleSwitch;
@end

@implementation TSSettingRowView
- (instancetype)initWithIcon:(NSString *)iconName color:(UIColor *)color title:(NSString *)title {
    if (self = [super init]) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        
        _iconContainer = [UIView new];
        _iconContainer.backgroundColor = color;
        _iconContainer.layer.cornerRadius = 8;
        _iconContainer.layer.cornerCurve = kCACornerCurveContinuous;
        _iconContainer.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_iconContainer];
        
        _iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName]];
        _iconView.tintColor = [UIColor whiteColor];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [_iconContainer addSubview:_iconView];
        
        _titleLabel = [UILabel new];
        _titleLabel.text = title;
        _titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
        _titleLabel.textColor = [UIColor labelColor];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_titleLabel];
        
        _toggleSwitch = [UISwitch new];
        _toggleSwitch.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_toggleSwitch];
        
        [NSLayoutConstraint activateConstraints:@[
            [_iconContainer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
            [_iconContainer.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_iconContainer.widthAnchor constraintEqualToConstant:30],
            [_iconContainer.heightAnchor constraintEqualToConstant:30],
            
            [_iconView.centerXAnchor constraintEqualToAnchor:_iconContainer.centerXAnchor],
            [_iconView.centerYAnchor constraintEqualToAnchor:_iconContainer.centerYAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:20],
            [_iconView.heightAnchor constraintEqualToConstant:20],
            
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconContainer.trailingAnchor constant:16],
            [_titleLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            
            [_toggleSwitch.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
            [_toggleSwitch.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
        ]];
    }
    return self;
}
@end


// ==========================================
// RootViewController 主类实现
// ==========================================
@interface RootViewController ()
@property (nonatomic, strong) NSMutableDictionary *userDefaults;
@property (nonatomic, strong) TSHeroCard *mainCard;
@property (nonatomic, strong) NSArray<TSModernSegmentButton *> *posButtons;
@property (nonatomic, strong) NSArray<TSSettingRowView *> *settingRows;
@property (nonatomic, strong) UIImpactFeedbackGenerator *impactFeedbackGenerator;
@end

@implementation RootViewController

static BOOL _gShouldToggleHUDAfterLaunch = NO;

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
    NSString *savedDay = [self.userDefaults objectForKey:@"kDailyTrafficDate"];
    
    if ([today isEqualToString:savedDay]) {
        uint64_t total = [[self.userDefaults objectForKey:@"kDailyTrafficTotalBytes"] unsignedLongLongValue];
        NSString *totalStr = @"0 KB";
        if (total < (1ULL << 20)) totalStr = [NSString stringWithFormat:@"%.1f KB", (double)total / (1ULL << 10)];
        else if (total < (1ULL << 30)) totalStr = [NSString stringWithFormat:@"%.1f MB", (double)total / (1ULL << 20)];
        else totalStr = [NSString stringWithFormat:@"%.2f GB", (double)total / (1ULL << 30)];
        
        self.mainCard.trafficLabel.text = [NSString stringWithFormat:@"📊 今日已用: %@", totalStr];
    } else {
        self.mainCard.trafficLabel.text = @"📊 今日已用: 0.0 KB";
    }
}

- (TSSettingRowView *)createRowWithIcon:(NSString *)icon color:(UIColor *)color title:(NSString *)title tag:(NSInteger)tag isLast:(BOOL)isLast {
    TSSettingRowView *row = [[TSSettingRowView alloc] initWithIcon:icon color:color title:title];
    row.toggleSwitch.tag = tag;
    [row.toggleSwitch addTarget:self action:@selector(settingToggled:) forControlEvents:UIControlEventValueChanged];
    [row.heightAnchor constraintEqualToConstant:50].active = YES;
    
    if (!isLast) {
        UIView *separator = [UIView new];
        separator.backgroundColor = [UIColor separatorColor];
        separator.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:separator];
        [NSLayoutConstraint activateConstraints:@[
            [separator.leadingAnchor constraintEqualToAnchor:row.titleLabel.leadingAnchor],
            [separator.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
            [separator.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
            [separator.heightAnchor constraintEqualToConstant:1.0 / [UIScreen mainScreen].scale]
        ]];
    }
    return row;
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor]; // 原生灰色背景

    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scrollView.alwaysBounceVertical = YES;
    scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:scrollView];

    UIStackView *mainStack = [[UIStackView alloc] init];
    mainStack.axis = UILayoutConstraintAxisVertical;
    mainStack.spacing = 24;
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:mainStack];
    
    [NSLayoutConstraint activateConstraints:@[
        [mainStack.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor constant:20],
        [mainStack.leadingAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.leadingAnchor constant:20],
        [mainStack.trailingAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.trailingAnchor constant:-20],
        [mainStack.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor constant:-40]
    ]];

    // 1. 英雄大卡片
    self.mainCard = [[TSHeroCard alloc] init];
    [self.mainCard.heightAnchor constraintEqualToConstant:150].active = YES;
    [self.mainCard addTarget:self action:@selector(mainSwitchToggled) forControlEvents:UIControlEventTouchUpInside];
    [mainStack addArrangedSubview:self.mainCard];

    // 2. 位置段选择器
    UIView *segmentContainer = [UIView new];
    segmentContainer.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    segmentContainer.layer.cornerRadius = 14;
    segmentContainer.layer.cornerCurve = kCACornerCurveContinuous;
    [segmentContainer.heightAnchor constraintEqualToConstant:50].active = YES;
    [mainStack addArrangedSubview:segmentContainer];
    
    UIStackView *posStack = [[UIStackView alloc] init];
    posStack.axis = UILayoutConstraintAxisHorizontal;
    posStack.distribution = UIStackViewDistributionFillEqually;
    posStack.translatesAutoresizingMaskIntoConstraints = NO;
    [segmentContainer addSubview:posStack];
    [NSLayoutConstraint activateConstraints:@[
        [posStack.topAnchor constraintEqualToAnchor:segmentContainer.topAnchor constant:4],
        [posStack.bottomAnchor constraintEqualToAnchor:segmentContainer.bottomAnchor constant:-4],
        [posStack.leadingAnchor constraintEqualToAnchor:segmentContainer.leadingAnchor constant:4],
        [posStack.trailingAnchor constraintEqualToAnchor:segmentContainer.trailingAnchor constant:-4]
    ]];
    
    NSArray *posTitles = @[@"居左停靠", @"屏幕居中", @"居右停靠"];
    NSMutableArray *tempPosBtns = [NSMutableArray array];
    for (int i = 0; i < 3; i++) {
        TSModernSegmentButton *btn = [[TSModernSegmentButton alloc] init];
        btn.titleLabel.text = posTitles[i];
        btn.tag = i;
        [btn addTarget:self action:@selector(positionToggled:) forControlEvents:UIControlEventTouchUpInside];
        [posStack addArrangedSubview:btn];
        [tempPosBtns addObject:btn];
    }
    self.posButtons = tempPosBtns;

    NSMutableArray *allRows = [NSMutableArray array];

    // 3. 分组 1: 外观与显示 (Appearance)
    UILabel *header1 = [UILabel new];
    header1.text = @"外观与显示";
    header1.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    header1.textColor = [UIColor secondaryLabelColor];
    [mainStack addArrangedSubview:header1];
    [mainStack setCustomSpacing:8 afterView:header1];

    UIStackView *group1 = [[UIStackView alloc] init];
    group1.axis = UILayoutConstraintAxisVertical;
    group1.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    group1.layer.cornerRadius = 12;
    group1.layer.masksToBounds = YES;
    [mainStack addArrangedSubview:group1];

    TSSettingRowView *r1 = [self createRowWithIcon:@"speedometer" color:[UIColor systemIndigoColor] title:@"显示模式 (网速/帧率)" tag:109 isLast:NO];
    TSSettingRowView *r2 = [self createRowWithIcon:@"paintpalette.fill" color:[UIColor systemOrangeColor] title:@"双色引擎渲染" tag:110 isLast:NO];
    TSSettingRowView *r3 = [self createRowWithIcon:@"minus" color:[UIColor systemGreenColor] title:@"单行紧凑显示" tag:101 isLast:NO];
    TSSettingRowView *r4 = [self createRowWithIcon:@"textformat.size" color:[UIColor systemBlueColor] title:@"大字体模式" tag:104 isLast:NO];
    TSSettingRowView *r5 = [self createRowWithIcon:@"arrow.up.arrow.down" color:[UIColor systemGrayColor] title:@"经典箭头前缀" tag:103 isLast:NO];
    TSSettingRowView *r6 = [self createRowWithIcon:@"chart.bar.fill" color:[UIColor systemTealColor] title:@"数据单位 (KB/s)" tag:102 isLast:YES];
    
    [group1 addArrangedSubview:r1]; [group1 addArrangedSubview:r2]; [group1 addArrangedSubview:r3];
    [group1 addArrangedSubview:r4]; [group1 addArrangedSubview:r5]; [group1 addArrangedSubview:r6];
    [allRows addObjectsFromArray:@[r1, r2, r3, r4, r5, r6]];

    // 4. 分组 2: 行为与控制 (Behavior)
    UILabel *header2 = [UILabel new];
    header2.text = @"行为与控制";
    header2.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    header2.textColor = [UIColor secondaryLabelColor];
    [mainStack addArrangedSubview:header2];
    [mainStack setCustomSpacing:8 afterView:header2];

    UIStackView *group2 = [[UIStackView alloc] init];
    group2.axis = UILayoutConstraintAxisVertical;
    group2.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    group2.layer.cornerRadius = 12;
    group2.layer.masksToBounds = YES;
    [mainStack addArrangedSubview:group2];

    TSSettingRowView *r7 = [self createRowWithIcon:@"hand.tap.slash.fill" color:[UIColor systemPurpleColor] title:@"触摸事件穿透" tag:100 isLast:NO];
    TSSettingRowView *r8 = [self createRowWithIcon:@"crop.rotate" color:[UIColor systemYellowColor] title:@"跟随屏幕旋转" tag:105 isLast:NO];
    TSSettingRowView *r9 = [self createRowWithIcon:@"eye.slash.fill" color:[UIColor systemRedColor] title:@"系统截图隐藏" tag:108 isLast:NO];
    TSSettingRowView *r10 = [self createRowWithIcon:@"moon.circle.fill" color:[UIColor blackColor] title:@"反色模式" tag:106 isLast:NO];
    TSSettingRowView *r11 = [self createRowWithIcon:@"lock.fill" color:[UIColor systemPinkColor] title:@"锁定悬浮窗位置" tag:107 isLast:YES];

    [group2 addArrangedSubview:r7]; [group2 addArrangedSubview:r8]; [group2 addArrangedSubview:r9];
    [group2 addArrangedSubview:r10]; [group2 addArrangedSubview:r11];
    [allRows addObjectsFromArray:@[r7, r8, r9, r10, r11]];
    
    self.settingRows = allRows;

    // 5. 底部按钮区 (Reset)
    UIButton *resetBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [resetBtn setTitle:@"重置拖拽坐标" forState:UIControlStateNormal];
    resetBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [resetBtn setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
    resetBtn.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    resetBtn.layer.cornerRadius = 12;
    [resetBtn.heightAnchor constraintEqualToConstant:50].active = YES;
    [resetBtn addTarget:self action:@selector(resetPositionTapped) forControlEvents:UIControlEventTouchUpInside];
    [mainStack addArrangedSubview:resetBtn];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.impactFeedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [self registerNotifications];
    [self updateTrafficUI];
    [self reloadAllStatesAnimated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self toggleHUDAfterLaunch];
}

- (void)mainSwitchToggled {
    [self.impactFeedbackGenerator prepare];
    [self.impactFeedbackGenerator impactOccurred];
    BOOL isNowEnabled = [self isHUDEnabled];
    [self setHUDEnabled:!isNowEnabled];
    
    if (!isNowEnabled) {
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

- (void)positionToggled:(TSModernSegmentButton *)sender {
    [self.impactFeedbackGenerator prepare]; [self.impactFeedbackGenerator impactOccurred];
    HUDPresetPosition currentMode = [self selectedModeForCurrentOrientation];
    HUDPresetPosition newMode = currentMode;
    if (sender.tag == 0) newMode = HUDPresetPositionTopLeft;
    if (sender.tag == 2) newMode = HUDPresetPositionTopRight;
    if (sender.tag == 1) newMode = (currentMode == HUDPresetPositionTopCenterMost) ? HUDPresetPositionTopCenter : HUDPresetPositionTopCenterMost;
    
    [self loadUserDefaults:NO];
    [self.userDefaults setObject:@(NO) forKey:@"HUDUserDefaultsKeyUsesCustomOffset"];
    [self.userDefaults setObject:@(0) forKey:@"HUDUserDefaultsKeyRealCustomOffsetX"];
    [self.userDefaults setObject:@(0) forKey:@"HUDUserDefaultsKeyRealCustomOffsetY"];
    [self saveUserDefaults];
    
    [self setSelectedModeForCurrentOrientation:newMode];
    [self reloadAllStatesAnimated:YES];
}

- (void)resetPositionTapped {
    [self.impactFeedbackGenerator prepare]; [self.impactFeedbackGenerator impactOccurred];
    [self loadUserDefaults:NO];
    [self.userDefaults setObject:@(NO) forKey:@"HUDUserDefaultsKeyUsesCustomOffset"];
    [self.userDefaults setObject:@(0) forKey:@"HUDUserDefaultsKeyRealCustomOffsetX"];
    [self.userDefaults setObject:@(0) forKey:@"HUDUserDefaultsKeyRealCustomOffsetY"];
    [self saveUserDefaults];
    [self reloadAllStatesAnimated:YES];
}

- (void)settingToggled:(UISwitch *)sender {
    [self.impactFeedbackGenerator prepare]; [self.impactFeedbackGenerator impactOccurred];
    BOOL newState = sender.isOn;
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
}

- (void)reloadAllStatesAnimated:(BOOL)animated {
    BOOL isActive = [self isHUDEnabled];
    [self.mainCard setOn:isActive animated:animated];
    
    HUDPresetPosition mode = [self selectedModeForCurrentOrientation];
    [self.posButtons[0] setOn:(mode == HUDPresetPositionTopLeft) animated:animated];
    [self.posButtons[2] setOn:(mode == HUDPresetPositionTopRight) animated:animated];
    BOOL isCenter = (mode == HUDPresetPositionTopCenter || mode == HUDPresetPositionTopCenterMost);
    [self.posButtons[1] setOn:isCenter animated:animated];

    for (TSSettingRowView *row in self.settingRows) {
        BOOL isOn = NO;
        switch (row.toggleSwitch.tag) {
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
        [row.toggleSwitch setOn:isOn animated:animated];
    }
}

// ==========================================
// 遗留 Protocol 实现 (完全防御编译报错)
// ==========================================
- (NSInteger)numberOfSectionsInTableView:(id)tableView { return 0; }
- (NSInteger)tableView:(id)tableView numberOfRowsInSection:(NSInteger)section { return 0; }
- (id)tableView:(id)tableView titleForHeaderInSection:(NSInteger)section { return nil; }
- (id)tableView:(id)tableView cellForRowAtIndexPath:(id)indexPath { return nil; }
- (void)tableView:(id)tableView didSelectRowAtIndexPath:(id)indexPath {}
- (void)reloadModeButtonState { [self reloadAllStatesAnimated:YES]; }
- (void)presentTopCenterMostHints {}
- (void)verticalSizeClassUpdated {}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {}
- (void)reloadMainButtonState { [self reloadAllStatesAnimated:YES]; }
- (BOOL)settingHighlightedWithKey:(NSString *)key { [self loadUserDefaults:NO]; NSNumber *mode = [self.userDefaults objectForKey:key]; return mode != nil ? [mode boolValue] : NO; }
- (void)settingDidSelectWithKey:(NSString *)key { BOOL highlighted = [self settingHighlightedWithKey:key]; [self.userDefaults setObject:@(!highlighted) forKey:key]; [self saveUserDefaults]; [self reloadAllStatesAnimated:YES]; }
- (void)toggleHUDNotificationReceived:(NSNotification *)notification { NSString *toggleAction = notification.userInfo[kToggleHUDAfterLaunchNotificationActionKey]; if (!toggleAction) [self toggleHUDAfterLaunch]; else if ([toggleAction isEqualToString:kToggleHUDAfterLaunchNotificationActionToggleOn]) [self toggleOnHUDAfterLaunch]; else if ([toggleAction isEqualToString:kToggleHUDAfterLaunchNotificationActionToggleOff]) [self toggleOffHUDAfterLaunch]; }
- (void)toggleHUDAfterLaunch { if ([RootViewController shouldToggleHUDAfterLaunch]) { [RootViewController setShouldToggleHUDAfterLaunch:NO]; if (![self isHUDEnabled]) [self mainSwitchToggled]; [[UIApplication sharedApplication] suspend]; } }
- (void)toggleOnHUDAfterLaunch { if ([RootViewController shouldToggleHUDAfterLaunch]) { [RootViewController setShouldToggleHUDAfterLaunch:NO]; if (![self isHUDEnabled]) [self mainSwitchToggled]; [[UIApplication sharedApplication] suspend]; } }
- (void)toggleOffHUDAfterLaunch { if ([RootViewController shouldToggleHUDAfterLaunch]) { [RootViewController setShouldToggleHUDAfterLaunch:NO]; if ([self isHUDEnabled]) [self mainSwitchToggled]; [[UIApplication sharedApplication] suspend]; } }
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator { [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator]; [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) { [self reloadAllStatesAnimated:NO]; } completion:nil]; }
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {}

- (void)loadUserDefaults:(BOOL)forceReload { if (forceReload || !self.userDefaults) { self.userDefaults = [[NSDictionary dictionaryWithContentsOfFile:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH))] mutableCopy] ?: [NSMutableDictionary dictionary]; } }
- (void)saveUserDefaults { [self.userDefaults writeToFile:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH)) atomically:YES]; notify_post(NOTIFY_RELOAD_HUD); }
- (BOOL)isLandscapeOrientation { UIInterfaceOrientation orientation = self.view.window.windowScene.interfaceOrientation; if (orientation == UIInterfaceOrientationUnknown) { return CGRectGetWidth(self.view.bounds) > CGRectGetHeight(self.view.bounds); } return UIInterfaceOrientationIsLandscape(orientation); }
- (HUDUserDefaultsKey)selectedModeKeyForCurrentOrientation { return [self isLandscapeOrientation] ? HUDUserDefaultsKeySelectedModeLandscape : HUDUserDefaultsKeySelectedMode; }
- (HUDPresetPosition)selectedModeForCurrentOrientation { [self loadUserDefaults:NO]; NSNumber *mode = [self.userDefaults objectForKey:[self selectedModeKeyForCurrentOrientation]]; return mode != nil ? (HUDPresetPosition)[mode integerValue] : HUDPresetPositionTopCenter; }
- (void)setSelectedModeForCurrentOrientation:(HUDPresetPosition)selectedMode { [self loadUserDefaults:NO]; if ([self isLandscapeOrientation]) { [self.userDefaults removeObjectForKey:HUDUserDefaultsKeyCurrentLandscapePositionY]; } else { [self.userDefaults removeObjectForKey:HUDUserDefaultsKeyCurrentPositionY]; } [self.userDefaults setObject:@(selectedMode) forKey:[self selectedModeKeyForCurrentOrientation]]; [self saveUserDefaults]; }

- (BOOL)passthroughMode { [self loadUserDefaults:NO]; NSNumber *m = [self.userDefaults objectForKey:HUDUserDefaultsKeyPassthroughMode]; return m != nil ? [m boolValue] : NO; }
- (void)setPassthroughMode:(BOOL)p { [self loadUserDefaults:NO]; [self.userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyPassthroughMode]; [self saveUserDefaults]; }
- (BOOL)singleLineMode { [self loadUserDefaults:NO]; NSNumber *m = [self.userDefaults objectForKey:HUDUserDefaultsKeySingleLineMode]; return m != nil ? [m boolValue] : NO; }
- (void)setSingleLineMode:(BOOL)p { [self loadUserDefaults:NO]; [self.userDefaults setObject:@(p) forKey:HUDUserDefaultsKeySingleLineMode]; [self saveUserDefaults]; }
- (BOOL)usesBitrate { [self loadUserDefaults:NO]; NSNumber *m = [self.userDefaults objectForKey:HUDUserDefaultsKeyUsesBitrate]; return m != nil ? [m boolValue] : NO; }
- (void)setUsesBitrate:(BOOL)p { [self loadUserDefaults:NO]; [self.userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyUsesBitrate]; [self saveUserDefaults]; }
- (BOOL)usesArrowPrefixes { [self loadUserDefaults:NO]; NSNumber *m = [self.userDefaults objectForKey:HUDUserDefaultsKeyUsesArrowPrefixes]; return m != nil ? [m boolValue] : NO; }
- (void)setUsesArrowPrefixes:(BOOL)p { [self loadUserDefaults:NO]; [self.userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyUsesArrowPrefixes]; [self saveUserDefaults]; }
- (BOOL)usesLargeFont { [self loadUserDefaults:NO]; NSNumber *m = [self.userDefaults objectForKey:HUDUserDefaultsKeyUsesLargeFont]; return m != nil ? [m boolValue] : NO; }
- (void)setUsesLargeFont:(BOOL)p { [self loadUserDefaults:NO]; [self.userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyUsesLargeFont]; [self saveUserDefaults]; }
- (BOOL)usesRotation { [self loadUserDefaults:NO]; NSNumber *m = [self.userDefaults objectForKey:HUDUserDefaultsKeyUsesRotation]; return m != nil ? [m boolValue] : NO; }
- (void)setUsesRotation:(BOOL)p { [self loadUserDefaults:NO]; [self.userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyUsesRotation]; [self saveUserDefaults]; }
- (BOOL)usesInvertedColor { [self loadUserDefaults:NO]; NSNumber *m = [self.userDefaults objectForKey:HUDUserDefaultsKeyUsesInvertedColor]; return m != nil ? [m boolValue] : NO; }
- (void)setUsesInvertedColor:(BOOL)p { [self loadUserDefaults:NO]; [self.userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyUsesInvertedColor]; [self saveUserDefaults]; }
- (BOOL)keepInPlace { [self loadUserDefaults:NO]; NSNumber *m = [self.userDefaults objectForKey:HUDUserDefaultsKeyKeepInPlace]; return m != nil ? [m boolValue] : NO; }
- (void)setKeepInPlace:(BOOL)p { [self loadUserDefaults:NO]; [self.userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyKeepInPlace]; [self saveUserDefaults]; }
- (BOOL)hideAtSnapshot { [self loadUserDefaults:NO]; NSNumber *m = [self.userDefaults objectForKey:HUDUserDefaultsKeyHideAtSnapshot]; return m != nil ? [m boolValue] : NO; }
- (void)setHideAtSnapshot:(BOOL)p { [self loadUserDefaults:NO]; [self.userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyHideAtSnapshot]; [self saveUserDefaults]; }
- (BOOL)displayMode { [self loadUserDefaults:NO]; NSNumber *m = [self.userDefaults objectForKey:HUDUserDefaultsKeyDisplayMode]; return m != nil ? [m boolValue] : NO; }
- (void)setDisplayMode:(BOOL)p { [self loadUserDefaults:NO]; [self.userDefaults setObject:@(p) forKey:HUDUserDefaultsKeyDisplayMode]; [self saveUserDefaults]; }
- (BOOL)usesDualColor { [self loadUserDefaults:NO]; NSNumber *m = [self.userDefaults objectForKey:@"HUD_USES_DUAL_COLOR"]; return m != nil ? [m boolValue] : YES; }
- (void)setUsesDualColor:(BOOL)p { [self loadUserDefaults:NO]; [self.userDefaults setObject:@(p) forKey:@"HUD_USES_DUAL_COLOR"]; [self saveUserDefaults]; }

- (CGFloat)currentPositionY { [self loadUserDefaults:NO]; NSNumber *positionY = [self.userDefaults objectForKey:HUDUserDefaultsKeyCurrentPositionY]; return positionY != nil ? [positionY doubleValue] : CGFLOAT_MAX; }
- (void)setCurrentPositionY:(CGFloat)positionY { [self loadUserDefaults:NO]; [self.userDefaults setObject:[NSNumber numberWithDouble:positionY] forKey:HUDUserDefaultsKeyCurrentPositionY]; [self saveUserDefaults]; }
- (CGFloat)currentLandscapePositionY { [self loadUserDefaults:NO]; NSNumber *positionY = [self.userDefaults objectForKey:HUDUserDefaultsKeyCurrentLandscapePositionY]; return positionY != nil ? [positionY doubleValue] : CGFLOAT_MAX; }
- (void)setCurrentLandscapePositionY:(CGFloat)positionY { [self loadUserDefaults:NO]; [self.userDefaults setObject:[NSNumber numberWithDouble:positionY] forKey:HUDUserDefaultsKeyCurrentLandscapePositionY]; [self saveUserDefaults]; }

#define PREFS_PATH "/var/mobile/Library/Preferences/ch.xxtou.hudapp.prefs.plist"
- (NSDictionary *)extraUserDefaultsDictionary { static BOOL isJailbroken = NO; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ isJailbroken = [[NSFileManager defaultManager] fileExistsAtPath:JBROOT_PATH_NSSTRING(@"/Library/PreferenceBundles/TrollSpeedPrefs.bundle")]; }); if (!isJailbroken) { return nil; } return [NSDictionary dictionaryWithContentsOfFile:JBROOT_PATH_NSSTRING(@PREFS_PATH)]; }

- (BOOL)usesCustomFontSize { NSDictionary *extraUserDefaults = [self extraUserDefaultsDictionary]; if (extraUserDefaults) { return [extraUserDefaults[HUDUserDefaultsKeyUsesCustomFontSize] boolValue]; } return [GetStandardUserDefaults() boolForKey:HUDUserDefaultsKeyUsesCustomFontSize]; }
- (CGFloat)realCustomFontSize { NSDictionary *extraUserDefaults = [self extraUserDefaultsDictionary]; if (extraUserDefaults) { return [extraUserDefaults[HUDUserDefaultsKeyRealCustomFontSize] doubleValue]; } return [GetStandardUserDefaults() doubleForKey:HUDUserDefaultsKeyRealCustomFontSize]; }
- (BOOL)usesCustomOffset { NSDictionary *extraUserDefaults = [self extraUserDefaultsDictionary]; if (extraUserDefaults) { return [extraUserDefaults[HUDUserDefaultsKeyUsesCustomOffset] boolValue]; } return [GetStandardUserDefaults() boolForKey:HUDUserDefaultsKeyUsesCustomOffset]; }
- (CGFloat)realCustomOffsetX { NSDictionary *extraUserDefaults = [self extraUserDefaultsDictionary]; if (extraUserDefaults) { return [extraUserDefaults[HUDUserDefaultsKeyRealCustomOffsetX] doubleValue]; } return [GetStandardUserDefaults() doubleForKey:HUDUserDefaultsKeyRealCustomOffsetX]; }
- (CGFloat)realCustomOffsetY { NSDictionary *extraUserDefaults = [self extraUserDefaultsDictionary]; if (extraUserDefaults) { return [extraUserDefaults[HUDUserDefaultsKeyRealCustomOffsetY] doubleValue]; } return [GetStandardUserDefaults() doubleForKey:HUDUserDefaultsKeyRealCustomOffsetY]; }

@end