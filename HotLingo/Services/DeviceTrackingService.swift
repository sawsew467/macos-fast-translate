import Foundation

/// Tracks macOS device installs in Supabase via hardware UUID.
/// All network calls are fire-and-forget — errors are silently ignored.
actor DeviceTrackingService {
    static let shared = DeviceTrackingService()

    // MARK: - Request bodies

    private struct UpsertBody: Encodable {
        let p_hardware_uuid: String
        let p_is_new_install: Bool
        let p_app_version: String?
        let p_os_version: String?
    }

    private struct LinkBody: Encodable {
        let p_hardware_uuid: String
    }

    // MARK: - Public API

    /// Call once per app launch from applicationDidFinishLaunching.
    /// Increments install_count only when UserDefaults flag is absent
    /// (fresh install or post-uninstall reinstall).
    func trackLaunch() async {
        let uuid = DeviceIdentifier.platformUUID
        let isNewInstall = !UserDefaults.standard.bool(
            forKey: Constants.UserDefaultsKey.deviceInstallTracked
        )

        let body = UpsertBody(
            p_hardware_uuid: uuid,
            p_is_new_install: isNewInstall,
            p_app_version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            p_os_version: ProcessInfo.processInfo.operatingSystemVersionString
        )

        do {
            _ = try await SupabaseClient.shared.requestRaw(
                endpoint: "/rest/v1/rpc/upsert_device_install",
                method: "POST",
                body: body,
                authenticated: false
            )
            if isNewInstall {
                UserDefaults.standard.set(
                    true,
                    forKey: Constants.UserDefaultsKey.deviceInstallTracked
                )
            }
        } catch {
            // Non-critical — never block app startup
        }
    }

    /// Call after successful login to link this device to the authenticated user.
    /// user_id is resolved server-side from auth.uid() — client never sends it.
    func linkToUser() async {
        let uuid = DeviceIdentifier.platformUUID
        do {
            _ = try await SupabaseClient.shared.requestRaw(
                endpoint: "/rest/v1/rpc/link_device_to_user",
                method: "POST",
                body: LinkBody(p_hardware_uuid: uuid),
                authenticated: true
            )
        } catch {
            // Non-critical
        }
    }
}
