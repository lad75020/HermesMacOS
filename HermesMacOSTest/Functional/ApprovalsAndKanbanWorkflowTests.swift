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
}
