import AppKit
import SwiftUI

@MainActor
final class SelectionTranslateButtonController {
    private var window: NSPanel?
    private var timer: Timer?
    private var mouseDownMonitor: Any?
    private var mouseDraggedMonitor: Any?
    private var mouseUpMonitor: Any?
    private var selectionCheckTask: Task<Void, Never>?
    private var lastText: String?
    private var mouseDownLocation: NSPoint?
    private var selectionAnchor: NSPoint?
    private var hasSelectionDrag = false
    private var isHovering = false
    private var isCheckingSelection = false
    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Constants.UserDefaultsKey.showSelectionTranslateButton) as? Bool ?? false
    }
    private let onTranslate: () -> Void

    private let dragThreshold: CGFloat = 4

    init(onTranslate: @escaping () -> Void) {
        self.onTranslate = onTranslate
    }

    func start() {
        stop()

        // Keep the lightweight AX poll for apps that expose selected text and for keyboard selection.
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollSelection() }
        }
        timer?.tolerance = 0.2

        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            Task { @MainActor in self?.handleMouseDown(event) }
        }
        mouseDraggedMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            Task { @MainActor in self?.handleMouseDragged(event) }
        }
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            Task { @MainActor in self?.handleMouseUp(event) }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(selectionButtonSettingChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        selectionCheckTask?.cancel()
        selectionCheckTask = nil
        removeEventMonitor(&mouseDownMonitor)
        removeEventMonitor(&mouseDraggedMonitor)
        removeEventMonitor(&mouseUpMonitor)
        NotificationCenter.default.removeObserver(self, name: UserDefaults.didChangeNotification, object: nil)
        hide()
    }

    @objc private func selectionButtonSettingChanged() {
        if !isEnabled { hide() }
    }

    private func pollSelection() {
        guard isEnabled else {
            hide()
            return
        }

        guard AXIsProcessTrusted(), !NSApp.isActive else {
            hide()
            return
        }

        guard let text = SelectedTextReader.readSelectedTextUsingAccessibilityOnly(), !text.isEmpty else {
            // Some apps (Terminal/IDEs) do not expose selected text via AX after the
            // button is shown from the clipboard fallback. Keep the current button
            // visible instead of immediately hiding it on the next lightweight poll.
            return
        }

        showIfNeeded(for: text)
    }

    private func handleMouseDown(_ event: NSEvent) {
        guard isEnabled else { hide(); return }
        guard !NSApp.isActive else { return }

        // A fresh click usually clears the previous selection. Hide immediately so
        // the button only belongs to the current selected text.
        if !isHovering { hide() }

        mouseDownLocation = event.locationInWindow
        hasSelectionDrag = false
    }

    private func handleMouseDragged(_ event: NSEvent) {
        guard isEnabled else { return }
        guard let start = mouseDownLocation else { return }
        if distance(from: start, to: event.locationInWindow) >= dragThreshold {
            hasSelectionDrag = true
        }
    }

    private func handleMouseUp(_ event: NSEvent) {
        guard isEnabled else {
            hide()
            mouseDownLocation = nil
            hasSelectionDrag = false
            return
        }

        guard hasSelectionDrag, !NSApp.isActive else {
            mouseDownLocation = nil
            hasSelectionDrag = false
            return
        }

        selectionAnchor = event.locationInWindow
        mouseDownLocation = nil
        hasSelectionDrag = false
        scheduleSelectionCheckNearMouse()
    }

    private func scheduleSelectionCheckNearMouse() {
        selectionCheckTask?.cancel()
        selectionCheckTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }

            await self?.checkSelectionWithClipboardFallback()
        }
    }

    private func checkSelectionWithClipboardFallback() async {
        guard isEnabled else { hide(); return }
        guard AXIsProcessTrusted(), !NSApp.isActive, !isCheckingSelection else { return }
        isCheckingSelection = true
        defer { isCheckingSelection = false }

        guard let text = await SelectedTextReader.readSelectedText(), !text.isEmpty else {
            if !isHovering { hide() }
            return
        }

        showIfNeeded(for: text)
    }

    private func showIfNeeded(for text: String) {
        if text == lastText, window?.isVisible == true { return }
        lastText = text
        showNearMouse()
    }

    private func showNearMouse() {
        let size = NSSize(width: 44, height: 32)
        let anchor = selectionAnchor ?? NSEvent.mouseLocation
        let origin = clampedOrigin(
            NSPoint(x: anchor.x + 6, y: anchor.y - size.height - 6),
            size: size
        )

        let panel = window ?? makePanel(size: size)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
        window = panel
    }

    private func makePanel(size: NSSize) -> NSPanel {
        let content = SelectionTranslateButton(
            onHoverChanged: { [weak self] hovering in self?.isHovering = hovering },
            onTap: { [weak self] in
                self?.hide()
                self?.onTranslate()
            }
        )
        let hosting = NSHostingController(rootView: content)
        hosting.view.frame = NSRect(origin: .zero, size: size)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting.view
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = size.height / 2
        panel.contentView?.layer?.masksToBounds = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        return panel
    }

    private func hide() {
        window?.orderOut(nil)
        lastText = nil
    }

    private func removeEventMonitor(_ monitor: inout Any?) {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func distance(from start: NSPoint, to end: NSPoint) -> CGFloat {
        hypot(end.x - start.x, end.y - start.y)
    }

    private func clampedOrigin(_ origin: NSPoint, size: NSSize) -> NSPoint {
        guard let screenFrame = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })?.visibleFrame else {
            return origin
        }
        return NSPoint(
            x: min(max(origin.x, screenFrame.minX + 8), screenFrame.maxX - size.width - 8),
            y: min(max(origin.y, screenFrame.minY + 8), screenFrame.maxY - size.height - 8)
        )
    }
}

private struct SelectionTranslateButton: View {
    let onHoverChanged: (Bool) -> Void
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "character.bubble.fill")
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 32)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.30), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .modifier(SelectionButtonGlassModifier())
            .clipShape(Capsule(style: .continuous))
            .contentShape(Capsule(style: .continuous))
            .scaleEffect(isHovered ? 1.04 : 1.0)
            .shadow(color: .black.opacity(isHovered ? 0.18 : 0.12), radius: isHovered ? 14 : 9, y: isHovered ? 6 : 4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            onHoverChanged(hovering)
        }
        .animation(.spring(response: 0.18, dampingFraction: 0.75), value: isHovered)
        .help("Translate selected text")
    }
}


private struct SelectionButtonGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        let shape = Capsule(style: .continuous)
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay { shape.stroke(.white.opacity(0.55), lineWidth: 1) }
                .overlay { shape.stroke(.primary.opacity(0.10), lineWidth: 1) }
                .clipShape(shape)
        }
    }
}
