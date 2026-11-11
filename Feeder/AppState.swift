import SwiftUI
import ServiceManagement

@MainActor
final class AppState: ObservableObject {
    @Published var text = "" {
        didSet { feeder.setText(text); objectWillChange.send() }
    }
    @Published private(set) var feeder = TextFeeder()
    @Published var armed = false {
        didSet {
            guard armed != oldValue, soundOnArm else { return }
            NSSound(named: armed ? "Tink" : "Pop")?.play()
        }
    }
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
    @Published var loopAtEnd: Bool = AppState.bool("loopAtEnd", false) {
        didSet { UserDefaults.standard.set(loopAtEnd, forKey: "loopAtEnd") }
    }
    @Published var autoDisarmAtEnd: Bool = AppState.bool("autoDisarmAtEnd", true) {
        didSet { UserDefaults.standard.set(autoDisarmAtEnd, forKey: "autoDisarmAtEnd") }
    }
    @Published var backspaceStepsBack: Bool = AppState.bool("backspaceStepsBack", false) {
        didSet {
            UserDefaults.standard.set(backspaceStepsBack, forKey: "backspaceStepsBack")
            keyTap.backspaceStepsBack = backspaceStepsBack
        }
    }
    @Published var ignoreAutoRepeat: Bool = AppState.bool("ignoreAutoRepeat", true) {
        didSet {
            UserDefaults.standard.set(ignoreAutoRepeat, forKey: "ignoreAutoRepeat")
            keyTap.ignoreAutoRepeat = ignoreAutoRepeat
        }
    }
    @Published var soundOnArm: Bool = AppState.bool("soundOnArm", true) {
        didSet { UserDefaults.standard.set(soundOnArm, forKey: "soundOnArm") }
    }
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published private(set) var launchAtLoginError: String?

    private static func bool(_ key: String, _ fallback: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? fallback
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
            if self.loopAtEnd { return self.feeder.nextLooping() }
            let c = self.feeder.next()
            if self.feeder.isFinished, self.autoDisarmAtEnd { self.armed = false }
            return c
        }
        keyTap.stepBack = { [weak self] in self?.feeder.back() }
        keyTap.isArmed = { [weak self] in self?.armed ?? false }
        keyTap.setArmed = { [weak self] in self?.armed = $0 }
        keyTap.armKey = armKey
        keyTap.spaceConsumes = spaceConsumes
        keyTap.backspaceStepsBack = backspaceStepsBack
        keyTap.ignoreAutoRepeat = ignoreAutoRepeat
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

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled
        if status == .requiresApproval {
            launchAtLoginError = "Approve Feeder in System Settings > General > Login Items."
        }
    }

    func resetPosition() { feeder.reset() }
    func clear() { text = ""; feeder.reset(); armed = false }
}
