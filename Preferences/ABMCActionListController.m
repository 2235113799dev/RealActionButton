#import "ABMCActionListController.h"
#import <Preferences/PSSpecifier.h>

#define PREFS_DOMAIN @"com.huynguyen.actionbuttonmulticlick"
#define PREFS_NOTIFICATION @"com.huynguyen.actionbuttonmulticlick/prefsChanged"

typedef struct {
    NSString *actionID;
    NSString *title;
} ABMCAction;

static const ABMCAction kBuiltInActions[] = {
    { @"default",    @"系统默认" },
    { @"flashlight", @"手电筒" },
    { @"camera",     @"相机" },
    { @"silent",     @"静音切换" },
    { @"screenshot", @"截屏" },
    { @"lock",       @"锁屏" },
    { @"respring",   @"重启界面" },
    { @"wechatScan", @"微信扫码" },
    { @"wechatPay",  @"微信付款码" },
    { @"alipayScan", @"支付宝扫码" },
    { @"alipayPay",  @"支付宝付款码" },
    { @"none",       @"无操作" },
};

@implementation ABMCActionListController {
    NSString *_prefKey;
    NSString *_currentValue;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    PSSpecifier *parentSpecifier = [self specifier];
    _prefKey = [parentSpecifier propertyForKey:@"key"];
    NSString *defaultVal = [parentSpecifier propertyForKey:@"default"] ?: @"none";

    CFPreferencesAppSynchronize((__bridge CFStringRef)PREFS_DOMAIN);
    CFStringRef val = (CFStringRef)CFPreferencesCopyAppValue((__bridge CFStringRef)_prefKey, (__bridge CFStringRef)PREFS_DOMAIN);
    _currentValue = val ? (__bridge_transfer NSString *)val : defaultVal;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];

        // Built-in actions group
        PSSpecifier *group1 = [PSSpecifier groupSpecifierWithName:@"内置动作"];
        [specs addObject:group1];

        NSUInteger count = sizeof(kBuiltInActions) / sizeof(kBuiltInActions[0]);
        for (NSUInteger i = 0; i < count; i++) {
            PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:kBuiltInActions[i].title
                                                              target:self
                                                                 set:NULL
                                                                 get:NULL
                                                              detail:Nil
                                                                cell:PSStaticTextCell
                                                                edit:Nil];
            [spec setProperty:kBuiltInActions[i].actionID forKey:@"actionID"];
            spec->action = @selector(selectAction:);
            [specs addObject:spec];
        }

        // Custom actions group
        PSSpecifier *group2 = [PSSpecifier groupSpecifierWithName:@"自定义动作"];
        [group2 setProperty:@"填写应用包名唤起App、运行快捷指令或填入URL‑Scheme。" forKey:@"footerText"];
        [specs addObject:group2];

        PSSpecifier *openApp = [PSSpecifier preferenceSpecifierNamed:@"打开应用…"
                                                             target:self
                                                                set:NULL
                                                                get:NULL
                                                             detail:Nil
                                                               cell:PSStaticTextCell
                                                               edit:Nil];
        [openApp setProperty:@"customApp" forKey:@"actionID"];
        openApp->action = @selector(selectAction:);
        [specs addObject:openApp];

        PSSpecifier *shortcut = [PSSpecifier preferenceSpecifierNamed:@"运行快捷指令…"
                                                              target:self
                                                                 set:NULL
                                                                 get:NULL
                                                              detail:Nil
                                                                cell:PSStaticTextCell
                                                                edit:Nil];
        [shortcut setProperty:@"customShortcut" forKey:@"actionID"];
        shortcut->action = @selector(selectAction:);
        [specs addObject:shortcut];

        PSSpecifier *openURL = [PSSpecifier preferenceSpecifierNamed:@"打开 URL…"
                                                             target:self
                                                                set:NULL
                                                                get:NULL
                                                             detail:Nil
                                                               cell:PSStaticTextCell
                                                               edit:Nil];
        [openURL setProperty:@"customURL" forKey:@"actionID"];
        openURL->action = @selector(selectAction:);
        [specs addObject:openURL];

        _specifiers = specs;
    }
    return _specifiers;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];

    // Show checkmark on currently selected action
    PSSpecifier *spec = [self specifierAtIndexPath:indexPath];
    NSString *actionID = [spec propertyForKey:@"actionID"];
    if (actionID && ![actionID hasPrefix:@"custom"]) {
        cell.accessoryType = [_currentValue isEqualToString:actionID] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    } else if ([actionID isEqualToString:@"customApp"] && [_currentValue hasPrefix:@"app:"]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else if ([actionID isEqualToString:@"customShortcut"] && [_currentValue hasPrefix:@"shortcut:"]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else if ([actionID isEqualToString:@"customURL"] && [_currentValue hasPrefix:@"url:"]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    return cell;
}

- (void)selectAction:(PSSpecifier *)specifier {
    NSString *actionID = [specifier propertyForKey:@"actionID"];

    if ([actionID isEqualToString:@"customApp"]) {
        [self promptForCustomValue:@"打开应用" message:@"输入App包名：" prefix:@"app:"];
    } else if ([actionID isEqualToString:@"customShortcut"]) {
        [self promptForCustomValue:@"运行快捷指令" message:@"输入快捷指令名称：" prefix:@"shortcut:"];
    } else if ([actionID isEqualToString:@"customURL"]) {
        [self promptForCustomValue:@"打开 URL" message:@"请输入完整 URL Scheme，例如：weixin://scanqrcode" prefix:@"url:"];
    } else {
        [self saveAction:actionID];
    }
}

- (void)promptForCustomValue:(NSString *)title message:(NSString *)message prefix:(NSString *)prefix {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;

        // Pre-fill if current value matches this prefix
        if ([self->_currentValue hasPrefix:prefix]) {
            textField.text = [self->_currentValue substringFromIndex:prefix.length];
        }
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *value = alert.textFields.firstObject.text;
        if (value.length > 0) {
            [self saveAction:[NSString stringWithFormat:@"%@%@", prefix, value]];
        }
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)saveAction:(NSString *)actionID {
    _currentValue = actionID;

    CFPreferencesSetAppValue((__bridge CFStringRef)_prefKey,
                             (__bridge CFPropertyListRef)actionID,
                             (__bridge CFStringRef)PREFS_DOMAIN);
    CFPreferencesAppSynchronize((__bridge CFStringRef)PREFS_DOMAIN);

    // Notify the tweak
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)PREFS_NOTIFICATION,
                                         NULL, NULL, YES);

    // Refresh checkmarks
    [self.table reloadData];
}

@end
