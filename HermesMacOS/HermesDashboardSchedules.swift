//
//  HermesDashboardSchedules.swift
//  HermesMacOS
//

import Foundation

struct HermesDashboardScheduleJob: Codable, Identifiable, Equatable {
    struct Schedule: Codable, Equatable {
        let kind: String?
        let expr: String?
        let display: String?
    }

    let id: String
    let profile: String?
    let profileName: String?
    let name: String?
    let prompt: String?
    let script: String?
    let schedule: Schedule?
    let scheduleDisplay: String?
    let enabled: Bool
    let state: String?
    let deliver: String?
    let lastRunAt: String?
    let nextRunAt: String?
    let lastError: String?
    let skill: String?
    let skills: [String]?

    enum CodingKeys: String, CodingKey {
        case id, profile, name, prompt, script, schedule, enabled, state, deliver, skill, skills
        case profileName = "profile_name"
        case scheduleDisplay = "schedule_display"
        case lastRunAt = "last_run_at"
        case nextRunAt = "next_run_at"
        case lastError = "last_error"
    }

    var profileLabel: String { (profile?.isEmpty == false ? profile : profileName) ?? "default" }
    var displayName: String {
        if let name, !name.isEmpty { return name }
        if let firstSkill = skills?.first, !firstSkill.isEmpty { return firstSkill }
        if let skill, !skill.isEmpty { return skill }
        if let prompt, !prompt.isEmpty { return String(prompt.prefix(60)) }
        return id
    }
    var scheduleLabel: String {
        if let scheduleDisplay, !scheduleDisplay.isEmpty { return scheduleDisplay }
        if let display = schedule?.display, !display.isEmpty { return display }
        if let expr = schedule?.expr, !expr.isEmpty { return expr }
        return "—"
    }
    var statusLabel: String {
        if let state, !state.isEmpty { return state.capitalized }
        return enabled ? "Scheduled" : "Paused"
    }
    var isEnabled: Bool { enabled && state?.lowercased() != "paused" }
    var skillLabel: String {
        let loaded = skills?.filter { !$0.isEmpty } ?? []
        if !loaded.isEmpty { return loaded.joined(separator: ", ") }
        if let skill, !skill.isEmpty { return skill }
        return ""
    }
    var contentPreview: String {
        if let prompt, !prompt.isEmpty { return prompt }
        if let script, !script.isEmpty { return script }
        return skillLabel.isEmpty ? "No prompt content" : "Skill: \(skillLabel)"
    }
}

@Observable
final class HermesDashboardSchedulesStore {
    var jobs: [HermesDashboardScheduleJob] = []
    var isLoading = false
    var lastErrorMessage = ""

    private var activeTask: Task<Void, Never>?
    private var cachedTokenByBaseURL: [String: String] = [:]

    func refresh(dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        activeTask?.cancel()
        activeTask = Task { await loadJobs(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) }
    }

    func setJobEnabled(_ job: HermesDashboardScheduleJob, enabled: Bool, dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        activeTask?.cancel()
        activeTask = Task { await updateEnabled(job, enabled: enabled, dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) }
    }

