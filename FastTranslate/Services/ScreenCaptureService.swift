import AppKit
import ScreenCaptureKit

// MARK: - Screen Capture Service

/// Presents a fullscreen crosshair overlay on the active screen and captures
/// the user-selected region as a CGImage (in-memory, no file written to disk).
@MainActor
final class ScreenCaptureService {
    private var activeSelector: RegionSelector?

    // MARK: Permission

    static func hasPermission() -> Bool { CGPreflightScreenCaptureAccess() }
    static func requestPermission() { CGRequestScreenCaptureAccess() }

    // MARK: Capture

    /// Shows a crosshair selection overlay on the screen containing the cursor.
    /// Returns the captured CGImage, or nil if the user cancels (Escape or tiny selection).
    func captureRegion() async -> CGImage? {
        #if !DEBUG
        guard Self.hasPermission() else {
            Self.requestPermission()
            return nil
        }
        #endif
        return await withCheckedContinuation { continuation in
            let selector = RegionSelector { [weak self] image in
                self?.activeSelector = nil
                continuation.resume(returning: image)
            }
            activeSelector = selector
            selector.present()
        }
    }
}

// MARK: - Overlay Window

/// Borderless NSWindow subclass — overrides canBecomeKey so makeKeyAndOrderFront
/// actually works and the SelectionView receives mouse + keyboard events.
private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - Region Selector

/// Manages the overlay window lifecycle and the ScreenCaptureKit screenshot.
private final class RegionSelector: NSObject {
    private var window: NSWindow?
    private let onComplete: (CGImage?) -> Void
    private var isDone = false
    private var timeoutTask: Task<Void, Never>?
    private var resignObserver: Any?

    init(onComplete: @escaping (CGImage?) -> Void) {
        self.onComplete = onComplete
    }

    func present() {
        let mousePoint = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mousePoint, $0.frame, false) } ?? NSScreen.main!

        let win = OverlayWindow(
            contentRect: screen.frame,
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        win.level = .screenSaver
        win.isOpaque = false
        win.backgroundColor = .clear
        win.ignoresMouseEvents = false
        win.acceptsMouseMovedEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size), selector: self)
        win.contentView = view
        NSApp.activate(ignoringOtherApps: true)
        win.makeFirstResponder(view)
        win.makeKeyAndOrderFront(nil)
        window = win
        print("[SCCapture] overlay presented  screen='\(screen.localizedName)'  frame=\(screen.frame)  isKey=\(win.isKeyWindow)")

        // Safety: auto-cancel if user doesn't interact within 30s
        timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard let self, !self.isDone else { return }
            print("[SCCapture] timeout — auto-cancelling overlay")
            self.cancel()
        }

        // Safety: cancel when app loses focus (e.g. Cmd+Tab away)
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, !self.isDone else { return }
            print("[SCCapture] app resigned active — cancelling overlay")
            self.cancel()
        }
    }

    /// Converts the NSView-local selection rect to CG coordinates, dismisses the overlay,
    /// then captures via ScreenCaptureKit (overlay is gone before the frame is taken).
    func captureRect(_ viewRect: NSRect) {
        guard let win = window else { finish(nil); return }

        // Convert NSView coords → global AppKit coords → CG coords (top-left origin, y down).
        // Must use CGDisplayBounds(CGMainDisplayID()).height (the CG primary display at origin 0,0),
        // NOT NSScreen.main.frame.height which returns the focused-window screen and can differ.
        let screenRect = win.convertToScreen(viewRect)
        let cgPrimaryHeight = CGDisplayBounds(CGMainDisplayID()).height
        let cgRect = CGRect(
            x: screenRect.origin.x,
            y: cgPrimaryHeight - screenRect.origin.y - screenRect.height,
            width: screenRect.width,
            height: screenRect.height
        )
        let scaleFactor = win.screen?.backingScaleFactor ?? 2.0

        print("[SCCapture] viewRect=\(viewRect)")
        print("[SCCapture] screenRect(AppKit)=\(screenRect)  cgPrimaryHeight=\(cgPrimaryHeight)")
        print("[SCCapture] cgRect(global-CG)=\(cgRect)  scaleFactor=\(scaleFactor)  cgPrimaryHeight=\(cgPrimaryHeight)")
        print("[SCCapture] win.screen=\(win.screen?.localizedName ?? "nil")  frame=\(win.screen?.frame ?? .zero)")

        // Dismiss overlay first so it does not appear in the screenshot
        win.orderOut(nil)
        window = nil

        Task {
            let image = await Self.captureWithSCKit(cgRect: cgRect, scaleFactor: scaleFactor)
            self.finish(image)
        }
    }

    // MARK: ScreenCaptureKit

    private static func captureWithSCKit(cgRect: CGRect, scaleFactor: CGFloat) async -> CGImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            print("[SCCapture] available displays:")
            for d in content.displays { print("  display id=\(d.displayID) frame=\(d.frame) size=\(d.width)×\(d.height)") }

            let center = CGPoint(x: cgRect.midX, y: cgRect.midY)
            guard let display = content.displays.first(where: { $0.frame.contains(center) })
                              ?? content.displays.first else {
                print("[SCCapture] ERROR: no display found for center=\(center)")
                return nil
            }
            print("[SCCapture] matched display id=\(display.displayID) frame=\(display.frame)")

            let filter = SCContentFilter(display: display, excludingWindows: [])

            // sourceRect is in display-local coordinates (origin = display top-left, y down).
            // Subtract the display's CG global origin to convert from global → local.
            let localRect = CGRect(
                x: cgRect.origin.x - display.frame.origin.x,
                y: cgRect.origin.y - display.frame.origin.y,
                width: cgRect.width,
                height: cgRect.height
            )
            print("[SCCapture] localRect=\(localRect)")

            let config = SCStreamConfiguration()
            config.sourceRect = localRect
            config.width = max(1, Int(cgRect.width * scaleFactor))
            config.height = max(1, Int(cgRect.height * scaleFactor))
            print("[SCCapture] output size=\(config.width)×\(config.height)")
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            print("[SCCapture] captured image size=\(image.width)×\(image.height)")
            return image
        } catch {
            print("[SCCapture] ERROR: \(error)")
            return nil
        }
    }

    func cancel() {
        print("[SCCapture] cancel called")
        finish(nil)
    }

    private func finish(_ image: CGImage?) {
        guard !isDone else { return }
        isDone = true
        timeoutTask?.cancel()
        timeoutTask = nil
        if let obs = resignObserver { NotificationCenter.default.removeObserver(obs) }
        resignObserver = nil
        print("[SCCapture] finish  image=\(image != nil ? "ok" : "nil")")
        window?.orderOut(nil)
        window = nil
        onComplete(image)
    }
}

