# Testing

## Automated
`xcodebuild -project Feeder.xcodeproj -scheme Feeder -derivedDataPath build test` runs the unit tests (TextFeeder, ArmKey).

## Smoke test against a real app (done in milestone 6)
Debug builds accept launch arguments so the tap can be driven without clicking the UI:

```bash
open build/Build/Products/Debug/Feeder.app --args -FeederDebugText "some text" -FeederDebugArmed YES \
  -loopAtEnd "<true/>"
```

Boolean preferences must be passed as plist (`"<true/>"`), strings work as-is. A small helper posted raw key events (`CGEvent` via the HID tap) while TextEdit was frontmost, and the document text was read back with AppleScript. Verified:

| Case | Result |
|---|---|
| ASCII, 10 keypresses | exact text |
| Umlaut, emoji with skin tone, newline | exact text |
| Keypresses after the text ends | type normally (auto-disarm) |
| Compatibility mode (key codes + Shift) | exact text |
| Backspace steps back (option on) | text stays consistent |
| Loop at end | wraps to the start |

### Bug found and fixed
The first implementation swallowed the key and posted a new event. Under fast typing the posted event could arrive after the next, unmodified real key ("linea2" instead of "line2a"). Feeder now rewrites the real event in place, which keeps strict ordering.

## Manual checklist (needs a person)
- Arm key recorder and combo arming; Caps Lock mode LED sync.
- Panic disarm: Ctrl+Opt+Cmd+Esc.
- Sleep and wake while armed (tap should recover; icon should still react).
- Secure input: focus a password field, the popover shows the notice, typing is untouched.
- Safari, Terminal, VS Code, Notes: characters and newlines come out right.
- A VM or remote desktop app (key-code path switches on automatically).
- Non-US layout: Compatibility mode produces the right characters.
- Launch at login (needs the app in /Applications, may need approval in Login Items).

## Known limits
- IME composition (Japanese, Chinese, etc.) may mangle injected text.
- Apps that read raw key codes only (some games) need Compatibility mode, and characters the layout can't type fall back to the normal method.
- Secure input hides keystrokes from every tap, so Feeder cannot work in password fields (by design).
