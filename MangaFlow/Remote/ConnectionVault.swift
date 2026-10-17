import Foundation
import Security

enum ConnectionVault {
    private static let service = "fr.yannick.mangaflow.remote"
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: "paired-server"]
    }
    static func load() throws -> ServerConnection? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw failure }
        return try JSONDecoder().decode(ServerConnection.self, from: data)
    }
    static func save(_ connection: ServerConnection) throws {
        let data = try JSONEncoder().encode(connection)
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            guard SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil) == errSecSuccess else { throw failure }
        } else if status != errSecSuccess { throw failure }
    }
    static func clear() { SecItemDelete(query as CFDictionary) }
    private static var failure: RemoteFailure { .init(code: "keychain_failed", message: "Impossible d’accéder au trousseau de cet appareil.") }
}
