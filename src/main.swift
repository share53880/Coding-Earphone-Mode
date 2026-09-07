import Foundation
import CoreGraphics
import AppKit
import ApplicationServices

// ==============================================================================
// Coding Earphone Mode V0.1 (Production Release for H7)
// Frozen Core Logic:
//   Targets: com.openai.codex, com.google.antigravity
//   Middle Button   -> Fn (flagsChanged 63) -> Typeless toggle
//   Volume +        -> Return / Enter (36)
//   Volume -        -> Backspace (51)
//   Volume - Hold   -> 12Hz hardware repeat Backspace (51)
//   Other Apps      -> Full Passthrough (Native Media / Volume)
// ==============================================================================

let APP_VERSION = "0.1.0"
let APP_BUILD = "H7.Release"
let MAGIC_SIGNATURE: Int64 = 0x434F4445 // "CODE"

let dateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return df
}()

func now() -> String {
    return dateFormatter.string(from: Date())
}

// ------------------------------------------------------------------------------
// Safe File Logging & Rotation (Zero Content Leak)
// ------------------------------------------------------------------------------
final class Logger {
    static let shared = Logger()
    private let queue = DispatchQueue(label: "coding.earphone.logger", qos: .utility)
    private var fileHandle: FileHandle?
    private var logPath: String?
    private let maxSizeBytes: UInt64 = 2 * 1024 * 1024 // 2 MB
    
    func setup(logDirectory: String) {
        let path = (logDirectory as NSString).appendingPathComponent("coding-earphone.log")
        self.logPath = path
        
        let fm = FileManager.default
        if !fm.fileExists(atPath: path) {
            fm.createFile(atPath: path, contents: nil, attributes: nil)
        }
        self.fileHandle = FileHandle(forWritingAtPath: path)
        self.fileHandle?.seekToEndOfFile()
    }
    
    func log(_ message: String, alsoPrint: Bool = true) {
        let entry = "[\(now())] \(message)\n"
        if alsoPrint {
            print(entry, terminator: "")
            fflush(stdout)
        }
        
        queue.async { [weak self] in
            guard let self = self, let handle = self.fileHandle, let data = entry.data(using: .utf8) else { return }
            
            // Check rotation
            if let path = self.logPath, let attrs = try? FileManager.default.attributesOfItem(atPath: path),
               let size = attrs[.size] as? UInt64, size > self.maxSizeBytes {
                let backupPath = path + ".old"
                try? FileManager.default.removeItem(atPath: backupPath)
                try? FileManager.default.moveItem(atPath: path, toPath: backupPath)
                FileManager.default.createFile(atPath: path, contents: nil, attributes: nil)
                self.fileHandle = FileHandle(forWritingAtPath: path)
            }
            
            handle.write(data)
        }
    }
}

// ------------------------------------------------------------------------------
// Single-Instance Lock Manager (flock based)
// ------------------------------------------------------------------------------
final class SingleInstanceLock {
    private var lockFd: Int32 = -1
    private var pidPath: String = ""
    private var lockPath: String = ""
    
    func acquire(runtimeDir: String) -> Bool {
        self.lockPath = (runtimeDir as NSString).appendingPathComponent("daemon.lock")
        self.pidPath = (runtimeDir as NSString).appendingPathComponent("daemon.pid")
        
        lockFd = open(lockPath, O_CREAT | O_RDWR, 0o644)
        guard lockFd >= 0 else {
            return false
        }
        
        // Try non-blocking exclusive lock
        if flock(lockFd, LOCK_EX | LOCK_NB) != 0 {
            // Already locked by another instance
            close(lockFd)
            lockFd = -1
            return false
        }
        
        // Write current PID
        let pid = getpid()
        let pidStr = "\(pid)\n"
        if let data = pidStr.data(using: .utf8) {
            let pidFd = open(pidPath, O_CREAT | O_TRUNC | O_WRONLY, 0o644)
            if pidFd >= 0 {
                _ = write(pidFd, (data as NSData).bytes, data.count)
                close(pidFd)
            }
        }
        return true
    }
    
    func release() {
        if !pidPath.isEmpty {
            try? FileManager.default.removeItem(atPath: pidPath)
        }
        if lockFd >= 0 {
            flock(lockFd, LOCK_UN)
            close(lockFd)
            lockFd = -1
        }
    }
}

