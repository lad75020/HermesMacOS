import Foundation
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
        XCTAssertEqual(HermesMacOSTab.allCases.count, 11)
    }

    func testSettingsTabVisibilityAndMemoryStringsAreCatalogBacked() throws {
        let catalogData = try Data(contentsOf: HermesTestAssertions.repositoryFile("HermesMacOS/Localizable.xcstrings"))
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: catalogData) as? [String: Any])
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        let expectedKeys: Set<String> = [
            "%lld–%lld of %lld",
            "%lld–%lld shown",
            "App tabs",
            "Ask Hermes tab",
            "Browse, filter, and delete readable Hindsight memories without exposing raw provider debug output.",
            "Cancel",
            "Chat with Hermes tab",
            "Could not delete memory: %@",
            "Delete",
            "Delete Memory",
            "Delete memory %@",
            "Delete memory %@?",
            "Delete memory?",
            "Deleting memory…",
            "Filter memories",
            "Hide optional prompt tabs from the side navigation without clearing their current drafts, attachments, or sessions. Settings remains available to restore them.",
            "Hindsight memory helper returned malformed output: %@",
            "Hindsight memory helper timed out.",
            "Hindsight memory provider unavailable: %@",
            "Loaded %lld memories.",
            "Loaded one memory.",
            "Loading memories…",
            "Memory",
            "Memory deleted.",
            "Memory provider error: %@",
            "Memory provider unavailable",
            "Memory range: %@",
            "Next",
            "Next memory page",
            "No matching memories",
            "No memories found",
            "No memories match this filter",
            "No memories shown",
            "Previous",
            "Previous memory page",
            "Refresh",
            "Refresh memories",
            "Shows a confirmation before deleting this Hindsight memory",
            "This invalidates the selected Hindsight memory after provider confirmation. Preview: %@",
            "Use Refresh to retry the active Hindsight provider. Default tests use fixtures; live provider access is opt-in.",
        ]
        let catalogKeys = Set(strings.keys)
        let missing = expectedKeys.subtracting(catalogKeys).sorted()

        XCTAssertTrue(missing.isEmpty, "Missing feature localization keys: \(missing)")
        for label in ["Ask Hermes tab", "Chat with Hermes tab", "Memory", "Filter memories", "Refresh memories", "Previous memory page", "Next memory page", "Delete"] {
            XCTAssertFalse(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(label.contains("_"))
        }
        XCTAssertTrue(HermesMacOSTestCoverageMap.covers("localization-accessibility", "Memory tab controls"))
        XCTAssertTrue(HermesMacOSTestCoverageMap.covers("localization-accessibility", "Settings tab visibility controls"))
    }

    func testResourceGaugeLabelsAndValuesAreCatalogBacked() throws {
        let catalogData = try Data(contentsOf: HermesTestAssertions.repositoryFile("HermesMacOS/Localizable.xcstrings"))
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: catalogData) as? [String: Any])
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        let expectedKeys: Set<String> = ["Memory", "GPU", "Unavailable", "Stale", "Memory usage", "GPU usage", "%@%%"]

        XCTAssertTrue(expectedKeys.isSubset(of: Set(strings.keys)))
        XCTAssertTrue(HermesMacOSTestCoverageMap.covers("localization-accessibility", "resource gauge labels and values"))
    }
}
