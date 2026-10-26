import Foundation
import Testing
@testable import OCTrainingLog

@MainActor
struct HistoryViewModelTests {
    @Test func keepsAuthorizedHistoryIncludingEmptyHistory() async {
        let loader = StubHistoryLoader(results: [
            .sportsPerformance: .failure(TodayAPIError.trackAccessDenied),
            .generalPopulation: .success(
                HistoryResponse(
                    track: TodayTrack(
                        id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
                        code: .generalPopulation,
                        name: "General Population"
                    ),
                    workouts: []
                )
            ),
        ])
        let model = HistoryViewModel()

        await model.load(using: loader)

        guard case .loaded(let responses) = model.state else {
            Issue.record("Expected authorized history")
            return
        }
        #expect(responses.count == 1)
        #expect(responses.first?.track.code == .generalPopulation)
        #expect(responses.first?.workouts.isEmpty == true)
    }

    @Test func reportsNetworkFailureWhenNoHistoryLoads() async {
        let loader = StubHistoryLoader(results: [
            .sportsPerformance: .failure(TodayAPIError.unavailable),
            .generalPopulation: .failure(TodayAPIError.trackAccessDenied),
        ])
        let model = HistoryViewModel()

        await model.load(using: loader)

        #expect(
            model.state == .failed(
                "We couldn't load workout history. Check your connection and try again."
            )
        )
    }

    @Test func sendsSearchDateAndPRFiltersToAuthorizedHistoryQuery() async throws {
        let recent = try sampleWorkout()
        let old = HistoryWorkout(
            workoutLogId: UUID(),
            programmingDayId: nil,
            workoutDate: "2025-01-01",
            completedAt: "2025-01-01T18:30:00.000Z",
            updatedAt: "2025-01-01T18:30:00.000Z",
            title: "Old trail run",
            notes: "Easy miles",
            hasPersonalRecord: false,
            movements: []
        )
        let loader = StubHistoryLoader(results: [
            .sportsPerformance: .failure(TodayAPIError.trackAccessDenied),
            .generalPopulation: .success(HistoryResponse(
                track: TodayTrack(id: UUID(), code: .generalPopulation, name: "GP"),
                workouts: [recent, old]
            )),
        ])
        let model = HistoryViewModel()
        model.searchText = "deadLIFT"
        model.dateRange = .thirtyDays
        model.personalRecordsOnly = true
        let reference = try #require(
            ISO8601DateFormatter().date(from: "2026-09-15T12:00:00Z")
        )
        await model.load(using: loader, referenceDate: reference)

        let request = try #require(loader.requests.last)
        #expect(request.query == "deadLIFT")
        #expect(request.fromDate == "2026-08-17")
        #expect(request.personalRecordsOnly)
        #expect(request.cursor == nil)
    }

    @Test func editsPrefilledResultsAndSendsExpectedVersion() async throws {
        let workout = try sampleWorkout()
        let model = HistoryWorkoutEditViewModel(workout: workout)
        let first = workout.movements[0]
        let second = workout.movements[1]
        #expect(model.value(for: first.id) == "100.5")
        #expect(model.value(for: second.id) == "7")
        #expect(model.secondaryValue(for: second.id) == "12")

        model.setValue("90.25", for: first.id)
        model.notes = "Corrected note"
        let editor = StubHistoryEditor()
        await model.save(using: editor)

        #expect(model.state == .saved)
        #expect(editor.requests.first?.expectedUpdatedAt == workout.updatedAt)
        #expect(editor.requests.first?.notes == "Corrected note")
        #expect(editor.requests.first?.results.first?.weightLb == 90.25)
        #expect(editor.requests.first?.results[1].roundsAndReps?.rounds == 7)
    }

    @Test func exposesStaleEditConflict() async throws {
        let model = HistoryWorkoutEditViewModel(workout: try sampleWorkout())
        let editor = StubHistoryEditor(error: TodayAPIError.workoutEditConflict)
        await model.save(using: editor)
        #expect(model.state == .conflict)
    }

    @Test func editsFreeTextTitleAndExactDetails() async throws {
        let data = Data(#"""
        {
          "workoutLogId":"10000000-0000-4000-8000-000000000009",
          "programmingDayId":null,
          "workoutDate":"2026-09-02",
          "completedAt":"2026-09-02T18:30:00.000Z",
          "updatedAt":"2026-09-02T18:31:00.000Z",
          "title":"Trail run",
          "notes":"Original details",
          "hasPersonalRecord":false,
          "movements":[]
        }
        """#.utf8)
        let workout = try JSONDecoder().decode(HistoryWorkout.self, from: data)
        let model = HistoryWorkoutEditViewModel(workout: workout)
        model.title = " Updated trail run "
        model.notes = "  Exact updated details\n"
        let editor = StubHistoryEditor()

        await model.save(using: editor)

        #expect(model.state == .saved)
        #expect(editor.freeTextRequests.first?.title == "Updated trail run")
        #expect(editor.freeTextRequests.first?.notes == "  Exact updated details\n")
        #expect(editor.freeTextRequests.first?.expectedUpdatedAt == workout.updatedAt)
    }

    @Test func resolvesQueuedConflictWithExplicitMemberChoice() async throws {
        let ownerId = UUID()
        let workout = try sampleWorkout()
        let queue = SyncIssueQueueStore()
        let drafts = SyncIssueDraftStore()
        let queued = QueuedWorkoutCompletion(
            request: WorkoutCompletionRequest(
                clientRequestId: UUID(),
                trackCode: .generalPopulation,
                programmingDayId: try #require(workout.programmingDayId),
                workoutDate: workout.workoutDate,
                notes: "Phone note",
                results: [
                    .weightedFixed(
                        prescribedMovementId: workout.movements[0].prescribedMovementId,
                        weightLb: 95.5
                    ),
                    .roundsAndReps(
                        prescribedMovementId: workout.movements[1].prescribedMovementId,
                        completedRounds: 8,
                        residualReps: 2
                    ),
                ]
            ),
            status: .conflict
        )
        queue.save(queued, ownerId: ownerId)
        let model = WorkoutSyncIssuesViewModel(queueStore: queue, draftStore: drafts)
        model.load(
            ownerId: ownerId,
            historyResponses: [HistoryResponse(
                track: TodayTrack(id: UUID(), code: .generalPopulation, name: "GP"),
                workouts: [workout]
            )]
        )
        let issue = try #require(model.issues.first)
        let editor = StubHistoryEditor()
        await model.useIPhoneVersion(issue, using: editor)

        #expect(editor.requests.first?.workoutLogId == workout.workoutLogId)
        #expect(editor.requests.first?.expectedUpdatedAt == workout.updatedAt)
        #expect(editor.requests.first?.results.first?.weightLb == 95.5)
        #expect(model.issues.isEmpty)
        #expect(queue.completions(ownerId: ownerId).isEmpty)
        #expect(drafts.deletedProgrammingDayId == workout.programmingDayId)
    }

    @Test func personalRecordsSearchAndPercentageTablePreserveScoreRules() async {
        let score = PersonalRecordScore(
            personalRecordId: UUID(),
            value: 187.5,
            unit: "lb",
            completedReps: 3,
            achievedAt: "2026-09-02T18:30:00.000Z"
        )
        let matching = PersonalRecordBenchmark(
            benchmarkId: UUID(),
            label: "Deficit Bench Press",
            resultSchema: .weightedVariableReps,
            comparisonDirection: "higher",
            currentBests: [score]
        )
        let loader = StubPersonalRecordsLoader(response: PersonalRecordListResponse(
            track: TodayTrack(id: UUID(), code: .generalPopulation, name: "GP"),
            benchmarks: [matching, PersonalRecordBenchmark(
                benchmarkId: UUID(),
                label: "500 m row",
                resultSchema: .forTime,
                comparisonDirection: "lower",
                currentBests: []
            )]
        ))
        let model = PersonalRecordsViewModel()
        await model.load(using: loader)
        model.searchText = "bench PRESS"

        #expect(model.filteredResponses.first?.benchmarks.map(\.label) == [matching.label])
        #expect(score.formattedValue == "187.5 lb × 3 reps")
        #expect(score.percentageRows.first?.percentage == 50)
        #expect(score.percentageRows.first?.pounds == 94)
        #expect(score.percentageRows.last?.percentage == 95)
        #expect(score.percentageRows.last?.pounds == 178)
    }

    @Test func loadsTheExactSourceWorkoutForARecordEvent() async throws {
        let workout = try sampleWorkout()
        let loader = StubSourceWorkoutLoader(workout: workout)
        let model = PersonalRecordSourceWorkoutViewModel()

        await model.load(
            track: .generalPopulation,
            workoutLogId: workout.workoutLogId,
            using: loader
        )

        #expect(model.state == .loaded(workout))
        #expect(loader.requestedTrack == .generalPopulation)
        #expect(loader.requestedWorkoutLogId == workout.workoutLogId)
    }

    private func sampleWorkout() throws -> HistoryWorkout {
        let data = Data(#"""
        {
          "workoutLogId":"10000000-0000-4000-8000-000000000001",
          "programmingDayId":"20000000-0000-4000-8000-000000000001",
          "workoutDate":"2026-09-02",
          "completedAt":"2026-09-02T18:30:00.000Z",
          "updatedAt":"2026-09-02T18:31:00.000Z",
          "title":"Editable workout",
          "notes":"Original",
          "hasPersonalRecord":true,
          "movements":[
            {
              "movementResultId":"30000000-0000-4000-8000-000000000001",
              "prescribedMovementId":"40000000-0000-4000-8000-000000000001",
              "name":"Deadlift","prescriptionText":"4x5","blockType":"strength",
              "resultSchema":"weighted_fixed_reps","weightLb":100.5,"isPersonalRecord":true
            },
            {
              "movementResultId":"30000000-0000-4000-8000-000000000002",
              "prescribedMovementId":"40000000-0000-4000-8000-000000000002",
              "name":"AMRAP","prescriptionText":"10 minutes","blockType":"wod",
              "resultSchema":"rounds_and_reps","completedRounds":7,"residualReps":12,
              "isPersonalRecord":false
            }
          ]
        }
        """#.utf8)
        return try JSONDecoder().decode(HistoryWorkout.self, from: data)
    }
}

private final class SyncIssueQueueStore: WorkoutCompletionQueueStoring {
    private var stored: [UUID: [QueuedWorkoutCompletion]] = [:]
    func completions(ownerId: UUID) -> [QueuedWorkoutCompletion] { stored[ownerId] ?? [] }
    func save(_ completion: QueuedWorkoutCompletion, ownerId: UUID) {
        var values = stored[ownerId] ?? []
        values.removeAll { $0.request.programmingDayId == completion.request.programmingDayId }
        values.append(completion)
        stored[ownerId] = values
    }
    func delete(ownerId: UUID, programmingDayId: UUID) {
        stored[ownerId]?.removeAll { $0.request.programmingDayId == programmingDayId }
    }
}

private final class SyncIssueDraftStore: WorkoutDraftStoring {
    private(set) var deletedProgrammingDayId: UUID?
    func load(ownerId: UUID, programmingDayId: UUID) -> WorkoutDraft? { nil }
    func save(_ draft: WorkoutDraft, ownerId: UUID, programmingDayId: UUID) {}
    func delete(ownerId: UUID, programmingDayId: UUID) {
        deletedProgrammingDayId = programmingDayId
    }
}

@MainActor
private final class StubHistoryLoader: HistoryLoading {
    struct Request {
        let track: TrainingTrack
        let query: String?
        let fromDate: String?
        let personalRecordsOnly: Bool
        let cursor: String?
    }

    private let results: [TrainingTrack: Result<HistoryResponse, Error>]
    private(set) var requests: [Request] = []

    init(results: [TrainingTrack: Result<HistoryResponse, Error>]) {
        self.results = results
    }

    func loadHistory(
        for track: TrainingTrack,
        query: String?,
        fromDate: String?,
        personalRecordsOnly: Bool,
        cursor: String?
    ) async throws -> HistoryResponse {
        requests.append(Request(
            track: track,
            query: query,
            fromDate: fromDate,
            personalRecordsOnly: personalRecordsOnly,
            cursor: cursor
        ))
        return try results[track]!.get()
    }
}

@MainActor
private final class StubHistoryEditor: HistoryEditing {
    private let error: Error?
    private(set) var requests: [WorkoutEditRequest] = []
    private(set) var freeTextRequests: [FreeTextWorkoutEditRequest] = []

    init(error: Error? = nil) { self.error = error }

    func editWorkout(_ request: WorkoutEditRequest) async throws -> WorkoutEditResponse {
        requests.append(request)
        if let error { throw error }
        return WorkoutEditResponse(
            state: "updated",
            workoutLogId: request.workoutLogId,
            updatedAt: "2026-09-02T18:32:00.000Z"
        )
    }

    func editFreeTextWorkout(
        _ request: FreeTextWorkoutEditRequest
    ) async throws -> WorkoutEditResponse {
        freeTextRequests.append(request)
        if let error { throw error }
        return WorkoutEditResponse(
            state: "updated",
            workoutLogId: request.workoutLogId,
            updatedAt: "2026-09-02T18:32:00.000Z"
        )
    }
}

@MainActor
private final class StubPersonalRecordsLoader: PersonalRecordsLoading {
    let response: PersonalRecordListResponse
    init(response: PersonalRecordListResponse) { self.response = response }
    func loadPersonalRecords(for track: TrainingTrack) async throws -> PersonalRecordListResponse {
        if track != response.track.code { throw TodayAPIError.trackAccessDenied }
        return response
    }
    func loadPersonalRecordDetail(
        for track: TrainingTrack,
        benchmarkId: UUID
    ) async throws -> PersonalRecordDetailResponse {
        throw TodayAPIError.unavailable
    }
}

@MainActor
private final class StubSourceWorkoutLoader: PersonalRecordSourceWorkoutLoading {
    let workout: HistoryWorkout
    private(set) var requestedTrack: TrainingTrack?
    private(set) var requestedWorkoutLogId: UUID?

    init(workout: HistoryWorkout) {
        self.workout = workout
    }

    func loadWorkout(
        for track: TrainingTrack,
        workoutLogId: UUID
    ) async throws -> HistoryWorkout {
        requestedTrack = track
        requestedWorkoutLogId = workoutLogId
        return workout
    }
}
