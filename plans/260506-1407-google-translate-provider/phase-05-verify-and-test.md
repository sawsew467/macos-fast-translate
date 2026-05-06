---
phase: 5
title: "Verify and test"
status: done
priority: P1
effort: "15min"
dependencies: [1, 2, 3, 4]
---

# Phase 5: Verify and Test

## Overview
Build, run, and manually verify all Google Translate integration points work end-to-end.

## Requirements
- App compiles without warnings on deployment target
- All translation flows work with Google Translate selected
- Provider switching works correctly
- Onboarding flow works for new users

## Implementation Steps

1. **Build verification:**
   - Clean build (`Cmd+Shift+K` then `Cmd+B`)
   - Resolve any compile errors or warnings

2. **Google Translate provider tests:**
   - EN→VI: "Hello, how are you?" → natural Vietnamese
   - VI→EN: "Xin chao ban" → natural English
   - Auto-detect: mixed text → correct detection
   - Long text (>500 chars): multi-segment response parsed correctly
   - Chinese (Simplified/Traditional): verify language code mapping
   - Empty input: proper error handling
   - Network offline: proper error message

3. **Settings tests:**
   - Provider picker shows both options
   - Switch Google Translate → OpenAI → back → translations use correct provider
   - API Keys tab shows contextual message

4. **Onboarding tests (reset `has_launched_before`):**
   - Fresh launch → provider choice screen appears
   - Select Google Translate → Continue → permissions → ready (no key needed)
   - Select OpenAI → key entry UI appears → can still Continue without key

5. **Screenshot OCR test:**
   - With Google Translate: screenshot → OCR → translate → result shows
   - Chat detection context is ignored (expected, no context support)

6. **Hotkey tests:**
   - Ctrl+Opt+T (translate selected text) works with Google Translate
   - Ctrl+Opt+S (screenshot OCR) works with Google Translate

## Success Criteria
- [x] Clean compile, no warnings
- [ ] Google Translate works for all supported languages
- [ ] Provider switching works in Settings
- [ ] Onboarding allows zero-config start
- [ ] Hotkey translation flows work with both providers
- [ ] Screenshot OCR + translate works with Google Translate

## Risk Assessment
- **Testing note:** Google Translate endpoint requires internet. If testing offline, expect network errors (not a bug).
