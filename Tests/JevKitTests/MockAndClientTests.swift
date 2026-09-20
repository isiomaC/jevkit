import Testing
@testable import JevKit

private enum Activity: String, CaseIterable, Codable, Sendable {
    case coding
    case debugging
}

@Test("Mock transport captures a sent request")
func mockCapturesSentRequest() async throws {
    let request = JevRequest(
        state: .object(["app": .string("Xcode")]),
        model: "jev-latest",
        questions: [
            "activity": .choice(
                instructions: .string("What is the activity?"),
                criteria: ["coding": .null, "debugging": .null]
            )
        ]
    )
    let response = JevResponse(
        model: "jev-latest",
        answers: [
            "activity": .choice(
                choice: "coding",
                probabilities: ["coding": 1],
                confidence: 1
            )
        ],
        usage: nil
    )
    let transport = MockJevTransport(responses: [.success(response)])

    _ = try await transport.send(request)

    let requests = await transport.recordedRequests()
    #expect(requests == [request])
}

@Test("Mock transport returns its queued error")
func mockReturnsQueuedError() async {
    let transport = MockJevTransport(responses: [.failure(.authentication)])
    let request = JevRequest(state: .null, model: "jev-latest", questions: [:])

    await #expect(throws: JevError.authentication) {
        try await transport.send(request)
    }
}

@Test("Client maps a Choice answer to the requested Swift option")
func clientMapsChoiceToRequestedOption() async throws {
    let response = JevResponse(
        model: "jev-latest",
        answers: [
            "decision": .choice(
                choice: "debugging",
                probabilities: ["coding": 0.1, "debugging": 0.9],
                confidence: 0.8
            )
        ],
        usage: Usage(inputTokens: 10, outputTokens: 2)
    )
    let client = JevClient(
        configuration: try JevConfiguration(apiKey: "test-key"),
        transport: MockJevTransport(responses: [.success(response)])
    )

    let criteria: [Activity: String?] = [.coding: nil, .debugging: nil]
    let answer: ChoiceAnswer<Activity> = try await client.choice(
        state: ["app": "Xcode"],
        instructions: "What is the user doing?",
        criteria: criteria
    )

    #expect(answer.value == Activity.debugging)
    #expect(answer.probabilities[Activity.debugging] == 0.9)
    #expect(answer.confidence == 0.8)
    #expect(answer.metadata.model == "jev-latest")
}

@Test("Client evaluates independent questions in one request")
func clientEvaluatesBatchQuestionsInOneRequest() async throws {
    let response = JevResponse(
        model: "jev-latest",
        answers: [
            "activity": .choice(choice: "coding", probabilities: ["coding": 1], confidence: 1),
            "intervention": .noul(0.75),
        ],
        usage: Usage(inputTokens: 12, outputTokens: 3)
    )
    let transport = MockJevTransport(responses: [.success(response)])
    let client = JevClient(
        configuration: try JevConfiguration(apiKey: "test-key"),
        transport: transport
    )
    let questions: [String: WireQuestion] = [
        "activity": .choice(instructions: .string("Identify activity."), criteria: ["coding": .null]),
        "intervention": .noul(instructions: .string("Would an intervention help?"), criteria: nil),
    ]

    let batch = try await client.evaluate(state: ["application": "Xcode"], questions: questions)

    #expect(batch.answers == response.answers)
    #expect(batch.metadata.model == "jev-latest")
    #expect((await transport.recordedRequests()).count == 1)
    #expect((await transport.recordedRequests()).first?.questions == questions)
}

@Test("Client can be configured with the default URLSession transport")
func clientUsesDefaultTransport() throws {
    _ = JevClient(configuration: try JevConfiguration(apiKey: "test-key"))
}
