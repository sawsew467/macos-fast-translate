---
title: "Streaming Translation UX"
status: completed
created: 2026-05-03
scope: project
blockedBy: []
blocks: []
---

# Streaming Translation UX

## Problem

Panel only appears after full OpenAI response completes. Users see no feedback for 1-3 seconds after pressing ⌃⌥T or completing a screenshot OCR capture.

## Goal

Show the floating panel immediately with a loading state, then stream translated tokens in real-time from OpenAI's SSE endpoint.

## Phases

| # | Phase | Status | Priority | Effort |
|---|-------|--------|----------|--------|
| 1 | [Add OpenAI SSE streaming](phase-01-openai-sse-streaming.md) | completed | P1 | 2h |
| 2 | [Streaming floating panel UI](phase-02-streaming-panel-ui.md) | completed | P1 | 2h |
| 3 | [Wire hotkey handlers to streaming](phase-03-wire-hotkey-streaming.md) | completed | P1 | 1h |

## Architecture Change

```
BEFORE:
  Hotkey → readText → await translate(full) → show(panel)
                        ~~~ 1-3s silence ~~~

AFTER:
  Hotkey → readText → show(panel, loading) → stream tokens → update panel live
                       ~~~ instant ~~~        ~~~ progressive ~~~
```

## Key Design Decisions

1. **AsyncSequence for streaming** — `TranslationProvider` gets a new `translateStream()` returning `AsyncThrowingStream<String, Error>`. Non-breaking: existing `translate()` stays for popover use.
2. **ObservableObject for panel state** — New `StreamingTranslationState` class drives the floating panel reactively. Panel shows immediately, text updates via `@Published`.
3. **Backward-compatible** — Popover translation (manual input) keeps the existing non-streaming `translate()` path. Only hotkey/screenshot flows use streaming.
4. **SSE parsing** — Minimal inline parser for OpenAI's `data: {json}\n\n` format. No external dependencies.
