# Stage H0: 耳机与转接头硬件设备检测报告

## 1. 检测环境与硬件

- **操作系统**: macOS 15.x / Darwin 25.x (Apple Silicon)
- **硬件设备**: 苹果 3.5mm EarPods 有线耳机 + Apple 官方 USB-C to 3.5mm Headphone Jack Adapter
- **检测时间**: 2026-09-07

---

## 2. 原生命令检测输出与设备标识

### 2.1 USB 设备识别 (`ioreg` / `system_profiler`)

```text
设备名称: USB-C to 3.5mm Headphone Jack Adapter
厂商 (Vendor): Apple, Inc.
Vendor ID (idVendor): 1452 (0x05ac)
Product ID (idProduct): 4362 (0x110a)
序列号 (Serial Number): <ANONYMIZED_SERIAL>
设备版本 (bcdDevice): 9808 (98.08)
传输协议 (Transport): USB (Link Speed: 12Mbps, Full Speed)
Location ID: 0x00100000 (1048576)
设备类别: bDeviceClass=239 (Miscellaneous), bDeviceSubClass=2 (Common Class)
```

### 2.2 音频接口识别 (`system_profiler SPAudioDataType`)

系统音频栈已成功识别该转接头并同时创建双向音频通道：

- **输出设备**: `USB-C转3.5毫米耳机插孔转换器`
  - Default Output Device: Yes
  - Manufacturer: Apple, Inc.
  - Output Channels: 2 (Stereo)
  - Current SampleRate: 44100 Hz
  - Transport: USB
- **输入设备**: `USB-C转3.5毫米耳机插孔转换器`
  - Input Channels: 1 (Mono Microphone)
  - Manufacturer: Apple, Inc.
  - Current SampleRate: 44100 Hz
  - Transport: USB

### 2.3 HID / Consumer Control 接口识别 (`hidutil list`)

通过 `hidutil list` 检查，该 USB-C 转接头注册了以下 HID 节点：

| VendorID | ProductID | LocationID | UsagePage | Usage | RegistryID | Transport | Class | Product | UserClass |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `0x5ac` | `0x110a` | `0x100000` | **12** (`0x0C`) | **1** (`0x01`) | `0x10008e817` | USB | AppleUserHIDEventService | USB-C to 3.5mm Headphone Jack Adapter | AppleUserHIDEventDriver |
| `0x5ac` | `0x110a` | `0x100000` | **12** (`0x0C`) | **1** (`0x01`) | `0x10008e803` | USB | AppleUserHIDDevice | USB-C to 3.5mm Headphone Jack Adapter | AppleUserUSBHostHIDDevice |
| `0x5ac` | `0x110a` | `0x100000` | **65280** (`0xFF00`) | **1** (`0x01`) | `0x10008e7fd` | USB | AppleUserHIDDevice | USB-C to 3.5mm Headphone Jack Adapter | AppleUserUSBHostHIDDevice |

---

## 3. 核心判定与结论

1. **是否暴露 HID / Consumer Control 输入设备？**
   - **是 (YES)**。
   - 设备明确暴露了 **UsagePage 12 (`0x0C` = Consumer Page)** 以及 **Usage 1 (`0x01` = Consumer Control)** 的标准 HID 节点。
   - 该节点由 `AppleUserHIDEventService` 与 `AppleUserHIDDevice` 驱动接管，完全具备向 macOS 系统上报媒体控制按键（播放/暂停、音量增大、音量减小等 Consumer Events）的物理和逻辑链路。

2. **硬件稳定唯一标识**:
   - **Vendor ID (VID)**: `0x05ac` (`1452`)
   - **Product ID (PID)**: `0x110a` (`4362`)
   - **Serial Number**: `<ANONYMIZED_SERIAL>` (具备芯片级独立序列号)
   - **Product Name**: `USB-C to 3.5mm Headphone Jack Adapter`

3. **Stage H0 验收结论**:
   - **PASS**。硬件检测通过，设备正常接入，HID Consumer Control 接口存在并就绪。
