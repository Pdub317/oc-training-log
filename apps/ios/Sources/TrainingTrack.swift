enum TrainingTrack: String, CaseIterable, Identifiable, Sendable {
    case sportsPerformance = "SP"
    case generalPopulation = "GP"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .sportsPerformance:
            "Sports Performance"
        case .generalPopulation:
            "General Population"
        }
    }
}
