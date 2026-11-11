import AppKit
import CoreGraphics

/// Owns the CGEventTap. While armed, character keypresses are swallowed and replaced
/// by the next character of the feeder's text.
///
/// Runs on the main run loop, so the callback is always on the main thread.
final class KeyTap {
    /// Marker stamped on events we post, so the tap ignores its own output.
    private static let marker: Int64 = 0x46454544 // "FEED"
    private static let capsLockKeyCode: Int64 = 57
    private static let returnKeyCode: CGKeyCode = 36
    private static let tabKeyCode: CGKeyCode = 48
    private static let escapeKeyCode: Int64 = 53
    /// Always disarms, whatever the arm key is set to.
    private static let panicFlags: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    /// Key codes whose key-down we swallowed, so we also swallow the matching key-up.
    private var swallowed = Set<Int64>()

    /// Called on the main thread. Return the next character, or nil if the text is finished.
    var nextCharacter: () -> Character? = { nil }
    var isArmed: () -> Bool = { false }
    var setArmed: (Bool) -> Void = { _ in }
    /// Whether Space consumes a character.
    var spaceConsumes = true
    /// What arms/disarms the feeder.
    var armKey: ArmKey = .capsLock
    /// True while the user is recording a new arm key in Settings.
    var hotkeysSuspended = false

    var isRunning: Bool { tap != nil }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let tap = Unmanaged<KeyTap>.fromOpaque(refcon).takeUnretainedValue()
            return tap.handle(type: type, event: event)
        }
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        tap = port
        source = src
        return true
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        tap = nil
        source = nil
        swallowed.removeAll()
    }

    // MARK: - Event handling

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)

        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        default:
            break
        }

        if event.getIntegerValueField(.eventSourceUserData) == Self.marker { return pass }

        let code = event.getIntegerValueField(.keyboardEventKeycode)

        if type == .flagsChanged {
            // Caps Lock mode: the Caps Lock state is the armed state.
            if code == Self.capsLockKeyCode, armKey == .capsLock, !hotkeysSuspended {
                setArmed(event.flags.contains(.maskAlphaShift))
            }
            return pass
        }

        if type == .keyUp {
            // Swallow the key-up of any key whose key-down we swallowed.
            return swallowed.remove(code) != nil ? nil : pass
        }

        guard type == .keyDown else { return pass }

        let autorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        if autorepeat, swallowed.contains(code) { return nil }

        let mods = event.flags.intersection(ArmKey.modifierMask)

        // Panic combo: always disarms.
        if code == Self.escapeKeyCode, mods == Self.panicFlags {
            setArmed(false)
            swallowed.insert(code)
            return nil
        }
        // Arm combo: toggles.
        if !hotkeysSuspended,
           case let .combo(keyCode, modifiers, _) = armKey,
           code == keyCode, mods.rawValue == modifiers {
            setArmed(!isArmed())
            swallowed.insert(code)
            return nil
        }

        guard isArmed() else { return pass }

        // Let the app's own windows (the paste box) work normally.
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier {
            return pass
        }
        // Shortcuts keep working.
        if event.flags.contains(.maskCommand) || event.flags.contains(.maskControl) { return pass }
        guard isCharacterKey(code) else { return pass }

        if autorepeat { return pass }

        guard let ch = nextCharacter() else { return pass } // finished: type normally
        swallowed.insert(code)
        post(ch)
        return nil
    }

    /// ANSI printable keys (0...50) minus Return and Tab; Space (49) is optional.
    private func isCharacterKey(_ code: Int64) -> Bool {
        guard (0...50).contains(code), code != 36, code != 48 else { return false }
        return code != 49 || spaceConsumes
    }

    // MARK: - Injection

    private func post(_ ch: Character) {
        let source = CGEventSource(stateID: .privateState)
        if ch.isNewline {
            postKey(code: Self.returnKeyCode, source: source)
        } else if ch == "\t" {
            postKey(code: Self.tabKeyCode, source: source)
        } else {
            let utf16 = Array(String(ch).utf16)
            for down in [true, false] {
                guard let e = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down) else { continue }
                var chars = utf16
                e.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
                e.flags = []
                e.setIntegerValueField(.eventSourceUserData, value: Self.marker)
                e.post(tap: .cgSessionEventTap)
            }
        }
    }

    private func postKey(code: CGKeyCode, source: CGEventSource?) {
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { continue }
            e.flags = []
            e.setIntegerValueField(.eventSourceUserData, value: Self.marker)
            e.post(tap: .cgSessionEventTap)
        }
    }
}
