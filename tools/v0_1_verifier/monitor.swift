import Foundation
import CoreGraphics
import AppKit

setbuf(stdout, nil)

let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "HH:mm:ss.SSS"
func now() -> String {
    return dateFormatter.string(from: Date())
}

let mask = (1 << CGEventType.keyDown.rawValue) |
           (1 << CGEventType.keyUp.rawValue) |
           (1 << CGEventType.flagsChanged.rawValue) |
           (1 << 14)

let callback: CGEventTapCallBack = { proxy, type, event, refcon in
    let raw = type.rawValue
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let userData = event.getIntegerValueField(.eventSourceUserData)
    let isOurs = (userData == 0x434F4445)
    
    if raw == 14 {
        let ns = NSEvent(cgEvent: event)
        if ns?.subtype.rawValue == 8 {
            let data1 = ns?.data1 ?? 0
            let key = (data1 & 0xFFFF0000) >> 16
            let flags = data1 & 0x0000FFFF
            let state = (flags & 0xFF00) >> 8
            let rep = flags & 0x1
            print("[\(now())] [DOWNSTREAM:MEDIA] Key=\(key), State=\(state == 0xA ? "DOWN" : "UP"), Rep=\(rep)")
        }
    } else {
        var name = "Other"
        if type == .keyDown { name = "KeyDown" }
        if type == .keyUp { name = "KeyUp" }
        if type == .flagsChanged { name = "FlagsChanged" }
        
        var keyDesc = "Key \(keyCode)"
        if keyCode == 36 { keyDesc = "Return (36)" }
        if keyCode == 51 { keyDesc = "Backspace (51)" }
        if keyCode == 63 { keyDesc = "Fn (63)" }
        
        print("[\(now())] [DOWNSTREAM:KEY] \(name): \(keyDesc), Synthetic=\(isOurs)")
    }
    return Unmanaged.passRetained(event)
}

guard let port = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .tailAppendEventTap, // downstream at tail
    options: .listenOnly,
    eventsOfInterest: CGEventMask(mask),
    callback: callback,
    userInfo: nil
) else {
    print("Failed to create downstream monitor tap.")
    exit(1)
}

let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
CGEvent.tapEnable(tap: port, enable: true)
print("Downstream monitor running.")
RunLoop.main.run()