// ------------------------------------------------------------------------------
// App Tracker (NSWorkspace Observer)
// ------------------------------------------------------------------------------
final class AppTracker {
    static let shared = AppTracker()
    
    private let lock = NSLock()
    private var _currentBundleId: String = ""
    private var _currentAppName: String = ""
    
    let targetBundleIds: Set<String> = [
        "com.openai.codex",
        "com.google.antigravity",
        "now.typeless.desktop"
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
    
    var currentAppName: String {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _currentAppName
        }
        set {
            lock.lock()
            _currentAppName = newValue
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
            self.currentBundleId = front.bundleIdentifier ?? ""
            self.currentAppName = front.localizedName ?? "App"
        }
        let active = isCodingActive
        Logger.shared.log("Initial Active App: \(currentAppName) (\(currentBundleId)) -> Mode: \(active ? "ACTIVE (Coding)" : "PASSTHROUGH")")
        RcdController.shared.setSuppressed(active)
        
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
                self.currentAppName = name
                let active = self.isCodingActive
                Logger.shared.log("🔄 App Switch: \(name) (\(bid)) -> Mode: \(active ? "ACTIVE (Coding 🟢)" : "PASSTHROUGH (⚪)")")
                RcdController.shared.setSuppressed(active)
            }
        }
    }
}

// ------------------------------------------------------------------------------
// MediaRemote / RCD Protection Controller
// Prevents macOS system-level rcd daemon from relaying Play/Pause pulses
// to background music apps (Spotify, Apple Music, Netease, etc.) while in coding mode.
// ------------------------------------------------------------------------------
final class RcdController {
    static let shared = RcdController()
    private let queue = DispatchQueue(label: "coding.earphone.rcd", qos: .utility)
    private var isSuppressed: Bool? = nil
    private let uid: String
    private let plist = "/System/Library/LaunchAgents/com.apple.rcd.plist"
    
    private init() {
        self.uid = "\(getuid())"
    }
    
    func setSuppressed(_ suppress: Bool) {
        queue.async { [weak self] in
            guard let self = self else { return }
            if self.isSuppressed == suppress { return }
            self.isSuppressed = suppress
            
            let target = "gui/\(self.uid)/com.apple.rcd"
            if suppress {
                let p1 = Process()
                p1.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                p1.arguments = ["disable", target]
                try? p1.run()
                p1.waitUntilExit()
                
                let p2 = Process()
                p2.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                p2.arguments = ["bootout", target]
                try? p2.run()
                p2.waitUntilExit()
                Logger.shared.log("🔇 MediaRemote protection ACTIVE (rcd suppressed for zero music leak).")
            } else {
                let p1 = Process()
                p1.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                p1.arguments = ["enable", target]
                try? p1.run()
                p1.waitUntilExit()
                
                let p2 = Process()
                p2.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                p2.arguments = ["bootstrap", "gui/\(self.uid)", self.plist]
                try? p2.run()
                p2.waitUntilExit()
                Logger.shared.log("🔊 MediaRemote passthrough ACTIVE (rcd restored).")
            }
        }
    }
    
    func isServiceEnabled() -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = ["print-disabled", "gui/\(self.uid)"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        try? p.run()
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8) ?? ""
        for line in out.components(separatedBy: "\n") {
            if line.contains("\"com.apple.rcd\"") {
                return line.contains("enabled")
            }
        }
        return true
    }
    
    func isProcessRunning() -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = ["print", "gui/\(self.uid)/com.apple.rcd"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        try? p.run()
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8) ?? ""
        return out.contains("state = running")
    }

    func restoreSynchronous() {
        let target = "gui/\(self.uid)/com.apple.rcd"
        let p1 = Process()
        p1.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p1.arguments = ["enable", target]
        try? p1.run()
        p1.waitUntilExit()
        
        let p2 = Process()
        p2.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p2.arguments = ["bootstrap", "gui/\(self.uid)", self.plist]
        try? p2.run()
        p2.waitUntilExit()
        
        let p3 = Process()
        p3.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p3.arguments = ["kickstart", "-k", target]
        try? p3.run()
        p3.waitUntilExit()
    }
    
    func repairSynchronous() -> Bool {
        restoreSynchronous()
        Thread.sleep(forTimeInterval: 0.3)
        return isServiceEnabled()
    }
}

