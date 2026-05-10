import Foundation
import IOKit

enum DeviceIdentifier {
    private static let fallbackKey = "device_identifier_fallback"

    static var platformUUID: String {
        // Prefer hardware UUID — immutable across reinstalls
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        defer { IOObjectRelease(service) }
        if let uuid = IORegistryEntryCreateCFProperty(
            service,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? String {
            return uuid
        }
        // Fallback: persist to UserDefaults so the same ID is reused across calls
        if let saved = UserDefaults.standard.string(forKey: fallbackKey) {
            return saved
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: fallbackKey)
        return generated
    }
}
