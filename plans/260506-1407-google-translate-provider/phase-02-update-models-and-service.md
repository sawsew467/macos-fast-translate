---
phase: 2
title: "Update models and TranslationService"
status: done
priority: P1
effort: "15min"
dependencies: [1]
---

# Phase 2: Update Models and TranslationService

## Overview
Add `googleTranslate` case to `ProviderType` enum and register the new provider in `TranslationService`. Set Google Translate as default for new users.

## Requirements
- Functional: `ProviderType.googleTranslate` available as selectable provider
- Functional: `TranslationService` initializes and routes to `GoogleTranslateProvider`
- Functional: New installs default to Google Translate; existing users with OpenAI key keep OpenAI

## Related Code Files
- Modify: `FastTranslate/Models/TranslationModels.swift`
- Modify: `FastTranslate/Services/TranslationService.swift`

## Implementation Steps

1. **TranslationModels.swift** — Add to `ProviderType`:
   ```swift
   case googleTranslate = "google_translate"
   ```
   Update `displayName`:
   ```swift
   case .googleTranslate: return "Google Translate"
   ```

2. **TranslationService.swift** — Register provider in `init()`:
   ```swift
   providers = [
       .googleTranslate: GoogleTranslateProvider(),
       .openAI: OpenAITranslationProvider()
   ]
   ```

3. **TranslationService.swift** — Update `activeProviderType` default:
   ```swift
   // Default to Google Translate for new users (no UserDefaults value yet)
   return ProviderType(rawValue: raw) ?? .googleTranslate
   ```

4. **Existing user migration**: Users who already saved `"openai"` in UserDefaults keep OpenAI. Only new installs (empty UserDefaults) get `.googleTranslate` default.

## Success Criteria
- [x] `ProviderType.googleTranslate` exists and encodes/decodes correctly
- [x] `TranslationService` routes to `GoogleTranslateProvider` when selected
- [x] New installs default to Google Translate
- [x] Existing users with saved OpenAI preference keep OpenAI

## Risk Assessment
- **Low:** Codable compatibility — adding a new enum case doesn't break existing saved data since `ProviderType(rawValue:)` returns nil for unknown values, which now falls back to `.googleTranslate` instead of `.openAI`.
