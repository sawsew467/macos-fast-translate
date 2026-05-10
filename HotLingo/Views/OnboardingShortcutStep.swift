import SwiftUI

struct OnboardingShortcutStep: View {
    @ObservedObject private var store = HotkeyStore.shared

    var body: some View {
        SetupCard(
            systemImage: "keyboard",
            tint: .indigo,
            title: String(localized: "Two ways to translate"),
            subtitle: String(localized: "Use these shortcuts anywhere on your Mac.")
        ) {
            VStack(spacing: 12) {
                shortcutRow(
                    hotkey: store.translateBinding.displayString,
                    icon: "text.cursor",
                    title: String(localized: "Translate selected text"),
                    steps: [
                        String(localized: "Select any text in any app"),
                        String(localized: "Press the shortcut"),
                        String(localized: "Translation appears instantly")
                    ]
                )

                shortcutRow(
                    hotkey: store.screenshotBinding.displayString,
                    icon: "camera.viewfinder",
                    title: String(localized: "Screenshot & translate"),
                    steps: [
                        String(localized: "Press the shortcut"),
                        String(localized: "Draw a region on screen"),
                        String(localized: "Text is extracted and translated")
                    ]
                )
            }
        }
    }

    @ViewBuilder
    private func shortcutRow(
        hotkey: String,
        icon: String,
        title: String,
        steps: [String]
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Hotkey badge
            Text(hotkey)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(minWidth: 60, minHeight: 32)
                .padding(.horizontal, 8)
                .background(.background.opacity(0.62), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.primary.opacity(0.10), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.indigo)
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(spacing: 6) {
                            Text("\(index + 1).")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 16, alignment: .trailing)
                            Text(step)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(14)
        .background(.background.opacity(0.40), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }
}
