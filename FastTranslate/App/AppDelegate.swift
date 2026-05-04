import AppKit
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
        window.styleMask = [.titled, .closable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
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
