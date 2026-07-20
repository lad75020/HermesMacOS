//
//  HermesHindsightMemoryClient.swift
//  HermesMacOS
//

import Foundation

struct MemoryEntry: Identifiable, Equatable {
    let id: String
    let content: String
    let kind: String?
    let source: String?
    let profile: String?
    let createdAt: String?
    let updatedAt: String?
    let confidence: Double?
    let metadata: [String: String]

    var preview: String { Self.preview(content) }

    var metadataSummary: String {
        var parts: [String] = []
        if let kind, !kind.isEmpty { parts.append(kind) }
        if let source, !source.isEmpty { parts.append(source) }
        if let profile, !profile.isEmpty { parts.append(profile) }
        if let createdAt, !createdAt.isEmpty { parts.append(createdAt) }
        if let updatedAt, !updatedAt.isEmpty, updatedAt != createdAt { parts.append("updated \(updatedAt)") }
        if let confidence { parts.append(String(format: "%.0f%% match", confidence * 100)) }
        for key in ["bank", "document_id", "context"] {
            if let value = metadata[key], !value.isEmpty { parts.append(value) }
        }
        return parts.map(HermesSecretRedactor.redact).joined(separator: " · ")
    }

    static func preview(_ text: String, limit: Int = 260) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > limit else { return HermesSecretRedactor.redact(collapsed) }
        return HermesSecretRedactor.redact(String(collapsed.prefix(limit))) + "…"
    }
}

struct MemoryPage: Equatable {
    let entries: [MemoryEntry]
    let pageIndex: Int
    let pageSize: Int
    let totalCount: Int?
    let hasMore: Bool

    var isEmpty: Bool { entries.isEmpty }
}

struct MemoryListRequest: Equatable {
    let filterText: String
    let pageIndex: Int
    let pageSize: Int

    init(filterText: String, pageIndex: Int, pageSize: Int) {
        self.filterText = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.pageIndex = max(0, pageIndex)
        self.pageSize = min(max(pageSize, 1), MemoryTabState.maximumPageSize)
    }

    var offset: Int { pageIndex * pageSize }
}

struct MemoryDeletionResult: Equatable {
    let entryID: String
    let deleted: Bool
    let message: String?
}

enum MemoryTabState {
    static let defaultPageSize = 10
    static let maximumPageSize = 50

    static func boundedPageSize(_ value: Int) -> Int {
        min(max(value, 1), maximumPageSize)
    }
}

enum HermesHindsightMemoryClientError: LocalizedError, Equatable {
    case providerUnavailable(String)
    case timedOut
    case malformedOutput(String)
    case deletionFailed(String)

    var errorDescription: String? {
        switch self {
        case .providerUnavailable(let message): "Hindsight memory provider unavailable: \(message)"
        case .timedOut: "Hindsight memory helper timed out."
        case .malformedOutput(let message): "Hindsight memory helper returned malformed output: \(message)"
        case .deletionFailed(let message): "Could not delete memory: \(message)"
        }
    }

    static func sanitized(_ message: String) -> String {
        let redacted = HermesSecretRedactor.redact(HermesDebugLogBuffer.redact(message))
        let withoutTraceback = redacted
            .components(separatedBy: .newlines)
            .filter { !$0.contains("Traceback") && !$0.trimmingCharacters(in: .whitespaces).hasPrefix("File ") }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if withoutTraceback.isEmpty { return "unknown provider error" }
        return String(withoutTraceback.prefix(280))
    }
}

@MainActor
protocol HindsightMemoryProviding: AnyObject {
    func listMemories(request: MemoryListRequest) async throws -> MemoryPage
    func deleteMemory(id: String) async throws -> MemoryDeletionResult
}

@MainActor
final class HermesHindsightMemoryClient: HindsightMemoryProviding {
    private let hermesHome: String
    private let timeout: TimeInterval

    init(hermesHome: String = HermesRuntimePaths.defaultHermesHome, timeout: TimeInterval = 45) {
        self.hermesHome = hermesHome
        self.timeout = timeout
    }

    func listMemories(request: MemoryListRequest) async throws -> MemoryPage {
        let output = try await runHelper(arguments: ["list", hermesHome, request.filterText, String(request.pageIndex), String(request.pageSize)])
        return try Self.decodeListOutput(Data(output.utf8), request: request)
    }

    func deleteMemory(id: String) async throws -> MemoryDeletionResult {
        let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let output = try await runHelper(arguments: ["delete", hermesHome, trimmedID])
        return try Self.decodeDeleteOutput(Data(output.utf8), requestedID: trimmedID)
    }

