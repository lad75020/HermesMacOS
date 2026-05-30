//
//  HermesKanbanView.swift
//  HermesMacOS
//

import Foundation
import SwiftUI

enum HermesKanbanColumnStatus: String, CaseIterable, Identifiable, Codable {
    case triage
    case todo
    case scheduled
    case ready
    case running
    case blocked
    case review
    case done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .triage: "Triage"
        case .todo: "Todo"
        case .scheduled: "Scheduled"
        case .ready: "Ready"
        case .running: "Running"
        case .blocked: "Blocked"
        case .review: "Review"
        case .done: "Done"
        }
    }

    var systemImage: String {
        switch self {
        case .triage: "tray.and.arrow.down"
        case .todo: "list.bullet.rectangle"
        case .scheduled: "calendar.badge.clock"
        case .ready: "bolt.fill"
        case .running: "play.circle.fill"
        case .blocked: "hand.raised.fill"
        case .review: "checkmark.seal"
        case .done: "checkmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .triage: .purple
        case .todo: .blue
        case .scheduled: .indigo
        case .ready: .hermesOrange
        case .running: .green
        case .blocked: .hermesDestructive
        case .review: .cyan
        case .done: .mint
        }
    }

    static let visibleOrder: [HermesKanbanColumnStatus] = [.triage, .todo, .scheduled, .ready, .running, .blocked, .review, .done]
    static let movableStatuses: [HermesKanbanColumnStatus] = [.triage, .todo, .scheduled, .ready, .blocked, .review, .done]
}

struct HermesKanbanTask: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let body: String?
    let assignee: String?
    let status: String
    let priority: Int
    let createdBy: String?
    let createdAt: Int?
    let startedAt: Int?
    let completedAt: Int?
    let workspaceKind: String?
    let workspacePath: String?
    let tenant: String?
    let result: String?
    let latestSummary: String?
    let commentCount: Int?
    let currentRunID: Int?
    let lastFailureError: String?
    let consecutiveFailures: Int?
    let skills: [String]?

    enum CodingKeys: String, CodingKey {
        case id, title, body, assignee, status, priority, tenant, result, skills
        case createdBy = "created_by"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case workspaceKind = "workspace_kind"
        case workspacePath = "workspace_path"
        case latestSummary = "latest_summary"
        case commentCount = "comment_count"
        case currentRunID = "current_run_id"
        case lastFailureError = "last_failure_error"
        case consecutiveFailures = "consecutive_failures"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = (try? container.decode(String.self, forKey: .title)) ?? id
        body = try? container.decodeIfPresent(String.self, forKey: .body)
        assignee = try? container.decodeIfPresent(String.self, forKey: .assignee)
        status = (try? container.decode(String.self, forKey: .status)) ?? "todo"
        priority = (try? container.decode(Int.self, forKey: .priority)) ?? 0
        createdBy = try? container.decodeIfPresent(String.self, forKey: .createdBy)
        createdAt = try? container.decodeIfPresent(Int.self, forKey: .createdAt)
        startedAt = try? container.decodeIfPresent(Int.self, forKey: .startedAt)
        completedAt = try? container.decodeIfPresent(Int.self, forKey: .completedAt)
        workspaceKind = try? container.decodeIfPresent(String.self, forKey: .workspaceKind)
        workspacePath = try? container.decodeIfPresent(String.self, forKey: .workspacePath)
        tenant = try? container.decodeIfPresent(String.self, forKey: .tenant)
        result = try? container.decodeIfPresent(String.self, forKey: .result)
        latestSummary = try? container.decodeIfPresent(String.self, forKey: .latestSummary)
        commentCount = try? container.decodeIfPresent(Int.self, forKey: .commentCount)
        currentRunID = try? container.decodeIfPresent(Int.self, forKey: .currentRunID)
        lastFailureError = try? container.decodeIfPresent(String.self, forKey: .lastFailureError)
        consecutiveFailures = try? container.decodeIfPresent(Int.self, forKey: .consecutiveFailures)
        skills = try? container.decodeIfPresent([String].self, forKey: .skills)
    }

    init(
        id: String,
        title: String,
        body: String?,
        assignee: String?,
        status: String,
        priority: Int,
        createdBy: String?,
        createdAt: Int?,
        startedAt: Int?,
        completedAt: Int?,
        workspaceKind: String?,
        workspacePath: String?,
        tenant: String?,
        result: String?,
        latestSummary: String?,
        commentCount: Int?,
        currentRunID: Int?,
        lastFailureError: String?,
        consecutiveFailures: Int?,
        skills: [String]?
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.assignee = assignee
        self.status = status
        self.priority = priority
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.workspaceKind = workspaceKind
        self.workspacePath = workspacePath
        self.tenant = tenant
        self.result = result
        self.latestSummary = latestSummary
        self.commentCount = commentCount
        self.currentRunID = currentRunID
        self.lastFailureError = lastFailureError
        self.consecutiveFailures = consecutiveFailures
        self.skills = skills
    }

    var statusEnum: HermesKanbanColumnStatus { HermesKanbanColumnStatus(rawValue: status) ?? .todo }
    var assigneeLabel: String { assignee?.isEmpty == false ? assignee! : "Unassigned" }
    var bodyPreview: String {
        let text = (body?.isEmpty == false ? body : latestSummary) ?? "No description"
        return String(text.prefix(180))
    }
    var createdAtLabel: String { Self.relativeTimeLabel(createdAt) }

    static func relativeTimeLabel(_ timestamp: Int?) -> String {
        guard let timestamp else { return "—" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        return date.formatted(.relative(presentation: .named))
    }
}

