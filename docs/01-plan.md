# Plan: Feeder (macOS menu bar app)

## How it works
1. A CGEventTap (session level) watches key-down, key-up and flags-changed events.
2. Disarmed: every event passes through untouched.
3. Armed: a real character keypress is swallowed (callback returns nil) and a synthetic key event carrying the next character is posted via `CGEvent.keyboardSetUnicodeString`.
4. The matching key-up is swallowed too, so apps never see an unpaired event.
5. Synthetic events carry a marker in `eventSourceUserData` so the tap ignores its own output.

## Permissions and distribution
- Input Monitoring (see keystrokes) and Accessibility (an active tap that swallows/injects events).
- Not sandboxed (event taps do not work in the sandbox). Distribute outside the App Store: Developer ID, notarized.
- First-run onboarding checks `AXIsProcessTrusted` and `CGPreflightListenEventAccess`, deep-links to System Settings, re-checks live.
- Use a stable signing identity in development: TCC grants are tied to the code signature.

## Components
| Piece | Job |
|---|---|
| KeyTap | Owns the tap on a background run loop; re-enables on `tapDisabledByTimeout` and after wake; decides pass / swallow / inject. |
| TextFeeder | Text as grapheme clusters plus index: next(), back(), reset(), loop / end behaviour. Platform-independent. |
| ArmController | Armed state driven by the arm keybind; sound/HUD feedback. |
| HotkeyStore | Persists the keybind (keycode, modifiers, or caps-lock mode). |
| Permissions | Checks and deep links. |
| UI | MenuBarExtra (window style) and Settings scene. |

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

## Milestones
1. Scaffold: menu bar agent, popover, permission onboarding.
2. Tap + injection spike with a hardcoded arm key.
3. Feeder model (newlines, Unicode, back, reset) with unit tests.
4. Keybind recorder, Caps Lock mode, panic disarm.
5. Settings and polish (toggles, launch at login, icon states, sound).
6. Hardening: sleep/wake, tap timeout, layout fallback; manual tests in TextEdit, Safari, Terminal, VS Code.
7. Sign, notarize, DMG.

## Decisions (defaults)
1. Arm default: Caps Lock.
2. Space consumes a character.
3. Distribution: just the owner first (Developer ID / local signing).
