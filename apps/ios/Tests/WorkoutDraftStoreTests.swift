import Foundation
import Testing
@testable import OCTrainingLog

struct WorkoutDraftStoreTests {
    @Test func storesDraftsSeparatelyForEachMemberAndWorkout() throws {
        let suiteName = "WorkoutDraftStoreTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsWorkoutDraftStore(
            defaults: defaults,
            storageKey: "drafts"
        )
        let firstOwner = UUID()
        let secondOwner = UUID()
        let day = UUID()
        let draft = WorkoutDraft(
            weightEntries: [UUID().uuidString.lowercased(): "101.5"],
            completedRepEntries: [UUID().uuidString.lowercased(): "7"],
            durationEntries: [UUID().uuidString.lowercased(): "03:21:05.5"],
            measurementEntries: [UUID().uuidString.lowercased(): "24.25"],
            measurementUnitEntries: [UUID().uuidString.lowercased(): .inches],
            activityResultEntries: [UUID().uuidString.lowercased(): "1.25"],
            activityResultUnitEntries: [UUID().uuidString.lowercased(): .kilometers],
            completedRoundEntries: [UUID().uuidString.lowercased(): "7"],
            residualRepEntries: [UUID().uuidString.lowercased(): "12"],
            notes: "Exact notes",
            clientRequestId: UUID()
        )

        store.save(draft, ownerId: firstOwner, programmingDayId: day)

        #expect(store.load(ownerId: firstOwner, programmingDayId: day) == draft)
        #expect(store.load(ownerId: secondOwner, programmingDayId: day) == nil)
        #expect(store.load(ownerId: firstOwner, programmingDayId: UUID()) == nil)

        store.delete(ownerId: firstOwner, programmingDayId: day)
        #expect(store.load(ownerId: firstOwner, programmingDayId: day) == nil)
    }

    @Test func storesQueuedCompletionSeparatelyByMemberAndRoundTripsRequest() throws {
        let suiteName = "WorkoutCompletionQueueStoreTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsWorkoutCompletionQueueStore(
            defaults: defaults,
            storageKey: "queue"
        )
        let ownerId = UUID()
        let otherOwnerId = UUID()
        let programmingDayId = UUID()
        let movementId = UUID()
        let request = WorkoutCompletionRequest(
            clientRequestId: UUID(),
            trackCode: .generalPopulation,
            programmingDayId: programmingDayId,
            workoutDate: "2026-09-02",
            notes: "Exact offline note",
            results: [
                .roundsAndReps(
                    prescribedMovementId: movementId,
                    completedRounds: 7,
                    residualReps: 12
                )
            ]
        )

        store.save(
            QueuedWorkoutCompletion(request: request, status: .pending),
            ownerId: ownerId
        )

        #expect(store.completions(ownerId: ownerId) == [
            QueuedWorkoutCompletion(request: request, status: .pending)
        ])
        #expect(store.completions(ownerId: otherOwnerId).isEmpty)

        store.save(
            QueuedWorkoutCompletion(request: request, status: .conflict),
            ownerId: ownerId
        )
        #expect(store.completions(ownerId: ownerId).first?.status == .conflict)

        store.delete(ownerId: ownerId, programmingDayId: programmingDayId)
        #expect(store.completions(ownerId: ownerId).isEmpty)
    }

    @Test func queuedRequestRoundTripsEveryScoredResultShape() throws {
        let movementIds = (0..<7).map { _ in UUID() }
        let request = WorkoutCompletionRequest(
            clientRequestId: UUID(),
            trackCode: .sportsPerformance,
            programmingDayId: UUID(),
            workoutDate: "2026-09-03",
            notes: nil,
            results: [
                .weightedFixed(prescribedMovementId: movementIds[0], weightLb: 100.5),
                .weightedVariable(
                    prescribedMovementId: movementIds[1],
                    weightLb: 150,
                    completedReps: 5
                ),
                .maxRepetitions(prescribedMovementId: movementIds[2], completedReps: 20),
                .forTime(prescribedMovementId: movementIds[3], durationMs: 90_500),
                .heightOrDistance(
                    prescribedMovementId: movementIds[4],
                    measurementValue: 24.25,
                    measurementUnit: .inches
                ),
                .caloriesOrDistance(
                    prescribedMovementId: movementIds[5],
                    resultValue: 1.25,
                    resultUnit: .kilometers
                ),
                .roundsAndReps(
                    prescribedMovementId: movementIds[6],
                    completedRounds: 7,
                    residualReps: 12
                ),
            ]
        )

        let data = try JSONEncoder().encode(request)
        #expect(try JSONDecoder().decode(WorkoutCompletionRequest.self, from: data) == request)
    }

    @Test func storesFreeTextDraftAndQueueByMemberTrackAndDate() throws {
        let suiteName = "FreeTextWorkoutStoresTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let drafts = UserDefaultsFreeTextWorkoutDraftStore(
            defaults: defaults,
            storageKey: "free-text-drafts"
        )
        let queue = UserDefaultsFreeTextWorkoutQueueStore(
            defaults: defaults,
            storageKey: "free-text-queue"
        )
        let ownerId = UUID()
        let trackId = UUID()
        let requestId = UUID()
        let draft = FreeTextWorkoutDraft(
            title: "Trail run",
            notes: "  Exact notes\n",
            clientRequestId: requestId
        )
        let request = FreeTextWorkoutRequest(
            clientRequestId: requestId,
            trackCode: .generalPopulation,
            workoutDate: "2026-09-02",
            title: draft.title,
            notes: draft.notes
        )

        drafts.save(
            draft,
            ownerId: ownerId,
            trackId: trackId,
            workoutDate: request.workoutDate
        )
        queue.save(
            QueuedFreeTextWorkout(trackId: trackId, request: request, status: .pending),
            ownerId: ownerId
        )

        #expect(
            drafts.load(ownerId: ownerId, trackId: trackId, workoutDate: request.workoutDate)
                == draft
        )
        #expect(queue.workouts(ownerId: ownerId).first?.request == request)
        #expect(queue.workouts(ownerId: UUID()).isEmpty)
    }
}
