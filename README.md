# Coding Earphone Mode (耳机线控编程助手)

> 把 3.5mm 苹果有线耳机线控变成 macOS AI Coding 快捷控制器。  
> 适合希望在 Codex (ChatGPT) / Antigravity 中使用语音输入，同时尽量减少触碰键盘的人。

---

## 🎮 标准环境与键位映射

当前已验证的标准环境：
- **系统**: macOS 14+ (Apple Silicon M 系列 & Intel)
- **硬件**: 苹果官方 3.5mm EarPods 有线耳机 + USB-C 官方转接头
- **软件**: ChatGPT (Codex) / Antigravity IDE + [Typeless Desktop](https://typeless.now)
- **Typeless 快捷键**: 保持默认的 `Fn`

在此环境下，耳机线控按键映射如下：

| 耳机按键 | Coding 模式 (Codex / Antigravity 前台) | 非目标应用 (Music / Safari / 访达) |
| :--- | :--- | :--- |
| **中间键 (Play/Pause)** | **Typeless 开始 / 结束语音录入** | 保持原生：播放 / 暂停 |
| **音量 +** | **Enter / 发送消息或换行** | 保持原生：系统音量增大 |
| **音量 −** | **Backspace / 单击删除一个字符** | 保持原生：系统音量降低 |
| **长按音量 −** | **连续 Backspace (利用硬件 12Hz repeat 连发)** | 保持原生：连续降低音量 |

> 💡 **无需手动切换模式**：当焦点在 Codex / Antigravity 时自动开启；切到网易云音乐、Safari 时自动恢复系统原始媒体控制。

---

## 💡 这个工具解决什么问题？

传统的语音 Coding 往往依然频繁离不开键盘：
1. 按键盘快捷键启动语音输入；
2. 说话；
3. 再按快捷键结束录音；
4. 移动鼠标点击或按 Enter 发送；
5. 说错时再伸手去按 Delete 修改。

有了 Coding Earphone Mode，手无需抬到键盘上，握着耳机线控即可盲操：  
👉 **按中键 → 说话 → 再按中键 → 音量+ 发送！**  
👉 **如果需要修改，按音量− 单删，长按音量− 连删。**

---

## 🚀 极速安装与部署

### 推荐方式：克隆或下载后一键安装

在终端执行：

```bash
git clone https://github.com/share53880/Coding-Earphone-Mode.git
cd Coding-Earphone-Mode
./scripts/install_local.sh
```

脚本会自动：
1. 编译优化版常驻二进制；
2. 安装至独立用户目录：`~/Library/Application Support/CodingEarphoneMode`；
3. 注册 macOS LaunchAgent 实现开机/登录自动静默运行；
4. 建立单实例保护，杜绝重复进程冲突。

---

## 🔑 首次使用需要的 macOS 权限

因为程序需要捕获耳机媒体键并合成键盘事件，首次使用需要授予系统辅助功能权限：

1. 打开 **系统设置 -> 隐私与安全性 -> 辅助功能** (Privacy & Security -> Accessibility)；
2. 点击右下方 `+` 号，按下快捷键 `Cmd + Shift + G`，输入：  
   `~/Library/Application Support/CodingEarphoneMode/bin/`
3. 选择 `coding-earphone` 并确认勾选开启。

> 🛡️ **安全保证**：本工具绝不需要关闭 SIP、绝不加载第三方驱动、绝不篡改系统 TCC 数据库、不以 root 身份运行，完全工作在受限的用户空间。

---

## 🛠️ 日常管理指令

安装后，您在终端中可以随时使用管理指令：

```bash
# 查看当前守护进程状态、前台应用、权限与模式
coding-earphone status

# 运行系统诊断 (硬件、权限、Typeless 联动)
coding-earphone doctor

# 平滑重启守护进程
coding-earphone restart

# 启动 / 停止守护进程
coding-earphone start
coding-earphone stop
```

---

## 🗑️ 如何完整卸载

如果不再需要该工具，运行一键卸载脚本即可彻底清除：

```bash
./scripts/uninstall_local.sh
```

卸载操作只会安全删除工具自身目录、LaunchAgent 及日志，绝对不影响 Typeless、Codex、Antigravity 或其他系统配置。

---

## 🔒 隐私与日志保护

- **绝对不记录内容**：本工具绝不记录用户说了什么、绝不记录 Typeless 语音转写文字、绝不记录 Prompt 和键盘输入的任何文本；
- **轻量日志审计**：日志仅用于记录进程启停与前台应用切换（如 `App Switch: ChatGPT -> ACTIVE`），且限制在 2MB 内自动轮转。

---

## 🗺️ 后续版本路线 (Roadmap)

- [x] **V1.0 (Share Edition)**: 核心事件拦截、硬件 12Hz Repeat、Fn 模拟、前台自动判断、LaunchAgent 常驻、一键安装与卸载。
- [ ] **V1.1 (Compatibility Setup)**: 增加非标准耳机与转接头自适应校准向导，支持不同媒体键码映射。
- [ ] **V1.2 (App Mapping)**: 支持通过配置文件自由增加目标 App（如 VS Code、Cursor、Terminal 等）。
