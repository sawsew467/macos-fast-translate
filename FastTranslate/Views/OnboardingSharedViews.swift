import SwiftUI

// MARK: - LiquidGlass modifiers

struct LiquidGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
                .shadow(color: .black.opacity(0.10), radius: 28, x: 0, y: 16)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay { shape.stroke(.white.opacity(0.70), lineWidth: 1) }
                .overlay { shape.stroke(.primary.opacity(0.08), lineWidth: 1) }
                .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 14)
        }
    }
}

struct LiquidGlassCapsuleModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        let shape = Capsule(style: .continuous)
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay { shape.stroke(.white.opacity(0.65), lineWidth: 1) }
                .overlay { shape.stroke(.primary.opacity(isActive ? 0.16 : 0.07), lineWidth: 1) }
        }
    }
}

// MARK: - StepPill

struct StepPill: View {
    let title: String
    let index: Int
    let isActive: Bool
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().fill(isComplete ? Color.green : (isActive ? Color.accentColor : Color.secondary.opacity(0.18)))
                if isComplete {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                } else {
                    Text("\(index)").font(.system(size: 10, weight: .bold)).foregroundStyle(isActive ? .white : .secondary)
                }
            }
            .frame(width: 18, height: 18)

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isActive ? .primary : .secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 10)
        .frame(minWidth: 94)
        .frame(height: 30)
        .modifier(LiquidGlassCapsuleModifier(isActive: isActive))
    }
}

// MARK: - SetupCard

struct SetupCard<Content: View>: View {
    let systemImage: String
    let tint: Color
    let title: String
    let subtitle: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 72, height: 72)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(spacing: 6) {
                Text(title).font(.system(size: 24, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content()
                .frame(maxWidth: 430)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .modifier(LiquidGlassCardModifier(cornerRadius: 24))
    }
}

// MARK: - ProviderOptionCard

struct ProviderOptionCard: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let badge: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .frame(width: 40, height: 40)
                    .background(isSelected ? Color.blue.opacity(0.12) : Color.secondary.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title).font(.system(size: 14, weight: .semibold))
                        if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue, in: Capsule())
                        }
                    }
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? .blue : .secondary.opacity(0.4))
            }
            .padding(14)
            .background(.background.opacity(isSelected ? 0.70 : 0.40),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.blue.opacity(0.30) : Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PermissionRow

struct PermissionRow: View {
    let title: String
    let detail: String
    let isGranted: Bool
    let settingsURL: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(isGranted ? Color.green : Color.orange)
                .font(.system(size: 20, weight: .semibold))

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .bold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            if isGranted {
                Text("Granted").font(.caption.weight(.semibold)).foregroundStyle(.green)
            } else {
                Button("Open Settings") {
                    NSWorkspace.shared.open(URL(string: settingsURL)!)
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
        .padding(12)
        .background(.background.opacity(0.50), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

// MARK: - HotkeyBadgeRow

struct HotkeyBadgeRow: View {
    let hotkey: String
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            Text(hotkey)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(width: 86, height: 30)
                .background(.background.opacity(0.62), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.primary.opacity(0.10), lineWidth: 1) }
            Text(label).font(.system(size: 13, weight: .medium))
            Spacer()
        }
        .padding(12)
        .background(.background.opacity(0.38), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
