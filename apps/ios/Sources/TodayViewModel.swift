import Foundation

@MainActor
protocol TodayLoading: AnyObject {
    var draftOwnerId: UUID? { get }
    func loadToday(
        for track: TrainingTrack,
        workoutDate: String?
    ) async throws -> TodayResponse
}

extension TodayLoading {
    var draftOwnerId: UUID? { nil }
}

extension AuthenticationModel: TodayLoading {}

@MainActor
protocol WorkoutCompleting: AnyObject {
    func completeWorkout(
        _ request: WorkoutCompletionRequest
    ) async throws -> WorkoutCompletionResponse
}

extension AuthenticationModel: WorkoutCompleting {}

@MainActor
protocol FreeTextWorkoutCompleting: AnyObject {
    func completeFreeTextWorkout(
        _ request: FreeTextWorkoutRequest
    ) async throws -> WorkoutCompletionResponse
}

extension AuthenticationModel: FreeTextWorkoutCompleting {}

@MainActor
final class TodayViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded([TodayResponse])
        case failed(String)
    }

    enum CompletionState: Equatable {
        case idle
        case submitting
        case queued
        case completed
        case conflict
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var weightEntries: [UUID: String] = [:]
    @Published private(set) var completedRepEntries: [UUID: String] = [:]
    @Published private(set) var durationEntries: [UUID: String] = [:]
    @Published private(set) var measurementEntries: [UUID: String] = [:]
    @Published private(set) var measurementUnitEntries: [UUID: MeasurementUnit] = [:]
    @Published private(set) var activityResultEntries: [UUID: String] = [:]
    @Published private(set) var activityResultUnitEntries: [UUID: ActivityResultUnit] = [:]
    @Published private(set) var completedRoundEntries: [UUID: String] = [:]
    @Published private(set) var residualRepEntries: [UUID: String] = [:]
    @Published private(set) var selectedOptionIds: Set<UUID> = []
    @Published private(set) var workoutNotes: [UUID: String] = [:]
    @Published private(set) var completionStates: [UUID: CompletionState] = [:]
    @Published private(set) var newPersonalRecords: [UUID: [String]] = [:]
    @Published private(set) var freeTextTitles: [UUID: String] = [:]
    @Published private(set) var freeTextNotes: [UUID: String] = [:]
    private let draftStore: any WorkoutDraftStoring
    private let completionQueueStore: any WorkoutCompletionQueueStoring
    private let freeTextDraftStore: any FreeTextWorkoutDraftStoring
    private let freeTextQueueStore: any FreeTextWorkoutQueueStoring
    private var requestIds: [UUID: UUID] = [:]
    private var programmingDayByMovement: [UUID: UUID] = [:]
    private var freeTextDateByTrack: [UUID: String] = [:]
    private var activeDraftOwnerId: UUID?

    init(
        draftStore: any WorkoutDraftStoring = UserDefaultsWorkoutDraftStore(),
        completionQueueStore: any WorkoutCompletionQueueStoring =
            UserDefaultsWorkoutCompletionQueueStore(),
        freeTextDraftStore: any FreeTextWorkoutDraftStoring =
            UserDefaultsFreeTextWorkoutDraftStore(),
        freeTextQueueStore: any FreeTextWorkoutQueueStoring =
            UserDefaultsFreeTextWorkoutQueueStore()
    ) {
        self.draftStore = draftStore
        self.completionQueueStore = completionQueueStore
        self.freeTextDraftStore = freeTextDraftStore
        self.freeTextQueueStore = freeTextQueueStore
    }

    func weightText(for movementId: UUID) -> String {
        weightEntries[movementId, default: ""]
    }

    func setWeightText(_ value: String, for movementId: UUID) {
        weightEntries[movementId] = value
        if let programmingDayId = programmingDayByMovement[movementId] {
            persistDraft(for: programmingDayId)
        }
    }

    func completedRepsText(for movementId: UUID) -> String {
        completedRepEntries[movementId, default: ""]
    }

    func setCompletedRepsText(_ value: String, for movementId: UUID) {
        completedRepEntries[movementId] = value
        if let programmingDayId = programmingDayByMovement[movementId] {
            persistDraft(for: programmingDayId)
        }
    }

    func durationText(for movementId: UUID) -> String {
        durationEntries[movementId, default: ""]
    }

    func setDurationText(_ value: String, for movementId: UUID) {
        durationEntries[movementId] = value
        persistMovementDraft(movementId)
    }

    func measurementText(for movementId: UUID) -> String {
        measurementEntries[movementId, default: ""]
    }

    func setMeasurementText(_ value: String, for movementId: UUID) {
        measurementEntries[movementId] = value
        persistMovementDraft(movementId)
    }

    func measurementUnit(for movementId: UUID) -> MeasurementUnit {
        measurementUnitEntries[movementId, default: .inches]
    }

    func setMeasurementUnit(_ value: MeasurementUnit, for movementId: UUID) {
        measurementUnitEntries[movementId] = value
        persistMovementDraft(movementId)
    }

    func activityResultText(for movementId: UUID) -> String {
        activityResultEntries[movementId, default: ""]
    }

    func setActivityResultText(_ value: String, for movementId: UUID) {
        activityResultEntries[movementId] = value
        persistMovementDraft(movementId)
    }

    func activityResultUnit(for movementId: UUID) -> ActivityResultUnit {
        activityResultUnitEntries[movementId, default: .calories]
    }

    func setActivityResultUnit(_ value: ActivityResultUnit, for movementId: UUID) {
        activityResultUnitEntries[movementId] = value
        persistMovementDraft(movementId)
    }

    func completedRoundsText(for movementId: UUID) -> String {
        completedRoundEntries[movementId, default: ""]
    }

    func setCompletedRoundsText(_ value: String, for movementId: UUID) {
        completedRoundEntries[movementId] = value
        persistMovementDraft(movementId)
    }

    func residualRepsText(for movementId: UUID) -> String {
        residualRepEntries[movementId, default: ""]
    }

    func setResidualRepsText(_ value: String, for movementId: UUID) {
        residualRepEntries[movementId] = value
        persistMovementDraft(movementId)
    }

    func isOptionSelected(_ movementId: UUID) -> Bool {
        selectedOptionIds.contains(movementId)
    }

    func setOptionSelected(_ selected: Bool, for movementId: UUID) {
        if selected {
            selectedOptionIds.insert(movementId)
        } else {
            selectedOptionIds.remove(movementId)
        }
        persistMovementDraft(movementId)
    }

    func notesText(for programmingDayId: UUID) -> String {
        workoutNotes[programmingDayId, default: ""]
    }

    func setNotesText(_ value: String, for programmingDayId: UUID) {
        workoutNotes[programmingDayId] = value
        persistDraft(for: programmingDayId)
    }

    func completionState(for programmingDayId: UUID) -> CompletionState {
        completionStates[programmingDayId, default: .idle]
    }

    func freeTextTitle(for trackId: UUID) -> String {
        freeTextTitles[trackId, default: "My workout"]
    }

    func setFreeTextTitle(_ value: String, for trackId: UUID) {
        freeTextTitles[trackId] = value
        persistFreeTextDraft(for: trackId)
    }

    func freeTextNotes(for trackId: UUID) -> String {
        freeTextNotes[trackId, default: ""]
    }

    func setFreeTextNotes(_ value: String, for trackId: UUID) {
        freeTextNotes[trackId] = value
        persistFreeTextDraft(for: trackId)
    }

    func canSubmitFreeText(_ response: NoProgrammingToday) -> Bool {
        let title = freeTextTitle(for: response.track.id).trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = freeTextNotes(for: response.track.id).trimmingCharacters(in: .whitespacesAndNewlines)
        return !title.isEmpty && title.count <= 200 && !notes.isEmpty && notes.count <= 5_000
            && completionState(for: response.track.id) == .idle
    }

    func completeFreeText(
        _ response: NoProgrammingToday,
        using completer: any FreeTextWorkoutCompleting
    ) async {
        guard canSubmitFreeText(response) else { return }
        let key = response.track.id
        let requestId = requestIds[key] ?? UUID()
        requestIds[key] = requestId
        persistFreeTextDraft(for: key)
        completionStates[key] = .submitting
        let request = FreeTextWorkoutRequest(
            clientRequestId: requestId,
            trackCode: response.track.code,
            workoutDate: response.workoutDate,
            title: freeTextTitle(for: key).trimmingCharacters(in: .whitespacesAndNewlines),
            notes: freeTextNotes(for: key)
        )
        do {
            _ = try await completer.completeFreeTextWorkout(request)
            completionStates[key] = .completed
            deleteFreeTextLocalCopies(for: key, workoutDate: response.workoutDate)
        } catch let error as TodayAPIError {
            if error == .unavailable, let ownerId = activeDraftOwnerId {
                freeTextQueueStore.save(
                    QueuedFreeTextWorkout(trackId: key, request: request, status: .pending),
                    ownerId: ownerId
                )
                completionStates[key] = .queued
            } else if error == .completionConflict, let ownerId = activeDraftOwnerId {
                freeTextQueueStore.save(
                    QueuedFreeTextWorkout(trackId: key, request: request, status: .conflict),
                    ownerId: ownerId
                )
                completionStates[key] = .conflict
            } else {
                completionStates[key] = .failed(completionMessage(for: error))
            }
        } catch {
            completionStates[key] = .failed("We couldn't save this workout. Please try again.")
        }
    }

    func supportsCompletion(_ published: PublishedToday) -> Bool {
        let movements = published.programmingDay.blocks.flatMap(\.movements)
        let scoreable = movements.filter { $0.resultSchema != .notesOnly }
        return !movements.isEmpty && scoreable.allSatisfy {
            [
                .weightedFixedReps,
                .weightedVariableReps,
                .maxRepetitions,
                .forTime,
                .heightOrDistance,
                .caloriesOrDistance,
                .roundsAndReps,
            ]
                .contains($0.resultSchema)
        }
    }

    func canSubmit(_ published: PublishedToday) -> Bool {
        guard supportsCompletion(published) else { return false }
        guard hasSelectionForEveryOptionGroup(in: published) else { return false }
        let valid = scoreableMovements(in: published).allSatisfy { movement in
            switch movement.resultSchema {
            case .weightedFixedReps:
                parsedWeight(weightText(for: movement.id)) != nil
            case .weightedVariableReps:
                parsedWeight(weightText(for: movement.id)) != nil
                    && parsedCompletedReps(completedRepsText(for: movement.id)) != nil
            case .maxRepetitions:
                parsedCompletedReps(completedRepsText(for: movement.id)) != nil
            case .forTime:
                parsedDurationMilliseconds(durationText(for: movement.id)) != nil
            case .heightOrDistance:
                parsedMeasurement(measurementText(for: movement.id)) != nil
            case .caloriesOrDistance:
                parsedActivityResult(activityResultText(for: movement.id)) != nil
            case .roundsAndReps:
                parsedRoundsAndReps(
                    rounds: completedRoundsText(for: movement.id),
                    reps: residualRepsText(for: movement.id)
                ) != nil
            default:
                false
            }
        }
        return valid && completionState(for: published.programmingDay.id) == .idle
    }

    func complete(
        _ published: PublishedToday,
        using completer: any WorkoutCompleting
    ) async {
        guard supportsCompletion(published),
              hasSelectionForEveryOptionGroup(in: published) else { return }

        let movements = scoreableMovements(in: published)
        let entries = movements.compactMap(resultEntry(for:))
        guard entries.count == movements.count else {
            completionStates[published.programmingDay.id] = .failed(
                "Check each entered result and try again."
            )
            return
        }

        completionStates[published.programmingDay.id] = .submitting
        let requestId = requestIds[published.programmingDay.id] ?? UUID()
        requestIds[published.programmingDay.id] = requestId
        persistDraft(for: published.programmingDay.id)
        let notes = notesText(for: published.programmingDay.id)
        let request = WorkoutCompletionRequest(
            clientRequestId: requestId,
            trackCode: published.track.code,
            programmingDayId: published.programmingDay.id,
            workoutDate: published.workoutDate,
            notes: notes.isEmpty ? nil : notes,
            results: entries
        )

        do {
            let response = try await completer.completeWorkout(request)
            newPersonalRecords[published.programmingDay.id] = response.personalRecords.map(
                \.benchmarkLabel
            )
            completionStates[published.programmingDay.id] = .completed
            if let ownerId = activeDraftOwnerId {
                completionQueueStore.delete(
                    ownerId: ownerId,
                    programmingDayId: published.programmingDay.id
                )
                draftStore.delete(
                    ownerId: ownerId,
                    programmingDayId: published.programmingDay.id
                )
            }
        } catch let error as TodayAPIError {
            if error == .unavailable, let ownerId = activeDraftOwnerId {
                completionQueueStore.save(
                    QueuedWorkoutCompletion(request: request, status: .pending),
                    ownerId: ownerId
                )
                completionStates[published.programmingDay.id] = .queued
            } else if error == .completionConflict, let ownerId = activeDraftOwnerId {
                completionQueueStore.save(
                    QueuedWorkoutCompletion(request: request, status: .conflict),
                    ownerId: ownerId
                )
                completionStates[published.programmingDay.id] = .conflict
            } else {
                completionStates[published.programmingDay.id] = .failed(
                    completionMessage(for: error)
                )
            }
        } catch {
            completionStates[published.programmingDay.id] = .failed(
                "We couldn't save this workout. Please try again."
            )
        }
    }

    func load(
        workoutDate: String? = nil,
        using loader: any TodayLoading
    ) async {
        resetMemberState()
        state = .loading
        activeDraftOwnerId = loader.draftOwnerId
        var responses: [TodayResponse] = []
        var firstUnexpectedError: Error?

        for track in TrainingTrack.allCases {
            do {
                responses.append(
                    try await loader.loadToday(for: track, workoutDate: workoutDate)
                )
            } catch TodayAPIError.trackAccessDenied {
                continue
            } catch {
                if firstUnexpectedError == nil {
                    firstUnexpectedError = error
                }
            }
        }

        if !responses.isEmpty {
            restoreDrafts(in: responses)
            restoreQueuedCompletionStates()
            restoreFreeTextDrafts(in: responses)
            restoreQueuedFreeTextStates()
            for response in responses where response.isCompleted {
                completionStates[response.completionKey] = .completed
            }
            state = .loaded(responses)
        } else if let error = firstUnexpectedError as? TodayAPIError {
            state = .failed(message(for: error))
        } else if firstUnexpectedError != nil {
            state = .failed("We couldn't load today's workout. Please try again.")
        } else {
            state = .failed("No active training track was found for this account.")
        }
    }

    func retryQueuedCompletions(using completer: any WorkoutCompleting) async {
        guard let ownerId = activeDraftOwnerId else { return }

        for queued in completionQueueStore.completions(ownerId: ownerId) {
            guard queued.status == .pending else {
                completionStates[queued.request.programmingDayId] = .conflict
                continue
            }

            completionStates[queued.request.programmingDayId] = .submitting
            do {
                let response = try await completer.completeWorkout(queued.request)
                completionQueueStore.delete(
                    ownerId: ownerId,
                    programmingDayId: queued.request.programmingDayId
                )
                draftStore.delete(
                    ownerId: ownerId,
                    programmingDayId: queued.request.programmingDayId
                )
                newPersonalRecords[queued.request.programmingDayId] = response.personalRecords.map(
                    \.benchmarkLabel
                )
                completionStates[queued.request.programmingDayId] = .completed
            } catch let error as TodayAPIError {
                if error == .completionConflict {
                    completionQueueStore.save(
                        QueuedWorkoutCompletion(request: queued.request, status: .conflict),
                        ownerId: ownerId
                    )
                    completionStates[queued.request.programmingDayId] = .conflict
                    continue
                }
                if error == .unavailable {
                    completionStates[queued.request.programmingDayId] = .queued
                    return
                }
                completionStates[queued.request.programmingDayId] = .failed(
                    completionMessage(for: error)
                )
                return
            } catch {
                completionStates[queued.request.programmingDayId] = .queued
                return
            }
        }
    }

    func retryQueuedFreeTextWorkouts(using completer: any FreeTextWorkoutCompleting) async {
        guard let ownerId = activeDraftOwnerId else { return }

        for queued in freeTextQueueStore.workouts(ownerId: ownerId) {
            guard queued.status == .pending else {
                completionStates[queued.trackId] = .conflict
                continue
            }
            completionStates[queued.trackId] = .submitting
            do {
                _ = try await completer.completeFreeTextWorkout(queued.request)
                deleteFreeTextLocalCopies(
                    for: queued.trackId,
                    workoutDate: queued.request.workoutDate
                )
                completionStates[queued.trackId] = .completed
            } catch let error as TodayAPIError {
                if error == .completionConflict {
                    freeTextQueueStore.save(
                        QueuedFreeTextWorkout(
                            trackId: queued.trackId,
                            request: queued.request,
                            status: .conflict
                        ),
                        ownerId: ownerId
                    )
                    completionStates[queued.trackId] = .conflict
                    continue
                }
                if error == .unavailable {
                    completionStates[queued.trackId] = .queued
                    return
                }
                completionStates[queued.trackId] = .failed(completionMessage(for: error))
                return
            } catch {
                completionStates[queued.trackId] = .queued
                return
            }
        }
    }

    private func message(for error: TodayAPIError) -> String {
        switch error {
        case .unauthorized:
            "Your session has expired. Sign out and sign in again."
        case .unavailable:
            "Today's workout is temporarily unavailable. Check your connection and try again."
        case .invalidData, .invalidResponse, .invalidRequest, .unexpectedStatus:
            "We couldn't load today's workout. Please try again."
        case .trackAccessDenied:
            "No active training track was found for this account."
        case .invalidEntry:
            "Check the entered results and try again."
        case .completionConflict, .workoutEditConflict:
            "This workout was already saved with different results."
        }
    }

    private func scoreableMovements(in published: PublishedToday) -> [TodayMovement] {
        published.programmingDay.blocks
            .flatMap(\.movements)
            .filter {
                $0.resultSchema != .notesOnly
                    && ($0.optionGroupKey == nil || selectedOptionIds.contains($0.id))
            }
    }

    private func hasSelectionForEveryOptionGroup(in published: PublishedToday) -> Bool {
        let allScoreable = published.programmingDay.blocks
            .flatMap(\.movements)
            .filter { $0.resultSchema != .notesOnly }
        let grouped = Dictionary(grouping: allScoreable.filter {
            $0.optionGroupKey != nil
        }, by: { $0.optionGroupKey! })
        return grouped.values.allSatisfy { options in
            options.contains { selectedOptionIds.contains($0.id) }
        }
    }

    private func resultEntry(for movement: TodayMovement) -> WorkoutResultEntry? {
        switch movement.resultSchema {
        case .weightedFixedReps:
            parsedWeight(weightText(for: movement.id)).map {
                .weightedFixed(prescribedMovementId: movement.id, weightLb: $0)
            }
        case .weightedVariableReps:
            if let weight = parsedWeight(weightText(for: movement.id)),
               let reps = parsedCompletedReps(completedRepsText(for: movement.id)) {
                .weightedVariable(
                    prescribedMovementId: movement.id,
                    weightLb: weight,
                    completedReps: reps
                )
            } else {
                nil
            }
        case .maxRepetitions:
            parsedCompletedReps(completedRepsText(for: movement.id)).map {
                .maxRepetitions(prescribedMovementId: movement.id, completedReps: $0)
            }
        case .forTime:
            parsedDurationMilliseconds(durationText(for: movement.id)).map {
                .forTime(prescribedMovementId: movement.id, durationMs: $0)
            }
        case .heightOrDistance:
            parsedMeasurement(measurementText(for: movement.id)).map {
                .heightOrDistance(
                    prescribedMovementId: movement.id,
                    measurementValue: $0,
                    measurementUnit: measurementUnit(for: movement.id)
                )
            }
        case .caloriesOrDistance:
            parsedActivityResult(activityResultText(for: movement.id)).map {
                .caloriesOrDistance(
                    prescribedMovementId: movement.id,
                    resultValue: $0,
                    resultUnit: activityResultUnit(for: movement.id)
                )
            }
        case .roundsAndReps:
            parsedRoundsAndReps(
                rounds: completedRoundsText(for: movement.id),
                reps: residualRepsText(for: movement.id)
            ).map {
                .roundsAndReps(
                    prescribedMovementId: movement.id,
                    completedRounds: $0.rounds,
                    residualReps: $0.reps
                )
            }
        default:
            nil
        }
    }

    private func parsedWeight(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmed.isEmpty,
            let weight = Double(trimmed),
            weight.isFinite,
            weight > 0,
            weight <= 100_000
        else {
            return nil
        }
        return weight
    }

    private func parsedCompletedReps(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let reps = Int(trimmed), reps > 0, reps <= 100_000 else { return nil }
        return reps
    }

    private func parsedDurationMilliseconds(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        guard components.count == 2 || components.count == 3 else { return nil }

        let hours: Int
        let minutesIndex: Int
        if components.count == 3 {
            guard
                let parsedHours = Int(components[0]),
                parsedHours >= 0,
                parsedHours <= 99
            else {
                return nil
            }
            hours = parsedHours
            minutesIndex = 1
        } else {
            hours = 0
            minutesIndex = 0
        }
        guard
            let minutes = Int(components[minutesIndex]),
            minutes >= 0,
            minutes <= 59
        else {
            return nil
        }

        let secondParts = components.last!.split(
            separator: ".",
            omittingEmptySubsequences: false
        )
        guard
            secondParts.count == 1 || secondParts.count == 2,
            let seconds = Int(secondParts[0]),
            seconds >= 0,
            seconds <= 59
        else {
            return nil
        }
        let tenths: Int
        if secondParts.count == 2 {
            guard secondParts[1].count == 1, let parsedTenths = Int(secondParts[1]) else {
                return nil
            }
            tenths = parsedTenths
        } else {
            tenths = 0
        }

        let milliseconds = ((hours * 3600 + minutes * 60 + seconds) * 1000) + tenths * 100
        guard milliseconds > 0, milliseconds <= 359_999_999 else { return nil }
        return milliseconds
    }

    private func parsedMeasurement(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let value = Double(trimmed),
            value.isFinite,
            value > 0,
            value <= 1_000_000
        else {
            return nil
        }
        return value
    }

    private func parsedActivityResult(_ text: String) -> Double? {
        parsedMeasurement(text)
    }

    private func parsedRoundsAndReps(
        rounds: String,
        reps: String
    ) -> (rounds: Int, reps: Int)? {
        let trimmedRounds = rounds.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReps = reps.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let roundsValue = Int(trimmedRounds),
            let repsValue = Int(trimmedReps),
            roundsValue >= 0,
            roundsValue <= 100_000,
            repsValue >= 0,
            repsValue <= 99_999,
            roundsValue > 0 || repsValue > 0
        else {
            return nil
        }
        return (roundsValue, repsValue)
    }

    private func completionMessage(for error: TodayAPIError) -> String {
        switch error {
        case .invalidEntry:
            "Check that every weight is a positive number."
        case .completionConflict, .workoutEditConflict:
            "This workout is already saved with different results. Refresh before trying again."
        case .unauthorized:
            "Your session has expired. Sign out and sign in again."
        case .trackAccessDenied:
            "You no longer have access to this workout."
        case .unavailable:
            "We couldn't save this workout. Check your connection and try again."
        case .invalidData, .invalidResponse, .invalidRequest, .unexpectedStatus:
            "We couldn't save this workout. Please try again."
        }
    }

    private func restoreDrafts(in responses: [TodayResponse]) {
        programmingDayByMovement = [:]

        for response in responses {
            guard case .published(let published) = response else { continue }
            let programmingDayId = published.programmingDay.id
            let movementIds = Set(
                published.programmingDay.blocks.flatMap(\.movements).map(\.id)
            )
            for movementId in movementIds {
                programmingDayByMovement[movementId] = programmingDayId
            }

            guard
                let ownerId = activeDraftOwnerId,
                let draft = draftStore.load(
                    ownerId: ownerId,
                    programmingDayId: programmingDayId
                )
            else {
                continue
            }

            for (movementIdText, value) in draft.weightEntries {
                guard
                    let movementId = UUID(uuidString: movementIdText),
                    movementIds.contains(movementId)
                else {
                    continue
                }
                weightEntries[movementId] = value
            }
            for (movementIdText, value) in draft.completedRepEntries {
                guard
                    let movementId = UUID(uuidString: movementIdText),
                    movementIds.contains(movementId)
                else {
                    continue
                }
                completedRepEntries[movementId] = value
            }
            restore(draft.durationEntries, into: &durationEntries, allowedIds: movementIds)
            restore(draft.measurementEntries, into: &measurementEntries, allowedIds: movementIds)
            for (movementIdText, value) in draft.measurementUnitEntries {
                guard
                    let movementId = UUID(uuidString: movementIdText),
                    movementIds.contains(movementId)
                else {
                    continue
                }
                measurementUnitEntries[movementId] = value
            }
            restore(
                draft.activityResultEntries,
                into: &activityResultEntries,
                allowedIds: movementIds
            )
            for (movementIdText, value) in draft.activityResultUnitEntries {
                guard let movementId = UUID(uuidString: movementIdText),
                      movementIds.contains(movementId) else { continue }
                activityResultUnitEntries[movementId] = value
            }
            restore(
                draft.completedRoundEntries,
                into: &completedRoundEntries,
                allowedIds: movementIds
            )
            restore(
                draft.residualRepEntries,
                into: &residualRepEntries,
                allowedIds: movementIds
            )
            selectedOptionIds.formUnion(draft.selectedOptionIds.compactMap { value in
                guard let id = UUID(uuidString: value), movementIds.contains(id) else {
                    return nil
                }
                return id
            })
            workoutNotes[programmingDayId] = draft.notes
            requestIds[programmingDayId] = draft.clientRequestId
        }
    }

    private func restoreQueuedCompletionStates() {
        guard let ownerId = activeDraftOwnerId else { return }
        for queued in completionQueueStore.completions(ownerId: ownerId) {
            completionStates[queued.request.programmingDayId] =
                queued.status == .pending ? .queued : .conflict
        }
    }

    private func restoreFreeTextDrafts(in responses: [TodayResponse]) {
        guard let ownerId = activeDraftOwnerId else { return }
        for response in responses {
            guard case .noProgramming(let day) = response else { continue }
            freeTextDateByTrack[day.track.id] = day.workoutDate
            guard let draft = freeTextDraftStore.load(
                ownerId: ownerId,
                trackId: day.track.id,
                workoutDate: day.workoutDate
            ) else { continue }
            freeTextTitles[day.track.id] = draft.title
            freeTextNotes[day.track.id] = draft.notes
            requestIds[day.track.id] = draft.clientRequestId
        }
    }

    private func restoreQueuedFreeTextStates() {
        guard let ownerId = activeDraftOwnerId else { return }
        for queued in freeTextQueueStore.workouts(ownerId: ownerId) {
            completionStates[queued.trackId] = queued.status == .pending ? .queued : .conflict
        }
    }

    private func persistFreeTextDraft(for trackId: UUID) {
        guard
            let ownerId = activeDraftOwnerId,
            let workoutDate = freeTextDateByTrack[trackId]
        else { return }
        let title = freeTextTitle(for: trackId)
        let notes = freeTextNotes(for: trackId)
        let requestId = requestIds[trackId]
        if title == "My workout" && notes.isEmpty && requestId == nil {
            freeTextDraftStore.delete(
                ownerId: ownerId,
                trackId: trackId,
                workoutDate: workoutDate
            )
            return
        }
        freeTextDraftStore.save(
            FreeTextWorkoutDraft(title: title, notes: notes, clientRequestId: requestId),
            ownerId: ownerId,
            trackId: trackId,
            workoutDate: workoutDate
        )
    }

    private func deleteFreeTextLocalCopies(for trackId: UUID, workoutDate: String) {
        guard let ownerId = activeDraftOwnerId else { return }
        freeTextQueueStore.delete(
            ownerId: ownerId,
            trackId: trackId,
            workoutDate: workoutDate
        )
        freeTextDraftStore.delete(
            ownerId: ownerId,
            trackId: trackId,
            workoutDate: workoutDate
        )
    }

    private func persistDraft(for programmingDayId: UUID) {
        guard let ownerId = activeDraftOwnerId else { return }
        let dayWeights = weightEntries.reduce(into: [String: String]()) {
            result, entry in
            if programmingDayByMovement[entry.key] == programmingDayId,
               !entry.value.isEmpty {
                result[entry.key.uuidString.lowercased()] = entry.value
            }
        }
        let notes = workoutNotes[programmingDayId, default: ""]
        let requestId = requestIds[programmingDayId]
        let dayReps = completedRepEntries.reduce(into: [String: String]()) {
            result, entry in
            if programmingDayByMovement[entry.key] == programmingDayId,
               !entry.value.isEmpty {
                result[entry.key.uuidString.lowercased()] = entry.value
            }
        }
        let dayDurations = draftStrings(durationEntries, for: programmingDayId)
        let dayMeasurements = draftStrings(measurementEntries, for: programmingDayId)
        let dayMeasurementUnits = measurementUnitEntries.reduce(
            into: [String: MeasurementUnit]()
        ) { result, entry in
            if programmingDayByMovement[entry.key] == programmingDayId {
                result[entry.key.uuidString.lowercased()] = entry.value
            }
        }
        let dayActivityResults = draftStrings(activityResultEntries, for: programmingDayId)
        let dayActivityUnits = activityResultUnitEntries.reduce(
            into: [String: ActivityResultUnit]()
        ) { result, entry in
            if programmingDayByMovement[entry.key] == programmingDayId {
                result[entry.key.uuidString.lowercased()] = entry.value
            }
        }
        let dayRounds = draftStrings(completedRoundEntries, for: programmingDayId)
        let dayResidualReps = draftStrings(residualRepEntries, for: programmingDayId)
        let daySelectedOptions = selectedOptionIds.filter {
            programmingDayByMovement[$0] == programmingDayId
        }.map { $0.uuidString.lowercased() }.sorted()

        if dayWeights.isEmpty && dayReps.isEmpty && dayDurations.isEmpty
            && dayMeasurements.isEmpty && dayActivityResults.isEmpty
            && dayRounds.isEmpty && dayResidualReps.isEmpty
            && daySelectedOptions.isEmpty
            && notes.isEmpty && requestId == nil {
            draftStore.delete(ownerId: ownerId, programmingDayId: programmingDayId)
            return
        }

        draftStore.save(
            WorkoutDraft(
                weightEntries: dayWeights,
                completedRepEntries: dayReps,
                durationEntries: dayDurations,
                measurementEntries: dayMeasurements,
                measurementUnitEntries: dayMeasurementUnits,
                activityResultEntries: dayActivityResults,
                activityResultUnitEntries: dayActivityUnits,
                completedRoundEntries: dayRounds,
                residualRepEntries: dayResidualReps,
                selectedOptionIds: daySelectedOptions,
                notes: notes,
                clientRequestId: requestId
            ),
            ownerId: ownerId,
            programmingDayId: programmingDayId
        )
    }

    private func resetMemberState() {
        weightEntries = [:]
        completedRepEntries = [:]
        durationEntries = [:]
        measurementEntries = [:]
        measurementUnitEntries = [:]
        activityResultEntries = [:]
        activityResultUnitEntries = [:]
        completedRoundEntries = [:]
        residualRepEntries = [:]
        selectedOptionIds = []
        workoutNotes = [:]
        completionStates = [:]
        newPersonalRecords = [:]
        freeTextTitles = [:]
        freeTextNotes = [:]
        requestIds = [:]
        programmingDayByMovement = [:]
        freeTextDateByTrack = [:]
        activeDraftOwnerId = nil
    }

    private func persistMovementDraft(_ movementId: UUID) {
        if let programmingDayId = programmingDayByMovement[movementId] {
            persistDraft(for: programmingDayId)
        }
    }

    private func draftStrings(
        _ entries: [UUID: String],
        for programmingDayId: UUID
    ) -> [String: String] {
        entries.reduce(into: [String: String]()) { result, entry in
            if programmingDayByMovement[entry.key] == programmingDayId,
               !entry.value.isEmpty {
                result[entry.key.uuidString.lowercased()] = entry.value
            }
        }
    }

    private func restore(
        _ stored: [String: String],
        into entries: inout [UUID: String],
        allowedIds: Set<UUID>
    ) {
        for (movementIdText, value) in stored {
            guard
                let movementId = UUID(uuidString: movementIdText),
                allowedIds.contains(movementId)
            else {
                continue
            }
            entries[movementId] = value
        }
    }
}
