import AppKit
import Carbon.HIToolbox

/// Four-char signature identifying this app's hotkeys in the Carbon event system ("FTRL").
private let kHotkeySignature: FourCharCode = 0x4654524C

/// Registers global keyboard shortcuts using the Carbon `RegisterEventHotKey` API.
///
/// Three hotkeys are registered:
///   - ⌃⌥T  — translate currently selected text (active)
///   - ⌃⌥S  — screenshot OCR (Phase 5 placeholder)
///   - ⌃⌥V  — translate clipboard (Phase 6 placeholder)
///
/// Rationale for Carbon over CGEventTap:
/// `RegisterEventHotKey` does not require Accessibility permission just to register.
/// CGEventTap needs it at registration time. Carbon is deprecated but stable on macOS 14+.
final class HotkeyManager {
    private var hotkeyRefs: [EventHotKeyRef?] = []
    private var eventHandlerRef: EventHandlerRef?

    private let translationService: TranslationService
    private let floatingPanel: FloatingPanelController

    /// Brief floating window shown when no text is selected.
    private var messageWindow: NSWindow?

    init(translationService: TranslationService, floatingPanel: FloatingPanelController) {
        self.translationService = translationService
        self.floatingPanel = floatingPanel
    }

    deinit {
        hotkeyRefs.compactMap { $0 }.forEach { UnregisterEventHotKey($0) }
        if let handler = eventHandlerRef { RemoveEventHandler(handler) }
    }

    // MARK: - Registration

    func register() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Pass self as userData (unretained — AppDelegate owns HotkeyManager for the full app lifetime)
        let userData = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventCallback,
            1,
            &eventSpec,
            userData,
            &eventHandlerRef
        )
        guard status == noErr else {
            print("HotkeyManager: InstallEventHandler failed (\(status))")
            return
        }

        registerHotkey(keyCode: Constants.HotkeyCode.translate,   id: Constants.HotkeyIDs.translate)
        registerHotkey(keyCode: Constants.HotkeyCode.screenshot,  id: Constants.HotkeyIDs.screenshot)
        registerHotkey(keyCode: Constants.HotkeyCode.clipboard,   id: Constants.HotkeyIDs.clipboard)
    }

    private func registerHotkey(keyCode: UInt32, id: UInt32) {
        var ref: EventHotKeyRef?
        let hotkeyID = EventHotKeyID(signature: kHotkeySignature, id: id)
        let modifiers = UInt32(controlKey | optionKey)
        let status = RegisterEventHotKey(
            keyCode, modifiers, hotkeyID,
            GetApplicationEventTarget(), 0, &ref
        )
        if status == noErr {
            hotkeyRefs.append(ref)
        } else {
            print("HotkeyManager: RegisterEventHotKey id=\(id) failed (\(status))")
        }
    }

    // MARK: - Dispatch (called from C callback via DispatchQueue.main)

    fileprivate func handleHotkeyID(_ id: UInt32) {
        switch id {
        case Constants.HotkeyIDs.translate:
            handleTranslateSelected()
        case Constants.HotkeyIDs.screenshot:
            print("HotkeyManager: ⌃⌥S — Screenshot OCR (Phase 5 placeholder)")
        case Constants.HotkeyIDs.clipboard:
            print("HotkeyManager: ⌃⌥V — Clipboard translate (Phase 6 placeholder)")
        default:
            break
        }
    }

    // MARK: - Handlers

    private func handleTranslateSelected() {
        // Capture mouse location at the moment the hotkey fires (before the async translation delay)
        // Mouse is always at the END of the selection — the most natural anchor point
        let anchorPoint = NSEvent.mouseLocation
        print("[HotkeyManager] hotkey fired — mouseLocation = \(anchorPoint)")
        Task { @MainActor in
            guard let text = await SelectedTextReader.readSelectedText(), !text.isEmpty else {
                showBriefMessage("No text selected", near: anchorPoint)
                return
            }
            do {
                let result = try await translationService.translate(text)
                floatingPanel.show(result: result, near: anchorPoint)
            } catch {
                print("HotkeyManager: translation error — \(error.localizedDescription)")
            }
        }
    }

    /// Displays a small 2-second floating banner with a plain text message.
    @MainActor
    private func showBriefMessage(_ message: String, near point: NSPoint) {
        messageWindow?.orderOut(nil)

        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        label.sizeToFit()

        let padding: CGFloat = 10
        let contentSize = NSSize(
            width: label.frame.width + padding * 2,
            height: label.frame.height + padding * 2
        )
        label.frame = NSRect(x: padding, y: padding, width: label.frame.width, height: label.frame.height)

        let offset: CGFloat = 12
        let origin = NSPoint(x: point.x + offset, y: point.y + offset)

        let win = NSWindow(
            contentRect: NSRect(origin: origin, size: contentSize),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        win.level = .floating
        win.isOpaque = false
        win.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.92)
        win.contentView?.addSubview(label)
        win.orderFront(nil)
        messageWindow = win

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.messageWindow?.orderOut(nil)
            self?.messageWindow = nil
        }
    }
}

// MARK: - C-compatible Carbon event callback

/// Must be a global (non-capturing) function to satisfy the C function-pointer requirement.
/// Extracts the HotkeyManager from `userData` and dispatches on the main queue.
private func hotkeyEventCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }

    var hotkeyID = EventHotKeyID()
    let err = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotkeyID
    )
    guard err == noErr else { return OSStatus(eventNotHandledErr) }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async { manager.handleHotkeyID(hotkeyID.id) }
    return noErr
}
