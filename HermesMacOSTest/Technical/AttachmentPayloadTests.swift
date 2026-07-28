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

    func testEverySupportedAttachmentCategoryReports128MiBSizeLimit() {
        let expectedLimit: Int64 = 128 * 1024 * 1024
        let representativeExtensions = [
            ("image", "png"),
            ("UTF-8 text", "txt"),
            ("document", "pdf"),
        ]

        for (category, fileExtension) in representativeExtensions {
            XCTAssertEqual(
                HermesPromptAttachment.sizeLimit(forExtension: fileExtension),
                expectedLimit,
                "\(category) attachments should allow one file up to exactly 128 MiB"
            )
        }
    }

    func testAttachmentAtExactly128MiBIsAcceptedUsingOriginalByteCount() throws {
        let maximumByteCount: Int64 = 128 * 1024 * 1024
        let fixtureData = Data([0x01])

        let attachment = try HermesPromptAttachment(
            filename: "boundary.pdf",
            contentType: .pdf,
            data: fixtureData,
            originalByteCount: maximumByteCount
        )

        XCTAssertEqual(attachment.originalByteCount, maximumByteCount)
        XCTAssertEqual(attachment.data, fixtureData)
        XCTAssertLessThan(Int64(attachment.data.count), maximumByteCount)
    }

    func testAttachmentOneByteOver128MiBIsRejectedWithVisibleLimit() {
        let maximumByteCount: Int64 = 128 * 1024 * 1024
        let expectedVisibleLimit = ByteCountFormatter.string(
            fromByteCount: maximumByteCount,
            countStyle: .binary
        )

        XCTAssertThrowsError(
            try HermesPromptAttachment(
                filename: "oversized.pdf",
                contentType: .pdf,
                data: Data([0x01]),
                originalByteCount: maximumByteCount + 1
            )
        ) { error in
            guard let attachmentError = error as? HermesAttachmentError else {
                return XCTFail("Expected HermesAttachmentError.fileTooLarge, got \(error)")
            }
            guard case .fileTooLarge(_, let reportedLimit) = attachmentError else {
                return XCTFail("Expected HermesAttachmentError.fileTooLarge, got \(attachmentError)")
            }

            XCTAssertEqual(reportedLimit, expectedVisibleLimit)
            XCTAssertTrue(attachmentError.localizedDescription.contains(expectedVisibleLimit))
        }
    }

    func testOversizedFileURLIsRejectedBeforeReadingContents() throws {
        let maximumByteCount: Int64 = 128 * 1024 * 1024
        let testDirectory = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent(".hermes-attachment-test-\(UUID().uuidString)", isDirectory: true)
        let oversizedURL = testDirectory.appendingPathComponent("oversized.pdf")
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: false)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: oversizedURL.path)
            try? FileManager.default.removeItem(at: testDirectory)
        }

        XCTAssertTrue(FileManager.default.createFile(atPath: oversizedURL.path, contents: Data()))
        let handle = try FileHandle(forWritingTo: oversizedURL)
        try handle.truncate(atOffset: UInt64(maximumByteCount + 1))
        try handle.close()
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: oversizedURL.path)

        XCTAssertThrowsError(try HermesPromptAttachment.load(from: oversizedURL)) { error in
            guard case HermesAttachmentError.fileTooLarge = error else {
                return XCTFail("Expected metadata preflight rejection, got \(error)")
            }
        }
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
