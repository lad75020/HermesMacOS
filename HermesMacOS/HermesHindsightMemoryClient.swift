//
//  HermesHindsightMemoryClient.swift
//  HermesMacOS
//

import Foundation

private let hindsightMemoryJSONMarker = "HERMES_MEMORY_JSON:"

struct HindsightMemoryContext: Equatable, Hashable, Sendable {
    let hermesHome: String
    let profile: String
    let providerBank: String?

    static func active(
        rootHermesHome: String,
        profile: String,
        providerBank: String? = nil
    ) -> HindsightMemoryContext {
        let safeProfile = normalizedProfile(profile)
        let expandedHome = NSString(string: rootHermesHome).expandingTildeInPath
        var rootURL = URL(fileURLWithPath: expandedHome, isDirectory: true).standardizedFileURL

        // A caller may already be scoped to `<root>/profiles/<profile>`. Always
        // derive from the Hermes root so changing profiles cannot nest homes.
        if rootURL.deletingLastPathComponent().lastPathComponent == "profiles" {
            rootURL.deleteLastPathComponent()
            rootURL.deleteLastPathComponent()
        }

        let effectiveHome: URL
        if safeProfile == "default" {
            effectiveHome = rootURL
        } else {
            effectiveHome = rootURL
                .appendingPathComponent("profiles", isDirectory: true)
                .appendingPathComponent(safeProfile, isDirectory: true)
        }

        let trimmedBank = providerBank?.trimmingCharacters(in: .whitespacesAndNewlines)
        return HindsightMemoryContext(
            hermesHome: effectiveHome.standardizedFileURL.path,
            profile: safeProfile,
            providerBank: trimmedBank.flatMap { $0.isEmpty ? nil : $0 }
        )
    }

    private static func normalizedProfile(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != ".", trimmed != ".." else { return "default" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard trimmed.rangeOfCharacter(from: allowed.inverted) == nil else { return "default" }
        return trimmed
    }
}

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
    let offset: Int
    let totalCount: Int?
    let hasMore: Bool
    let providerBank: String?
    let profile: String?

    init(
        entries: [MemoryEntry],
        pageIndex: Int,
        pageSize: Int,
        offset: Int? = nil,
        totalCount: Int?,
        hasMore: Bool,
        providerBank: String? = nil,
        profile: String? = nil
    ) {
        self.entries = entries
        self.pageIndex = max(0, pageIndex)
        self.pageSize = MemoryTabState.boundedPageSize(pageSize)
        self.offset = max(0, offset ?? pageIndex * pageSize)
        self.totalCount = totalCount
        self.hasMore = hasMore
        self.providerBank = providerBank
        self.profile = profile
    }

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
    func listMemories(request: MemoryListRequest, context: HindsightMemoryContext) async throws -> MemoryPage
    func deleteMemory(id: String, context: HindsightMemoryContext) async throws -> MemoryDeletionResult
}

struct HermesHindsightMemoryHelperInvocation: Equatable, Sendable {
    let arguments: [String]
    let context: HindsightMemoryContext
    let timeout: TimeInterval
}

@MainActor
final class HermesHindsightMemoryClient: HindsightMemoryProviding {
    typealias HelperExecutor = @Sendable (HermesHindsightMemoryHelperInvocation) async throws -> String

    private let timeout: TimeInterval
    private let helperExecutor: HelperExecutor

    init(
        timeout: TimeInterval = 45,
        helperExecutor: HelperExecutor? = nil
    ) {
        self.timeout = max(1, timeout)
        self.helperExecutor = helperExecutor ?? { invocation in
            try await Self.executeHelper(invocation)
        }
    }

    func listMemories(request: MemoryListRequest, context: HindsightMemoryContext) async throws -> MemoryPage {
        let output = try await runHelper(
            arguments: Self.listHelperArguments(request: request, context: context),
            context: context
        )
        return try Self.decodeListOutput(Data(output.utf8), request: request)
    }

    func deleteMemory(id: String, context: HindsightMemoryContext) async throws -> MemoryDeletionResult {
        let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else {
            throw HermesHindsightMemoryClientError.deletionFailed("memory ID is empty")
        }
        let output = try await runHelper(
            arguments: ["delete", context.hermesHome, context.profile, context.providerBank ?? "", trimmedID],
            context: context
        )
        return try Self.decodeDeleteOutput(Data(output.utf8), requestedID: trimmedID)
    }

