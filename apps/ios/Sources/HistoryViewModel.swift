import Foundation

@MainActor
protocol HistoryLoading: AnyObject {
    func loadHistory(
        for track: TrainingTrack,
        query: String?,
        fromDate: String?,
        personalRecordsOnly: Bool,
        cursor: String?
    ) async throws -> HistoryResponse
}

extension AuthenticationModel: HistoryLoading {}

@MainActor
protocol HistoryEditing: AnyObject {
    func editWorkout(_ request: WorkoutEditRequest) async throws -> WorkoutEditResponse
    func editFreeTextWorkout(
        _ request: FreeTextWorkoutEditRequest
    ) async throws -> WorkoutEditResponse
}

extension AuthenticationModel: HistoryEditing {}

enum HistoryDateRange: String, CaseIterable, Identifiable, Equatable {
    case all
    case thirtyDays
    case ninetyDays
    case oneYear

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All dates"
        case .thirtyDays: "30 days"
        case .ninetyDays: "90 days"
        case .oneYear: "1 year"
        }
    }

    var dayCount: Int? {
        switch self {
        case .all: nil
        case .thirtyDays: 30
        case .ninetyDays: 90
        case .oneYear: 365
        }
    }
}

@MainActor
final class HistoryViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded([HistoryResponse])
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published var searchText = ""
    @Published var dateRange: HistoryDateRange = .all
    @Published var personalRecordsOnly = false
    @Published private(set) var loadingMoreTrackIds: Set<UUID> = []
    @Published private(set) var paginationMessage: String?
    private var appliedQuery: String?
    private var appliedFromDate: String?
    private var appliedPersonalRecordsOnly = false

    var responses: [HistoryResponse] {
        if case .loaded(let responses) = state { return responses }
        return []
    }

    func load(using loader: any HistoryLoading, referenceDate: Date = Date()) async {
        state = .loading
        paginationMessage = nil
        var responses: [HistoryResponse] = []
        var firstError: Error?
        let query = normalizedQuery
        let fromDate = cutoffDate(referenceDate: referenceDate)
        appliedQuery = query
        appliedFromDate = fromDate
        appliedPersonalRecordsOnly = personalRecordsOnly

        for track in TrainingTrack.allCases {
            do {
                responses.append(try await loader.loadHistory(
                    for: track,
                    query: query,
                    fromDate: fromDate,
                    personalRecordsOnly: personalRecordsOnly,
                    cursor: nil
                ))
            } catch TodayAPIError.trackAccessDenied {
                continue
            } catch {
                if firstError == nil { firstError = error }
            }
        }

        if !responses.isEmpty {
            state = .loaded(responses)
        } else if firstError != nil {
            state = .failed("We couldn't load workout history. Check your connection and try again.")
        } else {
            state = .failed("No active training track was found for this account.")
        }
    }

    func loadMore(for response: HistoryResponse, using loader: any HistoryLoading) async {
        guard
            let cursor = response.nextCursor,
            !loadingMoreTrackIds.contains(response.track.id)
        else { return }
        loadingMoreTrackIds.insert(response.track.id)
        paginationMessage = nil
        defer { loadingMoreTrackIds.remove(response.track.id) }
        do {
            let page = try await loader.loadHistory(
                for: response.track.code,
                query: appliedQuery,
                fromDate: appliedFromDate,
                personalRecordsOnly: appliedPersonalRecordsOnly,
                cursor: cursor
            )
            guard case .loaded(var current) = state,
                  let index = current.firstIndex(where: { $0.track.id == response.track.id })
            else { return }
            let existingIds = Set(current[index].workouts.map(\.id))
            current[index] = HistoryResponse(
                track: response.track,
                workouts: current[index].workouts + page.workouts.filter {
                    !existingIds.contains($0.id)
                },
                nextCursor: page.nextCursor
            )
            state = .loaded(current)
        } catch {
            paginationMessage = "We couldn't load more workouts. Check your connection and try again."
        }
    }

    private var normalizedQuery: String? {
        let value = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func cutoffDate(referenceDate: Date) -> String? {
        guard let days = dateRange.dayCount else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard let cutoff = calendar.date(
            byAdding: .day,
            value: -(days - 1),
            to: calendar.startOfDay(for: referenceDate)
        ) else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: cutoff)
    }

}

