import XCTest
@testable import HermesMacOS

@MainActor
final class HermesResourceUsageMonitorTests: XCTestCase {
    func testParserAcceptsValidatedWholeAndDecimalPercentages() throws {
        let timestamp = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-20T12:00:00Z"))
        let snapshot = try XCTUnwrap(HermesResourceUsageMonitor.parseSnapshot(
            from: "GPU Usage: 27%\nMemory Usage: 66.1%",
            timestamp: timestamp
        ))

        XCTAssertEqual(snapshot.gpuPercentage, 27)
        XCTAssertEqual(snapshot.memoryPercentage, 66.1)
        XCTAssertEqual(snapshot.timestamp, timestamp)
    }

    func testParserRejectsMalformedMissingDuplicateAndOutOfRangePercentages() {
        let invalidSamples = [
            "GPU Usage: seventy%\nMemory Usage: 66%",
            "GPU Usage: 27%",
            "GPU usage: 27%\nMemory Usage: 66%",
            "GPU Usage: 101%\nMemory Usage: 66%",
            "GPU Usage: -1%\nMemory Usage: 66%",
            "GPU Usage: NaN%\nMemory Usage: 66%",
            "GPU Usage: 27%\nGPU Usage: 28%\nMemory Usage: 66%",
        ]

        for output in invalidSamples {
            XCTAssertNil(HermesResourceUsageMonitor.parseSnapshot(from: output), output)
        }
    }

    func testFailuresPublishSafeUnavailableOrStaleStateWithoutRawOutput() async {
        let rawOutput = "GPU Usage: 27%\nMemory Usage: 66%\napi_key=not-for-the-ui"
        let sequence = ResourceUsageExecutionSequence(results: [
            .init(exitCode: 0, output: rawOutput, timedOut: false),
            .init(exitCode: 1, output: rawOutput, timedOut: false),
        ])
        let monitor = HermesResourceUsageMonitor(executor: { try await sequence.next() })

        await monitor.refresh()
        XCTAssertEqual(monitor.availability, .fresh)
        XCTAssertNotNil(monitor.snapshot)

        let failingMonitor = HermesResourceUsageMonitor(executor: { .init(exitCode: 7, output: rawOutput, timedOut: false) })
        await failingMonitor.refresh()
        XCTAssertEqual(failingMonitor.availability, .unavailable)
        XCTAssertNil(failingMonitor.snapshot)

        let timedOutMonitor = HermesResourceUsageMonitor(executor: { .init(exitCode: 0, output: rawOutput, timedOut: true) })
        await timedOutMonitor.refresh()
        XCTAssertEqual(timedOutMonitor.availability, .unavailable)
        XCTAssertNil(timedOutMonitor.snapshot)

        await monitor.refresh()
        XCTAssertEqual(monitor.availability, .stale)
        XCTAssertNotNil(monitor.snapshot)
        XCTAssertFalse(String(describing: monitor.availability).contains("api_key="))
    }

    func testStartAndStopCancelTheInjectedExecutorPromptly() async {
        let probe = ResourceUsageExecutionProbe()
        let monitor = HermesResourceUsageMonitor(executor: { try await probe.execute() })

        monitor.start()
        await probe.waitUntilStarted()
        monitor.stop()

        let observedCancellation = await probe.waitForCancellation()
        XCTAssertTrue(observedCancellation)
    }

    func testFixedExecutionContractHasNoShellOrArguments() {
        XCTAssertEqual(HermesResourceUsageMonitor.executablePath, "/Volumes/WDBlack4TB/Code/NodeMLX/utils/GPUUsage")
        XCTAssertEqual(HermesResourceUsageMonitor.defaultPollingInterval, 5)
        XCTAssertGreaterThan(HermesResourceUsageMonitor.defaultExecutionTimeout, 0)
    }
}

private actor ResourceUsageExecutionSequence {
    private var results: [HermesResourceUsageExecution]

    init(results: [HermesResourceUsageExecution]) {
        self.results = results
    }

    func next() throws -> HermesResourceUsageExecution {
        guard !results.isEmpty else { throw URLError(.cannotLoadFromNetwork) }
        return results.removeFirst()
    }
}

private actor ResourceUsageExecutionProbe {
    private var didStart = false
    private var observedCancellation = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var cancellationWaiters: [CheckedContinuation<Void, Never>] = []

    func waitUntilStarted() async {
        if didStart { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func waitForCancellation() async -> Bool {
        if observedCancellation { return true }
        await withCheckedContinuation { cancellationWaiters.append($0) }
        return observedCancellation
    }

    func execute() async throws -> HermesResourceUsageExecution {
        didStart = true
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }

        do {
            while true {
                try Task.checkCancellation()
                await Task.yield()
            }
        } catch is CancellationError {
            observedCancellation = true
            let waiters = cancellationWaiters
            cancellationWaiters.removeAll()
            waiters.forEach { $0.resume() }
            throw CancellationError()
        }
    }
}
