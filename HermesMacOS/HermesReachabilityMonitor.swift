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

    private let agentAPIURLs = [
        URL(string: "http://localhost:8642")!,
        URL(string: "http://localhost:8642/v1/models")!,
        URL(string: "http://localhost:8642/v1/profiles")!,
        URL(string: "http://127.0.0.1:8642")!,
        URL(string: "http://127.0.0.1:8642/v1/models")!,
        URL(string: "http://127.0.0.1:8642/v1/profiles")!,
    ]
    private let dashboardURLs = [
        URL(string: "http://localhost:9119")!,
        URL(string: "http://127.0.0.1:9119")!,
    ]

    func runAgentAPILoop() async {
        await runLoop(urls: agentAPIURLs) { agentAPIIsReachable = $0 }
    }

    func runDashboardLoop() async {
        await runLoop(urls: dashboardURLs) { dashboardIsReachable = $0 }
    }

    private func runLoop(urls: [URL], setReachable: (Bool) -> Void) async {
        while !Task.isCancelled {
            let isReachable = await Self.anyEndpointIsReachable(urls)
            setReachable(isReachable)

            do {
                try await Task.sleep(for: .seconds(isReachable ? 5 : 1))
            } catch {
                break
            }
        }
    }

    private nonisolated static func anyEndpointIsReachable(_ urls: [URL]) async -> Bool {
        for url in urls {
            if Task.isCancelled { return false }
            if await endpointIsReachable(url) { return true }
        }
        return false
    }

    private nonisolated static func endpointIsReachable(_ url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 2
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (_, response) = try await URLSession.shared.bytes(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
