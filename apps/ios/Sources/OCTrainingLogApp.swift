import SwiftUI

@main
struct OCTrainingLogApp: App {
    @UIApplicationDelegateAdaptor(PushAppDelegate.self) private var pushAppDelegate
    @StateObject private var authentication = AuthenticationModel()
    @StateObject private var deepLinkRouter = WorkoutDeepLinkRouter.shared

    var body: some Scene {
        WindowGroup {
            Group {
                switch authentication.state {
                case .checkingSession:
                    ProgressView("Checking your session…")
                case .configurationRequired(let message):
                    ContentUnavailableView(
                        "Configuration required",
                        systemImage: "wrench.and.screwdriver",
                        description: Text(message)
                    )
                case .signedOut, .signingIn:
                    SignInView(authentication: authentication)
                case .signedIn:
                    if let ownerId = authentication.draftOwnerId {
                        UnlockedMemberView(
                            authentication: authentication,
                            deepLinkRouter: deepLinkRouter,
                            ownerId: ownerId
                        )
                        .id(ownerId)
                    }
                }
            }
            .task {
                await authentication.observeSession()
            }
            .onOpenURL { url in
                deepLinkRouter.handle(url)
            }
        }
    }
}
