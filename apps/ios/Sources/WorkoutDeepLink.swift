import Foundation

struct WorkoutDeepLink: Equatable, Sendable {
    static let scheme = "octraininglog"

    let workoutDate: String

    init?(url: URL) {
        guard
            url.scheme?.lowercased() == Self.scheme,
            url.host?.lowercased() == "log",
            url.path.isEmpty || url.path == "/",
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }

        let dateItems = (components.queryItems ?? []).filter { $0.name == "date" }
        guard
            dateItems.count == 1,
            let date = dateItems[0].value,
            Self.isValidWorkoutDate(date)
        else { return nil }

        workoutDate = date
    }

    init?(workoutDate: String) {
        guard Self.isValidWorkoutDate(workoutDate) else { return nil }
        self.workoutDate = workoutDate
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = "log"
        components.queryItems = [URLQueryItem(name: "date", value: workoutDate)]
        return components.url!
    }

    private static func isValidWorkoutDate(_ value: String) -> Bool {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value) else { return false }
        return formatter.string(from: date) == value
    }
}

@MainActor
final class WorkoutDeepLinkRouter: ObservableObject {
    static let shared = WorkoutDeepLinkRouter()

    @Published private(set) var pendingWorkoutDate: String?

    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard let link = WorkoutDeepLink(url: url) else { return false }
        pendingWorkoutDate = link.workoutDate
        return true
    }

    @discardableResult
    func handle(workoutDate: String) -> Bool {
        guard let link = WorkoutDeepLink(workoutDate: workoutDate) else { return false }
        pendingWorkoutDate = link.workoutDate
        return true
    }

    func consumeWorkoutDate() -> String? {
        defer { pendingWorkoutDate = nil }
        return pendingWorkoutDate
    }
}
