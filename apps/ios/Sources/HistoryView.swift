import SwiftUI

struct HistoryView: View {
    @ObservedObject var authentication: AuthenticationModel
    @StateObject private var history = HistoryViewModel()
    @StateObject private var syncIssues = WorkoutSyncIssuesViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Workouts")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)

                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(Brand.background)
            .navigationBarHidden(true)
            .refreshable { await refresh() }
            .task {
                if history.state == .idle {
                    await refresh()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch history.state {
        case .idle, .loading:
            HStack(spacing: 12) {
                ProgressView()
                Text("Loading workout history…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 180)

        case .loaded:
            let responses = history.responses
            if !syncIssues.issues.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Sync issues", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(Brand.red)
                    ForEach(syncIssues.issues) { issue in
                        NavigationLink {
                            WorkoutSyncIssueView(
                                issue: issue,
                                authentication: authentication,
                                history: history,
                                syncIssues: syncIssues
                            )
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(issue.serverWorkout?.title ?? "Queued workout")
                                        .font(.subheadline.weight(.semibold))
                                    Text(issue.queued.request.workoutDate)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding(14)
                            .background(.background)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search workouts or movements", text: $history.searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { Task { await refresh() } }
                if !history.searchText.isEmpty {
                    Button {
                        history.searchText = ""
                        Task { await refresh() }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(12)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Picker("Date range", selection: $history.dateRange) {
                ForEach(HistoryDateRange.allCases) { range in
                    Text(range.label).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Workout date range")
            .onChange(of: history.dateRange) { _, _ in
                Task { await refresh() }
            }

            Toggle("PR workouts only", isOn: $history.personalRecordsOnly)
                .font(.subheadline.weight(.semibold))
                .onChange(of: history.personalRecordsOnly) { _, _ in
                    Task { await refresh() }
                }

            ForEach(responses) { response in
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(response.track.name)
                            .font(.title2.bold())
                        Spacer()
                        Text(response.track.code.rawValue)
                            .font(.headline.weight(.black))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 40)
                            .background(Brand.red)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    if response.workouts.isEmpty {
                        ContentUnavailableView(
                            history.searchText.isEmpty && history.dateRange == .all
                                ? "No completed workouts" : "No matching workouts",
                            systemImage: history.searchText.isEmpty && history.dateRange == .all
                                ? "figure.strengthtraining.traditional" : "magnifyingglass",
                            description: Text(
                                history.searchText.isEmpty && history.dateRange == .all
                                    ? "Completed workouts will appear here."
                                    : "Try a different search or date range."
                            )
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                    } else {
                        ForEach(response.workouts) { workout in
                            NavigationLink {
                                HistoryWorkoutDetail(
                                    workout: workout,
                                    authentication: authentication,
                                    history: history
                                )
                            } label: {
                                HistoryWorkoutCard(workout: workout)
                            }
                            .buttonStyle(.plain)
                        }
                        if response.nextCursor != nil {
                            Button {
                                Task {
                                    await history.loadMore(
                                        for: response,
                                        using: authentication
                                    )
                                }
                            } label: {
                                HStack {
                                    Spacer()
                                    if history.loadingMoreTrackIds.contains(response.track.id) {
                                        ProgressView()
                                    }
                                    Text("Load more workouts")
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(history.loadingMoreTrackIds.contains(response.track.id))
                        }
                    }
                }
            }

            if let message = history.paginationMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(Brand.red)
            }

        case .failed(let message):
            ContentUnavailableView {
                Label("History unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") {
                    Task { await refresh() }
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.red)
            }
            .frame(maxWidth: .infinity, minHeight: 280)
        }
    }

    private func refresh() async {
        await history.load(using: authentication)
        syncIssues.load(
            ownerId: authentication.draftOwnerId,
            historyResponses: history.responses
        )
    }
}

private struct WorkoutSyncIssueView: View {
    let issue: WorkoutSyncIssue
    let authentication: AuthenticationModel
    @ObservedObject var history: HistoryViewModel
    @ObservedObject var syncIssues: WorkoutSyncIssuesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingServerVersion = false
    @State private var confirmingIPhoneVersion = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Two versions of this workout were saved. Compare them below before choosing which one to keep.")
                    .font(.subheadline)

                versionSection(
                    title: "Currently saved",
                    notes: issue.serverWorkout?.notes,
                    rows: serverRows
                )
                versionSection(
                    title: "From this iPhone",
                    notes: issue.queued.request.notes,
                    rows: iPhoneRows
                )

                if case .failed(let message) = syncIssues.resolutionState(for: issue) {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Brand.red)
                }

                Button("Keep currently saved version") {
                    confirmingServerVersion = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.red)
                .frame(maxWidth: .infinity)

                Button("Use results from this iPhone") {
                    confirmingIPhoneVersion = true
                }
                .buttonStyle(.bordered)
                .disabled(
                    issue.serverWorkout == nil
                        || syncIssues.resolutionState(for: issue) == .resolving
                )
            }
            .padding(20)
        }
        .background(Brand.background)
        .navigationTitle("Resolve sync issue")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Discard the results queued on this iPhone?",
            isPresented: $confirmingServerVersion,
            titleVisibility: .visible
        ) {
            Button("Keep saved version", role: .destructive) {
                syncIssues.keepServerVersion(issue)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The queued iPhone version will be removed.")
        }
        .confirmationDialog(
            "Replace the currently saved workout?",
            isPresented: $confirmingIPhoneVersion,
            titleVisibility: .visible
        ) {
            Button("Use iPhone results", role: .destructive) {
                Task {
                    await syncIssues.useIPhoneVersion(issue, using: authentication)
                    if !syncIssues.issues.contains(where: { $0.id == issue.id }) {
                        await history.load(using: authentication)
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The saved workout will be replaced with the queued values shown above.")
        }
    }

    private var serverRows: [(String, String)] {
        issue.serverWorkout?.movements.map { ($0.name, $0.formattedResult) } ?? [
            ("Saved version", "Refresh History to load its results")
        ]
    }

    private var iPhoneRows: [(String, String)] {
        issue.queued.request.results.map { result in
            let name = issue.serverWorkout?.movements.first {
                $0.prescribedMovementId == result.prescribedMovementId
            }?.name ?? "Workout result"
            return (name, result.syncDisplayValue)
        }
    }

    private func versionSection(
        title: String,
        notes: String?,
        rows: [(String, String)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.bold())
            ForEach(Array(rows.enumerated()), id: \.offset) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.element.0).font(.subheadline.weight(.semibold))
                    Text(item.element.1).font(.headline)
                }
            }
            if let notes, !notes.isEmpty {
                Divider()
                Text("Notes: \(notes)").font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private extension WorkoutResultEntry {
    var syncDisplayValue: String {
        switch self {
        case .weightedFixed(_, let weight):
            "\(Self.number(weight)) lb"
        case .weightedVariable(_, let weight, let reps):
            "\(Self.number(weight)) lb × \(reps) reps"
        case .maxRepetitions(_, let reps): "\(reps) reps"
        case .forTime(_, let milliseconds):
            Self.duration(milliseconds)
        case .heightOrDistance(_, let value, let unit):
            "\(Self.number(value)) \(unit.rawValue)"
        case .caloriesOrDistance(_, let value, let unit):
            "\(Self.number(value)) \(unit.rawValue)"
        case .roundsAndReps(_, let rounds, let reps):
            "\(rounds) rounds + \(reps) reps"
        }
    }

    private static func number(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%g", value)
    }

    private static func duration(_ milliseconds: Int) -> String {
        let total = milliseconds / 1000
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        let tenths = (milliseconds % 1000) / 100
        let suffix = tenths == 0 ? "" : ".\(tenths)"
        return hours > 0
            ? String(format: "%d:%02d:%02d%@", hours, minutes, seconds, suffix)
            : String(format: "%02d:%02d%@", minutes, seconds, suffix)
    }
}

struct HistoryWorkoutDetail: View {
    let workout: HistoryWorkout
    let authentication: AuthenticationModel
    @ObservedObject var history: HistoryViewModel
    @State private var showingEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(workout.workoutDate)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(workout.title)
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                }

                ForEach(workout.movements) { movement in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(movement.name)
                                .font(.headline)
                            if movement.isPersonalRecord {
                                Label("PR", systemImage: "star.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.yellow)
                            }
                        }
                        Text(movement.formattedResult)
                            .font(.title2.bold())
                        Text(movement.prescriptionText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if let notes = workout.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Workout notes")
                            .font(.headline)
                        Text(notes)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(Brand.background)
        .navigationTitle("Workout details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") { showingEditor = true }
        }
        .sheet(isPresented: $showingEditor) {
            HistoryWorkoutEditorView(
                workout: workout,
                authentication: authentication,
                history: history
            )
        }
    }
}

private struct HistoryWorkoutEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var editor: HistoryWorkoutEditViewModel
    let authentication: AuthenticationModel
    @ObservedObject var history: HistoryViewModel

    init(
        workout: HistoryWorkout,
        authentication: AuthenticationModel,
        history: HistoryViewModel
    ) {
        _editor = StateObject(wrappedValue: HistoryWorkoutEditViewModel(workout: workout))
        self.authentication = authentication
        self.history = history
    }

    var body: some View {
        NavigationStack {
            Form {
                if editor.workout.programmingDayId == nil {
                    Section("Workout title") {
                        TextField("Workout title", text: $editor.title)
                    }
                } else {
                    Section("Results") {
                        ForEach(editor.workout.movements) { movement in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(movement.name).font(.headline)
                                resultInputs(for: movement)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section(editor.workout.programmingDayId == nil ? "Workout details" : "Workout notes") {
                    TextField(
                        editor.workout.programmingDayId == nil ? "What did you do?" : "How did it feel?",
                        text: $editor.notes,
                        axis: .vertical
                    )
                        .lineLimit(2...5)
                }

                if editor.state == .conflict {
                    Section {
                        Label(
                            "This workout changed after you opened it. Close the editor, refresh History, and review the latest version.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(Brand.red)
                    }
                } else if case .failed(let message) = editor.state {
                    Section { Text(message).foregroundStyle(Brand.red) }
                }
            }
            .navigationTitle("Edit workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editor.state == .saving ? "Saving…" : "Save") {
                        Task {
                            await editor.save(using: authentication)
                            if editor.state == .saved {
                                await history.load(using: authentication)
                                dismiss()
                            }
                        }
                    }
                    .disabled(!editor.canSave)
                }
            }
        }
    }

    @ViewBuilder
    private func resultInputs(for movement: HistoryMovement) -> some View {
        switch movement.resultSchema {
        case .weightedFixedReps:
            numericField("Weight (lb)", movement, secondary: false, decimal: true)
        case .weightedVariableReps:
            numericField("Weight (lb)", movement, secondary: false, decimal: true)
            numericField("Completed reps", movement, secondary: true, decimal: false)
        case .maxRepetitions:
            numericField("Completed reps", movement, secondary: false, decimal: false)
        case .forTime:
            numericField("MM:SS or HH:MM:SS.0", movement, secondary: false, decimal: false)
                .keyboardType(.numbersAndPunctuation)
        case .heightOrDistance:
            HStack {
                numericField("Measurement", movement, secondary: false, decimal: true)
                Picker("Unit", selection: Binding(
                    get: { editor.measurementUnit(for: movement.id) },
                    set: { editor.setMeasurementUnit($0, for: movement.id) }
                )) {
                    ForEach(MeasurementUnit.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.menu)
            }
        case .caloriesOrDistance:
            HStack {
                numericField("Result", movement, secondary: false, decimal: true)
                Picker("Unit", selection: Binding(
                    get: { editor.activityUnit(for: movement.id) },
                    set: { editor.setActivityUnit($0, for: movement.id) }
                )) {
                    ForEach(ActivityResultUnit.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.menu)
            }
        case .roundsAndReps:
            numericField("Completed rounds", movement, secondary: false, decimal: false)
            numericField("Remaining reps", movement, secondary: true, decimal: false)
        case .notesOnly:
            EmptyView()
        }
    }

    private func numericField(
        _ title: String,
        _ movement: HistoryMovement,
        secondary: Bool,
        decimal: Bool
    ) -> some View {
        TextField(title, text: Binding(
            get: {
                secondary
                    ? editor.secondaryValue(for: movement.id)
                    : editor.value(for: movement.id)
            },
            set: {
                if secondary { editor.setSecondaryValue($0, for: movement.id) }
                else { editor.setValue($0, for: movement.id) }
            }
        ))
        .keyboardType(decimal ? .decimalPad : .numberPad)
        .textFieldStyle(.roundedBorder)
    }
}

private struct HistoryWorkoutCard: View {
    let workout: HistoryWorkout

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(formattedDate(workout.workoutDate))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(workout.title)
                        .font(.headline)
                }
                Spacer()
                if workout.hasPersonalRecord {
                    Label("PR", systemImage: "star.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("Personal record workout")
                }
            }

            ForEach(workout.movements) { movement in
                HStack(alignment: .top, spacing: 10) {
                    Text(movement.blockType.displayName.prefix(1))
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Brand.red)
                        .clipShape(RoundedRectangle(cornerRadius: 3))

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(movement.name)
                                .font(.subheadline.weight(.semibold))
                            if movement.isPersonalRecord {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                    .accessibilityLabel("Personal record")
                            }
                        }
                        Text(movement.formattedResult)
                            .font(.title3.bold())
                        Text(movement.prescriptionText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let notes = workout.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formattedDate(_ dateString: String) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: dateString) else { return dateString }

        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMM d, yyyy")
        return formatter.string(from: date)
    }
}
