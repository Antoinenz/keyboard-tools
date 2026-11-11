import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var text = "" {
        didSet { feeder.setText(text); objectWillChange.send() }
    }
    @Published private(set) var feeder = TextFeeder()
    @Published var armed = false
    @Published private(set) var accessibilityGranted = Permissions.accessibilityGranted
    @Published private(set) var inputMonitoringGranted = Permissions.inputMonitoringGranted
    @Published private(set) var tapRunning = false

    @Published var armKey: ArmKey = HotkeyStore.load() {
        didSet {
            HotkeyStore.save(armKey)
            keyTap.armKey = armKey
            // In Caps Lock mode the LED is the truth: sync to it right away.
            if armKey == .capsLock {
                armed = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)
            }
        }
    }
    @Published var spaceConsumes: Bool = UserDefaults.standard.object(forKey: "spaceConsumes") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(spaceConsumes, forKey: "spaceConsumes")
            keyTap.spaceConsumes = spaceConsumes
        }
    }
    /// True while Settings is recording a new arm key; the tap ignores hotkeys meanwhile.
    @Published var recordingArmKey = false {
        didSet { keyTap.hotkeysSuspended = recordingArmKey }
    }

    private let keyTap = KeyTap()
    private var pollTimer: Timer?

    init() {
        keyTap.nextCharacter = { [weak self] in
            guard let self else { return nil }
            let c = self.feeder.next()
            if self.feeder.isFinished { self.armed = false } // auto-disarm at end
            return c
        }
        keyTap.isArmed = { [weak self] in self?.armed ?? false }
        keyTap.setArmed = { [weak self] in self?.armed = $0 }
        keyTap.armKey = armKey
        keyTap.spaceConsumes = spaceConsumes
        refreshPermissions()
        // Poll so the UI and the tap react as soon as the user grants access.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshPermissions() }
        }
    }

    func refreshPermissions() {
        accessibilityGranted = Permissions.accessibilityGranted
        inputMonitoringGranted = Permissions.inputMonitoringGranted
        if Permissions.allGranted {
            if !keyTap.isRunning { keyTap.start() }
        } else if keyTap.isRunning {
            keyTap.stop()
            armed = false
        }
        tapRunning = keyTap.isRunning
    }

    func resetPosition() { feeder.reset() }
    func clear() { text = ""; feeder.reset(); armed = false }
}
