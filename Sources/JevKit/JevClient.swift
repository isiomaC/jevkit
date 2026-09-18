import Foundation

/// A typed asynchronous client for Jev decisions.
public struct JevClient: Sendable {
    private let configuration: JevConfiguration
    private let transport: any JevTransport

    /// Creates a client that uses Foundation URLSession for live Jev requests.
    public init(configuration: JevConfiguration) {
        self.init(configuration: configuration, transport: URLSessionJevTransport(configuration: configuration))
    }

    /// Creates a client using a caller-provided transport.
    public init(configuration: JevConfiguration, transport: any JevTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    /// Asks Jev to select an option from a closed Swift set.
    public func choice<State: Encodable & Sendable, Option: RawRepresentable & Hashable & Sendable>(
        state: State,
        instructions: String,
        criteria: [Option: String?]
    ) async throws -> ChoiceAnswer<Option> where Option.RawValue == String {
        guard !criteria.isEmpty else { throw JevError.invalidRequest("Choice criteria must not be empty.") }

        let wireCriteria = Dictionary(uniqueKeysWithValues: criteria.map { ($0.key.rawValue, $0.value.map(JSONValue.string) ?? .null) })
        let timedResponse = try await send(
            state: state,
            question: .choice(instructions: .string(instructions), criteria: wireCriteria)
        )
        let response = timedResponse.response
        guard case let .choice(selected, probabilities, confidence)? = response.answers["decision"] else {
            throw JevError.invalidResponse
        }

        try validate(probabilities: probabilities, expectedKeys: Set(criteria.keys.map(\.rawValue)))
        guard let value = criteria.keys.first(where: { $0.rawValue == selected }) else {
            throw JevError.invalidResponse
        }
        guard (0...1).contains(confidence) else { throw JevError.invalidResponse }

        let mapped = Dictionary(uniqueKeysWithValues: criteria.keys.map { option in
            (option, probabilities[option.rawValue]!)
        })
        return ChoiceAnswer(value: value, probabilities: mapped, confidence: confidence, metadata: metadata(for: response, latency: timedResponse.latency))
    }

    /// Asks Jev for the probability that a binary condition is true.
    public func noul<State: Encodable & Sendable>(
        state: State,
        instructions: String,
        trueCriteria: String? = nil,
        falseCriteria: String? = nil
    ) async throws -> NoulAnswer {
        var criteria: [String: JSONValue] = [:]
        if let trueCriteria { criteria["true"] = .string(trueCriteria) }
        if let falseCriteria { criteria["false"] = .string(falseCriteria) }
        let timedResponse = try await send(state: state, question: .noul(instructions: .string(instructions), criteria: criteria.isEmpty ? nil : criteria))
        let response = timedResponse.response
        guard case let .noul(probability)? = response.answers["decision"], (0...1).contains(probability) else {
            throw JevError.invalidResponse
        }
        return NoulAnswer(probability: probability, metadata: metadata(for: response, latency: timedResponse.latency))
    }

    /// Asks Jev to rate state against at least two ordered criteria.
    public func score<State: Encodable & Sendable>(
        state: State,
        instructions: String,
        criteria: [String]
    ) async throws -> ScoreAnswer {
        guard criteria.count >= 2 else { throw JevError.invalidRequest("Score requires at least two criteria.") }
        let timedResponse = try await send(state: state, question: .score(instructions: .string(instructions), criteria: criteria.map(JSONValue.string)))
        let response = timedResponse.response
        guard case let .score(score, legend, probabilities, confidence)? = response.answers["decision"], (0...1).contains(confidence) else {
            throw JevError.invalidResponse
        }
        let expected = Set(criteria.indices.map(String.init))
        try validate(probabilities: probabilities, expectedKeys: expected)
        guard let indexedProbabilities = dictionaryWithIntegerKeys(probabilities), let indexedLegend = dictionaryWithIntegerKeys(legend) else {
            throw JevError.invalidResponse
        }
        return ScoreAnswer(score: score, probabilities: indexedProbabilities, confidence: confidence, legend: indexedLegend, metadata: metadata(for: response, latency: timedResponse.latency))
    }

    private func send<State: Encodable & Sendable>(state: State, question: WireQuestion) async throws -> (response: JevResponse, latency: Duration) {
        let state = try encode(state)
        let request = JevRequest(state: state, model: configuration.model, questions: ["decision": question])
        let clock = ContinuousClock()
        let start = clock.now
        let response: JevResponse
        do {
            response = try await transport.send(request)
        } catch is CancellationError {
            throw JevError.cancelled
        }
        return (response, start.duration(to: clock.now))
    }

    private func metadata(for response: JevResponse, latency: Duration) -> DecisionMetadata {
        DecisionMetadata(latency: latency, model: response.model, usage: response.usage)
    }

    private func encode<State: Encodable>(_ state: State) throws -> JSONValue {
        do {
            return try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(state))
        } catch {
            throw JevError.invalidRequest("State must be JSON encodable.")
        }
    }

    private func validate(probabilities: [String: Double], expectedKeys: Set<String>) throws {
        guard Set(probabilities.keys) == expectedKeys,
              probabilities.values.allSatisfy({ (0...1).contains($0) }),
              abs(probabilities.values.reduce(0, +) - 1) <= 0.000_001 else {
            throw JevError.invalidResponse
        }
    }

    private func dictionaryWithIntegerKeys<Value>(_ values: [String: Value]) -> [Int: Value]? {
        var result: [Int: Value] = [:]
        for (key, value) in values {
            guard let index = Int(key), index >= 0 else { return nil }
            result[index] = value
        }
        return result
    }
}
