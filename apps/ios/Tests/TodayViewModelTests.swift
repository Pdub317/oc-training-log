import Foundation
import Testing
@testable import OCTrainingLog

@MainActor
struct TodayViewModelTests {
    @Test func keepsOnlyAuthorizedTrackResponses() async {
        let loader = StubTodayLoader(results: [
            .sportsPerformance: .failure(TodayAPIError.trackAccessDenied),
            .generalPopulation: .success(.noProgramming(noProgrammingResponse)),
        ])
        let model = TodayViewModel()

        await model.load(using: loader)

        guard case .loaded(let responses) = model.state else {
            Issue.record("Expected an authorized Today response")
            return
        }
        #expect(responses.count == 1)
        #expect(responses.first?.track.code == .generalPopulation)
    }

    @Test func distinguishesNoMembershipFromNetworkFailure() async {
        let noMembershipLoader = StubTodayLoader(results: [
            .sportsPerformance: .failure(TodayAPIError.trackAccessDenied),
            .generalPopulation: .failure(TodayAPIError.trackAccessDenied),
        ])
        let noMembershipModel = TodayViewModel()
        await noMembershipModel.load(using: noMembershipLoader)
        #expect(
            noMembershipModel.state == .failed(
                "No active training track was found for this account."
            )
        )

