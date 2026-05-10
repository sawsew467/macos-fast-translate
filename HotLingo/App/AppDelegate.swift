import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popoverWindow: NSPanel?
    private var eventMonitor: Any?
    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?
    var floatingPanel = FloatingPanelController()
    private var hotkeyManager: HotkeyManager?
    private var selectionTranslateButton: SelectionTranslateButtonController?
    private var hotkeyCancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        migrateAPIKeyToKeychain()
        _ = SupabaseAuthService.shared  // triggers restoreSession() in init
        setupStatusItem()
        setupPopover()
        setupEventMonitor()
        setupHotkeys()
        setupSelectionTranslateButton()
        setupAccountTabNotificationHandler()
        checkFirstLaunch()
        showPopoverOnLaunchIfNeeded()
        UpdateService.shared.checkOnLaunch()

        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateWindowTitlesForLanguage()
        }
    }

    private func updateWindowTitlesForLanguage() {
        settingsWindow?.title = String(localized: "HotLingo Settings", locale: effectiveLocale)
        onboardingWindow?.title = String(localized: "Welcome to HotLingo", locale: effectiveLocale)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        selectionTranslateButton?.stop()
    }

    /// Show Settings → About when user reopens the app (e.g. clicks icon in Spotlight/Finder while running).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            openSettingsOnAboutTab()
        }
        return true
    }

    // MARK: - Setup

    /// Opens the Settings window when an external request to show the Account tab arrives.
    /// If the window is not yet visible, posts `.openAccountTab` again after a short delay
    /// so SettingsView's `onReceive` fires after it has loaded.
    private func setupAccountTabNotificationHandler() {
        NotificationCenter.default.addObserver(
            forName: .openAccountTab,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let isAlreadyOpen = self.settingsWindow?.isVisible == true
            self.openSettings()
            if !isAlreadyOpen {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    NotificationCenter.default.post(name: .openAccountTab, object: nil)
                }
            }
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "HotLingo")
        button.action = #selector(statusItemClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// Returns the effective locale based on user's app language preference.
    private var effectiveLocale: Locale {
        let raw = UserDefaults.standard.string(forKey: Constants.UserDefaultsKey.appLanguage) ?? Constants.AppLanguage.system.rawValue
        let lang = Constants.AppLanguage(rawValue: raw) ?? .system
        return lang.locale ?? Locale.current
    }

    private func setupPopover() {
        let controller = NSHostingController(rootView: LocaleWrapper { TranslationPopoverView() })
        let window = QuickTranslatePanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 340),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = controller
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 26
        window.contentView?.layer?.cornerCurve = .continuous
        window.contentView?.layer?.masksToBounds = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window.hidesOnDeactivate = false
        popoverWindow = window
    }

    private func setupHotkeys() {
        #if !DEBUG
        if !AXIsProcessTrusted() {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
        }
        #endif

        let service = TranslationService()
        let manager = HotkeyManager(
            translationService: service,
            floatingPanel: floatingPanel,
            screenCaptureService: ScreenCaptureService(),
            ocrService: OCRService()
        )
        manager.register()
        hotkeyManager = manager

        // Re-register hotkeys when user changes bindings in Settings
        let store = HotkeyStore.shared
        store.$translateBinding
            .merge(with: store.$screenshotBinding)
            .dropFirst(2) // skip initial values
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak manager] _ in manager?.reRegister() }
            .store(in: &hotkeyCancellables)
    }

    /// Close the centered quick-translate window on any click outside it.
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.popoverWindow?.isVisible == true else { return }
            self.closePopover()
        }
    }

    private func setupSelectionTranslateButton() {
        let controller = SelectionTranslateButtonController { [weak self] in
            self?.hotkeyManager?.translateSelectedTextFromCurrentMouseLocation()
        }
        controller.start()
        selectionTranslateButton = controller
    }

    // MARK: - Status item click handling

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showStatusItemMenu(sender)
        } else {
            togglePopover()
        }
    }

    private func showStatusItemMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        let updatesItem = NSMenuItem(title: String(localized: "Check for Updates\u{2026}"), action: #selector(checkForUpdates), keyEquivalent: "")
        updatesItem.target = self
        updatesItem.image = NSImage(systemSymbolName: "arrow.clockwise.circle", accessibilityDescription: "Check for Updates")
        menu.addItem(updatesItem)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: String(localized: "Settings\u{2026}"), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Quit HotLingo"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }

    @objc private func checkForUpdates() {
        openSettingsOnAboutTab()
        UpdateService.shared.checkForUpdates()
    }

    /// Open Settings window and switch to About tab.
    private func openSettingsOnAboutTab() {
        openSettings()
        NotificationCenter.default.post(name: .openAboutTab, object: nil)
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let controller = NSHostingController(rootView: LocaleWrapper { SettingsView() })
            let window = NSWindow(contentViewController: controller)
            window.title = String(localized: "HotLingo Settings", locale: effectiveLocale)
            window.styleMask = [.titled, .closable]
            window.setFrame(NSRect(x: 0, y: 0, width: 560, height: 500), display: false)
            centerWindowOnMainScreen(window)
            // Clear reference when window closes
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window, queue: .main
            ) { [weak self] _ in self?.settingsWindow = nil }
            settingsWindow = window
        }
        if let settingsWindow {
            centerWindowOnMainScreen(settingsWindow)
            settingsWindow.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func centerWindowOnMainScreen(_ window: NSWindow) {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame
        guard let screenFrame else {
            window.center()
            return
        }

        let frame = window.frame
        let origin = NSPoint(
            x: screenFrame.midX - frame.width / 2,
            y: screenFrame.midY - frame.height / 2
        )
        window.setFrameOrigin(origin)
    }

    // MARK: - Popover control

    private func togglePopover() {
        if popoverWindow?.isVisible == true { closePopover() } else { openPopover() }
    }

    private func openPopover() {
        guard let window = popoverWindow else { return }
        centerWindowOnMainScreen(window)

        let finalFrame = window.frame
        let startFrame = finalFrame.insetBy(dx: 10, dy: 8)
        window.alphaValue = 0
        window.setFrame(startFrame, display: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
            window.animator().alphaValue = 1
            window.animator().setFrame(finalFrame, display: true)
        }
    }

    private func closePopover() {
        guard let window = popoverWindow, window.isVisible else { return }

        let finalFrame = window.frame
        let endFrame = finalFrame.insetBy(dx: 8, dy: 6)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0
            window.animator().setFrame(endFrame, display: true)
        } completionHandler: {
            window.orderOut(nil)
            window.alphaValue = 1
            window.setFrame(finalFrame, display: false)
        }
    }

    // MARK: - UserDefaults → Keychain migration (one-time)

    /// If the old UserDefaults key exists and Keychain is empty, migrate silently.
    private func migrateAPIKeyToKeychain() {
        let udKey = "openai_api_key"
        guard let oldKey = UserDefaults.standard.string(forKey: udKey), !oldKey.isEmpty,
              KeychainHelper.load(account: Constants.KeychainAccount.openAIAPIKey) == nil
        else { return }
        try? KeychainHelper.save(account: Constants.KeychainAccount.openAIAPIKey, value: oldKey)
        UserDefaults.standard.removeObject(forKey: udKey)
    }

    // MARK: - Launch behavior

    private func showPopoverOnLaunchIfNeeded() {
        guard UserDefaults.standard.bool(forKey: Constants.UserDefaultsKey.hasLaunchedBefore),
              !isLaunchedAsLoginItem
        else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            Task { @MainActor in
                guard let self, self.onboardingWindow == nil else { return }
                self.openPopover()
            }
        }
    }

    /// Show Settings → About on manual launch (Spotlight/Finder) when onboarding is already done.
    /// Skipped for login-item launches to avoid intrusive windows on system startup.
    private func showSettingsIfManualLaunch() {
        guard UserDefaults.standard.bool(forKey: Constants.UserDefaultsKey.hasLaunchedBefore),
              !isLaunchedAsLoginItem
        else { return }
        openSettingsOnAboutTab()
    }

    /// Detect if the app was launched as a login item (SMAppService) via Apple Events.
    private var isLaunchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              let propData = event.paramDescriptor(forKeyword: keyAEPropData)
        else { return false }
        return propData.enumCodeValue == UInt32(keyAELaunchedAsLogInItem)
    }

    // MARK: - First-launch onboarding

    private func checkFirstLaunch() {
        guard !UserDefaults.standard.bool(forKey: Constants.UserDefaultsKey.hasLaunchedBefore) else { return }
        showOnboarding()
    }

    private func showOnboarding() {
        let view = OnboardingView { [weak self] in
            // Mark onboarding complete and reset step for potential future runs
            UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKey.hasLaunchedBefore)
            UserDefaults.standard.set(0, forKey: Constants.UserDefaultsKey.onboardingStep)
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
        }
        let controller = NSHostingController(rootView: LocaleWrapper { view })
        let window = NSWindow(contentViewController: controller)
        window.title = String(localized: "Welcome to HotLingo", locale: effectiveLocale)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.setFrame(NSRect(origin: .zero, size: NSSize(width: 760, height: 640)), display: false)
        window.minSize = NSSize(width: 760, height: 640)
        window.maxSize = NSSize(width: 760, height: 640)
        configureOnboardingWindowChrome(window)
        centerOnMainScreen(window)
        window.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else { return }
            self.positionOnboardingTrafficButtons(in: window)
            window.standardWindowButton(.zoomButton)?.isEnabled = false
        }
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }

    private func configureOnboardingWindowChrome(_ window: NSWindow) {
        guard let frameView = window.contentView?.superview else { return }

        frameView.wantsLayer = true
        frameView.layer?.cornerRadius = 24
        frameView.layer?.cornerCurve = .continuous
        frameView.layer?.masksToBounds = true

        let effectView = NSVisualEffectView(frame: frameView.bounds)
        effectView.autoresizingMask = [.width, .height]
        effectView.blendingMode = .behindWindow
        effectView.material = .hudWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 24
        effectView.layer?.cornerCurve = .continuous
        effectView.layer?.masksToBounds = true
        frameView.addSubview(effectView, positioned: .below, relativeTo: nil)
    }

    private func centerOnMainScreen(_ window: NSWindow) {
        guard let frame = NSScreen.main?.visibleFrame else {
            window.center()
            return
        }
        let size = window.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2
        )
        window.setFrameOrigin(origin)
    }

    private func positionOnboardingTrafficButtons(in window: NSWindow) {
        for (index, type) in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].enumerated() {
            guard let button = window.standardWindowButton(type) else { continue }
            var frame = button.frame
            let superHeight = button.superview?.bounds.height ?? window.frame.height
            frame.origin.x = 24 + CGFloat(index) * 22
            frame.origin.y = superHeight - frame.height - 20
            button.setFrameOrigin(frame.origin)
        }
    }

    // MARK: - Smoke test (DEBUG only)

    #if DEBUG
    private func runTranslationSmokeTest() {
        let cases = [
            "Tôi muốn đặt lịch hẹn với khách hàng vào thứ Hai",
            "Hello, can we reschedule our meeting to next week?",
        ]
        Task { @MainActor in
            let service = TranslationService()
            for text in cases {
                do {
                    let result = try await service.translate(text)
                    print("[\(result.sourceLanguage.rawValue)→\(result.targetLanguage.rawValue)] \(result.sourceText)")
                    print("  → \(result.translatedText)\n")
                } catch {
                    print("Translation error: \(error.localizedDescription)\n")
                }
            }
        }
    }
    #endif
}


private final class QuickTranslatePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
