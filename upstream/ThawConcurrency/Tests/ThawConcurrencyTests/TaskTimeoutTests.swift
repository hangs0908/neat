import Synchronization
import Testing
@testable import ThawConcurrency

@Suite("구조화된 작업 시간 제한", .timeLimit(.minutes(1)))
struct TaskTimeoutTests {
    private enum OperationError: Error { case failed }

    @Test("작업의 값이나 원래 오류를 전달하고 타이머를 종료한다", arguments: [false, true])
    func operationWins(throwsError: Bool) async throws {
        let clock = ControlledClock()
        let releaseOperation = Signal()
        let task = Task {
            try await Task<Int, any Error>.withTimeout(.seconds(3600), clock: clock) {
                try await releaseOperation.wait()
                if throwsError {
                    throw OperationError.failed
                }
                return 42
            }
        }
        await clock.started.waitForSignal()
        releaseOperation.open()

        if throwsError {
            await #expect(throws: OperationError.failed) { try await task.value }
        } else {
            #expect(try await task.value == 42)
        }
        // 그룹이 반환한 시점에는 취소된 타이머도 종료되어야 한다.
        #expect(clock.finished.isOpen)
    }

    @Test("시간 초과나 호출자 취소는 작업을 취소하고 종료까지 기다린다", arguments: [false, true])
    func cancellationJoinsOperation(cancelCaller: Bool) async {
        let clock = ControlledClock()
        let operationStarted = Signal()
        let releaseOperation = Signal()
        let operationFinished = Signal()
        let task = Task {
            try await Task<Int, any Error>.withTimeout(.seconds(3600), clock: clock) {
                operationStarted.open()
                defer { operationFinished.open() }
                try await releaseOperation.wait()
                return 42
            }
        }
        await operationStarted.waitForSignal()
        await clock.started.waitForSignal()
        if cancelCaller {
            task.cancel()
            await #expect(throws: CancellationError.self) { try await task.value }
        } else {
            clock.deadline.open()
            await #expect(throws: TaskTimeoutError.self) { try await task.value }
        }
        #expect(operationFinished.isOpen)
        #expect(clock.finished.isOpen)
    }
}

private struct ControlledClock: Clock {
    typealias Instant = ContinuousClock.Instant
    let started = Signal()
    let deadline = Signal()
    let finished = Signal()
    var now: Instant {
        .now
    }

    var minimumResolution: Duration {
        .nanoseconds(1)
    }

    func sleep(until _: Instant, tolerance _: Duration?) async throws {
        started.open()
        defer { finished.open() }
        try await deadline.wait()
    }
}

private final class Signal: Sendable {
    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation
    private let state = Mutex(false)

    init() {
        (stream, continuation) = AsyncStream<Void>.makeStream()
    }

    var isOpen: Bool {
        state.withLock { $0 }
    }

    func open() {
        state.withLock { $0 = true }
        continuation.finish()
    }

    func wait() async throws {
        for await _ in stream {}
        try Task.checkCancellation()
    }

    func waitForSignal() async {
        for await _ in stream {}
    }
}
