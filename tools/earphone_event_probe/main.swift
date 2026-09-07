import Foundation
import CoreGraphics
import IOKit
import IOKit.hid
import AppKit

setbuf(stdout, nil)

print("==================================================")
print("🎧 Coding Earphone Mode - Event Probe Tool (Stage H1)")
print("==================================================")
print("Listening mode: Pure Monitor (No intercept, No modify)")
print("Probing:")
print("  1. CGEventTap (System-defined NX_SYSDEFINED / Media Keys / Key events)")
print("  2. IOHIDManager (Low-level HID Consumer / Telephony events)")
print("Press Ctrl+C to terminate probe.")
print("==================================================\n")

let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "HH:mm:ss.SSS"

func now() -> String {
    return dateFormatter.string(from: Date())
}

// -------------------------------------------------------------
// 1. IOHIDManager Setup
// -------------------------------------------------------------
let hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

// Match all devices so we capture any usage page from the adapter
IOHIDManagerSetDeviceMatching(hidManager, nil)

let hidCallback: IOHIDValueCallback = { context, result, sender, value in
    let element = IOHIDValueGetElement(value)
    let device = IOHIDElementGetDevice(element)
    
    let usagePage = IOHIDElementGetUsagePage(element)
    let usage = IOHIDElementGetUsage(element)
    let intVal = IOHIDValueGetIntegerValue(value)
    
    let prodName = (IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String) ?? "Unknown"
    let vendorId = (IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int) ?? 0
    let productId = (IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int) ?? 0
    let serial = (IOHIDDeviceGetProperty(device, kIOHIDSerialNumberKey as CFString) as? String) ?? "N/A"
    
    let isAdapter = (vendorId == 0x5ac && productId == 0x110a)
    let isConsumer = (usagePage == 0x0C)
    
    // Ignore high frequency pointer / trackpad / mouse movements unless it is our adapter
    if !isAdapter && (usagePage == 1 && (usage == 0x30 || usage == 0x31 || usage == 0x38)) {
        return
    }
    // Also ignore temperature / battery sensors (0xFF00) unless it is our adapter
    if !isAdapter && usagePage >= 0xFF00 {
        return
    }
    
    // Filter noise: if intVal == 0 and not relevant, still show transitions
    var usageMeaning = "Usage \(usage)"
    if usagePage == 0x0C {
        switch usage {
        case 0xCD: usageMeaning = "Play/Pause (0xCD)"
        case 0xE9: usageMeaning = "Volume Increment / Up (0xE9)"
        case 0xEA: usageMeaning = "Volume Decrement / Down (0xEA)"
        case 0xE2: usageMeaning = "Mute (0xE2)"
        case 0xB0: usageMeaning = "Play (0xB0)"
        case 0xB1: usageMeaning = "Pause (0xB1)"
        case 0xB5: usageMeaning = "Scan Next Track (0xB5)"
        case 0xB6: usageMeaning = "Scan Previous Track (0xB6)"
        case 0xB7: usageMeaning = "Stop (0xB7)"
        default: usageMeaning = "Consumer(0x\(String(usage, radix: 16)))"
        }
    }
    
    print("[\(now())] [IOHID] Device: '\(prodName)' (VID: 0x\(String(vendorId, radix: 16)), PID: 0x\(String(productId, radix: 16)), SN: \(serial))")
    print("           UsagePage: 0x\(String(usagePage, radix: 16)) (\(usagePage)), Usage: 0x\(String(usage, radix: 16)) (\(usageMeaning)), Value: \(intVal)")
    fflush(stdout)
}

