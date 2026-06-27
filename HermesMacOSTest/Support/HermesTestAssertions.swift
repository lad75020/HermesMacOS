import Foundation
import XCTest
@testable import HermesMacOS

enum HermesTestAssertions {
    static let fakeAPIKey = "sk-" + String(repeating: "A", count: 24)
    static let fakeDashboardToken = "dashboard-token-test-only"
    static let fakeSSHKey = "-----BEGIN PRIVATE KEY-----\nfake-test-key\n-----END PRIVATE KEY-----"
    static let fakePrompt = "summarize project with api_key=not-a-real-test-token-with-enough-length"

    static var repositoryRoot: URL {
        var current = URL(fileURLWithPath: #filePath)
        for _ in 0..<12 {
            current.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: current.appendingPathComponent("project.yml").path) {
                return current
            }
        }
        XCTFail("Unable to locate repository root from \(#filePath)")
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    static func repositoryFile(_ relativePath: String) -> URL {
        repositoryRoot.appendingPathComponent(relativePath)
    }

    static func readRepositoryFile(_ relativePath: String, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let url = repositoryFile(relativePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Missing repository file: \(relativePath)", file: file, line: line)
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func assertNoSecretLeak(_ text: String, secrets: [String] = [fakeAPIKey, fakeDashboardToken, fakeSSHKey], file: StaticString = #filePath, line: UInt = #line) {
        for secret in secrets where !secret.isEmpty {
            XCTAssertFalse(text.contains(secret), "Output leaked fake secret: \(secret)", file: file, line: line)
        }
    }

    static func assertRedacts(_ input: String, file: StaticString = #filePath, line: UInt = #line) {
        let redacted = HermesSecretRedactor.redact(input)
        assertNoSecretLeak(redacted, file: file, line: line)
        XCTAssertTrue(
            redacted.contains("[REDACTED]") || redacted.contains("[PRIVATE KEY REDACTED]") || redacted.contains("[DATA URL REDACTED]") || redacted.contains("[OPENAI KEY REDACTED]") || redacted.contains("[TOKEN REDACTED]") || redacted.contains("[JWT REDACTED]"),
            "Expected redacted marker in: \(redacted)",
            file: file,
            line: line
        )
    }

    static func assertTaskManifestContains(_ relativePath: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let tasks = try readRepositoryFile("specs/013-hermesmacos-test-target/tasks.md", file: file, line: line)
        XCTAssertTrue(tasks.contains(relativePath), "tasks.md should reference \(relativePath)", file: file, line: line)
    }
}
