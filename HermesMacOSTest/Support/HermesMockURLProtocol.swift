import Foundation

final class HermesMockURLProtocol: URLProtocol {
    struct Stub: Sendable {
        let statusCode: Int
        let headers: [String: String]
        let body: Data

        init(statusCode: Int = 200, headers: [String: String] = [:], body: Data = Data()) {
            self.statusCode = statusCode
            self.headers = headers
            self.body = body
        }
    }

    struct CapturedRequest: Sendable {
        let url: URL
        let method: String
        let headers: [String: String]
        let body: Data
    }

    nonisolated(unsafe) private static var stubs: [URL: Stub] = [:]
    nonisolated(unsafe) private static var capturedRequests: [CapturedRequest] = []

    static func makeSession(stubs newStubs: [URL: Stub]) -> URLSession {
        stubs = newStubs
        capturedRequests = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HermesMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func captured() -> [CapturedRequest] { capturedRequests }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let body = Self.requestBody(from: request)
        let headers = request.allHTTPHeaderFields ?? [:]
        Self.capturedRequests.append(CapturedRequest(url: url, method: request.httpMethod ?? "GET", headers: headers, body: body))
        guard let stub = Self.stubs[url] else {
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
            return
        }
        let response = HTTPURLResponse(url: url, statusCode: stub.statusCode, httpVersion: "HTTP/1.1", headerFields: stub.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func requestBody(from request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
