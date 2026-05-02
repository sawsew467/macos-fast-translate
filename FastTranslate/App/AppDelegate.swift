import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: Any?
    var floatingPanel = FloatingPanelController()
    private var hotkeyManager: HotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        setupEventMonitor()
        setupHotkeys()
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
        button.action = #selector(togglePopover)
        button.target = self
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 340)
        popover.behavior = .transient
        let popoverView = TranslationPopoverView { [weak self] result in
            guard let self else { return }
            let mousePoint = NSEvent.mouseLocation
            self.floatingPanel.show(result: result, near: mousePoint)
        }
        popover.contentViewController = NSHostingController(rootView: popoverView)
    }

    private func setupHotkeys() {
        // Prompt for Accessibility permission if not yet granted.
        // Required so CGEvent.post() can simulate ⌘+C to read selected text.
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

    /// Close popover on any click outside it
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            self.closePopover()
        }
    }

    // MARK: - Popover control

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func closePopover() {
        popover.performClose(nil)
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
