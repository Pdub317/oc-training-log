import Foundation

struct WorkoutDraft: Codable, Equatable, Sendable {
    let weightEntries: [String: String]
    let completedRepEntries: [String: String]
    let durationEntries: [String: String]
    let measurementEntries: [String: String]
    let measurementUnitEntries: [String: MeasurementUnit]
    let activityResultEntries: [String: String]
    let activityResultUnitEntries: [String: ActivityResultUnit]
    let completedRoundEntries: [String: String]
    let residualRepEntries: [String: String]
    let selectedOptionIds: [String]
    let notes: String
    let clientRequestId: UUID?

    init(
        weightEntries: [String: String],
        completedRepEntries: [String: String],
        durationEntries: [String: String],
        measurementEntries: [String: String],
        measurementUnitEntries: [String: MeasurementUnit],
        activityResultEntries: [String: String] = [:],
        activityResultUnitEntries: [String: ActivityResultUnit] = [:],
        completedRoundEntries: [String: String] = [:],
        residualRepEntries: [String: String] = [:],
        selectedOptionIds: [String] = [],
        notes: String,
        clientRequestId: UUID?
    ) {
        self.weightEntries = weightEntries
        self.completedRepEntries = completedRepEntries
        self.durationEntries = durationEntries
        self.measurementEntries = measurementEntries
        self.measurementUnitEntries = measurementUnitEntries
        self.activityResultEntries = activityResultEntries
        self.activityResultUnitEntries = activityResultUnitEntries
        self.completedRoundEntries = completedRoundEntries
        self.residualRepEntries = residualRepEntries
        self.selectedOptionIds = selectedOptionIds
        self.notes = notes
        self.clientRequestId = clientRequestId
    }

    private enum CodingKeys: String, CodingKey {
        case weightEntries, completedRepEntries, durationEntries, measurementEntries
        case measurementUnitEntries, notes, clientRequestId
        case activityResultEntries, activityResultUnitEntries
        case completedRoundEntries, residualRepEntries
        case selectedOptionIds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        weightEntries = try container.decode([String: String].self, forKey: .weightEntries)
        completedRepEntries = try container.decodeIfPresent(
            [String: String].self,
            forKey: .completedRepEntries
        ) ?? [:]
        durationEntries = try container.decodeIfPresent(
            [String: String].self,
            forKey: .durationEntries
        ) ?? [:]
        measurementEntries = try container.decodeIfPresent(
            [String: String].self,
            forKey: .measurementEntries
        ) ?? [:]
        measurementUnitEntries = try container.decodeIfPresent(
            [String: MeasurementUnit].self,
            forKey: .measurementUnitEntries
        ) ?? [:]
        activityResultEntries = try container.decodeIfPresent(
            [String: String].self,
            forKey: .activityResultEntries
        ) ?? [:]
        activityResultUnitEntries = try container.decodeIfPresent(
            [String: ActivityResultUnit].self,
            forKey: .activityResultUnitEntries
        ) ?? [:]
        completedRoundEntries = try container.decodeIfPresent(
            [String: String].self,
            forKey: .completedRoundEntries
        ) ?? [:]
        residualRepEntries = try container.decodeIfPresent(
            [String: String].self,
            forKey: .residualRepEntries
        ) ?? [:]
        selectedOptionIds = try container.decodeIfPresent(
            [String].self,
            forKey: .selectedOptionIds
        ) ?? []
        notes = try container.decode(String.self, forKey: .notes)
        clientRequestId = try container.decodeIfPresent(UUID.self, forKey: .clientRequestId)
    }
}

protocol WorkoutDraftStoring {
    func load(ownerId: UUID, programmingDayId: UUID) -> WorkoutDraft?
    func save(_ draft: WorkoutDraft, ownerId: UUID, programmingDayId: UUID)
    func delete(ownerId: UUID, programmingDayId: UUID)
}