// MARK: - Selection View

/// Custom NSView that draws the dim overlay and selection rectangle.
private final class SelectionView: NSView {
    private weak var selector: RegionSelector?
    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?

    init(frame: NSRect, selector: RegionSelector) {
        self.selector = selector
        super.init(frame: frame)
        wantsLayer = true  // required for CGContext blend mode .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    // MARK: Mouse Events

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        print("[SCCapture] mouseDown at \(startPoint!)")
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = startPoint else {
            print("[SCCapture] mouseUp — no startPoint, ignoring")
            return
        }
        let end = convert(event.locationInWindow, from: nil)
        let rect = NSRect(
            x: min(start.x, end.x), y: min(start.y, end.y),
            width: abs(end.x - start.x), height: abs(end.y - start.y)
        )
        print("[SCCapture] mouseUp  start=\(start) end=\(end) rect=\(rect)")
        guard rect.width > 5, rect.height > 5 else {
            print("[SCCapture] rect too small (\(rect.width)×\(rect.height)), cancelling")
            selector?.cancel()
            return
        }
        selector?.captureRect(rect)
    }

    // MARK: Keyboard Events

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { selector?.cancel() }  // Escape
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Dim the entire screen
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.4).cgColor)
        ctx.fill([bounds])

        guard let start = startPoint, let current = currentPoint else { return }
        let sel = CGRect(
            x: min(start.x, current.x), y: min(start.y, current.y),
            width: abs(current.x - start.x), height: abs(current.y - start.y)
        )

        // Punch out the selection area so the content below shows through
        ctx.setBlendMode(.clear)
        ctx.fill([sel])
        ctx.setBlendMode(.normal)

        // Dashed white border around selection
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineDash(phase: 0, lengths: [6, 3])
        ctx.stroke(sel.insetBy(dx: 0.75, dy: 0.75))
    }
}
