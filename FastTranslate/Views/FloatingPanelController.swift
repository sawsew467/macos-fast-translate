import AppKit
import Combine
import SwiftUI

/// Borderless floating window that shows a translation result near the cursor.
/// Supports both instant display (full result) and streaming mode (progressive tokens).
final class FloatingPanelController {
    private var window: NSWindow?
    private var outsideMonitor: Any?
    private var resizeCancellable: AnyCancellable?
    private var anchorPoint: NSPoint = .zero

    private let panelWidth: CGFloat = 360

    func show(result: TranslationResult, near point: NSPoint) {
        dismiss()

        let contentView = FloatingPanelContent(
            result: result,
            onCopy:  { [weak self] in self?.copyAndDismiss(result.translatedText) },
            onClose: { [weak self] in self?.dismiss() }
        )

        presentWindow(rootView: contentView, near: point)
    }

    /// Show panel immediately with loading state, then stream tokens in.
    func showStreaming(state: StreamingTranslationState, near point: NSPoint) {
        dismiss()
        anchorPoint = point

        let contentView = StreamingPanelContent(
            state: state,
            onCopy:  { [weak self] in self?.copyAndDismiss(state.streamedText) },
            onClose: { [weak self] in self?.dismiss() }
        )

        presentWindow(rootView: contentView, near: point)

        // Resize window as streamed text grows
        resizeCancellable = state.$streamedText
            .throttle(for: .milliseconds(80), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in self?.relayoutWindow() }
    }

    func dismiss() {
        resizeCancellable?.cancel()
        resizeCancellable = nil
        window?.orderOut(nil)
        window = nil
        if let m = outsideMonitor { NSEvent.removeMonitor(m) }
        outsideMonitor = nil
    }

    // MARK: - Private

    private func presentWindow<V: View>(rootView: V, near point: NSPoint) {
        anchorPoint = point
        let hosting = NSHostingController(rootView: rootView)

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

        hosting.view.layoutSubtreeIfNeeded()
        let fittingHeight = max(80, min(500, hosting.view.fittingSize.height))
        let size = NSSize(width: panelWidth, height: fittingHeight)
        let frame = adjustedFrame(size: size, near: point)

        win.setFrame(frame, display: false)
        win.makeKeyAndOrderFront(nil)

        window = win
        installOutsideClickMonitor()
    }

    /// Recalculate window height after streamed text changes.
    private func relayoutWindow() {
        guard let win = window,
              let hosting = win.contentViewController as? NSHostingController<StreamingPanelContent>
        else { return }

        hosting.view.layoutSubtreeIfNeeded()
        let fittingHeight = max(80, min(500, hosting.view.fittingSize.height))
        let newSize = NSSize(width: panelWidth, height: fittingHeight)
        let newFrame = adjustedFrame(size: newSize, near: anchorPoint)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.08
            win.animator().setFrame(newFrame, display: true)
        }
    }

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
    private func adjustedFrame(size: NSSize, near point: NSPoint) -> NSRect {
        let offset: CGFloat = 8
        var x = point.x
        var y = point.y - size.height - offset

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

// MARK: - Static result view (existing)

private struct FloatingPanelContent: View {
    let result: TranslationResult
    let onCopy: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.translatedText)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
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

// MARK: - Streaming result view

struct StreamingPanelContent: View {
    @ObservedObject var state: StreamingTranslationState
    let onCopy: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Content area
            if let error = state.error {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if state.streamedText.isEmpty && state.isStreaming {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7)
                    Text("Translating…")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(state.streamedText + (state.isStreaming ? "▊" : ""))
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }

            // Footer
            HStack(alignment: .center, spacing: 8) {
                Button(action: onCopy) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(state.isStreaming || state.streamedText.isEmpty)

                Text("\(state.sourceLanguage.displayName) → \(state.targetLanguage.displayName) · \(state.provider.displayName)")
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