final class UserDefaultsWorkoutDraftStore: WorkoutDraftStoring {
    private let defaults: UserDefaults
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "com.ocgymbend.traininglog.workout-drafts.v1"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func load(ownerId: UUID, programmingDayId: UUID) -> WorkoutDraft? {
        drafts()[key(ownerId: ownerId, programmingDayId: programmingDayId)]
    }

    func save(_ draft: WorkoutDraft, ownerId: UUID, programmingDayId: UUID) {
        var values = drafts()
        values[key(ownerId: ownerId, programmingDayId: programmingDayId)] = draft
        guard let data = try? JSONEncoder().encode(values) else { return }
        defaults.set(data, forKey: storageKey)
    }

    func delete(ownerId: UUID, programmingDayId: UUID) {
        var values = drafts()
        values.removeValue(forKey: key(ownerId: ownerId, programmingDayId: programmingDayId))
        if values.isEmpty {
            defaults.removeObject(forKey: storageKey)
        } else if let data = try? JSONEncoder().encode(values) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func drafts() -> [String: WorkoutDraft] {
        guard
            let data = defaults.data(forKey: storageKey),
            let values = try? JSONDecoder().decode([String: WorkoutDraft].self, from: data)
        else {
            return [:]
        }
        return values
    }

    private func key(ownerId: UUID, programmingDayId: UUID) -> String {
        "\(ownerId.uuidString.lowercased()):\(programmingDayId.uuidString.lowercased())"
    }
}

enum QueuedCompletionStatus: String, Codable, Equatable, Sendable {
    case pending
    case conflict
}

struct QueuedWorkoutCompletion: Codable, Equatable, Sendable {
    let request: WorkoutCompletionRequest
    let status: QueuedCompletionStatus
}

protocol WorkoutCompletionQueueStoring {
    func completions(ownerId: UUID) -> [QueuedWorkoutCompletion]
    func save(_ completion: QueuedWorkoutCompletion, ownerId: UUID)
    func delete(ownerId: UUID, programmingDayId: UUID)
}

final class UserDefaultsWorkoutCompletionQueueStore: WorkoutCompletionQueueStoring {
    private let defaults: UserDefaults
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "com.ocgymbend.traininglog.completion-queue.v1"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func completions(ownerId: UUID) -> [QueuedWorkoutCompletion] {
        let prefix = "\(ownerId.uuidString.lowercased()):"
        return values()
            .filter { $0.key.hasPrefix(prefix) }
            .map(\.value)
            .sorted {
                if $0.request.workoutDate == $1.request.workoutDate {
                    return $0.request.programmingDayId.uuidString
                        < $1.request.programmingDayId.uuidString
                }
                return $0.request.workoutDate < $1.request.workoutDate
            }
    }

    func save(_ completion: QueuedWorkoutCompletion, ownerId: UUID) {
        var stored = values()
        stored[key(ownerId: ownerId, programmingDayId: completion.request.programmingDayId)] = completion
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: storageKey)
    }

    func delete(ownerId: UUID, programmingDayId: UUID) {
        var stored = values()
        stored.removeValue(forKey: key(ownerId: ownerId, programmingDayId: programmingDayId))
        if stored.isEmpty {
            defaults.removeObject(forKey: storageKey)
        } else if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func values() -> [String: QueuedWorkoutCompletion] {
        guard
            let data = defaults.data(forKey: storageKey),
            let stored = try? JSONDecoder().decode(
                [String: QueuedWorkoutCompletion].self,
                from: data
            )
        else {
            return [:]
        }
        return stored
    }

    private func key(ownerId: UUID, programmingDayId: UUID) -> String {
        "\(ownerId.uuidString.lowercased()):\(programmingDayId.uuidString.lowercased())"
    }
}

struct FreeTextWorkoutDraft: Codable, Equatable, Sendable {
    let title: String
    let notes: String
    let clientRequestId: UUID?
}

protocol FreeTextWorkoutDraftStoring {
    func load(ownerId: UUID, trackId: UUID, workoutDate: String) -> FreeTextWorkoutDraft?
    func save(
        _ draft: FreeTextWorkoutDraft,
        ownerId: UUID,
        trackId: UUID,
        workoutDate: String
    )
    func delete(ownerId: UUID, trackId: UUID, workoutDate: String)
}

final class UserDefaultsFreeTextWorkoutDraftStore: FreeTextWorkoutDraftStoring {
    private let defaults: UserDefaults
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "com.ocgymbend.traininglog.free-text-drafts.v1"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func load(ownerId: UUID, trackId: UUID, workoutDate: String) -> FreeTextWorkoutDraft? {
        values()[key(ownerId: ownerId, trackId: trackId, workoutDate: workoutDate)]
    }

