import Foundation
import Supabase

@MainActor
protocol PasswordManaging {
    func requestRecovery(email: String) async throws
    func verifyRecovery(email: String, code: String) async throws
    func changePassword(email: String, ownerId: UUID, currentPassword: String, newPassword: String) async throws
    func resetPassword(_ password: String) async throws
    func clear() async
}

// Recovery credentials never enter the member's persistent Keychain session.
final class TransientAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func store(key: String, value: Data) throws {
        lock.lock(); defer { lock.unlock() }
        values[key] = value
    }
    func retrieve(key: String) throws -> Data? {
        lock.lock(); defer { lock.unlock() }
        return values[key]
    }
    func remove(key: String) throws {
        lock.lock(); defer { lock.unlock() }
        values.removeValue(forKey: key)
    }
    func clear() {
        lock.lock(); defer { lock.unlock() }
        values.removeAll()
    }
}

@MainActor
final class SupabasePasswordManager: PasswordManaging {
    private let storage = TransientAuthStorage()
    private let client: SupabaseClient
    private var recoveryVerified = false

    init(configuration: SupabaseConfiguration) {
        client = SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.publishableKey,
            options: SupabaseClientOptions(auth: .init(
                storage: storage,
                storageKey: "password-management",
                autoRefreshToken: false
            ))
        )
    }

    func requestRecovery(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }

    func verifyRecovery(email: String, code: String) async throws {
        let response = try await client.auth.verifyOTP(email: email, token: code, type: .recovery)
        guard response.session != nil else { throw PasswordManagementError.verification }
        recoveryVerified = true
    }

    func changePassword(email: String, ownerId: UUID, currentPassword: String, newPassword: String) async throws {
        do {
            let session = try await client.auth.signIn(email: email, password: currentPassword)
            guard session.user.id == ownerId else { throw PasswordManagementError.credentials }
        } catch {
            await clear()
            throw PasswordManagementError.credentials
        }
        do {
            try await client.auth.update(user: UserAttributes(password: newPassword))
        } catch {
            await clear()
            throw PasswordManagementError.update
        }
        await clear()
    }

    func resetPassword(_ password: String) async throws {
        guard recoveryVerified else { throw PasswordManagementError.verification }
        do { try await client.auth.update(user: UserAttributes(password: password)) }
        catch { throw PasswordManagementError.update }
        await clear()
    }

    func clear() async {
        recoveryVerified = false
        try? await client.auth.signOut(scope: .local)
        storage.clear()
    }
}

enum PasswordManagementError: LocalizedError {
    case credentials, verification, update
    var errorDescription: String? {
        switch self {
        case .credentials: "Could not verify your current password. Check it and try again."
        case .verification: "That code could not be verified. Check the code or request a new one."
        case .update: "Could not update your password. Use a different password of 12–128 characters and try again."
        }
    }
}

@MainActor
final class PasswordManagementModel: ObservableObject {
    @Published var email = ""
    @Published var currentPassword = ""
    @Published var newPassword = ""
    @Published var confirmation = ""
    @Published var code = ""
    @Published private(set) var working = false
    @Published private(set) var codeSent = false
    @Published private(set) var verified = false
    @Published private(set) var completed = false
    @Published private(set) var message: String?
    private let service: (any PasswordManaging)?
    private var recoveryEmail: String?

    init(service: (any PasswordManaging)? = nil) {
        if let service { self.service = service }
        else if let configuration = try? SupabaseConfiguration() {
            self.service = SupabasePasswordManager(configuration: configuration)
        } else { self.service = nil }
    }

    static func validation(password: String, confirmation: String) -> String? {
        guard (12...128).contains(password.unicodeScalars.count) else {
            return "Use a password of 12–128 characters."
        }
        guard password == confirmation else { return "The new passwords do not match." }
        return nil
    }

    func requestCode() async {
        guard !working, !verified, !completed else { return }
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard address.contains("@"), !address.contains(" ") else {
            message = "Enter your email address."
            return
        }
        guard let service else { message = "Password recovery is not configured."; return }
        working = true
        defer { working = false }
        do {
            try await service.requestRecovery(email: address)
            recoveryEmail = address
            codeSent = true
            code = ""
            message = "If an account exists for that email, a recovery code will arrive shortly."
        } catch {
            message = "Could not request a recovery code. Wait a moment and try again."
        }
    }

    func submit(ownerId: UUID? = nil, accountEmail: String? = nil) async {
        guard !working, !completed else { return }
        if let error = Self.validation(password: newPassword, confirmation: confirmation) {
            message = error
            return
        }
        guard let service else { message = "Password management is not configured."; return }
        working = true
        message = nil
        defer { working = false }
        do {
            if let ownerId, let accountEmail {
                guard !currentPassword.isEmpty else {
                    message = "Enter your current password."
                    return
                }
                guard currentPassword != newPassword else {
                    message = "Choose a different password from your current one."
                    return
                }
                try await service.changePassword(
                    email: accountEmail, ownerId: ownerId,
                    currentPassword: currentPassword, newPassword: newPassword
                )
            } else {
                guard let recoveryEmail, codeSent else {
                    message = "Request a recovery code first."
                    return
                }
                if !verified {
                    let token = code.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard token.count == 6, token.allSatisfy({ $0 >= "0" && $0 <= "9" }) else {
                        message = "Enter the six-digit recovery code."
                        return
                    }
                    do { try await service.verifyRecovery(email: recoveryEmail, code: token) }
                    catch { throw PasswordManagementError.verification }
                    verified = true
                    code = ""
                }
                try await service.resetPassword(newPassword)
            }
            completed = true
            eraseSecrets()
            message = "Password updated. Use your new password the next time you sign in."
        } catch {
            message = (error as? PasswordManagementError)?.errorDescription
                ?? "Could not update your password. Try again."
        }
    }

    func close() async {
        eraseSecrets()
        await service?.clear()
    }

    private func eraseSecrets() {
        currentPassword = ""
        newPassword = ""
        confirmation = ""
        code = ""
    }
}
