import AppKit
import SwiftUI

/// Borderless floating window that shows a translation result near the cursor.
/// Supports both instant display (full result) and streaming mode (progressive tokens).
final class FloatingPanelController {
    private var window: NSWindow?
    private var animationDelegate: WindowAnimationDelegate?

    private let panelWidth: CGFloat = 360
    private let minPanelHeight: CGFloat = 120
    private let maxPanelHeight: CGFloat = 560
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

    func showMessage(_ message: String, systemImage: String = "exclamationmark.triangle", near point: NSPoint) {
        dismiss()

        let contentView = FloatingMessagePanelContent(
            message: message,
            systemImage: systemImage,
            onClose: { [weak self] in self?.dismiss() }
        )
        presentWindow(rootView: contentView, near: point, fixedHeight: 64, isResizable: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
            self?.dismiss()
        }
    }

    /// Show panel immediately with loading state, then stream tokens in.
    func showStreaming(
        state: StreamingTranslationState,
        near point: NSPoint,
        onTargetLanguageChange: ((Language) -> Void)? = nil
    ) {
        dismiss()

        let contentView = StreamingPanelContent(
            state: state,
            onCopy:  { [weak self] in self?.copyAndDismiss(state.streamedText) },
            onClose: { [weak self] in self?.dismiss() },
            onTargetLanguageChange: onTargetLanguageChange
        )

        // Fixed height — text scrolls within, no resize jitter
        presentWindow(rootView: contentView, near: point, fixedHeight: streamingHeight)
    }

    func dismiss() {
        window?.orderOut(nil)
        window = nil
        animationDelegate = nil
    }

    func showOutOfCredit(near point: NSPoint, onTopUp: @escaping () -> Void, onUseGoogle: @escaping () -> Void) {
        dismiss()
        let contentView = OutOfCreditPanelContent(
            onTopUp:     { [weak self] in self?.dismiss(); onTopUp() },
            onUseGoogle: { [weak self] in self?.dismiss(); onUseGoogle() },
            onClose:     { [weak self] in self?.dismiss() }
        )
        presentWindow(rootView: contentView, near: point, fixedHeight: 120, isResizable: false)
    }

    // MARK: - Private

    private func presentWindow<V: View>(
        rootView: V,
        near point: NSPoint,
        fixedHeight: CGFloat? = nil,
        isResizable: Bool = true
    ) {
        let hosting = NSHostingController(rootView: rootView)
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.view.layer?.cornerRadius = floatingPanelCornerRadius
        hosting.view.layer?.cornerCurve = .continuous
        hosting.view.layer?.masksToBounds = true

        let win = NSWindow(
            contentRect: NSRect(x: -9999, y: -9999, width: panelWidth, height: 600),
            styleMask: isResizable ? [.resizable] : [],
            backing: .buffered,
            defer: false
        )
        win.level = .floating
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.isMovable = true
        win.isMovableByWindowBackground = true
        // Keep the default width as the minimum so the footer controls never collapse.
        if isResizable {
            win.minSize = NSSize(width: panelWidth, height: minPanelHeight)
            win.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: maxPanelHeight)
            win.contentMinSize = NSSize(width: panelWidth, height: minPanelHeight)
        }
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
            height = max(minPanelHeight, min(maxPanelHeight, hosting.view.fittingSize.height))
        }

        let size = NSSize(width: panelWidth, height: height)
        let frame = adjustedFrame(size: size, near: point)

        win.setFrame(frame, display: false)
        animationDelegate = WindowAnimationDelegate(
            window: win,
            minSize: NSSize(width: panelWidth, height: minPanelHeight),
            maxSize: NSSize(width: CGFloat.greatestFiniteMagnitude, height: maxPanelHeight)
        )
        win.delegate = animationDelegate
        win.makeKeyAndOrderFront(nil)
        animateIn(hosting.view)

        window = win
    }

    private func animateIn(_ view: NSView) {
        view.alphaValue = 0
        view.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        view.layer?.transform = CATransform3DMakeScale(0.97, 0.97, 1)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            view.animator().alphaValue = 1
            view.layer?.transform = CATransform3DIdentity
        }
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

private final class WindowAnimationDelegate: NSObject, NSWindowDelegate {
    weak var window: NSWindow?
    let minSize: NSSize
    let maxSize: NSSize

