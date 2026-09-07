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

## 🚀 两种安装方式 (GitHub 用户 / 离线压缩包朋友)

### 方式 A：GitHub 快速一键安装（推荐）

在终端中执行以下单行命令即可自动完成克隆与部署：

```bash
git clone https://github.com/share53880/Coding-Earphone-Mode.git
cd Coding-Earphone-Mode
./scripts/install_local.sh
```

### 方式 B：离线安装包 / 分享压缩包一键安装（免 Git / 朋友分享）

1. 下载或解压分享包 `CodingEarphoneMode-v0.1.0-macOS.zip`；
2. 双击运行其中的 **`一键安装.command`**（若 macOS 拦截提示「来自未识别开发者」，右键点击选择「打开」即可）；
3. 脚本会自动编译并安装到个人目录，并注册 LaunchAgent 开机自启。

> 💡 **安装过程完全可逆**：安装不修改系统只读分区，不注入内核驱动，全部资产位于 `~/Library/Application Support/CodingEarphoneMode`，随时可一键完全恢复。

---

## 🔑 首次使用：授予辅助功能权限 (唯一必需步骤)

由于 macOS 安全机制，捕获耳机媒体按键并向编辑区合成按键必须获得辅助功能（Accessibility）授权：

1. 打开 **系统设置 -> 隐私与安全性 -> 辅助功能** (Privacy & Security -> Accessibility)；
2. 点击右下方 `+` 号，在弹出的文件选择器中按下快捷键：  
   `Cmd + Shift + G`
3. 复制并粘贴以下路径后回车：  
   `~/Library/Application Support/CodingEarphoneMode/bin/coding-earphone`
4. 点击「打开」并确认勾选开启。

> 🛡️ **安全保证**：本工具绝不需要关闭 SIP、绝不加载驱动、不篡改系统 TCC 数据库、不以 root 身份运行，完全工作在受限的用户安全空间。

---

## 🛠️ 日常管理与自愈指令

安装后，全局命令行工具 `coding-earphone` 已自动链接至终端 PATH：

```bash
# 1. 查看守护进程状态、当前前台应用与运行模式
coding-earphone status

# 2. 运行系统全项健康诊断 (检测转接头硬件、Accessibility 权限、Typeless 联动)
coding-earphone doctor

# 3. 幂等自愈与系统媒体键恢复 (若非正常退出或媒体键异常，一键恢复原生 rcd)
coding-earphone repair

# 4. 重启守护进程
coding-earphone restart

# 5. 启动 / 停止守护进程
coding-earphone start
coding-earphone stop
```

---

## 🗑️ 一键卸载与环境完全恢复

如果需要卸载或把电脑交给他人使用：

- **方式 1 (终端命令)**：运行 `./scripts/uninstall_local.sh`；
- **方式 2 (离线包用户)**：双击离线包内的 **`一键卸载.command`**。

卸载程序将：
1. 彻底退出守护进程并卸载 LaunchAgent 开机项；
2. **无条件强制复位 macOS 原生 `rcd` 媒体守护进程**，使耳机与键盘所有媒体控制 100% 恢复系统初始状态；
3. 删除 `~/Library/Application Support/CodingEarphoneMode` 与 CLI 链接。

---

## 🔍 环境自检与硬件兼容性矩阵

在安装或分享给朋友前，请通过 `coding-earphone doctor` 或下表确认环境：

| 硬件 / 软件组件 | 标准支持规格 (100% 验证) | 兼容性现状与说明 |
| :--- | :--- | :--- |
| **操作系统** | macOS Sonoma (14.0+) / Sequoia (15.0+) | ✅ Intel 与 Apple Silicon (M1/M2/M3/M4) 原生支持 |
| **耳机型号** | **Apple EarPods 3.5mm 有线耳机** | ✅ 采用 CTIA 标准线序与物理电阻阶梯，支持 12Hz 退格连发 |
| **耳机转接头** | **Apple 官方 USB-C 至 3.5mm 耳机插孔转换器** | ✅ 底层识别为标准 USB Audio Device，支持 Native HID 媒体流 |
| **副厂转接头** | 绿联 / 倍思等 DAC 转接头 | ⚠️ 部分副厂转接头不转发长按 Repeat 事件，单删正常但连删可能需短按多次 |
| **无线耳机** | AirPods / 索尼降噪耳机等 | ❌ 蓝牙协议音量由耳机本地消化，不发送系统 12Hz 键盘事件 |
| **目标编辑器** | **ChatGPT 桌面版 (Codex)** / **Antigravity IDE** | ✅ 锁定目标保护，防止在终端、浏览器或文档中误发按键 |
| **语音工具** | **Typeless Desktop** (默认快捷键: `Fn`) | ✅ 中键双向透传模拟 Fn，支持自动启停录音落盘与转写 |

> 💡 **Doctor 智能提示**：如果您插入了非官方转接头或未安装 Typeless，运行 `coding-earphone doctor` 会通过 `CONNECTED ✅` / `NOT CONNECTED ⚠️` 明确指出具体缺失项，绝不盲目崩溃。

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