    func save(
        _ draft: FreeTextWorkoutDraft,
        ownerId: UUID,
        trackId: UUID,
        workoutDate: String
    ) {
        var stored = values()
        stored[key(ownerId: ownerId, trackId: trackId, workoutDate: workoutDate)] = draft
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: storageKey)
    }

    func delete(ownerId: UUID, trackId: UUID, workoutDate: String) {
        var stored = values()
        stored.removeValue(forKey: key(ownerId: ownerId, trackId: trackId, workoutDate: workoutDate))
        if stored.isEmpty {
            defaults.removeObject(forKey: storageKey)
        } else if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func values() -> [String: FreeTextWorkoutDraft] {
        guard
            let data = defaults.data(forKey: storageKey),
            let stored = try? JSONDecoder().decode([String: FreeTextWorkoutDraft].self, from: data)
        else { return [:] }
        return stored
    }

    private func key(ownerId: UUID, trackId: UUID, workoutDate: String) -> String {
        "\(ownerId.uuidString.lowercased()):\(trackId.uuidString.lowercased()):\(workoutDate)"
    }
}

struct QueuedFreeTextWorkout: Codable, Equatable, Sendable {
    let trackId: UUID
    let request: FreeTextWorkoutRequest
    let status: QueuedCompletionStatus
}

protocol FreeTextWorkoutQueueStoring {
    func workouts(ownerId: UUID) -> [QueuedFreeTextWorkout]
    func save(_ workout: QueuedFreeTextWorkout, ownerId: UUID)
    func delete(ownerId: UUID, trackId: UUID, workoutDate: String)
}

final class UserDefaultsFreeTextWorkoutQueueStore: FreeTextWorkoutQueueStoring {
    private let defaults: UserDefaults
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "com.ocgymbend.traininglog.free-text-queue.v1"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func workouts(ownerId: UUID) -> [QueuedFreeTextWorkout] {
        let prefix = "\(ownerId.uuidString.lowercased()):"
        return values().filter { $0.key.hasPrefix(prefix) }.map(\.value).sorted {
            if $0.request.workoutDate == $1.request.workoutDate {
                return $0.trackId.uuidString < $1.trackId.uuidString
            }
            return $0.request.workoutDate < $1.request.workoutDate
        }
    }

    func save(_ workout: QueuedFreeTextWorkout, ownerId: UUID) {
        var stored = values()
        stored[key(ownerId: ownerId, trackId: workout.trackId, workoutDate: workout.request.workoutDate)] = workout
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: storageKey)
    }

    func delete(ownerId: UUID, trackId: UUID, workoutDate: String) {
        var stored = values()
        stored.removeValue(forKey: key(ownerId: ownerId, trackId: trackId, workoutDate: workoutDate))
        if stored.isEmpty {
            defaults.removeObject(forKey: storageKey)
        } else if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func values() -> [String: QueuedFreeTextWorkout] {
        guard
            let data = defaults.data(forKey: storageKey),
            let stored = try? JSONDecoder().decode([String: QueuedFreeTextWorkout].self, from: data)
        else { return [:] }
        return stored
    }

    private func key(ownerId: UUID, trackId: UUID, workoutDate: String) -> String {
        "\(ownerId.uuidString.lowercased()):\(trackId.uuidString.lowercased()):\(workoutDate)"
    }
}