struct WorkoutSyncIssue: Identifiable, Equatable {
    let queued: QueuedWorkoutCompletion
    let serverWorkout: HistoryWorkout?

    var id: UUID { queued.request.programmingDayId }
}

@MainActor
final class WorkoutSyncIssuesViewModel: ObservableObject {
    enum ResolutionState: Equatable {
        case idle
        case resolving
        case failed(String)
    }

    @Published private(set) var issues: [WorkoutSyncIssue] = []
    @Published private(set) var resolutionStates: [UUID: ResolutionState] = [:]
    private let queueStore: any WorkoutCompletionQueueStoring
    private let draftStore: any WorkoutDraftStoring
    private var ownerId: UUID?

    init(
        queueStore: any WorkoutCompletionQueueStoring =
            UserDefaultsWorkoutCompletionQueueStore(),
        draftStore: any WorkoutDraftStoring = UserDefaultsWorkoutDraftStore()
    ) {
        self.queueStore = queueStore
        self.draftStore = draftStore
    }

    func load(ownerId: UUID?, historyResponses: [HistoryResponse]) {
        self.ownerId = ownerId
        guard let ownerId else {
            issues = []
            return
        }
        let workouts = historyResponses.flatMap(\.workouts)
        issues = queueStore.completions(ownerId: ownerId)
            .filter { $0.status == .conflict }
            .map { queued in
                WorkoutSyncIssue(
                    queued: queued,
                    serverWorkout: workouts.first {
                        $0.programmingDayId == queued.request.programmingDayId
                    }
                )
            }
    }

    func resolutionState(for issue: WorkoutSyncIssue) -> ResolutionState {
        resolutionStates[issue.id, default: .idle]
    }

    func keepServerVersion(_ issue: WorkoutSyncIssue) {
        guard let ownerId else { return }
        deleteLocalCopy(issue, ownerId: ownerId)
    }

    func useIPhoneVersion(
        _ issue: WorkoutSyncIssue,
        using editor: any HistoryEditing
    ) async {
        guard let ownerId, let server = issue.serverWorkout else {
            resolutionStates[issue.id] = .failed(
                "Refresh History before replacing the saved version."
            )
            return
        }
        resolutionStates[issue.id] = .resolving
        do {
            _ = try await editor.editWorkout(
                WorkoutEditRequest(
                    workoutLogId: server.workoutLogId,
                    expectedUpdatedAt: server.updatedAt,
                    notes: issue.queued.request.notes,
                    results: issue.queued.request.results
                )
            )
            deleteLocalCopy(issue, ownerId: ownerId)
        } catch TodayAPIError.workoutEditConflict {
            resolutionStates[issue.id] = .failed(
                "The saved workout changed again. Refresh and compare the latest version."
            )
        } catch TodayAPIError.unavailable {
            resolutionStates[issue.id] = .failed(
                "We couldn't resolve this yet. Check your connection and try again."
            )
        } catch {
            resolutionStates[issue.id] = .failed(
                "We couldn't resolve this workout. Refresh History and try again."
            )
        }
    }

    private func deleteLocalCopy(_ issue: WorkoutSyncIssue, ownerId: UUID) {
        queueStore.delete(ownerId: ownerId, programmingDayId: issue.id)
        draftStore.delete(ownerId: ownerId, programmingDayId: issue.id)
        issues.removeAll { $0.id == issue.id }
        resolutionStates.removeValue(forKey: issue.id)
    }
}

