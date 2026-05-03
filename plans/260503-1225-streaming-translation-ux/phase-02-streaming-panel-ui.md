---
phase: 2
title: "Streaming Floating Panel UI"
status: pending
priority: P1
effort: "2h"
dependencies: [1]
---

# Phase 2: Streaming Floating Panel UI

## Overview

Update `FloatingPanelController` to show immediately with a loading state, then progressively display streamed translation text. The panel becomes reactive via a shared `@ObservableObject` state.

## Requirements

- Functional: Panel appears instantly when translation starts (no wait for API)
- Functional: Shows spinner + "Translating..." initially
- Functional: Text appears token-by-token as stream yields chunks
- Functional: Copy button enabled only after stream completes
- Functional: Language direction label shown from start (detected before streaming)
- Non-functional: Smooth text rendering without flicker
- Non-functional: Panel resizes as text grows (up to max height)

## Architecture

```
StreamingTranslationState (@MainActor, ObservableObject)
├── @Published streamedText: String        ← accumulated tokens
├── @Published isStreaming: Bool            ← true until [DONE]
├── @Published error: String?              ← error message if failed
├── sourceLanguage / targetLanguage        ← set at start
├── provider: ProviderType                 ← set at start
└── fullResult: TranslationResult?         ← built after stream completes

FloatingPanelController
├── show(result:near:)          ← existing, unchanged
└── showStreaming(state:near:)  ← NEW, takes StreamingTranslationState
```

New SwiftUI view `StreamingPanelContent` replaces `FloatingPanelContent` for streaming mode:
- Loading: spinner + "Translating..."
- Streaming: growing text with cursor indicator
- Complete: full text + Copy button enabled
- Error: error message in red

## Related Code Files

- Create: `FastTranslate/Models/StreamingTranslationState.swift` — observable state
- Modify: `FastTranslate/Views/FloatingPanelController.swift` — add `showStreaming()` + `StreamingPanelContent`

## Implementation Steps

1. **Create `StreamingTranslationState`**:
   ```swift
   @MainActor
   final class StreamingTranslationState: ObservableObject {
       @Published var streamedText = ""
       @Published var isStreaming = true
       @Published var error: String?
       let sourceText: String
       let sourceLanguage: Language
       let targetLanguage: Language
       let provider: ProviderType
   }
   ```

2. **Create `StreamingPanelContent` view** in FloatingPanelController.swift:
   - `@ObservedObject var state: StreamingTranslationState`
   - When `isStreaming && streamedText.isEmpty` → show ProgressView + "Translating..."
   - When `isStreaming && !streamedText.isEmpty` → show growing text (with subtle typing cursor ▊)
   - When `!isStreaming && error == nil` → show final text + enabled Copy button
   - When `error != nil` → show error text in red
   - Same visual style as existing `FloatingPanelContent` (material background, shadow, rounded corners)

3. **Add `showStreaming()` to `FloatingPanelController`**:
   - Takes `StreamingTranslationState` and `NSPoint`
   - Creates window with `StreamingPanelContent` immediately
   - Window auto-resizes as text grows: observe `state.streamedText` changes, recalculate `fittingSize`, update window frame (capped at 500px height)

4. **Handle dynamic resize**:
   - Use `onChange(of: state.streamedText)` or Combine sink to trigger layout recalculation
   - Animate height changes smoothly (short 0.1s animation)
   - Keep top-left corner pinned during resize (only height changes downward)

## Success Criteria

- [ ] `StreamingTranslationState` model created with all published properties
- [ ] Panel appears instantly with loading spinner
- [ ] Text streams in progressively as tokens arrive
- [ ] Copy button disabled during streaming, enabled after completion
- [ ] Panel resizes smoothly as text grows
- [ ] Error state displays correctly
- [ ] Existing `show(result:near:)` still works for popover flow
- [ ] Project compiles without errors

## Risk Assessment

- **Window resize flicker** — mitigate with `NSAnimationContext` or batching rapid updates (accumulate for ~50ms before re-layout)
- **Text wrapping recalculation cost** — `fittingSize` on every token could be expensive. Batch updates: only relayout every 3-5 tokens or on timer.
