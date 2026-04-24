//
//  RootViewController.mm
//  TrollSpeed
//
//  Refactored with Pure Native Inset Grouped UI (Fixed Crash & Localization)
//

#import <notify.h>

#import "HUDHelper.h"
#import "MainButton.h"
#import "MainApplication.h"
#import "HUDPresetPosition.h"
#import "RootViewController.h"
#import "UIApplication+Private.h"
#import "HUDRootViewController.h"

#define HUD_TRANSITION_DURATION 0.25

static BOOL _gShouldToggleHUDAfterLaunch = NO;

// 添加 UITableView 协议
@interface RootViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation RootViewController {
    NSMutableDictionary *_userDefaults;
    UILabel *_authorLabel;
    BOOL _supportsCenterMost;
    BOOL _isRemoteHUDActive;
    HUDRootViewController *_localHUDRootViewController;  // Only for debugging
    UIImpactFeedbackGenerator *_impactFeedbackGenerator;
    UISwitch *_mainSwitch; // 核心开关原生控件
}

+ (void)setShouldToggleHUDAfterLaunch:(BOOL)flag
{
    _gShouldToggleHUDAfterLaunch = flag;
}

+ (BOOL)shouldToggleHUDAfterLaunch
{
    return _gShouldToggleHUDAfterLaunch;
}

- (BOOL)isHUDEnabled
{
    return IsHUDEnabled();
}

- (void)setHUDEnabled:(BOOL)enabled
{
    SetHUDEnabled(enabled);
}

- (void)registerNotifications
{
    int token;
    notify_register_dispatch(NOTIFY_RELOAD_APP, &token, dispatch_get_main_queue(), ^(int token) {
        [self loadUserDefaults:YES];
    });

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(toggleHUDNotificationReceived:) name:kToggleHUDAfterLaunchNotificationName object:nil];
}

// ==========================================
// 原生质感 UI 初始化
// ==========================================
- (void)loadView
{
    CGRect bounds = UIScreen.mainScreen.bounds;
    self.view = [[UIView alloc] initWithFrame:bounds];
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    // 1. 创建原生的 Inset Grouped TableView
    self.tableView = [[UITableView alloc] initWithFrame:bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];

    // 2. 头部大标题
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, 80)];
    UILabel *headerLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, bounds.size.width - 40, 40)];
    headerLabel.text = @"TrollSpeed";
    headerLabel.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
    headerLabel.textColor = [UIColor labelColor];
    headerLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [headerView addSubview:headerLabel];
    self.tableView.tableHeaderView = headerView;

    // 3. 底部致谢 (放弃 AutoLayout，改用 frame 避免某些情况下的约束闪退)
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, 100)];
    _authorLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 10, bounds.size.width - 40, 80)];
    _authorLabel.numberOfLines = 0;
    _authorLabel.textAlignment = NSTextAlignmentCenter;
    _authorLabel.textColor = [UIColor secondaryLabelColor];
    _authorLabel.font = [UIFont systemFontOfSize:13.0];
    _authorLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _authorLabel.userInteractionEnabled = YES;
    [footerView addSubview:_authorLabel];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapAuthorLabel:)];
    [_authorLabel addGestureRecognizer:tap];
    self.tableView.tableFooterView = footerView;

    // 4. 初始化核心 UISwitch
    _mainSwitch = [[UISwitch alloc] init];
    [_mainSwitch addTarget:self action:@selector(mainSwitchToggled:) forControlEvents:UIControlEventValueChanged];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _supportsCenterMost = CGRectGetMinY(self.view.window.safeAreaLayoutGuide.layoutFrame) >= 51;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _impactFeedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [self registerNotifications];
    [self reloadMainButtonState];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self toggleHUDAfterLaunch];
}

