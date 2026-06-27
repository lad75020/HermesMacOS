import XCTest
@testable import HermesMacOS

final class UtilitiesWorkflowTests: XCTestCase {
    func testUtilitiesRedactClipboardPromptAndResponseLikeValues() {
        HermesTestAssertions.assertRedacts("clipboard token " + String(repeating: "u", count: 30))
        HermesTestAssertions.assertRedacts("api_key=" + String(repeating: "v", count: 30))
    }

    func testUtilitiesCoverageIncludesRetentionDebugKnowledgeSpeechAndReachability() throws {
        let contract = try HermesTestAssertions.readRepositoryFile("specs/013-hermesmacos-test-target/contracts/test-coverage-contract.md")
        for phrase in ["clipboard retention", "prompt/response retention", "raw stream debug", "knowledge eraser", "speech-to-text", "reachability monitoring"] {
            XCTAssertTrue(contract.contains(phrase), "Utilities contract should mention \(phrase)")
        }
    }


    func testUtilitiesSubcategoryCoverageMatchesFR010() throws {
        let subcategories = HermesMacOSTestCoverageMap.subcategories(for: "utilities")
        XCTAssertTrue(subcategories.isSuperset(of: Set(["clipboard retention", "prompt retention", "response retention", "raw stream debug controls", "knowledge eraser scan", "knowledge eraser review", "knowledge eraser archive", "knowledge eraser erase", "speech-to-text selection", "recording stop", "recording cancel", "reachability monitoring"])))
        HermesTestAssertions.assertRedacts("clipboard api_key=\(HermesTestAssertions.fakeAPIKey) prompt response")
        let contract = try HermesTestAssertions.readRepositoryFile("specs/013-hermesmacos-test-target/contracts/test-coverage-contract.md")
        XCTAssertTrue(contract.contains("speech-to-text"))
    }
}
