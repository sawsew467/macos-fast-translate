import AppKit
import SwiftUI

/// Borderless floating window that shows a translation result near the cursor.
/// Dismissed by the user via close button or clicking outside.
final class FloatingPanelController {
    private var window: NSWindow?
    private var outsideMonitor: Any?

    func show(result: TranslationResult, near point: NSPoint) {
        dismiss()

        let contentView = FloatingPanelContent(
            result: result,
            onCopy:  { [weak self] in self?.copyAndDismiss(result.translatedText) },
            onClose: { [weak self] in self?.dismiss() }
        )

        let panelWidth: CGFloat = 360
        let hosting = NSHostingController(rootView: contentView)

        // Create the window first at a tall temp size so SwiftUI lays out inside the window hierarchy
        // — fittingSize is accurate only after the view is in a real window
        let win = NSWindow(
            contentRect: NSRect(x: -9999, y: -9999, width: panelWidth, height: 600),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        win.level = .floating
        win.isOpaque = false
        win.backgroundColor = .clear
        win.contentViewController = hosting
        win.ignoresMouseEvents = false

        // Measure real height now that the view is in a window
        hosting.view.layoutSubtreeIfNeeded()
        let fittingHeight = max(80, min(500, hosting.view.fittingSize.height))
        let size = NSSize(width: panelWidth, height: fittingHeight)
        let frame = adjustedFrame(size: size, near: point)
        print("[FloatingPanel] near=\(point) fittingHeight=\(fittingHeight) frame=\(frame)")

        win.setFrame(frame, display: false)
        win.makeKeyAndOrderFront(nil)

        window = win
        installOutsideClickMonitor()
    }

    func dismiss() {
        window?.orderOut(nil)
        window = nil
        if let m = outsideMonitor { NSEvent.removeMonitor(m) }
        outsideMonitor = nil
    }

    // MARK: - Private

    private func copyAndDismiss(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        dismiss()
    }

    private func installOutsideClickMonitor() {
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismiss()
        }
    }

    /// Positions the panel below-right of `point`, nudging inward if it would go off-screen.
    /// Uses the screen that actually contains `point` (multi-monitor safe).
    private func adjustedFrame(size: NSSize, near point: NSPoint) -> NSRect {
        let offset: CGFloat = 8
        var x = point.x
        var y = point.y - size.height - offset

        // Find the screen that contains the anchor point, not necessarily the main screen
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
        if let vis = screen?.visibleFrame {
            if x + size.width > vis.maxX { x = vis.maxX - size.width - offset }
            if x < vis.minX { x = vis.minX + offset }
            if y < vis.minY { y = point.y + offset }
            if y + size.height > vis.maxY { y = vis.maxY - size.height - offset }
        }

        return NSRect(origin: NSPoint(x: x, y: y), size: size)
    }
}

// MARK: - SwiftUI content view

private struct FloatingPanelContent: View {
    let result: TranslationResult
    let onCopy: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.translatedText)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true) // expand vertically, never truncate
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            HStack(alignment: .center, spacing: 8) {
                Button(action: onCopy) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Text("\(result.sourceLanguage.displayName) → \(result.targetLanguage.displayName) · \(result.provider.displayName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
    }
}
