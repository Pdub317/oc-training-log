import Foundation

struct MemberProfileResponse: Codable, Equatable, Sendable {
    let member: ProfileMember
    let gyms: [ProfileGym]
    let tracks: [ProfileTrack]
}

struct ProfileMember: Codable, Equatable, Sendable {
    let id: UUID
    let firstName: String
    let lastName: String
    let email: String
    let emailVerified: Bool
    let timeZone: String?
}

struct ProfileGym: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
}

struct ProfileTrack: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let gymId: UUID
    let gymName: String
    let code: TrainingTrack
    let name: String
    let joinedAt: String
}

struct UpdateMemberProfileRequest: Codable, Equatable, Sendable {
    let firstName: String
    let lastName: String
    let timeZone: String
}

struct LeaveTrackRequest: Encodable, Equatable, Sendable {
    let trackId: UUID
    let confirmation = "leave_track"
}

@MainActor
protocol MemberProfileLoading: AnyObject {
    func loadMemberProfile() async throws -> MemberProfileResponse
    func updateMemberProfile(_ request: UpdateMemberProfileRequest) async throws
        -> MemberProfileResponse
    func leaveTrack(_ trackId: UUID) async throws -> MemberProfileResponse
}

extension AuthenticationModel: MemberProfileLoading {}

@MainActor
final class MemberProfileViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var profile: MemberProfileResponse?
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var timeZone = TimeZone.current.identifier
    @Published private(set) var saving = false
    @Published private(set) var leavingTrackId: UUID?
    @Published private(set) var statusMessage: String?

    var canSave: Bool {
        !saving
            && !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && TimeZone(identifier: timeZone) != nil
    }

    func load(using loader: any MemberProfileLoading) async {
        state = .loading
        statusMessage = nil
        do {
            apply(try await loader.loadMemberProfile())
            state = .loaded
        } catch {
            state = .failed("We couldn't load your profile. Check your connection and try again.")
        }
    }

    func save(using loader: any MemberProfileLoading) async {
        guard canSave else { return }
        saving = true
        statusMessage = nil
        defer { saving = false }
        do {
            let updated = try await loader.updateMemberProfile(
                UpdateMemberProfileRequest(
                    firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                    lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                    timeZone: timeZone
                )
            )
            apply(updated)
            statusMessage = "Profile saved."
            state = .loaded
        } catch {
            statusMessage = "We couldn't save your profile. Please try again."
        }
    }

    func leave(_ track: ProfileTrack, using loader: any MemberProfileLoading) async {
        guard leavingTrackId == nil else { return }
        leavingTrackId = track.id
        statusMessage = nil
        defer { leavingTrackId = nil }
        do {
            apply(try await loader.leaveTrack(track.id))
            statusMessage = "You left " + track.name + ". Your workout history remains saved."
            state = .loaded
        } catch {
            statusMessage = "We couldn't update this membership. Refresh and try again."
        }
    }

    private func apply(_ value: MemberProfileResponse) {
        profile = value
        firstName = value.member.firstName
        lastName = value.member.lastName
        timeZone = value.member.timeZone ?? TimeZone.current.identifier
    }
}
