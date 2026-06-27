import XCTest

final class HermesMacOSTestCoverageMapTests: XCTestCase {
    func testCoverageMapAccountsForEveryContractCategory() throws {
        let contract = try HermesTestAssertions.readRepositoryFile("specs/013-hermesmacos-test-target/contracts/test-coverage-contract.md")
        for displayName in ["App shell", "Settings", "Ask Hermes", "Chat with Hermes", "TUI Gateway", "History and Sessions", "Approvals", "Kanban", "Dashboard embedding", "Configuration", "Local runtime", "Utilities", "Security", "Attachments", "Async lifecycle", "Localization/accessibility"] {
            XCTAssertTrue(contract.contains(displayName), "Contract should document \(displayName)")
            XCTAssertTrue(HermesMacOSTestCoverageMap.categories.contains { $0.displayName == displayName }, "Coverage map should include \(displayName)")
        }
    }

    func testEveryCoverageCategoryHasDefaultCoverageOrLiveSmokeSkip() {
        XCTAssertGreaterThanOrEqual(HermesMacOSTestCoverageMap.documentedSurfaceCount, 16)
        for category in HermesMacOSTestCoverageMap.categories {
            XCTAssertFalse(category.defaultCoverage.isEmpty, "\(category.identifier) must name at least one test or skip suite")
            if category.liveSmokeOnly {
                XCTAssertTrue(category.defaultCoverage.contains("LiveSmokeSkipTests"))
            }
        }
    }
}
