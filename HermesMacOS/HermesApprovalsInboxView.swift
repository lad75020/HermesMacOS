//
//  HermesApprovalsInboxView.swift
//  HermesMacOS
//

import Foundation
import Observation
import SwiftUI

struct HermesApprovalItem: Identifiable, Decodable, Equatable {
    let id: String
    let sessionKey: String
    let queuePosition: Int
    let kind: String
    let title: String
    let command: String
    let description: String
    let patternKey: String?
    let patternKeys: [String]
    let createdAt: Double?
    let surface: String?
    let scopeOptions: [String]

    enum CodingKeys: String, CodingKey {
        case id, kind, title, command, description, surface
        case sessionKey = "session_key"
        case queuePosition = "queue_position"
        case patternKey = "pattern_key"
        case patternKeys = "pattern_keys"
        case createdAt = "created_at"
        case scopeOptions = "scope_options"
    }

    var displayKind: String {
        switch kind {
        case "shell_command": "Shell command"
        default: kind.split(separator: "_").map { $0.capitalized }.joined(separator: " ")
        }
    }

    var allowsAlways: Bool { scopeOptions.contains("always") }

    var ageText: String {
        guard let createdAt else { return "Pending" }
        let elapsed = max(0, Date().timeIntervalSince1970 - createdAt)
        if elapsed < 60 { return "\(Int(elapsed))s ago" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))m ago" }
        return "\(Int(elapsed / 3600))h ago"
    }
}

struct HermesApprovalsResponse: Decodable {
    let approvals: [HermesApprovalItem]
    let count: Int
}

struct HermesApprovalResolveBody: Encodable {
    let choice: String
    let resolveAll: Bool
    let sessionKey: String

    enum CodingKeys: String, CodingKey {
        case choice
        case resolveAll = "resolve_all"
        case sessionKey = "session_key"
    }
}

@MainActor
@Observable
final class HermesApprovalsInboxStore {
    var approvals: [HermesApprovalItem] = []
    var status = "Ready"
    var lastErrorMessage = ""
    var isLoading = false
    var resolvingIDs: Set<String> = []
    var lastUpdated: Date?
    var autoRefresh = true
    private var cachedTokenByBaseURL: [String: String] = [:]

    var pendingCount: Int { approvals.count }

    func refresh(dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
        guard !isLoading else { return }
        isLoading = true
        status = "Refreshing approvals"
        lastErrorMessage = ""
        defer { isLoading = false }

        do {
            let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let token = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
            let response: HermesApprovalsResponse
            do {
                response = try await fetchApprovals(baseURL: baseURL, token: token, apiSettings: apiSettings)
            } catch HermesResponsesError.httpError(401) {
                cachedTokenByBaseURL.removeValue(forKey: baseURL.absoluteString)
                let refreshedToken = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
                response = try await fetchApprovals(baseURL: baseURL, token: refreshedToken, apiSettings: apiSettings)
            }
            approvals = response.approvals.sorted { lhs, rhs in
                if lhs.sessionKey == rhs.sessionKey { return lhs.queuePosition < rhs.queuePosition }
                return lhs.sessionKey.localizedStandardCompare(rhs.sessionKey) == .orderedAscending
            }
            lastUpdated = Date()
            status = approvals.isEmpty ? "No pending approvals" : "\(approvals.count) pending approval\(approvals.count == 1 ? "" : "s")"
        } catch {
            lastErrorMessage = error.localizedDescription
            status = "Approvals refresh failed"
        }
    }

    func resolve(_ approval: HermesApprovalItem, choice: String, dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
        guard !resolvingIDs.contains(approval.id) else { return }
        resolvingIDs.insert(approval.id)
        status = "Resolving approval"
        lastErrorMessage = ""
        defer { resolvingIDs.remove(approval.id) }

        do {
            let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let token = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
            do {
                try await resolveApproval(baseURL: baseURL, token: token, apiSettings: apiSettings, approval: approval, choice: choice)
            } catch HermesResponsesError.httpError(401) {
                cachedTokenByBaseURL.removeValue(forKey: baseURL.absoluteString)
                let refreshedToken = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
                try await resolveApproval(baseURL: baseURL, token: refreshedToken, apiSettings: apiSettings, approval: approval, choice: choice)
            }
            status = "Approval \(choice == "deny" ? "denied" : "approved")"
            await refresh(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
        } catch {
            lastErrorMessage = error.localizedDescription
            status = "Resolve failed"
        }
    }

    func runAutoRefreshLoop(dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
        await refresh(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
        while !Task.isCancelled {
            do { try await Task.sleep(nanoseconds: 5_000_000_000) } catch { break }
            if Task.isCancelled { break }
            guard autoRefresh else { continue }
            await refresh(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
        }
    }

    private func dashboardSessionToken(baseURL: URL, apiSettings: HermesAPISettings) async throws -> String {
        let cacheKey = baseURL.absoluteString
        if let cached = cachedTokenByBaseURL[cacheKey], !cached.isEmpty { return cached }
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (data, response) = try await session.data(from: baseURL)
        try HermesNetworkSessionFactory.validate(response: response)
        let html = String(decoding: data, as: UTF8.self)
        let pattern = #"window\.__HERMES_SESSION_TOKEN__=\"([^\"]+)\""#
        let regex = try NSRegularExpression(pattern: pattern)
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: nsRange), let tokenRange = Range(match.range(at: 1), in: html) else { throw HermesApprovalsInboxError.missingDashboardSessionToken }
        let token = String(html[tokenRange])
        cachedTokenByBaseURL[cacheKey] = token
        return token
    }

    private func fetchApprovals(baseURL: URL, token: String, apiSettings: HermesAPISettings) async throws -> HermesApprovalsResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/approvals"))
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (data, response) = try await session.data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
        return try JSONDecoder().decode(HermesApprovalsResponse.self, from: data)
    }

    private func resolveApproval(baseURL: URL, token: String, apiSettings: HermesAPISettings, approval: HermesApprovalItem, choice: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/approvals/resolve"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        request.httpBody = try JSONEncoder().encode(HermesApprovalResolveBody(choice: choice, resolveAll: false, sessionKey: approval.sessionKey))
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (_, response) = try await session.data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
    }

    private func resolvedDashboardBaseURL(from dashboardBaseURL: String, apiBaseURL: String) throws -> URL {
        let explicit = dashboardBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty, let url = normalizedBaseURL(from: explicit) { return url }
        var fallback = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if fallback.hasSuffix("/v1") { fallback.removeLast(3) }
        guard let url = normalizedBaseURL(from: fallback) else { throw HermesApprovalsInboxError.invalidDashboardURL }
        return url
    }

    private func normalizedBaseURL(from value: String) -> URL? {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        return URL(string: trimmed)
    }
}

enum HermesApprovalsInboxError: LocalizedError {
    case invalidDashboardURL
    case missingDashboardSessionToken

