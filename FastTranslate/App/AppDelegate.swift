import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        setupEventMonitor()
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
        popover.contentSize = NSSize(width: Constants.UI.popoverWidth, height: Constants.UI.popoverHeight)
        popover.behavior = .transient
        // Placeholder view — replaced in Phase 3
        popover.contentViewController = NSHostingController(
            rootView: Text("FastTranslate — Phase 3 will add the full UI")
                .padding()
        )
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
