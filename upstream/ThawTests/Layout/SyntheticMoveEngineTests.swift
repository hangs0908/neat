import AppKit
import MenuBarModel
import Testing
@testable import Thaw

@MainActor
@Suite("합성 이동의 취소와 재시도", .serialized)
struct SyntheticMoveEngineTests {
    @Test("이동 불가능한 출발 항목과 대상은 입력 준비 전에 거절한다", arguments: [true, false])
    func immovableItemIsRefused(blockSource: Bool) async throws {
        let fixture = try Fixture()
        let blocked = fixture.item(tag: .clock, x: fixture.origin.x)
        let source = blockSource ? blocked : fixture.mover
        let target = blockSource ? fixture.target : blocked
        do {
            try await fixture.engine.move(item: source, to: .rightOfItem(target))
            Issue.record("이동 불가능한 항목이 거절되지 않았습니다")
        } catch let error as SyntheticMoveEngine.EventError {
            guard case let .itemNotMovable(item, reason) = error else {
                Issue.record("잘못된 거절 오류: \(error)")
                return
            }
            #expect(item.tag == blocked.tag)
            #expect(reason != nil)
        }
        #expect(fixture.sourceCalls == 0)
        #expect(fixture.prepared.isEmpty && fixture.posts.isEmpty && fixture.snapshots == 0)
        try await expectSinglePermit(fixture.semaphore)
    }

    @Test("이미 도착한 초기 스냅샷은 재조회나 드래그 없이 종료한다")
    func satisfiedInitialSnapshotSkipsDrag() async throws {
        let fixture = try Fixture()
        fixture.settled = true
        var engine = fixture.engine
        engine.initialItems = fixture.items

        try await engine.move(item: fixture.mover, to: .rightOfItem(fixture.target))

        #expect(fixture.prepared == [1])
        #expect(fixture.snapshots == 0 && fixture.posts.isEmpty && fixture.results.isEmpty)
        try await expectSinglePermit(fixture.semaphore)
    }

    @Test("이동이 관측되지 않으면 정해진 횟수만 시도하고 오류를 반환한다", arguments: [0, 1, 3])
    func exhaustedAttemptsAreBounded(maxAttempts: Int) async throws {
        let fixture = try Fixture()
        do {
            try await fixture.engine.move(item: fixture.mover, to: .rightOfItem(fixture.target), maxAttempts: maxAttempts)
            Issue.record("실패한 이동이 성공으로 처리됐습니다")
        } catch let error as SyntheticMoveEngine.EventError {
            guard case .cannotComplete = error else {
                Issue.record("잘못된 재시도 종료 오류: \(error)")
                return
            }
        }
        let attempts = max(1, maxAttempts)
        #expect(fixture.prepared == Array(1 ... attempts))
        #expect(fixture.posts.count == attempts)
        #expect(fixture.results == Array(repeating: false, count: attempts))
        try await expectSinglePermit(fixture.semaphore)
    }

    @Test("성공하면 다음 시도를 멈추고 재시도에는 바뀐 좌표를 사용한다", arguments: [1, 2])
    func retryUsesFreshGeometryAndStopsOnSuccess(successAttempt: Int) async throws {
        let fixture = try Fixture()
        fixture.succeedsOnAttempt = successAttempt

        try await fixture.engine.move(item: fixture.mover, to: .rightOfItem(fixture.target), maxAttempts: 4)

        #expect(fixture.prepared == Array(1 ... successAttempt))
        #expect(fixture.results == Array(repeating: false, count: successAttempt - 1) + [true])
        try #require(fixture.posts.count == successAttempt)
        if successAttempt == 2 {
            #expect(fixture.posts[1].x - fixture.posts[0].x == 20)
        }
        try await expectSinglePermit(fixture.semaphore)
    }

    @Test("조회 또는 전송 중 취소되면 추가 조회와 재시도가 중단된다", arguments: [true, false])
    func cancellationStopsFurtherWork(duringEnumeration: Bool) async throws {
        let fixture = try Fixture()
        fixture.cancelDuringEnumeration = duringEnumeration
        fixture.cancelDuringDrag = !duringEnumeration
        let task = Task { @MainActor in
            try await fixture.engine.move(item: fixture.mover, to: .rightOfItem(fixture.target), maxAttempts: 4)
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(fixture.prepared == [1])
        #expect(fixture.snapshots == 1)
        #expect(fixture.posts.count == (duringEnumeration ? 0 : 1))
        #expect(fixture.results.isEmpty)
        try await expectSinglePermit(fixture.semaphore)
    }

    @Test("입력 소스 생성과 전송 오류는 그대로 전달되고 잠금은 해제된다", arguments: [true, false])
    func inputFailureReleasesPermit(sourceFails: Bool) async throws {
        let fixture = try Fixture()
        fixture.sourceFails = sourceFails
        fixture.dragFails = !sourceFails
        await #expect(throws: Fixture.InputFailure.self) {
            try await fixture.engine.move(item: fixture.mover, to: .rightOfItem(fixture.target), maxAttempts: 4)
        }
        #expect(fixture.sourceCalls == 1)
        #expect(fixture.prepared == (sourceFails ? [] : [1]))
        #expect(fixture.snapshots == (sourceFails ? 0 : 1))
        #expect(fixture.posts.count == (sourceFails ? 0 : 1))
        #expect(fixture.results.isEmpty)
        try await expectSinglePermit(fixture.semaphore)
    }

