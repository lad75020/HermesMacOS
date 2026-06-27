import XCTest

final class BuildCommandContractTests: XCTestCase {
    func testQuickstartDocumentsBuildAndTestCommands() throws {
        let quickstart = try HermesTestAssertions.readRepositoryFile("specs/013-hermesmacos-test-target/quickstart.md")
        XCTAssertTrue(quickstart.contains("xcodegen generate"))
        XCTAssertTrue(quickstart.contains("xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOS"))
        XCTAssertTrue(quickstart.contains("xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOSTest"))
        XCTAssertTrue(quickstart.contains("-derivedDataPath /tmp/HermesMacOSTestDerivedData"))
    }

    func testContractRequiresNoLiveServicesForDefaultTests() throws {
        let contract = try HermesTestAssertions.readRepositoryFile("specs/013-hermesmacos-test-target/contracts/test-coverage-contract.md")
        XCTAssertTrue(contract.contains("Default execution must not require live Hermes services"))
    }
}
