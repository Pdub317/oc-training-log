import Foundation
import Testing
@testable import OCTrainingLog

@MainActor
struct PasswordManagementTests {
    @Test func enforcesLengthAndMatchingWithoutTrimmingPasswords() {
        #expect(PasswordManagementModel.validation(password: "12345678901", confirmation: "12345678901") != nil)
        #expect(PasswordManagementModel.validation(password: String(repeating: "x", count: 129), confirmation: "") != nil)
        #expect(PasswordManagementModel.validation(password: " 1234567890 ", confirmation: " 1234567890 ") == nil)
        #expect(PasswordManagementModel.validation(password: "123456789012", confirmation: "123456789013") != nil)
    }

    @Test func invalidInputNeverReachesPasswordProvider() async {
        let service = PasswordServiceStub()
        let model = PasswordManagementModel(service: service)
        await model.submit(ownerId: UUID(), accountEmail: "member@example.com")
        #expect(service.changes == 0)
        #expect(service.verifications == 0)
    }

    @Test func changingRequiresCurrentPasswordAndPreservesExactNewValue() async {
        let service = PasswordServiceStub()
        let model = prepared(service)
        let owner = UUID()
        await model.submit(ownerId: owner, accountEmail: "member@example.com")
        #expect(service.changes == 0)
        model.currentPassword = "old-password"
        await model.submit(ownerId: owner, accountEmail: "member@example.com")
        #expect(service.owner == owner)
        #expect(service.password == " 1234567890 ")
        #expect(model.completed)
        #expect(model.currentPassword.isEmpty && model.newPassword.isEmpty && model.confirmation.isEmpty)
    }

    @Test func wrongCurrentPasswordLeavesUpdateIncomplete() async {
        let service = PasswordServiceStub()
        service.failChange = true
        let model = prepared(service)
        model.currentPassword = "wrong-password"
        await model.submit(ownerId: UUID(), accountEmail: "member@example.com")
        #expect(!model.completed && !model.working)
        #expect(model.message == PasswordManagementError.credentials.errorDescription)
    }

    @Test func recoveryBindsToRequestedEmailAndVerifiesBeforeUpdate() async {
        let service = PasswordServiceStub()
        let model = prepared(service)
        model.email = " MEMBER@EXAMPLE.COM "
        await model.requestCode()
        #expect(service.email == "member@example.com")
        #expect(model.message?.contains("If an account exists") == true)
        model.email = "someone-else@example.com"
        model.code = "123456"
        await model.submit()
        #expect(service.email == "member@example.com")
        #expect(service.verifications == 1 && service.resets == 1)
        #expect(model.completed && model.code.isEmpty)
    }

    @Test func expiredCodeNeverUpdatesPassword() async {
        let service = PasswordServiceStub()
        service.failVerification = true
        let model = prepared(service)
        model.email = "member@example.com"
        await model.requestCode()
        model.code = "123456"
        await model.submit()
        #expect(service.resets == 0 && !model.verified && !model.completed)
    }

    @Test func rejectedPasswordCanRetryWithoutReusingConsumedCode() async {
        let service = PasswordServiceStub()
        service.failReset = true
        let model = prepared(service)
        model.email = "member@example.com"
        await model.requestCode()
        model.code = "123456"
        await model.submit()
        #expect(model.verified && !model.completed)
        #expect(model.code.isEmpty)
        service.failReset = false
        await model.submit()
        #expect(service.verifications == 1 && service.resets == 2)
        #expect(model.completed)
    }

    @Test func recoveryCannotStartWithoutCodeRequestOrValidCode() async {
        let service = PasswordServiceStub()
        let model = prepared(service)
        await model.submit()
        #expect(service.verifications == 0 && service.resets == 0)
        model.email = "member@example.com"
        await model.requestCode()
        model.code = "１２３４５６"
        await model.submit()
        #expect(service.verifications == 0)
    }

    @Test func closingClearsSecretsAndTemporarySession() async {
        let service = PasswordServiceStub()
        let model = prepared(service)
        model.currentPassword = "old-password"
        model.code = "123456"
        await model.close()
        #expect(service.clears == 1)
        #expect(model.newPassword.isEmpty && model.confirmation.isEmpty)
        #expect(model.currentPassword.isEmpty && model.code.isEmpty)
    }

    @Test func temporaryStorageRetainsSessionOnlyWithinItsInstance() throws {
        let first = TransientAuthStorage()
        let second = TransientAuthStorage()
        try first.store(key: "session", value: Data([1, 2, 3]))
        #expect(try first.retrieve(key: "session") == Data([1, 2, 3]))
        #expect(try second.retrieve(key: "session") == nil)
        first.clear()
        #expect(try first.retrieve(key: "session") == nil)
    }

    private func prepared(_ service: PasswordServiceStub) -> PasswordManagementModel {
        let model = PasswordManagementModel(service: service)
        model.newPassword = " 1234567890 "
        model.confirmation = model.newPassword
        return model
    }
}

@MainActor
private final class PasswordServiceStub: PasswordManaging {
    var changes = 0
    var verifications = 0
    var resets = 0
    var clears = 0
    var email: String?
    var owner: UUID?
    var password: String?
    var failChange = false
    var failVerification = false
    var failReset = false

    func requestRecovery(email: String) async throws { self.email = email }
    func verifyRecovery(email: String, code: String) async throws {
        verifications += 1
        self.email = email
        if failVerification { throw PasswordManagementError.verification }
    }
    func changePassword(email: String, ownerId: UUID, currentPassword: String, newPassword: String) async throws {
        changes += 1
        owner = ownerId
        if failChange { throw PasswordManagementError.credentials }
        password = newPassword
    }
    func resetPassword(_ password: String) async throws {
        resets += 1
        if failReset { throw PasswordManagementError.update }
        self.password = password
    }
    func clear() async { clears += 1 }
}
