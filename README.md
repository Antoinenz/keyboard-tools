# Feeder

A macOS menu bar app that types a text you paste in, one character per keypress. Arm it, then mash the keyboard: each key you press types the next character of your text instead. Disarm at any time to go back to normal typing.

## Install
1. Download `Feeder-<version>.dmg` from the [latest release](../../releases/latest) and drag **Feeder** into **Applications**.
2. Open it. macOS will say it can't check the app for malicious software, because Feeder isn't notarized. To allow it:
   - Open **System Settings > Privacy & Security**, scroll to the **Security** section and click **Open Anyway** next to "Feeder was blocked", then confirm.
   - If that button doesn't appear, run `xattr -dr com.apple.quarantine /Applications/Feeder.app` in Terminal and open it again.
3. Click the keyboard icon in the menu bar and press **Grant…** next to **Accessibility** and **Input Monitoring**. Switch Feeder on in both lists in System Settings. It starts working as soon as both are on, with no relaunch.

Requires macOS 14 or later.

## Use
1. Click the menu bar icon and paste your text into the box.
2. Switch to any app and **arm** Feeder: turn Caps Lock on (the default), or press the arm key you chose in Settings. The menu bar icon fills in.
3. Press keys. Each letter, digit, punctuation key and (optionally) Space types the next character of your text. Newlines come out as Return.
4. **Disarm** by turning Caps Lock off, pressing your arm key again, or toggling Armed in the popover. Emergency disarm: **⌃⌥⌘Esc** always works.

Shortcuts (anything with ⌘ or ⌃), arrows, Esc and function keys always work normally. Feeder disarms by itself when the text runs out.

### Settings
- **Arm key:** Caps Lock, or any combo with ⌘, ⌃ or ⌥ (or a function key), recorded in Settings.
- **Typing:** whether Space types a character, whether Backspace deletes and steps the text back, whether holding a key types once, and Compatibility mode (types with real key codes, for apps that ignore the normal method; remote desktop and VM apps switch to it automatically).
- **At the end of the text:** start over, or disarm.
- **General:** launch at login, sounds.

### Good to know
- Your text lives in memory only. Feeder never logs or sends keystrokes anywhere.
- In password fields macOS hides keystrokes from every app, so Feeder can't act there and you type normally. The popover tells you when this is on.
- Input methods that compose text (Japanese, Chinese, and so on) may mangle the output.
- The menu bar icon shows a warning triangle while a permission is missing.

## Build from source
Needs Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen generate
xcodebuild -project Feeder.xcodeproj -scheme Feeder -derivedDataPath build test   # unit tests
scripts/install.sh      # build, sign with your Apple Development identity, install to /Applications
scripts/release.sh      # build and package dist/Feeder-<version>.dmg
```

`project.yml` is the source of truth; `Feeder.xcodeproj` is generated. See [docs/](docs/) for the design, testing notes, release process and Windows port thoughts.

## Status
Version 0.1.0. Works on the author's Mac; not notarized (no paid Apple Developer account). Windows port: not started, see [docs/02-windows-and-stack.md](docs/02-windows-and-stack.md).
