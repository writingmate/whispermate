import AppKit
import Foundation
import ServiceManagement
import WhisperMateShared
internal import Combine

/// Manages the launch at login functionality for WhisperMate
class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published private(set) var isEnabled: Bool = false

    private let launchAtLoginKey = "launchAtLogin"

    private init() {
        // Load initial state from UserDefaults
        isEnabled = AppDefaults.shared.bool(forKey: launchAtLoginKey)

        // Sync with actual system state if available
        if #available(macOS 13.0, *) {
            syncWithSystemState()
        }
    }

    // MARK: - Public Methods

    /// Toggle launch at login on or off
    func toggle() {
        setEnabled(!isEnabled)
    }

    /// Set launch at login to a specific state
    func setEnabled(_ enabled: Bool) {
        DebugLog.info("Setting launch at login to: \(enabled)", context: "LaunchAtLoginManager")

        if #available(macOS 13.0, *) {
            setEnabledModern(enabled)
        } else {
            setEnabledLegacy(enabled)
        }
    }

    // MARK: - Modern Implementation (macOS 13+)

    @available(macOS 13.0, *)
    private func setEnabledModern(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled {
                    DebugLog.info("Launch at login already enabled", context: "LaunchAtLoginManager")
                    updateState(enabled: true)
                } else {
                    try SMAppService.mainApp.register()
                    DebugLog.info("Successfully registered launch at login", context: "LaunchAtLoginManager")
                    updateState(enabled: true)
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    DebugLog.info("Successfully unregistered launch at login", context: "LaunchAtLoginManager")
                    updateState(enabled: false)
                } else {
                    DebugLog.info("Launch at login already disabled", context: "LaunchAtLoginManager")
                    updateState(enabled: false)
                }
            }
        } catch {
            DebugLog.error("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)", context: "LaunchAtLoginManager")
            // Keep UI state in sync even on error
            syncWithSystemState()
        }
    }

    @available(macOS 13.0, *)
    private func syncWithSystemState() {
        let status = SMAppService.mainApp.status
        let isSystemEnabled = status == .enabled

        DebugLog.info("System launch at login status: \(status.rawValue)", context: "LaunchAtLoginManager")

        if isEnabled != isSystemEnabled {
            DebugLog.info("Syncing UI state with system state: \(isSystemEnabled)", context: "LaunchAtLoginManager")
            updateState(enabled: isSystemEnabled)
        }
    }

    // MARK: - Legacy Implementation (macOS 12 and earlier)

    private func setEnabledLegacy(_ enabled: Bool) {
        // For older macOS versions, we'll use LSSharedFileList (deprecated but still works)
        // However, since this is primarily for macOS 13+, we'll just save the preference
        // and inform the user that this feature requires macOS 13+

        DebugLog.warning("Launch at login requires macOS 13 or later", context: "LaunchAtLoginManager")
        updateState(enabled: enabled)

        // Show alert to user
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "macOS 13 or Later Required"
            alert.informativeText = "Launch at login requires macOS 13 (Ventura) or later. Your preference has been saved but won't take effect until you upgrade."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    // MARK: - State Management

    private func updateState(enabled: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isEnabled = enabled
            AppDefaults.shared.set(enabled, forKey: self.launchAtLoginKey)
            DebugLog.info("Launch at login state updated: \(enabled)", context: "LaunchAtLoginManager")
        }
    }

    // MARK: - Status Check

    /// Check current launch at login status
    var currentStatus: String {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            switch status {
            case .enabled:
                return "Enabled"
            case .notRegistered:
                return "Not Registered"
            case .notFound:
                return "Not Found"
            case .requiresApproval:
                return "Requires Approval"
            @unknown default:
                return "Unknown"
            }
        } else {
            return isEnabled ? "Enabled (Preference Only)" : "Disabled"
        }
    }
}
