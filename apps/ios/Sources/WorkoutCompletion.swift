import Foundation

enum MeasurementUnit: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case inches = "in"
    case feet = "ft"
    case meters = "m"
    case yards = "yd"
    case miles = "mi"

    var id: String { rawValue }
}

enum ActivityResultUnit: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case calories = "cal"
    case meters = "m"
    case kilometers = "km"
    case feet = "ft"
    case yards = "yd"
    case miles = "mi"

    var id: String { rawValue }
}

struct WorkoutCompletionRequest: Codable, Equatable, Sendable {
    let clientRequestId: UUID
    let trackCode: TrainingTrack
    let programmingDayId: UUID
    let workoutDate: String
    let notes: String?
    let results: [WorkoutResultEntry]
}

struct FreeTextWorkoutRequest: Codable, Equatable, Sendable {
    let clientRequestId: UUID
    let trackCode: TrainingTrack
    let workoutDate: String
    let title: String
    let notes: String
}

enum WorkoutResultEntry: Codable, Equatable, Sendable {
    case weightedFixed(prescribedMovementId: UUID, weightLb: Double)
    case weightedVariable(prescribedMovementId: UUID, weightLb: Double, completedReps: Int)
    case maxRepetitions(prescribedMovementId: UUID, completedReps: Int)
    case forTime(prescribedMovementId: UUID, durationMs: Int)
    case heightOrDistance(
        prescribedMovementId: UUID,
        measurementValue: Double,
        measurementUnit: MeasurementUnit
    )
    case caloriesOrDistance(
        prescribedMovementId: UUID,
        resultValue: Double,
        resultUnit: ActivityResultUnit
    )
    case roundsAndReps(
        prescribedMovementId: UUID,
        completedRounds: Int,
        residualReps: Int
    )

    var prescribedMovementId: UUID {
        switch self {
        case .weightedFixed(let id, _), .weightedVariable(let id, _, _),
             .maxRepetitions(let id, _), .forTime(let id, _),
             .heightOrDistance(let id, _, _), .caloriesOrDistance(let id, _, _),
             .roundsAndReps(let id, _, _): id
        }
    }

    var weightLb: Double? {
        switch self {
        case .weightedFixed(_, let weight), .weightedVariable(_, let weight, _): weight
        case .maxRepetitions: nil
        case .forTime, .heightOrDistance, .caloriesOrDistance, .roundsAndReps: nil
        }
    }

    var completedReps: Int? {
        switch self {
        case .weightedVariable(_, _, let reps), .maxRepetitions(_, let reps): reps
        case .weightedFixed: nil
        case .forTime, .heightOrDistance, .caloriesOrDistance, .roundsAndReps: nil
        }
    }

    var durationMs: Int? {
        if case .forTime(_, let durationMs) = self { return durationMs }
        return nil
    }

    var measurement: (value: Double, unit: MeasurementUnit)? {
        if case .heightOrDistance(_, let value, let unit) = self {
            return (value, unit)
        }
        return nil
    }

    var activityResult: (value: Double, unit: ActivityResultUnit)? {
        if case .caloriesOrDistance(_, let value, let unit) = self {
            return (value, unit)
        }
        return nil
    }

