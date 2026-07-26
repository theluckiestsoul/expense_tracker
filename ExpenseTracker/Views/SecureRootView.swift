import SwiftUI

struct SecureRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(PrivacyLock.storageKey) private var lockEnabled = false
    @AppStorage("privacyShieldEnabled") private var privacyShieldEnabled = true
    @State private var unlocked = false
    @State private var authenticating = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if !lockEnabled || unlocked {
                RootView()
            } else {
                VStack(spacing: 18) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 54)).foregroundStyle(.indigo)
                    Text("LedgerLeaf Locked").font(.title2.bold())
                    Text("Authenticate to view your financial data.")
                        .multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Button("Unlock", action: unlock).buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .overlay {
            if privacyShieldEnabled && scenePhase != .active {
                ZStack {
                    Color(uiColor: .systemBackground).ignoresSafeArea()
                    VStack(spacing: 12) {
                        Image(systemName: "leaf.fill").font(.system(size: 46)).foregroundStyle(.green)
                        Text("LedgerLeaf").font(.title.bold())
                        Text("Financial details hidden").foregroundStyle(.secondary)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .task { if lockEnabled { await authenticate() } else { unlocked = true } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive { unlocked = false }
            else if phase == .active, lockEnabled { unlock() }
        }
        .alert("Couldn’t Unlock", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "Unknown error") }
    }

    private func unlock() {
        Task { await authenticate() }
    }

    @MainActor
    private func authenticate() async {
        guard lockEnabled, !unlocked, !authenticating else { return }
        authenticating = true
        defer { authenticating = false }
        do { unlocked = try await PrivacyLock.authenticate() }
        catch { errorMessage = error.localizedDescription }
    }
}
