import Foundation
import CryptoKit

// Ed25519 signing via CryptoKit. Keys are persisted in the Keychain.
// The firmware doesn't verify signatures today, but we generate and attach them
// to be forward-compatible with the web app's cipher.js.

final class CryptoManager {

    static let shared = CryptoManager()

    private let keychainKey = "com.sudoroom.DisasterRadio.signingKey"
    private var privateKey: Curve25519.Signing.PrivateKey

    var publicKeyData: Data { privateKey.publicKey.rawRepresentation }

    private init() {
        if let stored = Self.loadKey() {
            privateKey = stored
        } else {
            let key = Curve25519.Signing.PrivateKey()
            Self.saveKey(key)
            privateKey = key
        }
    }

    func sign(_ message: String) -> Data? {
        guard let data = message.data(using: .utf8) else { return nil }
        return try? privateKey.signature(for: data)
    }

    func regenerateKeys() {
        let key = Curve25519.Signing.PrivateKey()
        Self.saveKey(key)
        privateKey = key
    }

    // MARK: - Keychain helpers

    private static func loadKey() -> Curve25519.Signing.PrivateKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "signingKey",
            kSecAttrService as String: "com.sudoroom.DisasterRadio",
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return try? Curve25519.Signing.PrivateKey(rawRepresentation: data)
    }

    private static func saveKey(_ key: Curve25519.Signing.PrivateKey) {
        let data = key.rawRepresentation
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "signingKey",
            kSecAttrService as String: "com.sudoroom.DisasterRadio",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
}
