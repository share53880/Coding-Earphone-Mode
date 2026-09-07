# Coding Earphone Mode (耳机线控编程助手)

> **版本**: `v0.1.0` (Stage H7 Fully Certified / Daily-Use Ready)  
> **平台**: macOS 14+ / Darwin (Apple Silicon & Intel)  
> **依赖**: 苹果 3.5mm EarPods 线控耳机 + USB-C 官方转接头 + [Typeless Desktop](https://typeless.now)

---

## 💡 项目简介

`Coding Earphone Mode` 是专为 macOS 开发者打造的极简物理线控输入辅助工具。
无需低头看键盘或点击鼠标，通过手边 3.5mm 苹果线控耳机的三个物理按键，即可在 IDE 与 AI 聊天前台实现高频交互与语音录入。

### 🎮 键位映射设计

仅当前台处于 **Codex / ChatGPT** (`com.openai.codex`) 或 **Antigravity** (`com.google.antigravity`) 时激活：

| 耳机物理按键 | 映射按键 | 功能效果 |
| :--- | :--- | :--- |
| **中间键 (播放/暂停)** | 原生 `Fn` (KeyCode 63) | 联动唤起 / 停止 **Typeless** 语音麦克风，自动将转写文字填入输入框 |
| **音量 +** | `Return` (KeyCode 36) | 直接触发消息发送或代码换行（无系统音量 HUD 浮窗干扰） |
| **音量 −** | `Backspace` (KeyCode 51) | 单击删除单个字符；长按触发 ~12Hz 硬件 repeat 连续删除，松手即停 |

**无感应用穿透 (Passthrough)**：
- 切换到 **网易云音乐、Safari、访达 (Finder)** 等任何其他日常应用时，按键 **100% 恢复为 macOS 原生音量加减与音乐播放/暂停**，不拦截、不改写、零按键冲突。

---

## 🚀 极速安装与部署 (for 朋友快速上手)

### 1. 硬件连接
- 将 3.5mm 苹果线控耳机插入口径为 Type-C 的转接头；
- 插入 Mac 的 Type-C / 雷雳接口。

### 2. 本地一键安装
克隆本项目到本地，在终端中执行：

```bash
git clone <本仓库地址>
cd "耳机 coding"
./scripts/install_local.sh
```

- 该脚本会自动编译生产二进制并部署至 `~/Library/Application Support/CodingEarphoneMode`；
- 同时自动配置 `com.local.coding-earphone-mode` 开机自启动。

### 3. 授予 macOS 辅助功能权限
1. 打开 **系统设置 -> 隐私与安全性 -> 辅助功能**；
2. 点击 `+` 号，将 `~/Library/Application Support/CodingEarphoneMode/bin/coding-earphone` 添加并勾选开启。

### 4. 验证运行
在终端执行：
```bash
./scripts/coding-earphone doctor
```
全部检查呈现 `PASSED ✅` 即可戴上耳机开箱即用！

---

## 🛠️ 日常管理指令

工具已提供标准化 CLI 管理脚本：

```bash
# 查询当前前台应用、权限状态与工作模式
coding-earphone status

# 运行全面硬件与权限诊断
coding-earphone doctor

# 重启守护进程 (如遇登出后会话切换)
coding-earphone restart

# 启动 / 停止守护进程
coding-earphone start
coding-earphone stop
```

---

## 📂 项目架构与关键交付文档

- [`src/main.swift`](file:///Users/hanzhen/Documents/ChatGPT/耳机%20coding/src/main.swift): 核心守护进程源码（基于 POSIX flock 独占锁 + CGEventTap + NSWorkspace 监听）
- [`scripts/coding-earphone`](file:///Users/hanzhen/Documents/ChatGPT/耳机%20coding/scripts/coding-earphone): 日常统一管理 CLI 工具
- [`docs/DAILY_USE.md`](file:///Users/hanzhen/Documents/ChatGPT/耳机%20coding/docs/DAILY_USE.md): 终端用户极简日常使用指引
- [`CODING_EARPHONE_H7_INSTALLATION_REPORT.md`](file:///Users/hanzhen/Documents/ChatGPT/耳机%20coding/CODING_EARPHONE_H7_INSTALLATION_REPORT.md): Stage H7 生产安装与人工真实验收完整交付报告
- [`EARPHONE_FEASIBILITY_REPORT.md`](file:///Users/hanzhen/Documents/ChatGPT/耳机%20coding/EARPHONE_FEASIBILITY_REPORT.md): H0–H3 硬件与 EventTap 可行性研究报告

---

## 🛡️ 隐私与安全承诺

- **零内容记录**：本工具绝不记录用户的任何按键字符、代码内容或 Typeless 语音文本；
- **非侵入架构**：不修改系统 SIP、不加载外部内核驱动（kext）、不注入第三方应用进程；
- **一键干净卸载**：运行 `./scripts/uninstall_local.sh` 即可完全移除常驻配置与可执行文件，不留残余。
