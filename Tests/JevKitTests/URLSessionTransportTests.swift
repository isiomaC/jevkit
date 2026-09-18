import Foundation
import Testing
@testable import JevKit

private final class TestURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let (response, data) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func requestBody(from request: URLRequest) throws -> Data {
    if let body = request.httpBody { return body }
    let stream = try #require(request.httpBodyStream)
    stream.open()
    defer { stream.close() }
    var result = Data()
    var buffer = [UInt8](repeating: 0, count: 1_024)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        guard count >= 0 else { throw stream.streamError ?? URLError(.cannotDecodeContentData) }
        result.append(buffer, count: count)
    }
    return result
}

@Test("URLSession transport encodes the documented Jev request")
func urlSessionTransportEncodesDocumentedRequest() async throws {
    let endpoint = URL(string: "https://example.test/v1/systemone")!
    let configuration = try JevConfiguration(apiKey: "test-key", endpoint: endpoint)
    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [TestURLProtocol.self]
    let session = URLSession(configuration: sessionConfiguration)
    TestURLProtocol.handler = { request in
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.url == endpoint)
        let body = try requestBody(from: request)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(json?["model"] as? String == "jev-latest")
        let response = HTTPURLResponse(url: endpoint, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let data = #"{"model":"jev-latest","answers":{"decision":{"type":"noul","noul":0.75}},"usage":{"input_tokens":1,"output_tokens":1}}"#.data(using: .utf8)!
        return (response, data)
    }
    let transport = URLSessionJevTransport(configuration: configuration, session: session)
    let request = JevRequest(state: .string("hello"), model: "jev-latest", questions: ["decision": .noul(instructions: .string("Is this a greeting?"), criteria: nil)])

    let response = try await transport.send(request)

    #expect(response.answers["decision"] == .noul(0.75))
}
