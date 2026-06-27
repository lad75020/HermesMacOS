import XCTest
@testable import HermesMacOS

final class LocalRuntimeWorkflowTests: XCTestCase {
    func testTemporaryRuntimeFixtureNeverUsesRealHermesHome() throws {
        let fixture = try HermesTemporaryRuntimeFixture(testName: #function)
        fixture.assertNotRealHermesHome()
        XCTAssertTrue(try fixture.read("config.yaml").contains("mcp_servers"))
    }

    func testMCPServerYAMLFixtureParsesAndPreservesDisabledState() throws {
        let yaml = try HermesFixtureLoader.string(named: "runtime-fixtures", extension: "yaml", subdirectory: "LocalRuntime")
        let servers = HermesMCPServersYAML.parseServers(from: yaml)
        XCTAssertTrue(servers.contains { $0.name == "fixture" && $0.command == "echo" })
        XCTAssertTrue(servers.contains { $0.name == "disabled_server" && $0.disabled })
    }
}
