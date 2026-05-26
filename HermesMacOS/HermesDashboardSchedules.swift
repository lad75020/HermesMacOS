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
    let lastStatus: String?
    let lastError: String?
    let lastDeliveryError: String?
    let skill: String?
    let skills: [String]?
    let contextFrom: [String]?

    enum CodingKeys: String, CodingKey {
        case id, profile, name, prompt, script, schedule, enabled, state, deliver, skill, skills
        case profileName = "profile_name"
        case scheduleDisplay = "schedule_display"
        case lastRunAt = "last_run_at"
        case nextRunAt = "next_run_at"
        case lastStatus = "last_status"
        case lastError = "last_error"
        case lastDeliveryError = "last_delivery_error"
        case contextFrom = "context_from"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        profile = try container.decodeIfPresent(String.self, forKey: .profile)
        profileName = try container.decodeIfPresent(String.self, forKey: .profileName)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt)
        script = try container.decodeIfPresent(String.self, forKey: .script)
        schedule = try container.decodeIfPresent(Schedule.self, forKey: .schedule)
        scheduleDisplay = try container.decodeIfPresent(String.self, forKey: .scheduleDisplay)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        state = try container.decodeIfPresent(String.self, forKey: .state)
        deliver = try container.decodeIfPresent(String.self, forKey: .deliver)
        lastRunAt = try container.decodeIfPresent(String.self, forKey: .lastRunAt)
        nextRunAt = try container.decodeIfPresent(String.self, forKey: .nextRunAt)
        lastStatus = try container.decodeIfPresent(String.self, forKey: .lastStatus)
        lastError = try container.decodeIfPresent(String.self, forKey: .lastError)
        lastDeliveryError = try container.decodeIfPresent(String.self, forKey: .lastDeliveryError)
        skill = try container.decodeIfPresent(String.self, forKey: .skill)
        skills = try container.decodeIfPresent([String].self, forKey: .skills)
        if let contextList = try? container.decodeIfPresent([String].self, forKey: .contextFrom) {
            contextFrom = contextList
        } else if let contextID = try? container.decodeIfPresent(String.self, forKey: .contextFrom), !contextID.isEmpty {
            contextFrom = [contextID]
        } else {
            contextFrom = nil
        }
    }

    init(
        id: String,
        profile: String?,
        profileName: String?,
        name: String?,
        prompt: String?,
        script: String?,
        schedule: Schedule?,
        scheduleDisplay: String?,
        enabled: Bool,
        state: String?,
        deliver: String?,
        lastRunAt: String?,
        nextRunAt: String?,
        lastStatus: String?,
        lastError: String?,
        lastDeliveryError: String?,
        skill: String?,
        skills: [String]?,
        contextFrom: [String]?
    ) {
        self.id = id
        self.profile = profile
        self.profileName = profileName
        self.name = name
        self.prompt = prompt
        self.script = script
        self.schedule = schedule
        self.scheduleDisplay = scheduleDisplay
        self.enabled = enabled
        self.state = state
        self.deliver = deliver
        self.lastRunAt = lastRunAt
        self.nextRunAt = nextRunAt
        self.lastStatus = lastStatus
        self.lastError = lastError
        self.lastDeliveryError = lastDeliveryError
        self.skill = skill
        self.skills = skills
        self.contextFrom = contextFrom
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
    var lastStatusLabel: String {
        guard let lastStatus, !lastStatus.isEmpty else { return "Never run" }
        return lastStatus.uppercased()
    }
    var failureLabel: String {
        if let lastError, !lastError.isEmpty { return lastError }
        if let lastDeliveryError, !lastDeliveryError.isEmpty { return "Delivery: \(lastDeliveryError)" }
        return ""
    }
    var deliveryLabel: String {
        guard let deliver, !deliver.isEmpty else { return "local" }
        return deliver
    }
    var chainLabel: String {
        let chained = contextFrom?.filter { !$0.isEmpty } ?? []
        return chained.joined(separator: ", ")
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
    var lastActionMessage = ""
    var lastOutputByJobID: [String: String] = [:]

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

    func createSchedule(name: String, schedule: String, prompt: String, skillName: String, delivery: String, contextFrom: [String], dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        activeTask?.cancel()
        activeTask = Task {
            await createJob(name: name, schedule: schedule, prompt: prompt, skillName: skillName, delivery: delivery, contextFrom: contextFrom, dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
        }
    }

    func runJobNow(_ job: HermesDashboardScheduleJob, dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        activeTask?.cancel()
        activeTask = Task { await triggerJob(job, dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) }
    }

    func loadLastOutput(for job: HermesDashboardScheduleJob, hermesHome: String) {
        do {
            lastOutputByJobID[job.id] = try Self.latestOutput(for: job, hermesHome: hermesHome)
            lastActionMessage = "Loaded latest output for \(job.displayName)."
        } catch {
            lastOutputByJobID[job.id] = error.localizedDescription
            lastActionMessage = error.localizedDescription
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
        lastActionMessage = ""
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
            lastActionMessage = enabled ? "Resumed \(job.displayName)." : "Paused \(job.displayName)."
            await loadJobs(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func triggerJob(_ job: HermesDashboardScheduleJob, dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
        isLoading = true
        lastErrorMessage = ""
        lastActionMessage = ""
        defer { isLoading = false }

        do {
            let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let token = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
            var request = URLRequest(url: try apiURL(baseURL: baseURL, path: "api/cron/jobs/\(job.id)/trigger", queryItems: [URLQueryItem(name: "profile", value: job.profileLabel)]))
            request.httpMethod = "POST"
            request.timeoutInterval = 30
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
            let session = HermesNetworkSessionFactory.session(for: apiSettings)
            let (_, response) = try await session.data(for: request)
            try HermesNetworkSessionFactory.validate(response: response)
            lastActionMessage = "Queued \(job.displayName) for the next scheduler tick."
            await loadJobs(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func createJob(name: String, schedule: String, prompt: String, skillName: String, delivery: String, contextFrom: [String], dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
        isLoading = true
        lastErrorMessage = ""
        lastActionMessage = ""
        defer { isLoading = false }

        do {
            let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanSchedule = schedule.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanSkill = skillName.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanDelivery = delivery.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanContext = contextFrom.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            guard !cleanName.isEmpty else { throw HermesDashboardSchedulesError.validation("Enter a schedule name.") }
            guard !cleanSchedule.isEmpty else { throw HermesDashboardSchedulesError.validation("Enter a schedule expression.") }
            guard !cleanPrompt.isEmpty || !cleanSkill.isEmpty else { throw HermesDashboardSchedulesError.validation("Enter content or a skill name.") }
            guard !cleanDelivery.isEmpty else { throw HermesDashboardSchedulesError.validation("Choose a delivery target.") }

            let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let token = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
            let createPayload = HermesDashboardScheduleCreateRequest(
                prompt: cleanPrompt,
                schedule: cleanSchedule,
                name: cleanName,
                deliver: cleanDelivery
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

            if !cleanSkill.isEmpty || !cleanContext.isEmpty {
                try await updateJobMetadata(created, skillName: cleanSkill, contextFrom: cleanContext, baseURL: baseURL, token: token, apiSettings: apiSettings)
            }
            lastActionMessage = "Created \(cleanName)."
            await loadJobs(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func updateJobMetadata(_ job: HermesDashboardScheduleJob, skillName: String, contextFrom: [String], baseURL: URL, token: String, apiSettings: HermesAPISettings) async throws {
        var updateValues: [String: AnyEncodable] = [:]
        if !skillName.isEmpty {
            updateValues["skill"] = AnyEncodable(skillName)
            updateValues["skills"] = AnyEncodable([skillName])
        }
        if !contextFrom.isEmpty {
            updateValues["context_from"] = AnyEncodable(contextFrom)
        }
        guard !updateValues.isEmpty else { return }
        let updates = HermesDashboardScheduleUpdateRequest(updates: updateValues)
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

    private static func latestOutput(for job: HermesDashboardScheduleJob, hermesHome: String) throws -> String {
        let safeJobID = job.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeJobID.isEmpty, safeJobID == URL(fileURLWithPath: safeJobID).lastPathComponent, !safeJobID.contains("/"), !safeJobID.contains("\\") else {
            throw HermesDashboardSchedulesError.validation("Invalid cron job id for output lookup.")
        }
        let home = URL(fileURLWithPath: hermesHome.isEmpty ? "/Volumes/WDBlack4TB/.hermes" : hermesHome, isDirectory: true)
        let profileHome = resolvedProfileHome(for: job.profileLabel, under: home)
        let outputDirectory = profileHome.appendingPathComponent("cron/output/\(safeJobID)", isDirectory: true)
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: outputDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw HermesDashboardSchedulesError.validation("No output directory yet for \(job.displayName). Run the job once, then load output again.")
        }
        let markdownFiles = files.filter { $0.pathExtension.lowercased() == "md" }
        guard let latest = markdownFiles.max(by: { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate < rhsDate
        }) else {
            throw HermesDashboardSchedulesError.validation("No saved output found for \(job.displayName).")
        }
        let text = try String(contentsOf: latest, encoding: .utf8)
        let limited = text.count > 20_000 ? String(text.prefix(20_000)) + "\n\n… truncated in HermesMacOS preview …" : text
        return "\(latest.lastPathComponent)\n\n\(limited)"
    }

    private static func resolvedProfileHome(for profile: String, under root: URL) -> URL {
        let cleanProfile = profile.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanProfile.isEmpty, cleanProfile.lowercased() != "default" else { return root }
        let profilesDirectory = root.appendingPathComponent("profiles", isDirectory: true)
        if let children = try? FileManager.default.contentsOfDirectory(at: profilesDirectory, includingPropertiesForKeys: nil),
           let exact = children.first(where: { $0.lastPathComponent.caseInsensitiveCompare(cleanProfile) == .orderedSame }) {
            return exact
        }
        return profilesDirectory.appendingPathComponent(cleanProfile, isDirectory: true)
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
