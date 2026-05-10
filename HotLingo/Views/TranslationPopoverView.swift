import SwiftUI
import AppKit

struct TranslationPopoverView: View {
    @StateObject private var service = TranslationService()
    @ObservedObject private var creditService = CreditService.shared
    @AppStorage(Constants.UserDefaultsKey.defaultTargetLanguage) private var defaultTargetLanguage = Language.vietnamese.rawValue
    @State private var inputText = ""
    @State private var showContext = false
    @State private var contextText = ""
    @State private var errorMessage: String?

    private let popoverWidth: CGFloat = 380
    private let compactHeight: CGFloat = 340
    private let expandedHeight: CGFloat = 420
    private let outerPadding: CGFloat = 18
    private let popoverShape = RoundedRectangle(cornerRadius: 26, style: .continuous)

    private var isCreditError: Bool {
        errorMessage?.contains("Out of credits") == true
    }

    var body: some View {
        popoverContainer {
            VStack(alignment: .leading, spacing: 12) {
                headerBar
                if showContext { contextEditor }
                inputEditor
                outputDisplay
                if SupabaseAuthService.shared.authState.isLoggedIn && (creditService.balance < 10 || isCreditError) {
                    creditWarningBar
                }
                Spacer(minLength: 0)
                footerBar
            }
            .padding(outerPadding)
        }
        .frame(width: popoverWidth, height: showContext ? expandedHeight : compactHeight)
        .clipShape(popoverShape)
        .contentShape(popoverShape)
        .task { await CreditService.shared.fetchBalance() }
    }

    // MARK: - Credit Warning

    private var creditWarningBar: some View {
        let isOut = creditService.balance == 0 || isCreditError
        return Button {
            NotificationCenter.default.post(name: .openAccountTab, object: nil)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOut ? "creditcard.trianglebadge.exclamationmark" : "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(isOut ? Color.red : Color.orange)
                Text(isOut
                    ? String(localized: "Out of credits")
                    : String(localized: "credits.low \(creditService.balance)"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isOut ? AnyShapeStyle(Color.red) : AnyShapeStyle(Color.primary.opacity(0.7)))
                Spacer()
                Text("Top Up →")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isOut ? Color.red.opacity(0.08) : Color.orange.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Error Display

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 10) {
            Text(languageLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if showCreditBalance {
                HStack(spacing: 3) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 9, weight: .medium))
                    Text("\(creditService.balance)")
                        .font(.caption2.monospacedDigit())
                }
                .foregroundStyle(.secondary.opacity(0.6))
            }

            Spacer()

            targetLanguageMenu
        }
    }

    private var showCreditBalance: Bool {
        errorMessage == nil
            && service.activeProviderType == .aiTranslation
            && SupabaseAuthService.shared.authState.isLoggedIn
            && creditService.balance >= 10
    }

    private var languageLabel: String {
        guard let last = service.lastResult else { return String(localized: "Auto Detect") }
        return "\(last.sourceLanguage.displayName) -> \(last.targetLanguage.displayName)"
    }

    private var selectedTargetLanguage: Language {
        Language(rawValue: defaultTargetLanguage) ?? .vietnamese
    }

    // MARK: - Context editor

    private var contextEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Context")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            textBox(text: $contextText, height: 58, placeholder: "Add context for better translation...")
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Input

    private var inputEditor: some View {
        textBox(text: $inputText, height: showContext ? 76 : 92, placeholder: "Enter text to translate...") {
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
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.background.opacity(0.42), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.primary.opacity(0.10), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Output

    private var outputDisplay: some View {
        ZStack {
            if service.isTranslating {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("Translating...")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13, weight: .medium))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if let result = service.lastResult {
                ScrollView {
                    Text(result.translatedText)
                        .font(.system(size: 14))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            } else {
                Text("Translation will appear here")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background.opacity(0.32), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 8) {
            popoverActionButton("Copy", systemImage: "doc.on.doc", isProminent: true, isDisabled: service.lastResult == nil) {
                copyTranslation()
            }

            popoverActionButton(showContext ? String(localized: "Hide") : String(localized: "Context"), systemImage: "text.bubble") {
                toggleContext()
            }

            popoverActionButton("History", systemImage: "clock") {
                openHistoryWindow()
            }

            Spacer(minLength: 0)

            popoverIconButton(systemImage: "xmark.circle", label: "Clear") {
                clearAll()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 34)
    }

    private var targetLanguageMenu: some View {
        Menu {
            ForEach(Language.targetOptions) { language in
                Button(language.displayName) { defaultTargetLanguage = language.rawValue }
            }
        } label: {
            Text(selectedTargetLanguage.shortName)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .modifier(PopoverGlassCapsuleModifier())
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private func popoverActionButton(
        _ title: String,
        systemImage: String,
        isProminent: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(.primary.opacity(isDisabled ? 0.36 : 0.88))
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background {
                if isProminent {
                    Capsule(style: .continuous).fill(.primary.opacity(0.06))
                }
            }
            .modifier(PopoverGlassCapsuleModifier())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private func popoverIconButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(.secondary)
            .frame(height: 34)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func popoverContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 0) {
                content()
                    .background(.clear)
                    .glassEffect(.regular, in: popoverShape)
                    .clipShape(popoverShape)
                    .overlay {
                        popoverShape.stroke(.primary.opacity(0.08), lineWidth: 1)
                    }
            }
        } else {
            content()
                .background(.regularMaterial)
                .clipShape(popoverShape)
                .overlay {
                    popoverShape.stroke(.primary.opacity(0.10), lineWidth: 1)
                }
        }
    }

    private func openHistoryWindow() {
        let appLanguageRaw = UserDefaults.standard.string(forKey: Constants.UserDefaultsKey.appLanguage) ?? Constants.AppLanguage.system.rawValue
        let locale = Constants.AppLanguage(rawValue: appLanguageRaw)?.locale ?? Locale.current
        let controller = NSHostingController(rootView: LocaleWrapper { HistoryView() })
        let window = NSWindow(contentViewController: controller)
        window.title = String(localized: "Translation History", locale: locale)
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
                let result = try await service.translate(
                    text,
                    targetLanguage: selectedTargetLanguage,
                    perMessageContext: ctx.isEmpty ? nil : ctx
                )
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

private struct PopoverGlassCapsuleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        } else {
            content
                .background(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(.primary.opacity(0.12), lineWidth: 1)
                }
                .clipShape(Capsule(style: .continuous))
        }
    }
}
