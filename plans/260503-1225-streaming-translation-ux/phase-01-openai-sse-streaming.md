---
phase: 1
title: "Add OpenAI SSE Streaming"
status: pending
priority: P1
effort: "2h"
dependencies: []
---

# Phase 1: Add OpenAI SSE Streaming

## Overview

Add streaming support to the OpenAI translation provider using Server-Sent Events (SSE). The existing non-streaming `translate()` method stays intact for popover use. A new `translateStream()` method returns an `AsyncThrowingStream<String, Error>` yielding delta tokens.

## Requirements

- Functional: Stream translation tokens as they arrive from OpenAI's `stream: true` API
- Functional: Each yield is a delta chunk (not cumulative), caller accumulates
- Non-functional: Zero external dependencies — parse SSE inline
- Non-functional: Graceful error handling (network, auth, rate-limit) same as existing

## Architecture

```
OpenAITranslationProvider
├── translate()         ← existing, unchanged (returns full String)
└── translateStream()   ← NEW (returns AsyncThrowingStream<String, Error>)

TranslationProvider protocol
├── translate()         ← existing
└── translateStream()   ← NEW, default implementation calls translate() for non-streaming providers
```

SSE format from OpenAI:
```
data: {"choices":[{"delta":{"content":"Hello"}}]}

data: {"choices":[{"delta":{"content":" world"}}]}

data: [DONE]
```

## Related Code Files

- Modify: `FastTranslate/Services/TranslationProvider.swift` — add `translateStream()` with default impl
- Modify: `FastTranslate/Services/OpenAITranslationProvider.swift` — add streaming method + SSE models
- Modify: `FastTranslate/Services/TranslationService.swift` — add `translateStreaming()` method

## Implementation Steps

1. **Update `TranslationProvider` protocol** — add `translateStream()` method returning `AsyncThrowingStream<String, Error>`. Provide default implementation that calls `translate()` and yields the full result as a single chunk.

2. **Add SSE models to `OpenAITranslationProvider`** — add `ChatStreamRequest` (same as `ChatRequest` + `stream: true`) and `ChatStreamChunk` decodable for delta parsing.

3. **Implement `translateStream()` in `OpenAITranslationProvider`**:
   - Build request with `stream: true`
   - Use `URLSession.shared.bytes(for:)` to get async byte stream
   - Parse SSE line-by-line: skip empty lines, strip `data: ` prefix
   - Stop on `data: [DONE]`
   - Decode each JSON chunk, yield `delta.content` string

4. **Add `translateStreaming()` to `TranslationService`**:
   - Same setup as `translate()` (language detection, context merging)
   - Returns `(sourceLanguage: Language, targetLanguage: Language, stream: AsyncThrowingStream<String, Error>)`
   - Does NOT wait for completion — caller drives the stream
   - History entry created by caller after stream completes

## Success Criteria

- [ ] `TranslationProvider` has `translateStream()` with default impl
- [ ] `OpenAITranslationProvider.translateStream()` yields delta tokens
- [ ] SSE parser handles `data: [DONE]`, empty lines, error responses
- [ ] `TranslationService.translateStreaming()` returns language info + stream
- [ ] Existing `translate()` path unchanged — popover still works
- [ ] Project compiles without errors

## Risk Assessment

- **SSE parsing edge cases** — OpenAI occasionally sends `data: ` with empty content delta; filter these. Mitigated by null-checking `delta.content`.
- **URLSession.bytes availability** — requires macOS 12+. App already targets 13+, so safe.