    private func runHelper(arguments: [String]) async throws -> String {
        let script = Self.pythonHelperScript
        let timeout = timeout
        let environment = Self.normalizedPythonEnvironment(hermesHome: hermesHome)
        let executable = HermesRuntimePaths.defaultPythonExecutable
        let currentDirectory = HermesRuntimePaths.defaultHermesAgentRoot
        return try await Task.detached(priority: .userInitiated) {
            let result = try HermesProcessRunner.run(
                executable: executable,
                arguments: ["-c", script] + arguments,
                environment: environment,
                currentDirectory: currentDirectory,
                timeout: timeout
            )
            if result.timedOut { throw HermesHindsightMemoryClientError.timedOut }
            guard result.exitCode == 0 else {
                throw HermesHindsightMemoryClientError.providerUnavailable(HermesHindsightMemoryClientError.sanitized(result.output))
            }
            return result.output
        }.value
    }

    nonisolated static func decodeListOutput(_ data: Data, request: MemoryListRequest) throws -> MemoryPage {
        do {
            let response = try JSONDecoder().decode(HelperListResponse.self, from: data)
            guard response.success else {
                throw HermesHindsightMemoryClientError.providerUnavailable(HermesHindsightMemoryClientError.sanitized(response.error ?? response.message ?? "provider returned failure"))
            }
            let decodedRecords = response.results ?? response.entries ?? []
            let entries: [MemoryEntry] = decodedRecords.compactMap { decodedRecord in
                guard let record = decodedRecord.value else { return nil }
                return try? record.memoryEntry()
            }
            if !decodedRecords.isEmpty, entries.isEmpty {
                throw HermesHindsightMemoryClientError.malformedOutput("memory result contained no valid rows")
            }
            let total = response.totalCount ?? max(request.offset + entries.count, entries.count)
            let hasMore = response.hasMore ?? (request.offset + decodedRecords.count < total)
            return MemoryPage(entries: entries, pageIndex: request.pageIndex, pageSize: request.pageSize, totalCount: total, hasMore: hasMore)
        } catch let error as HermesHindsightMemoryClientError {
            throw error
        } catch {
            throw HermesHindsightMemoryClientError.malformedOutput(HermesHindsightMemoryClientError.sanitized(error.localizedDescription))
        }
    }

    nonisolated static func decodeDeleteOutput(_ data: Data, requestedID: String) throws -> MemoryDeletionResult {
        do {
            let response = try JSONDecoder().decode(HelperDeleteResponse.self, from: data)
            guard response.success else {
                throw HermesHindsightMemoryClientError.deletionFailed(HermesHindsightMemoryClientError.sanitized(response.error ?? response.message ?? "provider returned failure"))
            }
            let deleted = response.deleted ?? response.erased ?? []
            let skipped = response.skipped ?? []
            if deleted.contains(requestedID) || response.deletedID == requestedID || response.deleted == nil && response.erased == nil && skipped.isEmpty {
                return MemoryDeletionResult(entryID: requestedID, deleted: true, message: response.message.map { HermesHindsightMemoryClientError.sanitized($0) })
            }
            throw HermesHindsightMemoryClientError.deletionFailed(HermesHindsightMemoryClientError.sanitized(response.message ?? "provider skipped memory \(requestedID)"))
        } catch let error as HermesHindsightMemoryClientError {
            throw error
        } catch {
            throw HermesHindsightMemoryClientError.malformedOutput(HermesHindsightMemoryClientError.sanitized(error.localizedDescription))
        }
    }

    private static func normalizedPythonEnvironment(hermesHome: String) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["HERMES_HOME"] = hermesHome
        environment["TERM"] = environment["TERM"] ?? "xterm-256color"
        let agentRoot = HermesRuntimePaths.defaultHermesAgentRoot
        let existingPythonPath = environment["PYTHONPATH"] ?? ""
        environment["PYTHONPATH"] = existingPythonPath.isEmpty ? agentRoot : agentRoot + ":" + existingPythonPath
        environment["PATH"] = normalizedPATH(existing: environment["PATH"], hermesHome: hermesHome)
        return environment
    }

    private static func normalizedPATH(existing: String?, hermesHome: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let preferredPaths = [
            URL(fileURLWithPath: hermesHome).appendingPathComponent("node/bin").path,
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            URL(fileURLWithPath: home).appendingPathComponent(".local/bin").path
        ]
        let fallbackPaths = ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        let currentPaths = (existing ?? "")
            .split(separator: ":", omittingEmptySubsequences: true)
            .map(String.init)
        var seen = Set<String>()
        return (preferredPaths + currentPaths + fallbackPaths).filter { path in
            let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
            guard FileManager.default.fileExists(atPath: standardized), !seen.contains(standardized) else { return false }
            seen.insert(standardized)
            return true
        }.joined(separator: ":")
    }

    private static let pythonHelperScript = #"""