struct HermesKanbanColumn: Codable, Identifiable, Equatable {
    let name: String
    let tasks: [HermesKanbanTask]
    var id: String { name }
    var status: HermesKanbanColumnStatus { HermesKanbanColumnStatus(rawValue: name) ?? .todo }
}

struct HermesKanbanProfile: Codable, Identifiable, Equatable {
    let name: String
    let isDefault: Bool?
    let model: String?
    let provider: String?
    let description: String?
    let skillCount: Int?

    enum CodingKeys: String, CodingKey {
        case name, model, provider, description
        case isDefault = "is_default"
        case skillCount = "skill_count"
    }

    var id: String { name }
    var title: String { name == "default" ? "Default" : name }
}

struct HermesKanbanBoardInfo: Codable, Identifiable, Equatable {
    let slug: String
    let name: String?
    let description: String?
    let icon: String?
    let isCurrent: Bool?
    let total: Int?

    enum CodingKeys: String, CodingKey {
        case slug, name, description, icon, total
        case isCurrent = "is_current"
    }

    var id: String { slug }
    var displayName: String { name?.isEmpty == false ? name! : slug }
}

struct HermesKanbanComment: Codable, Identifiable, Equatable {
    let id: Int
    let taskID: String
    let author: String
    let body: String
    let createdAt: Int?

    enum CodingKeys: String, CodingKey {
        case id, author, body
        case taskID = "task_id"
        case createdAt = "created_at"
    }

    var createdAtLabel: String { HermesKanbanTask.relativeTimeLabel(createdAt) }
}

struct HermesKanbanEvent: Codable, Identifiable, Equatable {
    let id: Int
    let taskID: String
    let kind: String
    let payload: JSONValue?
    let createdAt: Int?
    let runID: Int?

    enum CodingKeys: String, CodingKey {
        case id, kind, payload
        case taskID = "task_id"
        case createdAt = "created_at"
        case runID = "run_id"
    }

    var createdAtLabel: String { HermesKanbanTask.relativeTimeLabel(createdAt) }
}

struct HermesKanbanRun: Codable, Identifiable, Equatable {
    let id: Int
    let taskID: String
    let profile: String?
    let status: String?
    let outcome: String?
    let summary: String?
    let error: String?
    let startedAt: Int?
    let endedAt: Int?

    enum CodingKeys: String, CodingKey {
        case id, profile, status, outcome, summary, error
        case taskID = "task_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
    }

    var statusLabel: String {
        if let outcome, !outcome.isEmpty { return outcome }
        if let status, !status.isEmpty { return status }
        return "run"
    }
}

struct HermesKanbanTaskDetails: Codable, Equatable {
    let task: HermesKanbanTask
    let comments: [HermesKanbanComment]
    let events: [HermesKanbanEvent]
    let runs: [HermesKanbanRun]
}

enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Double.self) { self = .number(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        if let value = try? container.decode([String: JSONValue].self) { self = .object(value); return }
        if let value = try? container.decode([JSONValue].self) { self = .array(value); return }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var compactDescription: String {
        switch self {
        case .string(let value): value
        case .number(let value): String(value)
        case .bool(let value): value ? "true" : "false"
        case .null: ""
        case .array(let value): value.map(\.compactDescription).joined(separator: ", ")
        case .object(let value):
            value.keys.sorted().map { key in "\(key): \(value[key]?.compactDescription ?? "")" }.joined(separator: ", ")
        }
    }
}

private struct HermesKanbanBoardResponse: Codable {
    let columns: [HermesKanbanColumn]
    let tenants: [String]?
    let assignees: [String]?
    let latestEventID: Int?
    let now: Int?

    enum CodingKeys: String, CodingKey {
        case columns, tenants, assignees, now
        case latestEventID = "latest_event_id"
    }
}

private struct HermesKanbanBoardsResponse: Codable {
    let boards: [HermesKanbanBoardInfo]
    let current: String?
}

private struct HermesKanbanProfilesResponse: Codable {
    let profiles: [HermesKanbanProfile]
}

private struct HermesKanbanTaskMutationResponse: Codable {
    let task: HermesKanbanTask?
    let warning: String?
}

private struct HermesKanbanLogResponse: Codable {
    let taskID: String
    let exists: Bool
    let sizeBytes: Int?
    let content: String
    let truncated: Bool?

    enum CodingKeys: String, CodingKey {
        case exists, content, truncated
        case taskID = "task_id"
        case sizeBytes = "size_bytes"
    }
}

private struct HermesKanbanActionOutcome: Codable {
    let ok: Bool?
    let taskID: String?
    let reason: String?
    let fanout: Bool?
    let childIDs: [String]?
    let newTitle: String?

    enum CodingKeys: String, CodingKey {
        case ok, reason, fanout
        case taskID = "task_id"
        case childIDs = "child_ids"
        case newTitle = "new_title"
    }

    var summary: String {
        if ok == true {
            if let childIDs, !childIDs.isEmpty { return "Created child cards: \(childIDs.joined(separator: ", "))" }
            if let newTitle, !newTitle.isEmpty { return "Updated card: \(newTitle)" }
            return "Action completed."
        }
        return reason?.isEmpty == false ? reason! : "Action did not complete."
    }
}

private struct HermesKanbanGenericResponse: Codable {
    let values: [String: JSONValue]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        values = (try? container.decode([String: JSONValue].self)) ?? [:]
    }
}

private struct HermesKanbanCreateTaskBody: Codable {
    let title: String
    let body: String?
    let assignee: String?
    let priority: Int
    let workspaceKind: String
    let triage: Bool

    enum CodingKeys: String, CodingKey {
        case title, body, assignee, priority, triage
        case workspaceKind = "workspace_kind"
    }
}

