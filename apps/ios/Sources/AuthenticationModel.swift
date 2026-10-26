import Foundation
import Supabase

@MainActor
final class AuthenticationModel: ObservableObject {
    enum State: Equatable {
        case checkingSession
        case configurationRequired(String)
        case signedOut
        case signingIn
        case signedIn
    }

    @Published private(set) var state: State = .checkingSession
    @Published private(set) var errorMessage: String?

    private let client: SupabaseClient?
    private let todayAPIClient: TodayAPIClient?

    var draftOwnerId: UUID? {
        client?.auth.currentSession?.user.id
    }

    init(bundle: Bundle = .main) {
        do {
            let supabaseConfiguration = try SupabaseConfiguration(bundle: bundle)
            let apiConfiguration = try APIConfiguration(bundle: bundle)
            client = SupabaseClientFactory.make(configuration: supabaseConfiguration)
            todayAPIClient = TodayAPIClient(configuration: apiConfiguration)
        } catch {
            client = nil
            todayAPIClient = nil
            state = .configurationRequired(
                "Add the local API URL, Supabase URL, and publishable key to the iOS build settings."
            )
        }
    }

    func observeSession() async {
        guard let client else { return }

        for await change in client.auth.authStateChanges {
            switch change.event {
            case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                state = change.session == nil ? .signedOut : .signedIn
            case .signedOut, .userDeleted:
                state = .signedOut
            default:
                break
            }
        }
    }