// ------------------------------------------------------------------------------
// Key Synthesizer
// ------------------------------------------------------------------------------
struct KeySynthesizer {
    static let workerQueue = DispatchQueue(label: "coding.earphone.synthesizer", qos: .userInteractive)
    
    static func sendKey(keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }
        keyDown.setIntegerValueField(.eventSourceUserData, value: MAGIC_SIGNATURE)
        keyUp.setIntegerValueField(.eventSourceUserData, value: MAGIC_SIGNATURE)
        
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
            down.setIntegerValueField(.eventSourceUserData, value: MAGIC_SIGNATURE)
            down.post(tap: .cghidEventTap)
            
            Thread.sleep(forTimeInterval: 0.05)
            
            // Fn release
            up.type = .flagsChanged
            up.setIntegerValueField(.keyboardEventKeycode, value: 63)
            up.flags = []
            up.setIntegerValueField(.eventSourceUserData, value: MAGIC_SIGNATURE)
            up.post(tap: .cghidEventTap)
        }
    }
}

// ------------------------------------------------------------------------------
// Event Tap Manager
// ------------------------------------------------------------------------------
final class EventTapManager {
    static let shared = EventTapManager()
    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    func start() -> Bool {
        let eventMask = (1 << 14) // NX_SYSDEFINED
        
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            // Auto-recovery from system tap timeouts
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let port = EventTapManager.shared.machPort {
                    CGEvent.tapEnable(tap: port, enable: true)
                    Logger.shared.log("⚠️ EventTap was disabled by system; auto-enabled successfully.")
                }
                return nil
            }
            
            guard type.rawValue == 14 else {
                return Unmanaged.passRetained(event)
            }
            
            // Check if synthetic event generated by us
            let userData = event.getIntegerValueField(.eventSourceUserData)
            if userData == MAGIC_SIGNATURE {
                return Unmanaged.passRetained(event)
            }
            
            // Check if coding mode is active for current frontmost app
            let isCoding = AppTracker.shared.isCodingActive
            
            // Passthrough for non-target apps
            if !isCoding {
                return Unmanaged.passRetained(event)
            }
            
            let nsEvent = NSEvent(cgEvent: event)
            let subtype = nsEvent?.subtype.rawValue ?? 0
            
            // Subtype 7 is macOS auxiliary media control pulse (e.g. play/pause toggles or remote pulses).
            // When coding mode is active, swallow these pulses so background music players never receive them.
            if subtype == 7 {
                return nil
            }
            
            guard subtype == 8 else {
                return Unmanaged.passRetained(event)
            }
            
            let data1 = nsEvent?.data1 ?? 0
            let mediaKeyCode = (data1 & 0xFFFF0000) >> 16
            let keyFlags = data1 & 0x0000FFFF
            let keyState = (keyFlags & 0xFF00) >> 8 // 0xA = down, 0xB = up
            let keyRepeat = keyFlags & 0x1
            
            // Coding mode active: Intercept and map
            switch mediaKeyCode {
            case 16: // NX_KEYTYPE_PLAY (Middle button)
                if keyState == 0xA && keyRepeat == 0 {
                    Logger.shared.log("[INTERCEPT] Middle Button -> Synthesizing Fn (Typeless)")
                    KeySynthesizer.sendFnAsync()
                }
                // Suppress both KeyDown (0xA) and KeyUp (0xB) to prevent system media toggle leak
                return nil
                
            case 0: // NX_KEYTYPE_SOUND_UP (Volume +)
                if keyState == 0xA && keyRepeat == 0 {
                    Logger.shared.log("[INTERCEPT] Volume + -> Synthesizing Return (KeyCode 36)")
                    KeySynthesizer.sendKey(keyCode: 36)
                }
                return nil // Suppress default volume up
                
            case 1: // NX_KEYTYPE_SOUND_DOWN (Volume -)
                if keyState == 0xA {
                    let repLabel = keyRepeat == 1 ? " (12Hz Repeat)" : ""
                    Logger.shared.log("[INTERCEPT] Volume -\(repLabel) -> Synthesizing Backspace (KeyCode 51)")
                    KeySynthesizer.sendKey(keyCode: 51)
                }
                return nil // Suppress default volume down
                
            default:
                return Unmanaged.passRetained(event)
            }
        }
        
        var port = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: nil
        )
        if port == nil {
            Logger.shared.log("⚠️ cghidEventTap returned nil; attempting cgSessionEventTap...")
            port = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(eventMask),
                callback: callback,
                userInfo: nil
            )
        }
        guard let validPort = port else {
            return false
        }
        
        self.machPort = validPort
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, validPort, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: validPort, enable: true)
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
        Logger.shared.log("🛑 Event tap disabled. All hooks released.")
    }
}

