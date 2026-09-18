import Foundation

/// A Foundation URLSession implementation of the documented Jev HTTP API.
public struct URLSessionJevTransport: JevTransport, Sendable {
    private let configuration: JevConfiguration
    private let session: URLSession

    /// Creates a transport. Inject a custom session only for controlled tests.
    public init(configuration: JevConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    /// Encodes, sends, validates, and decodes one Jev System One request.
    public func send(_ request: JevRequest) async throws -> JevResponse {
        var urlRequest = URLRequest(url: configuration.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = seconds(for: configuration.timeout)
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw JevError.invalidRequest("Request could not be encoded.")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch is CancellationError {
            throw JevError.cancelled
        } catch let error as URLError where error.code == .cancelled {
            throw JevError.cancelled
        } catch let error as URLError where error.code == .timedOut {
            throw JevError.timeout
        } catch {
            throw JevError.transport("Network request failed.")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JevError.transport("Jev returned a non-HTTP response.")
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try JSONDecoder().decode(JevResponse.self, from: data)
            } catch {
                throw JevError.decoding("Jev returned an invalid success response.")
            }
        case 401:
            throw JevError.authentication
        case 422:
            throw JevError.invalidRequest(errorMessage(from: data))
        case 429:
            throw JevError.rateLimited(retryAfter: retryAfter(from: httpResponse))
        default:
            throw JevError.server(statusCode: httpResponse.statusCode, message: errorMessage(from: data))
        }
    }

    private func seconds(for duration: Duration) -> TimeInterval {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }

    private func retryAfter(from response: HTTPURLResponse) -> Duration? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After"), let seconds = Double(value), seconds >= 0 else {
            return nil
        }
        return .seconds(seconds)
    }

    private func errorMessage(from data: Data) -> String? {
        struct APIError: Decodable { let message: String? }
        return try? JSONDecoder().decode(APIError.self, from: data).message
    }
}
