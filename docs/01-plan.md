# Design: Feeder (macOS menu bar app)

Originally the plan; updated to describe what was built.

## How it works
1. A CGEventTap (session level) watches key-down, key-up and flags-changed events.
2. Disarmed: every event passes through untouched.
3. Armed: a real character keypress is rewritten in place: its Unicode string (and, in compatibility mode, key code and Shift) is replaced with the next character via `CGEvent.keyboardSetUnicodeString`.
4. The matching key-up is rewritten the same way, so apps never see an unpaired event.
5. Rewriting the real event, rather than swallowing it and posting a new one, keeps strict ordering with other keys. (The first version posted synthetic events and reordered under fast typing; see docs/03-testing.md.)
6. Only hotkey presses (arm combo, panic) are swallowed.

## Permissions and distribution
- Input Monitoring (see keystrokes) and Accessibility (an active tap that swallows/injects events).
- Not sandboxed (event taps do not work in the sandbox), so no App Store. Distributed as a DMG signed with an Apple Development identity and not notarized; see docs/04-release.md.
- First-run onboarding checks `AXIsProcessTrusted` and `CGPreflightListenEventAccess`, deep-links to System Settings, re-checks live.
- Use a stable signing identity in development: TCC grants are tied to the code signature.

## Components
| Piece | Job |
|---|---|
| KeyTap | Owns the tap on the main run loop; re-enables on `tapDisabledByTimeout` and after wake; decides pass / swallow / rewrite. |
| TextFeeder | Text as grapheme clusters plus index: next(), back(), reset(), loop / end behaviour. Platform-independent. |
| ArmKey / HotkeyStore | The arm keybind (Caps Lock or a combo) and its persistence. |
| KeyRecorder | Records a new arm key in Settings. |
| LayoutMap | Character to key code (+Shift) for the current layout, for compatibility mode. |
| AppState | Armed state, preferences, permission polling, wake handling. |
| Permissions | Checks and deep links. |
| UI | MenuBarExtra (window style) and a Settings window. |

## UI
- Agent app (`LSUIElement = true`), no Dock icon; menu bar icon changes when armed.
- Popover: paste box, Arm/Disarm toggle, progress ("142 / 980") with next-up preview, Reset, Clear.
- Settings: arm keybind recorder (Caps Lock is first-class); toggles for loop at end, auto-disarm at end, Backspace steps back, ignore auto-repeat, Space consumes a character; launch at login (SMAppService); sound.

## Arming
- Caps Lock mode: armed follows the `alphaShift` flag from flagsChanged (LED doubles as indicator).
- Any other keybind: toggles; the keypress itself is swallowed.
- Safety: hardcoded panic combo (Ctrl+Opt+Cmd+Esc) always disarms; menu bar disarm; auto-disarm if the tap dies or permissions are revoked.

## Key rules while armed
- Consume: letters, digits, punctuation, optionally Space.
- Pass through: anything with Cmd or Ctrl held; arrows, Esc, function keys; Return and Tab by default.
- Newline in the text is injected as a real Return keypress.
- Backspace (option) steps the pointer back and deletes.
- Output is exactly the text character, regardless of Shift/Caps state.

## Edge cases
- Emoji / non-ASCII via Unicode-string events.
- Apps that ignore Unicode events (some terminals, remote desktop, games): fallback maps char to keycode + Shift for the current layout via `UCKeyTranslate`.
- Secure input (password fields) blocks taps; show a notice when active.
- Key auto-repeat ignored by default.
- Privacy: text stays in memory; keystrokes never logged or sent anywhere.

## Milestones (all done for v0.1.0)
1. Scaffold: menu bar agent, popover, permission onboarding.
2. Tap and injection spike.
3. Feeder model (newlines, Unicode, back, reset) with unit tests.
4. Keybind recorder, Caps Lock mode, panic disarm.
5. Settings and polish (toggles, launch at login, icon states, sound).
6. Hardening: wake recovery, layout fallback, secure input notice, smoke tests (manual checklist still open, see 03-testing.md).
7. Install script, DMG, app icon. Notarization skipped (no Developer ID).

## Decisions
1. Arm default: Caps Lock.
2. Space consumes a character (a setting).
3. Distribution: GitHub release DMG, signed with an Apple Development identity, not notarized; users click Open Anyway.
