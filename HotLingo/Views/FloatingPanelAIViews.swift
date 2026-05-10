import SwiftUI

// MARK: - AI Nudge Row

/// Small row shown below Google Translate results nudging users toward AI Translation.
struct AINudgeRow: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 11))
                    .foregroundStyle(.purple)
                Text("Try AI — 50 free translations")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.6))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Out-of-Credit Panel Content

/// Shown when AI translation fails due to zero credits.
struct OutOfCreditPanelContent: View {
    let onTopUp: () -> Void
    let onUseGoogle: () -> Void
    let onClose: () -> Void

    var body: some View {
        panelContainer {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "creditcard.trianglebadge.exclamationmark")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Out of credits")
                            .font(.system(size: 14, weight: .bold))
                        Text("Top up to continue using AI Translation")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                HStack(spacing: 8) {
                    Button("Top Up") { onTopUp() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    Button("Use Google") { onUseGoogle() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Low Credit Warning Row

/// Small row shown at the bottom of translation results when credits are running low.
struct LowCreditRow: View {
    let balance: Int
    let onTopUp: () -> Void

    private var isOut: Bool { balance == 0 }

    var body: some View {
        Button(action: onTopUp) {
            HStack(spacing: 6) {
                Image(systemName: isOut ? "creditcard.trianglebadge.exclamationmark" : "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(isOut ? Color.red : Color.orange)
                Text(isOut
                    ? String(localized: "Out of credits \u{2014} top up to keep translating")
                    : String(localized: "credits.low \(balance)"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isOut ? AnyShapeStyle(Color.red) : AnyShapeStyle(Color.primary.opacity(0.7)))
                Spacer()
                Text("Top Up →")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AI Nudge Helper

/// Stateless helpers for nudge/banner visibility logic. Must be called on the main actor.
@MainActor
enum AINudgeHelper {
    static var shouldShowNudge: Bool {
        let provider = UserDefaults.standard.string(forKey: Constants.UserDefaultsKey.defaultProvider) ?? ""
        let isGoogle = ProviderType(rawValue: provider) == .googleTranslate
        let hasSeen = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKey.hasSeenAINudgeBanner)
        let hasEverLoggedIn = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKey.hasEverLoggedIn)
        return isGoogle && !hasSeen && !hasEverLoggedIn
    }

    static var shouldShowBanner: Bool {
        let count = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKey.googleTranslateCount)
        let hasSeen = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKey.hasSeenAINudgeBanner)
        return count >= 10 && !hasSeen
    }

    static func markBannerSeen() {
        UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKey.hasSeenAINudgeBanner)
    }
}
