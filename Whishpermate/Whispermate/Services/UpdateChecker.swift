import Foundation
internal import Combine
import AppKit

// MARK: - GitHub Release Models
struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let publishedAt: String
    let htmlUrl: String
    let body: String
    let draft: Bool
    let prerelease: Bool
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case publishedAt = "published_at"
        case htmlUrl = "html_url"
        case body
        case draft
        case prerelease
        case assets
    }

    var version: String {
        // Remove 'v' prefix if present
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }

    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: publishedAt) else {
            return publishedAt
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        return displayFormatter.string(from: date)
    }
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let size: Int
    let contentType: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
        case contentType = "content_type"
    }
}

// MARK: - Update Info
struct UpdateInfo {
    let currentVersion: String
    let latestRelease: GitHubRelease
    let isUpdateAvailable: Bool

    var dmgAsset: GitHubAsset? {
        latestRelease.assets.first { $0.name.hasSuffix(".dmg") }
    }
}

// MARK: - Update Checker
@MainActor
class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var updateInfo: UpdateInfo?
    @Published var isCheckingForUpdates = false
    @Published var lastCheckDate: Date?
    @Published var checkError: String?

    private let githubRepoOwner = "writingmate"
    private let githubRepoName = "whispermate"
    private let releasesURL = "https://api.github.com/repos/writingmate/whispermate/releases"

    private init() {}

    // MARK: - Public Methods

    /// Check for updates from GitHub releases
    func checkForUpdates(showAlertIfNoUpdate: Bool = false) async {
        guard !isCheckingForUpdates else { return }

        isCheckingForUpdates = true
        checkError = nil

        defer {
            isCheckingForUpdates = false
            lastCheckDate = Date()
        }

        do {
            let currentVersion = getCurrentVersion()
            let latestRelease = try await fetchLatestRelease()

            // Skip draft and prerelease versions
            guard !latestRelease.draft && !latestRelease.prerelease else {
                DebugLog.info("Skipping draft or prerelease version", context: "UpdateChecker")
                return
            }

            let isUpdateAvailable = isNewerVersion(latestRelease.version, than: currentVersion)

            updateInfo = UpdateInfo(
                currentVersion: currentVersion,
                latestRelease: latestRelease,
                isUpdateAvailable: isUpdateAvailable
            )

            DebugLog.info("Update check complete - Current: \(currentVersion), Latest: \(latestRelease.version), Update available: \(isUpdateAvailable)", context: "UpdateChecker")

            if isUpdateAvailable {
                showUpdateNotification()
            } else if showAlertIfNoUpdate {
                showNoUpdateAlert()
            }

        } catch {
            checkError = error.localizedDescription
            DebugLog.info("Error checking for updates: \(error.localizedDescription)", context: "UpdateChecker")

            if showAlertIfNoUpdate {
                showErrorAlert(error)
            }
        }
    }

    // MARK: - Private Methods

    private func getCurrentVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "0.0.0"
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        guard let url = URL(string: releasesURL) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            throw URLError(.init(rawValue: httpResponse.statusCode))
        }

        let releases = try JSONDecoder().decode([GitHubRelease].self, from: data)

        // Get the first non-draft, non-prerelease version
        guard let latestRelease = releases.first(where: { !$0.draft && !$0.prerelease }) else {
            throw NSError(domain: "UpdateChecker", code: 1, userInfo: [NSLocalizedDescriptionKey: "No stable releases found"])
        }

        return latestRelease
    }

    private func isNewerVersion(_ version1: String, than version2: String) -> Bool {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(v1Components.count, v2Components.count)

        for i in 0..<maxLength {
            let v1Component = i < v1Components.count ? v1Components[i] : 0
            let v2Component = i < v2Components.count ? v2Components[i] : 0

            if v1Component > v2Component {
                return true
            } else if v1Component < v2Component {
                return false
            }
        }

        return false
    }

    private func showUpdateNotification() {
        guard let updateInfo = updateInfo else { return }

        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = """
        A new version of WhisperMate is available!

        Current version: \(updateInfo.currentVersion)
        Latest version: \(updateInfo.latestRelease.version)

        Release date: \(updateInfo.latestRelease.formattedDate)

        \(updateInfo.latestRelease.body.isEmpty ? "" : "What's new:\n\(updateInfo.latestRelease.body)")
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            openDownloadPage()
        }
    }

    private func showNoUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = "You're up to date!"
        alert.informativeText = "WhisperMate \(getCurrentVersion()) is the latest version."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showErrorAlert(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Update Check Failed"
        alert.informativeText = "Unable to check for updates: \(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func openDownloadPage() {
        guard let updateInfo = updateInfo else { return }

        // Prefer direct DMG download if available, otherwise open releases page
        if let dmgAsset = updateInfo.dmgAsset,
           let url = URL(string: dmgAsset.browserDownloadUrl) {
            NSWorkspace.shared.open(url)
        } else if let url = URL(string: updateInfo.latestRelease.htmlUrl) {
            NSWorkspace.shared.open(url)
        }
    }
}