    init(window: NSWindow, minSize: NSSize, maxSize: NSSize) {
        self.window = window
        self.minSize = minSize
        self.maxSize = maxSize
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        NSSize(
            width: min(max(frameSize.width, minSize.width), maxSize.width),
            height: min(max(frameSize.height, minSize.height), maxSize.height)
        )
    }

    func windowDidResize(_ notification: Notification) {
        guard let window, let view = window.contentView else { return }
        if window.frame.width < minSize.width || window.frame.height < minSize.height {
            let clampedSize = windowWillResize(window, to: window.frame.size)
            window.setFrame(NSRect(origin: window.frame.origin, size: clampedSize), display: true)
        }
        view.layer?.cornerRadius = floatingPanelCornerRadius
        view.layer?.masksToBounds = true
    }
}


private struct FloatingMessagePanelContent: View {
    let message: String
    let systemImage: String
    let onClose: () -> Void

    var body: some View {
        panelContainer {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .modifier(GlassCircleModifier())

                Text(message)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Spacer(minLength: 8)

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

// MARK: - Static result view (existing)

private struct FloatingPanelContent: View {
    let result: TranslationResult
    let onCopy: () -> Void
    let onClose: () -> Void

    @ObservedObject private var creditService = CreditService.shared

    var body: some View {
        panelContainer {
            Text(result.translatedText)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            HStack(alignment: .center, spacing: 8) {
                copyButton(action: onCopy)

                Text("\(result.sourceLanguage.displayName) → \(result.targetLanguage.displayName)")
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

            if SupabaseAuthService.shared.authState.isLoggedIn && creditService.balance < 10 {
                LowCreditRow(balance: creditService.balance) {
                    NotificationCenter.default.post(name: .openAccountTab, object: nil)
                }
            }

            if AINudgeHelper.shouldShowNudge {
                AINudgeRow {
                    NotificationCenter.default.post(name: .openAccountTab, object: nil)
                }
            }
        }
    }
}

// MARK: - Streaming result view

struct StreamingPanelContent: View {
    @ObservedObject var state: StreamingTranslationState
    let onCopy: () -> Void
    let onClose: () -> Void
    let onTargetLanguageChange: ((Language) -> Void)?

    @ObservedObject private var creditService = CreditService.shared

    @ViewBuilder
    private func streamingErrorView(_ raw: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.orange)
                .padding(.top, 1)
            Text(friendlyStreamingError(raw))
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func friendlyStreamingError(_ raw: String) -> String {
        let lower = raw.localizedLowercase
        if lower.contains("timeout") || lower.contains("timed out") {
            return "Request timed out. Check your connection and try again."
        }
        if lower.contains("401") || lower.contains("unauthorized") {
            return "Session expired. Please sign in again."
        }
        if lower.contains("500") || lower.contains("503") {
            return "Server error. Please try again in a moment."
        }
        if lower.contains("network") || lower.contains("offline") || lower.contains("internet") {
            return "Connection error. Check your internet and try again."
        }
        let stripped = raw.replacingOccurrences(
            of: #"^Network error:\s*\[\d+\]\s*"#, with: "", options: .regularExpression
        )
        return stripped.isEmpty ? "Something went wrong. Please try again." : stripped
    }

    private var isCreditError: Bool {
        guard let err = state.error else { return false }
        return err.localizedLowercase.contains("credit") || err.contains("402")
    }

    private var showLowCreditWarning: Bool {
        guard !state.isStreaming && SupabaseAuthService.shared.authState.isLoggedIn else { return false }
        return isCreditError || creditService.balance < 10
    }

    var body: some View {
        panelContainer {
            // Content area — ScrollView prevents overflow, auto-scrolls during streaming
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        if let error = state.error, !isCreditError {
                            streamingErrorView(error)
                        } else if state.streamedText.isEmpty && state.isStreaming {
                            HStack(spacing: 6) {
                                ProgressView().scaleEffect(0.7)
                                Text("Translating…")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else if state.presentation == .conversation {
                            ConversationTranscriptView(
                                text: state.streamedText,
                                isStreaming: state.isStreaming
                            )
                            .textSelection(.enabled)
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

            if showLowCreditWarning {
                LowCreditRow(balance: isCreditError ? 0 : creditService.balance) {
                    NotificationCenter.default.post(name: .openAccountTab, object: nil)
                }
            }

            // Footer
            HStack(alignment: .center, spacing: 8) {
                copyButton(action: onCopy)
                    .disabled(state.isStreaming || state.streamedText.isEmpty)

                targetLanguageMenu(
                    selected: state.targetLanguage,
                    isDisabled: state.isStreaming,
                    onSelect: { language in onTargetLanguageChange?(language) }
                )

                Text("\(state.sourceLanguage.displayName) → \(state.targetLanguage.displayName)")
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

            if !state.isStreaming && AINudgeHelper.shouldShowNudge {
                AINudgeRow {
                    NotificationCenter.default.post(name: .openAccountTab, object: nil)
                }
            }
        }
    }
}

private struct ConversationTranscriptView: View {
    let text: String
    let isStreaming: Bool

    private var messages: [ChatTranscriptMessage] {
        ChatTranscriptMessage.parse(text + (isStreaming ? "▊" : ""))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(messages) { message in
                VStack(alignment: .leading, spacing: 4) {
                    if let header = message.header {
                        Text(header)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Text(message.body)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ChatTranscriptMessage: Identifiable {
    let id = UUID()
    let header: String?
    let body: String

    static func parse(_ text: String) -> [ChatTranscriptMessage] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var messages: [ChatTranscriptMessage] = []
        var currentHeader: String?
        var currentBody: [String] = []

        func flush() {
            let body = currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard currentHeader != nil || !body.isEmpty else { return }
            messages.append(ChatTranscriptMessage(header: currentHeader, body: body))
            currentHeader = nil
            currentBody = []
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("[") && trimmed.contains("]") && trimmed.count <= 80 {
                flush()
                currentHeader = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            } else {
                currentBody.append(line)
            }
        }
        flush()
        return messages.isEmpty ? [ChatTranscriptMessage(header: nil, body: text)] : messages
    }
}

// MARK: - Shared panel chrome

private let floatingPanelCornerRadius: CGFloat = 18
private let floatingPanelShape = RoundedRectangle(cornerRadius: floatingPanelCornerRadius, style: .continuous)

@ViewBuilder
func panelContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    if #available(macOS 26.0, *) {
        GlassEffectContainer(spacing: 8) {
            panelContent(content)
                .glassEffect(.regular, in: floatingPanelShape)
        }
    } else {
        panelContent(content)
            .background(.regularMaterial)
            .clipShape(floatingPanelShape)
            .mask(floatingPanelShape)
            .compositingGroup()
            .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 10)
            .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
    }
}

func panelContent<Content: View>(_ content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 8, content: content)
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
}

@ViewBuilder
private func copyButton(action: @escaping () -> Void) -> some View {
    if #available(macOS 26.0, *) {
        Button(action: action) {
            Label("Copy", systemImage: "doc.on.doc")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .controlSize(.small)
    } else {
        Button(action: action) {
            copyLabel
        }
        .buttonStyle(.plain)
        .controlSize(.small)
    }
}

@ViewBuilder
private func targetLanguageMenu(
    selected: Language,
    isDisabled: Bool,
    onSelect: @escaping (Language) -> Void
) -> some View {
    Menu {
        ForEach(Language.targetOptions) { language in
            Button(language.displayName) { onSelect(language) }
        }
    } label: {
        Text(selected.shortName)
            .lineLimit(1)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .modifier(GlassCapsuleModifier())
    }
    .menuStyle(.borderlessButton)
    .fixedSize(horizontal: true, vertical: false)
    .disabled(isDisabled)
}

private struct GlassCircleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Circle())
        } else {
            content
                .background(.ultraThinMaterial, in: Circle())
                .overlay { Circle().stroke(.primary.opacity(0.10), lineWidth: 1) }
        }
    }
}

private struct GlassCapsuleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        } else {
            content
                .background(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(.primary.opacity(0.12), lineWidth: 1)
                }
                .clipShape(Capsule(style: .continuous))
        }
    }
}

private var copyLabel: some View {
    Label("Copy", systemImage: "doc.on.doc")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .overlay {
            Capsule(style: .continuous)
                .stroke(.primary.opacity(0.12), lineWidth: 1)
        }
        .clipShape(Capsule(style: .continuous))
}
