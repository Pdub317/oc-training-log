import SwiftUI

struct PasswordManagementView: View {
    var ownerId: UUID?
    var accountEmail: String?
    @StateObject private var model = PasswordManagementModel()
    @Environment(\.dismiss) private var dismiss

    private var changing: Bool { ownerId != nil && accountEmail != nil }

    var body: some View {
        NavigationStack {
            Form {
                if !model.completed {
                    if changing {
                        Section {
                            SecureField("Current password", text: $model.currentPassword)
                                .textContentType(.password)
                        }
                    } else {
                        Section {
                            TextField("Email", text: $model.email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .disabled(model.codeSent)
                            if !model.verified {
                                Button(model.codeSent ? "Resend recovery code" : "Send recovery code") {
                                    Task { await model.requestCode() }
                                }
                            }
                        } footer: {
                            Text("Enter the code from your recovery email here. Codes expire after one hour. Close this screen to start again with a different email.")
                        }
                        if model.codeSent && !model.verified {
                            Section {
                                TextField("Six-digit code", text: $model.code)
                                    .textContentType(.oneTimeCode)
                                    .keyboardType(.numberPad)
                            }
                        }
                    }
                    if changing || model.codeSent {
                        Section {
                            SecureField("New password", text: $model.newPassword)
                                .textContentType(.newPassword)
                            SecureField("Confirm new password", text: $model.confirmation)
                                .textContentType(.newPassword)
                        } footer: {
                            Text("Use 12–128 characters. Passwords are saved exactly as entered, including spaces.")
                        }
                        Button("Update password") {
                            Task { await model.submit(ownerId: ownerId, accountEmail: accountEmail) }
                        }
                    }
                }
                if model.working { ProgressView("Please wait…") }
                if let message = model.message {
                    Section { Text(message).accessibilityLabel(message) }
                }
            }
            .disabled(model.working)
            .navigationTitle(changing ? "Change password" : "Reset password")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.completed ? "Done" : "Cancel") { dismiss() }
                        .disabled(model.working)
                }
            }
            .interactiveDismissDisabled(model.working)
            .onDisappear { Task { await model.close() } }
        }
    }
}
