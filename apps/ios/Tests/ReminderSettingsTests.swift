import Foundation
import Testing
@testable import OCTrainingLog

@MainActor
struct ReminderSettingsViewModelTests {
    @Test func selectsDaysKeepsSeparateTimesAndAppliesOneTimeToAll() async {
        let loader = StubReminderSettingsLoader()
        let model = ReminderSettingsViewModel()
        await model.load(using: loader)

        #expect(model.isSelected(.monday))
        #expect(!model.isSelected(.tuesday))
        model.setSelected(true, weekday: .wednesday)
        model.setTime(Self.date(hour: 19, minute: 45), weekday: .wednesday)
        await model.save(using: loader)
        #expect(loader.updates.first?.schedules == [
            ReminderSchedule(weekday: .monday, localTime: "18:15"),
            ReminderSchedule(weekday: .wednesday, localTime: "19:45"),
        ])

        model.applyToAllTime = Self.date(hour: 20, minute: 30)
        model.applyTimeToSelectedDays()
        await model.save(using: loader)
        #expect(loader.updates.last?.schedules.map(\.localTime) == ["20:30", "20:30"])
    }

    @Test func savingNoSelectedDaysTurnsTheScheduleOff() async {
        let loader = StubReminderSettingsLoader()
        let model = ReminderSettingsViewModel()
        await model.load(using: loader)
        model.setSelected(false, weekday: .monday)
        await model.save(using: loader)
        #expect(loader.updates.last?.schedules.isEmpty == true)
        #expect(model.statusMessage == "Reminders turned off.")
    }

    private static func date(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }
}

@MainActor
private final class StubReminderSettingsLoader: ReminderSettingsLoading {
    var updates: [UpdateReminderSettingsRequest] = []

    func loadReminderSettings() async throws -> ReminderSettingsResponse {
        ReminderSettingsResponse(
            timeZone: "America/Los_Angeles",
            schedules: [ReminderSchedule(weekday: .monday, localTime: "18:15")]
        )
    }

    func updateReminderSettings(_ request: UpdateReminderSettingsRequest) async throws
        -> ReminderSettingsResponse {
        updates.append(request)
        return request
    }
}

struct ReminderSettingsAPIClientTests {
    @Test func sendsDistinctWeekdayTimesWithBearerAuthentication() async throws {
        let responseJSON = #"{"timeZone":"America/Los_Angeles","schedules":[{"weekday":1,"localTime":"18:15"}]}"#
        let session = ReminderMockHTTPDataLoader(
            data: Data(responseJSON.utf8),
            statusCode: 200
        )
        let client = TodayAPIClient(
            configuration: try APIConfiguration(values: [
                "OCAPIBaseURL": "https://api.example.test"
            ]),
            session: session
        )
        _ = try await client.updateReminderSettings(
            ReminderSettingsResponse(
                timeZone: "America/Los_Angeles",
                schedules: [ReminderSchedule(weekday: .monday, localTime: "18:15")]
            ),
            accessToken: "member-token"
        )
        let request = await session.capturedRequest()
        #expect(request?.httpMethod == "PUT")
        #expect(request?.url?.absoluteString == "https://api.example.test/api/reminders")
        #expect(request?.value(forHTTPHeaderField: "Authorization") == "Bearer member-token")
    }
}

private actor ReminderMockHTTPDataLoader: HTTPDataLoading {
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
