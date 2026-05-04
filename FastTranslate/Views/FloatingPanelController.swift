import AppKit
import SwiftUI

/// Borderless floating window that shows a translation result near the cursor.
/// Supports both instant display (full result) and streaming mode (progressive tokens).
final class FloatingPanelController {
    private var window: NSWindow?

    private let panelWidth: CGFloat = 360
    /// Fixed height for streaming panel — text scrolls within, no window resize jitter.
    private let streamingHeight: CGFloat = 200

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

        let contentView = StreamingPanelContent(
            state: state,
            onCopy:  { [weak self] in self?.copyAndDismiss(state.streamedText) },
            onClose: { [weak self] in self?.dismiss() }
        )

        // Fixed height — text scrolls within, no resize jitter
        presentWindow(rootView: contentView, near: point, fixedHeight: streamingHeight)
    }

    func dismiss() {
        window?.orderOut(nil)
        window = nil
    }

    // MARK: - Private

    private func presentWindow<V: View>(rootView: V, near point: NSPoint, fixedHeight: CGFloat? = nil) {
        let hosting = NSHostingController(rootView: rootView)
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.view.layer?.cornerRadius = floatingPanelCornerRadius
        hosting.view.layer?.cornerCurve = .continuous
        hosting.view.layer?.masksToBounds = true

        let win = NSWindow(
            contentRect: NSRect(x: -9999, y: -9999, width: panelWidth, height: 600),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        win.level = .floating
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.isMovableByWindowBackground = true
        win.contentViewController = hosting
        win.contentView?.wantsLayer = true
        win.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        win.contentView?.layer?.cornerRadius = floatingPanelCornerRadius
        win.contentView?.layer?.cornerCurve = .continuous
        win.contentView?.layer?.masksToBounds = true
        win.ignoresMouseEvents = false

        let height: CGFloat
        if let fixed = fixedHeight {
            height = fixed
        } else {
            hosting.view.layoutSubtreeIfNeeded()
            height = max(80, min(500, hosting.view.fittingSize.height))
        }

        let size = NSSize(width: panelWidth, height: height)
        let frame = adjustedFrame(size: size, near: point)

        win.setFrame(frame, display: false)
        win.makeKeyAndOrderFront(nil)

        window = win
    }

    private func copyAndDismiss(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        dismiss()
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
        panelContainer {
            Text(result.translatedText)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            HStack(alignment: .center, spacing: 8) {
                Button(action: onCopy) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.bordered)
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
    }
}

// MARK: - Streaming result view

struct StreamingPanelContent: View {
    @ObservedObject var state: StreamingTranslationState
    let onCopy: () -> Void
    let onClose: () -> Void

    var body: some View {
        panelContainer {
            // Content area — ScrollView prevents overflow, auto-scrolls during streaming
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        if let error = state.error {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundStyle(.red)
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
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }

                        // Invisible anchor for auto-scroll
                        Color.clear.frame(height: 1).id("bottom")
                    }
                }
                .onChange(of: state.streamedText) { _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }

            // Footer
            HStack(alignment: .center, spacing: 8) {
                Button(action: onCopy) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.bordered)
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
    }
}

// MARK: - Shared panel chrome

private let floatingPanelCornerRadius: CGFloat = 18

/// Use a compositing group so material and shadow are both clipped to the same
/// rounded rectangle. This avoids the light square corners visible on bright backgrounds.
private func panelContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 8, content: content)
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: floatingPanelCornerRadius, style: .continuous))
        .mask(RoundedRectangle(cornerRadius: floatingPanelCornerRadius, style: .continuous))
        .compositingGroup()
        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
}