        let offlineLoader = StubTodayLoader(results: [
            .sportsPerformance: .failure(TodayAPIError.unavailable),
            .generalPopulation: .failure(TodayAPIError.unavailable),
        ])
        let offlineModel = TodayViewModel()
        await offlineModel.load(using: offlineLoader)
        #expect(
            offlineModel.state == .failed(
                "Today's workout is temporarily unavailable. Check your connection and try again."
            )
        )
    }

    @Test func acceptsFractionalWeightsWithoutRounding() async {
        let model = TodayViewModel()
        let published = publishedResponse
        let movementId = published.programmingDay.blocks[0].movements[0].id

        model.setWeightText("53.25", for: movementId)
        #expect(model.canSubmit(published) == true)
    }

    @Test func validatesVariableWeightAndMaxRepEntries() async {
        let variable = publishedResponse(for: .weightedVariableReps)
        let variableMovementId = variable.programmingDay.blocks[0].movements[0].id
        let variableModel = TodayViewModel()
        variableModel.setWeightText("225.5", for: variableMovementId)
        variableModel.setCompletedRepsText("7", for: variableMovementId)
        #expect(variableModel.canSubmit(variable))

        let completer = StubWorkoutCompleter(results: [.success(completionResponse)])
        await variableModel.complete(variable, using: completer)
        #expect(completer.requests.first?.results.first?.weightLb == 225.5)
        #expect(completer.requests.first?.results.first?.completedReps == 7)

        let maxReps = publishedResponse(for: .maxRepetitions)
        let maxRepMovementId = maxReps.programmingDay.blocks[0].movements[0].id
        let maxRepModel = TodayViewModel()
        maxRepModel.setCompletedRepsText("42", for: maxRepMovementId)
        #expect(maxRepModel.canSubmit(maxReps))
        maxRepModel.setCompletedRepsText("4.2", for: maxRepMovementId)
        #expect(!maxRepModel.canSubmit(maxReps))
    }

    @Test func normalizesTimeAndPreservesMeasurementUnits() async {
        let timed = publishedResponse(for: .forTime)
        let timedMovementId = timed.programmingDay.blocks[0].movements[0].id
        let timedModel = TodayViewModel()
        timedModel.setDurationText("03:21:05.5", for: timedMovementId)
        #expect(timedModel.canSubmit(timed))

        let timedCompleter = StubWorkoutCompleter(results: [.success(completionResponse)])
        await timedModel.complete(timed, using: timedCompleter)
        #expect(timedCompleter.requests.first?.results.first?.durationMs == 12_065_500)

        timedModel.setDurationText("21:60", for: timedMovementId)
        #expect(!timedModel.canSubmit(timed))

        let measured = publishedResponse(for: .heightOrDistance)
        let measuredMovementId = measured.programmingDay.blocks[0].movements[0].id
        let measuredModel = TodayViewModel()
        measuredModel.setMeasurementText("24.25", for: measuredMovementId)
        measuredModel.setMeasurementUnit(.inches, for: measuredMovementId)
        #expect(measuredModel.canSubmit(measured))

        let measuredCompleter = StubWorkoutCompleter(results: [.success(completionResponse)])
        await measuredModel.complete(measured, using: measuredCompleter)
        #expect(measuredCompleter.requests.first?.results.first?.measurement?.value == 24.25)
        #expect(measuredCompleter.requests.first?.results.first?.measurement?.unit == .inches)
    }

    @Test func preservesActivityUnitsAndRoundsPlusReps() async {
        let activity = publishedResponse(for: .caloriesOrDistance)
        let movementId = activity.programmingDay.blocks[0].movements[0].id
        let activityModel = TodayViewModel()
        activityModel.setActivityResultText("1.25", for: movementId)
        activityModel.setActivityResultUnit(.kilometers, for: movementId)
        #expect(activityModel.canSubmit(activity))

        let activityCompleter = StubWorkoutCompleter(results: [.success(completionResponse)])
        await activityModel.complete(activity, using: activityCompleter)
        #expect(activityCompleter.requests.first?.results.first?.activityResult?.value == 1.25)
        #expect(activityCompleter.requests.first?.results.first?.activityResult?.unit == .kilometers)

        let amrap = publishedResponse(for: .roundsAndReps)
        let amrapModel = TodayViewModel()
        amrapModel.setCompletedRoundsText("7", for: movementId)
        amrapModel.setResidualRepsText("12", for: movementId)
        #expect(amrapModel.canSubmit(amrap))
        let amrapCompleter = StubWorkoutCompleter(results: [.success(completionResponse)])
        await amrapModel.complete(amrap, using: amrapCompleter)
        #expect(amrapCompleter.requests.first?.results.first?.roundsAndReps?.rounds == 7)
        #expect(amrapCompleter.requests.first?.results.first?.roundsAndReps?.reps == 12)

        amrapModel.setCompletedRoundsText("0", for: movementId)
        amrapModel.setResidualRepsText("0", for: movementId)
        #expect(!amrapModel.canSubmit(amrap))
    }

    @Test func completesNotesOnlyProgrammingWithWorkoutNotes() async {
        let notesOnly = publishedResponse(for: .notesOnly)
        let model = TodayViewModel()
        model.setNotesText("Recovery felt good.", for: notesOnly.programmingDay.id)
        #expect(model.supportsCompletion(notesOnly))
        #expect(model.canSubmit(notesOnly))

        let completer = StubWorkoutCompleter(results: [.success(completionResponse)])
        await model.complete(notesOnly, using: completer)
        #expect(completer.requests.first?.results == [])
        #expect(completer.requests.first?.notes == "Recovery felt good.")
    }

    @Test func completesFreeTextWorkoutWhenNoProgrammingIsPublished() async {
        let response = noProgrammingResponse
        let model = TodayViewModel()
        model.setFreeTextTitle("Trail run", for: response.track.id)
        model.setFreeTextNotes("Ran easy for 30 minutes.", for: response.track.id)
        #expect(model.canSubmitFreeText(response))

        let completer = StubFreeTextWorkoutCompleter()
        await model.completeFreeText(response, using: completer)

        #expect(model.completionState(for: response.track.id) == .completed)
        #expect(completer.requests.first?.trackCode == .generalPopulation)
        #expect(completer.requests.first?.workoutDate == response.workoutDate)
        #expect(completer.requests.first?.title == "Trail run")
        #expect(completer.requests.first?.notes == "Ran easy for 30 minutes.")
    }

    @Test func freeTextDraftSurvivesRestartAndOfflineRequestSynchronizes() async {
        let ownerId = UUID()
        let response = noProgrammingResponse
        let loader = StubTodayLoader(
            results: [
                .sportsPerformance: .failure(TodayAPIError.trackAccessDenied),
                .generalPopulation: .success(.noProgramming(response)),
            ],
            draftOwnerId: ownerId
        )
        let drafts = MemoryFreeTextWorkoutDraftStore()
        let queue = MemoryFreeTextWorkoutQueueStore()
        let firstModel = TodayViewModel(
            freeTextDraftStore: drafts,
            freeTextQueueStore: queue
        )
        await firstModel.load(using: loader)
        firstModel.setFreeTextTitle("Trail run", for: response.track.id)
        firstModel.setFreeTextNotes("  Ran easy for 30 minutes.\n", for: response.track.id)
        let unavailable = StubFreeTextWorkoutCompleter(
            results: [.failure(TodayAPIError.unavailable)]
        )
        await firstModel.completeFreeText(response, using: unavailable)

        #expect(firstModel.completionState(for: response.track.id) == .queued)
        let queuedRequest = try! #require(queue.workouts(ownerId: ownerId).first?.request)
        #expect(queuedRequest.notes == "  Ran easy for 30 minutes.\n")

        let restoredModel = TodayViewModel(
            freeTextDraftStore: drafts,
            freeTextQueueStore: queue
        )
        await restoredModel.load(using: loader)
        #expect(restoredModel.freeTextTitle(for: response.track.id) == "Trail run")
        #expect(restoredModel.freeTextNotes(for: response.track.id) == "  Ran easy for 30 minutes.\n")
        #expect(restoredModel.completionState(for: response.track.id) == .queued)

        let successful = StubFreeTextWorkoutCompleter()
        await restoredModel.retryQueuedFreeTextWorkouts(using: successful)
        #expect(successful.requests.first == queuedRequest)
        #expect(queue.workouts(ownerId: ownerId).isEmpty)
        #expect(
            drafts.load(
                ownerId: ownerId,
                trackId: response.track.id,
                workoutDate: response.workoutDate
            ) == nil
        )
        #expect(restoredModel.completionState(for: response.track.id) == .completed)
    }

    @Test func restoresExactTimeAndMeasurementDraftText() async {
        let ownerId = UUID()
        let store = MemoryWorkoutDraftStore()
        let measured = publishedResponse(for: .heightOrDistance)
        let movementId = measured.programmingDay.blocks[0].movements[0].id
        let loader = StubTodayLoader(
            results: [
                .sportsPerformance: .failure(TodayAPIError.trackAccessDenied),
                .generalPopulation: .success(.published(measured)),
            ],
            draftOwnerId: ownerId
        )
        let firstModel = TodayViewModel(draftStore: store)
        await firstModel.load(using: loader)
        firstModel.setMeasurementText("6.50", for: movementId)
        firstModel.setMeasurementUnit(.feet, for: movementId)

        let restoredModel = TodayViewModel(draftStore: store)
        await restoredModel.load(using: loader)
        #expect(restoredModel.measurementText(for: movementId) == "6.50")
        #expect(restoredModel.measurementUnit(for: movementId) == .feet)

        let timed = publishedResponse(for: .forTime)
        let timedLoader = StubTodayLoader(
            results: [
                .sportsPerformance: .failure(TodayAPIError.trackAccessDenied),
                .generalPopulation: .success(.published(timed)),
            ],
            draftOwnerId: UUID()
        )
        let timedModel = TodayViewModel(draftStore: store)
        await timedModel.load(using: timedLoader)
        timedModel.setDurationText("03:21:05.5", for: movementId)
        let restoredTimedModel = TodayViewModel(draftStore: store)
        await restoredTimedModel.load(using: timedLoader)
        #expect(restoredTimedModel.durationText(for: movementId) == "03:21:05.5")
    }

    @Test func completesWorkoutAndKeepsAStableRetryIdentifier() async {
        let model = TodayViewModel()
        let published = publishedResponse
        let movementId = published.programmingDay.blocks[0].movements[0].id
        let completer = StubWorkoutCompleter(
            results: [
                .failure(TodayAPIError.unavailable),
                .success(completionResponse),
            ]
        )
        model.setWeightText("53.5", for: movementId)
        model.setNotesText("Felt steady.", for: published.programmingDay.id)

        await model.complete(published, using: completer)
        guard case .failed = model.completionState(for: published.programmingDay.id) else {
            Issue.record("Expected the first save to fail")
            return
        }

        await model.complete(published, using: completer)
        #expect(model.completionState(for: published.programmingDay.id) == .completed)
        #expect(completer.requests.count == 2)
        #expect(completer.requests[0].clientRequestId == completer.requests[1].clientRequestId)
        #expect(completer.requests[1].results.first?.weightLb == 53.5)
        #expect(completer.requests[1].notes == "Felt steady.")
    }

    @Test func autosavesAndRestoresDraftForTheSignedInMember() async {
        let ownerId = UUID(uuidString: "80000000-0000-4000-8000-000000000001")!
        let store = MemoryWorkoutDraftStore()
        let published = publishedResponse
        let loader = StubTodayLoader(
            results: [
                .sportsPerformance: .failure(TodayAPIError.trackAccessDenied),
                .generalPopulation: .success(.published(published)),
            ],
            draftOwnerId: ownerId
        )
        let firstModel = TodayViewModel(draftStore: store)
        await firstModel.load(using: loader)
        let movementId = published.programmingDay.blocks[0].movements[0].id

        firstModel.setWeightText("53.5", for: movementId)
        firstModel.setNotesText("Keep this exact note.", for: published.programmingDay.id)

        let saved = store.load(
            ownerId: ownerId,
            programmingDayId: published.programmingDay.id
        )
        #expect(saved?.weightEntries[movementId.uuidString.lowercased()] == "53.5")
        #expect(saved?.notes == "Keep this exact note.")

        let restoredModel = TodayViewModel(draftStore: store)
        await restoredModel.load(using: loader)
        #expect(restoredModel.weightText(for: movementId) == "53.5")
        #expect(restoredModel.notesText(for: published.programmingDay.id) == "Keep this exact note.")
    }

    @Test func clearsInMemoryDraftWhenAnotherMemberSignsIn() async {
        let firstOwnerId = UUID()
        let secondOwnerId = UUID()
        let store = MemoryWorkoutDraftStore()
        let published = publishedResponse
        let firstLoader = StubTodayLoader(
            results: [
                .sportsPerformance: .failure(TodayAPIError.trackAccessDenied),
                .generalPopulation: .success(.published(published)),
            ],
            draftOwnerId: firstOwnerId
        )
        let secondLoader = StubTodayLoader(
            results: [
                .sportsPerformance: .failure(TodayAPIError.trackAccessDenied),
                .generalPopulation: .success(.published(published)),
            ],
            draftOwnerId: secondOwnerId
        )
        let model = TodayViewModel(draftStore: store)
        await model.load(using: firstLoader)
        let movementId = published.programmingDay.blocks[0].movements[0].id

        model.setWeightText("187.5", for: movementId)
        model.setNotesText("Private note", for: published.programmingDay.id)
        await model.load(using: secondLoader)

        #expect(model.weightText(for: movementId).isEmpty)
        #expect(model.notesText(for: published.programmingDay.id).isEmpty)
        #expect(
            store.load(
                ownerId: firstOwnerId,
                programmingDayId: published.programmingDay.id
            ) != nil
        )
    }

    @Test func offlineCompletionSurvivesRestartAndSynchronizesExactRequest() async {
        let ownerId = UUID(uuidString: "80000000-0000-4000-8000-000000000002")!
        let store = MemoryWorkoutDraftStore()
        let queue = MemoryWorkoutCompletionQueueStore()
        let published = publishedResponse
        let loader = StubTodayLoader(
            results: [
                .sportsPerformance: .failure(TodayAPIError.trackAccessDenied),
                .generalPopulation: .success(.published(published)),
            ],
            draftOwnerId: ownerId
        )
        let firstModel = TodayViewModel(
            draftStore: store,
            completionQueueStore: queue
        )
        await firstModel.load(using: loader)
        let movementId = published.programmingDay.blocks[0].movements[0].id
        firstModel.setWeightText("60", for: movementId)
        let failedCompleter = StubWorkoutCompleter(
            results: [.failure(TodayAPIError.unavailable)]
        )

        await firstModel.complete(published, using: failedCompleter)
        let firstRequestId = try! #require(failedCompleter.requests.first?.clientRequestId)
        #expect(firstModel.completionState(for: published.programmingDay.id) == .queued)
        #expect(queue.completions(ownerId: ownerId).first?.request.clientRequestId == firstRequestId)
        #expect(
            store.load(ownerId: ownerId, programmingDayId: published.programmingDay.id)?
                .clientRequestId == firstRequestId
        )

        let restoredModel = TodayViewModel(
            draftStore: store,
            completionQueueStore: queue
        )
        await restoredModel.load(using: loader)
        #expect(restoredModel.completionState(for: published.programmingDay.id) == .queued)
        let successfulCompleter = StubWorkoutCompleter(
            results: [.success(completionResponse)]
        )
        await restoredModel.retryQueuedCompletions(using: successfulCompleter)

        #expect(successfulCompleter.requests.first?.clientRequestId == firstRequestId)
        #expect(
            store.load(ownerId: ownerId, programmingDayId: published.programmingDay.id) == nil
        )
        #expect(queue.completions(ownerId: ownerId).isEmpty)
        #expect(restoredModel.completionState(for: published.programmingDay.id) == .completed)
    }

    @Test func synchronizationConflictPersistsAndIsNotRetried() async {
        let ownerId = UUID()
        let store = MemoryWorkoutDraftStore()
        let queue = MemoryWorkoutCompletionQueueStore()
        let published = publishedResponse
        let loader = StubTodayLoader(
            results: [
                .sportsPerformance: .failure(TodayAPIError.trackAccessDenied),
                .generalPopulation: .success(.published(published)),
            ],
            draftOwnerId: ownerId
        )
        let model = TodayViewModel(
            draftStore: store,
            completionQueueStore: queue
        )
        await model.load(using: loader)
        let movementId = published.programmingDay.blocks[0].movements[0].id
        model.setWeightText("60", for: movementId)
        await model.complete(
            published,
            using: StubWorkoutCompleter(results: [.failure(TodayAPIError.unavailable)])
        )

        let conflictCompleter = StubWorkoutCompleter(
            results: [.failure(TodayAPIError.completionConflict)]
        )
        await model.retryQueuedCompletions(using: conflictCompleter)
        #expect(model.completionState(for: published.programmingDay.id) == .conflict)
        #expect(queue.completions(ownerId: ownerId).first?.status == .conflict)

        let skippedCompleter = StubWorkoutCompleter(results: [])
        await model.retryQueuedCompletions(using: skippedCompleter)
        #expect(skippedCompleter.requests.isEmpty)
    }

    @Test func requestedCompletedWorkoutLoadsAsCompleted() async {
        let completed = PublishedToday(
            workoutDate: publishedResponse.workoutDate,
            timeZone: publishedResponse.timeZone,
            track: publishedResponse.track,
            isCompleted: true,
            programmingDay: publishedResponse.programmingDay
        )
        let loader = StubTodayLoader(results: [
            .sportsPerformance: .failure(TodayAPIError.trackAccessDenied),
            .generalPopulation: .success(.published(completed)),
        ])
        let model = TodayViewModel()

        await model.load(workoutDate: "2026-09-02", using: loader)

        #expect(loader.requestedDates == ["2026-09-02", "2026-09-02"])
        #expect(model.completionState(for: completed.programmingDay.id) == .completed)
    }

    @Test func selectableOptionsRequireOneValidSelectedResult() throws {
        let response = try JSONDecoder().decode(PublishedToday.self, from: Data(#"""
        {
          "workoutDate":"2026-09-14","timeZone":"America/Los_Angeles",
          "track":{"id":"00000000-0000-0000-0000-000000000202","code":"GP","name":"General Population"},
          "isCompleted":false,
          "programmingDay":{"id":"00000000-0000-0000-0000-000000000831","title":"Monostructural Test","coachNotes":null,"blocks":[{
            "id":"00000000-0000-0000-0000-000000001204","type":"wod","title":"WOD","instructions":null,"displayOrder":0,"movements":[
              {"id":"00000000-0000-0000-0000-000000001405","movementId":null,"name":"1k Row","prescriptionText":"1k row for time","coachNotes":null,"substitutions":[],"optionGroupKey":"mono","optionGroupLabel":"Select each option completed","resultSchema":"for_time","displayOrder":0},
              {"id":"00000000-0000-0000-0000-000000001423","movementId":null,"name":"4-minute Assault Bike","prescriptionText":"4-minute assault bike for max calories","coachNotes":null,"substitutions":[],"optionGroupKey":"mono","optionGroupLabel":"Select each option completed","resultSchema":"calories_or_distance","displayOrder":1}
            ]
          }]}
        }
        """#.utf8))
        let row = response.programmingDay.blocks[0].movements[0]
        let bike = response.programmingDay.blocks[0].movements[1]
        let model = TodayViewModel()

        #expect(!model.canSubmit(response))
        model.setOptionSelected(true, for: row.id)
        model.setDurationText("03:30", for: row.id)
        #expect(model.canSubmit(response))
        model.setOptionSelected(true, for: bike.id)
        #expect(!model.canSubmit(response))
        model.setActivityResultText("42", for: bike.id)
        #expect(model.canSubmit(response))
    }

    private var noProgrammingResponse: NoProgrammingToday {
        NoProgrammingToday(
            workoutDate: "2026-09-01",
            timeZone: "America/Los_Angeles",
            track: TodayTrack(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
                code: .generalPopulation,
                name: "General Population"
            ),
            isCompleted: false,
            canCreateFreeText: true
        )
    }

    private var publishedResponse: PublishedToday {
        publishedResponse(for: .weightedFixedReps)
    }

    private func publishedResponse(for resultSchema: ResultSchemaType) -> PublishedToday {
        PublishedToday(
            workoutDate: "2026-09-02",
            timeZone: "America/Los_Angeles",
            track: TodayTrack(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
                code: .generalPopulation,
                name: "General Population"
            ),
            isCompleted: false,
            programmingDay: TodayProgrammingDay(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000822")!,
                title: "GP Suitcase Deadlift and Zone 2",
                coachNotes: nil,
                blocks: [
                    TodayWorkoutBlock(
                        id: UUID(),
                        type: .strength,
                        title: "Strength",
                        instructions: nil,
                        displayOrder: 0,
                        movements: [
                            TodayMovement(
                                id: UUID(
                                    uuidString: "00000000-0000-0000-0000-000000001312"
                                )!,
                                movementId: nil,
                                name: "Kettlebell Suitcase Deadlift",
                                prescriptionText: "4x10",
                                coachNotes: nil,
                                substitutions: [],
                                resultSchema: resultSchema,
                                displayOrder: 0
                            )
                        ]
                    )
                ]
            )
        )
    }

    private var completionResponse: WorkoutCompletionResponse {
        WorkoutCompletionResponse(
            state: "completed",
            workoutLogId: UUID(),
            completedAt: "2026-09-02T18:30:00.000Z",
            replayed: false,
            results: [],
            personalRecords: []
        )
    }
}

@MainActor
private final class StubTodayLoader: TodayLoading {
    private let results: [TrainingTrack: Result<TodayResponse, Error>]
    let draftOwnerId: UUID?
    private(set) var requestedDates: [String?] = []

    init(
        results: [TrainingTrack: Result<TodayResponse, Error>],
        draftOwnerId: UUID? = nil
    ) {
        self.results = results
        self.draftOwnerId = draftOwnerId
    }

    func loadToday(
        for track: TrainingTrack,
        workoutDate: String?
    ) async throws -> TodayResponse {
        requestedDates.append(workoutDate)
        return try results[track]!.get()
    }
}

private final class MemoryWorkoutDraftStore: WorkoutDraftStoring {
    private var values: [String: WorkoutDraft] = [:]

    func load(ownerId: UUID, programmingDayId: UUID) -> WorkoutDraft? {
        values[key(ownerId, programmingDayId)]
    }

    func save(_ draft: WorkoutDraft, ownerId: UUID, programmingDayId: UUID) {
        values[key(ownerId, programmingDayId)] = draft
    }

    func delete(ownerId: UUID, programmingDayId: UUID) {
        values.removeValue(forKey: key(ownerId, programmingDayId))
    }

    private func key(_ ownerId: UUID, _ programmingDayId: UUID) -> String {
        "\(ownerId):\(programmingDayId)"
    }
}

private final class MemoryWorkoutCompletionQueueStore: WorkoutCompletionQueueStoring {
    private var values: [String: QueuedWorkoutCompletion] = [:]

    func completions(ownerId: UUID) -> [QueuedWorkoutCompletion] {
        let prefix = "\(ownerId):"
        return values.filter { $0.key.hasPrefix(prefix) }.map(\.value)
    }

    func save(_ completion: QueuedWorkoutCompletion, ownerId: UUID) {
        values[key(ownerId, completion.request.programmingDayId)] = completion
    }

    func delete(ownerId: UUID, programmingDayId: UUID) {
        values.removeValue(forKey: key(ownerId, programmingDayId))
    }

    private func key(_ ownerId: UUID, _ programmingDayId: UUID) -> String {
        "\(ownerId):\(programmingDayId)"
    }
}

private final class MemoryFreeTextWorkoutDraftStore: FreeTextWorkoutDraftStoring {
    private var values: [String: FreeTextWorkoutDraft] = [:]

    func load(ownerId: UUID, trackId: UUID, workoutDate: String) -> FreeTextWorkoutDraft? {
        values[key(ownerId, trackId, workoutDate)]
    }

    func save(
        _ draft: FreeTextWorkoutDraft,
        ownerId: UUID,
        trackId: UUID,
        workoutDate: String
    ) {
        values[key(ownerId, trackId, workoutDate)] = draft
    }

    func delete(ownerId: UUID, trackId: UUID, workoutDate: String) {
        values.removeValue(forKey: key(ownerId, trackId, workoutDate))
    }

    private func key(_ ownerId: UUID, _ trackId: UUID, _ workoutDate: String) -> String {
        "\(ownerId):\(trackId):\(workoutDate)"
    }
}

private final class MemoryFreeTextWorkoutQueueStore: FreeTextWorkoutQueueStoring {
    private var values: [String: QueuedFreeTextWorkout] = [:]

    func workouts(ownerId: UUID) -> [QueuedFreeTextWorkout] {
        let prefix = "\(ownerId):"
        return values.filter { $0.key.hasPrefix(prefix) }.map(\.value)
    }

    func save(_ workout: QueuedFreeTextWorkout, ownerId: UUID) {
        values[key(ownerId, workout.trackId, workout.request.workoutDate)] = workout
    }

    func delete(ownerId: UUID, trackId: UUID, workoutDate: String) {
        values.removeValue(forKey: key(ownerId, trackId, workoutDate))
    }

    private func key(_ ownerId: UUID, _ trackId: UUID, _ workoutDate: String) -> String {
        "\(ownerId):\(trackId):\(workoutDate)"
    }
}

@MainActor
private final class StubWorkoutCompleter: WorkoutCompleting {
    private var results: [Result<WorkoutCompletionResponse, Error>]
    private(set) var requests: [WorkoutCompletionRequest] = []

    init(results: [Result<WorkoutCompletionResponse, Error>]) {
        self.results = results
    }

    func completeWorkout(
        _ request: WorkoutCompletionRequest
    ) async throws -> WorkoutCompletionResponse {
        requests.append(request)
        return try results.removeFirst().get()
    }
}

@MainActor
private final class StubFreeTextWorkoutCompleter: FreeTextWorkoutCompleting {
    private var results: [Result<WorkoutCompletionResponse, Error>]
    private(set) var requests: [FreeTextWorkoutRequest] = []

    init(results: [Result<WorkoutCompletionResponse, Error>] = []) {
        self.results = results
    }

    func completeFreeTextWorkout(
        _ request: FreeTextWorkoutRequest
    ) async throws -> WorkoutCompletionResponse {
        requests.append(request)
        if !results.isEmpty { return try results.removeFirst().get() }
        return WorkoutCompletionResponse(
            state: "completed",
            workoutLogId: UUID(),
            completedAt: "2026-09-02T18:30:00.000Z",
            replayed: false,
            results: [],
            personalRecords: []
        )
    }
}
