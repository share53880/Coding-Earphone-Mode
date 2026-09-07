# Coding Earphone Mode 日常使用指南 (Daily Use Guide)

> **版本**: 0.1.0 (Production Release)  
> **状态**: 已安装至本机用户空间，支持开机/登录自动运行与前台无感自动切换。

---

## 1. 日常是否需要手动启动？

**不需要**。
- 软件已配置开机/用户登录自启动。
- 耳机插入 USB-C 转接头后，只要前台切换到 **Codex (ChatGPT)** 或 **Antigravity**，按键映射即刻生效。
- 切换到 Safari、Finder、音乐等其他应用时，耳机自动恢复系统原始的音量调节与播放控制。

---

## 2. 如何查看当前运行状态？

在终端运行以下命令：

```bash
./scripts/coding-earphone status
```

输出示例：
```text
==================================================
📊 Coding Earphone Mode Status
==================================================
installed:             yes (~/Library/Application Support/CodingEarphoneMode/bin/coding-earphone)
launch_agent_loaded:   yes (com.local.coding-earphone-mode)
process_running:       yes
pid:                   86923
version:               coding-earphone version 0.1.0 (H7.Release)
binary_sha256:         91a392076747dced8835b582ba5bcb70e00c17c8673c01cf352d2d769a3ddbc7
permission_status:     Accessibility (GRANTED ✅)
current_foreground_app: Antigravity (com.google.antigravity)
mode:                  ACTIVE
==================================================
```

- `mode: ACTIVE` 表示当前前台是 Codex 或 Antigravity，耳机按键正在映射。
- `mode: PASSTHROUGH` 表示当前前台是普通应用，耳机保持原生系统功能。

---

## 3. 如何临时暂停？

如果需要临时停止耳机映射，恢复所有应用下的原生音量控制：

```bash
./scripts/coding-earphone stop
```

- 执行后立即释放系统按键钩子，0% 键盘残留。

---

## 4. 如何恢复 / 重新启动？

```bash
./scripts/coding-earphone start
```

- 若已在运行，会自动检测并提示 `ALREADY_RUNNING`，绝不会产生重复进程。

---

## 5. 权限失效或系统异常时怎么办？

运行内置诊断工具一键体检：

```bash
./scripts/coding-earphone doctor
```
或：
```bash
./scripts/check_permissions.sh
```

- 若提示 `Accessibility: DENIED ❌`：
  1. 打开 **系统设置 -> 隐私与安全性 -> 辅助功能**；
  2. 确认 `coding-earphone` 处于开启状态。
- 若拔插耳机后偶发无反应，只需运行一次 `./scripts/coding-earphone restart` 即可。

---

## 6. 如何完整卸载？

若不再需要此工具，运行一键卸载脚本：

```bash
./scripts/uninstall_local.sh
```

- 脚本会自动停止常驻进程、注销 LaunchAgent、删除用户配置与日志目录。
- **绝对不触碰** 您的 Git 代码仓库、Typeless 软件及其他任何系统文件。
