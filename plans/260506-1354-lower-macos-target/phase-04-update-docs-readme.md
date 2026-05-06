---
phase: 4
title: "Update docs & README"
status: complete
priority: P2
effort: "10min"
dependencies: [1, 2, 3]
---

# Phase 4: Update Docs & README

## Overview
Update all references from "macOS 14+" to "macOS 13+" across documentation.

## Related Code Files
- Modify: `README.md` (badge + prerequisites)
- Modify: `docs/tech-stack.md`
- Modify: `docs/product-overview.md`
- Modify: `docs/project-changelog.md`

## Implementation Steps

1. **README.md** — Update badge and prerequisites:
   - Badge: `![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)`
   - Prerequisites: `macOS 13+ and Xcode 15+`

2. **docs/tech-stack.md** — Update deployment target line:
   - `**macOS 13+ (Ventura)** — minimum deployment target`

3. **docs/product-overview.md** — Update requirements:
   - `macOS 13 (Ventura) or later`

4. **docs/project-changelog.md** — Add entry:
   ```
   ## v1.4.0
   - Lowered minimum macOS requirement from 14.0 to 13.0 (Ventura)
   - Replaced SCScreenshotManager with CGWindowListCreateImage for broader compatibility
   - Note: Vietnamese OCR accuracy may be reduced on macOS 13 (full support from 14.4+)
   ```

## Success Criteria
- [x] README badge shows macOS 13+
- [x] All docs reference macOS 13+ as minimum
- [x] Changelog entry added (v1.4.0)