import asyncio
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

operation = sys.argv[1]
hermes_home = sys.argv[2]


def value(record, *names):
    for name in names:
        if isinstance(record, dict) and name in record:
            return record.get(name)
        candidate = getattr(record, name, None)
        if candidate is not None:
            return candidate
    return None


def as_list(candidate):
    if candidate is None:
        return []
    if isinstance(candidate, (list, tuple, set)):
        return [str(item) for item in candidate if str(item).strip()]
    return [str(candidate)] if str(candidate).strip() else []


def clean_record(item):
    memory_id = str(value(item, "id", "memory_id") or "").strip()
    text = str(value(item, "text", "content", "fact") or "").strip()
    fact_type = str(value(item, "type", "fact_type", "kind") or "").strip()
    if not memory_id or not text:
        return None
    return {
        "id": memory_id,
        "content": text,
        "kind": fact_type,
        "source": "Hindsight",
        "profile": value(item, "profile", "bank_id"),
        "confidence": value(item, "score", "confidence", "relevance"),
        "created_at": value(item, "created_at", "createdAt", "timestamp"),
        "updated_at": value(item, "updated_at", "updatedAt"),
        "metadata": {
            "document_id": str(value(item, "document_id") or ""),
            "context": str(value(item, "context") or ""),
            "tags": ", ".join(as_list(value(item, "tags"))),
        },
    }


async def invalidate_memories(client, provider, ids):
    base_url = str(getattr(client, "_base_url", "") or provider._probe_url() or provider._api_url or "").rstrip("/")
    if not base_url:
        raise RuntimeError("Hindsight API URL is unavailable")
    bank_id = str(getattr(provider, "_bank_id", "") or "").strip()
    if not bank_id:
        raise RuntimeError("Hindsight bank ID is unavailable")
    api_key = str(getattr(client, "_api_key", "") or getattr(provider, "_api_key", "") or "").strip()
    erased, skipped, errors = [], [], []
    for memory_id in ids:
        memory_id = str(memory_id or "").strip()
        if not memory_id:
            continue
        endpoint = f"{base_url}/v1/default/banks/{urllib.parse.quote(bank_id, safe='')}/memories/{urllib.parse.quote(memory_id, safe='')}"
        body = json.dumps({"state": "invalidated", "reason": "memory_tab"}).encode("utf-8")
        headers = {"Content-Type": "application/json"}
        if api_key:
            headers["Authorization"] = f"Bearer {api_key}"
        request = urllib.request.Request(endpoint, data=body, headers=headers, method="PATCH")
        try:
            await asyncio.to_thread(urllib.request.urlopen, request, timeout=30)
            erased.append(memory_id)
        except urllib.error.HTTPError as exc:
            skipped.append(memory_id)
            detail = exc.read().decode("utf-8", errors="replace")[:400]
            errors.append(f"{memory_id}: HTTP {exc.code} {detail}")
        except Exception as exc:
            skipped.append(memory_id)
            errors.append(f"{memory_id}: {exc}")
    return {"success": True, "erased": erased, "skipped": skipped, "message": "; ".join(errors)}


provider = None
try:
    from plugins.memory.hindsight import HindsightMemoryProvider

    provider = HindsightMemoryProvider()
    provider.initialize(
        "hermes-macos-memory-tab",
        hermes_home=hermes_home,
        platform="macos",
        agent_identity="default",
        agent_workspace="hermes",
        agent_context="primary",
    )
    if getattr(provider, "_mode", "") == "disabled":
        raise RuntimeError("Hindsight memory provider is disabled or unavailable for this Hermes profile")

    if operation == "list":
        filter_text = sys.argv[3]
        page_index = max(0, int(sys.argv[4]))
        page_size = min(max(1, int(sys.argv[5])), 50)
        query = filter_text.strip() or "memory"
        recall_kwargs = {
            "bank_id": provider._bank_id,
            "query": query,
            "budget": provider._budget,
            "max_tokens": 8192,
        }
        if provider._recall_tags:
            recall_kwargs["tags"] = provider._recall_tags
            recall_kwargs["tags_match"] = provider._recall_tags_match
        response = provider._run_hindsight_operation(lambda client: client.arecall(**recall_kwargs))
        all_records, seen = [], set()
        for item in response.results or []:
            record = clean_record(item)
            if record is None or record["id"] in seen:
                continue
            seen.add(record["id"])
            all_records.append(record)
        if filter_text.strip():
            needle = filter_text.strip().lower()
            all_records = [record for record in all_records if needle in record["content"].lower() or needle in json.dumps(record.get("metadata", {})).lower()]
        start = page_index * page_size
        end = start + page_size
        payload = {"success": True, "results": all_records[start:end], "total_count": len(all_records), "has_more": end < len(all_records)}
    elif operation == "delete":
        memory_id = sys.argv[3]
        payload = provider._run_hindsight_operation(lambda client: invalidate_memories(client, provider, [memory_id]))
    else:
        raise ValueError(f"Unsupported Hindsight memory tab operation: {operation}")
    print(json.dumps(payload, sort_keys=True))
