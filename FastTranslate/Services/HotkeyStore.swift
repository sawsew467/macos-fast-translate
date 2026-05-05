import Combine
import Carbon.HIToolbox

/// Reads/writes custom hotkey bindings from UserDefaults and publishes changes.
final class HotkeyStore: ObservableObject {
    static let shared = HotkeyStore()

    @Published var translateBinding: HotkeyBinding
    @Published var screenshotBinding: HotkeyBinding

    /// Non-nil when the last re-registration failed for an action.
    @Published var registrationError: (action: HotkeyAction, message: String)?

    private let defaults = UserDefaults.standard

    private init() {
        translateBinding = Self.loadBinding(
            action: .translate,
            from: UserDefaults.standard
        )
        screenshotBinding = Self.loadBinding(
            action: .screenshot,
            from: UserDefaults.standard
        )
    }

    // MARK: - Read

    private static func loadBinding(action: HotkeyAction, from defaults: UserDefaults) -> HotkeyBinding {
        let (keyCodeKey, modifiersKey) = userDefaultsKeys(for: action)
        guard defaults.object(forKey: keyCodeKey) != nil else {
            return action.defaultBinding
        }
        let keyCode   = UInt32(defaults.integer(forKey: keyCodeKey))
        let modifiers = UInt32(defaults.integer(forKey: modifiersKey))
        return HotkeyBinding(keyCode: keyCode, modifiers: modifiers)
    }

    // MARK: - Write

    func save(_ binding: HotkeyBinding, for action: HotkeyAction) {
        let (keyCodeKey, modifiersKey) = Self.userDefaultsKeys(for: action)
        defaults.set(Int(binding.keyCode), forKey: keyCodeKey)
        defaults.set(Int(binding.modifiers), forKey: modifiersKey)

        switch action {
        case .translate:  translateBinding = binding
        case .screenshot: screenshotBinding = binding
        }
        registrationError = nil
    }

    func resetToDefaults() {
        save(.defaultTranslate, for: .translate)
        save(.defaultScreenshot, for: .screenshot)
    }

    // MARK: - Duplicate detection

    /// Returns the other action if `binding` duplicates it, or nil.
    func duplicateAction(for binding: HotkeyBinding, excluding action: HotkeyAction) -> HotkeyAction? {
        let other: HotkeyBinding
        let otherAction: HotkeyAction
        switch action {
        case .translate:
            other = screenshotBinding
            otherAction = .screenshot
        case .screenshot:
            other = translateBinding
            otherAction = .translate
        }
        return (binding == other) ? otherAction : nil
    }

    // MARK: - Helpers

    private static func userDefaultsKeys(for action: HotkeyAction) -> (keyCode: String, modifiers: String) {
        switch action {
        case .translate:
            return (Constants.UserDefaultsKey.translateHotkeyKeyCode,
                    Constants.UserDefaultsKey.translateHotkeyModifiers)
        case .screenshot:
            return (Constants.UserDefaultsKey.screenshotHotkeyKeyCode,
                    Constants.UserDefaultsKey.screenshotHotkeyModifiers)
        }
    }
}
