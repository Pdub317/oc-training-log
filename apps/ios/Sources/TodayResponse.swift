import Foundation

enum TodayResponse: Decodable, Equatable, Identifiable, Sendable {
    case published(PublishedToday)
    case closed(ClosedToday)
    case noProgramming(NoProgrammingToday)

    var id: UUID { track.id }
    var track: TodayTrack {
        switch self {
        case .published(let response): response.track
        case .closed(let response): response.track
        case .noProgramming(let response): response.track
        }
    }

    var workoutDate: String {
        switch self {
        case .published(let response): response.workoutDate
        case .closed(let response): response.workoutDate
        case .noProgramming(let response): response.workoutDate
        }
    }

    var isCompleted: Bool {
        switch self {
        case .published(let response): response.isCompleted
        case .closed: false
        case .noProgramming(let response): response.isCompleted
        }
    }

    var completionKey: UUID {
        switch self {
        case .published(let response): response.programmingDay.id
        case .closed(let response): response.programmingDay.id
        case .noProgramming(let response): response.track.id
        }
    }

    private enum CodingKeys: String, CodingKey {
        case state
    }

    private enum State: String, Decodable {
        case published
        case closed
        case noProgramming = "no_programming"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(State.self, forKey: .state) {
        case .published:
            self = .published(try PublishedToday(from: decoder))
        case .closed:
            self = .closed(try ClosedToday(from: decoder))
        case .noProgramming:
            self = .noProgramming(try NoProgrammingToday(from: decoder))
        }
    }
}

struct TodayTrack: Decodable, Equatable, Sendable {
    let id: UUID
    let code: TrainingTrack
    let name: String
}

struct PublishedToday: Decodable, Equatable, Sendable {
    let workoutDate: String
    let timeZone: String
    let track: TodayTrack
    let isCompleted: Bool
    let programmingDay: TodayProgrammingDay
}

struct NoProgrammingToday: Decodable, Equatable, Sendable {
    let workoutDate: String
    let timeZone: String
    let track: TodayTrack
    let isCompleted: Bool
    let canCreateFreeText: Bool
}

struct ClosedToday: Decodable, Equatable, Sendable {
    let workoutDate: String
    let timeZone: String
    let track: TodayTrack
    let isCompleted: Bool
    let programmingDay: ClosedProgrammingDay
}

struct ClosedProgrammingDay: Decodable, Equatable, Sendable {
    let id: UUID
    let title: String
    let coachNotes: String?
}

struct TodayProgrammingDay: Decodable, Equatable, Sendable {
    let id: UUID
    let title: String
    let coachNotes: String?
    let blocks: [TodayWorkoutBlock]
}

struct TodayWorkoutBlock: Decodable, Equatable, Identifiable, Sendable {
    let id: UUID
    let type: WorkoutBlockType
    let title: String
    let instructions: String?
    let displayOrder: Int
    let movements: [TodayMovement]
}

struct TodayMovement: Decodable, Equatable, Identifiable, Sendable {
    let id: UUID
    let movementId: UUID?
    let name: String
    let prescriptionText: String
    let coachNotes: String?
    let substitutions: [String]
    let optionGroupKey: String?
    let optionGroupLabel: String?
    let resultSchema: ResultSchemaType
    let displayOrder: Int

    init(
        id: UUID,
        movementId: UUID?,
        name: String,
        prescriptionText: String,
        coachNotes: String?,
        substitutions: [String],
        optionGroupKey: String? = nil,
        optionGroupLabel: String? = nil,
        resultSchema: ResultSchemaType,
        displayOrder: Int
    ) {
        self.id = id
        self.movementId = movementId
        self.name = name
        self.prescriptionText = prescriptionText
        self.coachNotes = coachNotes
        self.substitutions = substitutions
        self.optionGroupKey = optionGroupKey
        self.optionGroupLabel = optionGroupLabel
        self.resultSchema = resultSchema
        self.displayOrder = displayOrder
    }
}

enum WorkoutBlockType: String, Decodable, Equatable, Sendable {
    case warmUp = "warm_up"
    case jumps
    case strength
    case accessory
    case wod
    case finisher
    case recovery
    case other

    var displayName: String {
        switch self {
        case .warmUp: "Warm-up"
        case .jumps: "Jumps"
        case .strength: "Strength"
        case .accessory: "Accessory"
        case .wod: "WOD"
        case .finisher: "Finisher"
        case .recovery: "Recovery"
        case .other: "Other"
        }
    }

    var isReadOnly: Bool { self == .warmUp || self == .recovery }
}

enum ResultSchemaType: String, Decodable, Equatable, Sendable {
    case weightedFixedReps = "weighted_fixed_reps"
    case weightedVariableReps = "weighted_variable_reps"
    case heightOrDistance = "height_or_distance"
    case forTime = "for_time"
    case maxRepetitions = "max_repetitions"
    case caloriesOrDistance = "calories_or_distance"
    case roundsAndReps = "rounds_and_reps"
    case notesOnly = "notes_only"
}

extension TrainingTrack: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let track = TrainingTrack(rawValue: value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported training track."
            )
        }
        self = track
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
