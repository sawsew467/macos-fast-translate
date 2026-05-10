import AppKit
import Foundation

// MARK: - GitHub API model

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlUrl: String
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case assets
    }

    struct Asset: Decodable {
        let name: String
        let browserDownloadUrl: String

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadUrl = "browser_download_url"
        }
    }

    /// Returns the first .zip asset, if any.
    var zipAsset: Asset? {
        assets.first { $0.name.hasSuffix(".zip") }
    }
}

// MARK: - UpdateService

@MainActor
final class UpdateService: ObservableObject {
    static let shared = UpdateService()

    enum CheckState: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String)
        case installing
        case error(String)
    }

    @Published var state: CheckState = .idle

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private let owner = "sawsew467"
    private let repo = "macos-fast-translate"
    private var releasePageURL: URL?

    private init() {}

    // MARK: - Public API

    /// Silent check on launch; no UI feedback if up-to-date.
    func checkOnLaunch() {
        Task { await performCheck(silent: true) }
    }

    /// Explicit check from UI; always shows result.
    func checkForUpdates() {
        Task { await performCheck(silent: false) }
    }

    /// Download the ZIP asset and replace the running app, then relaunch.
    /// Falls back to opening the browser if download/install fails.
    func installUpdate() {
        guard case .available(let version) = state else { return }
        Task { await performInstall(version: version) }
    }

    /// Open the GitHub Releases page for the latest version.
    func openReleasePage() {
        guard let url = releasePageURL else {
            NSWorkspace.shared.open(
                URL(string: "https://github.com/\(owner)/\(repo)/releases/latest")!
            )
            return
        }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Private implementation

    private func performCheck(silent: Bool) async {
        state = .checking
        do {
            let release = try await fetchLatestRelease()
            let remote = normalizeVersion(release.tagName)
            releasePageURL = URL(string: release.htmlUrl)
            if isNewer(remote, than: currentVersion) {
                state = .available(version: remote)
            } else {
                state = silent ? .idle : .upToDate
            }
        } catch {
            state = silent ? .idle : .error(error.localizedDescription)
        }
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("HotLingo/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    private func performInstall(version: String) async {
        state = .installing
        do {
            let release = try await fetchLatestRelease()
            guard let asset = release.zipAsset,
                  let downloadURL = URL(string: asset.browserDownloadUrl) else {
                throw UpdateError.noZipAsset
            }
            let zipURL = try await downloadAsset(url: downloadURL)
            try replaceAndRelaunch(zipURL: zipURL)
        } catch {
            // Fall back to browser
            state = .available(version: version)
            openReleasePage()
        }
    }

    private func downloadAsset(url: URL) async throws -> URL {
        let (tempURL, _) = try await URLSession.shared.download(from: url)
        // Move to a stable temp path with .zip extension
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(
            "HotLingo-update.zip"
        )
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tempURL, to: dest)
        return dest
    }

    private func replaceAndRelaunch(zipURL: URL) throws {
        let appURL = Bundle.main.bundleURL
        let appDir = appURL.deletingLastPathComponent()
        let appName = appURL.lastPathComponent // "HotLingo.app"
        let tmpExtractDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HotLingo-update-extracted")

        // Extract zip to tmp directory
        try? FileManager.default.removeItem(at: tmpExtractDir)
        try FileManager.default.createDirectory(at: tmpExtractDir, withIntermediateDirectories: true)

        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzip.arguments = ["-q", zipURL.path, "-d", tmpExtractDir.path]
        try unzip.run()
        unzip.waitUntilExit()
        guard unzip.terminationStatus == 0 else {
            throw UpdateError.extractionFailed
        }

        // Find the .app inside the extracted directory
        let extracted = try FileManager.default.contentsOfDirectory(
            at: tmpExtractDir, includingPropertiesForKeys: nil
        ).first { $0.lastPathComponent == appName }

        guard let newAppURL = extracted else {
            throw UpdateError.appNotFoundInZip
        }

        // Launch a short shell script to replace app and relaunch after current process exits
        let destAppPath = appDir.appendingPathComponent(appName).path
        let script = """
        #!/bin/bash
        sleep 1
        rm -rf \(shellEscape(destAppPath))
        mv \(shellEscape(newAppURL.path)) \(shellEscape(destAppPath))
        open \(shellEscape(destAppPath))
        """
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HotLingo-updater.sh")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let launcher = Process()
        launcher.executableURL = URL(fileURLWithPath: "/bin/bash")
        launcher.arguments = [scriptURL.path]
        try launcher.run()

        NSApp.terminate(nil)
    }

    private func shellEscape(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: - Version comparison

    private func normalizeVersion(_ tag: String) -> String {
        tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    private func isNewer(_ remote: String, than current: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let c = current.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, c.count) {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv > cv { return true }
            if rv < cv { return false }
        }
        return false
    }
}

// MARK: - Errors

private enum UpdateError: LocalizedError {
    case noZipAsset
    case extractionFailed
    case appNotFoundInZip

    var errorDescription: String? {
        switch self {
        case .noZipAsset: return "No .zip asset found in the latest release."
        case .extractionFailed: return "Failed to extract the update archive."
        case .appNotFoundInZip: return "HotLingo.app not found in the downloaded archive."
        }
    }
}
