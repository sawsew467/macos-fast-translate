---
date: 2026-05-05
type: journal
feature: auto-update via GitHub Releases
---

# Auto-Update Feature — Session Journal

## What shipped

Implemented end-to-end auto-update for FastTranslate using a DIY approach with zero external dependencies. The app can now detect, download, and install new versions from GitHub Releases without the user having to visit GitHub manually.

## Key decision: DIY over AppUpdater SPM

The plan recommended `s1ntoneli/AppUpdater` but I switched to a DIY implementation. Reasons:
- Adding SPM to `project.pbxproj` manually is complex and error-prone without Xcode UI
- Exact API of AppUpdater v0.1.5 was unverifiable (no internet access to check)
- The actual functionality is ~190 lines of URLSession + Process calls — not "too much work" as the plan stated

The plan was right about the capability (GitHub API, ZIP download, replace + relaunch) — just wrong about the effort. DIY gave us full control with better debuggability.

## How the install flow works

The tricky part is replacing a running app. Solution: write a short bash script to `/tmp/FastTranslate-updater.sh` that sleeps 1 second (gives the app time to quit), then `rm -rf` the old `.app`, `mv` the new one in, and `open` it. We `Process.run()` the script, then immediately call `NSApp.terminate(nil)`. Clean and reliable for non-sandboxed apps.

## Files changed

- `FastTranslate/Services/UpdateService.swift` — new (188 lines)
- `FastTranslate/App/AppDelegate.swift` — +8 lines (launch check + menu item)
- `FastTranslate/Views/SettingsView.swift` — +80 lines (AboutSettingsTab)
- `scripts/build-dmg.sh` — +8 lines (ditto ZIP step)
- `FastTranslate.xcodeproj/project.pbxproj` — +4 entries (file registration)

## Risks to watch

- Install requires write access to the app location. If installed in `/Applications` on a multi-user Mac, replacement may need admin auth — currently falls back silently to browser.
- Release ZIP must contain `FastTranslate.app` at root level. `ditto` preserves this structure.