// ------------------------------------------------------------------------------
// Permissions & Doctor Helper
// ------------------------------------------------------------------------------
struct Doctor {
    static func checkAccessibility(prompt: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    static func runDoctor() -> Int32 {
        print("==================================================")
        print("🏥 Coding Earphone Mode Doctor (H7 Diagnostics)")
        print("==================================================")
        print("Version: \(APP_VERSION) (\(APP_BUILD))")
        print("Binary Path: \(CommandLine.arguments[0])")
        
        var allOk = true
        
        // 1. Accessibility
        let axOk = checkAccessibility()
        print("1. Accessibility Permission : \(axOk ? "GRANTED ✅" : "DENIED ❌ (PERMISSION_REQUIRED: Accessibility)")")
        if !axOk { allOk = false }
        
        // 2. EventTap Creation
        let testTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << 14),
            callback: { _,_,e,_ in Unmanaged.passRetained(e) },
            userInfo: nil
        )
        let tapOk = (testTap != nil)
        print("2. EventTap Creation        : \(tapOk ? "SUCCESS ✅" : "FAILED ❌ (Check Input Monitoring / Accessibility)")")
        if !tapOk { allOk = false }
        
        // 3. Frontmost App Detection
        if let front = NSWorkspace.shared.frontmostApplication {
            let bid = front.bundleIdentifier ?? "N/A"
            let name = front.localizedName ?? "N/A"
            print("3. Foreground App Detection : OK ✅ (Current: '\(name)' [\(bid)], PID: \(front.processIdentifier))")
        } else {
            print("3. Foreground App Detection : FAILED ❌")
            allOk = false
        }
        
        // 4. Earphone Adapter Hardware
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        proc.arguments = ["-p", "IOUSB", "-n", "USB-C to 3.5mm Headphone Jack Adapter"]
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let hasAdapter = data.count > 0
        print("4. USB-C 3.5mm Adapter      : \(hasAdapter ? "CONNECTED ✅" : "NOT CONNECTED ⚠️ (Connect adapter for full function)")")
        
        // 5. Typeless App
        let typelessRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "now.typeless.desktop").isEmpty
        print("5. Typeless Desktop App     : \(typelessRunning ? "RUNNING ✅" : "NOT RUNNING ⚠️ (Launch Typeless for voice dictation)")")
        
        // 6. MediaRemote / RCD Protection Status
        let rcdEnabled = RcdController.shared.isServiceEnabled()
        let rcdRunning = RcdController.shared.isProcessRunning()
        let isCoding = AppTracker.shared.isCodingActive
        let protectionActive = !rcdEnabled || !rcdRunning
        
        print("6. MediaRemote Protection   : \(protectionActive ? "ACTIVE (Zero Leak Guaranteed) 🔇" : "STANDBY (Passthrough ready) 🔊")")
        print("   - rcd service state      : \(rcdEnabled ? "ENABLED" : "DISABLED")")
        print("   - rcd process running    : \(rcdRunning ? "RUNNING" : "NOT RUNNING")")
        print("   - foreground coding mode : \(isCoding ? "ACTIVE (Coding 🟢)" : "PASSTHROUGH (⚪)")")
        
        print("==================================================")
        if allOk {
            print("Result: ALL CORE SYSTEM CHECKS PASSED ✅")
            return 0
        } else {
            print("Result: PERMISSION ISSUES DETECTED ❌")
            print("Please navigate to: System Settings -> Privacy & Security -> Accessibility")
            print("and enable permissions for this binary / terminal.")
            return 1
        }
    }
}

// ------------------------------------------------------------------------------
// Main Entrypoint
// ------------------------------------------------------------------------------
setbuf(stdout, nil)

let args = CommandLine.arguments

