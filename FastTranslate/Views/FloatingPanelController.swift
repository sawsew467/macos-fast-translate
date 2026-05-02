import AppKit
import SwiftUI

/// Borderless floating window that shows a translation result near the cursor.
/// Auto-dismisses after 10 seconds or on copy/outside-click.
final class FloatingPanelController {
    private var window: NSWindow?
    private var dismissTimer: Timer?

    func show(result: TranslationResult, near point: NSPoint) {
        dismiss()

        let contentView = FloatingPanelContent(result: result) { [weak self] in
            self?.copyAndDismiss(result.translatedText)
        }

        let hosting = NSHostingController(rootView: contentView)
        hosting.view.layoutSubtreeIfNeeded()

        let size = NSSize(width: 300, height: 90)
        let frame = adjustedFrame(size: size, near: point)

        let win = NSWindow(
            contentRect: frame,
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        win.level = .floating
        win.isOpaque = false
        win.backgroundColor = .clear
        win.contentViewController = hosting
        win.ignoresMouseEvents = false
        win.makeKeyAndOrderFront(nil)

        window = win
        scheduleDismiss()
        installOutsideClickMonitor()
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        window?.orderOut(nil)
        window = nil
    }

    // MARK: - Private

    private func copyAndDismiss(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        dismiss()
    }

    private func scheduleDismiss() {
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    private var outsideMonitor: Any?

    private func installOutsideClickMonitor() {
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismiss()
            if let m = self?.outsideMonitor { NSEvent.removeMonitor(m) }
        }
    }

    /// Adjusts position so the panel stays on screen.
    private func adjustedFrame(size: NSSize, near point: NSPoint) -> NSRect {
        let offset: CGFloat = 12
        var x = point.x + offset
        var y = point.y - size.height - offset

        if let screen = NSScreen.main {
            let vis = screen.visibleFrame
            if x + size.width > vis.maxX { x = vis.maxX - size.width - offset }
            if y < vis.minY { y = point.y + offset }
        }

        return NSRect(origin: NSPoint(x: x, y: y), size: size)
    }
}

// MARK: - SwiftUI content view

private struct FloatingPanelContent: View {
    let result: TranslationResult
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(result.translatedText)
                .font(.system(size: 13))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button(action: onCopy) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Spacer()

                Text("\(result.sourceLanguage.displayName) → \(result.targetLanguage.displayName) · \(result.provider.displayName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
    }
}
