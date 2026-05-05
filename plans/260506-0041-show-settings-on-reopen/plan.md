---
title: "Show Settings on App Reopen"
status: in-progress
created: 2026-05-06
blockedBy: []
blocks: []
---

# Show Settings on App Reopen

## Problem

When a user who has completed onboarding opens FastTranslate from Applications folder or Spotlight search, the app only shows the menu bar icon. No window appears, causing confusion. Users also miss update notifications since they never see the About tab.

## Solution

Show the Settings window (About tab) when the app is reopened by the user. Two scenarios:

1. **App already running** - user clicks icon in Spotlight/Finder -> `applicationShouldHandleReopen` -> open Settings -> About tab
2. **Fresh manual launch** (not login-item) - user opens from Applications/Spotlight -> detect non-login-item launch -> open Settings -> About tab

Login-item launches (auto-start at login) should NOT show Settings to avoid annoying startup behavior.

## Phases

| # | Phase | Status | File |
|---|-------|--------|------|
| 1 | Implement show-settings-on-reopen | pending | [phase-01](phase-01-implement-show-settings-on-reopen.md) |

## Files to Modify

- `FastTranslate/App/AppDelegate.swift` — add reopen handler + launch detection

## Cook Command

```bash
/ck:cook plans/260506-0041-show-settings-on-reopen/plan.md
```
