import Foundation
import UIKit
import UserNotifications

enum NotificationPermissionStatus: Equatable, Sendable {
    case unknown
    case notDetermined
    case denied
    case authorized
}

struct DeviceRegistrationRequest: Codable, Equatable, Sendable {
    let platform: String
    let environment: String
    let token: String

    init(token: String, environment: String = DeviceRegistrationRequest.currentEnvironment) {
        platform = "ios"
        self.environment = environment
        self.token = token
    }

    static var currentEnvironment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }
}

struct DeviceRegistrationResponse: Codable, Equatable, Sendable {
    let registered: Bool
}

@MainActor
protocol NotificationSystemProviding: AnyObject {
    func authorizationStatus() async -> NotificationPermissionStatus
    func requestAuthorization() async throws -> Bool
    func registerForRemoteNotifications() async throws -> String
    func openSettings()
}

@MainActor
protocol DeviceRegistrationLoading: AnyObject {
    func registerDevice(_ request: DeviceRegistrationRequest) async throws
        -> DeviceRegistrationResponse
}

extension AuthenticationModel: DeviceRegistrationLoading {}

@MainActor
final class NotificationRegistrationViewModel: ObservableObject {
    @Published private(set) var permission: NotificationPermissionStatus = .unknown
    @Published private(set) var working = false
    @Published private(set) var deviceRegistered = false
    @Published private(set) var statusMessage: String?

    func refresh(
        using system: any NotificationSystemProviding = SystemNotificationSystem.shared,
        registration: (any DeviceRegistrationLoading)? = nil
    ) async {
        permission = await system.authorizationStatus()
        guard permission == .authorized, let registration else { return }
        await register(using: system, registration: registration)
    }

    func enable(
        using system: any NotificationSystemProviding = SystemNotificationSystem.shared,
        registration: any DeviceRegistrationLoading
    ) async {
        working = true
        statusMessage = nil
        defer { working = false }
        do {
            let granted = try await system.requestAuthorization()
            permission = granted ? .authorized : .denied
            guard granted else {
                deviceRegistered = false
                statusMessage = "Notifications are off. You can enable them in iPhone Settings."
                return
            }
            await register(using: system, registration: registration)
        } catch {
            statusMessage = "We couldn't enable notifications. Please try again."
        }
    }

    func openSettings(
        using system: any NotificationSystemProviding = SystemNotificationSystem.shared
    ) {
        system.openSettings()
    }

    private func register(
        using system: any NotificationSystemProviding,
        registration: any DeviceRegistrationLoading
    ) async {
        working = true
        defer { working = false }
        do {
            let token = try await system.registerForRemoteNotifications()
            let request = DeviceRegistrationRequest(token: token)
            let response = try await registration.registerDevice(request)
            guard response.registered else { throw TodayAPIError.invalidData }
            DeviceRegistrationStore.shared.registration = request
            deviceRegistered = true
            statusMessage = "Notifications are enabled on this iPhone."
        } catch {
            deviceRegistered = false
            statusMessage = "Permission is on, but this device couldn't be registered yet."
        }
    }
}

@MainActor
final class SystemNotificationSystem: NotificationSystemProviding {
    static let shared = SystemNotificationSystem()

    func authorizationStatus() async -> NotificationPermissionStatus {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized, .provisional, .ephemeral: .authorized
        @unknown default: .unknown
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        )
    }

    func registerForRemoteNotifications() async throws -> String {
        try await PushRegistrationBroker.shared.requestToken()
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

@MainActor
final class PushRegistrationBroker {
    static let shared = PushRegistrationBroker()
    private var continuation: CheckedContinuation<String, Error>?
    private var currentToken: String?

    func requestToken() async throws -> String {
        if let currentToken { return currentToken }
        if continuation != nil { throw TodayAPIError.unavailable }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func didRegister(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        currentToken = token
        continuation?.resume(returning: token)
        continuation = nil
    }

    func didFail(error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

@MainActor
final class PushAppDelegate: NSObject, UIApplicationDelegate,
    @preconcurrency UNUserNotificationCenterDelegate
{
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushRegistrationBroker.shared.didRegister(deviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushRegistrationBroker.shared.didFail(error: error)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let workoutDate = response.notification.request.content.userInfo["workoutDate"] as? String
        else { return }
        WorkoutDeepLinkRouter.shared.handle(workoutDate: workoutDate)
    }
}

@MainActor
final class DeviceRegistrationStore {
    static let shared = DeviceRegistrationStore()
    var registration: DeviceRegistrationRequest?
}
