import Foundation
import Testing
@testable import OCTrainingLog

@MainActor
struct NotificationRegistrationViewModelTests {
    @Test func explainsDeniedPermissionWithoutRegistering() async {
        let system = StubNotificationSystem(status: .notDetermined, grant: false)
        let registration = StubDeviceRegistrationLoader()
        let model = NotificationRegistrationViewModel()

        await model.enable(using: system, registration: registration)

        #expect(model.permission == .denied)
        #expect(!model.deviceRegistered)
        #expect(registration.requests.isEmpty)
        #expect(model.statusMessage?.contains("iPhone Settings") == true)
    }

    @Test func registersTheAPNsTokenAfterPermissionIsGranted() async {
        let token = String(repeating: "ab", count: 32)
        let system = StubNotificationSystem(
            status: .notDetermined,
            grant: true,
            token: token
        )
        let registration = StubDeviceRegistrationLoader()
        let model = NotificationRegistrationViewModel()

        await model.enable(using: system, registration: registration)

        #expect(model.permission == .authorized)
        #expect(model.deviceRegistered)
        #expect(registration.requests == [
            DeviceRegistrationRequest(token: token, environment: "sandbox")
        ])
    }

    @Test func refreshDoesNotPromptForPermission() async {
        let system = StubNotificationSystem(status: .notDetermined, grant: true)
        let model = NotificationRegistrationViewModel()

        await model.refresh(using: system)

        #expect(model.permission == .notDetermined)
        #expect(system.authorizationRequests == 0)
    }
}

@MainActor
private final class StubNotificationSystem: NotificationSystemProviding {
    let status: NotificationPermissionStatus
    let grant: Bool
    let token: String
    var authorizationRequests = 0

    init(
        status: NotificationPermissionStatus,
        grant: Bool = false,
        token: String = String(repeating: "ab", count: 32)
    ) {
        self.status = status
        self.grant = grant
        self.token = token
    }

    func authorizationStatus() async -> NotificationPermissionStatus { status }
    func requestAuthorization() async throws -> Bool {
        authorizationRequests += 1
        return grant
    }
    func registerForRemoteNotifications() async throws -> String { token }
    func openSettings() {}
}

@MainActor
private final class StubDeviceRegistrationLoader: DeviceRegistrationLoading {
    var requests: [DeviceRegistrationRequest] = []

    func registerDevice(
        _ request: DeviceRegistrationRequest
    ) async throws -> DeviceRegistrationResponse {
        requests.append(request)
        return DeviceRegistrationResponse(registered: true)
    }
}

struct DeviceRegistrationAPIClientTests {
    @Test func sendsTheTokenWithBearerAuthentication() async throws {
        let session = DeviceRegistrationMockLoader(
            data: Data(#"{"registered":true}"#.utf8),
            statusCode: 200
        )
        let client = TodayAPIClient(
            configuration: try APIConfiguration(values: [
                "OCAPIBaseURL": "https://api.example.test"
            ]),
            session: session
        )
        let token = String(repeating: "ab", count: 32)

        _ = try await client.registerDevice(
            DeviceRegistrationRequest(token: token, environment: "sandbox"),
            accessToken: "member-token"
        )

        let request = await session.capturedRequest()
        #expect(request?.httpMethod == "POST")
        #expect(request?.url?.absoluteString == "https://api.example.test/api/notifications/devices")
        #expect(request?.value(forHTTPHeaderField: "Authorization") == "Bearer member-token")
        #expect(String(data: request?.httpBody ?? Data(), encoding: .utf8)?.contains(token) == true)
    }
}

private actor DeviceRegistrationMockLoader: HTTPDataLoading {
    private let data: Data
    private let statusCode: Int
    private var request: URLRequest?

    init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        self.request = request
        return (
            data,
            HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
        )
    }

    func capturedRequest() -> URLRequest? { request }
}
