import Foundation

struct PersonalRecordListResponse: Decodable, Equatable, Identifiable, Sendable {
    let track: TodayTrack
    let benchmarks: [PersonalRecordBenchmark]
    var id: UUID { track.id }
}

struct PersonalRecordBenchmark: Decodable, Equatable, Identifiable, Sendable {
    let benchmarkId: UUID
    let label: String
    let resultSchema: ResultSchemaType
    let comparisonDirection: String
    let currentBests: [PersonalRecordScore]
    var id: UUID { benchmarkId }
}

struct PersonalRecordScore: Decodable, Equatable, Identifiable, Sendable {
    let personalRecordId: UUID
    let value: Double
    let unit: String
    let completedReps: Int?
    let achievedAt: String
    var id: UUID { personalRecordId }

    var formattedValue: String {
        switch unit {
        case "lb":
            let suffix = completedReps.map { " × \($0) reps" } ?? ""
            return "\(Self.number(value)) lb\(suffix)"
        case "reps": return "\(Int(value)) reps"
        case "ms": return Self.duration(Int(value))
        case "in": return "\(Self.number(value)) in"
        case "cal": return "\(Self.number(value)) cal"
        case "m": return "\(Self.number(value)) m"
        case "rounds_reps":
            let total = Int(value)
            return "\(total / 100_000) rounds + \(total % 100_000) reps"
        default: return Self.number(value)
        }
    }

    var percentageRows: [(percentage: Int, pounds: Int)] {
        guard unit == "lb" else { return [] }
        return stride(from: 50, through: 95, by: 5).map {
            ($0, Int((value * Double($0) / 100).rounded()))
        }
    }

    private static func number(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%g", value)
    }

    private static func duration(_ milliseconds: Int) -> String {
        let total = milliseconds / 1_000
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        let tenths = (milliseconds % 1_000) / 100
        let suffix = tenths == 0 ? "" : ".\(tenths)"
        return hours > 0
            ? String(format: "%d:%02d:%02d%@", hours, minutes, seconds, suffix)
            : String(format: "%02d:%02d%@", minutes, seconds, suffix)
    }
}

struct PersonalRecordDetailResponse: Decodable, Equatable, Sendable {
    let track: TodayTrack
    let benchmark: PersonalRecordBenchmark
    let history: [PersonalRecordHistoryEntry]
}

struct PersonalRecordHistoryEntry: Decodable, Equatable, Identifiable, Sendable {
    let personalRecordId: UUID
    let value: Double
    let unit: String
    let completedReps: Int?
    let achievedAt: String
    let workoutLogId: UUID
    let workoutDate: String
    let workoutTitle: String
    let isCurrentBest: Bool
    var id: UUID { personalRecordId }
    var score: PersonalRecordScore {
        PersonalRecordScore(
            personalRecordId: personalRecordId,
            value: value,
            unit: unit,
            completedReps: completedReps,
            achievedAt: achievedAt
        )
    }
}

@MainActor
protocol PersonalRecordsLoading: AnyObject {
    func loadPersonalRecords(for track: TrainingTrack) async throws -> PersonalRecordListResponse
    func loadPersonalRecordDetail(
        for track: TrainingTrack,
        benchmarkId: UUID
    ) async throws -> PersonalRecordDetailResponse
}

extension AuthenticationModel: PersonalRecordsLoading {}

@MainActor
protocol PersonalRecordSourceWorkoutLoading: AnyObject {
    func loadWorkout(
        for track: TrainingTrack,
        workoutLogId: UUID
    ) async throws -> HistoryWorkout
}

extension AuthenticationModel: PersonalRecordSourceWorkoutLoading {}

@MainActor
final class PersonalRecordsViewModel: ObservableObject {
    enum State: Equatable { case idle, loading, loaded([PersonalRecordListResponse]), failed(String) }
    @Published private(set) var state: State = .idle
    @Published var searchText = ""

    var filteredResponses: [PersonalRecordListResponse] {
        guard case .loaded(let responses) = state else { return [] }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return responses }
        return responses.map {
            PersonalRecordListResponse(
                track: $0.track,
                benchmarks: $0.benchmarks.filter {
                    $0.label.localizedCaseInsensitiveContains(query)
                }
            )
        }
    }

    func load(using loader: any PersonalRecordsLoading) async {
        state = .loading
        var responses: [PersonalRecordListResponse] = []
        var firstError: Error?
        for track in TrainingTrack.allCases {
            do { responses.append(try await loader.loadPersonalRecords(for: track)) }
            catch TodayAPIError.trackAccessDenied { continue }
            catch { if firstError == nil { firstError = error } }
        }
        if !responses.isEmpty { state = .loaded(responses) }
        else if firstError != nil { state = .failed("We couldn't load personal records.") }
        else { state = .failed("No active training track was found for this account.") }
    }
}

@MainActor
final class PersonalRecordDetailViewModel: ObservableObject {
    enum State: Equatable { case idle, loading, loaded(PersonalRecordDetailResponse), failed(String) }
    @Published private(set) var state: State = .idle

    func load(
        track: TrainingTrack,
        benchmarkId: UUID,
        using loader: any PersonalRecordsLoading
    ) async {
        state = .loading
        do { state = .loaded(try await loader.loadPersonalRecordDetail(for: track, benchmarkId: benchmarkId)) }
        catch { state = .failed("We couldn't load this record history.") }
    }
}

@MainActor
final class PersonalRecordSourceWorkoutViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded(HistoryWorkout)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    func load(
        track: TrainingTrack,
        workoutLogId: UUID,
        using loader: any PersonalRecordSourceWorkoutLoading
    ) async {
        state = .loading
        do {
            state = .loaded(
                try await loader.loadWorkout(for: track, workoutLogId: workoutLogId)
            )
        } catch {
            state = .failed("We couldn't load the source workout.")
        }
    }
}
