import XCTest
@testable import OCTrainingLog

final class TrainingTrackTests: XCTestCase {
    func testInitialTracksRemainDistinct() {
        XCTAssertEqual(TrainingTrack.allCases.map(\.rawValue), ["SP", "GP"])
        XCTAssertEqual(Set(TrainingTrack.allCases.map(\.rawValue)).count, 2)
    }
}