    var roundsAndReps: (rounds: Int, reps: Int)? {
        if case .roundsAndReps(_, let rounds, let reps) = self {
            return (rounds, reps)
        }
        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case resultSchema, prescribedMovementId, weightLb, completedReps
        case durationMs, measurementValue, measurementUnit
        case resultValue, resultUnit, completedRounds, residualReps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schema = try container.decode(ResultSchemaType.self, forKey: .resultSchema)
        let movementId = try container.decode(UUID.self, forKey: .prescribedMovementId)
        switch schema {
        case .weightedFixedReps:
            self = .weightedFixed(
                prescribedMovementId: movementId,
                weightLb: try container.decode(Double.self, forKey: .weightLb)
            )
        case .weightedVariableReps:
            self = .weightedVariable(
                prescribedMovementId: movementId,
                weightLb: try container.decode(Double.self, forKey: .weightLb),
                completedReps: try container.decode(Int.self, forKey: .completedReps)
            )
        case .maxRepetitions:
            self = .maxRepetitions(
                prescribedMovementId: movementId,
                completedReps: try container.decode(Int.self, forKey: .completedReps)
            )
        case .forTime:
            self = .forTime(
                prescribedMovementId: movementId,
                durationMs: try container.decode(Int.self, forKey: .durationMs)
            )
        case .heightOrDistance:
            self = .heightOrDistance(
                prescribedMovementId: movementId,
                measurementValue: try container.decode(Double.self, forKey: .measurementValue),
                measurementUnit: try container.decode(MeasurementUnit.self, forKey: .measurementUnit)
            )
        case .caloriesOrDistance:
            self = .caloriesOrDistance(
                prescribedMovementId: movementId,
                resultValue: try container.decode(Double.self, forKey: .resultValue),
                resultUnit: try container.decode(ActivityResultUnit.self, forKey: .resultUnit)
            )
        case .roundsAndReps:
            self = .roundsAndReps(
                prescribedMovementId: movementId,
                completedRounds: try container.decode(Int.self, forKey: .completedRounds),
                residualReps: try container.decode(Int.self, forKey: .residualReps)
            )
        case .notesOnly:
            throw DecodingError.dataCorruptedError(
                forKey: .resultSchema,
                in: container,
                debugDescription: "Notes-only movements do not have scored results."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(prescribedMovementId, forKey: .prescribedMovementId)
        switch self {
        case .weightedFixed(_, let weight):
            try container.encode(ResultSchemaType.weightedFixedReps.rawValue, forKey: .resultSchema)
            try container.encode(weight, forKey: .weightLb)
        case .weightedVariable(_, let weight, let reps):
            try container.encode(ResultSchemaType.weightedVariableReps.rawValue, forKey: .resultSchema)
            try container.encode(weight, forKey: .weightLb)
            try container.encode(reps, forKey: .completedReps)
        case .maxRepetitions(_, let reps):
            try container.encode(ResultSchemaType.maxRepetitions.rawValue, forKey: .resultSchema)
            try container.encode(reps, forKey: .completedReps)
        case .forTime(_, let durationMs):
            try container.encode(ResultSchemaType.forTime.rawValue, forKey: .resultSchema)
            try container.encode(durationMs, forKey: .durationMs)
        case .heightOrDistance(_, let value, let unit):
            try container.encode(ResultSchemaType.heightOrDistance.rawValue, forKey: .resultSchema)
            try container.encode(value, forKey: .measurementValue)
            try container.encode(unit, forKey: .measurementUnit)
        case .caloriesOrDistance(_, let value, let unit):
            try container.encode(ResultSchemaType.caloriesOrDistance.rawValue, forKey: .resultSchema)
            try container.encode(value, forKey: .resultValue)
            try container.encode(unit, forKey: .resultUnit)
        case .roundsAndReps(_, let rounds, let reps):
            try container.encode(ResultSchemaType.roundsAndReps.rawValue, forKey: .resultSchema)
            try container.encode(rounds, forKey: .completedRounds)
            try container.encode(reps, forKey: .residualReps)
        }
    }
}

struct WorkoutCompletionResponse: Decodable, Equatable, Sendable {
    let state: String
    let workoutLogId: UUID
    let completedAt: String
    let replayed: Bool
    let results: [SavedMovementResult]
    let personalRecords: [CompletedPersonalRecord]
}

enum SavedMovementResult: Decodable, Equatable, Sendable {
    case weightedFixed(movementResultId: UUID, prescribedMovementId: UUID, weightLb: Double)
    case weightedVariable(
        movementResultId: UUID,
        prescribedMovementId: UUID,
        weightLb: Double,
        completedReps: Int
    )
    case maxRepetitions(
        movementResultId: UUID,
        prescribedMovementId: UUID,
        completedReps: Int
    )
    case forTime(movementResultId: UUID, prescribedMovementId: UUID, durationMs: Int)
    case heightOrDistance(
        movementResultId: UUID,
        prescribedMovementId: UUID,
        measurementValue: Double,
        measurementUnit: MeasurementUnit
    )
    case caloriesOrDistance(
        movementResultId: UUID,
        prescribedMovementId: UUID,
        resultValue: Double,
        resultUnit: ActivityResultUnit
    )
    case roundsAndReps(
        movementResultId: UUID,
        prescribedMovementId: UUID,
        completedRounds: Int,
        residualReps: Int
    )

    private enum CodingKeys: String, CodingKey {
        case resultSchema, movementResultId, prescribedMovementId, weightLb, completedReps
        case durationMs, measurementValue, measurementUnit
        case resultValue, resultUnit, completedRounds, residualReps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schema = try container.decode(ResultSchemaType.self, forKey: .resultSchema)
        let resultId = try container.decode(UUID.self, forKey: .movementResultId)
        let movementId = try container.decode(UUID.self, forKey: .prescribedMovementId)
        switch schema {
        case .weightedFixedReps:
            self = .weightedFixed(
                movementResultId: resultId,
                prescribedMovementId: movementId,
                weightLb: try container.decode(Double.self, forKey: .weightLb)
            )
        case .weightedVariableReps:
            self = .weightedVariable(
                movementResultId: resultId,
                prescribedMovementId: movementId,
                weightLb: try container.decode(Double.self, forKey: .weightLb),
                completedReps: try container.decode(Int.self, forKey: .completedReps)
            )
        case .maxRepetitions:
            self = .maxRepetitions(
                movementResultId: resultId,
                prescribedMovementId: movementId,
                completedReps: try container.decode(Int.self, forKey: .completedReps)
            )
        case .forTime:
            self = .forTime(
                movementResultId: resultId,
                prescribedMovementId: movementId,
                durationMs: try container.decode(Int.self, forKey: .durationMs)
            )
        case .heightOrDistance:
            self = .heightOrDistance(
                movementResultId: resultId,
                prescribedMovementId: movementId,
                measurementValue: try container.decode(Double.self, forKey: .measurementValue),
                measurementUnit: try container.decode(
                    MeasurementUnit.self,
                    forKey: .measurementUnit
                )
            )
        case .caloriesOrDistance:
            self = .caloriesOrDistance(
                movementResultId: resultId,
                prescribedMovementId: movementId,
                resultValue: try container.decode(Double.self, forKey: .resultValue),
                resultUnit: try container.decode(ActivityResultUnit.self, forKey: .resultUnit)
            )
        case .roundsAndReps:
            self = .roundsAndReps(
                movementResultId: resultId,
                prescribedMovementId: movementId,
                completedRounds: try container.decode(Int.self, forKey: .completedRounds),
                residualReps: try container.decode(Int.self, forKey: .residualReps)
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .resultSchema,
                in: container,
                debugDescription: "Unsupported saved result schema."
            )
        }
    }
}

struct CompletedPersonalRecord: Decodable, Equatable, Sendable {
    let personalRecordId: UUID
    let benchmarkId: UUID
    let benchmarkLabel: String
    let movementResultId: UUID
    let value: Double
    let unit: String
    let achievedAt: String
}

struct WorkoutEditRequest: Encodable, Equatable, Sendable {
    let workoutLogId: UUID
    let expectedUpdatedAt: String
    let notes: String?
    let results: [WorkoutResultEntry]
}

struct WorkoutEditResponse: Decodable, Equatable, Sendable {
    let state: String
    let workoutLogId: UUID
    let updatedAt: String
}

struct FreeTextWorkoutEditRequest: Encodable, Equatable, Sendable {
    let workoutLogId: UUID
    let expectedUpdatedAt: String
    let title: String
    let notes: String
}
