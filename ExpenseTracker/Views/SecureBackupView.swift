import SwiftUI
import UniformTypeIdentifiers

struct EncryptedBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct SecureBackupView: View {
    let backup: LedgerLeafBackup
    let onRestore: (LedgerLeafBackup) -> Void
    @State private var password = ""
    @State private var confirmation = ""
    @State private var encryptedData = Data()
    @State private var exporting = false
    @State private var importing = false
    @State private var importedData: Data?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Password") {
                SecureField("Password", text: $password)
                SecureField("Confirm password", text: $confirmation)
                Text("LedgerLeaf cannot recover a forgotten backup password.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Button("Export Encrypted Backup", systemImage: "lock.doc") { export() }
                    .disabled(password.count < 8 || password != confirmation)
                Button("Restore Encrypted Backup", systemImage: "lock.open") { importing = true }
                    .disabled(password.isEmpty)
            }
        }
        .navigationTitle("Encrypted Backup")
        .fileExporter(isPresented: $exporting, document: EncryptedBackupDocument(data: encryptedData),
                      contentType: .data, defaultFilename: "ledgerleaf-encrypted.backup") { result in
            if case .failure(let error) = result { errorMessage = error.localizedDescription }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let decrypted = try EncryptedBackup.decrypt(Data(contentsOf: url), password: password)
                onRestore(try LedgerLeafBackup.decoded(from: decrypted))
            } catch { errorMessage = error.localizedDescription }
        }
        .alert("Secure Backup Error", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private func export() {
        do {
            encryptedData = try EncryptedBackup.encrypt(try backup.encoded(), password: password)
            exporting = true
        } catch { errorMessage = error.localizedDescription }
    }
}
