//
//  HermesReachabilityMonitor.swift
//  HermesMacOS
//

import Foundation
import Observation

@MainActor
@Observable
final class HermesReachabilityMonitor {
    var agentAPIIsReachable = false
    var dashboardIsReachable = false

    func runAgentAPILoop(apiBaseURL: String) async {
        await runLoop(urls: Self.apiEndpointCandidates(baseURLString: apiBaseURL), includeAPIKey: true) { agentAPIIsReachable = $0 }
    }

    func runDashboardLoop(dashboardBaseURL: String) async {
        await runLoop(urls: Self.dashboardEndpointCandidates(baseURLString: dashboardBaseURL), includeAPIKey: false) { dashboardIsReachable = $0 }
    }

    private func runLoop(urls: [URL], includeAPIKey: Bool, setReachable: (Bool) -> Void) async {
        while !Task.isCancelled {
            let isReachable = await Self.anyEndpointIsReachable(urls, includeAPIKey: includeAPIKey)
            setReachable(isReachable)

            do {
                try await Task.sleep(for: .seconds(isReachable ? 5 : 1))
            } catch {
                break
            }
        }
    }

    private nonisolated static func apiEndpointCandidates(baseURLString: String) -> [URL] {
        guard let baseURL = URL(string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return [] }
        return uniqueURLs([
            baseURL,
            baseURL.appendingPathComponent("models"),
            baseURL.appendingPathComponent("profiles"),
        ])
    }

    private nonisolated static func dashboardEndpointCandidates(baseURLString: String) -> [URL] {
        guard let baseURL = URL(string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return [] }
        return uniqueURLs([baseURL])
    }

    private nonisolated static func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { url in
            let key = url.absoluteString
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private nonisolated static func anyEndpointIsReachable(_ urls: [URL], includeAPIKey: Bool) async -> Bool {
        for url in urls {
            if Task.isCancelled { return false }
            if await endpointIsReachable(url, includeAPIKey: includeAPIKey) { return true }
        }
        return false
    }

    private nonisolated static func endpointIsReachable(_ url: URL, includeAPIKey: Bool) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 2
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let apiKey = includeAPIKey ? HermesAPIKeychain.loadAPIKey() : ""
        if !apiKey.isEmpty, !HermesEndpointSecurity.isRemotePlaintext(url) {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await URLSession.shared.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200..<500).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }
}
