import Foundation

enum ReminderWeekday: Int, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case monday = 1
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        case .sunday: "Sunday"
        }
    }
}

struct ReminderSchedule: Codable, Equatable, Sendable {
    let weekday: ReminderWeekday
    let localTime: String
}

struct ReminderSettingsResponse: Codable, Equatable, Sendable {
    let timeZone: String
    let schedules: [ReminderSchedule]
}

typealias UpdateReminderSettingsRequest = ReminderSettingsResponse

@MainActor
protocol ReminderSettingsLoading: AnyObject {
    func loadReminderSettings() async throws -> ReminderSettingsResponse
    func updateReminderSettings(_ request: UpdateReminderSettingsRequest) async throws
        -> ReminderSettingsResponse
}

extension AuthenticationModel: ReminderSettingsLoading {}

@MainActor
final class ReminderSettingsViewModel: ObservableObject {
    enum State: Equatable { case idle, loading, loaded, failed(String) }

    @Published private(set) var state: State = .idle
    @Published private(set) var times: [ReminderWeekday: Date] = [:]
    @Published var applyToAllTime = ReminderSettingsViewModel.date(hour: 18, minute: 0)
    @Published private(set) var saving = false
    @Published private(set) var statusMessage: String?
    private(set) var timeZone = TimeZone.current.identifier

    var hasSelectedDays: Bool { !times.isEmpty }

    func isSelected(_ weekday: ReminderWeekday) -> Bool {
        times[weekday] != nil
    }

    func time(for weekday: ReminderWeekday) -> Date {
        times[weekday] ?? applyToAllTime
    }

    func setSelected(_ selected: Bool, weekday: ReminderWeekday) {
        if selected {
            times[weekday] = times[weekday] ?? applyToAllTime
        } else {
            times.removeValue(forKey: weekday)
        }
        statusMessage = nil
    }

    func setTime(_ value: Date, weekday: ReminderWeekday) {
        guard times[weekday] != nil else { return }
        times[weekday] = value
        statusMessage = nil
    }

    func applyTimeToSelectedDays() {
        for weekday in times.keys {
            times[weekday] = applyToAllTime
        }
        statusMessage = nil
    }

    func load(using loader: any ReminderSettingsLoading) async {
        state = .loading
        statusMessage = nil
        do {
            apply(try await loader.loadReminderSettings())
            state = .loaded
        } catch {
            state = .failed("We couldn't load reminder settings.")
        }
    }

    func save(using loader: any ReminderSettingsLoading) async {
        saving = true
        statusMessage = nil
        defer { saving = false }
        let schedules = ReminderWeekday.allCases.compactMap { weekday in
            times[weekday].map {
                ReminderSchedule(weekday: weekday, localTime: Self.localTime($0))
            }
        }
        do {
            apply(
                try await loader.updateReminderSettings(
                    UpdateReminderSettingsRequest(
                        timeZone: TimeZone.current.identifier,
                        schedules: schedules
                    )
                )
            )
            statusMessage = schedules.isEmpty ? "Reminders turned off." : "Reminder schedule saved."
            state = .loaded
        } catch {
            statusMessage = "We couldn't save reminder settings. Please try again."
        }
    }

    private func apply(_ settings: ReminderSettingsResponse) {
        timeZone = settings.timeZone
        times = Dictionary(
            uniqueKeysWithValues: settings.schedules.compactMap { schedule in
                Self.date(schedule.localTime).map { (schedule.weekday, $0) }
            }
        )
    }

    private static func localTime(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    private static func date(_ localTime: String) -> Date? {
        let values = localTime.split(separator: ":").compactMap { Int($0) }
        guard values.count == 2 else { return nil }
        return date(hour: values[0], minute: values[1])
    }

    private static func date(hour: Int, minute: Int) -> Date {
        Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Date()
        ) ?? Date()
    }
}
