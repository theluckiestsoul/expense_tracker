import LocalAuthentication

enum PrivacyLock {
    static let storageKey = "privacyLockEnabled"

    static func authenticate(reason: String = "Unlock LedgerLeaf to view your financial data.") async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw error ?? LAError(.passcodeNotSet)
        }
        return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
    }
}
