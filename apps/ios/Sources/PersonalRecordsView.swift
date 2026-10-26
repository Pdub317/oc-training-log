import SwiftUI

struct PersonalRecordsView: View {
    @ObservedObject var authentication: AuthenticationModel
    @StateObject private var records = PersonalRecordsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Personal Records")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    searchField
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(Brand.background)
            .navigationBarHidden(true)
            .refreshable { await records.load(using: authentication) }
            .task {
                if records.state == .idle { await records.load(using: authentication) }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search benchmarks", text: $records.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !records.searchText.isEmpty {
                Button { records.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(12)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var content: some View {
        switch records.state {
        case .idle, .loading:
            HStack { ProgressView(); Text("Loading personal records…").foregroundStyle(.secondary) }
                .frame(maxWidth: .infinity, minHeight: 180)
        case .loaded:
            ForEach(records.filteredResponses) { response in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(response.track.name).font(.title2.bold())
                        Spacer()
                        Text(response.track.code.rawValue)
                            .font(.headline.weight(.black)).foregroundStyle(.white)
                            .frame(width: 48, height: 40).background(Brand.red)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    if response.benchmarks.isEmpty {
                        ContentUnavailableView(
                            records.searchText.isEmpty ? "No benchmarks" : "No matching benchmarks",
                            systemImage: "trophy",
                            description: Text(records.searchText.isEmpty
                                ? "Benchmarks will appear after the track catalog is configured."
                                : "Try a different search.")
                        )
                    } else {
                        ForEach(response.benchmarks) { benchmark in
                            NavigationLink {
                                PersonalRecordDetailView(
                                    track: response.track.code,
                                    benchmark: benchmark,
                                    authentication: authentication
                                )
                            } label: {
                                benchmarkCard(benchmark)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        case .failed(let message):
            ContentUnavailableView("Records unavailable", systemImage: "exclamationmark.triangle", description: Text(message))
        }
    }

    private func benchmarkCard(_ benchmark: PersonalRecordBenchmark) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(benchmark.label).font(.headline)
            if benchmark.currentBests.isEmpty {
                Text("No result yet").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(benchmark.currentBests) { best in
                    HStack {
                        Text(best.formattedValue).font(.title3.bold())
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16).background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct PersonalRecordDetailView: View {
    let track: TrainingTrack
    let benchmark: PersonalRecordBenchmark
    let authentication: AuthenticationModel
    @StateObject private var detail = PersonalRecordDetailViewModel()
    @State private var tab = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(benchmark.label).font(.largeTitle.bold())
                if !benchmark.currentBests.isEmpty {
                    ForEach(benchmark.currentBests) { best in
                        Text(best.formattedValue).font(.title.bold()).foregroundStyle(Brand.red)
                    }
                } else {
                    Text("No result yet").foregroundStyle(.secondary)
                }

                if benchmark.currentBests.contains(where: { $0.unit == "lb" }) {
                    Picker("Record detail", selection: $tab) {
                        Text("History").tag(0)
                        Text("Percentages").tag(1)
                    }.pickerStyle(.segmented)
                }

                switch detail.state {
                case .idle, .loading:
                    ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                case .failed(let message):
                    Text(message).foregroundStyle(Brand.red)
                case .loaded(let response):
                    if tab == 1 {
                        VStack(spacing: 16) {
                            ForEach(response.benchmark.currentBests.filter { $0.unit == "lb" }) {
                                percentageTable($0)
                            }
                        }
                    } else if response.history.isEmpty {
                        ContentUnavailableView("No record history", systemImage: "trophy")
                    } else {
                        ForEach(response.history) { entry in
                            NavigationLink {
                                PersonalRecordSourceWorkoutView(
                                    track: track,
                                    workoutLogId: entry.workoutLogId,
                                    authentication: authentication
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(entry.score.formattedValue).font(.headline)
                                        Spacer()
                                        if entry.isCurrentBest {
                                            Label("Best", systemImage: "star.fill")
                                                .foregroundStyle(.yellow)
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(entry.workoutDate).font(.subheadline).foregroundStyle(.secondary)
                                    Label(entry.workoutTitle, systemImage: "figure.strengthtraining.traditional")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16).background(.background)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(20)
        }
        .background(Brand.background)
        .navigationTitle("PR details").navigationBarTitleDisplayMode(.inline)
        .task {
            if detail.state == .idle {
                await detail.load(track: track, benchmarkId: benchmark.id, using: authentication)
            }
        }
    }

    private func percentageTable(_ score: PersonalRecordScore) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let reps = score.completedReps {
                Text("\(reps)-rep best · \(score.formattedValue)")
                    .font(.headline).padding(.vertical, 12)
            }
            ForEach(score.percentageRows, id: \.percentage) { row in
                HStack {
                    Text("\(row.percentage)%").fontWeight(.semibold)
                    Spacer()
                    Text("\(row.pounds) lb").font(.headline)
                }
                .padding(.vertical, 10)
                Divider()
            }
        }
        .padding(.horizontal, 16).background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct PersonalRecordSourceWorkoutView: View {
    let track: TrainingTrack
    let workoutLogId: UUID
    let authentication: AuthenticationModel
    @StateObject private var source = PersonalRecordSourceWorkoutViewModel()
    @StateObject private var history = HistoryViewModel()

    var body: some View {
        Group {
            switch source.state {
            case .idle, .loading:
                ProgressView("Loading source workout…")
            case .failed(let message):
                ContentUnavailableView(
                    "Workout unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            case .loaded(let workout):
                HistoryWorkoutDetail(
                    workout: workout,
                    authentication: authentication,
                    history: history
                )
            }
        }
        .task {
            if source.state == .idle {
                await source.load(
                    track: track,
                    workoutLogId: workoutLogId,
                    using: authentication
                )
            }
        }
    }
}
