import Foundation
import CoreGraphics
import AppKit

setbuf(stdout, nil)

// ==============================================================================
// Coding Earphone Mode V0.1
// Architecture:
// 1. AppTracker: Real-time foreground app bundle identifier observer via NSWorkspace
// 2. KeySynthesizer: Low-latency synthetic Return (36), Backspace (51), and Fn (63)
// 3. EventTapManager: CGEventTap filter at cghidEventTap for media keys (14)
// ==============================================================================

let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "HH:mm:ss.SSS"
func now() -> String {
    return dateFormatter.string(from: Date())
}

// ------------------------------------------------------------------------------
// 1. App Tracker
// ------------------------------------------------------------------------------
final class AppTracker {
    static let shared = AppTracker()
    
    private let lock = NSLock()
    private var _currentBundleId: String = ""
    private var _currentAppName: String = ""
    
    let targetBundleIds: Set<String> = [
        "com.openai.codex",
        "com.google.antigravity"
    ]
    
    var currentBundleId: String {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _currentBundleId
        }
        set {
            lock.lock()
            _currentBundleId = newValue
            lock.unlock()
        }
    }
    
    var isCodingActive: Bool {
        let bid = currentBundleId
        if bid.isEmpty {
            if let front = NSWorkspace.shared.frontmostApplication {
                return targetBundleIds.contains(front.bundleIdentifier ?? "")
            }
        }
        return targetBundleIds.contains(bid)
    }
    
    func start() {
        if let front = NSWorkspace.shared.frontmostApplication {
            self._currentBundleId = front.bundleIdentifier ?? ""
            self._currentAppName = front.localizedName ?? "App"
        }
        print("[\(now())] Initial Frontmost App: \(_currentAppName) (\(_currentBundleId)) -> CodingMode: \(isCodingActive ? "ENABLED 🟢" : "DISABLED ⚪")")
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self = self else { return }
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                let bid = app.bundleIdentifier ?? ""
                let name = app.localizedName ?? "App"
                self.currentBundleId = bid
                self._currentAppName = name
                let active = self.isCodingActive
                print("[\(now())] 🔄 App Switch: \(name) (\(bid)) -> Mode: \(active ? "CODING 🟢 (Middle=Fn, +=Enter, -=Backspace)" : "PASSTHROUGH ⚪ (Native Audio/Volume)")")
            }
        }
    }
}

// ------------------------------------------------------------------------------
// 2. Key Synthesizer
// ------------------------------------------------------------------------------
struct KeySynthesizer {
    static let magicSignature: Int64 = 0x434F4445 // "CODE"
    static let workerQueue = DispatchQueue(label: "coding.earphone.synthesizer", qos: .userInteractive)
    
    static func sendKey(keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }
        keyDown.setIntegerValueField(.eventSourceUserData, value: magicSignature)
        keyUp.setIntegerValueField(.eventSourceUserData, value: magicSignature)
        
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
    
    static func sendFnAsync() {
        workerQueue.async {
            let source = CGEventSource(stateID: .hidSystemState)
            guard let down = CGEvent(source: source),
                  let up = CGEvent(source: source) else { return }
            
            // Fn press (flagsChanged, keycode 63, maskSecondaryFn)
            down.type = .flagsChanged
            down.setIntegerValueField(.keyboardEventKeycode, value: 63)
            down.flags = [.maskSecondaryFn]
            down.setIntegerValueField(.eventSourceUserData, value: magicSignature)
            down.post(tap: .cghidEventTap)
            
            Thread.sleep(forTimeInterval: 0.05)
            
            // Fn release
            up.type = .flagsChanged
            up.setIntegerValueField(.keyboardEventKeycode, value: 63)
            up.flags = []
            up.setIntegerValueField(.eventSourceUserData, value: magicSignature)
            up.post(tap: .cghidEventTap)
        }
    }
}

// ------------------------------------------------------------------------------
// 3. Event Tap Manager (Filter Mode)
// ------------------------------------------------------------------------------
final class EventTapManager {
    static let shared = EventTapManager()
    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    func start() -> Bool {
        let eventMask = (1 << 14) // NX_SYSDEFINED
        
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            // Handle tap disable recovery
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let port = EventTapManager.shared.machPort {
                    CGEvent.tapEnable(tap: port, enable: true)
                }
                return nil
            }
            
            // Filter only NX_SYSDEFINED
            guard type.rawValue == 14 else {
                return Unmanaged.passRetained(event)
            }
            
