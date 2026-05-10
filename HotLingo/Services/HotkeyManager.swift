import AppKit
import Carbon.HIToolbox

/// Four-char signature identifying this app's hotkeys in the Carbon event system ("FTRL").
private let kHotkeySignature: FourCharCode = 0x4654524C

/// Registers global keyboard shortcuts using the Carbon `RegisterEventHotKey` API.
///
/// Two hotkeys are registered:
///   - ⌃⌥T  — translate currently selected text
///   - ⌃⌥S  — screenshot OCR
///
/// Rationale for Carbon over CGEventTap:
/// `RegisterEventHotKey` does not require Accessibility permission just to register.
/// CGEventTap needs it at registration time. Carbon is deprecated but stable on macOS 14+.
final class HotkeyManager {
    private var hotkeyRefs: [EventHotKeyRef?] = []
    private var eventHandlerRef: EventHandlerRef?

    private let translationService: TranslationService
    private let floatingPanel: FloatingPanelController
    private let screenCaptureService: ScreenCaptureService
    private let ocrService: OCRService

    init(
        translationService: TranslationService,
        floatingPanel: FloatingPanelController,
        screenCaptureService: ScreenCaptureService,
        ocrService: OCRService
    ) {
        self.translationService = translationService
        self.floatingPanel = floatingPanel
        self.screenCaptureService = screenCaptureService
        self.ocrService = ocrService
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

        registerFromStore()
    }

    /// Unregister all current hotkeys and re-register from HotkeyStore.
    func reRegister() {
        // Unregister existing
        for ref in hotkeyRefs {
            if let ref { UnregisterEventHotKey(ref) }
        }
        hotkeyRefs.removeAll()

        registerFromStore()
    }

    private func registerFromStore() {
        let store = HotkeyStore.shared
        registerHotkey(keyCode: store.translateBinding.keyCode,
                       modifiers: store.translateBinding.modifiers,
                       id: Constants.HotkeyIDs.translate)
        registerHotkey(keyCode: store.screenshotBinding.keyCode,
                       modifiers: store.screenshotBinding.modifiers,
                       id: Constants.HotkeyIDs.screenshot)
    }

    private func registerHotkey(keyCode: UInt32, modifiers: UInt32, id: UInt32) {
        var ref: EventHotKeyRef?
        let hotkeyID = EventHotKeyID(signature: kHotkeySignature, id: id)
        let status = RegisterEventHotKey(
            keyCode, modifiers, hotkeyID,
            GetApplicationEventTarget(), 0, &ref
        )
        if status == noErr {
            hotkeyRefs.append(ref)
        } else {
            print("HotkeyManager: RegisterEventHotKey id=\(id) failed (\(status))")
            // Report failure to HotkeyStore for UI display
            let action: HotkeyAction = (id == Constants.HotkeyIDs.translate) ? .translate : .screenshot
            HotkeyStore.shared.registrationError = (action: action, message: "System rejected this shortcut (code \(status))")
        }
    }

    // MARK: - Dispatch (called from C callback via DispatchQueue.main)

    fileprivate func handleHotkeyID(_ id: UInt32) {
        switch id {
        case Constants.HotkeyIDs.translate:
            translateSelectedTextFromCurrentMouseLocation()
        case Constants.HotkeyIDs.screenshot:
            handleScreenshotOCR()
        default:
            break
        }
    }

    func translateSelectedTextFromCurrentMouseLocation() {
        handleTranslateSelected()
    }

    // MARK: - Handlers

    private func handleScreenshotOCR() {
        Task { @MainActor in
            print("[HotkeyManager] ⌃⌥S fired — starting screenshot OCR")
            let anchorPoint = NSEvent.mouseLocation
            guard let cgImage = await screenCaptureService.captureRegion() else {
                if !ScreenCaptureService.hasPermission() {
                    floatingPanel.showMessage(String(localized: "panel.screenRecordingRequired"), systemImage: "record.circle", near: anchorPoint)
                }
                return
            }
            do {
                let document = try await ocrService.recognizeDocument(from: cgImage)
                try streamTranslation(
                    document.text,
                    near: anchorPoint,
                    perMessageContext: document.translationContext,
                    presentation: document.presentation
                )
            } catch {
                floatingPanel.showMessage(error.localizedDescription, systemImage: "exclamationmark.triangle", near: anchorPoint)
            }
        }
    }

