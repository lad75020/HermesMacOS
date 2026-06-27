import XCTest
@testable import HermesMacOS

final class LocalizationAndAccessibilityTests: XCTestCase {
    func testPrimaryNavigationLabelsAreNonEmptyAndHumanReadable() {
        for tab in HermesMacOSTab.allCases {
            XCTAssertFalse(tab.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(tab.systemImage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(tab.title.contains("_"), "Tab title should be a readable accessibility label")
        }
    }

    func testCriticalControlStringsAreRepresentedInCoverageContract() throws {
        let contract = try HermesTestAssertions.readRepositoryFile("specs/013-hermesmacos-test-target/contracts/test-coverage-contract.md")
        XCTAssertTrue(contract.contains("primary navigation labels"))
        XCTAssertTrue(contract.contains("critical control strings"))
    }


    func testLocalizationAccessibilityCoverageMapTracksCriticalLabels() {
        let subcategories = HermesMacOSTestCoverageMap.subcategories(for: "localization-accessibility")
        XCTAssertTrue(subcategories.isSuperset(of: Set(["primary navigation labels", "critical control strings", "supported app surfaces"])))
        XCTAssertEqual(HermesMacOSTab.allCases.count, 10)
    }
}