IOHIDManagerRegisterInputValueCallback(hidManager, hidCallback, nil)
IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
let openStatus = IOHIDManagerOpen(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
if openStatus != kIOReturnSuccess {
    print("⚠️ Warning: IOHIDManagerOpen returned \(openStatus). HID events might need Input Monitoring permissions.")
} else {
    print("✅ IOHIDManager initialized and listening to Consumer Control devices.")
}

// -------------------------------------------------------------
// 2. CGEventTap Setup (NX_SYSDEFINED + Key events)
// -------------------------------------------------------------
let eventMask = (1 << CGEventType.keyDown.rawValue) |
                (1 << CGEventType.keyUp.rawValue) |
                (1 << CGEventType.flagsChanged.rawValue) |
                (1 << 14) // 14 == NX_SYSDEFINED / SystemDefined

func tapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    let rawType = type.rawValue
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags.rawValue
    
    if rawType == 14 { // NX_SYSDEFINED
        let nsEvent = NSEvent(cgEvent: event)
        let subtype = nsEvent?.subtype.rawValue ?? -1
        let data1 = nsEvent?.data1 ?? 0
        let data2 = nsEvent?.data2 ?? 0
        
        // SystemDefined Media Key parsing
        // In data1: (keyCode << 16) | (keyFlags)
        // keyFlags: (keyState << 8) | (keyRepeat)
        let mediaKeyCode = (data1 & 0xFFFF0000) >> 16
        let keyFlags = data1 & 0x0000FFFF
        let keyState = (keyFlags & 0xFF00) >> 8 // 0xA (down=10), 0xB (up=11)
        let keyRepeat = keyFlags & 0x1
        
        var mediaKeyName = "Code \(mediaKeyCode)"
        switch mediaKeyCode {
        case 0: mediaKeyName = "NX_KEYTYPE_SOUND_UP (Volume +)"
        case 1: mediaKeyName = "NX_KEYTYPE_SOUND_DOWN (Volume -)"
        case 16: mediaKeyName = "NX_KEYTYPE_PLAY (Play/Pause)"
        case 7: mediaKeyName = "NX_KEYTYPE_MUTE (Mute)"
        case 19: mediaKeyName = "NX_KEYTYPE_FAST (Next)"
        case 20: mediaKeyName = "NX_KEYTYPE_REWIND (Previous)"
        default: mediaKeyName = "NX_KEYTYPE_\(mediaKeyCode)"
        }
        
        let stateStr = keyState == 0xA ? "DOWN" : (keyState == 0xB ? "UP" : "STATE_\(keyState)")
        
        print("[\(now())] [CGEventTap:SYSDEFINED] Type: 14, Subtype: \(subtype), Data1: 0x\(String(data1, radix: 16)), Data2: 0x\(String(data2, radix: 16))")
        print("           Parsed: Key=\(mediaKeyName), State=\(stateStr), Repeat=\(keyRepeat), Flags=0x\(String(flags, radix: 16))")
        fflush(stdout)
    } else {
        var typeName = "Other(\(rawType))"
        switch type {
        case .keyDown: typeName = "KeyDown"
        case .keyUp: typeName = "KeyUp"
        case .flagsChanged: typeName = "FlagsChanged"
        default: break
        }
        print("[\(now())] [CGEventTap:KEY] Type: \(typeName), KeyCode: \(keyCode), Flags: 0x\(String(flags, radix: 16))")
        fflush(stdout)
    }
    
    // Listen-only: return original event without modifying
    return Unmanaged.passRetained(event)
}

if let port = CGEvent.tapCreate(
    tap: .cghidEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: CGEventMask(eventMask),
    callback: tapCallback,
    userInfo: nil
) {
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
    CGEvent.tapEnable(tap: port, enable: true)
    print("✅ CGEventTap created successfully at cghidEventTap.")
} else {
    print("⚠️ Notice: CGEventTap creation failed at cghidEventTap (May need Accessibility permission). Attempting sessionEventTap...")
    if let port2 = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .listenOnly,
        eventsOfInterest: CGEventMask(eventMask),
        callback: tapCallback,
        userInfo: nil
    ) {
        let source2 = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port2, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source2, .commonModes)
        CGEvent.tapEnable(tap: port2, enable: true)
        print("✅ CGEventTap created successfully at cgSessionEventTap.")
    } else {
        print("❌ Warning: CGEventTap could not be created. Please grant Accessibility permissions if needed.")
    }
}

print("\n🚀 Event Probe is RUNNING. Please perform tests on earphone buttons...")
CFRunLoopRun()
