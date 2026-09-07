import Foundation
import CoreGraphics
import AppKit

setbuf(stdout, nil)

print("==================================================")
print("🧪 macOS Fn Key Simulation Probe (Stage H2)")
print("==================================================")
print("Testing macOS official CGEvent synthesis for 'Fn' key...")

let kVK_Function: CGKeyCode = 63 // 0x3F

func simulateFnMethod1() {
    print("\n--- Method 1: flagsChanged event (KeyCode: 63, maskSecondaryFn) ---")
    let source = CGEventSource(stateID: .hidSystemState)
    
    // Press (Fn down)
    guard let eventDown = CGEvent(source: source) else {
        print("Failed to create CGEvent down")
        return
    }
    eventDown.type = .flagsChanged
    eventDown.setIntegerValueField(.keyboardEventKeycode, value: Int64(kVK_Function))
    eventDown.flags = [.maskSecondaryFn]
    eventDown.post(tap: .cghidEventTap)
    print("-> Posted Fn Down (.flagsChanged, flags: maskSecondaryFn)")
    
    Thread.sleep(forTimeInterval: 0.1)
    
    // Release (Fn up)
    guard let eventUp = CGEvent(source: source) else {
        print("Failed to create CGEvent up")
        return
    }
    eventUp.type = .flagsChanged
    eventUp.setIntegerValueField(.keyboardEventKeycode, value: Int64(kVK_Function))
    eventUp.flags = []
    eventUp.post(tap: .cghidEventTap)
    print("-> Posted Fn Up (.flagsChanged, flags: empty)")
}

func simulateFnMethod2() {
    print("\n--- Method 2: keyDown / keyUp (KeyCode: 63) ---")
    let source = CGEventSource(stateID: .hidSystemState)
    if let kd = CGEvent(keyboardEventSource: source, virtualKey: kVK_Function, keyDown: true) {
        kd.post(tap: .cghidEventTap)
        print("-> Posted KeyDown(63)")
    }
    Thread.sleep(forTimeInterval: 0.1)
    if let ku = CGEvent(keyboardEventSource: source, virtualKey: kVK_Function, keyDown: false) {
        ku.post(tap: .cghidEventTap)
        print("-> Posted KeyUp(63)")
    }
}

func simulateFnMethod3() {
    print("\n--- Method 3: SessionEventTap flagsChanged ---")
    let source = CGEventSource(stateID: .combinedSessionState)
    if let eventDown = CGEvent(source: source) {
        eventDown.type = .flagsChanged
        eventDown.setIntegerValueField(.keyboardEventKeycode, value: Int64(kVK_Function))
        eventDown.flags = [.maskSecondaryFn]
        eventDown.post(tap: .cgSessionEventTap)
        print("-> Posted Fn Down to cgSessionEventTap")
    }
    Thread.sleep(forTimeInterval: 0.1)
    if let eventUp = CGEvent(source: source) {
        eventUp.type = .flagsChanged
        eventUp.setIntegerValueField(.keyboardEventKeycode, value: Int64(kVK_Function))
        eventUp.flags = []
        eventUp.post(tap: .cgSessionEventTap)
        print("-> Posted Fn Up to cgSessionEventTap")
    }
}

let args = CommandLine.arguments
if args.count > 1 {
    let mode = args[1]
    switch mode {
    case "1": simulateFnMethod1()
    case "2": simulateFnMethod2()
    case "3": simulateFnMethod3()
    case "loop1":
        print("Running 10 consecutive tests of Method 1 with 1s interval...")
        for i in 1...10 {
            print("\n[Iteration \(i)/10]")
            simulateFnMethod1()
            Thread.sleep(forTimeInterval: 1.0)
        }
    default:
        simulateFnMethod1()
    }
} else {
    simulateFnMethod1()
}
print("\nSimulation completed.")