    var errorDescription: String? {
        switch self {
        case .invalidDashboardURL: "The Hermes dashboard URL is invalid."
        case .missingDashboardSessionToken: "The dashboard session token was not found in the dashboard HTML."
        }
    }
}

struct HermesApprovalsInboxView: View {
    let apiSettings: HermesAPISettings
    let dashboardURL: String
    let store: HermesApprovalsInboxStore
    let connectedHostName: String
    let connectedWindowID: UUID

    var body: some View {
        VStack(spacing: 18) {
            header
            statusRow
            content
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: dashboardURL + apiSettings.baseURL) {
            await store.runAutoRefreshLoop(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Approvals Inbox")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Native queue for pending Hermes confirmations, shell commands, and destructive action warnings.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Label(connectedHostName, systemImage: "network")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.hermesSurface.opacity(0.7)))
        }
    }

    private var statusRow: some View {
        HStack(spacing: 12) {
            Label(store.status, systemImage: store.pendingCount == 0 ? "checkmark.circle" : "tray.full")
                .font(.callout.weight(.semibold))
                .foregroundStyle(store.pendingCount == 0 ? .green : .hermesOrange)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.hermesSurface.opacity(0.72)))
            if let lastUpdated = store.lastUpdated {
                Text("Updated \(lastUpdated.formatted(date: .omitted, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Auto refresh", isOn: Binding(
                get: { store.autoRefresh },
                set: { store.autoRefresh = $0 }
            ))
                .toggleStyle(.switch)
                .font(.caption)
            Button {
                Task { await store.refresh(dashboardBaseURL: dashboardURL, apiSettings: apiSettings) }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(store.isLoading)
        }
    }

    @ViewBuilder
    private var content: some View {
        if !store.lastErrorMessage.isEmpty {
            Text(store.lastErrorMessage)
                .font(.callout)
                .foregroundStyle(Color.hermesDestructive)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .hermesGlassPanel(tint: Color.hermesDestructive.opacity(0.08), cornerRadius: 16)
        }

        if store.approvals.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("No approvals waiting")
                    .font(.title3.weight(.semibold))
                Text("When Hermes needs confirmation for a command or destructive action, it will appear here with approve / deny controls.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .hermesGlassPanel(tint: Color.hermesSurface.opacity(0.54), cornerRadius: 24)
        } else {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(store.approvals) { approval in
                        approvalCard(approval)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func approvalCard(_ approval: HermesApprovalItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: approval.kind == "shell_command" ? "terminal" : "exclamationmark.triangle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.hermesOrange)
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(approval.title)
                        .font(.headline)
                    Text("\(approval.displayKind) • Queue #\(approval.queuePosition) • \(approval.ageText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(approval.surface ?? "gateway")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.hermesSurface.opacity(0.8)))
            }

            if !approval.description.isEmpty {
                Label(approval.description, systemImage: "exclamationmark.shield")
                    .font(.callout)
                    .foregroundStyle(Color.hermesOrange)
            }

            if !approval.command.isEmpty {
                Text(approval.command)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.18)))
            }

            Text("Session: \(approval.sessionKey)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)

            HStack(spacing: 10) {
                approvalButton("Approve once", systemImage: "checkmark.circle", tint: .green, approval: approval, choice: "once")
                approvalButton("Approve session", systemImage: "checkmark.seal", tint: .hermesActionBlue, approval: approval, choice: "session")
                approvalButton("Always allow similar", systemImage: "infinity.circle", tint: .purple, approval: approval, choice: "always")
                    .disabled(!approval.allowsAlways || store.resolvingIDs.contains(approval.id))
                approvalButton("Deny", systemImage: "xmark.octagon", tint: .hermesDestructive, approval: approval, choice: "deny")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hermesGlassPanel(tint: Color.hermesSurface.opacity(0.62), cornerRadius: 22)
    }

    private func approvalButton(_ title: String, systemImage: String, tint: Color, approval: HermesApprovalItem, choice: String) -> some View {
        Button {
            Task { await store.resolve(approval, choice: choice, dashboardBaseURL: dashboardURL, apiSettings: apiSettings) }
        } label: {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .disabled(store.resolvingIDs.contains(approval.id))
    }
}
