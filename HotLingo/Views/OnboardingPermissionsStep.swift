import SwiftUI
import ApplicationServices

struct OnboardingPermissionsStep: View {
    @State private var hasAccessibility = AXIsProcessTrusted()
    @State private var hasScreenRecording = CGPreflightScreenCaptureAccess()

    var body: some View {
        SetupCard(
            systemImage: "lock.shield",
            tint: .orange,
            title: String(localized: "Grant permissions"),
            subtitle: String(localized: "macOS needs approval before HotLingo can read selected text or capture OCR screenshots.")
        ) {
            VStack(spacing: 12) {
                PermissionRow(
                    title: String(localized: "Accessibility"),
                    detail: String(localized: "Read selected text with Control + Option + T"),
                    isGranted: hasAccessibility,
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                )
                PermissionRow(
                    title: String(localized: "Screen Recording"),
                    detail: String(localized: "Capture OCR regions with Control + Option + S"),
                    isGranted: hasScreenRecording,
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
                )
            }
        }
        .onAppear {
            CGRequestScreenCaptureAccess()
            if !AXIsProcessTrusted() {
                let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                AXIsProcessTrustedWithOptions(opts)
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            hasAccessibility = AXIsProcessTrusted()
            hasScreenRecording = CGPreflightScreenCaptureAccess()
        }
    }
}
