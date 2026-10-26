import Foundation
import Testing
@testable import OCTrainingLog

@MainActor
struct LocalUnlockTests {
    private func storage() -> UserDefaults {
        UserDefaults(suiteName: "LocalUnlockTests." + UUID().uuidString)!
    }

    @Test func preferenceRequiresSuccessfulAuthenticationAndSurvivesRelaunch() async {
        let defaults = storage()
        let owner = UUID()
        let model = LocalUnlockModel(ownerId: owner, defaults: defaults, authenticate: { true })
        #expect(!model.enabled && !model.locked)
        await model.setEnabled(true)
        #expect(model.enabled && !model.locked)
        let restored = LocalUnlockModel(ownerId: owner, defaults: defaults, authenticate: { true })
        #expect(restored.enabled && restored.locked)
        await restored.unlock()
        #expect(!restored.locked)
        restored.background()
        #expect(restored.locked)
    }

    @Test func failedSetupDoesNotEnableProtection() async {
        let model = LocalUnlockModel(ownerId: UUID(), defaults: storage(), authenticate: { false })
        await model.setEnabled(true)
        #expect(!model.enabled && !model.locked)
        #expect(model.message != nil)
    }

    @Test func canceledUnlockCannotDisableOrBypassLock() async {
        let defaults = storage()
        let owner = UUID()
        let setup = LocalUnlockModel(ownerId: owner, defaults: defaults, authenticate: { true })
        await setup.setEnabled(true)
        let model = LocalUnlockModel(ownerId: owner, defaults: defaults, authenticate: {
            throw CancellationError()
        })
        await model.unlock()
        await model.setEnabled(false)
        #expect(model.locked && model.enabled)
        #expect(!model.working)
    }

    @Test func preferencesAreIsolatedByMember() async {
        let defaults = storage()
        let first = LocalUnlockModel(ownerId: UUID(), defaults: defaults, authenticate: { true })
        await first.setEnabled(true)
        let second = LocalUnlockModel(ownerId: UUID(), defaults: defaults, authenticate: { true })
        #expect(!second.enabled && !second.locked)
    }

    @Test func disablingWhileUnlockedPersists() async {
        let defaults = storage()
        let owner = UUID()
        let model = LocalUnlockModel(ownerId: owner, defaults: defaults, authenticate: { true })
        await model.setEnabled(true)
        await model.setEnabled(false)
        model.background()
        #expect(!model.locked)
        #expect(!LocalUnlockModel(ownerId: owner, defaults: defaults).enabled)
    }

    @Test func lateAuthenticationCannotUnlockAfterBackgrounding() async {
        let defaults = storage()
        let owner = UUID()
        let setup = LocalUnlockModel(ownerId: owner, defaults: defaults, authenticate: { true })
        await setup.setEnabled(true)
        var continuation: CheckedContinuation<Bool, Never>?
        let model = LocalUnlockModel(ownerId: owner, defaults: defaults, authenticate: {
            await withCheckedContinuation { continuation = $0 }
        })
        let task = Task { await model.unlock() }
        while continuation == nil { await Task.yield() }
        model.background()
        continuation?.resume(returning: true)
        await task.value
        #expect(model.locked && !model.working)
    }
}
