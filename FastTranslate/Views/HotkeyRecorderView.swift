import SwiftUI
import AppKit
import Carbon.HIToolbox

// MARK: - NSView subclass that captures key events

/// Native key-recording field. Click to start recording, press modifier+key to capture.
final class HotkeyRecorderNSView: NSView {
    var currentBinding: HotkeyBinding?
    var onRecord: ((HotkeyBinding) -> Void)?

    private var isRecording = false
    private var liveModifiers: UInt32 = 0
    private var trackingArea: NSTrackingArea?
    private var isHovered = false

    override var acceptsFirstResponder: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Focus

    override func becomeFirstResponder() -> Bool {
        isRecording = true
        liveModifiers = 0
        needsDisplay = true
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        liveModifiers = 0
        needsDisplay = true
        return super.resignFirstResponder()
    }

    override func mouseDown(with event: NSEvent) {
        if !isRecording {
            window?.makeFirstResponder(self)
        }
    }

    // MARK: - Key capture

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }

        // Escape cancels
        if event.keyCode == UInt16(kVK_Escape) {
            window?.makeFirstResponder(nil)
            return
        }

        let carbonModifiers = Self.carbonModifiers(from: event.modifierFlags)

        // Require at least one modifier to avoid conflicts with system/app shortcuts
        guard carbonModifiers != 0 else { return }

        let binding = HotkeyBinding(keyCode: UInt32(event.keyCode), modifiers: carbonModifiers)
        onRecord?(binding)
        window?.makeFirstResponder(nil)
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecording else { return }
        liveModifiers = Self.carbonModifiers(from: event.modifierFlags)
        needsDisplay = true
    }

    // MARK: - Tracking area (hover)

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent)  { isHovered = false; needsDisplay = true }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)

        // Background
        if isRecording {
            NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
        } else if isHovered {
            NSColor.labelColor.withAlphaComponent(0.06).setFill()
        } else {
            NSColor.labelColor.withAlphaComponent(0.04).setFill()
        }
        path.fill()

        // Border
        if isRecording {
            NSColor.controlAccentColor.withAlphaComponent(0.5).setStroke()
        } else {
            NSColor.labelColor.withAlphaComponent(0.1).setStroke()
        }
        path.lineWidth = 1
        path.stroke()

        // Text
        let text: String
        if isRecording {
            if liveModifiers != 0 {
                text = Self.modifierSymbols(liveModifiers) + "…"
            } else {
                text = "Record shortcut…"
            }
        } else {
            text = currentBinding?.displayString ?? "None"
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: isRecording ? .medium : .bold),
            .foregroundColor: isRecording ? NSColor.controlAccentColor : NSColor.labelColor
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let point = NSPoint(x: (bounds.width - size.width) / 2,
                            y: (bounds.height - size.height) / 2)
        (text as NSString).draw(at: point, withAttributes: attrs)
    }

    // MARK: - Modifier conversion

    /// Convert NSEvent.ModifierFlags → Carbon modifier mask.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option)  { carbon |= UInt32(optionKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.shift)   { carbon |= UInt32(shiftKey) }
        return carbon
    }

    private static func modifierSymbols(_ mods: UInt32) -> String {
        var s = ""
        if mods & UInt32(controlKey) != 0 { s += "⌃" }
        if mods & UInt32(optionKey)  != 0 { s += "⌥" }
        if mods & UInt32(shiftKey)   != 0 { s += "⇧" }
        if mods & UInt32(cmdKey)     != 0 { s += "⌘" }
        return s
    }
}

// MARK: - SwiftUI wrapper

/// SwiftUI-compatible hotkey recorder field.
struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var binding: HotkeyBinding

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView(frame: NSRect(x: 0, y: 0, width: 120, height: 28))
        view.currentBinding = binding
        view.onRecord = { newBinding in
            context.coordinator.parent.binding = newBinding
        }
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.currentBinding = binding
        nsView.needsDisplay = true
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator {
        var parent: HotkeyRecorderView
        init(_ parent: HotkeyRecorderView) { self.parent = parent }
    }
}
