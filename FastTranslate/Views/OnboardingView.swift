import SwiftUI

/// First-launch setup flow: permissions, language, provider choice, shortcuts.
struct OnboardingView: View {
    let onDismiss: () -> Void
    @AppStorage(Constants.UserDefaultsKey.onboardingStep) private var step = 0

    private let steps = ["Permissions", "Language", "Setup", "Shortcuts"]
    private let lastStep = 3

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header

                ZStack {
                    switch step {
                    case 0: OnboardingPermissionsStep()
                    case 1: OnboardingLanguageStep()
                    case 2: OnboardingProviderStep()
                    default: OnboardingShortcutStep()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 34)

                navigationButtons.padding(24)
            }
            .padding(.top, 30)
        }
        .frame(width: 760, height: 640)
        .background(Color.clear)
    }

    private var header: some View {
        VStack(spacing: 12) {
            VStack(spacing: 5) {
                Text("FastTranslate")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Quick setup for menu bar translation")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { index in
                    StepPill(
                        title: steps[index],
                        index: index + 1,
                        isActive: index == step,
                        isComplete: index < step
                    )
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button("Back") { step -= 1 }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
            }

            Spacer()

            Button(step < lastStep ? "Continue" : "Start Using FastTranslate") {
                if step < lastStep { step += 1 } else { onDismiss() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}
