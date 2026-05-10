import SwiftUI

// MARK: - SettingsPage

struct SettingsPage<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 24, weight: .bold))
                    Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
                }
                .padding(.top, 6)
                content()
            }
            .padding(22)
        }
    }
}

// MARK: - SettingsCard

struct SettingsCard<Content: View>: View {
    let systemImage: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 30, height: 30)
                    .background(.ultraThinMaterial, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 14, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            content().padding(.leading, 42)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

// MARK: - SettingsButton

struct SettingsButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    var isPrimary = false
    let action: () -> Void

    init(_ title: LocalizedStringKey, systemImage: String, isPrimary: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isPrimary = isPrimary
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(isPrimary ? Color.primary.opacity(0.08) : Color.clear, in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous).stroke(.primary.opacity(0.10), lineWidth: 1)
        }
    }
}

// MARK: - SettingsBackground

struct SettingsBackground: View {
    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
            LinearGradient(
                colors: [.primary.opacity(0.04), .clear, .primary.opacity(0.025)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - HotkeyRecorderRow

struct HotkeyRecorderRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let action: HotkeyAction
    @Binding var binding: HotkeyBinding
    let store: HotkeyStore

    private var isDuplicate: Bool {
        store.duplicateAction(for: binding, excluding: action) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                Text(title).font(.system(size: 13, weight: .medium))
                Spacer()
                HotkeyRecorderView(binding: Binding(
                    get: { binding },
                    set: { newBinding in
                        binding = newBinding
                        store.save(newBinding, for: action)
                    }
                ))
                .frame(width: 120, height: 28)
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(.background.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if isDuplicate {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10))
                    Text("Conflicts with another shortcut").font(.system(size: 11))
                }
                .foregroundStyle(.orange)
                .padding(.leading, 44)
            }
        }
    }
}
