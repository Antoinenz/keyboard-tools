import Carbon.HIToolbox
import CoreGraphics

/// Maps a character to the key (and Shift state) that types it on the current keyboard
/// layout. Used as a fallback for apps that ignore Unicode-string key events (some remote
/// desktop clients, VMs and games), which need real key codes.
enum LayoutMap {
    struct Stroke { let code: CGKeyCode; let shift: Bool }

    private static var cachedLayoutID: String?
    private static var table: [Character: Stroke] = [:]

    static func keyStroke(for ch: Character) -> Stroke? {
        rebuildIfLayoutChanged()
        return table[ch]
    }

    private static func rebuildIfLayoutChanged() {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else { return }
        let id = layoutID(of: source)
        if id == cachedLayoutID { return }
        cachedLayoutID = id
        table = build(from: source)
    }

    private static func layoutID(of source: TISInputSource) -> String {
        guard let p = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return "" }
        return Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String
    }

    private static func build(from source: TISInputSource) -> [Character: Stroke] {
        guard let p = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return [:] }
        let data = Unmanaged<CFData>.fromOpaque(p).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return [:] }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        let kbdType = UInt32(LMGetKbdType())

        var result: [Character: Stroke] = [:]
        // Unshifted first so that, if both could type a character, the plain key wins.
        for shift in [false, true] {
            let modifiers: UInt32 = shift ? UInt32(shiftKey >> 8) & 0xFF : 0
            for code in 0...50 where code != 36 && code != 48 { // Return, Tab
                var dead: UInt32 = 0
                var length = 0
                var chars = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(
                    layout, UInt16(code), UInt16(kUCKeyActionDown), modifiers, kbdType,
                    OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, chars.count, &length, &chars)
                guard status == noErr, length == 1, chars[0] >= 0x20, chars[0] != 0x7F else { continue }
                let ch = Character(String(utf16CodeUnits: chars, count: length))
                if result[ch] == nil { result[ch] = Stroke(code: CGKeyCode(code), shift: shift) }
            }
        }
        return result
    }
}
