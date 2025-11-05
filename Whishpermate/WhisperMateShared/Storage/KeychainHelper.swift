import Foundation
import Security

public struct KeychainHelper {
    // Use a consistent service identifier for the app
    private static let service = "com.whispermate.app"

    // App Group identifier for sharing between app and keyboard extension
    private static let accessGroup = "group.com.whispermate.shared"

    // Migrate old keychain items (without service identifier) to new format
    public static func migrateIfNeeded(key: String) {
        // Try to get old format (without service identifier)
        let oldQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(oldQuery as CFDictionary, &dataTypeRef)

        if status == errSecSuccess, let data = dataTypeRef as? Data, let value = String(data: data, encoding: .utf8) {
            DebugLog.info("Migrating keychain item '\(key)' to new format", context: "KeychainHelper")
            // Delete old item
            SecItemDelete(oldQuery as CFDictionary)
            // Save in new format
            save(key: key, value: value)
        }
    }

    public static func save(key: String, value: String) {
        let data = value.data(using: .utf8)!

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Add access group for iOS to enable sharing between app and keyboard extension
        #if os(iOS)
        query[kSecAttrAccessGroup as String] = accessGroup
        #endif

        // Delete any existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            DebugLog.info("Error saving to keychain: \(status)", context: "KeychainHelper")
        } else {
            DebugLog.info("Successfully saved '\(key)' to keychain", context: "KeychainHelper")
        }
    }

    public static func get(key: String) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        // Add access group for iOS
        #if os(iOS)
        query[kSecAttrAccessGroup as String] = accessGroup
        #endif

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess {
            if let data = dataTypeRef as? Data {
                return String(data: data, encoding: .utf8)
            }
        } else if status != errSecItemNotFound {
            DebugLog.info("Error reading from keychain: \(status)", context: "KeychainHelper")
        }

        return nil
    }

    public static func delete(key: String) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        // Add access group for iOS
        #if os(iOS)
        query[kSecAttrAccessGroup as String] = accessGroup
        #endif

        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess {
            DebugLog.info("Successfully deleted '\(key)' from keychain", context: "KeychainHelper")
        } else if status != errSecItemNotFound {
            DebugLog.info("Error deleting from keychain: \(status)", context: "KeychainHelper")
        }
    }
}