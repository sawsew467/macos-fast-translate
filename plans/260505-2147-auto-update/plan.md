---
title: "Auto-Update via GitHub Releases"
status: complete
created: 2026-05-05
phases: 4
blockedBy: []
blocks: []
---

# Auto-Update via GitHub Releases

## Goal
Allow users to check for updates from within the app and install new versions without manually downloading from GitHub Releases.

## Approach Decision

| Option | Pros | Cons | Fit |
|--------|------|------|-----|
| **Sparkle 2.x** | Industry standard, delta updates, release notes UI, automatic checks | Heavy (~5MB), requires appcast.xml hosting, EdDSA key mgmt | Over-engineered for this app |
| **s1ntoneli/AppUpdater** | GitHub-native, ObservableObject, code-sign verification, ~100KB | Smaller community, no delta updates | Good balance |
| **DIY (GitHub API)** | Zero deps, full control | Must implement download/replace/restart manually | Too much work |

**Recommendation: s1ntoneli/AppUpdater** — lightweight, works directly with GitHub Releases (no appcast.xml), SwiftUI-native, code signature verification built-in. Aligns with app's zero-bloat philosophy.

## Key Facts
- App is NOT sandboxed (entitlements: `app-sandbox = false`)
- Already distributed via GitHub Releases as signed+notarized DMG
- Repo: `sawsew467/macos-fast-translate`
- Current version: 1.1.0, `MARKETING_VERSION` in project.pbxproj

## Phases

| # | Phase | Status | Priority | Effort |
|---|-------|--------|----------|--------|
| 1 | [UpdateService (DIY)](phase-01-spm-update-service.md) | ✅ complete | P1 | 1h |
| 2 | [UI Integration (Settings + Menu)](phase-02-ui-integration.md) | ✅ complete | P1 | 1h |
| 3 | [Release Workflow Update](phase-03-release-workflow.md) | ✅ complete | P2 | 30m |
| 4 | [Testing & Docs](phase-04-testing-docs.md) | ✅ complete | P2 | 30m |

## Architecture

```
AppDelegate.applicationDidFinishLaunching()
  └─► UpdateService.shared.checkOnLaunch()
        └─► GitHub API: GET /repos/sawsew467/macos-fast-translate/releases/latest
              └─► Compare tag vs CFBundleShortVersionString
                    └─► If newer → show update alert / update Settings badge

SettingsView → "About" tab
  └─► "Check for Updates" button → UpdateService.check()
        └─► Download .zip → verify code signature → replace .app → restart

Right-click menu bar icon
  └─► "Check for Updates…" menu item
```
