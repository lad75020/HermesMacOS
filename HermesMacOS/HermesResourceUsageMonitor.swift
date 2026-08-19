//
//  HermesResourceUsageMonitor.swift
//  HermesMacOS
//

import Foundation
import Observation

struct HermesResourceUsageSnapshot: Equatable, Sendable {
    let gpuPercentage: Double
    let memoryPercentage: Double
    let timestamp: Date
}

enum HermesResourceUsageAvailability: Equatable, Sendable {
    case fresh
    case stale
    case unavailable
}

struct HermesResourceUsageExecution: Equatable, Sendable {
    let exitCode: Int32
    let output: String
    let timedOut: Bool
}

@MainActor
@Observable
final class HermesResourceUsageMonitor {
    typealias Executor = @Sendable () async throws -> HermesResourceUsageExecution

    static let executablePath = "/Volumes/WDBlack4TB/Code/NodeMLX/utils/GPUUsage"
    static let defaultPollingInterval: TimeInterval = 5
    static let defaultExecutionTimeout: TimeInterval = 2

    private(set) var snapshot: HermesResourceUsageSnapshot?
    private(set) var availability: HermesResourceUsageAvailability = .unavailable
    private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private let executor: Executor
    @ObservationIgnored private let pollingInterval: TimeInterval

    init(
        executor: @escaping Executor = HermesResourceUsageMonitor.executeGPUUsageUtility,
        pollingInterval: TimeInterval = HermesResourceUsageMonitor.defaultPollingInterval
    ) {
        self.executor = executor
        self.pollingInterval = max(pollingInterval, Self.defaultPollingInterval)
    }


    func start() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            await self?.runPollingLoop()
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh() async {
        do {
            let execution = try await executor()
            try Task.checkCancellation()
            guard execution.exitCode == 0, !execution.timedOut,
                  let parsedSnapshot = Self.parseSnapshot(from: execution.output, timestamp: .now) else {
                markUnavailable()
                return
            }

            snapshot = parsedSnapshot
            availability = .fresh
        } catch is CancellationError {
            // Cancellation is a lifecycle event, not a user-visible utility failure.
        } catch {
            markUnavailable()
        }
    }

    static func parseSnapshot(from output: String, timestamp: Date = .now) -> HermesResourceUsageSnapshot? {
        guard let gpuPercentage = percentage(named: "GPU Usage", in: output),
              let memoryPercentage = percentage(named: "Memory Usage", in: output),
              gpuPercentage.isFinite,
              memoryPercentage.isFinite,
              (0...100).contains(gpuPercentage),
              (0...100).contains(memoryPercentage) else {
            return nil
        }

        return HermesResourceUsageSnapshot(
            gpuPercentage: gpuPercentage,
            memoryPercentage: memoryPercentage,
            timestamp: timestamp
        )
    }

    private func runPollingLoop() async {
        defer { pollingTask = nil }
        while !Task.isCancelled {
            await refresh()
            guard !Task.isCancelled else { break }
            do {
                try await Task.sleep(for: .seconds(pollingInterval))
            } catch {
                break
            }
        }
    }

    private func markUnavailable() {
        availability = snapshot == nil ? .unavailable : .stale
    }

    private static func percentage(named label: String, in output: String) -> Double? {
        let escapedLabel = NSRegularExpression.escapedPattern(for: label)
        let pattern = "^\\s*\(escapedLabel)\\s*:\\s*([+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+))\\s*%\\s*$"
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }

        let matches = output
            .split(whereSeparator: { $0.isNewline })
            .compactMap { line -> Double? in
                let text = String(line)
                let range = NSRange(text.startIndex..., in: text)
                guard let match = expression.firstMatch(in: text, range: range), match.numberOfRanges == 2,
                      let valueRange = Range(match.range(at: 1), in: text) else {
                    return nil
                }
                return Double(text[valueRange])
            }

        guard matches.count == 1 else { return nil }
        return matches[0]
    }

    private nonisolated static func executeGPUUsageUtility() async throws -> HermesResourceUsageExecution {
        let processTask = Task.detached(priority: .utility) {
            let result = try await HermesProcessRunner.runCancellable(
                executable: executablePath,
                arguments: [],
                timeout: defaultExecutionTimeout
            )
            return HermesResourceUsageExecution(
                exitCode: result.exitCode,
                output: result.output,
                timedOut: result.timedOut
            )
        }

        return try await withTaskCancellationHandler(
            operation: { try await processTask.value },
            onCancel: { processTask.cancel() }
        )
    }
}
