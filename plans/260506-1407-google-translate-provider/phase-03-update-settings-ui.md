---
phase: 3
title: "Update Settings UI with provider picker"
status: done
priority: P1
effort: "20min"
dependencies: [2]
---

# Phase 3: Update Settings UI with Provider Picker

## Overview
Add a translation provider picker to the General settings tab so users can switch between Google Translate and OpenAI. Make API Keys tab contextual — only relevant when OpenAI is selected.

## Requirements
- Functional: Provider picker in General tab (Google Translate / OpenAI)
- Functional: API Keys tab shows hint when Google Translate is active
- Non-functional: Match existing SettingsCard design pattern

## Related Code Files
- Modify: `FastTranslate/Views/SettingsView.swift`

## Implementation Steps

1. **GeneralSettingsTab** — Add provider picker using existing `SettingsCard` pattern:
   ```swift
   @AppStorage(Constants.UserDefaultsKey.defaultProvider) private var defaultProvider = ProviderType.googleTranslate.rawValue
   ```
   Add a `SettingsCard` with systemImage "brain", title "Translation Engine":
   - Picker with `ProviderType.allCases`
   - Subtitle explaining: Google Translate = free, no key. OpenAI = better quality, needs key.

2. **APIKeysSettingsTab** — Add info banner at top when provider is Google Translate:
   - "You're using Google Translate (free). Switch to OpenAI in General settings for AI-powered translation with context support."
   - Only show OpenAI key fields (no change to existing UI)

3. **Provider picker position:** Place ABOVE the Language picker in General tab (provider choice is more important).

## Success Criteria
- [x] Provider picker shows both options in General tab
- [x] Switching provider persists to UserDefaults
- [x] API Keys tab shows contextual info based on active provider
- [x] Matches existing visual style (SettingsCard, Picker, etc.)

## Risk Assessment
- **blockedBy `260506-1354-lower-macos-target`**: That plan also modifies `SettingsView.swift` (onChange signatures). Must complete first to avoid merge conflicts.
