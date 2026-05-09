import Foundation
import IOKit

enum DeviceIdentifier {
    static var platformUUID: String {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        defer { IOObjectRelease(service) }
        guard let uuid = IORegistryEntryCreateCFProperty(
            service,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? String else {
            return UUID().uuidString // fallback
        }
        return uuid
    }
}
