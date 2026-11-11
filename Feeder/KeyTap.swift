import AppKit
import CoreGraphics

/// Owns the CGEventTap. While armed, each character keypress is rewritten in place so it
/// types the next character of the feeder's text instead. Rewriting the real event (rather
/// than swallowing it and posting a new one) keeps it in order with every other key event.
///
/// Runs on the main run loop, so the callback is always on the main thread.
final class KeyTap {
    private static let capsLockKeyCode: Int64 = 57
    private static let returnKeyCode: CGKeyCode = 36
    private static let tabKeyCode: CGKeyCode = 48

    /// How a physical key is rewritten while we are typing a character in its place.
    private struct Replacement {
        var unicode: [UniChar]
        var keyCode: CGKeyCode?   // nil keeps the physical key's code
        var flags: CGEventFlags
    }
    private static let escapeKeyCode: Int64 = 53
    private static let deleteKeyCode: Int64 = 51
    /// Always disarms, whatever the arm key is set to.
    private static let panicFlags: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    /// Hotkey presses (arm / panic) we swallowed, so their key-up and auto-repeats go too.
    private var swallowed = Set<Int64>()
    /// Physical keys currently held that we rewrote, so the key-up is rewritten to match.
    private var rewritten = [Int64: Replacement]()

    /// Called on the main thread. Return the next character, or nil if the text is finished.
    var nextCharacter: () -> Character? = { nil }
    var isArmed: () -> Bool = { false }
    var setArmed: (Bool) -> Void = { _ in }
    /// Whether Space consumes a character.
    var spaceConsumes = true
    /// Type with real key codes (current layout) instead of Unicode-string events.
    var compatibilityMode = false
    /// Apps that are known to ignore Unicode-string key events (VMs, remote desktop).
    private static let keyCodeApps: Set<String> = [
        "com.parallels.desktop.console", "com.vmware.fusion", "com.utmapp.UTM",
        "org.virtualbox.app.VirtualBoxVM", "com.microsoft.rdc.macos", "com.microsoft.rdc.mac",
        "com.apple.ScreenSharing", "com.teamviewer.TeamViewer", "com.citrix.receiver.nomas",
    ]
    /// Backspace deletes as usual and also steps the text pointer back.
    var backspaceStepsBack = false
    var stepBack: () -> Void = {}
    /// Held keys type once. When false, each auto-repeat types the next character.
    var ignoreAutoRepeat = true
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

    /// Re-enables the tap if macOS disabled it (timeouts, wake from sleep).
    func ensureEnabled() {
        guard let tap, !CGEvent.tapIsEnabled(tap: tap) else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func restart() {
        stop()
        start()
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        tap = nil
        source = nil
        swallowed.removeAll()
        rewritten.removeAll()
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

        let code = event.getIntegerValueField(.keyboardEventKeycode)

        if type == .flagsChanged {
            // Caps Lock mode: the Caps Lock state is the armed state.
            if code == Self.capsLockKeyCode, armKey == .capsLock, !hotkeysSuspended {
                setArmed(event.flags.contains(.maskAlphaShift))
            }
            return pass
        }

        if type == .keyUp {
            if swallowed.remove(code) != nil { return nil }
            if let r = rewritten.removeValue(forKey: code) { apply(r, to: event) }
            return pass
        }

        guard type == .keyDown else { return pass }

        let autorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let mods = event.flags.intersection(ArmKey.modifierMask)

        // Panic combo: always disarms.
        if code == Self.escapeKeyCode, mods == Self.panicFlags {
            if !autorepeat { setArmed(false) }
            swallowed.insert(code)
            return nil
        }
        // Arm combo: toggles.
        if !hotkeysSuspended,
           case let .combo(keyCode, modifiers, _) = armKey,
           code == keyCode, mods.rawValue == modifiers {
            if !autorepeat { setArmed(!isArmed()) }
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

        // Backspace: let it delete, and move the text pointer back with it.
        if code == Self.deleteKeyCode, backspaceStepsBack, mods.isEmpty {
            stepBack()
            return pass
        }

        guard isCharacterKey(code) else { return pass }

        if autorepeat, ignoreAutoRepeat {
            return rewritten[code] != nil ? nil : pass
        }

        guard let ch = nextCharacter() else { return pass } // finished: type normally
        let r = replacement(for: ch)
        rewritten[code] = r
        apply(r, to: event)
        return pass
    }

    /// ANSI printable keys (0...50) minus Return and Tab; Space (49) is optional.
    private func isCharacterKey(_ code: Int64) -> Bool {
        guard (0...50).contains(code), code != 36, code != 48 else { return false }
        return code != 49 || spaceConsumes
    }

    // MARK: - Rewriting

    private func replacement(for ch: Character) -> Replacement {
        if ch.isNewline { return Replacement(unicode: [13], keyCode: Self.returnKeyCode, flags: []) }
        if ch == "\t" { return Replacement(unicode: [9], keyCode: Self.tabKeyCode, flags: []) }
        let unicode = Array(String(ch).utf16)
        if useKeyCodes, let stroke = LayoutMap.keyStroke(for: ch) {
            return Replacement(unicode: unicode, keyCode: stroke.code, flags: stroke.shift ? .maskShift : [])
        }
        return Replacement(unicode: unicode, keyCode: nil, flags: [])
    }

    private func apply(_ r: Replacement, to event: CGEvent) {
        if let code = r.keyCode {
            event.setIntegerValueField(.keyboardEventKeycode, value: Int64(code))
        }
        event.flags = r.flags
        var chars = r.unicode
        event.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
    }

    private var useKeyCodes: Bool {
        if compatibilityMode { return true }
        guard let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return false }
        return Self.keyCodeApps.contains(id)
    }
}
