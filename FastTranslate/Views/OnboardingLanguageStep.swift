import SwiftUI

struct OnboardingLanguageStep: View {
    @AppStorage(Constants.UserDefaultsKey.defaultTargetLanguage)
    private var defaultTargetLanguage = Language.vietnamese.rawValue

    var body: some View {
        SetupCard(
            systemImage: "globe.asia.australia",
            tint: .blue,
            title: "Default language",
            subtitle: "Choose the language you translate to most often. You can change this anytime."
        ) {
            Picker("Target Language", selection: $defaultTargetLanguage) {
                ForEach(Language.targetOptions) { lang in
                    Text("\(lang.shortName) - \(lang.displayName)").tag(lang.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
