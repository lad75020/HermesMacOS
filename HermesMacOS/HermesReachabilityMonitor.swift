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

    private let agentAPIURL = URL(string: "http://localhost:8642")!
    private let dashboardURL = URL(string: "http://localhost:9119")!

    func runAgentAPILoop() async {
        // First run check immediately on loop start to set initial state
        let initialReachable = await Self.endpointIsReachable(agentAPIURL)
        agentAPIIsReachable = initialReachable
        await runLoop(url: agentAPIURL) { agentAPIIsReachable = $0 }
    }

    func runDashboardLoop() async {
        await runLoop(url: dashboardURL) { dashboardIsReachable = $0 }
    }

    private func runLoop(url: URL, setReachable: (Bool) -> Void) async {
        while !Task.isCancelled {
            let isReachable = await Self.endpointIsReachable(url)
            setReachable(isReachable)

            do {
                try await Task.sleep(for: .seconds(isReachable ? 5 : 1))
            } catch {
                break
            }
        }
    }

    private nonisolated static func endpointIsReachable(_ url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 2

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
