import SwiftUI
import LocalAuthentication

@MainActor
final class LocalUnlockModel: ObservableObject {
    @Published private(set) var enabled: Bool
    @Published private(set) var locked: Bool
    @Published private(set) var working = false
    @Published private(set) var message: String?
    private let defaults: UserDefaults
    private let key: String
    private let authenticate: @MainActor () async throws -> Bool
    private var generation = 0

    init(
        ownerId: UUID,
        defaults: UserDefaults = .standard,
        authenticate: @escaping @MainActor () async throws -> Bool = {
            let context = LAContext()
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock your private training log."
            )
        }
    ) {
        self.defaults = defaults
        key = "oc.localUnlock." + ownerId.uuidString
        self.authenticate = authenticate
        let saved = defaults.bool(forKey: key)
        enabled = saved
        locked = saved
    }

    func background() {
        generation += 1
        working = false
        if enabled { locked = true }
    }

    func setEnabled(_ value: Bool) async {
        guard !working, !locked else { return }
        if value {
            guard await verify() else { return }
        }
        enabled = value
        defaults.set(value, forKey: key)
        message = nil
    }

    func unlock() async {
        guard locked, !working else { return }
        if await verify() { locked = false }
    }

    private func verify() async -> Bool {
        working = true
        message = nil
        let attempt = generation
        let success: Bool
        do { success = try await authenticate() }
        catch { success = false }
        guard attempt == generation else { return false }
        working = false
        if !success {
            message = "Could not unlock. Try again, or use your iPhone passcode in the system prompt."
        }
        return success
    }
}

struct UnlockedMemberView: View {
    @ObservedObject var authentication: AuthenticationModel
    @ObservedObject var deepLinkRouter: WorkoutDeepLinkRouter
    @StateObject private var unlock: LocalUnlockModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasOpened = false

    init(authentication: AuthenticationModel, deepLinkRouter: WorkoutDeepLinkRouter, ownerId: UUID) {
        self.authentication = authentication
        self.deepLinkRouter = deepLinkRouter
        _unlock = StateObject(wrappedValue: LocalUnlockModel(ownerId: ownerId))
    }

    var body: some View {
        ZStack {
            if hasOpened || !unlock.locked {
                RootView(authentication: authentication, deepLinkRouter: deepLinkRouter)
                    .environmentObject(unlock)
                    .disabled(unlock.locked || scenePhase != .active)
                    .accessibilityHidden(unlock.locked || scenePhase != .active)
            }
            if unlock.locked || scenePhase != .active {
                Brand.background.ignoresSafeArea()
                VStack(spacing: 20) {
                    Image(systemName: "lock.fill").font(.largeTitle)
                    Text("Training Log locked").font(.title2.bold())
                    if scenePhase == .active {
                        Button("Unlock") { Task { await unlock.unlock() } }
                            .buttonStyle(.borderedProminent)
                            .disabled(unlock.working)
                        if unlock.working { ProgressView() }
                        if let message = unlock.message { Text(message) }
                        Button("Sign out", role: .destructive) {
                            Task { await authentication.signOut() }
                        }
                        if let error = authentication.errorMessage { Text(error) }
                    }
                }
                .padding()
            }
        }
        .onChange(of: unlock.locked, initial: true) { _, locked in
            if !locked { hasOpened = true }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { unlock.background() }
        }
    }
}