// ==========================================
// UITableView DataSource & Delegate (完全中文化)
// ==========================================

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact) ? 2 : 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1; 
    if (section == 1) return 3; 
    if (section == 2) return 1; 
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    // 修复：直接输出中文
    if (section == 0) return @"运行状态";
    if (section == 1) return @"显示位置";
    if (section == 2) return @"高级选项";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellId];
    }

    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    if (indexPath.section == 0) {
        // 修复：直接输出中文
        NSString *title = _isRemoteHUDActive ? @"悬浮窗已开启" : @"悬浮窗已关闭";
        if (@available(iOS 14.0, *)) {
            UIListContentConfiguration *config = [cell defaultContentConfiguration];
            config.text = title;
            config.image = [UIImage systemImageNamed:@"speedometer"];
            config.imageProperties.tintColor = [UIColor systemBlueColor];
            cell.contentConfiguration = config;
        } else {
            cell.textLabel.text = title;
            cell.imageView.image = [UIImage systemImageNamed:@"speedometer"];
        }
        [_mainSwitch setOn:_isRemoteHUDActive animated:NO];
        cell.accessoryView = _mainSwitch;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    else if (indexPath.section == 1) {
        HUDPresetPosition selectedMode = [self selectedModeForCurrentOrientation];
        NSString *title = @"";
        NSString *iconName = @"";
        BOOL isSelected = NO;

        // 修复：直接输出中文
        if (indexPath.row == 0) {
            title = @"左上角";
            iconName = @"arrow.up.left";
            isSelected = (selectedMode == HUDPresetPositionTopLeft);
        } else if (indexPath.row == 1) {
            BOOL isCenteredMost = (selectedMode == HUDPresetPositionTopCenterMost);
            title = isCenteredMost ? @"顶部居中 (灵动岛)" : @"顶部居中";
            iconName = isCenteredMost ? @"arrow.up.to.line" : @"arrow.up";
            isSelected = (selectedMode == HUDPresetPositionTopCenter || selectedMode == HUDPresetPositionTopCenterMost);
        } else if (indexPath.row == 2) {
            title = @"右上角";
            iconName = @"arrow.up.right";
            isSelected = (selectedMode == HUDPresetPositionTopRight);
        }

        if (@available(iOS 14.0, *)) {
            UIListContentConfiguration *config = [cell defaultContentConfiguration];
            config.text = title;
            config.image = [UIImage systemImageNamed:iconName];
            cell.contentConfiguration = config;
        } else {
            cell.textLabel.text = title;
            cell.imageView.image = [UIImage systemImageNamed:iconName];
        }
        cell.accessoryType = isSelected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    }
    else if (indexPath.section == 2) {
        // 修复：直接输出中文
        if (@available(iOS 14.0, *)) {
            UIListContentConfiguration *config = [cell defaultContentConfiguration];
            config.text = @"高级设置";
            config.image = [UIImage systemImageNamed:@"gear"];
            config.imageProperties.tintColor = [UIColor systemGrayColor];
            cell.contentConfiguration = config;
        } else {
            cell.textLabel.text = @"高级设置";
            cell.imageView.image = [UIImage systemImageNamed:@"gear"];
        }
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            [self setSelectedModeForCurrentOrientation:HUDPresetPositionTopLeft];
        } else if (indexPath.row == 1) {
            HUDPresetPosition selectedMode = [self selectedModeForCurrentOrientation];
            if (selectedMode == HUDPresetPositionTopCenter || selectedMode == HUDPresetPositionTopCenterMost) {
                [self setSelectedModeForCurrentOrientation: (selectedMode == HUDPresetPositionTopCenterMost) ? HUDPresetPositionTopCenter : HUDPresetPositionTopCenterMost];
            } else {
                [self setSelectedModeForCurrentOrientation:HUDPresetPositionTopCenter];
                if (_supportsCenterMost) {
                    [self presentTopCenterMostHints];
                }
            }
        } else if (indexPath.row == 2) {
            [self setSelectedModeForCurrentOrientation:HUDPresetPositionTopRight];
        }
        [self reloadModeButtonState];
    }
    else if (indexPath.section == 2) {
        [self tapSettingsButton:nil];
    }
}

