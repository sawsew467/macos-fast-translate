import SwiftUI
import AppKit

struct TranslationPopoverView: View {
    @StateObject private var service = TranslationService()
    @State private var inputText = ""
    @State private var showContext = false
    @State private var contextText = ""
    @State private var errorMessage: String?

    // Injected by AppDelegate for floating panel callback
    var onShowFloating: ((TranslationResult) -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            headerBar
            if showContext { contextEditor }
            inputEditor
            outputDisplay
            footerBar
        }
        .padding(12)
        .frame(width: 380, height: showContext ? 420 : 340)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text(languageLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var languageLabel: String {
        guard let last = service.lastResult else { return "Vi ↔ En" }
        return "\(last.sourceLanguage.displayName) → \(last.targetLanguage.displayName)"
    }

    // MARK: - Context editor

    private var contextEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Context")
                .font(.caption)
                .foregroundStyle(.secondary)
            textBox(text: $contextText, height: 60, placeholder: "Add context for better translation…")
        }
    }

    // MARK: - Input

    private var inputEditor: some View {
        textBox(text: $inputText, height: 80, placeholder: "Enter text to translate…") {
            triggerTranslation()
        }
    }

    /// Reusable text box with placeholder backed by NSTextView (correct cursor alignment, no scrollbar).
    @ViewBuilder
    private func textBox(
        text: Binding<String>,
        height: CGFloat,
        placeholder: String,
        onEnter: (() -> Void)? = nil
    ) -> some View {
        MultilineTextField(text: text, placeholder: placeholder, onEnter: onEnter)
        .frame(height: height)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }

    // MARK: - Output

    private var outputDisplay: some View {
        Group {
            if service.isTranslating {
                HStack {
                    ProgressView().scaleEffect(0.8)
                    Text("Translating…").foregroundStyle(.secondary).font(.system(size: 13))
                }
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            } else if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.system(size: 13))
                    .padding(8)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.red.opacity(0.3), lineWidth: 1))
            } else if let result = service.lastResult {
                ScrollView {
                    Text(result.translatedText)
                        .font(.system(size: 14))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(8)
                }
                .frame(height: 80)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(NSColor.separatorColor), lineWidth: 1))
            } else {
                Text("Translation will appear here")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 13))
                    .padding(8)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
            }
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 8) {
            Button(action: copyTranslation) {
                Label("Copy", systemImage: "doc.on.doc").font(.system(size: 13))
            }
            .buttonStyle(.bordered)
            .disabled(service.lastResult == nil)

            Button(action: toggleContext) {
                Label(showContext ? "Hide Context" : "Context", systemImage: "text.bubble")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)

            Button(action: openHistoryWindow) {
                Label("History", systemImage: "clock")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: clearAll) {
                Label("Clear", systemImage: "xmark.circle").font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private func openHistoryWindow() {
        let controller = NSHostingController(rootView: HistoryView())
        let window = NSWindow(contentViewController: controller)
        window.title = "Translation History"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 440, height: 440))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Actions

    private func triggerTranslation() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        errorMessage = nil
        Task {
            do {
                let ctx = contextText.trimmingCharacters(in: .whitespacesAndNewlines)
                let result = try await service.translate(text, perMessageContext: ctx.isEmpty ? nil : ctx)
                onShowFloating?(result)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func copyTranslation() {
        guard let text = service.lastResult?.translatedText else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func toggleContext() {
        withAnimation(.easeInOut(duration: 0.2)) { showContext.toggle() }
    }

    private func clearAll() {
        inputText = ""
        contextText = ""
        errorMessage = nil
    }
}

