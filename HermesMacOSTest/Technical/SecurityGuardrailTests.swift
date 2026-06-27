import XCTest
@testable import HermesMacOS

final class SecurityGuardrailTests: XCTestCase {
    func testEndpointSecurityAllowsLoopbackPlaintextAndRejectsRemotePlaintext() throws {
        XCTAssertTrue(HermesEndpointSecurity.isLoopbackHost("localhost"))
        XCTAssertTrue(HermesEndpointSecurity.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(HermesEndpointSecurity.isLoopbackHost("example.com"))
        XCTAssertFalse(HermesEndpointSecurity.isRemotePlaintext(URL(string: "https://example.com")!))
        XCTAssertTrue(HermesEndpointSecurity.isRemotePlaintext(URL(string: "http://example.com")!))
    }

    func testSecretRedactorHandlesKeyLinesPrivateKeysJWTsAndDataURLs() {
        let longPayload = String(repeating: "a", count: 40)
        let keyToken = String(repeating: "b", count: 30)
        let jwtSegment = String(repeating: "c", count: 24)
        let privateKeyBlock = "-----BEGIN " + "PRIVATE KEY-----\nfake-test-key\n-----END " + "PRIVATE KEY-----"
        let input = "api_key=" + keyToken + "\n" + privateKeyBlock + "\n" + jwtSegment + "." + jwtSegment + "." + jwtSegment + "\n" + "data:image/png;base64," + longPayload
        let redacted = HermesSecretRedactor.redact(input)
        XCTAssertFalse(redacted.contains(longPayload))
        XCTAssertFalse(redacted.contains(keyToken))
        XCTAssertFalse(redacted.contains("fake-test-key"))
        XCTAssertTrue(redacted.contains("[PRIVATE KEY REDACTED]"))
        XCTAssertTrue(redacted.contains("[DATA URL REDACTED]"))
        XCTAssertTrue(redacted.contains("[JWT REDACTED]"))
    }

    func testFilesystemPolicyStandardizesPathsBeforeApproval() {
        let standardized = HermesFilesystemAccessPolicy.standardizedPath("/tmp/../tmp/hermes")
        XCTAssertEqual(standardized, "/tmp/hermes")
    }
}