// ==========================================
// 核心交互逻辑与状态更新
// ==========================================
- (void)mainSwitchToggled:(UISwitch *)sender {
    BOOL intendedState = sender.isOn;
    // UI上先恢复，防止状态还没生效就改变
    [sender setOn:_isRemoteHUDActive animated:NO]; 
    if (intendedState != _isRemoteHUDActive) {
        [self toggleMainHUDState];
    }
}

- (void)toggleMainHUDState {
    BOOL isNowEnabled = [self isHUDEnabled];
    [self setHUDEnabled:!isNowEnabled];
    isNowEnabled = !isNowEnabled;

    if (isNowEnabled) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        [_impactFeedbackGenerator prepare];
        int anyToken;
        __weak typeof(self) weakSelf = self;
        notify_register_dispatch(NOTIFY_LAUNCHED_HUD, &anyToken, dispatch_get_main_queue(), ^(int token) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            notify_cancel(token);
            [strongSelf->_impactFeedbackGenerator impactOccurred];
            dispatch_semaphore_signal(semaphore);
        });

        [self.view setUserInteractionEnabled:NO];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            intptr_t timedOut = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)));
            dispatch_async(dispatch_get_main_queue(), ^{
                if (timedOut) {
                    log_error(OS_LOG_DEFAULT, "Timed out waiting for HUD to launch");
                }
                [self reloadMainButtonState];
                [self.view setUserInteractionEnabled:YES];
            });
        });
    } else {
        [self.view setUserInteractionEnabled:NO];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self reloadMainButtonState];
            [self.view setUserInteractionEnabled:YES];
        });
    }
}

- (void)reloadMainButtonState
{
    _isRemoteHUDActive = [self isHUDEnabled];

    static NSAttributedString *hintAttributedString = nil;
    static NSAttributedString *creditsAttributedString = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSDictionary *defaultAttributes = @{
            NSForegroundColorAttributeName: [UIColor secondaryLabelColor],
            NSFontAttributeName: [UIFont systemFontOfSize:13],
        };

        NSMutableParagraphStyle *creditsParaStyle = [[NSMutableParagraphStyle alloc] init];
        creditsParaStyle.lineHeightMultiple = 1.2;
        creditsParaStyle.alignment = NSTextAlignmentCenter;

        NSDictionary *creditsAttributes = @{
            NSForegroundColorAttributeName: [UIColor secondaryLabelColor],
            NSFontAttributeName: [UIFont systemFontOfSize:13],
            NSParagraphStyleAttributeName: creditsParaStyle,
        };

        // 修复：翻译为中文
        NSString *hintText = @"现在可以退出此 App，\n悬浮窗将持续在屏幕上显示。";
        hintAttributedString = [[NSAttributedString alloc] initWithString:hintText attributes:defaultAttributes];

        NSTextAttachment *githubIcon = [NSTextAttachment textAttachmentWithImage:[UIImage imageNamed:@"github-mark-white"]];
        [githubIcon setBounds:CGRectMake(0, 0, 14, 14)];

        NSTextAttachment *i18nIcon = [NSTextAttachment textAttachmentWithImage:[UIImage systemImageNamed:@"character.bubble.fill"]];
        [i18nIcon setBounds:CGRectMake(0, 0, 14, 14)];

        NSAttributedString *githubIconText = [NSAttributedString attributedStringWithAttachment:githubIcon];
        NSMutableAttributedString *githubIconTextFull = [[NSMutableAttributedString alloc] initWithAttributedString:githubIconText];
        [githubIconTextFull appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:creditsAttributes]];

        NSAttributedString *i18nIconText = [NSAttributedString attributedStringWithAttachment:i18nIcon];
        NSMutableAttributedString *i18nIconTextFull = [[NSMutableAttributedString alloc] initWithAttributedString:i18nIconText];
        [i18nIconTextFull appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:creditsAttributes]];

        NSString *creditsText = NSLocalizedString(@"Made with ♥ by @GITHUB@Lessica and @GITHUB@jmpews\nTranslation @TRANSLATION@", nil);
        NSMutableAttributedString *creditsAttributedText = [[NSMutableAttributedString alloc] initWithString:creditsText attributes:creditsAttributes];

        NSRange atRange = [creditsAttributedText.string rangeOfString:@"@GITHUB@"];
        while (atRange.location != NSNotFound) {
            [creditsAttributedText replaceCharactersInRange:atRange withAttributedString:githubIconTextFull];
            atRange = [creditsAttributedText.string rangeOfString:@"@GITHUB@"];
        }

        atRange = [creditsAttributedText.string rangeOfString:@"@TRANSLATION@"];
        while (atRange.location != NSNotFound) {
            [creditsAttributedText replaceCharactersInRange:atRange withAttributedString:i18nIconTextFull];
            atRange = [creditsAttributedText.string rangeOfString:@"@TRANSLATION@"];
        }

        creditsAttributedString = creditsAttributedText;
    });

    __weak typeof(self) weakSelf = self;
    [UIView transitionWithView:self.view duration:HUD_TRANSITION_DURATION options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf->_mainSwitch setOn:strongSelf->_isRemoteHUDActive animated:YES];
        
        // 【关键修复点】：绝对不能在动画块里使用 reloadRows，会直接闪退！改为直接拿到 Cell 并修改文本
        UITableViewCell *cell = [strongSelf.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        if (cell) {
            NSString *titleText = strongSelf->_isRemoteHUDActive ? @"悬浮窗已开启" : @"悬浮窗已关闭";
            if (@available(iOS 14.0, *)) {
                UIListContentConfiguration *config = [cell defaultContentConfiguration];
                config.text = titleText;
                config.image = [UIImage systemImageNamed:@"speedometer"];
                config.imageProperties.tintColor = [UIColor systemBlueColor];
                cell.contentConfiguration = config;
            } else {
                cell.textLabel.text = titleText;
            }
        }
        
        [strongSelf->_authorLabel setAttributedText:(strongSelf->_isRemoteHUDActive ? hintAttributedString : creditsAttributedString)];
    } completion:nil];
}

