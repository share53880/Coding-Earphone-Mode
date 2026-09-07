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

## ⚠️ 适用与不适用条件声明 (重要)

在下载或安装前，请务必确认您的使用环境：

### ✅ 适用条件（100% 验证支持）
1. **电脑**: macOS 14 及以上系统（Apple Silicon M 系列芯片或 Intel 芯片均可）；
2. **耳机硬件**: **苹果原装 3.5mm EarPods 有线耳机 + USB-C 官方转接头**（只有该硬件能产生稳定的 12Hz 硬件脉冲与标准媒体键码）；
3. **目标应用**: 当前前台激活窗口为 **ChatGPT 桌面版 (Codex)** 或 **Antigravity IDE**；
4. **语音工具**: 已安装运行 **Typeless**，且快捷键保持默认的 **`Fn`**。

### ❌ 暂不适用条件（当前版本暂未开放）
1. **无线蓝牙耳机（如 AirPods、索尼等）**: 蓝牙耳机音量调节由耳机内部固件控制，不会向 Mac 发送 ~12Hz 连续按键事件，长按连删无法生效；
2. **安卓 3.5mm 耳机或部分副厂转接头**: 线序标准不同（CTIA vs OMTP），可能无法识别中间键或产生错误键码；
3. **其他代码编辑器（如 VS Code、Cursor、Xcode 等）**: 为防止代码误触，当前版本严格锁定只对 ChatGPT 和 Antigravity 生效；
4. **自定义了 Typeless 快捷键**: 若将 Typeless 改为 `Option + Space` 等组合键，当前版本派发的原生 `Fn` 将无法调出麦克风。

---

## 🗺️ 后续版本路线 (Roadmap)

为了让更多朋友和不同软硬件环境的用户也能享受耳机 Vibe Coding，我们规划了以下迭代：

- [x] **V1.0 (Standard Share Edition / 当前版本)**:
  - 核心事件拦截与注入（基于 `CGEventTap` 与 `flock` 独占锁）；
  - 硬件原生 12Hz Repeat 连发 Backspace；
  - 模拟原生 `Fn` 键完美联动 Typeless 语音转写；
  - 基于 `NSWorkspace` 的毫秒级前台应用自动感知与非目标应用 100% 原生透传；
  - macOS `LaunchAgent` 用户级静默常驻开机自启；
  - 提供完整的一键安装、卸载与全局 CLI 诊断。

- [ ] **V1.1 (Compatibility Setup / 硬件兼容校准向导)**:
  - **核心目标**: 解决非标准耳机与不同品牌 USB-C 转接头的兼容性；
  - **自适应向导**: 提供可视化的简单按键校准工具（插入耳机后按提示依次按“中键”、“音量+”、“音量−”）；
  - **自动录制特征**: 自动捕获并记录该耳机的底层 HID / Consumer Control 键码及长按 Repeat 特征，生成本机专属硬件配置 profile。

- [ ] **V1.2 (App & Shortcut Mapping / 自定义编辑器与快捷键)**:
  - **核心目标**: 解除编辑器与快捷键限制，让任何 IDE 都能一键 Vibe Coding；
  - **自定义目标 App**: 允许用户在配置文件中自由添加目标应用的 Bundle ID（如 VS Code `com.microsoft.VSCode`、Cursor `com.todesktop.230313mzl4w4u92`、Terminal、iTerm2 等）；
  - **自定义快捷键映射**: 支持将 Typeless 或其他语音工具的启动按键自定义为任意组合键（如 `Ctrl + Opt + Space` 等）；
  - **多 App 独立配置**: 支持为不同编辑器配置不同的发送键（例如 VS Code 映射为 `Enter`，某 AI 插件映射为 `Cmd + Enter`）。

