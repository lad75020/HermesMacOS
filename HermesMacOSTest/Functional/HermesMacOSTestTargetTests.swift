import XCTest
@testable import HermesMacOS

final class HermesMacOSTestTargetTests: XCTestCase {
    func testProjectDeclaresHermesMacOSTestTargetAndSwift6() throws {
        let project = try HermesTestAssertions.readRepositoryFile("project.yml")
        XCTAssertTrue(project.contains("HermesMacOSTest:"))
        XCTAssertTrue(project.contains("type: bundle.unit-test"))
        XCTAssertTrue(project.contains("SWIFT_VERSION: 6.0"))
        XCTAssertTrue(project.contains("MACOSX_DEPLOYMENT_TARGET: 26.0"))
    }

    func testTargetSmokeCanImportAppModuleAndReadTabs() {
        XCTAssertEqual(HermesMacOSTab.allCases.first, .ask)
        XCTAssertTrue(HermesMacOSTab.allCases.map(\.title).contains("Utilities"))
    }

    func testTasksManifestReferencesTargetSmokeFile() throws {
        try HermesTestAssertions.assertTaskManifestContains("HermesMacOSTest/Functional/HermesMacOSTestTargetTests.swift")
    }
}