- (void)reloadModeButtonState
{
    if (self.tableView.numberOfSections > 1) {
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
    }
}

// ==========================================
// 触控、跳转与原有通知交互
// ==========================================
- (void)toggleHUDNotificationReceived:(NSNotification *)notification {
    NSString *toggleAction = notification.userInfo[kToggleHUDAfterLaunchNotificationActionKey];
    if (!toggleAction) {
        [self toggleHUDAfterLaunch];
    } else if ([toggleAction isEqualToString:kToggleHUDAfterLaunchNotificationActionToggleOn]) {
        [self toggleOnHUDAfterLaunch];
    } else if ([toggleAction isEqualToString:kToggleHUDAfterLaunchNotificationActionToggleOff]) {
        [self toggleOffHUDAfterLaunch];
    }
}

- (void)toggleHUDAfterLaunch {
    if ([RootViewController shouldToggleHUDAfterLaunch]) {
        [RootViewController setShouldToggleHUDAfterLaunch:NO];
        [self toggleMainHUDState];
        [[UIApplication sharedApplication] suspend];
    }
}

- (void)toggleOnHUDAfterLaunch {
    if ([RootViewController shouldToggleHUDAfterLaunch]) {
        [RootViewController setShouldToggleHUDAfterLaunch:NO];
        if (!_isRemoteHUDActive) {
            [self toggleMainHUDState];
        }
        [[UIApplication sharedApplication] suspend];
    }
}

- (void)toggleOffHUDAfterLaunch {
    if ([RootViewController shouldToggleHUDAfterLaunch]) {
        [RootViewController setShouldToggleHUDAfterLaunch:NO];
        if (_isRemoteHUDActive) {
            [self toggleMainHUDState];
        }
        [[UIApplication sharedApplication] suspend];
    }
}

