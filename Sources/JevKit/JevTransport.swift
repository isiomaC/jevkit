import Foundation

/// The boundary between JevKit's typed client and a concrete Jev transport.
public protocol JevTransport: Sendable {
    /// Sends one documented TypeSafe System One request.
    func send(_ request: JevRequest) async throws -> JevResponse
}

/// A Codable JSON value used only at the Jev transport boundary.
public indirect enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else { throw DecodingError.typeMismatch(JSONValue.self, .init(codingPath: decoder.codingPath, debugDescription: "Expected a JSON value.")) }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

/// The documented request body for TypeSafe's System One API.
public struct JevRequest: Codable, Sendable, Equatable {
    public let state: JSONValue
    public let model: String
    public let questions: [String: WireQuestion]

    public init(state: JSONValue, model: String, questions: [String: WireQuestion]) {
        self.state = state
        self.model = model
        self.questions = questions
    }
}

/// A documented Jev question.
public enum WireQuestion: Codable, Sendable, Equatable {
    case choice(instructions: JSONValue, criteria: [String: JSONValue])
    case noul(instructions: JSONValue, criteria: [String: JSONValue]?)
    case score(instructions: JSONValue, criteria: [JSONValue])

    private enum CodingKeys: String, CodingKey { case type, instructions, criteria }
    private enum Kind: String, Codable { case choice, noul, score }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .type)
        let instructions = try container.decode(JSONValue.self, forKey: .instructions)
        switch kind {
        case .choice: self = .choice(instructions: instructions, criteria: try container.decode([String: JSONValue].self, forKey: .criteria))
        case .noul: self = .noul(instructions: instructions, criteria: try container.decodeIfPresent([String: JSONValue].self, forKey: .criteria))
        case .score: self = .score(instructions: instructions, criteria: try container.decode([JSONValue].self, forKey: .criteria))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .choice(let instructions, let criteria):
            try container.encode(Kind.choice, forKey: .type); try container.encode(instructions, forKey: .instructions); try container.encode(criteria, forKey: .criteria)
        case .noul(let instructions, let criteria):
            try container.encode(Kind.noul, forKey: .type); try container.encode(instructions, forKey: .instructions); try container.encodeIfPresent(criteria, forKey: .criteria)
        case .score(let instructions, let criteria):
            try container.encode(Kind.score, forKey: .type); try container.encode(instructions, forKey: .instructions); try container.encode(criteria, forKey: .criteria)
        }
    }
}

/// A documented Jev response body.
public struct JevResponse: Codable, Sendable, Equatable {
    public let model: String
    public let answers: [String: WireAnswer]
    public let usage: Usage?

    public init(model: String, answers: [String: WireAnswer], usage: Usage?) {
        self.model = model
        self.answers = answers
        self.usage = usage
    }
}

/// A documented Jev answer.
public enum WireAnswer: Codable, Sendable, Equatable {
    case choice(choice: String, probabilities: [String: Double], confidence: Double)
    case noul(Double)
    case score(score: Double, legend: [String: JSONValue], probabilities: [String: Double], confidence: Double)

    private enum CodingKeys: String, CodingKey { case type, choice, probabilities, confidence, noul, score, legend }
    private enum Kind: String, Codable { case choice, noul, score }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .choice:
            self = .choice(choice: try container.decode(String.self, forKey: .choice), probabilities: try container.decode([String: Double].self, forKey: .probabilities), confidence: try container.decode(Double.self, forKey: .confidence))
        case .noul:
            self = .noul(try container.decode(Double.self, forKey: .noul))
        case .score:
            self = .score(score: try container.decode(Double.self, forKey: .score), legend: try container.decode([String: JSONValue].self, forKey: .legend), probabilities: try container.decode([String: Double].self, forKey: .probabilities), confidence: try container.decode(Double.self, forKey: .confidence))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .choice(let choice, let probabilities, let confidence):
            try container.encode(Kind.choice, forKey: .type); try container.encode(choice, forKey: .choice); try container.encode(probabilities, forKey: .probabilities); try container.encode(confidence, forKey: .confidence)
        case .noul(let probability):
            try container.encode(Kind.noul, forKey: .type); try container.encode(probability, forKey: .noul)
        case .score(let score, let legend, let probabilities, let confidence):
            try container.encode(Kind.score, forKey: .type); try container.encode(score, forKey: .score); try container.encode(legend, forKey: .legend); try container.encode(probabilities, forKey: .probabilities); try container.encode(confidence, forKey: .confidence)
        }
    }
}

/// Token counts returned by the Jev API.
public struct Usage: Codable, Sendable, Equatable {
    public let inputTokens: Int
    public let outputTokens: Int

    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    private enum CodingKeys: String, CodingKey { case inputTokens = "input_tokens", outputTokens = "output_tokens" }
}
