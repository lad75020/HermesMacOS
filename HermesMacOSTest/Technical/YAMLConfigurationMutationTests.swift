import XCTest
@testable import HermesMacOS

final class YAMLConfigurationMutationTests: XCTestCase {
    func testMCPYAMLUpsertPreservesExistingDisabledServer() throws {
        let yaml = try HermesFixtureLoader.string(named: "runtime-fixtures", extension: "yaml", subdirectory: "LocalRuntime")
        let replacement = HermesDashboardMCPServer(name: "fixture", command: "python3", args: ["-m", "demo"], url: nil, disabled: false, auth: nil, env: ["HERMES_TEST_TOKEN": "fake-token"], headers: [:], toolsInclude: ["alpha"], toolsExclude: nil)
        let updated = HermesMCPServersYAML.upsertingServer(replacement, in: yaml)
        XCTAssertTrue(updated.contains("disabled_server"))
        XCTAssertTrue(updated.contains("python3"))
        XCTAssertTrue(updated.contains("tools:"))
        XCTAssertTrue(updated.contains("include:"))
    }

    func testMCPYAMLRemovalDoesNotRemoveUnrelatedServers() throws {
        let yaml = try HermesFixtureLoader.string(named: "runtime-fixtures", extension: "yaml", subdirectory: "LocalRuntime")
        let updated = try HermesMCPServersYAML.removingServer(named: "fixture", from: yaml)
        XCTAssertFalse(updated.contains("  fixture:"))
        XCTAssertTrue(updated.contains("disabled_server"))
    }


    func testYAMLAndRawConfigurationCoverageMatchesFR013() throws {
        let configuration = HermesMacOSTestCoverageMap.subcategories(for: "configuration")
        XCTAssertTrue(configuration.isSuperset(of: Set(["profiles", "models", "skills", "schedules", "plugins", "toolsets", "MCP servers", "raw config", "mutation failure handling"])))
        let localRuntime = HermesMacOSTestCoverageMap.subcategories(for: "local-runtime")
        XCTAssertTrue(localRuntime.contains("MCP YAML editing"))
        let yaml = try HermesFixtureLoader.string(named: "runtime-fixtures", extension: "yaml", subdirectory: "LocalRuntime")
        XCTAssertTrue(yaml.contains("disabled_server"))
    }
}