- (void)presentTopCenterMostHints {
    if (!_isRemoteHUDActive) {
        return;
    }
    [_authorLabel setText:@"再次点击顶部居中按钮，\n可开启/关闭“灵动岛”模式。"];
}

- (void)tapAuthorLabel:(UITapGestureRecognizer *)sender
{
    if (_isRemoteHUDActive) {
        return;
    }
    NSString *repoURLString = @"https://trollspeed.app";
    NSURL *repoURL = [NSURL URLWithString:repoURLString];
    [[UIApplication sharedApplication] openURL:repoURL options:@{} completionHandler:nil];
}

- (void)tapSettingsButton:(id)sender
{
    if (!self.view.userInteractionEnabled) return;

    log_debug(OS_LOG_DEFAULT, "- [RootViewController tapSettingsButton]");

    TSSettingsController *settingsViewController = [[TSSettingsController alloc] init];
    settingsViewController.delegate = self;
    settingsViewController.alreadyLaunched = _isRemoteHUDActive;

    SPLarkTransitioningDelegate *transitioningDelegate = [[SPLarkTransitioningDelegate alloc] init];
    settingsViewController.transitioningDelegate = transitioningDelegate;
    settingsViewController.modalPresentationStyle = UIModalPresentationCustom;
    settingsViewController.modalPresentationCapturesStatusBarAppearance = YES;
    [self presentViewController:settingsViewController animated:YES completion:nil];
}

- (void)verticalSizeClassUpdated
{
    [self.tableView reloadData];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [self verticalSizeClassUpdated];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self reloadModeButtonState];
    } completion:nil];
}

// ==========================================
// 开发者与原设 UserDefaults 逻辑 (保留)
// ==========================================
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if (motion == UIEventSubtypeMotionShake) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"开发者选项" message:@"请选择操作" preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [alertController addAction:[UIAlertAction actionWithTitle:@"重置所有设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self resetUserDefaults];
        }]];
#if DEBUG && !TARGET_OS_SIMULATOR
        [alertController addAction:[UIAlertAction actionWithTitle:@"内存压力测试" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            SimulateMemoryPressure();
        }]];
#endif
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
    BOOL removed = [[NSFileManager defaultManager] removeItemAtPath:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH)) error:nil];
    if (removed) {
        [self setHUDEnabled:NO];
        [[UIApplication sharedApplication] terminateWithSuccess];
    }
}

