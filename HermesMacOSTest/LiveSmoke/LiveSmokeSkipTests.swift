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
}
