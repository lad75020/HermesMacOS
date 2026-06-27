import Foundation
import XCTest

final class HermesTemporaryRuntimeFixture {
    let rootURL: URL
    let hermesHomeURL: URL
    let repositoryURL: URL

    init(testName: String = #function) throws {
        let sanitized = testName.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent("HermesMacOSTest-\(sanitized)-\(UUID().uuidString)", isDirectory: true)
        hermesHomeURL = rootURL.appendingPathComponent(".hermes", isDirectory: true)
        repositoryURL = rootURL.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: hermesHomeURL.appendingPathComponent("profiles/default"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: repositoryURL, withIntermediateDirectories: true)
        try write("provider: test\nmodel: hermes-test\n", to: "profiles/default/config.yaml")
        try write("mcp_servers:\n  demo:\n    command: echo\n    args: [hello]\n", to: "config.yaml")
    }

    deinit {
        try? FileManager.default.removeItem(at: rootURL)
    }

    func write(_ text: String, to relativePath: String) throws {
        let url = hermesHomeURL.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    func read(_ relativePath: String) throws -> String {
        try String(contentsOf: hermesHomeURL.appendingPathComponent(relativePath), encoding: .utf8)
    }

    func assertNotRealHermesHome(file: StaticString = #filePath, line: UInt = #line) {
        let path = hermesHomeURL.standardizedFileURL.path
        XCTAssertTrue(path.contains("HermesMacOSTest-"), "Fixture must live under a test temp root", file: file, line: line)
        XCTAssertFalse(path == NSString(string: "~/.hermes").expandingTildeInPath, "Fixture must not point at the real Hermes home", file: file, line: line)
    }
}