    func createSchedule(name: String, schedule: String, prompt: String, skillName: String, dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        activeTask?.cancel()
        activeTask = Task {
            await createJob(name: name, schedule: schedule, prompt: prompt, skillName: skillName, dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
        }
    }

    private func loadJobs(dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
        isLoading = true
        lastErrorMessage = ""
        defer { isLoading = false }

        do {
            let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let token = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
            jobs = try await fetchJobs(baseURL: baseURL, token: token, apiSettings: apiSettings).sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func updateEnabled(_ job: HermesDashboardScheduleJob, enabled: Bool, dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
        isLoading = true
        lastErrorMessage = ""
        defer { isLoading = false }

        do {
            let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let token = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
            let path = "api/cron/jobs/\(job.id)/\(enabled ? "resume" : "pause")"
            var request = URLRequest(url: try apiURL(baseURL: baseURL, path: path, queryItems: [URLQueryItem(name: "profile", value: job.profileLabel)]))
            request.httpMethod = "POST"
            request.timeoutInterval = 30
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
            let session = HermesNetworkSessionFactory.session(for: apiSettings)
            let (_, response) = try await session.data(for: request)
            try HermesNetworkSessionFactory.validate(response: response)
            await loadJobs(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func createJob(name: String, schedule: String, prompt: String, skillName: String, dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
        isLoading = true
        lastErrorMessage = ""
        defer { isLoading = false }

        do {
            let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanSchedule = schedule.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanSkill = skillName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanName.isEmpty else { throw HermesDashboardSchedulesError.validation("Enter a schedule name.") }
            guard !cleanSchedule.isEmpty else { throw HermesDashboardSchedulesError.validation("Enter a schedule expression.") }
            guard !cleanPrompt.isEmpty || !cleanSkill.isEmpty else { throw HermesDashboardSchedulesError.validation("Enter content or a skill name.") }

            let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let token = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
            let createPayload = HermesDashboardScheduleCreateRequest(
                prompt: cleanPrompt,
                schedule: cleanSchedule,
                name: cleanName,
                deliver: "local"
            )
            var request = URLRequest(url: try apiURL(baseURL: baseURL, path: "api/cron/jobs", queryItems: [URLQueryItem(name: "profile", value: "default")]))
            request.httpMethod = "POST"
            request.timeoutInterval = 30
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
            request.httpBody = try JSONEncoder().encode(createPayload)
            let session = HermesNetworkSessionFactory.session(for: apiSettings)
            let (data, response) = try await session.data(for: request)
            try HermesNetworkSessionFactory.validate(response: response)
            let created = try JSONDecoder().decode(HermesDashboardScheduleJob.self, from: data)

            if !cleanSkill.isEmpty {
                try await updateJobSkills(created, skillName: cleanSkill, baseURL: baseURL, token: token, apiSettings: apiSettings)
            }
            await loadJobs(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func updateJobSkills(_ job: HermesDashboardScheduleJob, skillName: String, baseURL: URL, token: String, apiSettings: HermesAPISettings) async throws {
        let updates = HermesDashboardScheduleUpdateRequest(updates: [
            "skill": AnyEncodable(skillName),
            "skills": AnyEncodable([skillName])
        ])
        var request = URLRequest(url: try apiURL(baseURL: baseURL, path: "api/cron/jobs/\(job.id)", queryItems: [URLQueryItem(name: "profile", value: job.profileLabel)]))
        request.httpMethod = "PUT"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        request.httpBody = try JSONEncoder().encode(updates)
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (_, response) = try await session.data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
    }

    private func fetchJobs(baseURL: URL, token: String, apiSettings: HermesAPISettings) async throws -> [HermesDashboardScheduleJob] {
        var request = URLRequest(url: try apiURL(baseURL: baseURL, path: "api/cron/jobs", queryItems: [URLQueryItem(name: "profile", value: "all")]))
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (data, response) = try await session.data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
        return try JSONDecoder().decode([HermesDashboardScheduleJob].self, from: data)
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
        guard let match = regex.firstMatch(in: html, range: nsRange), let tokenRange = Range(match.range(at: 1), in: html) else {
            throw HermesDashboardSchedulesError.missingDashboardSessionToken
        }
        let token = String(html[tokenRange])
        cachedTokenByBaseURL[cacheKey] = token
        return token
    }

    private func resolvedDashboardBaseURL(from dashboardBaseURL: String, apiBaseURL: String) throws -> URL {
        let explicit = dashboardBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty, let url = normalizedBaseURL(from: explicit) { return url }
        var fallback = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if fallback.hasSuffix("/v1") { fallback.removeLast(3) }
        guard let url = normalizedBaseURL(from: fallback) else { throw HermesDashboardSchedulesError.invalidDashboardURL }
        return url
    }

    private func normalizedBaseURL(from value: String) -> URL? {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        return URL(string: trimmed)
    }

    private func apiURL(baseURL: URL, path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        var basePath = components?.path ?? ""
        while basePath.hasSuffix("/") { basePath.removeLast() }
        components?.path = basePath + "/" + path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components?.url else { throw HermesDashboardSchedulesError.invalidDashboardURL }
        return url
    }
}

private struct HermesDashboardScheduleCreateRequest: Encodable {
    let prompt: String
    let schedule: String
    let name: String
    let deliver: String
}

private struct HermesDashboardScheduleUpdateRequest: Encodable {
    let updates: [String: AnyEncodable]
}

private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        self.encodeValue = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}

enum HermesDashboardSchedulesError: LocalizedError {
    case invalidDashboardURL
    case missingDashboardSessionToken
    case validation(String)

    var errorDescription: String? {
        switch self {
        case .invalidDashboardURL:
            return "The Hermes dashboard URL is invalid."
        case .missingDashboardSessionToken:
            return "The dashboard session token was not found in the dashboard HTML."
        case .validation(let message):
            return message
        }
    }
}
