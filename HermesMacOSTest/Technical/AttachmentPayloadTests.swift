import UniformTypeIdentifiers
import XCTest
@testable import HermesMacOS

final class AttachmentPayloadTests: XCTestCase {
    func testTextAttachmentInfersMimeAndInlinesBoundedText() throws {
        let attachment = try HermesPromptAttachment(filename: "notes.txt", contentType: .plainText, data: Data("hello".utf8))
        XCTAssertEqual(attachment.mimeType, "text/plain")
        XCTAssertTrue(attachment.isUTF8Text)
        XCTAssertTrue(attachment.textAttachmentBlock.contains("hello"))
    }

    func testBinaryDocumentIsNotInlinedAsPromptText() throws {
        let attachment = try HermesPromptAttachment(filename: "paper.pdf", contentType: .pdf, data: Data([0, 1, 2, 3]))
        XCTAssertFalse(attachment.isUTF8Text)
        XCTAssertTrue(attachment.textAttachmentBlock.contains("Binary document bytes are not inlined"))
    }

    func testAttachmentSizeLimitsAreExtensionSpecific() {
        XCTAssertEqual(HermesPromptAttachment.sizeLimit(forExtension: "png"), HermesPromptAttachment.maxImageBytes)
        XCTAssertEqual(HermesPromptAttachment.sizeLimit(forExtension: "txt"), HermesPromptAttachment.maxTextBytes)
        XCTAssertEqual(HermesPromptAttachment.sizeLimit(forExtension: "pdf"), HermesPromptAttachment.maxDocumentBytes)
    }

    func testUnsupportedExtensionFailsVisibly() {
        XCTAssertThrowsError(try HermesPromptAttachment(filename: "secret.exe", contentType: nil, data: Data()))
    }


    func testAttachmentCoverageMapIncludesCountAndVisibleErrorContracts() {
        let subcategories = HermesMacOSTestCoverageMap.subcategories(for: "attachments")
        XCTAssertTrue(subcategories.isSuperset(of: Set(["MIME inference", "size limits", "count limits", "payload encoding", "unsupported visible errors", "oversized visible errors"])))
        XCTAssertTrue(HermesMacOSTestCoverageMap.category("attachments").defaultCoverage.contains { $0.contains("AttachmentPayloadTests") })
    }
}