@MainActor
final class HistoryWorkoutEditViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case saving
        case saved
        case conflict
        case failed(String)
    }

    @Published var notes: String
    @Published var title: String
    @Published private(set) var values: [UUID: String] = [:]
    @Published private(set) var secondaryValues: [UUID: String] = [:]
    @Published private(set) var measurementUnits: [UUID: MeasurementUnit] = [:]
    @Published private(set) var activityUnits: [UUID: ActivityResultUnit] = [:]
    @Published private(set) var state: State = .idle

    let workout: HistoryWorkout

    init(workout: HistoryWorkout) {
        self.workout = workout
        title = workout.title
        notes = workout.notes ?? ""
        for movement in workout.movements {
            switch movement.resultSchema {
            case .weightedFixedReps:
                values[movement.id] = movement.weightLb.map(Self.number) ?? ""
            case .weightedVariableReps:
                values[movement.id] = movement.weightLb.map(Self.number) ?? ""
                secondaryValues[movement.id] = movement.completedReps.map(String.init) ?? ""
            case .maxRepetitions:
                values[movement.id] = movement.completedReps.map(String.init) ?? ""
            case .forTime:
                values[movement.id] = movement.durationMs.map(Self.duration) ?? ""
            case .heightOrDistance:
                values[movement.id] = movement.measurementValue.map(Self.number) ?? ""
                measurementUnits[movement.id] = movement.measurementUnit ?? .inches
            case .caloriesOrDistance:
                values[movement.id] = movement.resultValue.map(Self.number) ?? ""
                activityUnits[movement.id] = movement.resultUnit ?? .calories
            case .roundsAndReps:
                values[movement.id] = movement.completedRounds.map(String.init) ?? ""
                secondaryValues[movement.id] = movement.residualReps.map(String.init) ?? ""
            case .notesOnly:
                break
            }
        }
    }

    func value(for id: UUID) -> String { values[id, default: ""] }
    func setValue(_ value: String, for id: UUID) { values[id] = value }
    func secondaryValue(for id: UUID) -> String { secondaryValues[id, default: ""] }
    func setSecondaryValue(_ value: String, for id: UUID) { secondaryValues[id] = value }
    func measurementUnit(for id: UUID) -> MeasurementUnit { measurementUnits[id, default: .inches] }
    func setMeasurementUnit(_ unit: MeasurementUnit, for id: UUID) { measurementUnits[id] = unit }
    func activityUnit(for id: UUID) -> ActivityResultUnit { activityUnits[id, default: .calories] }
    func setActivityUnit(_ unit: ActivityResultUnit, for id: UUID) { activityUnits[id] = unit }

    var canSave: Bool {
        if workout.programmingDayId == nil {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            return state != .saving && !trimmedTitle.isEmpty && trimmedTitle.count <= 200
                && !trimmedNotes.isEmpty && notes.count <= 5_000
        }
        return state != .saving && workout.movements.allSatisfy { result(for: $0) != nil }
    }

    func save(using editor: any HistoryEditing) async {
        if workout.programmingDayId == nil {
            await saveFreeText(using: editor)
            return
        }
        let results = workout.movements.compactMap(result(for:))
        guard results.count == workout.movements.count else {
            state = .failed("Check each result and try again.")
            return
        }
        state = .saving
        do {
            _ = try await editor.editWorkout(WorkoutEditRequest(
                workoutLogId: workout.workoutLogId,
                expectedUpdatedAt: workout.updatedAt,
                notes: notes.isEmpty ? nil : notes,
                results: results
            ))
            state = .saved
        } catch TodayAPIError.workoutEditConflict {
            state = .conflict
        } catch TodayAPIError.unavailable {
            state = .failed("We couldn't save these changes. Check your connection and try again.")
        } catch {
            state = .failed("We couldn't save these changes. Refresh History and try again.")
        }
    }

    private func saveFreeText(using editor: any HistoryEditing) async {
        guard canSave else {
            state = .failed("Add a title and workout details before saving.")
            return
        }
        state = .saving
        do {
            _ = try await editor.editFreeTextWorkout(
                FreeTextWorkoutEditRequest(
                    workoutLogId: workout.workoutLogId,
                    expectedUpdatedAt: workout.updatedAt,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    notes: notes
                )
            )
            state = .saved
        } catch TodayAPIError.workoutEditConflict {
            state = .conflict
        } catch TodayAPIError.unavailable {
            state = .failed("We couldn't save these changes. Check your connection and try again.")
        } catch {
            state = .failed("We couldn't save these changes. Refresh History and try again.")
        }
    }

    private func result(for movement: HistoryMovement) -> WorkoutResultEntry? {
        let first = value(for: movement.id).trimmingCharacters(in: .whitespacesAndNewlines)
        let second = secondaryValue(for: movement.id).trimmingCharacters(in: .whitespacesAndNewlines)
        switch movement.resultSchema {
        case .weightedFixedReps:
            guard let weight = validWeight(first) else { return nil }
            return .weightedFixed(prescribedMovementId: movement.prescribedMovementId, weightLb: weight)
        case .weightedVariableReps:
            guard let weight = validWeight(first), let reps = validPositiveInt(second) else { return nil }
            return .weightedVariable(prescribedMovementId: movement.prescribedMovementId, weightLb: weight, completedReps: reps)
        case .maxRepetitions:
            guard let reps = validPositiveInt(first) else { return nil }
            return .maxRepetitions(prescribedMovementId: movement.prescribedMovementId, completedReps: reps)
        case .forTime:
            guard let duration = parseDuration(first) else { return nil }
            return .forTime(prescribedMovementId: movement.prescribedMovementId, durationMs: duration)
        case .heightOrDistance:
            guard let value = validPositiveNumber(first) else { return nil }
            return .heightOrDistance(prescribedMovementId: movement.prescribedMovementId, measurementValue: value, measurementUnit: measurementUnit(for: movement.id))
        case .caloriesOrDistance:
            guard let value = validPositiveNumber(first) else { return nil }
            return .caloriesOrDistance(prescribedMovementId: movement.prescribedMovementId, resultValue: value, resultUnit: activityUnit(for: movement.id))
        case .roundsAndReps:
            guard let rounds = validNonnegativeInt(first, maximum: 100_000),
                  let reps = validNonnegativeInt(second, maximum: 99_999), rounds + reps > 0 else { return nil }
            return .roundsAndReps(prescribedMovementId: movement.prescribedMovementId, completedRounds: rounds, residualReps: reps)
        case .notesOnly:
            return nil
        }
    }

    private func validWeight(_ text: String) -> Double? {
        guard let value = validPositiveNumber(text), value <= 100_000 else { return nil }
        return value
    }

    private func validPositiveNumber(_ text: String) -> Double? {
        guard let value = Double(text), value.isFinite, value > 0, value <= 1_000_000 else { return nil }
        return value
    }

    private func validPositiveInt(_ text: String) -> Int? {
        guard let value = Int(text), value > 0, value <= 100_000 else { return nil }
        return value
    }

    private func validNonnegativeInt(_ text: String, maximum: Int) -> Int? {
        guard let value = Int(text), value >= 0, value <= maximum else { return nil }
        return value
    }

    private func parseDuration(_ text: String) -> Int? {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2 || parts.count == 3 else { return nil }
        let hours = parts.count == 3 ? Int(parts[0]) : 0
        let minutes = Int(parts[parts.count - 2])
        let secondsParts = parts.last!.split(separator: ".", omittingEmptySubsequences: false)
        guard let hours, let minutes, hours >= 0, minutes >= 0, minutes <= 59,
              secondsParts.count <= 2, let seconds = Int(secondsParts[0]), seconds >= 0, seconds <= 59 else { return nil }
        let tenths = secondsParts.count == 2 ? Int(secondsParts[1]) : 0
        guard let tenths, (0...9).contains(tenths), secondsParts.count == 1 || secondsParts[1].count == 1 else { return nil }
        let value = ((hours * 3600 + minutes * 60 + seconds) * 1000) + tenths * 100
        return value > 0 && value <= 359_999_999 ? value : nil
    }

    private static func number(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%g", value)
    }

    private static func duration(_ milliseconds: Int) -> String {
        let total = milliseconds / 1000
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        let tenths = (milliseconds % 1000) / 100
        let suffix = tenths == 0 ? "" : ".\(tenths)"
        return hours > 0
            ? String(format: "%d:%02d:%02d%@", hours, minutes, seconds, suffix)
            : String(format: "%02d:%02d%@", minutes, seconds, suffix)
    }
}
