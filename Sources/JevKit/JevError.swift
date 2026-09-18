/// Errors produced while configuring or communicating with the Jev service.
public enum JevError: Error, Sendable, Equatable {
    /// The supplied client configuration is invalid.
    case invalidConfiguration
    /// The service rejected the API credential.
    case authentication
    /// The service rejected a request.
    case invalidRequest(String?)
    /// The response did not match the documented Jev API schema.
    case invalidResponse
    /// The service requested that the caller slow down.
    case rateLimited(retryAfter: Duration?)
    /// Decoding a response body failed.
    case decoding(String)
    /// A non-HTTP transport failure occurred.
    case transport(String)
    /// The request exceeded its configured timeout.
    case timeout
    /// The caller cancelled the request.
    case cancelled
    /// The service returned an unexpected server error.
    case server(statusCode: Int, message: String?)
}
