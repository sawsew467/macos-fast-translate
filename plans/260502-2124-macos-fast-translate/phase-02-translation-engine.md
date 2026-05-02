---
phase: 2
title: "Translation Engine"
status: pending
priority: P0
effort: "4h"
dependencies: [1]
---

# Phase 2: Translation Engine

## Overview
Translation service layer: provider protocol, GPT-4o-mini implementation, language auto-detection, và 3-layer context system (persistent + per-message + screenshot).

## Requirements
- **Functional:**
  - Protocol-based provider (swappable GPT-4o-mini / Claude Sonnet)
  - Auto-detect Vi↔En direction
  - 3 loại context: persistent (từ Settings), per-message (user gõ), screenshot (OCR vùng rộng)
  - Async/await API
- **Non-functional:**
  - Response time < 3s cho tin nhắn ngắn
  - Graceful error handling (network, rate limit, invalid API key)
  - Token-efficient prompts

## Architecture

### Files
```
Services/
├── TranslationProvider.swift          # Protocol definition
├── OpenAITranslationProvider.swift    # GPT-4o-mini via OpenAI API
├── TranslationService.swift           # Coordinator + context management
└── LanguageDetector.swift             # Vi/En auto-detection
```

### Provider Protocol
```swift
protocol TranslationProvider {
    var name: String { get }
    var providerType: TranslationProviderType { get }

    /// Translate text with optional context for better accuracy
    func translate(
        _ text: String,
        from source: Language,
        to target: Language,
        context: TranslationContext?
    ) async throws -> String
}

/// 3-layer context system
struct TranslationContext {
    var persistent: String?    // Từ Settings, luôn gửi kèm
    var perMessage: String?    // User gõ trong popover cho lần dịch này
    var screenshot: String?    // OCR text từ vùng xung quanh (Phase 5)
}
```

### OpenAI API Call
```swift
// POST https://api.openai.com/v1/chat/completions
// Model: gpt-4o-mini
// System prompt ví dụ:
"""
You are a translator. Translate the following from {source} to {target}.
Return ONLY the translation, no explanations.

{context nếu có:}
Context: {persistent + perMessage + screenshot}
"""
```

### Language Detection Logic
```swift
struct LanguageDetector {
    /// Detect based on Unicode ranges + common Vietnamese diacritics
    static func detect(_ text: String) -> Language {
        // Vietnamese-specific characters: ă, â, đ, ê, ô, ơ, ư
        // Vietnamese tone marks: ́, ̀, ̉, ̃, ̣
        // If text contains Vietnamese chars → .vietnamese
        // Else → .english
    }
}
```

Cách detect: check tỷ lệ ký tự Vietnamese diacritics. Nếu >5% chars là Vietnamese → source = .vietnamese, target = .english. Ngược lại → source = .english, target = .vietnamese.

### TranslationService (Coordinator)
```swift
class TranslationService: ObservableObject {
    @Published var activeProvider: TranslationProviderType = .openai
    @Published var isTranslating = false
    @Published var lastResult: TranslationResult?
    @Published var history: [TranslationResult] = []

    // Persistent context from Settings
    var persistentContext: String { UserDefaults... }

    func translate(
        _ text: String,
        perMessageContext: String? = nil,
        screenshotContext: String? = nil
    ) async throws -> TranslationResult {
        // 1. Detect language
        // 2. Build TranslationContext (merge 3 layers)
        // 3. Call active provider
        // 4. Create TranslationResult
        // 5. Add to history
        // 6. Return result
    }
}
```

### Error Handling
```swift
enum TranslationError: LocalizedError {
    case noAPIKey
    case networkError(Error)
    case rateLimited
    case invalidResponse
    case emptyInput

    var errorDescription: String? { ... }
}
```

## Related Code Files
- Create: `FastTranslate/Services/TranslationProvider.swift`
- Create: `FastTranslate/Services/OpenAITranslationProvider.swift`
- Create: `FastTranslate/Services/TranslationService.swift`
- Create: `FastTranslate/Services/LanguageDetector.swift`
- Modify: `FastTranslate/Models/TranslationModels.swift` (add TranslationContext, TranslationError)

## Implementation Steps
1. Định nghĩa `TranslationProvider` protocol với context parameter
2. Định nghĩa `TranslationContext` struct (persistent, perMessage, screenshot)
3. Định nghĩa `TranslationError` enum
4. Implement `LanguageDetector` — Unicode range check cho Vietnamese diacritics
5. Implement `OpenAITranslationProvider`:
   - Build system prompt với context nếu có
   - POST to OpenAI Chat Completions API
   - Parse response, extract translated text
   - Handle errors (401 invalid key, 429 rate limit, network)
6. Implement `TranslationService`:
   - Manage active provider
   - Merge 3 context layers
   - Auto-detect language direction
   - Maintain translation history (last 50)
   - Publish state via @Published for SwiftUI binding
7. Test: dịch Vi→En và En→Vi, verify context improves translation quality

### OpenAI API Details
```
Endpoint: POST https://api.openai.com/v1/chat/completions
Headers:
  Authorization: Bearer {api_key}
  Content-Type: application/json
Body:
  model: "gpt-4o-mini"
  messages: [
    { role: "system", content: "{system prompt}" },
    { role: "user", content: "{text to translate}" }
  ]
  temperature: 0.3   // Low for consistent translation
  max_tokens: 2048
```

### System Prompt Template
```
You are a professional translator between Vietnamese and English.
Translate the following text from {source_language} to {target_language}.
Return ONLY the translated text. Do not add explanations or notes.
Keep the same tone and register as the original.
{if context exists:}

Additional context for accurate translation:
{persistent_context}
{per_message_context}
{screenshot_context}
```

## Success Criteria
- [ ] Dịch Vi→En chính xác (test 5 câu thường dùng)
- [ ] Dịch En→Vi chính xác
- [ ] Auto-detect language direction đúng
- [ ] Context cải thiện chất lượng dịch (test câu có từ chuyên ngành)
- [ ] Error handling: no API key → thông báo lỗi rõ ràng
- [ ] Error handling: network error → thông báo, không crash
- [ ] Response time < 3s cho tin nhắn ngắn (~50 từ)

## Risk Assessment
- **API key security:** Lưu trong Keychain, không hardcode. Phase 7 xử lý UI nhập key
- **Rate limiting:** GPT-4o-mini có rate limit cao, ít rủi ro. Thêm retry với backoff nếu bị 429
- **Prompt injection:** User text được gửi trong user message, không trong system prompt → an toàn
