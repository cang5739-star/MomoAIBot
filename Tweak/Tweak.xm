/* 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲
 * MomoAIBot.xm 鈥?闄岄檶 AI 鏅鸿兘鍥炲 Tweak
 * 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲 */

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <notify.h>

// 鈹€鈹€ 閰嶇疆绠＄悊鍣?鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
@interface MomoPrefs : NSObject
+ (id)val:(NSString *)key;
+ (void)setVal:(id)v key:(NSString *)key;
@end

@implementation MomoPrefs
+ (NSString *)p { return @"/var/mobile/Library/Preferences/com.momo.aibot.plist"; }
+ (id)val:(NSString *)key {
    NSString *p = [self p];
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:p];
    if (!d) {
        NSData *data = [NSData dataWithContentsOfFile:p];
        if (data) d = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:nil];
    }
    return d[key];
}
+ (void)setVal:(id)v key:(NSString *)key {
    NSString *p = [self p];
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithContentsOfFile:p] ?: [NSMutableDictionary dictionary];
    d[key] = v;
    [d writeToFile:p atomically:YES];
}
@end


// 鈹€鈹€ AI 寮曟搸 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
@interface MomoAI : NSObject
@property (class, readonly) MomoAI *shared;
@property (strong) NSMutableDictionary *convs;
@property (strong) NSMutableSet *blocked;
@property (strong) NSMutableArray *recent;
- (BOOL)enabled;
- (NSString *)apiKey;
- (NSString *)apiBase;
- (NSString *)model;
- (CGFloat)temp;
- (NSInteger)maxTok;
- (NSString *)sysPrompt;
- (BOOL)threshEn;
- (NSInteger)threshCnt;
- (NSString *)threshAct;
- (NSArray *)customTxts;
- (NSArray *)imgPaths;
- (NSInteger)delMin;
- (NSInteger)delMax;
- (void)recordMsg:(NSString *)msg from:(NSString *)uid name:(NSString *)uname;
- (NSInteger)msgCnt:(NSString *)uid;
- (NSArray *)history:(NSString *)uid limit:(NSInteger)lim;
- (BOOL)triggered:(NSString *)uid;
- (void)markTrig:(NSString *)uid;
- (BOOL)blocked:(NSString *)uid;
- (void)setBlocked:(NSString *)uid blocked:(BOOL)b;
- (void)genReply:(NSString *)uid name:(NSString *)uname cb:(void(^)(NSString *r, NSDictionary *act))cb;
- (NSString *)fallback;
- (NSString *)randImg;
- (NSTimeInterval)randDelay;
- (void)saveMem;
@end

