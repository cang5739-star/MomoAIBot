/* ══════════════════════════════════════════════════════════
 * MomoAIPrefs.mm — 陌陌 AI Bot 设置面板 (PreferenceBundle)
 * ══════════════════════════════════════════════════════════ */

#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <notify.h>

#define SETTINGS_PATH @"/var/mobile/Library/Preferences/com.momo.aibot.plist"
#define NOTIFY_NAME "com.momo.aibot.settingsChanged"

@interface MomoAIPrefsRootController : PSListController
- (void)respring;
- (void)resetAllConversations;
- (void)exportConfig;
- (void)saveSetting:(PSSpecifier *)spec;
@end

@implementation MomoAIPrefsRootController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"MomoAIPrefs" target:self];
    }
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"Momo AI Bot";
}

// 保存设置并发送通知
- (void)saveSetting:(PSSpecifier *)spec {
    [self reloadSpecifier:spec animated:YES];
    // 通知 tweak 配置变更
    notify_post(NOTIFY_NAME);
}

// 注销 SpringBoard
- (void)respring {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重启 SpringBoard"
                                                                   message:@"重启后配置生效。确定要重启吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"重启" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *act) {
        notify_post(NOTIFY_NAME);
        sleep(1);
        notify_post(NOTIFY_NAME); exit(0);
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

// 重置所有对话
- (void)resetAllConversations {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重置对话"
                                                                   message:@"确定要清除所有对话记录和对话计数吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *act) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:SETTINGS_PATH];
        if (dict) {
            dict[@"conversation_memory"] = @{};
            [dict writeToFile:SETTINGS_PATH atomically:YES];
        }
        notify_post(NOTIFY_NAME);
        UIAlertController *done = [UIAlertController alertControllerWithTitle:@"已重置"
                                                                       message:@"所有对话记录已清除"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [done addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:done animated:YES completion:nil];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

// 导出配置（复制到剪贴板）
- (void)exportConfig {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:SETTINGS_PATH];
    if (dict) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
        if (data) {
            NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            [UIPasteboard generalPasteboard].string = json;
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已导出"
                                                                           message:@"配置已复制到剪贴板"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }
}

@end


// ── 对话管理面板 ──────────────────────────────────────
@interface MomoAIConversationsController : PSListController
@end

@implementation MomoAIConversationsController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"MomoAIConversations" target:self];
    }
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"对话管理";
}

// 动态生成对话列表
- (NSArray *)conversationSpecifiers {
    NSMutableArray *specs = [NSMutableArray array];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:SETTINGS_PATH];
    NSDictionary *convs = dict[@"conversation_memory"];

    if (convs.count == 0) {
        PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:@"暂无对话记录"
                                                           target:self
                                                              set:nil
                                                              get:nil
                                                           detail:nil
                                                             cell:PSTitleValueCell
                                                             edit:nil];
        [specs addObject:spec];
        return specs;
    }

    for (NSString *uid in [convs allKeys]) {
        NSDictionary *c = convs[uid];
        NSInteger cnt = [c[@"cnt"] integerValue];
        BOOL trig = [c[@"trig"] boolValue];
        NSString *name = c[@"name"] ?: uid;
        NSString *label = [NSString stringWithFormat:@"%@ (%ld句)%@", name, (long)cnt, trig ? @" 🔔" : @""];

        PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:label
                                                           target:self
                                                              set:nil
                                                              get:nil
                                                           detail:nil
                                                             cell:PSButtonCell
                                                             edit:nil];
        spec.buttonAction = @selector(showConversation:);
        spec.properties = [@{@"uid": uid} mutableCopy];
        [specs addObject:spec];
    }

    return specs;
}

- (void)showConversation:(PSSpecifier *)spec {
    NSString *uid = spec.properties[@"uid"];
    if (!uid) return;

    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:SETTINGS_PATH];
    NSDictionary *conv = dict[@"conversation_memory"][uid];
    if (!conv) return;

    NSArray *hist = conv[@"hist"];
    NSMutableString *text = [NSMutableString string];
    for (NSDictionary *msg in hist) {
        NSString *role = [msg[@"role"] isEqualToString:@"user"] ? @"👤" : @"🤖";
        [text appendFormat:@"%@ %@\n", role, msg[@"content"]];
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:conv[@"name"] ?: uid
                                                                   message:text.length ? text : @"(空)"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleDefault handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"重置此对话" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *act) {
        NSMutableDictionary *mDict = [NSMutableDictionary dictionaryWithContentsOfFile:SETTINGS_PATH];
        NSMutableDictionary *mConvs = [mDict[@"conversation_memory"] mutableCopy];
        [mConvs removeObjectForKey:uid];
        mDict[@"conversation_memory"] = mConvs;
        [mDict writeToFile:SETTINGS_PATH atomically:YES];
        notify_post(NOTIFY_NAME);
        [self reloadSpecifiers];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end


// ── 关于页面 ──────────────────────────────────────────
@interface MomoAIAboutController : PSListController
@end

@implementation MomoAIAboutController
- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"MomoAIAbout" target:self];
    }
    return _specifiers;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"关于";
}
@end
