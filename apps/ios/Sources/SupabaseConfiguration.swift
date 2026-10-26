import Foundation
import Supabase

struct SupabaseConfiguration: Equatable, Sendable {
    let publishableKey: String
    let url: URL

    enum ConfigurationError: LocalizedError, Equatable {
        case missingValue(String)
        case invalidURL

        var errorDescription: String? {
            switch self {
            case .missingValue(let name):
                "Missing required app configuration: \(name)."
            case .invalidURL:
                "The configured Supabase URL is invalid."
            }
        }
    }

    init(values: [String: Any]) throws {
        let urlValue = try Self.requiredString("OCSupabaseURL", in: values)
        publishableKey = try Self.requiredString("OCSupabasePublishableKey", in: values)

        guard let parsedURL = URL(string: urlValue), parsedURL.scheme != nil else {
            throw ConfigurationError.invalidURL
        }

        url = parsedURL
    }

    init(bundle: Bundle = .main) throws {
        try self.init(values: bundle.infoDictionary ?? [:])
    }

    private static func requiredString(
        _ name: String,
        in values: [String: Any]
    ) throws -> String {
        guard let rawValue = values[name] as? String else {
            throw ConfigurationError.missingValue(name)
        }

        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.hasPrefix("$(") else {
            throw ConfigurationError.missingValue(name)
        }

        return value
    }
}

enum SupabaseClientFactory {
    static func make(configuration: SupabaseConfiguration) -> SupabaseClient {
        let sessionStorage = KeychainLocalStorage(
            service: "com.ocgymbend.traininglog.auth"
        )

        return SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.publishableKey,
            options: SupabaseClientOptions(
                auth: .init(
                    storage: sessionStorage,
                    storageKey: "oc-training-log.session"
                )
            )
        )
    }
}
