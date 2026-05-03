---
phase: 3
title: "Wire Hotkey Handlers to Streaming"
status: pending
priority: P1
effort: "1h"
dependencies: [1, 2]
---

# Phase 3: Wire Hotkey Handlers to Streaming

## Overview

Update `HotkeyManager` to use the new streaming flow: show panel immediately after text capture, then pipe streamed tokens into it. Save history after stream completes.

## Requirements

- Functional: ⌃⌥T — panel appears right after selected text is read, streams translation
- Functional: ⌃⌥S — panel appears right after OCR completes, streams translation
- Functional: Translation history updated after stream finishes (not during)
- Functional: Error shown in panel (not via separate brief message window)
- Non-functional: Mouse anchor point captured before async work (existing behavior preserved)

## Architecture

```
BEFORE (handleTranslateSelected):
  1. readSelectedText()        → await
  2. translate(text)           → await (1-3s blocking)
  3. floatingPanel.show(result) → finally visible

AFTER:
  1. readSelectedText()              → await
  2. translateStreaming(text)         → instant return (lang + stream)
  3. floatingPanel.showStreaming()    → visible immediately
  4. for await chunk in stream       → update state.streamedText
  5. save to history                 → after loop completes
```

## Related Code Files

- Modify: `FastTranslate/Services/HotkeyManager.swift` — rewrite `handleTranslateSelected()` and `handleScreenshotOCR()`
- Modify: `FastTranslate/Services/TranslationService.swift` — add `addToHistory()` public method

## Implementation Steps

1. **Add `addToHistory()` to `TranslationService`**:
   - Extract history-saving logic from `translate()` into a public method
   - Takes `TranslationResult`, inserts at index 0, caps at 50, saves to disk
   - Called by `HotkeyManager` after stream completes

2. **Rewrite `handleTranslateSelected()`**:
   ```swift
   private func handleTranslateSelected() {
       let anchorPoint = NSEvent.mouseLocation
       Task { @MainActor in
           guard let text = await SelectedTextReader.readSelectedText(), !text.isEmpty else {
               showBriefMessage("No text selected", near: anchorPoint)
               return
           }
           do {
               let (source, target, stream) = try await translationService.translateStreaming(text)
               let state = StreamingTranslationState(
                   sourceText: text, sourceLanguage: source,
                   targetLanguage: target, provider: translationService.activeProviderType
               )
               floatingPanel.showStreaming(state: state, near: anchorPoint)

               for try await chunk in stream {
                   state.streamedText += chunk
               }
               state.isStreaming = false

               let result = TranslationResult(
                   sourceText: text, translatedText: state.streamedText,
                   sourceLanguage: source, targetLanguage: target,
                   provider: translationService.activeProviderType
               )
               translationService.addToHistory(result)
           } catch {
               // If panel is already showing, set error on state
               // Otherwise show brief message
               showBriefMessage(error.localizedDescription, near: anchorPoint)
           }
       }
   }
   ```

3. **Rewrite `handleScreenshotOCR()`** — same pattern as above but with OCR step first.

4. **Error handling in streaming**:
   - If error occurs before panel is shown → `showBriefMessage()` (existing behavior)
   - If error occurs during streaming (panel already visible) → set `state.error`

## Success Criteria

- [ ] ⌃⌥T shows panel immediately after text capture, streams tokens
- [ ] ⌃⌥S shows panel immediately after OCR, streams tokens
- [ ] History saved correctly after stream completes
- [ ] Errors during streaming shown in panel
- [ ] Errors before streaming (no text selected, no API key) shown as brief message
- [ ] No regressions in existing popover translation flow
- [ ] Project compiles without errors

## Risk Assessment

- **Race condition: user dismisses panel during stream** — stream should check if state is still referenced. Use `[weak state]` or check `state.isStreaming` before appending. If panel is dismissed, stream can continue silently (tokens discarded).
- **History duplication** — ensure `translate()` (popover path) and `addToHistory()` (hotkey path) don't double-save. The streaming path bypasses `translate()` entirely, so no duplication.