private struct HermesKanbanUpdateTaskBody: Codable {
    let status: String?
    let assignee: String?
    let priority: Int?
    let title: String?
    let body: String?
    let blockReason: String?

    enum CodingKeys: String, CodingKey {
        case status, assignee, priority, title, body
        case blockReason = "block_reason"
    }
}

private struct HermesKanbanCommentBody: Codable {
    let body: String
    let author: String?
}

private struct HermesKanbanAuthorBody: Codable {
    let author: String?
}

private enum HermesKanbanError: LocalizedError {
    case invalidDashboardURL
    case missingDashboardSessionToken
    case invalidWebSocketURL
    case invalidResponse
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidDashboardURL:
            return "The Hermes dashboard URL is invalid."
        case .missingDashboardSessionToken:
            return "The dashboard session token was not found in the dashboard HTML."
        case .invalidWebSocketURL:
            return "The Kanban live-update URL is invalid."
        case .invalidResponse:
            return "The Hermes dashboard returned an invalid response."
        case .httpStatus(let status, let detail):
            return detail.isEmpty ? "Kanban request failed with HTTP \(status)." : detail
        }
    }
}

@MainActor
@Observable
final class HermesKanbanStore {
    var columns: [HermesKanbanColumn] = HermesKanbanColumnStatus.visibleOrder.map { HermesKanbanColumn(name: $0.rawValue, tasks: []) }
    var boards: [HermesKanbanBoardInfo] = []
    var profiles: [HermesKanbanProfile] = []
    var assignees: [String] = []
    var selectedBoardSlug = ""
    var latestEventID: Int?
    var isLoading = false
    var isMutating = false
    var liveStatus = "Idle"
    var lastErrorMessage = ""
    var lastActionMessage = ""
    var selectedTaskID: String?
    var selectedTaskDetails: HermesKanbanTaskDetails?
    var selectedTaskLog = ""
    var selectedTaskLogTruncated = false
    var commentDraft = ""

    private var webSocketTask: URLSessionWebSocketTask?

    var allTasks: [HermesKanbanTask] { columns.flatMap(\.tasks) }
    var selectedBoardTitle: String {
        if let board = boards.first(where: { $0.slug == selectedBoardSlug }) { return board.displayName }
        return selectedBoardSlug.isEmpty ? "Current board" : selectedBoardSlug
    }

    func refresh(dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        Task { await loadAll(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, updateDetails: true) }
    }

