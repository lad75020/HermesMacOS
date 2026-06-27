import XCTest

final class HermesCoverageContractVerifierTests: XCTestCase {
    func testCoverageIdentifiersAreUniqueAndStable() {
        let identifiers = HermesMacOSTestCoverageMap.categories.map(\.identifier)
        XCTAssertEqual(Set(identifiers).count, identifiers.count)
        XCTAssertTrue(identifiers.contains("ask-hermes"))
        XCTAssertTrue(identifiers.contains("security"))
        XCTAssertTrue(identifiers.contains("live-api"))
    }

    func testCoverageVerifierPointsMaintainersToExpectedSuiteFamilies() {
        let suiteNames = Set(HermesMacOSTestCoverageMap.categories.flatMap(\.defaultCoverage))
        XCTAssertTrue(suiteNames.contains("AskHermesWorkflowTests"))
        XCTAssertTrue(suiteNames.contains("SecurityGuardrailTests"))
        XCTAssertTrue(suiteNames.contains("LiveSmokeSkipTests"))
    }
}
