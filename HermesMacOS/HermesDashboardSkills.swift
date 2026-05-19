//
//  HermesDashboardSkills.swift
//  HermesMacOS
//

import SwiftUI

struct HermesDashboardSkill: Decodable, Identifiable, Equatable {
    let name: String
    let description: String?
    let enabled: Bool?

    var id: String { name }
}

@Observable
final class HermesDashboardSkillsStore {
    var skills: [HermesDashboardSkill] = []
    var isLoading = false
    var lastErrorMessage = ""

    private var activeTask: Task<Void, Never>?
    private var cachedTokenByBaseURL: [String: String] = [:]

    func refreshIfNeeded(dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        guard skills.isEmpty, !isLoading else { return }
        refresh(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
    }

    func refresh(dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        activeTask?.cancel()
        activeTask = Task { await loadSkills(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) }
    }

    private func loadSkills(dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
        isLoading = true
        lastErrorMessage = ""
        defer { isLoading = false }

        do {
            let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let token = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
            let fetched = try await fetchSkills(baseURL: baseURL, token: token, apiSettings: apiSettings)
            skills = fetched
                .filter { $0.enabled ?? true }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            lastErrorMessage = error.localizedDescription
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
        guard let match = regex.firstMatch(in: html, range: nsRange), let tokenRange = Range(match.range(at: 1), in: html) else {
            throw HermesDashboardSkillsError.missingDashboardSessionToken
        }
        let token = String(html[tokenRange])
        cachedTokenByBaseURL[cacheKey] = token
        return token
    }

    private func fetchSkills(baseURL: URL, token: String, apiSettings: HermesAPISettings) async throws -> [HermesDashboardSkill] {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/skills"))
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (data, response) = try await session.data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
        return try JSONDecoder().decode([HermesDashboardSkill].self, from: data)
    }

    private func resolvedDashboardBaseURL(from dashboardBaseURL: String, apiBaseURL: String) throws -> URL {
        let explicit = dashboardBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty, let url = normalizedBaseURL(from: explicit) { return url }
        var fallback = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if fallback.hasSuffix("/v1") { fallback.removeLast(3) }
        guard let url = normalizedBaseURL(from: fallback) else { throw HermesDashboardSkillsError.invalidDashboardURL }
        return url
    }

    private func normalizedBaseURL(from value: String) -> URL? {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        return URL(string: trimmed)
    }
}

enum HermesDashboardSkillsError: LocalizedError {
    case invalidDashboardURL
    case missingDashboardSessionToken

    var errorDescription: String? {
        switch self {
        case .invalidDashboardURL:
            return "The Hermes dashboard URL is invalid."
        case .missingDashboardSessionToken:
            return "The dashboard session token was not found in the dashboard HTML."
        }
    }
}

struct HermesSkillSlashPicker: View {
    let skills: [HermesDashboardSkill]
    let selectedIndex: Int
    let isLoading: Bool
    let errorMessage: String
    let onSelect: (HermesDashboardSkill) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading && skills.isEmpty {
                dropdownRow(title: "Loading skills…", subtitle: nil, isSelected: false)
            } else if !errorMessage.isEmpty && skills.isEmpty {
                dropdownRow(title: "Skills unavailable", subtitle: errorMessage, isSelected: false)
            } else if skills.isEmpty {
                dropdownRow(title: "No matching skills", subtitle: nil, isSelected: false)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(skills.enumerated()), id: \.element.id) { index, skill in
                                Button { onSelect(skill) } label: {
                                    dropdownRow(title: "/\(skill.name)", subtitle: skill.description, isSelected: index == selectedIndex)
                                }
                                .id(skill.id)
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(height: 176)
                    .onChange(of: selectedIndex) { _, newIndex in
                        guard skills.indices.contains(newIndex) else { return }
                        withAnimation(.easeInOut(duration: 0.12)) { proxy.scrollTo(skills[newIndex].id, anchor: .center) }
                    }
                    .onAppear {
                        guard skills.indices.contains(selectedIndex) else { return }
                        proxy.scrollTo(skills[selectedIndex].id, anchor: .center)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: 10)
    }

    private func dropdownRow(title: String, subtitle: String?, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .lineLimit(1)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.82) : Color.hermesSecondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 35, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.hermesActionBlue.opacity(0.86) : Color.clear)
        .contentShape(Rectangle())
    }
}

extension String {
    var hermesActiveSlashSkillQuery: String? {
        guard let slashIndex = lastIndex(of: "/") else { return nil }
        let suffix = self[index(after: slashIndex)...]
        if suffix.contains(where: { $0.isWhitespace || $0 == "/" }) { return nil }
        return String(suffix)
    }

    func replacingActiveSlashSkillQuery(with skillName: String) -> String {
        guard let slashIndex = lastIndex(of: "/") else { return self }
        let prefix = self[..<slashIndex]
        return "\(prefix)/\(skillName) "
    }
}