    func selectBoard(_ slug: String, dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        selectedBoardSlug = slug
        selectedTaskID = nil
        selectedTaskDetails = nil
        selectedTaskLog = ""
        refresh(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
    }

    func selectTask(_ task: HermesKanbanTask, dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        selectedTaskID = task.id
        selectedTaskDetails = nil
        selectedTaskLog = ""
        Task { await loadTaskDetails(taskID: task.id, dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) }
    }

    func closeTaskDetails() {
        selectedTaskID = nil
        selectedTaskDetails = nil
        selectedTaskLog = ""
        commentDraft = ""
    }

    func createTask(title: String, body: String, assignee: String, priority: Int, triage: Bool, dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        Task {
            await mutate(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) { baseURL, token in
                let payload = HermesKanbanCreateTaskBody(
                    title: trimmedTitle,
                    body: body.nilIfBlank,
                    assignee: assignee.nilIfBlank,
                    priority: priority,
                    workspaceKind: "scratch",
                    triage: triage
                )
                let response: HermesKanbanTaskMutationResponse = try await self.request(
                    baseURL: baseURL,
                    path: ["api", "plugins", "kanban", "tasks"],
                    queryItems: self.boardQueryItems,
                    method: "POST",
                    token: token,
                    apiSettings: apiSettings,
                    body: payload,
                    timeout: 30
                )
                self.lastActionMessage = response.warning?.isEmpty == false ? response.warning! : "Created \(response.task?.title ?? trimmedTitle)."
            }
        }
    }

    func updateTask(_ taskID: String, title: String, body: String, assignee: String, priority: Int, status: String, dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        Task {
            await mutate(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) { baseURL, token in
                let payload = HermesKanbanUpdateTaskBody(
                    status: status,
                    assignee: assignee,
                    priority: priority,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    body: body,
                    blockReason: status == "blocked" ? "Blocked from HermesMacOS" : nil
                )
                let response: HermesKanbanTaskMutationResponse = try await self.request(
                    baseURL: baseURL,
                    path: ["api", "plugins", "kanban", "tasks", taskID],
                    queryItems: self.boardQueryItems,
                    method: "PATCH",
                    token: token,
                    apiSettings: apiSettings,
                    body: payload,
                    timeout: 30
                )
                self.lastActionMessage = "Saved \(response.task?.title ?? taskID)."
            }
        }
    }

    func moveTask(_ task: HermesKanbanTask, to status: HermesKanbanColumnStatus, dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        guard task.status != status.rawValue else { return }
        Task {
            await mutate(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) { baseURL, token in
                let payload = HermesKanbanUpdateTaskBody(status: status.rawValue, assignee: nil, priority: nil, title: nil, body: nil, blockReason: status == .blocked ? "Blocked from HermesMacOS" : nil)
                let _: HermesKanbanTaskMutationResponse = try await self.request(
                    baseURL: baseURL,
                    path: ["api", "plugins", "kanban", "tasks", task.id],
                    queryItems: self.boardQueryItems,
                    method: "PATCH",
                    token: token,
                    apiSettings: apiSettings,
                    body: payload,
                    timeout: 30
                )
                self.lastActionMessage = "Moved \(task.title) to \(status.title)."
            }
        }
    }

    func deleteTask(_ task: HermesKanbanTask, dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        Task {
            await mutate(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) { baseURL, token in
                let _: HermesKanbanGenericResponse = try await self.request(
                    baseURL: baseURL,
                    path: ["api", "plugins", "kanban", "tasks", task.id],
                    queryItems: self.boardQueryItems,
                    method: "DELETE",
                    token: token,
                    apiSettings: apiSettings,
                    body: Optional<Int>.none,
                    timeout: 30
                )
                if self.selectedTaskID == task.id { self.closeTaskDetails() }
                self.lastActionMessage = "Deleted \(task.title)."
            }
        }
    }

    func addComment(taskID: String, dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        let body = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        Task {
            await mutate(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, reloadBoard: false) { baseURL, token in
                let payload = HermesKanbanCommentBody(body: body, author: "HermesMacOS")
                let _: HermesKanbanGenericResponse = try await self.request(
                    baseURL: baseURL,
                    path: ["api", "plugins", "kanban", "tasks", taskID, "comments"],
                    queryItems: self.boardQueryItems,
                    method: "POST",
                    token: token,
                    apiSettings: apiSettings,
                    body: payload,
                    timeout: 30
                )
                self.commentDraft = ""
                self.lastActionMessage = "Comment added."
                await self.loadTaskDetails(taskID: taskID, dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
            }
        }
    }

    func specifyTask(_ taskID: String, dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        Task { await runLongTaskAction(pathTail: ["specify"], taskID: taskID, dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, startedMessage: "Specifying card…") }
    }

    func decomposeTask(_ taskID: String, dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        Task { await runLongTaskAction(pathTail: ["decompose"], taskID: taskID, dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, startedMessage: "Decomposing card…") }
    }

    func dispatchNow(dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        Task {
            await mutate(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) { baseURL, token in
                let _: HermesKanbanGenericResponse = try await self.request(
                    baseURL: baseURL,
                    path: ["api", "plugins", "kanban", "dispatch"],
                    queryItems: self.boardQueryItems,
                    method: "POST",
                    token: token,
                    apiSettings: apiSettings,
                    body: Optional<Int>.none,
                    timeout: 60
                )
                self.lastActionMessage = "Dispatcher nudged. Ready cards will be claimed if a worker is available."
            }
        }
    }

    func runLiveUpdates(dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
        await loadAll(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, updateDetails: false)
        while !Task.isCancelled {
            do {
                let baseURL = try await HermesDashboardClient.shared.resolvedBaseURL(dashboardBaseURL: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
                let token = try await HermesDashboardClient.shared.sessionToken(baseURL: baseURL, apiSettings: apiSettings)
                let url = try eventsURL(baseURL: baseURL, token: token)
                let session = HermesNetworkSessionFactory.session(for: apiSettings)
                let webSocketTask = session.webSocketTask(with: url)
                self.webSocketTask = webSocketTask
                webSocketTask.resume()
                liveStatus = "Live updates connected"
                try await receiveEvents(webSocketTask, dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
            } catch {
                if Task.isCancelled { break }
                liveStatus = "Live updates unavailable; polling"
                lastErrorMessage = error.localizedDescription
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await loadAll(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, updateDetails: false)
            }
        }
    }

    func stopLiveUpdates() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    private func runLongTaskAction(pathTail: [String], taskID: String, dashboardBaseURL: String, apiSettings: HermesAPISettings, startedMessage: String) async {
        await mutate(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, startedMessage: startedMessage) { baseURL, token in
            let outcome: HermesKanbanActionOutcome = try await self.request(
                baseURL: baseURL,
                path: ["api", "plugins", "kanban", "tasks", taskID] + pathTail,
                queryItems: self.boardQueryItems,
                method: "POST",
                token: token,
                apiSettings: apiSettings,
                body: HermesKanbanAuthorBody(author: "HermesMacOS"),
                timeout: 300
            )
            self.lastActionMessage = outcome.summary
            await self.loadTaskDetails(taskID: taskID, dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
        }
    }

    private func mutate(
        dashboardBaseURL: String,
        apiSettings: HermesAPISettings,
        reloadBoard: Bool = true,
        startedMessage: String = "Working…",
        action: @escaping (URL, String) async throws -> Void
    ) async {
        isMutating = true
        lastErrorMessage = ""
        lastActionMessage = startedMessage
        defer { isMutating = false }
        do {
            let baseURL = try await HermesDashboardClient.shared.resolvedBaseURL(dashboardBaseURL: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let token = try await HermesDashboardClient.shared.sessionToken(baseURL: baseURL, apiSettings: apiSettings)
            try await action(baseURL, token)
            if reloadBoard { await loadAll(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, updateDetails: true) }
        } catch HermesKanbanError.httpStatus(401, _) {
            await retryWithFreshToken(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, reloadBoard: reloadBoard, action: action)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func retryWithFreshToken(
        dashboardBaseURL: String,
        apiSettings: HermesAPISettings,
        reloadBoard: Bool,
        action: @escaping (URL, String) async throws -> Void
    ) async {
        do {
            let baseURL = try await HermesDashboardClient.shared.resolvedBaseURL(dashboardBaseURL: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let token = try await HermesDashboardClient.shared.sessionToken(baseURL: baseURL, apiSettings: apiSettings, refresh: true)
            try await action(baseURL, token)
            if reloadBoard { await loadAll(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, updateDetails: true) }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func loadAll(dashboardBaseURL: String, apiSettings: HermesAPISettings, updateDetails: Bool) async {
        isLoading = true
        lastErrorMessage = ""
        defer { isLoading = false }
        do {
            let baseURL = try await HermesDashboardClient.shared.resolvedBaseURL(dashboardBaseURL: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let token = try await HermesDashboardClient.shared.sessionToken(baseURL: baseURL, apiSettings: apiSettings)
            async let boardResponse: HermesKanbanBoardResponse = request(
                baseURL: baseURL,
                path: ["api", "plugins", "kanban", "board"],
                queryItems: boardQueryItems,
                method: "GET",
                token: token,
                apiSettings: apiSettings,
                body: Optional<Int>.none,
                timeout: 30
            )
            async let profilesResponse: HermesKanbanProfilesResponse = request(
                baseURL: baseURL,
                path: ["api", "plugins", "kanban", "profiles"],
                queryItems: [],
                method: "GET",
                token: token,
                apiSettings: apiSettings,
                body: Optional<Int>.none,
                timeout: 30
            )
            async let boardsResponse: HermesKanbanBoardsResponse = request(
                baseURL: baseURL,
                path: ["api", "plugins", "kanban", "boards"],
                queryItems: [],
                method: "GET",
                token: token,
                apiSettings: apiSettings,
                body: Optional<Int>.none,
                timeout: 30
            )
            let loadedBoard = try await boardResponse
            let loadedProfiles = try await profilesResponse
            let loadedBoards = try await boardsResponse
            columns = normalizedColumns(from: loadedBoard.columns)
            assignees = (loadedBoard.assignees ?? []).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            latestEventID = loadedBoard.latestEventID
            profiles = loadedProfiles.profiles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            boards = loadedBoards.boards.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            if selectedBoardSlug.isEmpty {
                selectedBoardSlug = loadedBoards.current ?? boards.first?.slug ?? "default"
            }
            liveStatus = "Updated \(Date().formatted(date: .omitted, time: .shortened))"
            if updateDetails, let selectedTaskID { await loadTaskDetails(taskID: selectedTaskID, dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) }
        } catch HermesKanbanError.httpStatus(401, _) {
            do {
                let baseURL = try await HermesDashboardClient.shared.resolvedBaseURL(dashboardBaseURL: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
                _ = try await HermesDashboardClient.shared.sessionToken(baseURL: baseURL, apiSettings: apiSettings, refresh: true)
                await loadAll(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, updateDetails: updateDetails)
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            liveStatus = "Refresh failed"
        }
    }

    private func loadTaskDetails(taskID: String, dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
        do {
            let baseURL = try await HermesDashboardClient.shared.resolvedBaseURL(dashboardBaseURL: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let token = try await HermesDashboardClient.shared.sessionToken(baseURL: baseURL, apiSettings: apiSettings)
            let details: HermesKanbanTaskDetails = try await request(
                baseURL: baseURL,
                path: ["api", "plugins", "kanban", "tasks", taskID],
                queryItems: boardQueryItems,
                method: "GET",
                token: token,
                apiSettings: apiSettings,
                body: Optional<Int>.none,
                timeout: 30
            )
            selectedTaskDetails = details
            await loadTaskLog(taskID: taskID, baseURL: baseURL, token: token, apiSettings: apiSettings)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func loadTaskLog(taskID: String, baseURL: URL, token: String, apiSettings: HermesAPISettings) async {
        do {
            let log: HermesKanbanLogResponse = try await request(
                baseURL: baseURL,
                path: ["api", "plugins", "kanban", "tasks", taskID, "log"],
                queryItems: boardQueryItems + [URLQueryItem(name: "tail", value: "12000")],
                method: "GET",
                token: token,
                apiSettings: apiSettings,
                body: Optional<Int>.none,
                timeout: 30
            )
            selectedTaskLog = log.content
            selectedTaskLogTruncated = log.truncated ?? false
        } catch HermesKanbanError.httpStatus(404, _) {
            selectedTaskLog = "No worker log yet."
            selectedTaskLogTruncated = false
        } catch {
            selectedTaskLog = error.localizedDescription
            selectedTaskLogTruncated = false
        }
    }

    private func receiveEvents(_ webSocketTask: URLSessionWebSocketTask, dashboardBaseURL: String, apiSettings: HermesAPISettings) async throws {
        while !Task.isCancelled {
            _ = try await webSocketTask.receive()
            await loadAll(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, updateDetails: true)
        }
    }

    private var boardQueryItems: [URLQueryItem] {
        selectedBoardSlug.isEmpty ? [] : [URLQueryItem(name: "board", value: selectedBoardSlug)]
    }

    private func normalizedColumns(from fetched: [HermesKanbanColumn]) -> [HermesKanbanColumn] {
        let byName = Dictionary(uniqueKeysWithValues: fetched.map { ($0.name, $0) })
        return HermesKanbanColumnStatus.visibleOrder.map { status in byName[status.rawValue] ?? HermesKanbanColumn(name: status.rawValue, tasks: []) }
    }

    private func request<Response: Decodable, Body: Encodable>(
        baseURL: URL,
        path: [String],
        queryItems: [URLQueryItem],
        method: String,
        token: String,
        apiSettings: HermesAPISettings,
        body: Body?,
        timeout: TimeInterval
    ) async throws -> Response {
        var request = URLRequest(url: try pluginURL(baseURL: baseURL, path: path, queryItems: queryItems))
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func pluginURL(baseURL: URL, path: [String], queryItems: [URLQueryItem]) throws -> URL {
        var url = baseURL
        for component in path { url.appendPathComponent(component) }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw HermesKanbanError.invalidDashboardURL }
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let finalURL = components.url else { throw HermesKanbanError.invalidDashboardURL }
        return finalURL
    }

    private func eventsURL(baseURL: URL, token: String) throws -> URL {
        var url = baseURL
        for component in ["api", "plugins", "kanban", "events"] { url.appendPathComponent(component) }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw HermesKanbanError.invalidWebSocketURL }
        switch components.scheme?.lowercased() {
        case "http": components.scheme = "ws"
        case "https": components.scheme = "wss"
        default: throw HermesKanbanError.invalidWebSocketURL
        }
        var query = boardQueryItems
        query.append(URLQueryItem(name: "token", value: token))
        components.queryItems = query
        guard let finalURL = components.url else { throw HermesKanbanError.invalidWebSocketURL }
        return finalURL
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else { throw HermesKanbanError.invalidResponse }
        guard 200 ..< 300 ~= httpResponse.statusCode else {
            let detail = Self.errorDetail(from: data)
            throw HermesKanbanError.httpStatus(httpResponse.statusCode, detail)
        }
    }

    private static func errorDetail(from data: Data) -> String {
        guard !data.isEmpty else { return "" }
        if let decoded = try? JSONDecoder().decode([String: JSONValue].self, from: data), let detail = decoded["detail"]?.compactDescription, !detail.isEmpty { return detail }
        return String(decoding: data.prefix(500), as: UTF8.self)
    }

}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct HermesKanbanView: View {
    let apiSettings: HermesAPISettings
    let dashboardURL: String
    @Bindable var store: HermesKanbanStore
    let connectedHostName: String
    let connectedWindowID: UUID

    @State private var newTitle = ""
    @State private var newBody = ""
    @State private var newAssignee = ""
    @State private var newPriority = 0
    @State private var createAsTriage = true
    @State private var isCreateExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            header
            mainContent
        }
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
        .task(id: dashboardURL + apiSettings.baseURL + apiSettings.allowSelfSignedCertificates.description + store.selectedBoardSlug) {
            await store.runLiveUpdates(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
        }
        .onDisappear { store.stopLiveUpdates() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label("Kanban", systemImage: "rectangle.3.group.bubble.left")
                .hermesWebsiteTitleFont(size: 22, weight: .bold)
            if store.isLoading { ProgressView().controlSize(.small) }
            Text(store.liveStatus)
                .hermesWebsiteLabelFont(size: 11, weight: .bold)
                .foregroundStyle(Color.hermesSecondaryText)
            Spacer()
            boardPicker
            Button { store.refresh(dashboardBaseURL: dashboardURL, apiSettings: apiSettings) } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .help("Refresh Kanban board")
            Button { store.dispatchNow(dashboardBaseURL: dashboardURL, apiSettings: apiSettings) } label: {
                Label("Dispatch", systemImage: "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isMutating)
            HermesConnectedHostLabel(hostName: connectedHostName, windowID: connectedWindowID)
        }
        .padding(18)
        .hermesGlassPanel(cornerRadius: 0)
    }

    private var boardPicker: some View {
        HStack(spacing: 6) {
            Text("Board")
                .font(.caption)
                .foregroundStyle(Color.hermesSecondaryText)
            Picker("Board", selection: Binding(
                get: { store.selectedBoardSlug },
                set: { store.selectBoard($0, dashboardBaseURL: dashboardURL, apiSettings: apiSettings) }
            )) {
                if store.boards.isEmpty {
                    Text(store.selectedBoardTitle).tag(store.selectedBoardSlug)
                } else {
                    ForEach(store.boards) { board in
                        Text(board.icon?.isEmpty == false ? "\(board.icon!) \(board.displayName)" : board.displayName).tag(board.slug)
                    }
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 180)
        }
    }

    private var mainContent: some View {
        HStack(spacing: 12) {
            VStack(spacing: 12) {
                createCardPanel
                statusPanel
                boardColumns
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let details = store.selectedTaskDetails {
                HermesKanbanTaskDrawer(
                    details: details,
                    logText: store.selectedTaskLog,
                    logTruncated: store.selectedTaskLogTruncated,
                    profiles: store.profiles,
                    commentDraft: $store.commentDraft,
                    isMutating: store.isMutating,
                    onClose: store.closeTaskDetails,
                    onSave: { title, body, assignee, priority, status in
                        store.updateTask(details.task.id, title: title, body: body, assignee: assignee, priority: priority, status: status, dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                    },
                    onSpecify: { store.specifyTask(details.task.id, dashboardBaseURL: dashboardURL, apiSettings: apiSettings) },
                    onDecompose: { store.decomposeTask(details.task.id, dashboardBaseURL: dashboardURL, apiSettings: apiSettings) },
                    onAddComment: { store.addComment(taskID: details.task.id, dashboardBaseURL: dashboardURL, apiSettings: apiSettings) },
                    onMove: { status in store.moveTask(details.task, to: status, dashboardBaseURL: dashboardURL, apiSettings: apiSettings) },
                    onDelete: { store.deleteTask(details.task, dashboardBaseURL: dashboardURL, apiSettings: apiSettings) }
                )
                .frame(width: 360)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if store.selectedTaskID != nil {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading card…")
                        .foregroundStyle(Color.hermesSecondaryText)
                }
                .frame(width: 360)
                .frame(maxHeight: .infinity)
                .hermesGlassPanel(tint: Color.hermesSurface.opacity(0.58), cornerRadius: 20)
                .padding(.trailing, 14)
                .padding(.vertical, 12)
            }
        }
        .padding(14)
    }

    private var createCardPanel: some View {
        DisclosureGroup(isExpanded: $isCreateExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Card title", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
                TextField("Describe the workflow or request", text: $newBody, axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.roundedBorder)
                HStack(spacing: 10) {
                    profilePicker(selection: $newAssignee, includeUnassigned: true)
                    Stepper("Priority \(newPriority)", value: $newPriority, in: -10...100)
                        .frame(width: 150)
                    Toggle("Triage first", isOn: $createAsTriage)
                        .toggleStyle(.switch)
                    Spacer()
                    Button { createCard() } label: {
                        Label("Create Card", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isMutating)
                }
            }
            .padding(.top, 10)
        } label: {
            Label("New card", systemImage: "plus.rectangle.on.rectangle")
                .font(.headline)
        }
        .padding(14)
        .hermesGlassPanel(tint: Color.hermesSurface.opacity(0.58), cornerRadius: 18)
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !store.lastActionMessage.isEmpty {
                Text(store.lastActionMessage)
                    .font(.caption)
                    .foregroundStyle(Color.hermesSecondaryText)
            }
            if !store.lastErrorMessage.isEmpty {
                Text(store.lastErrorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.hermesDestructive)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var boardColumns: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(store.columns) { column in
                    HermesKanbanColumnView(
                        column: column,
                        selectedTaskID: store.selectedTaskID,
                        isMutating: store.isMutating,
                        onSelect: { task in store.selectTask(task, dashboardBaseURL: dashboardURL, apiSettings: apiSettings) },
                        onMove: { task, status in store.moveTask(task, to: status, dashboardBaseURL: dashboardURL, apiSettings: apiSettings) }
                    )
                    .frame(width: 270)
                }
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func profilePicker(selection: Binding<String>, includeUnassigned: Bool) -> some View {
        Picker("Assignee", selection: selection) {
            if includeUnassigned { Text("Unassigned").tag("") }
            ForEach(store.profiles) { profile in
                Text(profile.title).tag(profile.name)
            }
            ForEach(store.assignees.filter { assignee in !store.profiles.contains(where: { $0.name == assignee }) }, id: \.self) { assignee in
                Text(assignee).tag(assignee)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 180)
    }

    private func createCard() {
        store.createTask(
            title: newTitle,
            body: newBody,
            assignee: newAssignee,
            priority: newPriority,
            triage: createAsTriage,
            dashboardBaseURL: dashboardURL,
            apiSettings: apiSettings
        )
        newTitle = ""
        newBody = ""
    }
}

private struct HermesKanbanColumnView: View {
    let column: HermesKanbanColumn
    let selectedTaskID: String?
    let isMutating: Bool
    let onSelect: (HermesKanbanTask) -> Void
    let onMove: (HermesKanbanTask, HermesKanbanColumnStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: column.status.systemImage)
                    .foregroundStyle(column.status.tint)
                Text(column.status.title)
                    .font(.headline)
                Spacer()
                Text("\(column.tasks.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.hermesSecondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(column.status.tint.opacity(0.14)))
            }
            .padding(.horizontal, 4)

            ScrollView {
                LazyVStack(spacing: 10) {
                    if column.tasks.isEmpty {
                        Text("No cards")
                            .font(.caption)
                            .foregroundStyle(Color.hermesSecondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.04)))
                    } else {
                        ForEach(column.tasks) { task in
                            HermesKanbanTaskCard(
                                task: task,
                                isSelected: selectedTaskID == task.id,
                                isMutating: isMutating,
                                onSelect: { onSelect(task) },
                                onMove: { status in onMove(task, status) }
                            )
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .hermesGlassPanel(tint: Color.hermesSurface.opacity(0.54), cornerRadius: 20)
    }
}

private struct HermesKanbanTaskCard: View {
    let task: HermesKanbanTask
    let isSelected: Bool
    let isMutating: Bool
    let onSelect: () -> Void
    let onMove: (HermesKanbanColumnStatus) -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                        Text(task.id)
                            .font(.caption2.monospaced())
                            .foregroundStyle(Color.hermesSecondaryText)
                    }
                    Spacer(minLength: 4)
                    Menu {
                        ForEach(HermesKanbanColumnStatus.movableStatuses) { status in
                            Button(status.title) { onMove(status) }
                                .disabled(status.rawValue == task.status || isMutating)
                        }
                    } label: {
                        Image(systemName: "arrow.right.arrow.left")
                            .font(.caption)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.borderless)
                }

                Text(task.bodyPreview)
                    .font(.caption)
                    .foregroundStyle(Color.hermesSecondaryText)
                    .lineLimit(4)

                HStack(spacing: 6) {
                    Label(task.assigneeLabel, systemImage: "person.crop.circle")
                    if let commentCount = task.commentCount, commentCount > 0 {
                        Label("\(commentCount)", systemImage: "text.bubble")
                    }
                    if task.priority != 0 {
                        Label("\(task.priority)", systemImage: "flag")
                    }
                }
                .font(.caption2)
                .foregroundStyle(Color.hermesSecondaryText)

                if let latestSummary = task.latestSummary, !latestSummary.isEmpty {
                    Text(latestSummary)
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.hermesActionBlue.opacity(0.18) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Color.hermesActionBlue.opacity(0.78) : Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Kanban card \(task.title)")
    }
}

private struct HermesKanbanTaskDrawer: View {
    let details: HermesKanbanTaskDetails
    let logText: String
    let logTruncated: Bool
    let profiles: [HermesKanbanProfile]
    @Binding var commentDraft: String
    let isMutating: Bool
    let onClose: () -> Void
    let onSave: (String, String, String, Int, String) -> Void
    let onSpecify: () -> Void
    let onDecompose: () -> Void
    let onAddComment: () -> Void
    let onMove: (HermesKanbanColumnStatus) -> Void
    let onDelete: () -> Void

    @State private var title = ""
    @State private var bodyDraft = ""
    @State private var assignee = ""
    @State private var priority = 0
    @State private var status = "todo"

    var task: HermesKanbanTask { details.task }

    var body: some View {
        VStack(spacing: 0) {
            drawerHeader
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    editSection
                    orchestrationSection
                    summarySection
                    commentsSection
                    runsSection
                    eventsSection
                    logSection
                }
                .padding(14)
            }
        }
        .hermesGlassPanel(tint: Color.hermesSurface.opacity(0.62), cornerRadius: 20)
        .padding(.trailing, 14)
        .padding(.vertical, 12)
        .onAppear(perform: resetDrafts)
        .onChange(of: task.id) { _, _ in resetDrafts() }
    }

    private var drawerHeader: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(task.id)
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.hermesSecondaryText)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close card details")
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
    }

    private var editSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Card", systemImage: "rectangle.and.pencil.and.ellipsis")
                .font(.headline)
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
            TextField("Body", text: $bodyDraft, axis: .vertical)
                .lineLimit(4...9)
                .textFieldStyle(.roundedBorder)
            Picker("Status", selection: $status) {
                ForEach(HermesKanbanColumnStatus.movableStatuses) { columnStatus in
                    Text(columnStatus.title).tag(columnStatus.rawValue)
                }
                if status == "running" { Text("Running").tag("running") }
            }
            .pickerStyle(.menu)
            Picker("Assignee", selection: $assignee) {
                Text("Unassigned").tag("")
                ForEach(profiles) { profile in Text(profile.title).tag(profile.name) }
                if !assignee.isEmpty && !profiles.contains(where: { $0.name == assignee }) { Text(assignee).tag(assignee) }
            }
            .pickerStyle(.menu)
            Stepper("Priority \(priority)", value: $priority, in: -10...100)
            HStack {
                Button { onSave(title, bodyDraft, assignee, priority, status) } label: {
                    Label("Save", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isMutating)
                Menu("Move") {
                    ForEach(HermesKanbanColumnStatus.movableStatuses) { target in
                        Button(target.title) { onMove(target) }
                            .disabled(target.rawValue == task.status || isMutating)
                    }
                }
                .disabled(isMutating)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(isMutating)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.05)))
    }

    private var orchestrationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Orchestrator", systemImage: "wand.and.stars")
                .font(.headline)
            Text("Specify triage cards, decompose them into child cards, then nudge the dispatcher from the toolbar to execute ready work.")
                .font(.caption)
                .foregroundStyle(Color.hermesSecondaryText)
            HStack {
                Button(action: onSpecify) {
                    Label("Specify", systemImage: "text.badge.checkmark")
                }
                .buttonStyle(.bordered)
                Button(action: onDecompose) {
                    Label("Decompose", systemImage: "arrow.triangle.branch")
                }
                .buttonStyle(.borderedProminent)
            }
            .disabled(isMutating)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.hermesOrange.opacity(0.08)))
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Summary", systemImage: "doc.text")
                .font(.headline)
            Text(task.latestSummary?.isEmpty == false ? task.latestSummary! : (task.result?.isEmpty == false ? task.result! : "No worker handoff yet."))
                .font(.caption)
                .foregroundStyle(Color.hermesSecondaryText)
                .textSelection(.enabled)
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Comments", systemImage: "text.bubble")
                .font(.headline)
            if details.comments.isEmpty {
                Text("No comments yet.")
                    .font(.caption)
                    .foregroundStyle(Color.hermesSecondaryText)
            } else {
                ForEach(details.comments) { comment in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(comment.author) · \(comment.createdAtLabel)")
                            .font(.caption2)
                            .foregroundStyle(Color.hermesSecondaryText)
                        Text(comment.body)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.04)))
                }
            }
            TextField("Add a comment", text: $commentDraft, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
            Button(action: onAddComment) {
                Label("Add Comment", systemImage: "plus.bubble")
            }
            .buttonStyle(.bordered)
            .disabled(commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isMutating)
        }
    }

    private var runsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Runs", systemImage: "terminal")
                .font(.headline)
            if details.runs.isEmpty {
                Text("No worker runs yet.")
                    .font(.caption)
                    .foregroundStyle(Color.hermesSecondaryText)
            } else {
                ForEach(details.runs) { run in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Run #\(run.id) · \(run.statusLabel)")
                            .font(.caption.weight(.semibold))
                        if let profile = run.profile, !profile.isEmpty {
                            Text(profile)
                                .font(.caption2)
                                .foregroundStyle(Color.hermesSecondaryText)
                        }
                        if let summary = run.summary, !summary.isEmpty {
                            Text(summary)
                                .font(.caption2)
                                .lineLimit(3)
                        }
                        if let error = run.error, !error.isEmpty {
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(Color.hermesDestructive)
                                .lineLimit(3)
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.04)))
                }
            }
        }
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Events", systemImage: "waveform.path.ecg")
                .font(.headline)
            ForEach(details.events.prefix(8)) { event in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(event.kind) · \(event.createdAtLabel)")
                        .font(.caption2.weight(.semibold))
                    if let payload = event.payload, !payload.compactDescription.isEmpty {
                        Text(payload.compactDescription)
                            .font(.caption2)
                            .foregroundStyle(Color.hermesSecondaryText)
                            .lineLimit(2)
                    }
                }
            }
        }
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(logTruncated ? "Worker Log (tail)" : "Worker Log", systemImage: "scroll")
                .font(.headline)
            ScrollView(.vertical) {
                Text(logText.isEmpty ? "No log available." : logText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.hermesSecondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 90, maxHeight: 180)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.18)))
        }
    }

    private func resetDrafts() {
        title = task.title
        bodyDraft = task.body ?? ""
        assignee = task.assignee ?? ""
        priority = task.priority
        status = task.status
    }
}
