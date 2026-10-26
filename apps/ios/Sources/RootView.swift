import SwiftUI

struct RootView: View {
    @EnvironmentObject private var localUnlock: LocalUnlockModel
    @ObservedObject var authentication: AuthenticationModel
    @ObservedObject var deepLinkRouter: WorkoutDeepLinkRouter
    @StateObject private var today = TodayViewModel()
    @State private var selectedTab = RootTab.home
    @State private var requestedWorkoutDate: String?

    private enum RootTab: Hashable {
        case home
        case workouts
        case records
        case profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            todayView
                .tag(RootTab.home)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            HistoryView(authentication: authentication)
                .tag(RootTab.workouts)
                .tabItem {
                    Label("Workouts", systemImage: "clock.arrow.circlepath")
                }

            PersonalRecordsView(authentication: authentication)
                .tag(RootTab.records)
                .tabItem {
                    Label("PRs", systemImage: "trophy.fill")
                }

            ProfileView(authentication: authentication)
                .tag(RootTab.profile)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
        }
        .tint(Brand.red)
        .task {
            await authentication.registerCurrentDeviceIfAuthorized()
            await openPendingWorkoutDate()
        }
        .onChange(of: localUnlock.locked) { _, locked in
            if !locked { Task { await openPendingWorkoutDate() } }
        }
        .onChange(of: deepLinkRouter.pendingWorkoutDate) { _, workoutDate in
            guard workoutDate != nil else { return }
            Task { await openPendingWorkoutDate() }
        }
    }

    private var todayView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    todaySection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(Brand.background)
            .navigationBarHidden(true)
            .refreshable {
                await refreshToday()
            }
            .task {
                if today.state == .idle && deepLinkRouter.pendingWorkoutDate == nil {
                    await refreshToday()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("OC GYM BEND")
                    .font(.caption.weight(.heavy))
                    .tracking(1.5)
                    .foregroundStyle(Brand.red)

                Spacer()

                Button("Sign out") {
                    Task {
                        await authentication.signOut()
                    }
                }
                .font(.subheadline.weight(.semibold))
            }

            Text(requestedWorkoutDate == nil ? "Today" : "Log Results")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)

            HStack {
                Text(requestedWorkoutDate == nil
                     ? "Your OC Gym Bend programming"
                     : "Workout for the selected date")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if requestedWorkoutDate != nil {
                    Spacer()
                    Button("Back to Today") {
                        Task {
                            requestedWorkoutDate = nil
                            await refreshToday()
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .frame(height: 4)
        }
    }

    @ViewBuilder
    private var todaySection: some View {
        switch today.state {
        case .idle, .loading:
            HStack(spacing: 12) {
                ProgressView()
                Text("Loading workout…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 180)

        case .loaded(let responses):
            ForEach(responses) { response in
                TodayCard(
                    response: response,
                    today: today,
                    authentication: authentication
                )
            }

        case .failed(let message):
            ContentUnavailableView {
                Label("Workout unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") {
                    Task {
                        await today.load(
                            workoutDate: requestedWorkoutDate,
                            using: authentication
                        )
                        await today.retryQueuedCompletions(using: authentication)
                        await today.retryQueuedFreeTextWorkouts(using: authentication)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.red)
            }
            .frame(maxWidth: .infinity, minHeight: 280)
        }
    }

    private func refreshToday() async {
        await today.load(
            workoutDate: requestedWorkoutDate,
            using: authentication
        )
        await today.retryQueuedCompletions(using: authentication)
        await today.retryQueuedFreeTextWorkouts(using: authentication)
    }

    private func openPendingWorkoutDate() async {
        guard !localUnlock.locked else { return }
        guard let workoutDate = deepLinkRouter.consumeWorkoutDate() else { return }
        selectedTab = .home
        requestedWorkoutDate = workoutDate
        await refreshToday()
    }
}

private struct TodayCard: View {
    let response: TodayResponse
    @ObservedObject var today: TodayViewModel
    let authentication: AuthenticationModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedDate(response.workoutDate))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(response.track.name)
                        .font(.title2.bold())
                }

                Spacer()

                Text(response.track.code.rawValue)
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 40)
                    .background(Brand.red)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .accessibilityLabel(response.track.name)
            }

            switch response {
            case .published(let published):
                publishedContent(published)
            case .closed(let closed):
                VStack(alignment: .leading, spacing: 10) {
                    Label(closed.programmingDay.title, systemImage: "building.2.crop.circle")
                        .font(.title3.bold())
                    Text(closed.programmingDay.coachNotes ?? "The gym is closed. No workout can be logged for this track and date.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            case .noProgramming(let noProgramming):
                noProgrammingContent(noProgramming)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func publishedContent(_ response: PublishedToday) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(response.programmingDay.title)
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)

                if let coachNotes = response.programmingDay.coachNotes {
                    Text(coachNotes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(response.programmingDay.blocks) { block in
                WorkoutBlockView(block: block, today: today)
                    .disabled(isCompletionLocked(response.programmingDay.id))
            }

            if today.supportsCompletion(response) {
                completionForm(response)
            }
        }
    }

    private func completionForm(_ response: PublishedToday) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            Text("Workout notes (optional)")
                .font(.subheadline.weight(.semibold))
            TextField(
                "How did it feel?",
                text: Binding(
                    get: { today.notesText(for: response.programmingDay.id) },
                    set: { today.setNotesText($0, for: response.programmingDay.id) }
                ),
                axis: .vertical
            )
            .lineLimit(2...4)
            .textFieldStyle(.roundedBorder)
            .disabled(isCompletionLocked(response.programmingDay.id))

            completionStatus(response)

            Button {
                Task {
                    await today.complete(response, using: authentication)
                }
            } label: {
                HStack {
                    Spacer()
                    if today.completionState(for: response.programmingDay.id) == .submitting {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(buttonTitle(for: response.programmingDay.id))
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.red)
            .disabled(
                !today.canSubmit(response)
            )

            if !today.canSubmit(response),
               today.completionState(for: response.programmingDay.id) == .idle {
                Text("Enter a valid result for each scored movement to complete the workout.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func completionStatus(_ response: PublishedToday) -> some View {
        switch today.completionState(for: response.programmingDay.id) {
        case .completed:
            VStack(alignment: .leading, spacing: 5) {
                Label("Workout saved", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                    .accessibilityAddTraits(.isHeader)
                ForEach(
                    today.newPersonalRecords[response.programmingDay.id, default: []],
                    id: \.self
                ) { benchmark in
                    Label("New PR · \(benchmark)", systemImage: "star.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.yellow)
                }
            }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(Brand.red)
        case .queued:
            Label("Saved on this iPhone · waiting for a connection", systemImage: "icloud.and.arrow.up")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        case .conflict:
            Label(
                "This workout differs from the version already saved. It needs review.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(Brand.red)
        case .idle, .submitting:
            EmptyView()
        }
    }

    private func buttonTitle(for programmingDayId: UUID) -> String {
        switch today.completionState(for: programmingDayId) {
        case .submitting: "Saving…"
        case .completed: "Completed"
        case .queued: "Waiting to sync"
        case .conflict: "Review needed"
        case .idle, .failed: "Complete workout"
        }
    }

    private func isCompletionLocked(_ programmingDayId: UUID) -> Bool {
        switch today.completionState(for: programmingDayId) {
        case .submitting, .queued, .completed, .conflict:
            true
        case .idle, .failed:
            false
        }
    }

    private func noProgrammingContent(_ response: NoProgrammingToday) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("No programming published", systemImage: "calendar.badge.minus")
                .font(.headline)
            Text("You can still record a self-directed workout for this track and date.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField(
                "Workout title",
                text: Binding(
                    get: { today.freeTextTitle(for: response.track.id) },
                    set: { today.setFreeTextTitle($0, for: response.track.id) }
                )
            )
            .textFieldStyle(.roundedBorder)
            .disabled(isFreeTextLocked(response.track.id))

            TextField(
                "What did you do?",
                text: Binding(
                    get: { today.freeTextNotes(for: response.track.id) },
                    set: { today.setFreeTextNotes($0, for: response.track.id) }
                ),
                axis: .vertical
            )
            .lineLimit(3...7)
            .textFieldStyle(.roundedBorder)
            .disabled(isFreeTextLocked(response.track.id))

            switch today.completionState(for: response.track.id) {
            case .completed:
                Label("Workout saved", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .conflict:
                Label("A workout is already saved for this track and date.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Brand.red)
            case .failed(let message):
                Text(message).font(.caption).foregroundStyle(Brand.red)
            case .queued:
                Label(
                    "Saved on this iPhone · waiting for a connection",
                    systemImage: "icloud.and.arrow.up"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            case .idle, .submitting:
                EmptyView()
            }

            Button {
                Task { await today.completeFreeText(response, using: authentication) }
            } label: {
                HStack {
                    Spacer()
                    if today.completionState(for: response.track.id) == .submitting {
                        ProgressView().tint(.white)
                    }
                    Text(today.completionState(for: response.track.id) == .completed
                         ? "Completed" : "Save workout")
                        .fontWeight(.bold)
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.red)
            .disabled(!today.canSubmitFreeText(response))
        }
        .padding(.vertical, 8)
    }

    private func isFreeTextLocked(_ trackId: UUID) -> Bool {
        switch today.completionState(for: trackId) {
        case .submitting, .queued, .completed, .conflict:
            true
        case .idle, .failed:
            false
        }
    }

    private func formattedDate(_ dateString: String) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"

        guard let date = parser.date(from: dateString) else {
            return dateString
        }

        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEEEMMMMd")
        return formatter.string(from: date)
    }
}

private struct WorkoutBlockView: View {
    let block: TodayWorkoutBlock
    @ObservedObject var today: TodayViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(block.title)
                    .font(.headline)
                Spacer()
                if block.type.isReadOnly {
                    Text("READ ONLY")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }

            if let instructions = block.instructions {
                Text(instructions)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(block.movements) { movement in
                VStack(alignment: .leading, spacing: 5) {
                    if let optionGroupLabel = movement.optionGroupLabel {
                        Toggle(
                            isOn: Binding(
                                get: { today.isOptionSelected(movement.id) },
                                set: { today.setOptionSelected($0, for: movement.id) }
                            )
                        ) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(movement.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(optionGroupLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                    Text(movement.name)
                        .font(.subheadline.weight(.semibold))
                    }
                    Text(movement.prescriptionText)
                        .font(.body)

                    if let coachNotes = movement.coachNotes {
                        Text(coachNotes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !movement.substitutions.isEmpty {
                        Text("Options: \(movement.substitutions.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if movement.optionGroupKey == nil || today.isOptionSelected(movement.id) {
                    if movement.resultSchema == .weightedFixedReps
                        || movement.resultSchema == .weightedVariableReps {
                        HStack(spacing: 8) {
                            TextField(
                                "Weight used",
                                text: Binding(
                                    get: { today.weightText(for: movement.id) },
                                    set: { today.setWeightText($0, for: movement.id) }
                                )
                            )
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Weight used for \(movement.name) in pounds")

                            Text("lb")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }

                    if movement.resultSchema == .weightedVariableReps
                        || movement.resultSchema == .maxRepetitions {
                        HStack(spacing: 8) {
                            TextField(
                                "Completed reps",
                                text: Binding(
                                    get: { today.completedRepsText(for: movement.id) },
                                    set: { today.setCompletedRepsText($0, for: movement.id) }
                                )
                            )
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Completed repetitions for \(movement.name)")

                            Text("reps")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }

                    if movement.resultSchema == .forTime {
                        TextField(
                            "MM:SS or HH:MM:SS.0",
                            text: Binding(
                                get: { today.durationText(for: movement.id) },
                                set: { today.setDurationText($0, for: movement.id) }
                            )
                        )
                        .keyboardType(.numbersAndPunctuation)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Completion time for \(movement.name)")
                        .padding(.top, 4)
                    }

                    if movement.resultSchema == .heightOrDistance {
                        HStack(spacing: 8) {
                            TextField(
                                "Height or distance",
                                text: Binding(
                                    get: { today.measurementText(for: movement.id) },
                                    set: { today.setMeasurementText($0, for: movement.id) }
                                )
                            )
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Height or distance for \(movement.name)")

                            Picker(
                                "Unit",
                                selection: Binding(
                                    get: { today.measurementUnit(for: movement.id) },
                                    set: { today.setMeasurementUnit($0, for: movement.id) }
                                )
                            ) {
                                ForEach(MeasurementUnit.allCases) { unit in
                                    Text(unit.rawValue).tag(unit)
                                }
                            }
                            .pickerStyle(.menu)
                            .accessibilityLabel("Measurement unit for \(movement.name)")
                        }
                        .padding(.top, 4)
                    }

                    if movement.resultSchema == .caloriesOrDistance {
                        HStack(spacing: 8) {
                            TextField(
                                "Calories or distance",
                                text: Binding(
                                    get: { today.activityResultText(for: movement.id) },
                                    set: { today.setActivityResultText($0, for: movement.id) }
                                )
                            )
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Calories or distance for \(movement.name)")

                            Picker(
                                "Unit",
                                selection: Binding(
                                    get: { today.activityResultUnit(for: movement.id) },
                                    set: { today.setActivityResultUnit($0, for: movement.id) }
                                )
                            ) {
                                ForEach(ActivityResultUnit.allCases) { unit in
                                    Text(unit.rawValue).tag(unit)
                                }
                            }
                            .pickerStyle(.menu)
                            .accessibilityLabel("Result unit for \(movement.name)")
                        }
                        .padding(.top, 4)
                    }

                    if movement.resultSchema == .roundsAndReps {
                        HStack(spacing: 8) {
                            TextField(
                                "Rounds",
                                text: Binding(
                                    get: { today.completedRoundsText(for: movement.id) },
                                    set: { today.setCompletedRoundsText($0, for: movement.id) }
                                )
                            )
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Completed rounds for \(movement.name)")

                            TextField(
                                "Remaining reps",
                                text: Binding(
                                    get: { today.residualRepsText(for: movement.id) },
                                    set: { today.setResidualRepsText($0, for: movement.id) }
                                )
                            )
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Remaining repetitions for \(movement.name)")
                        }
                        .padding(.top, 4)
                    }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Brand.background.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(block.type.displayName)
    }
}

#Preview {
    RootView(
        authentication: AuthenticationModel(),
        deepLinkRouter: WorkoutDeepLinkRouter.shared
    )
    .environmentObject(LocalUnlockModel(ownerId: UUID()))
}
