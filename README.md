# keyboard-tools

A macOS menu bar app (working name **Feeder**) that, when armed, replaces each key you press with the next character of a pasted text. Disarm at any time to type normally.

See [docs/](docs/) for the plan and the Windows/stack notes.

## Status
| Milestone | State |
|---|---|
| 1-2 Scaffold, tap and injection | done |
| 3 Feeder model and tests | done |
| 4 Arm key recorder, Caps Lock mode, panic disarm | done |
| 5 Settings and polish | done |
| 6 Hardening (sleep/wake, layout fallback, app testing) | next |
| 7 Sign, notarize, DMG | todo |

## Build
Needs Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen generate
xcodebuild -project Feeder.xcodeproj -scheme Feeder -derivedDataPath build test
xcodebuild -project Feeder.xcodeproj -scheme Feeder -derivedDataPath build build
open build/Build/Products/Debug/Feeder.app
```

On first launch grant **Accessibility** and **Input Monitoring** from the menu bar popover. Panic disarm: Ctrl+Opt+Cmd+Esc.
