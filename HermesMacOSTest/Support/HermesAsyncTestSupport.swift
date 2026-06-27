import Foundation
import XCTest

enum HermesAsyncTestSupport {
    struct FakeProcessResult: Equatable, Sendable {
        let exitCode: Int32
        let output: String
    }

    static func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw URLError(.timedOut)
            }
            let value = try await group.next()!
            group.cancelAll()
            return value
        }
    }

    static func fakeProcess(arguments: [String], timeout: TimeInterval = 1) async -> FakeProcessResult {
        let joined = arguments.joined(separator: " ")
        if timeout <= 0 { return FakeProcessResult(exitCode: 124, output: "timed out") }
        return FakeProcessResult(exitCode: 0, output: "fake process: \(joined)")
    }
}
