import SwiftUI

/// First-launch setup flow: permissions, language, provider choice.
struct OnboardingView: View {
    let onDismiss: () -> Void
    @AppStorage(Constants.UserDefaultsKey.onboardingStep) private var step = 0

    private let steps = ["Permissions", "Language", "Setup"]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header

                ZStack {
                    switch step {
                    case 0: OnboardingPermissionsStep()
                    case 1: OnboardingLanguageStep()
                    default: OnboardingProviderStep()
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
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FastTranslate")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Quick setup for menu bar translation")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 310, alignment: .leading)

            Spacer()

            HStack(spacing: 8) {
                ForEach(steps.indices, id: \.self) { index in
                    StepPill(
                        title: steps[index],
                        index: index + 1,
                        isActive: index == step,
                        isComplete: index < step
                    )
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button("Back") { step -= 1 }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
            }

            Spacer()

            Button(step < 2 ? "Continue" : "Start Using FastTranslate") {
                if step < 2 { step += 1 } else { onDismiss() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}
