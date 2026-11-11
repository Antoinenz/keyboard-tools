import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @StateObject private var recorder = KeyRecorder()

    var body: some View {
        Form {
            Section("Arm key") {
                HStack {
                    Text(state.armKey.displayName)
                        .font(.body.monospaced())
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    Spacer()
                    Button(recorder.isRecording ? "Cancel" : "Change…") {
                        if recorder.isRecording {
                            recorder.stop()
                            state.recordingArmKey = false
                        } else {
                            recorder.start(
                                onRecord: { state.armKey = $0 },
                                onStateChange: { state.recordingArmKey = $0 }
                            )
                        }
                    }
                    Button("Use Caps Lock") { state.armKey = .capsLock }
                        .disabled(state.armKey == .capsLock || recorder.isRecording)
                }
                if let message = recorder.message, recorder.isRecording {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                Text("Caps Lock arms while it is on. Any other key toggles armed on and off.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Typing") {
                Toggle("Space types the next character", isOn: $state.spaceConsumes)
            }
            Section("Safety") {
                LabeledContent("Panic disarm", value: "⌃⌥⌘Esc")
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .onDisappear {
            recorder.stop()
            state.recordingArmKey = false
        }
    }
}
