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
}
