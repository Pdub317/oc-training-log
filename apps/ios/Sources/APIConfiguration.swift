import Foundation

struct APIConfiguration: Equatable, Sendable {
    let baseURL: URL

    enum ConfigurationError: LocalizedError, Equatable {
        case missingValue(String)
        case invalidURL

        var errorDescription: String? {
            switch self {
            case .missingValue(let name):
                "Missing required app configuration: \(name)."
            case .invalidURL:
                "The configured API URL is invalid."
            }
        }
    }

    init(values: [String: Any]) throws {
        guard let rawValue = values["OCAPIBaseURL"] as? String else {
            throw ConfigurationError.missingValue("OCAPIBaseURL")
        }

        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.hasPrefix("$(") else {
            throw ConfigurationError.missingValue("OCAPIBaseURL")
        }

        guard
            let parsedURL = URL(string: value),
            parsedURL.scheme == "http" || parsedURL.scheme == "https",
            parsedURL.host != nil
        else {
            throw ConfigurationError.invalidURL
        }

        baseURL = parsedURL
    }

    init(bundle: Bundle = .main) throws {
        try self.init(values: bundle.infoDictionary ?? [:])
    }
}
