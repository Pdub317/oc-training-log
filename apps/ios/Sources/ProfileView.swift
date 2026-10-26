import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var localUnlock: LocalUnlockModel
    @ObservedObject var authentication: AuthenticationModel
    @StateObject private var model = MemberProfileViewModel()
    @StateObject private var reminders = ReminderSettingsViewModel()
    @StateObject private var notifications = NotificationRegistrationViewModel()
    @State private var showingPassword = false
    @State private var firstConfirmation: ProfileTrack?
    @State private var finalConfirmation: ProfileTrack?

    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .idle, .loading:
                    ProgressView("Loading profile…")
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Profile unavailable", systemImage: "person.crop.circle.badge.exclamationmark")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try again") {
                            Task { await model.load(using: authentication) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Brand.red)
                    }
                case .loaded:
                    profileForm
                }
            }
            .background(Brand.background)
            .navigationTitle("Profile")
            .task {
                if model.state == .idle {
                    await model.load(using: authentication)
                }
                if reminders.state == .idle {
                    await reminders.load(using: authentication)
                }
                if notifications.permission == .unknown {
                    await notifications.refresh(
                        registration: authentication
                    )
                }
            }
            .sheet(isPresented: $showingPassword) {
                if let ownerId = authentication.draftOwnerId, let email = model.profile?.member.email {
                    PasswordManagementView(ownerId: ownerId, accountEmail: email)
                }
            }
            .refreshable {
                await model.load(using: authentication)
            }
            .confirmationDialog(
                "Leave " + (firstConfirmation?.name ?? "this track") + "?",
                isPresented: Binding(
                    get: { firstConfirmation != nil },
                    set: { if !$0 { firstConfirmation = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Continue", role: .destructive) {
                    finalConfirmation = firstConfirmation
                    firstConfirmation = nil
                }
                Button("Cancel", role: .cancel) { firstConfirmation = nil }
            } message: {
                Text("You will stop receiving programming for this track. Your saved workouts and records will remain.")
            }
            .alert(
                "Final confirmation",
                isPresented: Binding(
                    get: { finalConfirmation != nil },
                    set: { if !$0 { finalConfirmation = nil } }
                ),
                presenting: finalConfirmation
            ) { track in
                Button("Leave " + track.code.rawValue, role: .destructive) {
                    finalConfirmation = nil
                    Task { await model.leave(track, using: authentication) }
                }
                Button("Keep membership", role: .cancel) { finalConfirmation = nil }
            } message: { track in
                Text(
                    "This removes only your " + track.name
                        + " membership. Rejoining later requires a new invitation or share link."
                )
            }
        }
    }

    private var profileForm: some View {
        Form {
            Section("Account") {
                TextField("First name", text: $model.firstName)
                    .textContentType(.givenName)
                TextField("Last name", text: $model.lastName)
                    .textContentType(.familyName)
                if let member = model.profile?.member {
                    LabeledContent("Email", value: member.email)
                    Label(
                        member.emailVerified ? "Email verified" : "Email not verified",
                        systemImage: member.emailVerified
                            ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(member.emailVerified ? .green : Brand.red)
                }
            }

            Section {
                TextField("Time zone", text: $model.timeZone)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Time zone")
            } footer: {
                Text(
                    "Used for workout dates and future reminders. Current device: "
                        + TimeZone.current.identifier
                )
            }

            Section {
                Button("Change password") { showingPassword = true }
                Toggle("Face ID / Touch ID unlock", isOn: Binding(
                    get: { localUnlock.enabled },
                    set: { value in Task { await localUnlock.setEnabled(value) } }
                ))
                .disabled(localUnlock.working)
                if localUnlock.working { ProgressView("Confirming device authentication…") }
                if let message = localUnlock.message { Text(message) }
            } header: {
                Text("Security")
            } footer: {
                Text("Protect this account on this iPhone when you reopen the app. Your device passcode is available if Face ID or Touch ID cannot be used.")
            }

            reminderSection

            notificationSection

            Section {
                Button {
                    Task { await model.save(using: authentication) }
                } label: {
                    HStack {
                        Spacer()
                        if model.saving { ProgressView() }
                        Text(model.saving ? "Saving…" : "Save profile")
                        Spacer()
                    }
                }
                .disabled(!model.canSave)
            }

            Section("Gym memberships") {
                if model.profile?.gyms.isEmpty != false {
                    Text("No active gym membership")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.profile?.gyms ?? []) { gym in
                        Label(gym.name, systemImage: "building.2.fill")
                    }
                }
            }

            Section {
                if model.profile?.tracks.isEmpty != false {
                    Text("No active training tracks. Use a valid invitation to join one.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.profile?.tracks ?? []) { track in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(track.name).font(.headline)
                                Spacer()
                                Text(track.code.rawValue).font(.headline.weight(.black))
                                    .foregroundStyle(Brand.red)
                            }
                            Text(track.gymName).font(.subheadline).foregroundStyle(.secondary)
                            Button("Leave track", role: .destructive) {
                                firstConfirmation = track
                            }
                            .disabled(model.leavingTrackId != nil)
                        }
                    }
                }
            } header: {
                Text("Training tracks")
            } footer: {
                Text("Tracks cannot be switched here. Join another track using its invitation link.")
            }

            if let status = model.statusMessage {
                Section {
                    Text(status)
                        .foregroundStyle(status.contains("couldn't") ? Brand.red : .secondary)
                }
            }

            Section {
                Button("Sign out", role: .destructive) {
                    Task { await authentication.signOut() }
                }
            }
        }
    }

    @ViewBuilder
    private var notificationSection: some View {
        Section {
            switch notifications.permission {
            case .unknown:
                HStack { ProgressView(); Text("Checking notification access…") }
            case .notDetermined:
                Button("Enable workout notifications") {
                    Task { await notifications.enable(registration: authentication) }
                }
                .disabled(notifications.working)
            case .denied:
                Label("Notifications are off", systemImage: "bell.slash.fill")
                    .foregroundStyle(Brand.red)
                Button("Open iPhone Settings") { notifications.openSettings() }
            case .authorized:
                Label(
                    notifications.deviceRegistered
                        ? "Notifications enabled" : "Notification permission granted",
                    systemImage: notifications.deviceRegistered
                        ? "bell.badge.fill" : "bell.fill"
                )
                .foregroundStyle(notifications.deviceRegistered ? .green : .primary)
                if !notifications.deviceRegistered && !notifications.working {
                    Button("Register this iPhone") {
                        Task {
                            await notifications.refresh(registration: authentication)
                        }
                    }
                }
            }
            if notifications.working { ProgressView("Registering this iPhone…") }
            if let message = notifications.statusMessage {
                Text(message).foregroundStyle(
                    notifications.deviceRegistered ? .secondary : Brand.red
                )
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text(
                "We ask only after you choose Enable. Permission and a registered iPhone are required before scheduled reminders can be delivered."
            )
        }
    }

    @ViewBuilder
    private var reminderSection: some View {
        Section {
            switch reminders.state {
            case .idle, .loading:
                HStack {
                    ProgressView()
                    Text("Loading reminder settings…")
                }
            case .failed(let message):
                Text(message).foregroundStyle(Brand.red)
                Button("Try again") {
                    Task { await reminders.load(using: authentication) }
                }
            case .loaded:
                ForEach(ReminderWeekday.allCases) { weekday in
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(
                            weekday.name,
                            isOn: Binding(
                                get: { reminders.isSelected(weekday) },
                                set: { reminders.setSelected($0, weekday: weekday) }
                            )
                        )
                        if reminders.isSelected(weekday) {
                            DatePicker(
                                "Reminder time",
                                selection: Binding(
                                    get: { reminders.time(for: weekday) },
                                    set: { reminders.setTime($0, weekday: weekday) }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                        }
                    }
                }

                if reminders.hasSelectedDays {
                    DatePicker(
                        "Time for selected days",
                        selection: $reminders.applyToAllTime,
                        displayedComponents: .hourAndMinute
                    )
                    Button("Apply this time to all selected days") {
                        reminders.applyTimeToSelectedDays()
                    }
                }

                Button {
                    Task { await reminders.save(using: authentication) }
                } label: {
                    HStack {
                        Spacer()
                        if reminders.saving { ProgressView() }
                        Text(reminders.saving ? "Saving…" : "Save reminders")
                        Spacer()
                    }
                }
                .disabled(reminders.saving)

                if let status = reminders.statusMessage {
                    Text(status)
                        .foregroundStyle(status.contains("couldn't") ? Brand.red : .secondary)
                }
            }
        } header: {
            Text("Training reminders")
        } footer: {
            Text(
                "Choose separate local times for any training days. Saving no days turns reminders off."
            )
        }
    }
}
