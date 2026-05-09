import SwiftUI
import AppKit

/// NSViewRepresentable wrapper around NSTextView.
/// Renders placeholder at the exact text insertion point (no ZStack guesswork).
/// Hides scrollbars and fires onEnter when Return is pressed without Shift.
struct MultilineTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var onEnter: (() -> Void)? = nil

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = PlaceholderTextView.scrollableTextView()
        guard let tv = scrollView.documentView as? PlaceholderTextView else {
            return scrollView
        }

        tv.placeholderString = placeholder
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.font = .systemFont(ofSize: 14)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.backgroundColor = .clear
        tv.drawsBackground = false
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.textContainer?.widthTracksTextView = true
        tv.textContainerInset = NSSize(width: 0, height: 4)

        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tv = scrollView.documentView as? PlaceholderTextView else { return }
        context.coordinator.onEnter = onEnter
        // Avoid resetting selection when text hasn't changed
        if tv.string != text {
            let selected = tv.selectedRanges
            tv.string = text
            tv.selectedRanges = selected
        }
        tv.placeholderString = placeholder
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var binding: Binding<String>
        var onEnter: (() -> Void)?

        init(text: Binding<String>) { self.binding = text }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            binding.wrappedValue = tv.string
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)),
               !NSEvent.modifierFlags.contains(.shift) {
                onEnter?()
                return true
            }
            return false
        }
    }
}

// MARK: - NSTextView subclass with native placeholder drawing

private class PlaceholderTextView: NSTextView {
    var placeholderString: String = ""

    /// Trigger background redraw on every text change so the placeholder appears/disappears correctly.
    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard string.isEmpty else { return }

        let padding = textContainer?.lineFragmentPadding ?? 5
        let insetX = textContainerInset.width + padding
        let insetY = textContainerInset.height

        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.placeholderTextColor,
            .font: font ?? NSFont.systemFont(ofSize: 14)
        ]
        let drawRect = NSRect(x: insetX, y: insetY,
                              width: rect.width - insetX * 2,
                              height: rect.height)
        placeholderString.draw(in: drawRect, withAttributes: attrs)
    }
}
