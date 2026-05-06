---
phase: 1
title: "Create GoogleTranslateProvider"
status: done
priority: P1
effort: "30min"
dependencies: []
---

# Phase 1: Create GoogleTranslateProvider

## Overview
Implement a new `GoogleTranslateProvider` conforming to `TranslationProvider` protocol. Uses the unofficial free Google Translate endpoint that requires no API key.

## Requirements
- Functional: Translate text between all languages defined in `Language` enum via Google Translate
- Functional: Parse the nested JSON array response format correctly
- Functional: Map app's `Language` enum rawValues to Google Translate language codes
- Non-functional: Handle network errors, rate limiting, empty responses gracefully

## Architecture

```
GoogleTranslateProvider: TranslationProvider
├── translate(_:from:to:context:) → String
├── translateStream(…) → uses default fallback (single-shot)
└── Private helpers:
    ├── buildURL(text:source:target:) → URL
    ├── parseResponse(data:) → String
    └── languageCode(for:) → String
```

**Endpoint:** `https://translate.googleapis.com/translate_a/single`
**Params:** `client=gtx&sl={src}&tl={tgt}&dt=t&q={urlencoded_text}`
**Response:** Nested JSON array — `[[["translated text","source text",...],...],null,"detected_lang"]`

Note: `context` parameter is ignored — Google Translate doesn't support contextual translation. This is a known limitation; users wanting context-aware translation should use OpenAI.

## Related Code Files
- Create: `FastTranslate/Services/GoogleTranslateProvider.swift`
- Read: `FastTranslate/Services/TranslationProvider.swift` (protocol to conform to)
- Read: `FastTranslate/Services/OpenAITranslationProvider.swift` (reference implementation)
- Read: `FastTranslate/Models/TranslationModels.swift` (Language enum, TranslationError)

## Implementation Steps

1. Create `FastTranslate/Services/GoogleTranslateProvider.swift`
2. Implement `TranslationProvider` protocol:
   - `name` = "Google Translate"
   - `providerType` = `.googleTranslate` (added in phase 2)
3. Build request URL with proper URL encoding for Unicode text (Vietnamese diacritics)
4. Parse nested JSON array response — handle multi-segment translations (long text split across array elements)
5. Map `Language.autoDetect` to `sl=auto`
6. Map other `Language` rawValues — most match Google codes already (`vi`, `en`, `ja`, etc.) except:
   - `.simplifiedChinese` ("zh-Hans") → `zh-CN`
   - `.traditionalChinese` ("zh-Hant") → `zh-TW`
7. No streaming support — use default protocol extension fallback
8. Error handling:
   - Network failure → `TranslationError.networkError`
   - HTTP 429 → `TranslationError.rateLimited`
   - Empty/unparseable response → `TranslationError.invalidResponse`
   - No need for `TranslationError.noAPIKey` (keyless)

## Success Criteria
- [x] `GoogleTranslateProvider` compiles and conforms to `TranslationProvider`
- [x] Correctly translates EN→VI and VI→EN text
- [x] Handles Unicode/diacritics in both input and output
- [x] Multi-segment long text responses are joined correctly
- [x] Errors mapped to existing `TranslationError` cases

## Risk Assessment
- **URL encoding:** Vietnamese diacritics must be properly percent-encoded. Use `addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)`.
- **Response format:** Google may change the JSON structure. Keep parser simple, fail gracefully.
