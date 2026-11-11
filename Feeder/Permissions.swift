import AppKit
import ApplicationServices
import CoreGraphics

enum Permissions {
    /// Accessibility: needed for an active tap that can swallow and inject events.
    static var accessibilityGranted: Bool { AXIsProcessTrusted() }
    /// Input Monitoring: needed to see keystrokes at all.
    static var inputMonitoringGranted: Bool { CGPreflightListenEventAccess() }
    static var allGranted: Bool { accessibilityGranted && inputMonitoringGranted }

    static func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
    }

    static func openAccessibilitySettings() {
        open("Privacy_Accessibility")
    }

    static func openInputMonitoringSettings() {
        open("Privacy_ListenEvent")
    }

    private static func open(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}