    @Test("잠금을 얻기 전에 취소된 이동은 다른 보유자의 잠금을 해제하지 않는다")
    func cancelledWaitDoesNotReleaseAnotherPermit() async throws {
        let fixture = try Fixture()
        try await fixture.semaphore.wait()
        let task = Task { @MainActor in
            try await fixture.engine.move(item: fixture.mover, to: .rightOfItem(fixture.target))
        }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(fixture.sourceCalls == 0 && fixture.posts.isEmpty)
        await #expect(throws: SimpleSemaphore.TimeoutError.self) {
            try await fixture.semaphore.wait(timeout: .milliseconds(25))
        }
        await fixture.semaphore.signal()
        try await expectSinglePermit(fixture.semaphore)
    }

    private func expectSinglePermit(_ semaphore: SimpleSemaphore) async throws {
        try await semaphore.wait(timeout: .seconds(1))
        defer { await semaphore.signal() }
        await #expect(throws: SimpleSemaphore.TimeoutError.self) {
            try await semaphore.wait(timeout: .milliseconds(25))
        }
    }
}

@MainActor
private final class Fixture {
    struct InputFailure: Error {}

    let semaphore = SimpleSemaphore(value: 1)
    let origin: CGPoint
    var sourceCalls = 0
    var snapshots = 0
    var prepared = [Int]()
    var posts = [CGPoint]()
    var results = [Bool]()
    var settled = false
    var succeedsOnAttempt: Int?
    var cancelDuringEnumeration = false
    var cancelDuringDrag = false
    var sourceFails = false
    var dragFails = false

    init() throws {
        let frame = try #require(NSScreen.allDisplayBoundsCG.first { $0.width >= 240 && $0.height >= 240 })
        origin = CGPoint(x: frame.minX + 30, y: frame.midY)
        try #require(!MenuBarLayoutPlannerProvider.current.liveOrderSatisfiesDestination(
            items: items, item: mover, destination: .rightOfItem(target), experimentalSystemItemHiding: false
        ))
        settled = true
        try #require(MenuBarLayoutPlannerProvider.current.liveOrderSatisfiesDestination(
            items: items, item: mover, destination: .rightOfItem(target), experimentalSystemItemHiding: false
        ))
        settled = false
    }

    var mover: MenuBarItem {
        item(tag: MenuBarItemTag(namespace: .string("test.mover"), title: "Item-0"), x: origin.x)
    }

    var target: MenuBarItem {
        item(tag: MenuBarItemTag(namespace: .string("test.target"), title: "Item-0"), x: origin.x + 80 + retryOffset)
    }

    private var retryOffset: CGFloat {
        prepared.count > 1 ? 20 : 0
    }

    var items: [MenuBarItem] {
        if settled {
            [target, item(tag: mover.tag, x: origin.x + 120 + retryOffset)]
        } else {
            [mover, target]
        }
    }

    func item(tag: MenuBarItemTag, x: CGFloat) -> MenuBarItem {
        // 창 ID 0으로 실제 창 경로를 피하고 이벤트 전송도 기록 함수로 대체한다.
        MenuBarItem(tag: tag, windowID: 0, ownerPID: 100, sourcePID: 200,
                    bounds: CGRect(x: x, y: origin.y, width: 20, height: 20), title: tag.title, isOnScreen: true)
    }

    var engine: SyntheticMoveEngine {
        var engine = SyntheticMoveEngine(
            eventSemaphore: semaphore,
            makeEventSource: {
                self.sourceCalls += 1
                if self.sourceFails {
                    throw InputFailure()
                }
                return try #require(CGEventSource(stateID: .privateState))
            },
            enumerateItems: {
                self.snapshots += 1
                if self.cancelDuringEnumeration {
                    withUnsafeCurrentTask { $0?.cancel() }
                }
                return self.items
            }
        )
        engine.resolveMenuBarAgentPID = { nil }
        engine.prepareForAttempt = { self.prepared.append($0) }
        engine.postCommandDrag = { _, end, _, _, _ in
            self.posts.append(end)
            if self.dragFails {
                throw InputFailure()
            }
            if self.cancelDuringDrag {
                withUnsafeCurrentTask { $0?.cancel() }
            }
            if self.prepared.last == self.succeedsOnAttempt {
                self.settled = true
            }
        }
        engine.onAttemptResult = { _, satisfied in self.results.append(satisfied) }
        return engine
    }
}
