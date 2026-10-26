import Foundation
import Testing
@testable import OCTrainingLog

struct APIConfigurationTests {
    @Test func readsAPIBaseURL() throws {
        let configuration = try APIConfiguration(values: [
            "OCAPIBaseURL": "http://127.0.0.1:3000"
        ])

        #expect(configuration.baseURL.absoluteString == "http://127.0.0.1:3000")
    }

    @Test func rejectsMissingOrUnsupportedURLs() {
        #expect(throws: APIConfiguration.ConfigurationError.self) {
            try APIConfiguration(values: [:])
        }
        #expect(throws: APIConfiguration.ConfigurationError.self) {
            try APIConfiguration(values: ["OCAPIBaseURL": "file:///private/app"])
        }
    }
}
