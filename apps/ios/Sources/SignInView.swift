import SwiftUI

struct SignInView: View {
    @ObservedObject var authentication: AuthenticationModel
    @State private var showingRecovery = false
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                } header: {
                    Text("Member sign in")
                } footer: {
                    Text("Use the email address associated with your OC Gym Bend membership.")
                }

                Section {
                    Button("Forgot password?") { showingRecovery = true }
                }

                if let errorMessage = authentication.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Brand.red)
                            .accessibilityLabel("Sign-in error: \(errorMessage)")
                    }
                }

                Section {
                    Button {
                        Task {
                            await authentication.signIn(email: email, password: password)
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if authentication.state == .signingIn {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Sign in")
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.red)
                    .disabled(
                        authentication.state == .signingIn
                            || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || password.isEmpty
                    )
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Training Log")
        }
        .sheet(isPresented: $showingRecovery) { PasswordManagementView() }
    }
}
