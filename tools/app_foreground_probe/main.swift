import Foundation
import AppKit

setbuf(stdout, nil)

print("==================================================")
print("🔍 Foreground App Detection Probe (Stage H3)")
print("==================================================")

func printCurrentFrontmost() {
    if let frontApp = NSWorkspace.shared.frontmostApplication {
        print("Current Frontmost Application:")
        print("  - Name: \(frontApp.localizedName ?? "Unknown")")
        print("  - Bundle ID: \(frontApp.bundleIdentifier ?? "N/A")")
        print("  - PID: \(frontApp.processIdentifier)")
        print("  - Executable: \(frontApp.executableURL?.path ?? "N/A")")
    } else {
        print("No frontmost application found.")
    }
}

// Check by target bundle identifiers or app names
let targetBundleIDs = [
    "Codex (ChatGPT)": "com.openai.codex",
    "Antigravity": "com.google.antigravity",
    "Safari": "com.apple.Safari",
    "Finder": "com.apple.finder",
    "Music": "com.apple.Music"
]

print("\n--- Target Applications Inspection ---")
for (label, bundleId) in targetBundleIDs {
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
    if let app = runningApps.first {
        print("[$] \(label):")
        print("    Running: YES")
        print("    Name: \(app.localizedName ?? "Unknown")")
        print("    Bundle ID: \(app.bundleIdentifier ?? "N/A")")
        print("    PID: \(app.processIdentifier)")
        print("    Active: \(app.isActive)")
    } else {
        print("[-] \(label):")
        print("    Running: NO (Bundle ID: \(bundleId))")
    }
}

let args = CommandLine.arguments
if args.contains("--monitor") {
    print("\n--- Monitoring Frontmost App Changes (Ctrl+C to stop) ---")
    NSWorkspace.shared.notificationCenter.addObserver(
        forName: NSWorkspace.didActivateApplicationNotification,
        object: nil,
        queue: .main
    ) { notification in
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            let bundleId = app.bundleIdentifier ?? "N/A"
            let isTarget = (bundleId == "com.openai.codex" || bundleId == "com.google.antigravity")
            let tag = isTarget ? "[CODING MODE ACTIVE]" : "[DEFAULT EARPHONE MODE]"
            print("[\(Date())] Activated: \(app.localizedName ?? "Unknown") (\(bundleId), PID: \(app.processIdentifier)) -> \(tag)")
        }
    }
    RunLoop.main.run()
} else {
    printCurrentFrontmost()
}