- (void)loadUserDefaults:(BOOL)forceReload
{
    if (forceReload || !_userDefaults) {
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
    UIInterfaceOrientation orientation;
    orientation = self.view.window.windowScene.interfaceOrientation;
    BOOL isLandscape;
    if (orientation == UIInterfaceOrientationUnknown) {
        isLandscape = CGRectGetWidth(self.view.bounds) > CGRectGetHeight(self.view.bounds);
    } else {
        isLandscape = UIInterfaceOrientationIsLandscape(orientation);
    }
    return isLandscape;
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
    if ([self isLandscapeOrientation]) {
        [_userDefaults removeObjectForKey:HUDUserDefaultsKeyCurrentLandscapePositionY];
    } else {
        [_userDefaults removeObjectForKey:HUDUserDefaultsKeyCurrentPositionY];
    }
    [_userDefaults setObject:@(selectedMode) forKey:[self selectedModeKeyForCurrentOrientation]];
    [self saveUserDefaults];
}

- (BOOL)passthroughMode { [self loadUserDefaults:NO]; NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyPassthroughMode]; return mode != nil ? [mode boolValue] : NO; }
- (void)setPassthroughMode:(BOOL)passthroughMode { [self loadUserDefaults:NO]; [_userDefaults setObject:@(passthroughMode) forKey:HUDUserDefaultsKeyPassthroughMode]; [self saveUserDefaults]; }
- (BOOL)singleLineMode { [self loadUserDefaults:NO]; NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeySingleLineMode]; return mode != nil ? [mode boolValue] : NO; }
- (void)setSingleLineMode:(BOOL)singleLineMode { [self loadUserDefaults:NO]; [_userDefaults setObject:@(singleLineMode) forKey:HUDUserDefaultsKeySingleLineMode]; [self saveUserDefaults]; }
- (BOOL)usesBitrate { [self loadUserDefaults:NO]; NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesBitrate]; return mode != nil ? [mode boolValue] : NO; }
- (void)setUsesBitrate:(BOOL)usesBitrate { [self loadUserDefaults:NO]; [_userDefaults setObject:@(usesBitrate) forKey:HUDUserDefaultsKeyUsesBitrate]; [self saveUserDefaults]; }
- (BOOL)usesArrowPrefixes { [self loadUserDefaults:NO]; NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesArrowPrefixes]; return mode != nil ? [mode boolValue] : NO; }
- (void)setUsesArrowPrefixes:(BOOL)usesArrowPrefixes { [self loadUserDefaults:NO]; [_userDefaults setObject:@(usesArrowPrefixes) forKey:HUDUserDefaultsKeyUsesArrowPrefixes]; [self saveUserDefaults]; }
- (BOOL)usesLargeFont { [self loadUserDefaults:NO]; NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesLargeFont]; return mode != nil ? [mode boolValue] : NO; }
- (void)setUsesLargeFont:(BOOL)usesLargeFont { [self loadUserDefaults:NO]; [_userDefaults setObject:@(usesLargeFont) forKey:HUDUserDefaultsKeyUsesLargeFont]; [self saveUserDefaults]; }
- (BOOL)usesRotation { [self loadUserDefaults:NO]; NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesRotation]; return mode != nil ? [mode boolValue] : NO; }
- (void)setUsesRotation:(BOOL)usesRotation { [self loadUserDefaults:NO]; [_userDefaults setObject:@(usesRotation) forKey:HUDUserDefaultsKeyUsesRotation]; [self saveUserDefaults]; }
- (BOOL)usesInvertedColor { [self loadUserDefaults:NO]; NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesInvertedColor]; return mode != nil ? [mode boolValue] : NO; }
- (void)setUsesInvertedColor:(BOOL)usesInvertedColor { [self loadUserDefaults:NO]; [_userDefaults setObject:@(usesInvertedColor) forKey:HUDUserDefaultsKeyUsesInvertedColor]; [self saveUserDefaults]; }
- (BOOL)keepInPlace { [self loadUserDefaults:NO]; NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyKeepInPlace]; return mode != nil ? [mode boolValue] : NO; }
- (void)setKeepInPlace:(BOOL)keepInPlace { [self loadUserDefaults:NO]; [_userDefaults setObject:@(keepInPlace) forKey:HUDUserDefaultsKeyKeepInPlace]; [self saveUserDefaults]; }
- (BOOL)hideAtSnapshot { [self loadUserDefaults:NO]; NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyHideAtSnapshot]; return mode != nil ? [mode boolValue] : NO; }
- (void)setHideAtSnapshot:(BOOL)hideAtSnapshot { [self loadUserDefaults:NO]; [_userDefaults setObject:@(hideAtSnapshot) forKey:HUDUserDefaultsKeyHideAtSnapshot]; [self saveUserDefaults]; }
- (BOOL)displayMode { [self loadUserDefaults:NO]; NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyDisplayMode]; return mode != nil ? [mode boolValue] : NO; }
- (void)setDisplayMode:(BOOL)displayMode { [self loadUserDefaults:NO]; [_userDefaults setObject:@(displayMode) forKey:HUDUserDefaultsKeyDisplayMode]; [self saveUserDefaults]; }

- (BOOL)settingHighlightedWithKey:(NSString * _Nonnull)key {
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:key];
    return mode != nil ? [mode boolValue] : NO;
}

- (void)settingDidSelectWithKey:(NSString * _Nonnull)key {
    BOOL highlighted = [self settingHighlightedWithKey:key];
    [_userDefaults setObject:@(!highlighted) forKey:key];
    [self saveUserDefaults];
}

@end