    nonisolated static func listHelperArguments(
        request: MemoryListRequest,
        context: HindsightMemoryContext
    ) -> [String] {
        [
            "list",
            context.hermesHome,
            context.profile,
            context.providerBank ?? "",
            request.filterText,
            String(request.pageSize),
            String(request.offset),
        ]
    }

    nonisolated static var pythonHelperContract: String { pythonHelperScript }

    private func runHelper(arguments: [String], context: HindsightMemoryContext) async throws -> String {
        try Task.checkCancellation()
        return try await helperExecutor(
            HermesHindsightMemoryHelperInvocation(arguments: arguments, context: context, timeout: timeout)
        )
    }

    private nonisolated static func executeHelper(_ invocation: HermesHindsightMemoryHelperInvocation) async throws -> String {
        let worker = Task.detached(priority: .userInitiated) {
            let result = try HermesProcessRunner.runCancellable(
                executable: HermesRuntimePaths.defaultPythonExecutable,
                arguments: ["-c", pythonHelperScript] + invocation.arguments,
                environment: normalizedPythonEnvironment(hermesHome: invocation.context.hermesHome),
                currentDirectory: HermesRuntimePaths.defaultHermesAgentRoot,
                timeout: invocation.timeout
            )
            if result.timedOut { throw HermesHindsightMemoryClientError.timedOut }
            guard result.exitCode == 0 else {
                throw HermesHindsightMemoryClientError.providerUnavailable(
                    HermesHindsightMemoryClientError.sanitized(result.output)
                )
            }
            return result.output
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    nonisolated static func decodeListOutput(_ data: Data, request: MemoryListRequest) throws -> MemoryPage {
        do {
            let payload = framedJSONPayload(from: data)
            let response = try JSONDecoder().decode(HelperListResponse.self, from: normalizedListOutput(payload))
            guard response.success else {
                throw HermesHindsightMemoryClientError.providerUnavailable(HermesHindsightMemoryClientError.sanitized(response.error ?? response.message ?? "provider returned failure"))
            }
            guard let decodedRecords = response.items,
                  let total = response.total,
                  let limit = response.limit,
                  let offset = response.offset,
                  total >= 0,
                  (1...MemoryTabState.maximumPageSize).contains(limit),
                  offset >= 0
            else {
                throw HermesHindsightMemoryClientError.malformedOutput(
                    "inventory response is missing exact total/limit/offset metadata"
                )
            }
            let entries: [MemoryEntry] = decodedRecords.compactMap { decodedRecord in
                guard let record = decodedRecord.value else { return nil }
                return try? record.memoryEntry(defaultBank: response.bankID)
            }
            if !decodedRecords.isEmpty, entries.isEmpty {
                throw HermesHindsightMemoryClientError.malformedOutput("memory result contained no valid rows")
            }
            let hasMore = offset + decodedRecords.count < total
            return MemoryPage(
                entries: entries,
                pageIndex: offset / limit,
                pageSize: limit,
                offset: offset,
                totalCount: total,
                hasMore: hasMore,
                providerBank: response.bankID,
                profile: response.profile
            )
        } catch let error as HermesHindsightMemoryClientError {
            throw error
        } catch {
            throw HermesHindsightMemoryClientError.malformedOutput(HermesHindsightMemoryClientError.sanitized(error.localizedDescription))
        }
    }

    private nonisolated static func framedJSONPayload(from data: Data) -> Data {
        guard let output = String(data: data, encoding: .utf8),
              let framedLine = output.split(whereSeparator: { $0.isNewline }).last(where: {
                  $0.hasPrefix(hindsightMemoryJSONMarker)
              })
        else {
            return data
        }
        return Data(framedLine.dropFirst(hindsightMemoryJSONMarker.count).utf8)
    }

    private nonisolated static func normalizedListOutput(_ data: Data) -> Data {
        let bytes = Array(data)
        let null = Array("null".utf8)
        let nonFiniteNumbers = [
            Array("-Infinity".utf8),
            Array("Infinity".utf8),
            Array("NaN".utf8),
        ]
        var normalized: [UInt8] = []
        normalized.reserveCapacity(bytes.count)
        var index = 0
        var isInsideString = false
        var isEscaped = false

        while index < bytes.count {
            let byte = bytes[index]
            if isInsideString {
                normalized.append(byte)
                if isEscaped {
                    isEscaped = false
                } else if byte == 0x5C {
                    isEscaped = true
                } else if byte == 0x22 {
                    isInsideString = false
                }
                index += 1
                continue
            }

            if byte == 0x22 {
                isInsideString = true
                normalized.append(byte)
                index += 1
                continue
            }

            if isNonFiniteMemoryFieldValue(at: index, in: bytes),
               let token = nonFiniteNumbers.first(where: { token in
                guard index + token.count <= bytes.count,
                      bytes[index..<(index + token.count)].elementsEqual(token),
                      index == 0 || isJSONValueBoundary(bytes[index - 1]),
                      index + token.count == bytes.count || isJSONValueBoundary(bytes[index + token.count])
                else { return false }
                return true
            }) {
                normalized.append(contentsOf: null)
                index += token.count
                continue
            }

            normalized.append(byte)
            index += 1
        }

        return Data(normalized)
    }

    private nonisolated static func isNonFiniteMemoryFieldValue(at index: Int, in bytes: [UInt8]) -> Bool {
        var cursor = index
        while cursor > 0, isJSONWhitespace(bytes[cursor - 1]) { cursor -= 1 }
        guard cursor > 0, bytes[cursor - 1] == 0x3A else { return false }
        cursor -= 1
        while cursor > 0, isJSONWhitespace(bytes[cursor - 1]) { cursor -= 1 }

        return ["confidence", "score", "relevance"].contains { name in
            let key = Array("\"\(name)\"".utf8)
            guard cursor >= key.count else { return false }
            return bytes[(cursor - key.count)..<cursor].elementsEqual(key)
        }
    }

    private nonisolated static func isJSONWhitespace(_ byte: UInt8) -> Bool {
        switch byte {
        case 0x09, 0x0A, 0x0D, 0x20:
            return true
        default:
            return false
        }
    }

    private nonisolated static func isJSONValueBoundary(_ byte: UInt8) -> Bool {
        switch byte {
        case 0x09, 0x0A, 0x0D, 0x20, 0x2C, 0x3A, 0x5B, 0x5D, 0x7B, 0x7D:
            return true
        default:
            return false
        }
    }

    nonisolated static func decodeDeleteOutput(_ data: Data, requestedID: String) throws -> MemoryDeletionResult {
        do {
            let response = try JSONDecoder().decode(HelperDeleteResponse.self, from: framedJSONPayload(from: data))
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

    private nonisolated static func normalizedPythonEnvironment(hermesHome: String) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["HERMES_HOME"] = hermesHome
        environment["TERM"] = environment["TERM"] ?? "xterm-256color"
        let agentRoot = HermesRuntimePaths.defaultHermesAgentRoot
        let existingPythonPath = environment["PYTHONPATH"] ?? ""
        environment["PYTHONPATH"] = existingPythonPath.isEmpty ? agentRoot : agentRoot + ":" + existingPythonPath
        environment["PATH"] = normalizedPATH(existing: environment["PATH"], hermesHome: hermesHome)
        return environment
    }

    private nonisolated static func normalizedPATH(existing: String?, hermesHome: String) -> String {
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

    private nonisolated static let pythonHelperScript = #"""
import asyncio
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

JSON_OUTPUT_MARKER = "\#(hindsightMemoryJSONMarker)"

operation = sys.argv[1]
hermes_home = sys.argv[2]
profile = sys.argv[3]
expected_bank = sys.argv[4].strip()


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


def response_dict(response):
    if isinstance(response, dict):
        return response
    if callable(getattr(response, "to_dict", None)):
        return response.to_dict()
    if callable(getattr(response, "model_dump", None)):
        return response.model_dump(by_alias=True, exclude_none=True)
    raise RuntimeError("Hindsight inventory returned an unsupported response shape")


def clean_record(item, active_profile, bank_id):
    memory_id = str(value(item, "id", "memory_id") or "").strip()
    text = str(value(item, "text", "content", "fact") or "").strip()
    fact_type = str(value(item, "fact_type", "type", "kind") or "").strip()
    if not memory_id or not text:
        raise RuntimeError("Hindsight inventory returned a row without id or text")
    confidence = value(item, "score", "confidence", "relevance")
    if not isinstance(confidence, (int, float)):
        confidence = None
    return {
        "id": memory_id,
        "content": text,
        "kind": fact_type,
        "source": "Hindsight",
        "profile": active_profile,
        "confidence": confidence,
        "created_at": str(value(item, "date", "mentioned_at", "created_at") or ""),
        "updated_at": str(value(item, "consolidated_at", "updated_at") or ""),
        "metadata": {
            "bank": bank_id,
            "context": str(value(item, "context") or ""),
            "chunk_id": str(value(item, "chunk_id") or ""),
            "proof_count": str(value(item, "proof_count") or ""),
            "tags": ", ".join(as_list(value(item, "tags"))),
            "entities": ", ".join(as_list(value(item, "entities"))),
            "occurred_start": str(value(item, "occurred_start") or ""),
            "occurred_end": str(value(item, "occurred_end") or ""),
        },
    }


async def list_memory_inventory(client, bank_id, search_query, limit, offset):
    def perform_list():
        memories = getattr(client, "memories", None)
        if memories is not None and callable(getattr(memories, "list", None)):
            return client.memories.list(
                bank_id=bank_id,
                search_query=search_query,
                limit=limit,
                offset=offset,
            )
        if callable(getattr(client, "list_memories", None)):
            return client.list_memories(
                bank_id=bank_id,
                search_query=search_query,
                limit=limit,
                offset=offset,
            )
        raise RuntimeError("Installed Hindsight client does not expose the memory inventory API")

    return await asyncio.to_thread(perform_list)


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
        agent_identity=profile,
        agent_workspace="hermes",
        agent_context="primary",
    )
    if getattr(provider, "_mode", "") == "disabled":
        raise RuntimeError("Hindsight memory provider is disabled or unavailable for this Hermes profile")

    bank_id = str(getattr(provider, "_bank_id", "") or "").strip()
    if not bank_id:
        raise RuntimeError("Hindsight bank ID is unavailable")
    if expected_bank and expected_bank != bank_id:
        raise RuntimeError("Active Hindsight bank does not match the requested profile context")

    if operation == "list":
        search_query = sys.argv[5].strip() or None
        limit = min(max(1, int(sys.argv[6])), 50)
        offset = max(0, int(sys.argv[7]))
        response = provider._run_hindsight_operation(
            lambda client: list_memory_inventory(client, bank_id, search_query, limit, offset)
        )
        inventory = response_dict(response)
        items = inventory.get("items")
        total = inventory.get("total")
        exact_limit = inventory.get("limit")
        exact_offset = inventory.get("offset")
        if not isinstance(items, list) or not isinstance(total, int) or not isinstance(exact_limit, int) or not isinstance(exact_offset, int):
            raise RuntimeError("Hindsight inventory omitted exact items/total/limit/offset metadata")
        payload = {
            "success": True,
            "items": [clean_record(item, profile, bank_id) for item in items],
            "total": total,
            "limit": exact_limit,
            "offset": exact_offset,
            "bank_id": bank_id,
            "profile": profile,
        }
    elif operation == "delete":
        memory_id = sys.argv[5]
        payload = provider._run_hindsight_operation(lambda client: invalidate_memories(client, provider, [memory_id]))
    else:
        raise ValueError(f"Unsupported Hindsight memory tab operation: {operation}")
    print(JSON_OUTPUT_MARKER + json.dumps(payload, sort_keys=True))
except Exception as exc:
    print(JSON_OUTPUT_MARKER + json.dumps({
        "success": False,
        "error": str(exc),
        "items": [],
        "total": 0,
        "limit": 0,
        "offset": 0,
        "erased": [],
        "skipped": [],
    }, sort_keys=True))
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
    let items: [FailableDecodable<HelperMemoryRecord>]?
    let total: Int?
    let limit: Int?
    let offset: Int?
    let bankID: String?
    let profile: String?

    enum CodingKeys: String, CodingKey {
        case success, error, message, items, total, limit, offset, profile
        case bankID = "bank_id"
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
        var decodedMetadata = container.stringDictionary(for: "metadata")
        for key in ["context", "proof_count", "chunk_id", "document_id", "occurred_start", "occurred_end"] {
            if let value = container.optionalString(for: [key]), !value.isEmpty {
                decodedMetadata[key] = value
            }
        }
        for key in ["tags", "entities"] {
            let codingKey = DynamicCodingKey(key)
            if let values = try? container.decode([String].self, forKey: codingKey), !values.isEmpty {
                decodedMetadata[key] = values.joined(separator: ", ")
            }
        }
        metadata = decodedMetadata
    }

    func memoryEntry(defaultBank: String? = nil) throws -> MemoryEntry {
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
            profile: (profile ?? defaultBank)?.trimmingCharacters(in: .whitespacesAndNewlines),
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
