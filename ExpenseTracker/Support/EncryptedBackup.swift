import Foundation
import CryptoKit

enum EncryptedBackup {
    enum BackupError: LocalizedError {
        case invalidFile
        case wrongPassword
        var errorDescription: String? {
            switch self {
            case .invalidFile: "This is not a valid encrypted LedgerLeaf backup."
            case .wrongPassword: "The password is incorrect or the backup is damaged."
            }
        }
    }

    private static let magic = Data("LEDGERLEAF-ENC-1".utf8)

    static func encrypt(_ data: Data, password: String) throws -> Data {
        let salt = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
        let key = deriveKey(password: password, salt: salt)
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else { throw BackupError.invalidFile }
        return magic + salt + combined
    }

    static func decrypt(_ data: Data, password: String) throws -> Data {
        guard data.count > magic.count + 16, data.prefix(magic.count) == magic else { throw BackupError.invalidFile }
        let saltStart = magic.count
        let salt = data[saltStart..<(saltStart + 16)]
        let combined = data.dropFirst(saltStart + 16)
        do {
            return try AES.GCM.open(AES.GCM.SealedBox(combined: combined),
                                    using: deriveKey(password: password, salt: Data(salt)))
        } catch { throw BackupError.wrongPassword }
    }

    private static func deriveKey(password: String, salt: Data) -> SymmetricKey {
        var digest = Data(SHA256.hash(data: Data(password.utf8) + salt))
        for _ in 0..<20_000 { digest = Data(SHA256.hash(data: digest + salt)) }
        return SymmetricKey(data: digest)
    }
}
