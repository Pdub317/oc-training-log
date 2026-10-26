import Foundation
import Supabase
import Testing
@testable import OCTrainingLog

struct SupabaseConfigurationTests {
    @Test func readsPublicClientConfiguration() throws {
        let configuration = try SupabaseConfiguration(values: [
            "OCSupabaseURL": "http://127.0.0.1:54321",
            "OCSupabasePublishableKey": "publishable-key",
        ])

        #expect(configuration.url.absoluteString == "http://127.0.0.1:54321")
        #expect(configuration.publishableKey == "publishable-key")
    }

    @Test func rejectsUnexpandedBuildSettings() {
        #expect(throws: SupabaseConfiguration.ConfigurationError.self) {
            try SupabaseConfiguration(values: [
                "OCSupabaseURL": "$(SUPABASE_URL)",
                "OCSupabasePublishableKey": "$(SUPABASE_PUBLISHABLE_KEY)",
            ])
        }
    }

    @Test func buildsClientWithSecureSessionConfiguration() throws {
        let configuration = try SupabaseConfiguration(values: [
            "OCSupabaseURL": "http://127.0.0.1:54321",
            "OCSupabasePublishableKey": "publishable-key",
        ])

        let client = SupabaseClientFactory.make(configuration: configuration)
        #expect(client.auth.currentSession == nil)
    }
}
