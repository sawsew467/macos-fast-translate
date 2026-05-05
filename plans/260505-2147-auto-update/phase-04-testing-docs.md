---
phase: 4
title: "Testing & Docs"
status: pending
priority: P2
effort: "30m"
dependencies: [2, 3]
---

# Phase 4: Testing & Docs

## Overview
Verify end-to-end update flow and update project documentation.

## Implementation Steps

1. **Test update flow**:
   - Create a test pre-release on GitHub with ZIP asset
   - Build app with lower version number
   - Verify: check detects update → download → signature verification → install → restart

2. **Update docs**:
   - `docs/project-changelog.md` — add auto-update entry
   - `docs/system-architecture.md` — add UpdateService component
   - `docs/product-overview.md` — mention auto-update feature
   - `README.md` — add to Features section

3. **Update release workflow docs** if any

## Success Criteria
- [ ] End-to-end update flow works (detect → download → install → restart)
- [ ] Code signature verification passes
- [ ] Docs updated
- [ ] Build succeeds with new dependency

## Risk Assessment
- **Notarization after ZIP**: The .app inside ZIP must retain its notarization ticket. `ditto` preserves this, `zip` may not.
