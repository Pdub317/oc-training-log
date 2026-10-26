import Foundation

struct HistoryResponse: Decodable, Equatable, Identifiable, Sendable {
    let track: TodayTrack
    let workouts: [HistoryWorkout]
    let nextCursor: String?

    var id: UUID { track.id }

    init(track: TodayTrack, workouts: [HistoryWorkout], nextCursor: String? = nil) {
        self.track = track
        self.workouts = workouts
        self.nextCursor = nextCursor
    }

    private enum CodingKeys: String, CodingKey { case track, workouts, nextCursor }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        track = try container.decode(TodayTrack.self, forKey: .track)
        workouts = try container.decode([HistoryWorkout].self, forKey: .workouts)
        nextCursor = try container.decodeIfPresent(String.self, forKey: .nextCursor)
    }
}

struct HistoryWorkout: Decodable, Equatable, Identifiable, Sendable {
    let workoutLogId: UUID
    let programmingDayId: UUID?
    let workoutDate: String
    let completedAt: String
    let updatedAt: String
    let title: String
    let notes: String?
    let hasPersonalRecord: Bool
    let movements: [HistoryMovement]

    var id: UUID { workoutLogId }
}

struct HistoryMovement: Decodable, Equatable, Identifiable, Sendable {
    let movementResultId: UUID
    let prescribedMovementId: UUID
    let name: String
    let prescriptionText: String
    let blockType: WorkoutBlockType
    let resultSchema: ResultSchemaType
    let weightLb: Double?
    let completedReps: Int?
    let durationMs: Int?
    let measurementValue: Double?
    let measurementUnit: MeasurementUnit?
    let resultValue: Double?
    let resultUnit: ActivityResultUnit?
    let completedRounds: Int?
    let residualReps: Int?
    let isPersonalRecord: Bool

    var id: UUID { movementResultId }

    var formattedResult: String {
        switch resultSchema {
        case .weightedFixedReps:
            weightLb.map { "\(Self.formattedWeight($0)) lb" } ?? "Result unavailable"
        case .weightedVariableReps:
            if let weightLb, let completedReps {
                "\(Self.formattedWeight(weightLb)) lb × \(completedReps) reps"
            } else {
                "Result unavailable"
            }
        case .maxRepetitions:
            completedReps.map { "\($0) reps" } ?? "Result unavailable"
        case .forTime:
            durationMs.map(Self.formattedDuration) ?? "Result unavailable"
        case .heightOrDistance:
            if let measurementValue, let measurementUnit {
                "\(Self.formattedNumber(measurementValue)) \(measurementUnit.rawValue)"
            } else {
                "Result unavailable"
            }
        case .caloriesOrDistance:
            if let resultValue, let resultUnit {
                "\(Self.formattedNumber(resultValue)) \(resultUnit.rawValue)"
            } else {
                "Result unavailable"
            }
        case .roundsAndReps:
            if let completedRounds, let residualReps {
                "\(completedRounds) rounds + \(residualReps) reps"
            } else {
                "Result unavailable"
            }
        default:
            "Result unavailable"
        }
    }

    private static func formattedWeight(_ weight: Double) -> String {
        formattedNumber(weight)
    }

    private static func formattedNumber(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%g", value)
    }

    private static func formattedDuration(_ milliseconds: Int) -> String {
        let totalSeconds = milliseconds / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let tenths = (milliseconds % 1000) / 100
        let suffix = tenths == 0 ? "" : ".\(tenths)"
        if hours > 0 {
            return String(format: "%d:%02d:%02d%@", hours, minutes, seconds, suffix)
        }
        return String(format: "%02d:%02d%@", minutes, seconds, suffix)
    }
}
