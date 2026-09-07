import Foundation
import AppKit
import CoreGraphics

func postMedia(key: Int32, state: Int32, repeatFlag: Int32) {
    let flags: Int32 = (state << 8) | repeatFlag
    let data1 = (key << 16) | (flags & 0xFFFF)
    let event = NSEvent.otherEvent(
        with: .systemDefined,
        location: .zero,
        modifierFlags: NSEvent.ModifierFlags(rawValue: 0xa00),
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        subtype: 8,
        data1: Int(data1),
        data2: -1
    )
    event?.cgEvent?.post(tap: .cghidEventTap)
}

func sendSingle(key: Int32) {
    postMedia(key: key, state: 0xA, repeatFlag: 0) // DOWN
    Thread.sleep(forTimeInterval: 0.05)
    postMedia(key: key, state: 0xB, repeatFlag: 0) // UP
}

func sendHold(key: Int32, durationSeconds: Double, repeatIntervalMs: Double = 83.5) {
    postMedia(key: key, state: 0xA, repeatFlag: 0) // initial DOWN
    let count = Int((durationSeconds * 1000.0) / repeatIntervalMs)
    for _ in 0..<count {
        Thread.sleep(forTimeInterval: repeatIntervalMs / 1000.0)
        postMedia(key: key, state: 0xA, repeatFlag: 1) // repeat DOWN
    }
    Thread.sleep(forTimeInterval: 0.05)
    postMedia(key: key, state: 0xB, repeatFlag: 0) // UP
}

let args = CommandLine.arguments
if args.count > 1 {
    let action = args[1]
    switch action {
    case "play":
        sendSingle(key: 16)
    case "vol_up":
        sendSingle(key: 0)
    case "vol_down":
        sendSingle(key: 1)
    case "vol_down_hold":
        let sec = args.count > 2 ? (Double(args[2]) ?? 1.5) : 1.5
        sendHold(key: 1, durationSeconds: sec)
    default:
        print("Unknown action: \(action)")
    }
}
