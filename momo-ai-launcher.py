#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Momo AI Bot - Frida Windows 启动器
===================================
无需 macOS/Linux/Theos，Windows 直接使用 Frida 注入陌陌
实现 AI 自动回复 + 对话记忆 + 句数触发

使用方法:
  python momo-ai-launcher.py --api-key sk-xxx

依赖:
  pip install frida-tools

支持:
  - USB 连接越狱 iPhone（需安装 frida-server）
  - 通过 OpenAI API 智能回复
  - 多对话独立上下文记忆
  - 句数触发自动发图/话术
  - 模拟真人输入延迟
"""

import frida
import sys
import json
import time
import threading
import urllib.request
import urllib.error
import random
import os
import argparse
from datetime import datetime

# ========== 配置 ==========
CONFIG = {
    "api_key": None,
    "model": "gpt-4o-mini",
    "system_prompt": "你是一个普通朋友，正在和对方聊天。用自然的中文回复，语气贴近日常对话。尽量简短（不超过50字）。",
    "trigger_count": 10,
    "reply_delay_min": 2,
    "reply_delay_max": 8,
    "auto_reply": True,
    "use_image_trigger": False,
    "use_text_trigger": False,
    "custom_texts": ["在忙什么呢？", "哈哈好的", "嗯嗯", "刚看到", "好的吧"],
}

# 对话上下文
conversations = {}
message_counts = {}

# Frida
session = None
script = None
stopped = False


def ask_openai(message, sender_id, system_prompt, model, api_key):
    """调用 OpenAI API 获取 AI 回复"""
    if sender_id not in conversations:
        conversations[sender_id] = []
    
    conversations[sender_id].append({"role": "user", "content": message})
    if len(conversations[sender_id]) > 20:
        conversations[sender_id] = conversations[sender_id][-20:]
    
    messages = [{"role": "system", "content": system_prompt}]
    messages.extend(conversations[sender_id])
    
    # 计数触发
    if sender_id not in message_counts:
        message_counts[sender_id] = 0
    message_counts[sender_id] += 1
    
    try:
        data = json.dumps({
            "model": model,
            "messages": messages,
            "max_tokens": 150,
            "temperature": 0.8,
        }).encode("utf-8")
        
        req = urllib.request.Request(
            "https://api.openai.com/v1/chat/completions",
            data=data,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
        )
        
        resp = urllib.request.urlopen(req, timeout=30)
        result = json.loads(resp.read())
        reply = result["choices"][0]["message"]["content"].strip()
        
        conversations[sender_id].append({"role": "assistant", "content": reply})
        
        # 检查是否触发动作
        trigger_action = None
        if message_counts[sender_id] >= CONFIG["trigger_count"]:
            message_counts[sender_id] = 0
            if CONFIG["use_image_trigger"]:
                trigger_action = "image"
            elif CONFIG["use_text_trigger"]:
                trigger_action = "text"
        
        return reply, trigger_action
    
    except urllib.error.HTTPError as e:
        error_body = e.read().decode()
        print(f"  [MomoAI] ❌ API错误: {e.code} - {error_body[:200]}")
        return "抱歉，我现在有点忙，稍后再聊~", None
    except Exception as e:
        print(f"  [MomoAI] ❌ 网络错误: {e}")
        return "好的呢", None


def on_message(message, data):
    """处理从 Frida JS 脚本发来的消息"""
    if message["type"] == "send":
        try:
            payload = json.loads(message["payload"])
            if payload["type"] == "ask_ai":
                handle_ai_request(payload)
        except json.JSONDecodeError:
            pass
    elif message["type"] == "error":
        print(f"  [MomoAI] ❌ Frida错误: {message.get('description', '')}")


def handle_ai_request(payload):
    """处理 AI 回复请求"""
    msg = payload["message"]
    sender_id = payload["senderId"]
    system_prompt = payload.get("systemPrompt", CONFIG["system_prompt"])
    model = payload.get("model", CONFIG["model"])
    api_key = payload.get("apiKey", CONFIG["api_key"])
    
    cb_id = payload.get("cbId", "")
    
    print(f"  [MomoAI] 🤔 正在生成回复...")
    
    # 模拟延迟
    delay = random.uniform(CONFIG["reply_delay_min"], CONFIG["reply_delay_max"])
    print(f"  [MomoAI] ⏱️ 模拟延迟 {delay:.1f}秒")
    time.sleep(delay)
    
    reply, trigger = ask_openai(msg, sender_id, system_prompt, model, api_key)
    
    print(f"  [MomoAI] 💬 AI回复: {reply[:80]}...")
    
    if trigger:
        print(f"  [MomoAI] 🔔 触发动作: {trigger}")
    
    # 发送回复回 JS 脚本
    response = {
        "type": "ai_response",
        "senderId": sender_id,
        "reply": reply,
        "cbId": cb_id,
    }
    
    if script:
        script.post(json.dumps(response))


def load_script(js_path):
    """加载 Frida JS 脚本"""
    global script
    
    with open(js_path, "r", encoding="utf-8") as f:
        js_code = f.read()
    
    script = session.create_script(js_code)
    script.on("message", on_message)
    script.load()
    print("  [MomoAI] ✅ Frida 脚本已加载")
    
    # 更新配置到 JS
    update_js_config()


def update_js_config():
    """将 Python 配置同步到 JS 脚本"""
    config_for_js = {
        "apiKey": CONFIG["api_key"],
        "model": CONFIG["model"],
        "systemPrompt": CONFIG["system_prompt"],
        "triggerCount": CONFIG["trigger_count"],
        "replyDelayMin": CONFIG["reply_delay_min"],
        "replyDelayMax": CONFIG["reply_delay_max"],
        "autoReply": CONFIG["auto_reply"],
        "useImageTrigger": CONFIG["use_image_trigger"],
        "useTextTrigger": CONFIG["use_text_trigger"],
        "customTexts": CONFIG["custom_texts"],
    }
    
    try:
        script.exports.updateconfig(json.dumps(config_for_js))
        print("  [MomoAI] ⚙️ 配置已同步到 Frida")
    except Exception as e:
        print(f"  [MomoAI] ⚠️ 配置同步失败: {e}")


def attach_to_momo(device):
    """附加到 Momo 进程"""
    global session
    
    try:
        # 尝试通过进程名附加
        session = device.attach("com.immomo.momo")
        print(f"  [MomoAI] ✅ 已连接到 Momo 进程")
        return True
    except frida.ProcessNotFoundError:
        print("  [MomoAI] ❌ Momo 未运行，请先打开陌陌App")
        return False
    except Exception as e:
        print(f"  [MomoAI] ❌ 连接失败: {e}")
        return False


def print_banner():
    """打印启动横幅"""
    banner = """