@implementation MomoAI
+ (MomoAI *)shared {
    static MomoAI *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [[self alloc] init]; });
    return inst;
}
- (instancetype)init {
    if ((self = [super init])) {
        _convs = [NSMutableDictionary dictionary];
        _blocked = [NSMutableSet set];
        _recent = [NSMutableArray array];
        NSArray *b = [MomoPrefs val:@"blocked_users"];
        if ([b isKindOfClass:[NSArray class]]) [_blocked addObjectsFromArray:b];
        NSDictionary *mem = [MomoPrefs val:@"conversation_memory"];
        if ([mem isKindOfClass:[NSDictionary class]]) _convs = [mem mutableCopy];
    }
    return self;
}
- (BOOL)enabled { return [[MomoPrefs val:@"enabled"] boolValue]; }
- (NSString *)apiKey { return [MomoPrefs val:@"api_key"] ?: @""; }
- (NSString *)apiBase { return [MomoPrefs val:@"api_base"] ?: @"https://api.openai.com/v1"; }
- (NSString *)model { return [MomoPrefs val:@"model"] ?: @"gpt-4o-mini"; }
- (CGFloat)temp { return [[MomoPrefs val:@"temperature"] floatValue] ?: 0.8; }
- (NSInteger)maxTok { return [[MomoPrefs val:@"max_tokens"] integerValue] ?: 200; }
- (NSString *)sysPrompt { return [MomoPrefs val:@"system_prompt"] ?: @"浣犳槸涓€涓湪闄岄檶绀句氦App涓婁笌浜鸿亰澶╃殑鐢ㄦ埛銆傝鑷劧鍦板洖澶嶅鏂圭殑娑堟伅锛岃姘斾翰鍒囥€?; }
- (BOOL)threshEn { return [[MomoPrefs val:@"threshold_enabled"] boolValue]; }
- (NSInteger)threshCnt { return [[MomoPrefs val:@"threshold_count"] integerValue] ?: 10; }
- (NSString *)threshAct { return [MomoPrefs val:@"threshold_action"] ?: @"auto_image"; }
- (NSArray *)customTxts { return [MomoPrefs val:@"custom_texts"] ?: @[]; }
- (NSArray *)imgPaths { return [MomoPrefs val:@"image_paths"] ?: @[]; }
- (NSInteger)delMin { return [[MomoPrefs val:@"delay_min"] integerValue] ?: 2; }
- (NSInteger)delMax { return [[MomoPrefs val:@"delay_max"] integerValue] ?: 8; }

- (void)recordMsg:(NSString *)msg from:(NSString *)uid name:(NSString *)uname {
    if (!uid || !msg) return;
    if (!_convs[uid]) {
        _convs[uid] = [NSMutableDictionary dictionaryWithDictionary:@{@"name": uname ?: @"?", @"cnt": @0, @"hist": [NSMutableArray array], @"trig": @NO}];
    }
    NSMutableDictionary *c = _convs[uid];
    c[@"name"] = uname ?: c[@"name"];
    c[@"cnt"] = @([c[@"cnt"] integerValue] + 1);
    NSMutableArray *h = c[@"hist"];
    [h addObject:@{@"role":@"user", @"content":msg}];
    if (h.count > 100) [h removeObjectsInRange:NSMakeRange(0, h.count-100)];
    [self saveMem];
    NSLog(@"[MomoAI] +[%@] #%@: %@", uid, c[@"cnt"], [msg substringToIndex:MIN(20,msg.length)]);
}
- (NSInteger)msgCnt:(NSString *)uid { return [_convs[uid][@"cnt"] integerValue]; }
- (NSArray *)history:(NSString *)uid limit:(NSInteger)lim {
    NSArray *h = [_convs[uid][@"hist"] copy];
    if (h.count > lim) h = [h subarrayWithRange:NSMakeRange(h.count-lim, lim)];
    return h ?: @[];
}
- (BOOL)triggered:(NSString *)uid { return [_convs[uid][@"trig"] boolValue]; }
- (void)markTrig:(NSString *)uid { _convs[uid][@"trig"] = @YES; [self saveMem]; }
- (BOOL)blocked:(NSString *)uid { return [_blocked containsObject:uid]; }
- (void)setBlocked:(NSString *)uid blocked:(BOOL)b {
    if (b) [_blocked addObject:uid]; else [_blocked removeObject:uid];
    [MomoPrefs setVal:[_blocked allObjects] key:@"blocked_users"];
}
- (void)saveMem { [MomoPrefs setVal:[_convs copy] key:@"conversation_memory"]; }

- (NSTimeInterval)randDelay {
    NSInteger mn = [self delMin], mx = [self delMax];
    return (mx > mn) ? mn + arc4random_uniform((uint32_t)(mx-mn+1)) : mn;
}
- (NSString *)fallback {
    NSArray *fb = @[@"鍝堝搱锛岀湡鐨勫悧锛燄煒?,@"鍡棷锛岃寰楀锝?,@"鎴戜篃鏄繖涔堟兂鐨勶紒",
        @"鏈夎叮鏈夎叮锝?,@"鍘熸潵濡傛锛?,@"鍝堝搱浣犲お鏈夋剰鎬濅簡",@"瀵瑰憖瀵瑰憖锝?,
        @"鏄繖鏍风殑锛?,@"鍝囩湡鐨勫亣鐨勶紵",@"绗戞馃槀",@"鏈夐亾鐞嗭紒",@"纭疄濡傛锝?,
        @"濂芥淮濂芥淮",@"鍡棷鎴戝湪鍚綖"];
    return fb[arc4random_uniform((uint32_t)fb.count)];
}
- (NSString *)randImg {
    NSArray *p = [self imgPaths];
    return p.count ? p[arc4random_uniform((uint32_t)p.count)] : nil;
}

- (void)genReply:(NSString *)uid name:(NSString *)uname cb:(void(^)(NSString *, NSDictionary *))cb {
    if (!cb) return;
    if (![self enabled]) { cb(nil, nil); return; }
    NSString *key = [self apiKey];
    if (!key.length) { cb([self fallback], nil); return; }

    BOOL shouldTrig = [self threshEn] && [self msgCnt:uid] >= [self threshCnt] && ![self triggered:uid];
    if (shouldTrig) [self markTrig:uid];

    NSArray *hist = [self history:uid limit:20];
    NSString *sp = [self sysPrompt];
    if (shouldTrig) sp = [sp stringByAppendingString:@"\n鎻愮ず锛氬拰杩欎綅鐢ㄦ埛鑱婂緱姣旇緝鎶曠紭浜嗭紝鍙互鑷劧鍦板紩瀵煎姞寰俊鎴栦氦鎹㈣仈绯绘柟寮忋€?];

    NSMutableArray *msgs = [NSMutableArray array];
    [msgs addObject:@{@"role":@"system", @"content":sp}];
    for (NSDictionary *m in hist) [msgs addObject:m];

    NSDictionary *payload = @{
        @"model": [self model], @"messages": msgs,
        @"temperature": @([self temp]), @"max_tokens": @([self maxTok])
    };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    if (!jsonData) { cb([self fallback], nil); return; }

    NSString *urlStr = [NSString stringWithFormat:@"%@/chat/completions", [self apiBase]];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", key] forHTTPHeaderField:@"Authorization"];
    req.HTTPBody = jsonData;
    req.timeoutInterval = 30;

    NSArray *recentCopy = [_recent copy];
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (e || !d) { dispatch_async(dispatch_get_main_queue(), ^{ cb([self fallback], nil); }); return; }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        NSString *reply = json[@"choices"][0][@"message"][@"content"];
        if (!reply) { dispatch_async(dispatch_get_main_queue(), ^{ cb([self fallback], nil); }); return; }
        reply = [reply stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        for (NSString *r in recentCopy) {
            if ([r containsString:reply] || [reply containsString:r]) { reply = [reply stringByAppendingString:@" 馃槉"]; break; }
        }

        NSDictionary *specialAct = nil;
        if (shouldTrig) {
            NSString *act = [self threshAct];
            if ([act isEqualToString:@"auto_image"]) {
                NSString *img = [self randImg];
                if (img) specialAct = @{@"type":@"image", @"path":img, @"caption":reply};
                else { NSArray *txts = [self customTxts];
                    if (txts.count) { reply = txts[arc4random_uniform((uint32_t)txts.count)]; specialAct = @{@"type":@"text", @"text":reply}; } }
            } else if ([act isEqualToString:@"custom_text"]) {
                NSArray *txts = [self customTxts];
                if (txts.count) { reply = txts[arc4random_uniform((uint32_t)txts.count)]; specialAct = @{@"type":@"text", @"text":reply}; }
            }
        }

        [self->_recent addObject:reply ?: @""];
        if (self->_recent.count > 20) [self->_recent removeObjectAtIndex:0];

        NSLog(@"[MomoAI] 鍥炲: %@", [reply substringToIndex:MIN(30,reply.length)]);
        dispatch_async(dispatch_get_main_queue(), ^{ cb(reply, specialAct); });
    }] resume];
}
@end


