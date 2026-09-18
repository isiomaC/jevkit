import Testing
@testable import JevKit

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
