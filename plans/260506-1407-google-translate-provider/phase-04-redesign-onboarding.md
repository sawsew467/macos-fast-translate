---
phase: 4
title: "Redesign Onboarding flow"
status: done
priority: P1
effort: "30min"
dependencies: [2]
---

# Phase 4: Redesign Onboarding Flow

## Overview
Redesign onboarding step 1 from mandatory "Connect OpenAI" to a provider choice screen. Users can start with Google Translate (zero config) or optionally enter an OpenAI key.

## Requirements
- Functional: Step 1 presents provider choice (Google Translate default, OpenAI optional)
- Functional: Choosing Google Translate → skip API key entry, go straight to permissions
- Functional: Choosing OpenAI → show existing API key entry UI
- Functional: "Continue" always enabled (no longer blocked by missing API key)
- Non-functional: Clean, non-intimidating UI for non-technical users

## Architecture

**Current flow:**
```
Step 1: API Key (mandatory) → Step 2: Permissions → Step 3: Ready
```

**New flow:**
```
Step 1: Choose Provider → Step 2: Permissions → Step 3: Ready
         ├── Google Translate (default) → Continue immediately
         └── OpenAI → Show key entry → Continue
```

## Related Code Files
- Modify: `FastTranslate/Views/OnboardingView.swift`

## Implementation Steps

1. **Rename step 1** from "API Key" to "Translation" in `steps` array:
   ```swift
   private let steps = ["Translation", "Permissions", "Ready"]
   ```

2. **Replace `apiKeyStep`** with new `providerStep`:
   - Two `ProviderOptionCard` views side by side:
     - **Google Translate**: icon "globe", label "Google Translate", subtitle "Free, no setup needed", badge "Recommended"
     - **OpenAI**: icon "sparkles", label "OpenAI GPT", subtitle "Better quality, requires API key"
   - Selection saves to `@AppStorage(Constants.UserDefaultsKey.defaultProvider)`
   - When OpenAI selected → expand to show existing SecureField + Test/Save buttons (reuse current logic)
   - When Google Translate selected → show simple "Ready to go!" message

3. **SetupCard** title/subtitle update:
   - Title: "Choose your translator"
   - Subtitle: "You can change this anytime in Settings."

4. **"Continue" button**: Always enabled regardless of provider choice. Remove the dependency on API key validation for navigation.

5. **Keep existing API key logic** (test/save functions) — just conditionally shown when OpenAI is selected.

6. **Clean up**: Remove `@State private var apiKey`, `isTesting`, `testStatus` from view level — move into a conditional sub-view or keep but only show when OpenAI selected.

## Success Criteria
- [x] Onboarding shows provider choice as step 1
- [x] Google Translate option requires zero input — user can Continue immediately
- [x] OpenAI option shows key entry UI (existing behavior)
- [x] Provider choice is saved to UserDefaults
- [x] Continue button is never disabled
- [x] Existing SetupCard/StepPill design language preserved

## Risk Assessment
- **UX risk:** Non-technical users may not understand "provider" terminology. Use simple language: "Google Translate" vs "OpenAI GPT" with clear descriptions.
- **State risk:** Existing users who completed onboarding won't see the new flow. That's fine — they can change provider in Settings.
