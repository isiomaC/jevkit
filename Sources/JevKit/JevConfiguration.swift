import Foundation

/// Immutable configuration for a Jev client.
public struct JevConfiguration: Sendable {
    /// The host application's Jev API key. JevKit never persists this value.
    public let apiKey: String
    /// The TypeSafe System One endpoint.
    public let endpoint: URL
    /// The Jev model identifier.
    public let model: String
    /// Maximum duration for a single network attempt.
    public let timeout: Duration

    /// Creates a configuration after validating its credential is not blank.
    public init(
        apiKey: String,
        endpoint: URL = URL(string: "https://api.typesafe.ai/v1/systemone")!,
        model: String = "jev-latest",
        timeout: Duration = .seconds(30)
    ) throws {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw JevError.invalidConfiguration
        }

        self.apiKey = apiKey
        self.endpoint = endpoint
        self.model = model
        self.timeout = timeout
    }
}
