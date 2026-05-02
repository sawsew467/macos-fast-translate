---
phase: 5
title: "Screenshot OCR"
status: pending
priority: P1
effort: "5h"
dependencies: [2, 3, 4]
---

# Phase 5: Screenshot OCR

## Overview
Chụp vùng màn hình → OCR trích xuất text → dịch. Feature quan trọng nhất cho việc đọc tin nhắn khách. Hỗ trợ chụp vùng rộng để lấy context từ cuộc hội thoại.

## Requirements
- **Functional:**
  - `⌃+⌥+S` trigger chọn vùng màn hình
  - User kéo chọn area (crosshair cursor)
  - Vision framework OCR trích xuất text (Vi + En)
  - Text được dịch tự động
  - Kết quả hiện trong floating panel
  - **Không tạo file ảnh trên disk** (in-memory only)
  - Escape hủy capture
  - Hỗ trợ chụp vùng rộng → toàn bộ text làm context, dòng cuối/vùng cuối là text cần dịch
- **Non-functional:**
  - Yêu cầu Screen Recording permission
  - OCR accuracy cao cho cả Vietnamese diacritics
  - Capture → result < 5s

## Architecture

### Files
```
Services/
├── ScreenCaptureService.swift    # Region selection overlay + capture
└── OCRService.swift              # Vision framework text recognition
```

### Full Pipeline
```
⌃+⌥+S pressed
  → ScreenCaptureService.captureRegion()
    → Show fullscreen transparent overlay (crosshair)
    → User drags to select rectangle
    → Capture region as CGImage (in-memory)
    → Escape → cancel, dismiss overlay
  → OCRService.recognizeText(cgImage)
    → VNRecognizeTextRequest with ["vi-VT", "en-US"]
    → Return recognized text string
  → TranslationService.translate(text, screenshotContext: fullText)
    → Detect language
    → Translate via GPT-4o-mini
  → FloatingPanelController.show(result, near: mouseLocation)
```

### Region Selection Overlay
```swift
class ScreenCaptureService {
    /// Show fullscreen transparent window, let user drag-select a region
    func captureRegion() async -> CGImage? {
        // 1. Create fullscreen borderless transparent NSWindow
        //    - window.level = .screenSaver (above everything)
        //    - window.backgroundColor = NSColor.black.withAlphaComponent(0.2)
        //    - window.ignoresMouseEvents = false
        //
        // 2. Custom NSView handles mouse events:
        //    - mouseDown: record start point
        //    - mouseDragged: draw selection rectangle (dashed border)
        //    - mouseUp: capture region, dismiss overlay
        //    - keyDown (Escape): cancel, dismiss overlay
        //
        // 3. Capture the selected region:
        //    - CGWindowListCreateImage(selectedRect,
        //        .optionOnScreenBelowWindow,  // exclude overlay itself
        //        kCGNullWindowID,
        //        .bestResolution)
        //
        // 4. Return CGImage (in-memory, no file saved)
    }
}
```

### OCR Service
```swift
class OCRService {
    /// Extract text from image using Vision framework
    func recognizeText(from image: CGImage) async throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["vi-VT", "en-US"]
        request.usesLanguageCorrection = true
        // revision3 for macOS 14+ best accuracy

        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        guard let observations = request.results else {
            throw OCRError.noTextFound
        }

        // Sort observations top-to-bottom, left-to-right
        // Join recognized text with newlines
        return observations
            .sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}
```

### Screenshot Context Strategy
Khi user chụp vùng rộng (cả đoạn chat), OCR sẽ trích xuất toàn bộ text. GPT-4o-mini nhận:
- **System prompt:** "Translate the last message. Use the conversation above as context."
- **User content:** Full OCR text

Cách này giúp dịch chính xác hơn vì GPT hiểu ngữ cảnh cuộc hội thoại.

### Permission Handling
```swift
// Check Screen Recording permission
// macOS 14+: ScreenCaptureKit has its own permission prompt
// Fallback: CGPreflightScreenCaptureAccess() / CGRequestScreenCaptureAccess()
```

## Related Code Files
- Create: `FastTranslate/Services/ScreenCaptureService.swift`
- Create: `FastTranslate/Services/OCRService.swift`
- Modify: `FastTranslate/Services/HotkeyManager.swift` (wire ⌃+⌥+S handler)
- Modify: `FastTranslate/Models/TranslationModels.swift` (add OCRError)

## Implementation Steps
1. Tạo `OCRService.swift`:
   - `recognizeText(from: CGImage) async throws -> String`
   - Config: `.accurate`, `["vi-VT", "en-US"]`, `usesLanguageCorrection = true`
   - Sort observations top-to-bottom cho đúng thứ tự đọc
   - Handle error: no text found, recognition failed
2. Tạo `ScreenCaptureService.swift`:
   - `captureRegion() async -> CGImage?`
   - Fullscreen transparent overlay window
   - Mouse drag selection (start → drag → release)
   - Draw selection rectangle (dashed white border trên nền tối)
   - Capture region via `CGWindowListCreateImage` (exclude overlay window)
   - Escape key → cancel → return nil
   - Return CGImage in-memory
3. Check Screen Recording permission:
   - `CGPreflightScreenCaptureAccess()` → if false → `CGRequestScreenCaptureAccess()`
   - Show dialog hướng dẫn nếu bị denied
4. Wire vào HotkeyManager:
   - `⌃+⌥+S` → `handleScreenshotOCR()`
   - Call ScreenCaptureService → OCRService → TranslationService → FloatingPanel
5. Implement screenshot context:
   - Nếu OCR text > 1 dòng → gửi toàn bộ làm screenshotContext
   - TranslationService dùng special prompt: "Translate the last message, use conversation above as context"
6. Test:
   - Chụp tin nhắn tiếng Anh trong Chrome → verify OCR đúng → dịch sang Việt
   - Chụp tin nhắn tiếng Việt → verify diacritics OCR đúng → dịch sang Anh
   - Chụp vùng rộng (nhiều tin nhắn) → verify context cải thiện dịch thuật
   - Escape hủy capture → không crash
   - Verify không có file ảnh tạo trên disk

## Success Criteria
- [ ] ⌃+⌥+S mở overlay chọn vùng
- [ ] Kéo chọn vùng → hiện selection rectangle
- [ ] Escape hủy capture
- [ ] OCR trích xuất text tiếng Anh chính xác
- [ ] OCR trích xuất text tiếng Việt (diacritics) chính xác
- [ ] Dịch kết quả hiện trong floating panel
- [ ] Chụp vùng rộng → context cải thiện bản dịch
- [ ] Không tạo file ảnh trên disk
- [ ] Screen Recording permission request hoạt động
- [ ] Pipeline hoàn thành < 5s

## Risk Assessment
- **Screen Recording permission:** macOS rất strict. User phải bật thủ công trong System Settings. Cần UX rõ ràng hướng dẫn
- **OCR accuracy cho Vietnamese diacritics:** Vision framework hỗ trợ từ macOS 14, nhưng accuracy có thể thấp hơn English. Test kỹ với font nhỏ, screenshot chat apps
- **Overlay window ordering:** Cần đảm bảo overlay ở trên tất cả windows nhưng không block system UI (menu bar, notification center)
- **Multi-monitor:** `CGWindowListCreateImage` cần handle đúng screen coordinates trên multi-monitor setup