except Exception as exc:
    print(json.dumps({"success": False, "error": str(exc), "results": [], "erased": [], "skipped": []}, sort_keys=True))
    sys.exit(1)
finally:
    if provider is not None:
        try:
            provider.shutdown()
        except Exception:
            pass
"""#
}

private struct HelperListResponse: Decodable {
    let success: Bool
    let error: String?
    let message: String?
    let results: [FailableDecodable<HelperMemoryRecord>]?
    let entries: [FailableDecodable<HelperMemoryRecord>]?
    let totalCount: Int?
    let hasMore: Bool?

    enum CodingKeys: String, CodingKey {
        case success, error, message, results, entries
        case totalCount = "total_count"
        case hasMore = "has_more"
    }
}

private struct FailableDecodable<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}

private struct HelperDeleteResponse: Decodable {
    let success: Bool
    let error: String?
    let message: String?
    let deletedID: String?
    let deleted: [String]?
    let erased: [String]?
    let skipped: [String]?

    enum CodingKeys: String, CodingKey {
        case success, error, message, deleted, erased, skipped
        case deletedID = "deleted_id"
    }
}

private struct HelperMemoryRecord: Decodable {
    let id: String
    let content: String
    let kind: String?
    let source: String?
    let profile: String?
    let createdAt: String?
    let updatedAt: String?
    let confidence: Double?
    let metadata: [String: String]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = try container.requiredString(for: ["id", "memory_id"])
        content = try container.requiredString(for: ["content", "text", "fact"])
        kind = container.optionalString(for: ["kind", "type", "fact_type", "memory_type"])
        source = container.optionalString(for: ["source", "provider"])
        profile = container.optionalString(for: ["profile", "bank", "bank_id"])
        createdAt = container.optionalString(for: ["created_at", "createdAt", "timestamp"])
        updatedAt = container.optionalString(for: ["updated_at", "updatedAt"])
        confidence = container.optionalDouble(for: ["confidence", "score", "relevance"])
        metadata = container.stringDictionary(for: "metadata")
    }

    func memoryEntry() throws -> MemoryEntry {
        let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty, !trimmedContent.isEmpty else {
            throw HermesHindsightMemoryClientError.malformedOutput("memory row is missing id or content")
        }
        return MemoryEntry(
            id: trimmedID,
            content: HermesSecretRedactor.redact(trimmedContent),
            kind: kind?.trimmingCharacters(in: .whitespacesAndNewlines),
            source: source?.trimmingCharacters(in: .whitespacesAndNewlines),
            profile: profile?.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: createdAt?.trimmingCharacters(in: .whitespacesAndNewlines),
            updatedAt: updatedAt?.trimmingCharacters(in: .whitespacesAndNewlines),
            confidence: confidence,
            metadata: metadata.mapValues(HermesSecretRedactor.redact)
        )
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }

    init(_ stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
}

private extension KeyedDecodingContainer where Key == DynamicCodingKey {
    func requiredString(for names: [String]) throws -> String {
        for name in names {
            let key = DynamicCodingKey(name)
            if let value = try? decode(String.self, forKey: key), !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return value }
            if let value = try? decode(Int.self, forKey: key) { return String(value) }
        }
        throw HermesHindsightMemoryClientError.malformedOutput("missing required field: \(names.joined(separator: "/"))")
    }

    func optionalString(for names: [String]) -> String? {
        for name in names {
            let key = DynamicCodingKey(name)
            if let value = try? decode(String.self, forKey: key), !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return value }
            if let value = try? decode(Int.self, forKey: key) { return String(value) }
            if let value = try? decode(Double.self, forKey: key) { return String(value) }
        }
        return nil
    }

    func optionalDouble(for names: [String]) -> Double? {
        for name in names {
            let key = DynamicCodingKey(name)
            if let value = try? decode(Double.self, forKey: key) { return value }
            if let value = try? decode(String.self, forKey: key), let double = Double(value) { return double }
        }
        return nil
    }

    func stringDictionary(for name: String) -> [String: String] {
        let key = DynamicCodingKey(name)
        if let values = try? decode([String: String].self, forKey: key) { return values }
        if let values = try? decode([String: Int].self, forKey: key) { return values.mapValues { String($0) } }
        if let values = try? decode([String: Double].self, forKey: key) { return values.mapValues { String($0) } }
        return [:]
    }
}
