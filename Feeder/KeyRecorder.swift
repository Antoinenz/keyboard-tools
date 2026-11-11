import AppKit
import CoreGraphics

/// Records the next key combo pressed while Feeder's own window is frontmost.
@MainActor
final class KeyRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var message: String?

    private var monitor: Any?

    func start(onRecord: @escaping (ArmKey) -> Void, onStateChange: @escaping (Bool) -> Void) {
        stop()
        isRecording = true
        message = "Press the new arm key (Esc to cancel)"
        onStateChange(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            if let key = self.interpret(event) {
                self.stop()
                onRecord(key)
                onStateChange(false)
            } else if event.type == .keyDown, event.keyCode == 53 {
                self.stop()
                onStateChange(false)
            }
            return nil // swallow while recording
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }

    private func interpret(_ event: NSEvent) -> ArmKey? {
        if event.type == .flagsChanged {
            return event.keyCode == 57 ? .capsLock : nil
        }
        let code = Int64(event.keyCode)
        if code == 53 { return nil } // Esc cancels
        let flags = event.cgEvent?.flags ?? []
        guard ArmKey.isAcceptable(keyCode: code, modifiers: flags) else {
            message = "Add ⌘, ⌃ or ⌥ (or use a function key) so normal typing isn't affected."
            return nil
        }
        let mods = flags.intersection(ArmKey.modifierMask)
        return .combo(keyCode: code,
                      modifiers: mods.rawValue,
                      label: ArmKey.label(forKeyCode: code, characters: event.charactersIgnoringModifiers))
    }
}
