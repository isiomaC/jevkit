/// An actor-isolated, deterministic Jev transport for tests and previews.
public actor MockJevTransport: JevTransport {
    private var queued: [Result<JevResponse, JevError>]
    private var requests: [JevRequest] = []

    /// Creates a mock that returns queued results in order.
    public init(responses: [Result<JevResponse, JevError>] = []) {
        self.queued = responses
    }

    /// Records a request and returns the next queued result.
    public func send(_ request: JevRequest) async throws -> JevResponse {
        requests.append(request)
        guard !queued.isEmpty else {
            throw JevError.transport("No queued mock response")
        }
        return try queued.removeFirst().get()
    }

    /// Returns the requests recorded so far.
    public func recordedRequests() -> [JevRequest] {
        requests
    }
}
