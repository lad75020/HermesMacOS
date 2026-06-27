import XCTest
@testable import HermesMacOS

final class EndpointAndRequestContractTests: XCTestCase {
    func testHostEndpointNormalizationAndPorts() {
        XCTAssertEqual(HermesHostEndpoints.normalizedHost("http://localhost:8642/v1"), "localhost")
        XCTAssertEqual(HermesHostEndpoints.tcpPort(from: "http://localhost:8642/v1", fallback: "0"), "8642")
        XCTAssertEqual(HermesHostEndpoints.httpURLString(host: "localhost", port: "8642", path: "/v1"), "http://localhost:8642/v1")
    }

    func testRequestFailureClassifierRecognizesTimeoutAndNetworkLoss() {
        XCTAssertTrue(HermesRequestFailureClassifier.isTimeoutOrNetworkLoss(URLError(.timedOut)))
        XCTAssertTrue(HermesRequestFailureClassifier.isTimeoutOrNetworkLoss("network connection was lost"))
        XCTAssertFalse(HermesRequestFailureClassifier.isTimeoutOrNetworkLoss("validation failed"))
    }

    func testSensitiveRemotePlaintextIsRejectedBeforeCredentials() {
        XCTAssertNoThrow(try HermesEndpointSecurity.validateSensitiveURL(URL(string: "http://localhost:8642/v1")!))
        XCTAssertThrowsError(try HermesEndpointSecurity.validateSensitiveURL(URL(string: "http://example.com:8642/v1")!))
    }


    func testHermesRequestMetadataCoverageIncludesHeadersAndCancellation() {
        let askCoverage = HermesMacOSTestCoverageMap.subcategories(for: "ask-hermes")
        let chatCoverage = HermesMacOSTestCoverageMap.subcategories(for: "chat-hermes")
        XCTAssertTrue(askCoverage.contains("previous response continuation"))
        XCTAssertTrue(chatCoverage.contains("session continuation headers"))
        XCTAssertEqual(HermesAPISettings.requestCancelURL(from: "http://localhost:8642/v1", requestID: "req-contract")?.path, "/v1/requests/req-contract/cancel")
        XCTAssertTrue(HermesMacOSTestCoverageMap.category("ask-hermes").defaultCoverage.contains { $0.contains("EndpointAndRequestContractTests") })
    }
}
