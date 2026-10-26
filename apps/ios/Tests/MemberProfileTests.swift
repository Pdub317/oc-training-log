import Foundation
import Testing
@testable import OCTrainingLog

@MainActor
struct MemberProfileViewModelTests {
    @Test func loadsEditsAndLeavesOnlyTheSelectedTrack() async {
        let loader = StubMemberProfileLoader()
        let model = MemberProfileViewModel()

        await model.load(using: loader)
        #expect(model.profile?.tracks.count == 2)
        #expect(model.firstName == "Jamie")

        model.firstName = "  Jay  "
        model.timeZone = "America/New_York"
        await model.save(using: loader)
        #expect(loader.updates.first?.firstName == "Jay")
        #expect(model.profile?.member.firstName == "Jay")

        let selected = loader.profile.tracks[0]
        await model.leave(selected, using: loader)
        #expect(loader.leftTrackIds == [selected.id])
        #expect(model.profile?.tracks.map(\.id) == [loader.profile.tracks[1].id])
    }

    @Test func rejectsBlankNamesAndInvalidTimeZonesLocally() async {
        let model = MemberProfileViewModel()
        let loader = StubMemberProfileLoader()
        await model.load(using: loader)
        model.firstName = " "
        #expect(!model.canSave)
        model.firstName = "Jamie"
        model.timeZone = "Not/A_Time_Zone"
        #expect(!model.canSave)
    }
}

@MainActor
private final class StubMemberProfileLoader: MemberProfileLoading {
    var updates: [UpdateMemberProfileRequest] = []
    var leftTrackIds: [UUID] = []
    let profile = MemberProfileResponse(
        member: ProfileMember(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000003")!,
            firstName: "Jamie",
            lastName: "Member",
            email: "jamie@example.com",
            emailVerified: true,
            timeZone: "America/Los_Angeles"
        ),
        gyms: [
            ProfileGym(
                id: UUID(uuidString: "00000000-0000-4000-8000-000000000100")!,
                name: "OC Gym Bend"
            )
        ],
        tracks: [
            ProfileTrack(
                id: UUID(uuidString: "00000000-0000-4000-8000-000000000201")!,
                gymId: UUID(uuidString: "00000000-0000-4000-8000-000000000100")!,
                gymName: "OC Gym Bend",
                code: .sportsPerformance,
                name: "Sports Performance",
                joinedAt: "2026-09-01T00:00:00.000Z"
            ),
            ProfileTrack(
                id: UUID(uuidString: "00000000-0000-4000-8000-000000000202")!,
                gymId: UUID(uuidString: "00000000-0000-4000-8000-000000000100")!,
                gymName: "OC Gym Bend",
                code: .generalPopulation,
                name: "General Population",
                joinedAt: "2026-09-02T00:00:00.000Z"
            ),
        ]
    )

    func loadMemberProfile() async throws -> MemberProfileResponse { profile }

    func updateMemberProfile(_ request: UpdateMemberProfileRequest) async throws
        -> MemberProfileResponse {
        updates.append(request)
        return MemberProfileResponse(
            member: ProfileMember(
                id: profile.member.id,
                firstName: request.firstName,
                lastName: request.lastName,
                email: profile.member.email,
                emailVerified: true,
                timeZone: request.timeZone
            ),
            gyms: profile.gyms,
            tracks: profile.tracks
        )
    }

    func leaveTrack(_ trackId: UUID) async throws -> MemberProfileResponse {
        leftTrackIds.append(trackId)
        return MemberProfileResponse(
            member: profile.member,
            gyms: profile.gyms,
            tracks: profile.tracks.filter { $0.id != trackId }
        )
    }
}

struct MemberProfileAPIClientTests {
    @Test func loadsProfileAndSendsExplicitLeaveConfirmation() async throws {
        let data = Data(Self.profileJSON.utf8)
        let session = ProfileMockHTTPDataLoader(data: data, statusCode: 200)
        let client = TodayAPIClient(
            configuration: try APIConfiguration(values: [
                "OCAPIBaseURL": "https://api.example.test"
            ]),
            session: session
        )

        _ = try await client.leaveTrack(
            UUID(uuidString: "00000000-0000-4000-8000-000000000202")!,
            accessToken: "member-token"
        )

        let request = await session.capturedRequest()
        #expect(request?.httpMethod == "POST")
        #expect(request?.url?.absoluteString == "https://api.example.test/api/profile/tracks/leave")
        #expect(request?.value(forHTTPHeaderField: "Authorization") == "Bearer member-token")
        let body = try #require(request?.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["confirmation"] as? String == "leave_track")
    }

    private static let profileJSON = #"{"member":{"id":"00000000-0000-4000-8000-000000000003","firstName":"Jamie","lastName":"Member","email":"jamie@example.com","emailVerified":true,"timeZone":"America/Los_Angeles"},"gyms":[],"tracks":[]}"#
}

private actor ProfileMockHTTPDataLoader: HTTPDataLoading {
    private let data: Data
    private let statusCode: Int
    private var request: URLRequest?

    init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        self.request = request
        return (
            data,
            HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
        )
    }

    func capturedRequest() -> URLRequest? { request }
}
