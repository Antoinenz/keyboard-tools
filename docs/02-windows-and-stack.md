# Windows port and stack choice

## Decision
Build the Mac app in **Swift/SwiftUI**. Keep the core logic (TextFeeder, key-rule decisions) small and free of platform APIs so it can be re-implemented or shared later. Do not pay a cross-platform tax up front.

## How hard is Windows?
The engine is easier on Windows than on macOS:
- Intercept and swallow: `SetWindowsHookEx(WH_KEYBOARD_LL)`; return non-zero to swallow.
- Inject: `SendInput` with `KEYEVENTF_UNICODE` (works for any character, no layout fallback needed in most apps).
- Caps Lock state: `GetKeyState(VK_CAPITAL)`.
- No Input Monitoring / Accessibility style permission prompts.
- Gotchas: UIPI (cannot inject into elevated/admin windows unless we run elevated), hook must stay responsive or Windows silently unhooks it, injected events are flagged `LLKHF_INJECTED` (use that instead of a user-data marker), antivirus may flag keyboard hooks.
- Tray icon (Shell_NotifyIcon), launch at login (registry Run key), and a settings window are the real work.

Rough split: engine ~200 lines per OS; TextFeeder ~100 lines; the bulk is UI, onboarding and packaging/signing.

## Options for a cross-platform build
| Option | Pros | Cons |
|---|---|---|
| Swift on Mac + native Windows app later (C#/WinUI or Rust) | Best Mac menu bar polish, SMAppService, clean TCC handling; each app idiomatic | Two UIs; feeder logic written twice (small) |
| Rust core + native UIs | Shared logic, one tested core | FFI glue; native UIs still needed |
| Tauri 2 (Rust core + web UI) | One codebase, tray support, hooks behind `cfg(target_os)` | Menu bar app feels less native; Mac permission onboarding and signing identity need care; larger binary |

## Pick
Swift now. If a Windows version is wanted, the cheapest path is a separate small Windows app (Rust or C#) reusing the same behaviour spec in docs/01-plan.md, since the logic is tiny. Only switch to Tauri if one shared codebase becomes a firm requirement.
