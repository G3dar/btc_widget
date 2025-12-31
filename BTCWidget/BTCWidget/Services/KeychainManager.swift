import Foundation
import Security

@MainActor
class KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.3dar.BTCWidget"
    private let apiKeyAccount = "binance_api_key"
    private let secretKeyAccount = "binance_secret_key"

    private init() {}

    // MARK: - Public Methods

    func hasCredentials() -> Bool {
        return getAPIKey() != nil && getSecretKey() != nil
    }

    func saveAPIKey(_ key: String) -> Bool {
        // Trim whitespace that might be accidentally pasted
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return save(key: trimmedKey, account: apiKeyAccount)
    }

    func saveSecretKey(_ key: String) -> Bool {
        // Trim whitespace that might be accidentally pasted
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return save(key: trimmedKey, account: secretKeyAccount)
    }

    func getAPIKey() -> String? {
        return get(account: apiKeyAccount)
    }

    func getSecretKey() -> String? {
        return get(account: secretKeyAccount)
    }

    func deleteCredentials() {
        delete(account: apiKeyAccount)
        delete(account: secretKeyAccount)
    }

    // MARK: - Private Keychain Operations

    private func save(key: String, account: String) -> Bool {
        // First delete any existing item
        delete(account: account)

        guard let data = key.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}
