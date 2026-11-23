import Foundation
import Security

enum VPNKeychain {
    private static let service = "com.example.discord-drover-ios.ikev2"

    static func store(_ secret: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: UUID().uuidString,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(secret.utf8),
            kSecReturnPersistentRef as String: true,
        ]
        var result: CFTypeRef?
        let status = SecItemAdd(query as CFDictionary, &result)
        guard status == errSecSuccess, let reference = result as? Data else {
            throw KeychainError(status: status == errSecSuccess ? errSecInternalError : status)
        }
        return reference
    }

    static func remove(_ reference: Data) {
        SecItemDelete([kSecValuePersistentRef as String: reference] as CFDictionary)
    }

    struct KeychainError: LocalizedError {
        let status: OSStatus

        var errorDescription: String? {
            if status == errSecMissingEntitlement {
                return "Keychain access is unavailable. Sign the app with a provisioning profile that includes its Keychain access group and Personal VPN."
            }
            return "Could not save the VPN credential (Keychain error \(status))."
        }
    }
}