            // Check if synthetic event generated by us
            let userData = event.getIntegerValueField(.eventSourceUserData)
            if userData == KeySynthesizer.magicSignature {
                return Unmanaged.passRetained(event)
            }
            
            let nsEvent = NSEvent(cgEvent: event)
            guard nsEvent?.subtype.rawValue == 8 else {
                return Unmanaged.passRetained(event)
            }
            
            let data1 = nsEvent?.data1 ?? 0
            let mediaKeyCode = (data1 & 0xFFFF0000) >> 16
            let keyFlags = data1 & 0x0000FFFF
            let keyState = (keyFlags & 0xFF00) >> 8 // 0xA = down, 0xB = up
            let keyRepeat = keyFlags & 0x1
            
            // Check if coding mode is active for current frontmost app
            let isCoding = AppTracker.shared.isCodingActive
            
            // If not coding mode, pass through completely
            if !isCoding {
                return Unmanaged.passRetained(event)
            }
            
            // Coding mode active: Intercept and map the 3 keys
            switch mediaKeyCode {
            case 16: // NX_KEYTYPE_PLAY (Middle button)
                if keyState == 0xA && keyRepeat == 0 {
                    print("[\(now())] [INTERCEPT] Middle Button -> Synthesizing Fn (Typeless toggle)")
                    KeySynthesizer.sendFnAsync()
                }
                // Suppress original event to prevent system media playback
                return nil
                
            case 0: // NX_KEYTYPE_SOUND_UP (Volume +)
                if keyState == 0xA && keyRepeat == 0 {
                    print("[\(now())] [INTERCEPT] Volume + -> Synthesizing Return/Enter")
                    KeySynthesizer.sendKey(keyCode: 36) // kVK_Return = 36
                }
                // Suppress original event to prevent system volume increase
                return nil
                
            case 1: // NX_KEYTYPE_SOUND_DOWN (Volume -)
                if keyState == 0xA {
                    // Both single click (repeat=0) and hardware hold repeat (repeat=1)
                    let repeatStr = keyRepeat == 1 ? " (Repeat)" : ""
                    print("[\(now())] [INTERCEPT] Volume -\(repeatStr) -> Synthesizing Backspace")
                    KeySynthesizer.sendKey(keyCode: 51) // kVK_Delete = 51
                }
                // Suppress original event to prevent system volume decrease
                return nil
                
            default:
                // Other media keys (brightness, keyboard backlight, etc.) pass through untouched
                return Unmanaged.passRetained(event)
            }
        }
        
        guard let port = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap, // Filter / Intercept mode
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: nil
        ) else {
            print("❌ Failed to create CGEventTap at cghidEventTap. Check Accessibility permissions.")
            return false
        }
        
        self.machPort = port
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }
    
    func stop() {
        if let port = machPort {
            CGEvent.tapEnable(tap: port, enable: false)
            machPort = nil
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }
        print("[\(now())] 🛑 Event tap disabled. All keyboard and earphone hooks released.")
    }
}

// ------------------------------------------------------------------------------
// Main Entry & Lifecycle
// ------------------------------------------------------------------------------
print("==================================================================")
print("🎧 Coding Earphone Mode V0.1 Daemon")
print("==================================================================")
print("Targets: Codex (com.openai.codex), Antigravity (com.google.antigravity)")
print("Mappings in Target Apps:")
print("  • Middle Button → Fn (Toggle Typeless dictation)")
print("  • Volume +      → Return / Enter")
print("  • Volume −      → Backspace (Delete)")
print("  • Volume − Hold → Continuous Backspace (~12Hz hardware repeat)")
print("Other Apps:")
print("  • Complete Passthrough: Native Audio Playback & Volume Control")
print("==================================================================")

AppTracker.shared.start()

guard EventTapManager.shared.start() else {
    print("❌ Critical: Unable to start Event Tap. Exiting.")
    exit(1)
}

print("✅ Coding Earphone Mode V0.1 is ACTIVE.")
print("Press Ctrl+C or send SIGINT/SIGTERM to stop safely.\n")

// Graceful signal handling
signal(SIGINT) { _ in
    print("\nReceived SIGINT. Shutting down...")
    EventTapManager.shared.stop()
    exit(0)
}
signal(SIGTERM) { _ in
    print("\nReceived SIGTERM. Shutting down...")
    EventTapManager.shared.stop()
    exit(0)
}

RunLoop.main.run()