if args.count > 1 {
    let sub = args[1]
    switch sub {
    case "doctor":
        exit(Doctor.runDoctor())
    case "repair":
        print("🔧 Running Coding Earphone Mode Self-Healing & RCD Repair...")
        let ok = RcdController.shared.repairSynchronous()
        if ok {
            print("✅ RCD Service Repair SUCCESS: rcd is ENABLED and running.")
            exit(0)
        } else {
            print("❌ RCD Service Repair FAILED: unable to re-enable com.apple.rcd.")
            exit(1)
        }
    case "version", "--version", "-v":
        print("coding-earphone version \(APP_VERSION) (\(APP_BUILD))")
        exit(0)
    case "status-permission":
        let axOk = Doctor.checkAccessibility(prompt: false)
        print(axOk ? "GRANTED" : "DENIED")
        exit(0)
    case "status-foreground":
        if let front = NSWorkspace.shared.frontmostApplication {
            let bid = front.bundleIdentifier ?? ""
            let name = front.localizedName ?? ""
            let isCoding = (bid == "com.openai.codex" || bid == "com.google.antigravity" || bid == "now.typeless.desktop")
            print("APP:\(name)|BUNDLE:\(bid)|PID:\(front.processIdentifier)|MODE:\(isCoding ? "ACTIVE" : "PASSTHROUGH")")
        } else {
            print("APP:Unknown|BUNDLE:Unknown|PID:0|MODE:UNKNOWN")
        }
        exit(0)
    case "--help", "-h", "help":
        print("Usage: coding-earphone [doctor | repair | version | --help]")
        print("Runs the Coding Earphone Mode daemon by default.")
        exit(0)
    default:
        break
    }
}

// Daemon Mode
let home = FileManager.default.homeDirectoryForCurrentUser.path
let appSupportDir = (home as NSString).appendingPathComponent("Library/Application Support/CodingEarphoneMode")
let logsDir = (appSupportDir as NSString).appendingPathComponent("logs")
let runtimeDir = (appSupportDir as NSString).appendingPathComponent("runtime")

// Ensure directories exist
try? FileManager.default.createDirectory(atPath: logsDir, withIntermediateDirectories: true, attributes: nil)
try? FileManager.default.createDirectory(atPath: runtimeDir, withIntermediateDirectories: true, attributes: nil)

Logger.shared.setup(logDirectory: logsDir)
Logger.shared.log("==================================================================")
Logger.shared.log("🎧 Coding Earphone Mode Daemon v\(APP_VERSION) (\(APP_BUILD)) Starting")
Logger.shared.log("PID: \(getpid()), Process: \(CommandLine.arguments[0])")
Logger.shared.log("Targets: com.openai.codex, com.google.antigravity")
Logger.shared.log("==================================================================")

// 1. Single-Instance Protection
let singleInstance = SingleInstanceLock()
guard singleInstance.acquire(runtimeDir: runtimeDir) else {
    Logger.shared.log("❌ ALREADY_RUNNING: Another instance is already holding the lock.")
    fputs("ALREADY_RUNNING\n", stderr)
    exit(0)
}

// 2. Permission Check
let axOk = Doctor.checkAccessibility(prompt: false)
Logger.shared.log("Permission check: AXIsProcessTrusted=\(axOk)")
if !axOk {
    Logger.shared.log("Notice: AXIsProcessTrusted is false. Testing direct EventTap creation capability...")
}

// 3. Signal Handling
signal(SIGINT) { _ in
    Logger.shared.log("Received SIGINT. Shutting down gracefully...")
    EventTapManager.shared.stop()
    RcdController.shared.restoreSynchronous()
    exit(0)
}
signal(SIGTERM) { _ in
    Logger.shared.log("Received SIGTERM. Shutting down gracefully...")
    EventTapManager.shared.stop()
    RcdController.shared.restoreSynchronous()
    exit(0)
}

// 4. Initialize Core Components
AppTracker.shared.start()

guard EventTapManager.shared.start() else {
    Logger.shared.log("❌ FAILED to create EventTap at cghidEventTap. Exiting.")
    fputs("PERMISSION_REQUIRED: Input Monitoring / EventTap\n", stderr)
    RcdController.shared.restoreSynchronous()
    singleInstance.release()
    exit(1)
}

Logger.shared.log("✅ Coding Earphone Mode Daemon is now ACTIVE.")

// Clean exit handler
atexit {
    RcdController.shared.restoreSynchronous()
    SingleInstanceLock().release()
    let pidFile = ((FileManager.default.homeDirectoryForCurrentUser.path as NSString)
        .appendingPathComponent("Library/Application Support/CodingEarphoneMode/runtime/daemon.pid"))
    try? FileManager.default.removeItem(atPath: pidFile)
}

RunLoop.main.run()
