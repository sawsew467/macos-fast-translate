# FastTranslate — Product Overview

## Sản phẩm là gì?
macOS menu bar app dịch nhanh Tiếng Việt ↔ Tiếng Anh. Dùng AI (GPT-4o-mini) để dịch tự nhiên, hỗ trợ gửi kèm context để dịch chính xác hơn. App gọn nhẹ, chạy nền, truy cập qua icon menu bar hoặc phím tắt.

## Giải quyết vấn đề gì?
Người dùng Việt giao tiếp với khách nước ngoài hàng ngày qua chat (Slack, Discord, email...). Workflow hiện tại rất chậm:
1. Mở ChatGPT/Claude → gõ tiếng Việt → copy bản dịch → paste vào chat (~30-60s/lần)
2. Đọc tin khách: chụp ảnh → upload vào AI → đọc bản dịch (~30-60s/lần)
3. Tạo rất nhiều ảnh chụp màn hình rác

**FastTranslate giảm từ 30-60s xuống 3-5s/lần, không tạo file rác.**

## Ai dùng?
- Người Việt làm việc với khách/đồng nghiệp nói tiếng Anh
- Developer, freelancer, nhân viên support, sales
- Người viết tiếng Anh chưa tốt, cần AI hỗ trợ dịch tự nhiên

## 4 cách dùng chính

### 1. Dịch text đang bôi đen (`⌃+⌥+T`)
**Dùng khi:** Viết tin nhắn tiếng Việt xong, muốn dịch sang Anh gửi cho khách.
```
Bôi đen text → ⌃+⌥+T → popup hiện bản dịch → click copy → paste gửi khách
```
Cũng dùng ngược lại: bôi đen tin nhắn tiếng Anh của khách → dịch sang Việt để đọc.

### 2. Chụp màn hình → dịch (`⌃+⌥+S`)
**Dùng khi:** Đọc tin nhắn khách mà không thể bôi đen (ảnh, app không cho select text).
```
⌃+⌥+S → kéo chọn vùng tin nhắn → OCR đọc chữ → dịch → popup hiện kết quả
```
- Không tạo file ảnh trên disk (xử lý trong bộ nhớ)
- Chụp vùng rộng (cả đoạn chat) → AI dùng ngữ cảnh cuộc hội thoại để dịch chính xác hơn

### 3. Dịch thủ công (click menu bar)
**Dùng khi:** Muốn gõ text và thêm context cụ thể.
```
Click icon menu bar → gõ text + context → xem bản dịch → copy
```

## Context — dịch chính xác hơn

Lợi thế lớn so với Google Translate: gửi kèm **ngữ cảnh** để AI dịch đúng ý.

| Loại context | Cách dùng | Ví dụ |
|--------------|-----------|-------|
| **Persistent** | Set 1 lần trong Settings, gửi kèm mọi bản dịch | "I'm a software developer, professional but friendly tone" |
| **Per-message** | Gõ trong popover cho 1 lần dịch cụ thể | "đang thảo luận về bug trên production" |
| **Screenshot** | Chụp vùng rộng, AI dùng cả đoạn chat làm context | Chụp cả cuộc hội thoại, không chỉ 1 tin nhắn |

**Ví dụ thực tế:**
- Không context: "Em deploy lại giúp em" → "Please help me deploy again" (chung chung)
- Có context "production server bug fix": "Em deploy lại giúp em" → "Could you redeploy the fix for me?" (chính xác)

## Đặc điểm kỹ thuật
- **Native macOS** — Swift, ~10MB, không phải Electron
- **AI Translation** — GPT-4o-mini, streaming token-by-token
- **OCR offline** — Vision framework của Apple, đọc chữ Vi+En không cần internet
- **Tự nhận diện ngôn ngữ** — gõ tiếng Việt → tự dịch sang Anh, và ngược lại
- **Phím tắt toàn cục** — hoạt động từ bất kỳ app nào
- **Không tạo file rác** — screenshot xử lý trong bộ nhớ
- **Chi phí rẻ** — ~7,000 VND/tháng (GPT-4o-mini, 100 tin/ngày)

## Yêu cầu hệ thống
- macOS 14 (Sonoma) trở lên
- OpenAI API key
- Cấp quyền Accessibility (cho phím tắt + đọc text bôi đen)
- Cấp quyền Screen Recording (cho chụp màn hình OCR)

## Phím tắt
| Phím tắt | Hành động |
|----------|-----------|
| `⌃+⌥+T` | Dịch text đang bôi đen |
| `⌃+⌥+S` | Chụp vùng màn hình → OCR → dịch |
| `⌘+,`   | Mở Settings |

Phím tắt có thể đổi trong Settings.
