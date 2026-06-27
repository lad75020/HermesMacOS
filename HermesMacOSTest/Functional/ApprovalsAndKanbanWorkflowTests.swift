import XCTest

final class ApprovalsAndKanbanWorkflowTests: XCTestCase {
    func testAPIFixturesCoverApprovals() throws {
        let fixture = try HermesFixtureLoader.string(named: "api-fixtures", extension: "json", subdirectory: "HermesAPI")
        XCTAssertTrue(fixture.contains("approval-test"))
        XCTAssertTrue(fixture.contains("pending"))
    }

    func testCoverageMapAssignsApprovalsAndKanbanToWorkflowTests() {
        let approvals = HermesMacOSTestCoverageMap.categories.first { $0.identifier == "approvals" }
        let kanban = HermesMacOSTestCoverageMap.categories.first { $0.identifier == "kanban" }
        XCTAssertEqual(approvals?.defaultCoverage, ["ApprovalsAndKanbanWorkflowTests"])
        XCTAssertEqual(kanban?.defaultCoverage, ["ApprovalsAndKanbanWorkflowTests"])
    }


    func testApprovalsAndKanbanSubcategoryCoverageMatchesFR008() throws {
        let approvals = HermesMacOSTestCoverageMap.subcategories(for: "approvals")
        XCTAssertTrue(approvals.isSuperset(of: Set(["pending approvals", "approve mutation", "deny mutation", "auto-refresh", "unavailable API state"])))
        let kanban = HermesMacOSTestCoverageMap.subcategories(for: "kanban")
        XCTAssertTrue(kanban.isSuperset(of: Set(["board load", "task mutations", "comment mutations", "action mutations", "live updates", "plugin unavailable state"])))
        let fixture = try HermesFixtureLoader.string(named: "api-fixtures", extension: "json", subdirectory: "HermesAPI")
        XCTAssertTrue(fixture.contains("approval-test"))
        XCTAssertTrue(HermesMacOSTestCoverageMap.category("kanban").defaultCoverage.contains { $0.contains("ApprovalsAndKanbanWorkflowTests") })
    }
}
