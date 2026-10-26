import Foundation

protocol HTTPDataLoading: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPDataLoading {}

enum TodayAPIError: Error, Equatable {
    case invalidRequest
    case invalidResponse
    case unauthorized
    case trackAccessDenied
    case invalidEntry
    case completionConflict
    case workoutEditConflict
    case unavailable
    case unexpectedStatus(Int)
    case invalidData
}

struct TodayAPIClient: Sendable {
    private let baseURL: URL
    private let session: any HTTPDataLoading

    init(
        configuration: APIConfiguration,
        session: any HTTPDataLoading = URLSession.shared
    ) {
        baseURL = configuration.baseURL
        self.session = session
    }

    func fetchToday(
        track: TrainingTrack,
        workoutDate: String? = nil,
        accessToken: String
    ) async throws -> TodayResponse {
        guard
            var components = URLComponents(
                url: baseURL.appending(path: "api/today"),
                resolvingAgainstBaseURL: false
            )
        else {
            throw TodayAPIError.invalidRequest
        }

        components.queryItems = [URLQueryItem(name: "track", value: track.rawValue)]
        if let workoutDate {
            components.queryItems?.append(URLQueryItem(name: "date", value: workoutDate))
        }
        guard let url = components.url else {
            throw TodayAPIError.invalidRequest
        }

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TodayAPIError.unavailable
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TodayAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(TodayResponse.self, from: data)
            } catch {
                throw TodayAPIError.invalidData
            }
        case 401:
            throw TodayAPIError.unauthorized
        case 403:
            throw TodayAPIError.trackAccessDenied
        case 408, 429, 500...599:
            throw TodayAPIError.unavailable
        default:
            throw TodayAPIError.unexpectedStatus(httpResponse.statusCode)
        }
    }

    func completeWorkout(
        _ completion: WorkoutCompletionRequest,
        accessToken: String
    ) async throws -> WorkoutCompletionResponse {
        let url = baseURL.appending(path: "api/workouts/complete")
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(completion)
        } catch {
            throw TodayAPIError.invalidRequest
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TodayAPIError.unavailable
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TodayAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(WorkoutCompletionResponse.self, from: data)
            } catch {
                throw TodayAPIError.invalidData
            }
        case 400:
            throw TodayAPIError.invalidEntry
        case 401:
            throw TodayAPIError.unauthorized
        case 403:
            throw TodayAPIError.trackAccessDenied
        case 409:
            throw TodayAPIError.completionConflict
        case 408, 429, 500...599:
            throw TodayAPIError.unavailable
        default:
            throw TodayAPIError.unexpectedStatus(httpResponse.statusCode)
        }
    }

    func completeFreeTextWorkout(
        _ completion: FreeTextWorkoutRequest,
        accessToken: String
    ) async throws -> WorkoutCompletionResponse {
        let url = baseURL.appending(path: "api/workouts/free-text")
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do { request.httpBody = try JSONEncoder().encode(completion) }
        catch { throw TodayAPIError.invalidRequest }

        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch { throw TodayAPIError.unavailable }
        guard let response = response as? HTTPURLResponse else {
            throw TodayAPIError.invalidResponse
        }
        switch response.statusCode {
        case 200:
            do { return try JSONDecoder().decode(WorkoutCompletionResponse.self, from: data) }
            catch { throw TodayAPIError.invalidData }
        case 400: throw TodayAPIError.invalidEntry
        case 401: throw TodayAPIError.unauthorized
        case 403: throw TodayAPIError.trackAccessDenied
        case 409: throw TodayAPIError.completionConflict
        case 408, 429, 500...599: throw TodayAPIError.unavailable
        default: throw TodayAPIError.unexpectedStatus(response.statusCode)
        }
    }

    func fetchHistory(
        track: TrainingTrack,
        query: String? = nil,
        fromDate: String? = nil,
        personalRecordsOnly: Bool = false,
        cursor: String? = nil,
        workoutLogId: UUID? = nil,
        accessToken: String
    ) async throws -> HistoryResponse {
        guard
            var components = URLComponents(
                url: baseURL.appending(path: "api/history"),
                resolvingAgainstBaseURL: false
            )
        else {
            throw TodayAPIError.invalidRequest
        }
        components.queryItems = [URLQueryItem(name: "track", value: track.rawValue)]
        if let query { components.queryItems?.append(URLQueryItem(name: "query", value: query)) }
        if let fromDate { components.queryItems?.append(URLQueryItem(name: "from", value: fromDate)) }
        if personalRecordsOnly {
            components.queryItems?.append(URLQueryItem(name: "pr", value: "true"))
        }
        if let cursor { components.queryItems?.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let workoutLogId {
            components.queryItems?.append(
                URLQueryItem(name: "workout", value: workoutLogId.uuidString.lowercased())
            )
        }
        guard let url = components.url else { throw TodayAPIError.invalidRequest }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TodayAPIError.unavailable
        }
        guard let response = response as? HTTPURLResponse else {
            throw TodayAPIError.invalidResponse
        }
        switch response.statusCode {
        case 200:
            do { return try JSONDecoder().decode(HistoryResponse.self, from: data) }
            catch { throw TodayAPIError.invalidData }
        case 401: throw TodayAPIError.unauthorized
        case 403: throw TodayAPIError.trackAccessDenied
        case 500...599: throw TodayAPIError.unavailable
        default: throw TodayAPIError.unexpectedStatus(response.statusCode)
        }
    }

    func editWorkout(
        _ edit: WorkoutEditRequest,
        accessToken: String
    ) async throws -> WorkoutEditResponse {
        let url = baseURL.appending(path: "api/workouts/edit")
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do { request.httpBody = try JSONEncoder().encode(edit) }
        catch { throw TodayAPIError.invalidRequest }

        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch { throw TodayAPIError.unavailable }
        guard let response = response as? HTTPURLResponse else {
            throw TodayAPIError.invalidResponse
        }
        switch response.statusCode {
        case 200:
            do { return try JSONDecoder().decode(WorkoutEditResponse.self, from: data) }
            catch { throw TodayAPIError.invalidData }
        case 400: throw TodayAPIError.invalidEntry
        case 401: throw TodayAPIError.unauthorized
        case 403: throw TodayAPIError.trackAccessDenied
        case 409: throw TodayAPIError.workoutEditConflict
        case 408, 429, 500...599: throw TodayAPIError.unavailable
        default: throw TodayAPIError.unexpectedStatus(response.statusCode)
        }
    }

    func editFreeTextWorkout(
        _ edit: FreeTextWorkoutEditRequest,
        accessToken: String
    ) async throws -> WorkoutEditResponse {
        let url = baseURL.appending(path: "api/workouts/free-text/edit")
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do { request.httpBody = try JSONEncoder().encode(edit) }
        catch { throw TodayAPIError.invalidRequest }

        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch { throw TodayAPIError.unavailable }
        guard let response = response as? HTTPURLResponse else {
            throw TodayAPIError.invalidResponse
        }
        switch response.statusCode {
        case 200:
            do { return try JSONDecoder().decode(WorkoutEditResponse.self, from: data) }
            catch { throw TodayAPIError.invalidData }
        case 400: throw TodayAPIError.invalidEntry
        case 401: throw TodayAPIError.unauthorized
        case 403: throw TodayAPIError.trackAccessDenied
        case 409: throw TodayAPIError.workoutEditConflict
        case 408, 429, 500...599: throw TodayAPIError.unavailable
        default: throw TodayAPIError.unexpectedStatus(response.statusCode)
        }
    }

    func fetchPersonalRecords(
        track: TrainingTrack,
        benchmarkId: UUID? = nil,
        accessToken: String
    ) async throws -> Data {
        guard var components = URLComponents(
            url: baseURL.appending(path: "api/personal-records"),
            resolvingAgainstBaseURL: false
        ) else { throw TodayAPIError.invalidRequest }
        components.queryItems = [URLQueryItem(name: "track", value: track.rawValue)]
        if let benchmarkId {
            components.queryItems?.append(
                URLQueryItem(name: "benchmark", value: benchmarkId.uuidString.lowercased())
            )
        }
        guard let url = components.url else { throw TodayAPIError.invalidRequest }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch { throw TodayAPIError.unavailable }
        guard let response = response as? HTTPURLResponse else {
            throw TodayAPIError.invalidResponse
        }
        switch response.statusCode {
        case 200: return data
        case 401: throw TodayAPIError.unauthorized
        case 403: throw TodayAPIError.trackAccessDenied
        case 408, 429, 500...599: throw TodayAPIError.unavailable
        default: throw TodayAPIError.unexpectedStatus(response.statusCode)
        }
    }

    func fetchMemberProfile(accessToken: String) async throws -> MemberProfileResponse {
        try await memberProfileRequest(
            path: "api/profile",
            method: "GET",
            body: nil,
            accessToken: accessToken
        )
    }

    func updateMemberProfile(
        _ update: UpdateMemberProfileRequest,
        accessToken: String
    ) async throws -> MemberProfileResponse {
        let body: Data
        do { body = try JSONEncoder().encode(update) }
        catch { throw TodayAPIError.invalidRequest }
        return try await memberProfileRequest(
            path: "api/profile",
            method: "PATCH",
            body: body,
            accessToken: accessToken
        )
    }

    func leaveTrack(
        _ trackId: UUID,
        accessToken: String
    ) async throws -> MemberProfileResponse {
        let body: Data
        do { body = try JSONEncoder().encode(LeaveTrackRequest(trackId: trackId)) }
        catch { throw TodayAPIError.invalidRequest }
        return try await memberProfileRequest(
            path: "api/profile/tracks/leave",
            method: "POST",
            body: body,
            accessToken: accessToken
        )
    }

    private func memberProfileRequest(
        path: String,
        method: String,
        body: Data?,
        accessToken: String
    ) async throws -> MemberProfileResponse {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch { throw TodayAPIError.unavailable }
        guard let response = response as? HTTPURLResponse else {
            throw TodayAPIError.invalidResponse
        }
        switch response.statusCode {
        case 200:
            do { return try JSONDecoder().decode(MemberProfileResponse.self, from: data) }
            catch { throw TodayAPIError.invalidData }
        case 400: throw TodayAPIError.invalidEntry
        case 401: throw TodayAPIError.unauthorized
        case 403: throw TodayAPIError.trackAccessDenied
        case 409: throw TodayAPIError.completionConflict
        case 408, 429, 500...599: throw TodayAPIError.unavailable
        default: throw TodayAPIError.unexpectedStatus(response.statusCode)
        }
    }

    func fetchReminderSettings(accessToken: String) async throws -> ReminderSettingsResponse {
        try await reminderSettingsRequest(method: "GET", body: nil, accessToken: accessToken)
    }

    func updateReminderSettings(
        _ settings: UpdateReminderSettingsRequest,
        accessToken: String
    ) async throws -> ReminderSettingsResponse {
        let body: Data
        do { body = try JSONEncoder().encode(settings) }
        catch { throw TodayAPIError.invalidRequest }
        return try await reminderSettingsRequest(
            method: "PUT",
            body: body,
            accessToken: accessToken
        )
    }

    private func reminderSettingsRequest(
        method: String,
        body: Data?,
        accessToken: String
    ) async throws -> ReminderSettingsResponse {
        var request = URLRequest(
            url: baseURL.appending(path: "api/reminders"),
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch { throw TodayAPIError.unavailable }
        guard let response = response as? HTTPURLResponse else {
            throw TodayAPIError.invalidResponse
        }
        switch response.statusCode {
        case 200:
            do { return try JSONDecoder().decode(ReminderSettingsResponse.self, from: data) }
            catch { throw TodayAPIError.invalidData }
        case 400: throw TodayAPIError.invalidEntry
        case 401: throw TodayAPIError.unauthorized
        case 408, 429, 500...599: throw TodayAPIError.unavailable
        default: throw TodayAPIError.unexpectedStatus(response.statusCode)
        }
    }

    func registerDevice(
        _ device: DeviceRegistrationRequest,
        accessToken: String
    ) async throws -> DeviceRegistrationResponse {
        try await deviceRegistrationRequest(
            device,
            method: "POST",
            accessToken: accessToken
        )
    }

    func disableDevice(
        _ device: DeviceRegistrationRequest,
        accessToken: String
    ) async throws -> DeviceRegistrationResponse {
        try await deviceRegistrationRequest(
            device,
            method: "DELETE",
            accessToken: accessToken
        )
    }

    private func deviceRegistrationRequest(
        _ device: DeviceRegistrationRequest,
        method: String,
        accessToken: String
    ) async throws -> DeviceRegistrationResponse {
        var request = URLRequest(
            url: baseURL.appending(path: "api/notifications/devices"),
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do { request.httpBody = try JSONEncoder().encode(device) }
        catch { throw TodayAPIError.invalidRequest }
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch { throw TodayAPIError.unavailable }
        guard let response = response as? HTTPURLResponse else {
            throw TodayAPIError.invalidResponse
        }
        switch response.statusCode {
        case 200:
            do { return try JSONDecoder().decode(DeviceRegistrationResponse.self, from: data) }
            catch { throw TodayAPIError.invalidData }
        case 400: throw TodayAPIError.invalidEntry
        case 401: throw TodayAPIError.unauthorized
        case 408, 429, 500...599: throw TodayAPIError.unavailable
        default: throw TodayAPIError.unexpectedStatus(response.statusCode)
        }
    }
}
