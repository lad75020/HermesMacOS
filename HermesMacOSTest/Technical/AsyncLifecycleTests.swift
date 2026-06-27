import XCTest

final class AsyncLifecycleTests: XCTestCase {
    func testTimeoutHelperReturnsBeforeDeadlineForFastOperation() async throws {
        let value = try await HermesAsyncTestSupport.withTimeout(seconds: 1) { "ok" }
        XCTAssertEqual(value, "ok")
    }

    func testTimeoutHelperCancelsSlowOperation() async {
        do {
            _ = try await HermesAsyncTestSupport.withTimeout(seconds: 0.01) {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return "late"
            }
            XCTFail("Expected timeout")
        } catch {
            XCTAssertTrue((error as? URLError)?.code == .timedOut)
        }
    }

    func testFakeProcessIsBoundedAndDeterministic() async {
        let result = await HermesAsyncTestSupport.fakeProcess(arguments: ["git", "status"], timeout: 1)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("git status"))
    }
}