    private func handleTranslateSelected() {
        let anchorPoint = NSEvent.mouseLocation
        print("[HotkeyManager] hotkey fired — mouseLocation = \(anchorPoint)")
        Task { @MainActor in
            guard let text = await SelectedTextReader.readSelectedText(), !text.isEmpty else {
                floatingPanel.showMessage(String(localized: "panel.noTextSelected"), systemImage: "text.cursor", near: anchorPoint)
                return
            }
            do {
                try streamTranslation(text, near: anchorPoint)
            } catch {
                floatingPanel.showMessage(error.localizedDescription, systemImage: "exclamationmark.triangle", near: anchorPoint)
            }
        }
    }

    /// Show panel immediately, then pipe streamed tokens into it.
    /// Pass `providerOverride` to use a specific provider for this call only — does not change settings.
    @MainActor
    private func streamTranslation(
        _ text: String,
        near point: NSPoint,
        perMessageContext: String? = nil,
        presentation: TranslationPresentation = .plain,
        providerOverride: ProviderType? = nil
    ) throws {
        let (source, target, stream) = try translationService.translateStreaming(
            text,
            perMessageContext: perMessageContext,
            providerOverride: providerOverride
        )

        let state = StreamingTranslationState(
            sourceText: text,
            sourceLanguage: source,
            targetLanguage: target,
            provider: translationService.activeProviderType,
            presentation: presentation
        )
        floatingPanel.showStreaming(
            state: state,
            near: point,
            onTargetLanguageChange: { [weak self] language in
                self?.restartTranslation(state: state, targetLanguage: language)
            }
        )

        consume(stream, into: state)
    }

    @MainActor
    private func restartTranslation(state: StreamingTranslationState, targetLanguage: Language) {
        do {
            let (source, target, stream) = try translationService.translateStreaming(
                state.sourceText,
                targetLanguage: targetLanguage,
                perMessageContext: state.presentation == .conversation
                    ? "Translate this chat transcript message-by-message. Preserve speaker names, timestamps, mentions, emojis, and message order. Return [speaker timestamp] headers followed by translated message text."
                    : nil
            )
            // Cancel any in-flight consumer before resetting state to prevent two Tasks
            // racing to append to streamedText.
            state.consumeTask?.cancel()
            state.consumeTask = nil
            state.streamedText = ""
            state.error = nil
            state.isStreaming = true
            state.targetLanguage = target
            consume(stream, into: state)
        } catch {
            state.isStreaming = false
            state.error = error.localizedDescription
        }
    }

    @MainActor
    private func consume(_ stream: AsyncThrowingStream<String, Error>, into state: StreamingTranslationState) {
        state.consumeTask = Task { @MainActor in
            do {
                for try await chunk in stream {
                    state.streamedText += chunk
                }
                state.isStreaming = false
                translationService.addToHistory(state.completedResult)
                trackGoogleTranslateIfNeeded(state: state)
            } catch let error as TranslationError {
                state.isStreaming = false
                state.error = error.localizedDescription
            } catch {
                state.isStreaming = false
                state.error = error.localizedDescription
            }
        }
    }

    @MainActor
    private func trackGoogleTranslateIfNeeded(state: StreamingTranslationState) {
        guard state.provider == .googleTranslate else { return }
        let key = Constants.UserDefaultsKey.googleTranslateCount
        let count = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(count, forKey: key)

        if AINudgeHelper.shouldShowBanner {
            AINudgeHelper.markBannerSeen()
            let anchorPoint = NSEvent.mouseLocation
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.floatingPanel.showMessage(
                    "You've translated \(count) times! Try AI free — 50 credits",
                    systemImage: "wand.and.stars",
                    near: anchorPoint
                )
            }
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
