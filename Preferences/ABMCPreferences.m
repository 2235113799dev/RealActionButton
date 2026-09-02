#import "ABMCPreferences.h"
#import <Preferences/PSSpecifier.h>

#define PREFS_DOMAIN @"com.huynguyen.actionbuttonmulticlick"
#define PREFS_NOTIFICATION @"com.huynguyen.actionbuttonmulticlick/prefsChanged"

static NSString *titleForActionID(NSString *actionID) {
    if (!actionID || [actionID isEqualToString:@"none"]) return @"无操作";
    if ([actionID isEqualToString:@"default"]) return @"系统默认";
    if ([actionID isEqualToString:@"flashlight"]) return @"手电筒";
    if ([actionID isEqualToString:@"camera"]) return @"相机";
    if ([actionID isEqualToString:@"silent"]) return @"静音切换";
    if ([actionID isEqualToString:@"screenshot"]) return @"截屏";
    if ([actionID isEqualToString:@"lock"]) return @"锁屏";
    if ([actionID isEqualToString:@"respring"]) return @"重启界面";
    if ([actionID isEqualToString:@"wechatScan"]) return @"微信扫码";
    if ([actionID isEqualToString:@"wechatPay"]) return @"微信付款码";
    if ([actionID isEqualToString:@"alipayScan"]) return @"支付宝扫码";
    if ([actionID isEqualToString:@"alipayPay"]) return @"支付宝付款码";
    if ([actionID hasPrefix:@"app:"]) return [NSString stringWithFormat:@"打开应用：%@", [actionID substringFromIndex:4]];
    if ([actionID hasPrefix:@"shortcut:"]) return [NSString stringWithFormat:@"运行快捷指令：%@", [actionID substringFromIndex:9]];
    if ([actionID hasPrefix:@"url:"]) return [NSString stringWithFormat:@"打开 URL：%@", [actionID substringFromIndex:4]];
    return actionID;
}

@implementation ABMCPreferences

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];

        PSSpecifier *group1 = [PSSpecifier groupSpecifierWithName:@"按键动作"];
        [group1 setProperty:@"单击在松开后最多等待 240 毫秒；第二次松开后会立即执行双击。长按仍由系统原生时机识别。" forKey:@"footerText"];
        [specs addObject:group1];

        PSSpecifier *single = [PSSpecifier preferenceSpecifierNamed:@"单击动作"
                                                             target:self
                                                                set:NULL
                                                                get:NULL
                                                             detail:NSClassFromString(@"ABMCActionListController")
                                                               cell:PSLinkCell
                                                               edit:Nil];
        [single setProperty:@"singleClickAction" forKey:@"key"];
        [single setProperty:@"default" forKey:@"default"];
        [single setProperty:PREFS_DOMAIN forKey:@"defaults"];
        [specs addObject:single];

        PSSpecifier *dbl = [PSSpecifier preferenceSpecifierNamed:@"双击动作"
                                                          target:self
                                                             set:NULL
                                                             get:NULL
                                                          detail:NSClassFromString(@"ABMCActionListController")
                                                            cell:PSLinkCell
                                                            edit:Nil];
        [dbl setProperty:@"doubleClickAction" forKey:@"key"];
        [dbl setProperty:@"none" forKey:@"default"];
        [dbl setProperty:PREFS_DOMAIN forKey:@"defaults"];
        [specs addObject:dbl];

        PSSpecifier *longPress = [PSSpecifier preferenceSpecifierNamed:@"长按动作"
                                                                target:self
                                                                   set:NULL
                                                                   get:NULL
                                                                detail:NSClassFromString(@"ABMCActionListController")
                                                                  cell:PSLinkCell
                                                                  edit:Nil];
        [longPress setProperty:@"longPressAction" forKey:@"key"];
        [longPress setProperty:@"default" forKey:@"default"];
        [longPress setProperty:PREFS_DOMAIN forKey:@"defaults"];
        [specs addObject:longPress];

        _specifiers = specs;
    }
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reload];
}

- (void)reloadSpecifiers {
    [super reloadSpecifiers];
    for (PSSpecifier *spec in _specifiers) {
        NSString *key = [spec propertyForKey:@"key"];
        if ([key hasSuffix:@"Action"]) {
            CFPreferencesAppSynchronize((__bridge CFStringRef)PREFS_DOMAIN);
            CFStringRef val = (CFStringRef)CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)PREFS_DOMAIN);
            NSString *actionID = val ? (__bridge_transfer NSString *)val : [spec propertyForKey:@"default"];
            [spec setProperty:titleForActionID(actionID) forKey:@"cellValue"];
        }
    }
}

@end
