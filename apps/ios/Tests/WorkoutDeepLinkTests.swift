import Foundation
import Testing
@testable import OCTrainingLog

@MainActor
struct WorkoutDeepLinkTests {
    @Test func parsesTheWorkoutDateContract() throws {
        let url = try #require(URL(string: "octraininglog://log?date=2026-09-08"))
        let link = try #require(WorkoutDeepLink(url: url))

        #expect(link.workoutDate == "2026-09-08")
        #expect(link.url.absoluteString == "octraininglog://log?date=2026-09-08")
    }

    @Test func rejectsMalformedDatesRoutesAndDuplicateDates() {
        #expect(WorkoutDeepLink(url: URL(string: "octraininglog://log?date=September-8")!) == nil)
        #expect(WorkoutDeepLink(url: URL(string: "octraininglog://log?date=2026-02-30")!) == nil)
        #expect(WorkoutDeepLink(url: URL(string: "octraininglog://history?date=2026-09-08")!) == nil)
        #expect(
            WorkoutDeepLink(
                url: URL(string: "octraininglog://log?date=2026-09-08&date=2026-09-09")!
            ) == nil
        )
    }

    @Test func routerRetainsThenConsumesTheDestinationForSignInHandoff() {
        let router = WorkoutDeepLinkRouter()

        #expect(router.handle(workoutDate: "2026-09-08"))
        #expect(router.pendingWorkoutDate == "2026-09-08")
        #expect(router.consumeWorkoutDate() == "2026-09-08")
        #expect(router.pendingWorkoutDate == nil)
    }
}
