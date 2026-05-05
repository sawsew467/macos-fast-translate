import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: Any?
    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?
    var floatingPanel = FloatingPanelController()
    private var hotkeyManager: HotkeyManager?
    private var hotkeyCancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        migrateAPIKeyToKeychain()
        setupStatusItem()
        setupPopover()
        setupEventMonitor()
        setupHotkeys()
        checkFirstLaunch()
        #if DEBUG
        runTranslationSmokeTest()
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "FastTranslate")
        button.action = #selector(statusItemClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 340)
        popover.behavior = .transient
        let popoverView = TranslationPopoverView()
        popover.contentViewController = NSHostingController(rootView: popoverView)
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

    /// Close popover on any click outside it.
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            self.closePopover()
        }
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
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit FastTranslate", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let controller = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: controller)
            window.title = "FastTranslate Settings"
            window.styleMask = [.titled, .closable]
            window.center()
            // Clear reference when window closes
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window, queue: .main
            ) { [weak self] _ in self?.settingsWindow = nil }
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Popover control

    private func togglePopover() {
        if popover.isShown { closePopover() } else { openPopover() }
    }

    private func openPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func closePopover() {
        popover.performClose(nil)
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
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "Welcome to FastTranslate"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.setFrame(NSRect(origin: .zero, size: NSSize(width: 760, height: 570)), display: false)
        window.minSize = NSSize(width: 760, height: 570)
        window.maxSize = NSSize(width: 760, height: 570)
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