// 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲
//  馃帲 Logos Hooks
// 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲

%hook UIApplication
- (void)applicationDidFinishLaunching:(id)sender {
    %orig;
    [MomoAI shared];
    NSLog(@"[MomoAI] Momo AI Bot 宸插姞杞?v1.0.0");
}
%end


// 鈹€鈹€ 杈呭姪鏂规硶澹版槑锛堣缂栬瘧鍣ㄥ拰 IDE 鐭ラ亾杩欎簺鏂规硶瀛樺湪锛夆攢鈹€
@interface UITableView (MomoAIHelper)
- (UITextView *)findInputInView:(UIView *)v;
- (UITextField *)findFieldInView:(UIView *)v;
- (void)trigSend:(UIView *)v;
- (void)toast:(NSString *)msg;
@end


// 鈹€鈹€ 鑱婂ぉ鐣岄潰娑堟伅鎷︽埅 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
%hook UITableView

- (void)insertRowsAtIndexPaths:(NSArray *)ips withRowAnimation:(UITableViewRowAnimation)anim {
    %orig;
    UIViewController *vc = (id)self;
    while (vc && ![vc isKindOfClass:[UIViewController class]]) vc = (id)[vc nextResponder];
    if (!vc) return;
    NSString *cls = NSStringFromClass([vc class]);
    if (![cls containsString:@"Chat"] && ![cls containsString:@"Message"] &&
        ![cls containsString:@"Conversation"] && ![cls containsString:@"Session"]) return;
    if (![[MomoAI shared] enabled]) return;

    for (NSIndexPath *ip in ips) {
        UITableViewCell *cell = [self cellForRowAtIndexPath:ip];
        if (!cell) continue;
        NSString *txt = nil;
        for (UIView *v in cell.contentView.subviews) {
            if ([v isKindOfClass:[UILabel class]]) { txt = ((UILabel *)v).text; if (txt.length) break; }
            if ([v isKindOfClass:[UITextView class]]) { txt = ((UITextView *)v).text; if (txt.length) break; }
        }
        if (!txt.length) continue;
        BOOL isOwn = cell.contentView.frame.origin.x > self.frame.size.width * 0.4;
        if (isOwn) continue;

        NSString *name = vc.navigationItem.title ?: vc.title ?: @"鑱婂ぉ瀵硅薄";
        NSString *uid = [NSString stringWithFormat:@"chat_%p", vc];
        MomoAI *ai = [MomoAI shared];
        if ([ai blocked:uid]) continue;

        [ai recordMsg:txt from:uid name:name];
        [ai genReply:uid name:name cb:^(NSString *reply, NSDictionary *act) {
            if (!reply) return;
            NSTimeInterval delay = [ai randDelay];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UITextView *tv = [self findInputInView:vc.view];
                UITextField *tf = tv ? nil : [self findFieldInView:vc.view];
                if (act && [act[@"type"] isEqualToString:@"image"]) {
                    NSString *cap = act[@"caption"] ?: reply;
                    if (tv) { tv.text = cap; [self trigSend:vc.view]; }
                    else if (tf) { tf.text = cap; [self trigSend:vc.view]; }
                    else { [UIPasteboard generalPasteboard].string = cap; [self toast:@"AI 鍥炲宸插鍒?]; }
                } else {
                    if (tv) { tv.text = reply; [[NSNotificationCenter defaultCenter] postNotificationName:UITextViewTextDidChangeNotification object:tv]; [self trigSend:vc.view]; }
                    else if (tf) { tf.text = reply; [[NSNotificationCenter defaultCenter] postNotificationName:UITextFieldTextDidChangeNotification object:tf]; [self trigSend:vc.view]; }
                    else { [UIPasteboard generalPasteboard].string = reply; [self toast:@"AI 鍥炲宸插鍒?]; }
                }
            });
        }];
    }
}

%new
- (UITextView *)findInputInView:(UIView *)v {
    if ([v isKindOfClass:[UITextView class]] && ((UITextView *)v).isEditable) return (UITextView *)v;
    for (UIView *sv in v.subviews) { UITextView *f = [self findInputInView:sv]; if (f) return f; }
    return nil;
}
%new
- (UITextField *)findFieldInView:(UIView *)v {
    if ([v isKindOfClass:[UITextField class]]) return (UITextField *)v;
    for (UIView *sv in v.subviews) { UITextField *f = [self findFieldInView:sv]; if (f) return f; }
    return nil;
}
%new
- (void)trigSend:(UIView *)v {
    if ([v isKindOfClass:[UIButton class]]) {
        NSString *t = [(UIButton *)v titleForState:UIControlStateNormal] ?: @"";
        if ([t containsString:@"鍙戦€?] || [t containsString:@"Send"] || [t containsString:@">"]) {
            [(UIButton *)v sendActionsForControlEvents:UIControlEventTouchUpInside];
            return;
        }
    }
    for (UIView *sv in v.subviews) [self trigSend:sv];
}
%new
- (void)toast:(NSString *)msg {
    UIWindow *w = [UIApplication sharedApplication].keyWindow;
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, w.frame.size.width-40, 44)];
    l.backgroundColor = [UIColor colorWithWhite:0 alpha:0.85];
    l.textColor = UIColor.whiteColor;
    l.textAlignment = NSTextAlignmentCenter;
    l.font = [UIFont systemFontOfSize:14];
    l.text = msg;
    l.layer.cornerRadius = 10;
    l.clipsToBounds = YES;
    l.alpha = 0;
    [w addSubview:l];
    [UIView animateWithDuration:0.3 animations:^{ l.alpha = 1; } completion:^(BOOL done) {
        [UIView animateWithDuration:0.3 delay:2.0 options:0 animations:^{ l.alpha = 0; } completion:^(BOOL done) { [l removeFromSuperview]; }];
    }];
}
%end


// 鈹€鈹€ 閫氱煡鎷︽埅 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
%hook NSNotificationCenter
- (void)postNotification:(NSNotification *)n {
    %orig;
    NSString *name = n.name;
    if (![name containsString:@"Message"] && ![name containsString:@"message"] &&
        ![name containsString:@"RecvMsg"] && ![name containsString:@"OnReceive"]) return;
    NSString *txt = nil, *uid = nil, *uname = nil;
    if ([n.object isKindOfClass:[NSString class]]) txt = n.object;
    else if ([n.object respondsToSelector:@selector(content)]) txt = [n.object performSelector:@selector(content)];
    else if ([n.object respondsToSelector:@selector(text)]) txt = [n.object performSelector:@selector(text)];
    if (!txt) txt = n.userInfo[@"content"] ?: n.userInfo[@"text"] ?: n.userInfo[@"message"];
    if (!txt.length) return;
    uid = n.userInfo[@"senderId"] ?: n.userInfo[@"from"] ?: n.userInfo[@"userId"] ?: [NSString stringWithFormat:@"notif_%p", n];
    uname = n.userInfo[@"senderName"] ?: n.userInfo[@"fromName"] ?: n.userInfo[@"nick"] ?: @"鑱婂ぉ瀵硅薄";
    MomoAI *ai = [MomoAI shared];
    if (![ai enabled] || [ai blocked:uid]) return;
    [ai recordMsg:txt from:uid name:uname];
    [ai genReply:uid name:uname cb:^(NSString *r, NSDictionary *a) {
        if (r) [UIPasteboard generalPasteboard].string = r;
    }];
}
%end

%ctor {
    NSLog(@"[MomoAI] =========================");
    NSLog(@"[MomoAI] Momo AI Bot v1.0.0 loaded");
    NSLog(@"[MomoAI] =========================");
    [MomoAI shared];
}
