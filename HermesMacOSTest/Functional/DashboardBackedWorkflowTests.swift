import XCTest

final class DashboardBackedWorkflowTests: XCTestCase {
    func testDashboardFixturesCoverTokenRefreshAndCoreRoutes() throws {
        let fixture = try HermesFixtureLoader.string(named: "dashboard-fixtures", extension: "json", subdirectory: "Dashboard")
        for token in ["window.__HERMES_SESSION_TOKEN__", "skills", "schedules", "plugins", "toolsets", "mcp_servers", "history", "sessions", "raw_config"] {
            XCTAssertTrue(fixture.contains(token), "Dashboard fixture should cover \(token)")
        }
    }

    func testDashboardTokenFixtureDoesNotUseRealSecret() throws {
        let fixture = try HermesFixtureLoader.string(named: "dashboard-fixtures", extension: "json", subdirectory: "Dashboard")
        XCTAssertTrue(fixture.contains("dashboard-token-fixture"))
        XCTAssertFalse(fixture.contains("dashboard-token-test-only"))
    }


    func testDashboardSubcategoryCoverageMatchesFR008() throws {
        let history = HermesMacOSTestCoverageMap.subcategories(for: "history-sessions")
        XCTAssertTrue(history.isSuperset(of: Set(["dashboard search", "paged session list", "per-session messages", "resume into Ask", "resume into Chat", "resume into TUI", "empty state", "error state", "token-refresh state", "Hindsight session retention"])))
        let dashboard = HermesMacOSTestCoverageMap.subcategories(for: "dashboard")
        XCTAssertTrue(dashboard.isSuperset(of: Set(["URL construction", "dashboard availability", "session-token dependency", "visible errors"])))
        let configuration = HermesMacOSTestCoverageMap.subcategories(for: "configuration")
        XCTAssertTrue(configuration.isSuperset(of: Set(["profiles", "models", "skills", "schedules", "plugins", "toolsets", "MCP servers", "raw config", "token refresh", "mutation failure handling"])))
        let fixture = try HermesFixtureLoader.string(named: "dashboard-fixtures", extension: "json", subdirectory: "Dashboard")
        XCTAssertTrue(fixture.contains("window.__HERMES_SESSION_TOKEN__"))
        XCTAssertTrue(fixture.contains("dashboard-token-fixture"))
    }

    func testSessionsTabStoresTranscriptsInHindsightProvider() throws {
        let source = try HermesTestAssertions.readRepositoryFile("HermesMacOS/HermesHistoryView.swift")
        XCTAssertTrue(source.contains("Store in Hindsight"))
        XCTAssertTrue(source.contains("from plugins.memory.hindsight import HindsightMemoryProvider"))
        XCTAssertTrue(source.contains("client.aretain_batch"))
        XCTAssertTrue(source.contains("source:hermes_macos_sessions_tab"))
        XCTAssertFalse(source.contains("Store in local_memory"))
    }
}
