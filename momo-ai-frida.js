// == Momo AI Bot - Frida Hook Script ==
// 适用于 Windows 用户，无需 Theos/越狱插件编译环境
// 使用方式: frida -U com.immomo.momo -l momo-ai-frida.js

// 配置（可通过 Python 启动器动态设置）
var CONFIG = {
    apiKey: null,          // OpenAI API Key
    model: 'gpt-4o-mini',  // AI模型
    systemPrompt: '你是一个普通朋友，正在和对方聊天。用自然的中文回复，语气贴近日常对话。尽量简短（不超过50字）。',
    triggerCount: 10,      // 多少句后触发动作
    replyDelayMin: 2,      // 最小回复延迟（秒）
    replyDelayMax: 8,      // 最大回复延迟（秒）
    imagePath: '/var/mobile/Media/DCIM/MomoAI/',  // 自动发图目录
    autoReply: true,       // 是否启用AI自动回复
    useImageTrigger: false, // 触发时发图
    useTextTrigger: false,  // 触发时发自定义话术
    customTexts: ['在忙什么呢？', '哈哈好的', '嗯嗯'], // 自定义话术列表
};

// 对话上下文存储
var conversations = {};
var messageCounts = {};

// 工具函数：生成随机延迟
function randomDelay(min, max) {
    return (Math.random() * (max - min) + min) * 1000;
}

// 工具函数：随机选取数组元素
function randomChoice(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
}

// 发送数据到 Python 端请求 AI 回复
function requestAIReply(senderId, message, callback) {
    var conversation = conversations[senderId] || [];
    conversation.push({role: 'user', content: message});
    if (conversation.length > 20) conversation = conversation.slice(-20);
    conversations[senderId] = conversation;
    
    var payload = {
        type: 'ask_ai',
        message: message,
        senderId: senderId,
        conversation: conversation,
        systemPrompt: CONFIG.systemPrompt,
        model: CONFIG.model,
        apiKey: CONFIG.apiKey
    };
    
    send(JSON.stringify(payload));
    
    // 注册一次性回调
    _callbacks = _callbacks || {};
    var cbId = 'cb_' + Date.now() + '_' + Math.random();
    _callbacks[cbId] = callback;
    
    // 超时处理
    setTimeout(function() {
        if (_callbacks[cbId]) {
            delete _callbacks[cbId];
            callback('抱歉，回复超时了');
        }
    }, 30000);
}

var _callbacks = {};

// 接收 Python 端的 AI 回复
recv(function(raw) {
    try {
        var data = JSON.parse(raw);
        if (data.type === 'ai_response' && data.senderId) {
            var cbId = data.cbId;
            if (_callbacks[cbId]) {
                _callbacks[cbId](data.reply);
                delete _callbacks[cbId];
                
                // 更新对话上下文
                if (conversations[data.senderId]) {
                    conversations[data.senderId].push({role: 'assistant', content: data.reply});
                }
            }
        }
    } catch(e) {
        console.log('[MomoAI] recv error: ' + e);
    }
});

// ====== Hook 陌陌消息发送 ======

// Momo 消息发送 - Hook sendMessage 方法
// 陌陌的聊天页面类是 MomotalkViewController
var MomotalkViewController = ObjC.classes.MomotalkViewController;
if (MomotalkViewController) {
    console.log('[MomoAI] ✅ 找到 MomotalkViewController');
    
    // Hook 发送消息方法
    var sendMessage = MomotalkViewController['- sendMessageWithText:'];
    if (sendMessage) {
        Interceptor.attach(sendMessage.implementation, {
            onEnter: function(args) {
                var text = ObjC.Object(args[2]).toString();
                this.text = text;
                console.log('[MomoAI] 📤 发送消息: ' + text.substring(0, 50));
            }
        });
    }
    
    // Hook 收到消息后的数据处理
    // Momo 收到消息后会刷新对话列表，hook 刷新方法
    var reloadData = MomotalkViewController['- tableView:cellForRowAtIndexPath:'];
    if (reloadData) {
        // 这个方法调用太频繁，不适合直接hook
    }
    
    console.log('[MomoAI] ✅ Momo Hook 已加载，等待消息...');
} else {
    console.log('[MomoAI] ❌ 未找到 MomotalkViewController');
    console.log('[MomoAI]    Momo 可能未运行或类名已变更');
}

// ====== 通用消息 Hook ======
// 尝试 Hook 更底层的消息发送方法
var MMObject = ObjC.classes.MMObject;
if (MMObject) {
    console.log('[MomoAI] ✅ 找到 MMObject');
    
    // Hook 消息发送
    var sendMsg = MMObject['+ sendMessage:'];
    if (sendMsg) {
        Interceptor.attach(sendMsg.implementation, {
            onEnter: function(args) {
                console.log('[MomoAI] MMObject sendMessage called');
            }
        });
    }
}

// ====== 辅助：进程信息 ======
console.log('[MomoAI] 🔌 进程: ' + ObjC.classes.NSBundle.mainBundle().bundleIdentifier().toString());
console.log('[MomoAI] 📱 设备: ' + ObjC.classes.UIDevice.currentDevice().systemVersion().toString());

// 导出配置更新方法
function updateConfig(newConfig) {
    for (var key in newConfig) {
        if (CONFIG.hasOwnProperty(key)) {
            CONFIG[key] = newConfig[key];
        }
    }
    console.log('[MomoAI] ⚙️ 配置已更新');
}

// 导出到全局
rpc.exports = {
    updateconfig: function(newConfig) {
        updateConfig(JSON.parse(newConfig));
        return 'ok';
    },
    getstatus: function() {
        return JSON.stringify({
            hooked: !!MomotalkViewController,
            conversations: Object.keys(conversations).length,
            config: CONFIG
        });
    }
};

console.log('[MomoAI] 🚀 Momo AI Bot Frida 脚本已加载');
console.log('[MomoAI] 💡 使用 frida -U com.immomo.momo -l momo-ai-frida.js 连接');