    func signIn(email: String, password: String) async {
        guard let client else { return }

        errorMessage = nil
        state = .signingIn

        do {
            try await client.auth.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                password: password
            )
        } catch {
            state = .signedOut
            errorMessage = "We could not sign you in with those credentials."
        }
    }

    func signOut() async {
        guard let client else { return }

        do {
            if let registration = try await currentDeviceRegistration(),
               let todayAPIClient,
               let accessToken = client.auth.currentSession?.accessToken {
                _ = try await todayAPIClient.disableDevice(
                    registration,
                    accessToken: accessToken
                )
                DeviceRegistrationStore.shared.registration = nil
            }
            try await client.auth.signOut()
        } catch {
            errorMessage = "We could not sign you out. Please try again."
        }
    }

    func registerCurrentDeviceIfAuthorized() async {
        guard await SystemNotificationSystem.shared.authorizationStatus() == .authorized else {
            return
        }
        do {
            let token = try await SystemNotificationSystem.shared.registerForRemoteNotifications()
            let request = DeviceRegistrationRequest(token: token)
            _ = try await registerDevice(request)
            DeviceRegistrationStore.shared.registration = request
        } catch {
            // Profile exposes registration status and a retry action.
        }
    }

    private func currentDeviceRegistration() async throws -> DeviceRegistrationRequest? {
        if let registration = DeviceRegistrationStore.shared.registration {
            return registration
        }
        guard await SystemNotificationSystem.shared.authorizationStatus() == .authorized else {
            return nil
        }
        let token = try await SystemNotificationSystem.shared.registerForRemoteNotifications()
        return DeviceRegistrationRequest(token: token)
    }

    func loadToday(
        for track: TrainingTrack,
        workoutDate: String? = nil
    ) async throws -> TodayResponse {
        guard
            let client,
            let todayAPIClient,
            let accessToken = client.auth.currentSession?.accessToken,
            !accessToken.isEmpty
        else {
            throw TodayAPIError.unauthorized
        }

        return try await todayAPIClient.fetchToday(
            track: track,
            workoutDate: workoutDate,
            accessToken: accessToken
        )
    }

    func completeWorkout(
        _ request: WorkoutCompletionRequest
    ) async throws -> WorkoutCompletionResponse {
        guard
            let client,
            let todayAPIClient,
            let accessToken = client.auth.currentSession?.accessToken,
            !accessToken.isEmpty
        else {
            throw TodayAPIError.unauthorized
        }

        return try await todayAPIClient.completeWorkout(
            request,
            accessToken: accessToken
        )
    }

    func completeFreeTextWorkout(
        _ request: FreeTextWorkoutRequest
    ) async throws -> WorkoutCompletionResponse {
        guard
            let client,
            let todayAPIClient,
            let accessToken = client.auth.currentSession?.accessToken,
            !accessToken.isEmpty
        else { throw TodayAPIError.unauthorized }
        return try await todayAPIClient.completeFreeTextWorkout(
            request,
            accessToken: accessToken
        )
    }

    func loadHistory(
        for track: TrainingTrack,
        query: String?,
        fromDate: String?,
        personalRecordsOnly: Bool,
        cursor: String?
    ) async throws -> HistoryResponse {
        guard
            let client,
            let todayAPIClient,
            let accessToken = client.auth.currentSession?.accessToken,
            !accessToken.isEmpty
        else {
            throw TodayAPIError.unauthorized
        }
        return try await todayAPIClient.fetchHistory(
            track: track,
            query: query,
            fromDate: fromDate,
            personalRecordsOnly: personalRecordsOnly,
            cursor: cursor,
            accessToken: accessToken
        )
    }

    func editWorkout(_ request: WorkoutEditRequest) async throws -> WorkoutEditResponse {
        guard
            let client,
            let todayAPIClient,
            let accessToken = client.auth.currentSession?.accessToken,
            !accessToken.isEmpty
        else {
            throw TodayAPIError.unauthorized
        }
        return try await todayAPIClient.editWorkout(request, accessToken: accessToken)
    }

    func loadWorkout(
        for track: TrainingTrack,
        workoutLogId: UUID
    ) async throws -> HistoryWorkout {
        guard
            let client,
            let todayAPIClient,
            let accessToken = client.auth.currentSession?.accessToken,
            !accessToken.isEmpty
        else {
            throw TodayAPIError.unauthorized
        }
        let response = try await todayAPIClient.fetchHistory(
            track: track,
            workoutLogId: workoutLogId,
            accessToken: accessToken
        )
        guard let workout = response.workouts.first,
              workout.workoutLogId == workoutLogId else {
            throw TodayAPIError.invalidData
        }
        return workout
    }

    func editFreeTextWorkout(
        _ request: FreeTextWorkoutEditRequest
    ) async throws -> WorkoutEditResponse {
        guard
            let client,
            let todayAPIClient,
            let accessToken = client.auth.currentSession?.accessToken,
            !accessToken.isEmpty
        else {
            throw TodayAPIError.unauthorized
        }
        return try await todayAPIClient.editFreeTextWorkout(
            request,
            accessToken: accessToken
        )
    }

    func loadPersonalRecords(
        for track: TrainingTrack
    ) async throws -> PersonalRecordListResponse {
        let data = try await personalRecordsData(track: track, benchmarkId: nil)
        do { return try JSONDecoder().decode(PersonalRecordListResponse.self, from: data) }
        catch { throw TodayAPIError.invalidData }
    }

    func loadPersonalRecordDetail(
        for track: TrainingTrack,
        benchmarkId: UUID
    ) async throws -> PersonalRecordDetailResponse {
        let data = try await personalRecordsData(track: track, benchmarkId: benchmarkId)
        do { return try JSONDecoder().decode(PersonalRecordDetailResponse.self, from: data) }
        catch { throw TodayAPIError.invalidData }
    }

    private func personalRecordsData(
        track: TrainingTrack,
        benchmarkId: UUID?
    ) async throws -> Data {
        guard
            let client,
            let todayAPIClient,
            let accessToken = client.auth.currentSession?.accessToken,
            !accessToken.isEmpty
        else { throw TodayAPIError.unauthorized }
        return try await todayAPIClient.fetchPersonalRecords(
            track: track,
            benchmarkId: benchmarkId,
            accessToken: accessToken
        )
    }

    func loadMemberProfile() async throws -> MemberProfileResponse {
        try await profileRequest { client, token in
            try await client.fetchMemberProfile(accessToken: token)
        }
    }

    func updateMemberProfile(
        _ request: UpdateMemberProfileRequest
    ) async throws -> MemberProfileResponse {
        try await profileRequest { client, token in
            try await client.updateMemberProfile(request, accessToken: token)
        }
    }

    func leaveTrack(_ trackId: UUID) async throws -> MemberProfileResponse {
        try await profileRequest { client, token in
            try await client.leaveTrack(trackId, accessToken: token)
        }
    }

    private func profileRequest(
        _ request: (TodayAPIClient, String) async throws -> MemberProfileResponse
    ) async throws -> MemberProfileResponse {
        guard
            let client,
            let todayAPIClient,
            let accessToken = client.auth.currentSession?.accessToken,
            !accessToken.isEmpty
        else { throw TodayAPIError.unauthorized }
        return try await request(todayAPIClient, accessToken)
    }

    func loadReminderSettings() async throws -> ReminderSettingsResponse {
        try await reminderRequest { client, token in
            try await client.fetchReminderSettings(accessToken: token)
        }
    }

    func updateReminderSettings(
        _ request: UpdateReminderSettingsRequest
    ) async throws -> ReminderSettingsResponse {
        try await reminderRequest { client, token in
            try await client.updateReminderSettings(request, accessToken: token)
        }
    }

    private func reminderRequest(
        _ request: (TodayAPIClient, String) async throws -> ReminderSettingsResponse
    ) async throws -> ReminderSettingsResponse {
        guard
            let client,
            let todayAPIClient,
            let accessToken = client.auth.currentSession?.accessToken,
            !accessToken.isEmpty
        else { throw TodayAPIError.unauthorized }
        return try await request(todayAPIClient, accessToken)
    }

    func registerDevice(
        _ request: DeviceRegistrationRequest
    ) async throws -> DeviceRegistrationResponse {
        guard
            let client,
            let todayAPIClient,
            let accessToken = client.auth.currentSession?.accessToken,
            !accessToken.isEmpty
        else { throw TodayAPIError.unauthorized }
        return try await todayAPIClient.registerDevice(request, accessToken: accessToken)
    }
}
