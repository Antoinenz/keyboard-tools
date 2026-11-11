import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !state.tapRunning {
                permissionsSection
            }

            Text("Text to type").font(.headline)
            TextEditor(text: $state.text)
                .font(.body.monospaced())
                .frame(height: 140)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

            HStack {
                Text("\(state.feeder.index) / \(state.feeder.total)")
                    .monospacedDigit().foregroundStyle(.secondary)
                Spacer()
                Button("Reset") { state.resetPosition() }
                Button("Clear") { state.clear() }
            }
            if !state.feeder.upcoming().isEmpty {
                Text("Next: \(state.feeder.upcoming())")
                    .font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
            }

            Toggle("Armed", isOn: $state.armed)
                .toggleStyle(.switch)
                .disabled(!state.tapRunning)
            Text(armHint)
                .font(.caption).foregroundStyle(.secondary)

            Divider()
            HStack {
                Button("Settings…") {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("Quit Feeder") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 340)
    }

    private var armHint: String {
        switch state.armKey {
        case .capsLock: return "Caps Lock on = armed. Panic disarm: ⌃⌥⌘Esc."
        default: return "Press \(state.armKey.displayName) to arm or disarm. Panic disarm: ⌃⌥⌘Esc."
        }
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Permissions needed").font(.headline)
            permissionRow("Accessibility", granted: state.accessibilityGranted) {
                Permissions.requestAccessibility()
                Permissions.openAccessibilitySettings()
            }
            permissionRow("Input Monitoring", granted: state.inputMonitoringGranted) {
                Permissions.requestInputMonitoring()
                Permissions.openInputMonitoringSettings()
            }
            Text("Feeder starts working as soon as both are on.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
        }
    }

    private func permissionRow(_ name: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(granted ? .green : .red)
            Text(name)
            Spacer()
            if !granted { Button("Grant…", action: action) }
        }
    }
}
