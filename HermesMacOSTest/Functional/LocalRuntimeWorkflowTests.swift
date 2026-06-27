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


    func testLocalRuntimeSubcategoryCoverageMatchesFR009() throws {
        let subcategories = HermesMacOSTestCoverageMap.subcategories(for: "local-runtime")
        XCTAssertTrue(subcategories.isSuperset(of: Set(["profile config", "model provider settings", "MCP YAML editing", "Hermes CLI refresh", "Hermes CLI add", "repository status", "repository preview", "repository update review", "dirty state", "conflict state", "Git", "SSH", "temporary local files only"])))
        let fixture = try HermesTemporaryRuntimeFixture(testName: #function)
        fixture.assertNotRealHermesHome()
        XCTAssertTrue(try fixture.read("config.yaml").contains("mcp_servers"))
        XCTAssertTrue(HermesMacOSTestCoverageMap.category("local-runtime").defaultCoverage.contains { $0.contains("LocalRuntimeWorkflowTests") })
    }
}
