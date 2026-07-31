import Foundation
@testable import HermesMacOS

enum HindsightMemoryFixtures {
    static func entries(count: Int = 13) -> [MemoryEntry] {
        (1...count).map { index in
            MemoryEntry(
                id: "mem-\(index)",
                content: "Memory fixture row \(index) about Hermes settings and Hindsight browsing.",
                kind: index.isMultiple(of: 2) ? "experience" : "world",
                source: "fixture",
                profile: "default",
                createdAt: "2026-06-28T10:00:00Z",
                updatedAt: nil,
                confidence: 0.8,
                metadata: ["document_id": "doc-\(index)"]
            )
        }
    }

    static let providerError = "Traceback api_key=[REDACTED] failed with token [REDACTED]"

    static func listJSON() -> Data {
        Data(#"{"success":true,"items":[{"id":"h-1","text":"A retained Hindsight memory","fact_type":"experience","context":"test","mentioned_at":"2026-06-28T10:00:00Z","proof_count":2,"tags":["fixture"]},{"id":"h-2","text":"Second memory with optional metadata","fact_type":"world"}],"total":2,"limit":10,"offset":0,"bank_id":"bank-default","profile":"default"}"#.utf8)
    }

    static func malformedListJSON() -> Data {
        Data(#"{"success":true,"items":[{"id":"missing-content"}],"total":1,"limit":10,"offset":0}"#.utf8)
    }

    static func deleteJSON(id: String = "h-1") -> Data {
        Data("{\"success\":true,\"erased\":[\"\(id)\"],\"skipped\":[]}".utf8)
    }

    static func failedDeleteJSON() -> Data {
        Data(#"{"success":false,"error":"Authorization: Bearer [REDACTED] api_key=[REDACTED] Traceback"}"#.utf8)
    }
}