╔══════════════════════════════════════════════╗
║     Momo AI Bot - Frida Windows 启动器       ║
║     无需 Theos / macOS / Linux               ║
║    适用于越狱 iPhone + Frida                 ║
╚══════════════════════════════════════════════╝
"""
    print(banner)


def print_status():
    """打印状态信息"""
    print(f"\n  [MomoAI] 📊 状态")
    print(f"  ─────────────────────────")
    print(f"  AI: {'✅ 已启用' if CONFIG['auto_reply'] else '❌ 已禁用'}")
    print(f"  API Key: {'✅ 已配置' if CONFIG['api_key'] else '❌ 未配置'}")
    print(f"  模型: {CONFIG['model']}")
    print(f"  触发句数: {CONFIG['trigger_count']}句")
    print(f"  回复延迟: {CONFIG['reply_delay_min']}-{CONFIG['reply_delay_max']}秒")
    print(f"  对话数: {len(conversations)}")
    print(f"  触发动作: ", end="")
    actions = []
    if CONFIG["use_image_trigger"]: actions.append("发图")
    if CONFIG["use_text_trigger"]: actions.append("发话术")
    print(f"{'、'.join(actions) if actions else '无'}")


def main():
    parser = argparse.ArgumentParser(description="Momo AI Bot - Frida Windows 启动器")
    parser.add_argument("--api-key", help="OpenAI API Key", default=os.environ.get("OPENAI_API_KEY"))
    parser.add_argument("--model", help="AI模型 (默认: gpt-4o-mini)", default="gpt-4o-mini")
    parser.add_argument("--trigger", type=int, help=f"触发句数 (默认: {CONFIG['trigger_count']})", default=CONFIG["trigger_count"])
    parser.add_argument("--delay-min", type=int, help=f"最小延迟秒数 (默认: {CONFIG['reply_delay_min']})", default=CONFIG["reply_delay_min"])
    parser.add_argument("--delay-max", type=int, help=f"最大延迟秒数 (默认: {CONFIG['reply_delay_max']})", default=CONFIG["reply_delay_max"])
    parser.add_argument("--image-trigger", action="store_true", help="启用句数触发发图")
    parser.add_argument("--text-trigger", action="store_true", help="启用句数触发发话术")
    parser.add_argument("--js", help="Frida JS 脚本路径", default="momo-ai-frida.js")
    
    args = parser.parse_args()
    
    if not args.api_key:
        print("❌ 请提供 OpenAI API Key")
        print("   python momo-ai-launcher.py --api-key sk-xxx")
        print("   或设置环境变量: set OPENAI_API_KEY=sk-xxx")
        return
    
    # 更新配置
    CONFIG["api_key"] = args.api_key
    CONFIG["model"] = args.model
    CONFIG["trigger_count"] = args.trigger
    CONFIG["reply_delay_min"] = args.delay_min
    CONFIG["reply_delay_max"] = args.delay_max
    CONFIG["use_image_trigger"] = args.image_trigger
    CONFIG["use_text_trigger"] = args.text_trigger
    
    print_banner()
    
    # 连接设备
    print("  [MomoAI] 🔌 正在连接 iPhone...")
    try:
        device = frida.get_usb_device(timeout=5)
        print(f"  [MomoAI] ✅ 已检测到设备: {device.name}")
    except frida.InvalidArgumentError:
        print("  [MomoAI] ❌ 未检测到 iPhone")
        print("  [MomoAI]    1. 确保 iPhone 通过 USB 连接")
        print("  [MomoAI]    2. 确保已安装 frida-server")
        print("  [MomoAI]    3. 手机上运行: frida-server -l 0.0.0.0")
        return
    except Exception as e:
        print(f"  [MomoAI] ❌ 设备连接失败: {e}")
        return
    
    # 附加到 Momo
    if not attach_to_momo(device):
        return
    
    # 加载脚本
    js_path = os.path.join(os.path.dirname(__file__), args.js)
    if not os.path.exists(js_path):
        js_path = args.js
    if not os.path.exists(js_path):
        print(f"  [MomoAI] ❌ 找不到 Frida 脚本: {js_path}")
        return
    
    load_script(js_path)
    print_status()
    
    print(f"\n  [MomoAI] 🚀 Momo AI Bot 已启动！")
    print(f"  [MomoAI] 💡 在陌陌中收到消息将自动回复")
    print(f"  [MomoAI] 🛑 按 Ctrl+C 停止\n")
    
    # 保持运行
    try:
        while not stopped:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n  [MomoAI] 👋 正在退出...")
    finally:
        if session:
            session.detach()
        print("  [MomoAI] ✅ 已断开")


if __name__ == "__main__":
    main()
