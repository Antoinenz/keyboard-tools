import Foundation
import CoreGraphics

/// What arms/disarms the feeder.
enum ArmKey: Codable, Equatable {
    /// Armed while Caps Lock is on (the LED doubles as the indicator).
    case capsLock
    /// A key combo that toggles armed state. `modifiers` is a CGEventFlags raw value
    /// restricted to `ArmKey.modifierMask`.
    case combo(keyCode: Int64, modifiers: UInt64, label: String)

    static let modifierMask: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]

    var displayName: String {
        switch self {
        case .capsLock: return "Caps Lock"
        case let .combo(_, modifiers, label):
            return Self.symbols(for: CGEventFlags(rawValue: modifiers)) + label
        }
    }

    static func symbols(for flags: CGEventFlags) -> String {
        var s = ""
        if flags.contains(.maskControl) { s += "⌃" }
        if flags.contains(.maskAlternate) { s += "⌥" }
        if flags.contains(.maskShift) { s += "⇧" }
        if flags.contains(.maskCommand) { s += "⌘" }
        return s
    }

    /// Function keys (F1...F12), which are safe to use without a modifier.
    static let functionKeyCodes: Set<Int64> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]

    /// A combo is only accepted if it can't be confused with ordinary typing.
    static func isAcceptable(keyCode: Int64, modifiers: CGEventFlags) -> Bool {
        let m = modifiers.intersection(modifierMask)
        return m.contains(.maskCommand) || m.contains(.maskControl) || m.contains(.maskAlternate)
            || functionKeyCodes.contains(keyCode)
    }

    static func label(forKeyCode code: Int64, characters: String?) -> String {
        switch code {
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 51: return "Delete"
        case 53: return "Esc"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default:
            if let c = characters?.uppercased(), !c.isEmpty { return c }
            return "Key \(code)"
        }
    }
}

enum HotkeyStore {
    private static let key = "armKey"

    static func load() -> ArmKey {
        guard let data = UserDefaults.standard.data(forKey: key),
              let k = try? JSONDecoder().decode(ArmKey.self, from: data) else { return .capsLock }
        return k
    }

    static func save(_ armKey: ArmKey) {
        if let data = try? JSONEncoder().encode(armKey) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
