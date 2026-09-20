/// Locally measured and server-provided information about a Jev decision.
public struct DecisionMetadata: Sendable, Equatable {
    /// End-to-end latency measured by JevKit.
    public let latency: Duration
    /// A server request ID when a transport can provide one.
    public let requestID: String?
    /// The model reported by Jev.
    public let model: String?
    /// Token usage reported by Jev.
    public let usage: Usage?

    public init(latency: Duration, requestID: String? = nil, model: String? = nil, usage: Usage? = nil) {
        self.latency = latency
        self.requestID = requestID
        self.model = model
        self.usage = usage
    }
}

/// A Choice result mapped to a caller-supplied Swift type.
public struct ChoiceAnswer<Option: Hashable & Sendable>: Sendable {
    /// The highest-probability option selected by Jev.
    public let value: Option
    /// Probability for every option supplied by the caller.
    public let probabilities: [Option: Double]
    /// API-provided confidence derived from the probability distribution.
    public let confidence: Double
    /// Local latency and optional Jev metadata.
    public let metadata: DecisionMetadata
}

/// A Noul result, representing Jev's probability that a condition is true.
public struct NoulAnswer: Sendable {
    /// Probability the binary condition is true, in 0...1.
    public let probability: Double
    /// Local latency and optional Jev metadata.
    public let metadata: DecisionMetadata
}

/// The typed wire answers returned for a group of independent System One questions.
///
/// This preserves the server's one-request fan-out so an application can map each
/// answer to its own domain type without making separate network calls.
public struct BatchDecision: Sendable, Equatable {
    public let answers: [String: WireAnswer]
    public let metadata: DecisionMetadata

    public init(answers: [String: WireAnswer], metadata: DecisionMetadata) {
        self.answers = answers
        self.metadata = metadata
    }
}

/// A Score result across ordered descriptive levels.
public struct ScoreAnswer: Sendable {
    /// Jev's probability-weighted score.
    public let score: Double
    /// Probability associated with each zero-based criterion level.
    public let probabilities: [Int: Double]
    /// API-provided confidence derived from the probability distribution.
    public let confidence: Double
    /// Returned level descriptions keyed by zero-based level.
    public let legend: [Int: JSONValue]
    /// Local latency and optional Jev metadata.
    public let metadata: DecisionMetadata
}

/// The deterministic action category associated with a confidence value.
public enum PolicyDisposition: Sendable, Equatable {
    case automatic
    case suggest
    case uncertain
}

/// A deterministic policy for consuming Choice or Score confidence.
public struct DecisionPolicy: Sendable {
    public let automaticThreshold: Double
    public let suggestionThreshold: Double

    public init(automaticThreshold: Double, suggestionThreshold: Double) throws {
        guard (0...1).contains(automaticThreshold),
              (0...1).contains(suggestionThreshold),
              automaticThreshold >= suggestionThreshold else {
            throw JevError.invalidConfiguration
        }
        self.automaticThreshold = automaticThreshold
        self.suggestionThreshold = suggestionThreshold
    }

    /// Classifies confidence without performing an application action.
    public func disposition(for confidence: Double) -> PolicyDisposition {
        if confidence >= automaticThreshold { return .automatic }
        if confidence >= suggestionThreshold { return .suggest }
        return .uncertain
    }
}
