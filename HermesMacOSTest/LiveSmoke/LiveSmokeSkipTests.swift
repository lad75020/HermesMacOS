import XCTest

final class LiveSmokeSkipTests: XCTestCase {
    func testLiveSmokeChecksSkipByDefault() {
        XCTAssertFalse(HermesLiveSmokeConfiguration.hasAnyLiveTarget)
        XCTAssertEqual(HermesLiveSmokeConfiguration.skipReason, "Live smoke checks are opt-in; set HERMESMACOS_LIVE_* variables to enable.")
    }

    func testLiveSmokeDocumentationNamesSafetyRules() throws {
        let guide = try HermesTestAssertions.readRepositoryFile("HermesMacOSTest/LiveSmoke/LiveSmokeConfiguration.md")
        XCTAssertTrue(guide.contains("Skip with a clear reason"))
        XCTAssertTrue(guide.contains("Validate sensitive destinations"))
        XCTAssertTrue(guide.contains("Never print raw API keys"))
    }


    func testLiveSmokeSafetySubcategoryCoverageMatchesContract() {
        let subcategories = HermesMacOSTestCoverageMap.subcategories(for: "live-api")
        XCTAssertTrue(subcategories.isSuperset(of: Set(["explicit enablement", "clear skip reason", "destination validation", "destructive operation confirmation", "secret redaction"])))
        XCTAssertTrue(HermesMacOSTestCoverageMap.category("live-api").liveSmokeOnly)
        XCTAssertTrue(HermesMacOSTestCoverageMap.category("live-api").defaultCoverage.contains { $0.contains("LiveSmokeSkipTests") })
    }
}
