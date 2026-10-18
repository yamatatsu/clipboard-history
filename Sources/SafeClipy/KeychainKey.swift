import CryptoKit
import Foundation
import Security

/// 履歴を暗号化する鍵をログインキーチェーンに置く（ADR-0004）。
enum KeychainKey {
    struct Error: Swift.Error, CustomStringConvertible {
        let status: OSStatus
        var description: String {
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown"
            return "Keychain error \(status): \(message)"
        }
    }

    static let service = "SafeClipy history key"
    static let account = "default"

    /// 鍵がなければ nil。アクセスを拒否された場合などは throw する。
    static func load() throws -> SymmetricKey? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data, data.count == 32 else { throw Error(status: errSecDecode) }
            return SymmetricKey(data: data)
        case errSecItemNotFound:
            return nil
        default:
            throw Error(status: status)
        }
    }

    static func create() throws -> SymmetricKey {
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        var attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrLabel: service,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        var status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecParam {
            // ファイル型のキーチェーンで accessible が使えない場合は付けずに保存する。
            attributes.removeValue(forKey: kSecAttrAccessible)
            status = SecItemAdd(attributes as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw Error(status: status) }
        return key
    }
}
