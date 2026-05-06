# Plan: Add Google Translate as Free Default Provider

Add Google Translate (unofficial free endpoint) as the default translation provider so users can translate immediately without an API key. Keep OpenAI as optional premium provider.

## Context

- Current: only OpenAI provider, requires API key + credit card
- Problem: TikTok users can't/won't get API keys
- Solution: Google Translate free endpoint (`translate.googleapis.com`) as zero-config default
- Future: Gemini Flash provider (separate plan)

## Dependencies

- **blockedBy:** `260506-1354-lower-macos-target` (both modify `SettingsView.swift`)
- Wait for lower-macos plan to complete before implementing phase 3+

## Key Decisions

- Google Translate endpoint: `https://translate.googleapis.com/translate_a/single?client=gtx&sl={src}&tl={tgt}&dt=t&q={text}`
- No API key needed, no registration
- Unofficial endpoint - may break, but stable for years across many projects
- Does NOT support context/streaming - plain text translation only
- Default provider for new installs = Google Translate
- Existing users who already have OpenAI key = keep OpenAI as their default

## Phases

| # | Phase | Status | Priority | Effort |
|---|-------|--------|----------|--------|
| 1 | [Create GoogleTranslateProvider](phase-01-create-google-translate-provider.md) | done | P1 | 30min |
| 2 | [Update models and TranslationService](phase-02-update-models-and-service.md) | done | P1 | 15min |
| 3 | [Update Settings UI with provider picker](phase-03-update-settings-ui.md) | done | P1 | 20min |
| 4 | [Redesign Onboarding flow](phase-04-redesign-onboarding.md) | done | P1 | 30min |
| 5 | [Verify and test](phase-05-verify-and-test.md) | done | P1 | 15min |

## Risk Assessment

- **Medium risk:** Google may block/change the unofficial endpoint at any time. Mitigation: app still works with OpenAI fallback, can add Gemini later.
- **Low risk:** Response format parsing - well-documented by many open source projects.
- **Low risk:** Rate limiting on heavy usage - unlikely for individual desktop app use.
