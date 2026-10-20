import Foundation
import Testing
@testable import Thaw

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct MenuBarDragSettlementTests {
    @Test("드래그 종료 처리는 대기 중인 설정창 순서보다 사용자 이동을 우선한다")
    func dragEndSupersedesPendingLayoutEdit() {
        let manager = MenuBarItemManager()
        manager.authoredVisibleOrderPendingPhysicalApply = true

        manager.noteUserMenuBarDragEnded()

        #expect(!manager.authoredVisibleOrderPendingPhysicalApply)
        #expect(manager.moveActivity.occurred(within: .seconds(1)))
    }

    @Test("500ms 갱신과 1.5초 정착 뒤 분류·저장을 순서대로 수행한다")
    func dragRefreshesBeforeAdoptingAndRecording() async throws {
        let (settlement, pauses) = pausedSettlement()
        var waits = pauses.makeAsyncIterator()
        let completion = AsyncStream<Void>.makeStream()
        var finished = completion.stream.makeAsyncIterator()
        var events: [String] = []
        let earlyCompletion = AsyncStream<Void>.makeStream()
        var refreshed = earlyCompletion.stream.makeAsyncIterator()
        settlement.schedule(afterUserDrag: true, refresh: {
            events.append("refresh:\($0)")
            if !$0 {
                earlyCompletion.continuation.yield(())
            }
        }, adopt: {
            events.append("adopt")
        }, record: {
            events.append("record")
            completion.continuation.yield(())
        })
        let settling = try #require(await waits.next())
        let earlyRefresh = try #require(await waits.next())
        #expect(settling.delay == .milliseconds(1500))
        #expect(earlyRefresh.delay == .milliseconds(500))
        #expect(events.isEmpty)
        earlyRefresh.resume.resume()
        _ = await refreshed.next()
        #expect(events == ["refresh:false"])
        settling.resume.resume()
        _ = await finished.next()
        #expect(events == ["refresh:false", "refresh:true", "adopt", "record"])
    }

    @Test("수동 모드 관찰은 분류만 채택하고 드래그 갱신과 순서 저장은 하지 않는다")
    func manualObservationDoesNotRecordDragOrder() async throws {
        let (settlement, pauses) = pausedSettlement()
        var waits = pauses.makeAsyncIterator()
        let completion = AsyncStream<Void>.makeStream()
        var finished = completion.stream.makeAsyncIterator()
        var events: [String] = []
        settlement.schedule(afterUserDrag: false, refresh: { events.append("refresh:\($0)") }, adopt: {
            events.append("adopt")
            completion.continuation.yield(())
        }, record: { events.append("record") })
        let settling = try #require(await waits.next())
        settling.resume.resume()
        _ = await finished.next()
        #expect(events == ["refresh:true", "adopt"])
        #expect(!settlement.isArranging(isDragging: false))
    }

    @Test("연속 드래그는 이전 정착을 취소하되 각 500ms 갱신은 유지한다")
    func nextDragReplacesOnlyPendingSettlement() async throws {
        let (settlement, pauses) = pausedSettlement()
        var waits = pauses.makeAsyncIterator()
        let completion = AsyncStream<Void>.makeStream()
        var finished = completion.stream.makeAsyncIterator()
        var events: [String] = []
        settlement.schedule(afterUserDrag: true, refresh: { events.append("old:\($0)") }, adopt: {
            events.append("old adopt")
        }, record: { events.append("old record") })
        let oldSettlement = try #require(await waits.next())
        let oldRefresh = try #require(await waits.next())
        settlement.schedule(afterUserDrag: true, refresh: { events.append("new:\($0)") }, adopt: {
            events.append("new adopt")
        }, record: {
            events.append("new record")
            completion.continuation.yield(())
        })
        let newSettlement = try #require(await waits.next())
        let newRefresh = try #require(await waits.next())
        oldSettlement.resume.resume()
        oldRefresh.resume.resume()
        newRefresh.resume.resume()
        newSettlement.resume.resume()
        _ = await finished.next()
        #expect(events.filter { !$0.hasSuffix(":false") } == ["new:true", "new adopt", "new record"])
        #expect(events.filter { $0 == "old:false" }.count == 1)
        #expect(events.filter { $0 == "new:false" }.count == 1)
    }

    @Test("캐시 갱신 대기 중 교체된 관찰은 분류와 순서를 확정하지 않는다")
    func replacementDuringRefreshCannotAdopt() async throws {
        let (settlement, pauses) = pausedSettlement()
        var waits = pauses.makeAsyncIterator()
        let refreshPause = AsyncStream<CheckedContinuation<Void, Never>>.makeStream()
        var refreshes = refreshPause.stream.makeAsyncIterator()
        let completion = AsyncStream<Void>.makeStream()
        var finished = completion.stream.makeAsyncIterator()
        var events: [String] = []
        settlement.schedule(afterUserDrag: false, refresh: { _ in
            events.append("old refresh")
            await withCheckedContinuation { refreshPause.continuation.yield($0) }
        }, adopt: { events.append("old adopt") }, record: { events.append("old record") })
        let oldSettlement = try #require(await waits.next())
        oldSettlement.resume.resume()
        let refresh = try #require(await refreshes.next())
        settlement.schedule(afterUserDrag: false, refresh: { _ in events.append("new refresh") }, adopt: {
            events.append("new adopt")
            completion.continuation.yield(())
        }, record: { events.append("new record") })
        let newSettlement = try #require(await waits.next())
        refresh.resume()
        newSettlement.resume.resume()
        _ = await finished.next()
        #expect(events == ["old refresh", "new refresh", "new adopt"])
    }

    @Test("진행 중 드래그와 종료 후 4초 동안 자동 이동을 보호한다")
    func quietPeriodTracksTheLatestDragOnly() {
        let start = ContinuousClock.now
        let settlement = MenuBarDragSettlement(sleep: { _ in })
        #expect(!settlement.isArranging(isDragging: false, now: start))
        #expect(settlement.isArranging(isDragging: true, now: start))
        settlement.schedule(afterUserDrag: true, now: start, refresh: { _ in }, adopt: {}, record: {})
        #expect(settlement.isArranging(isDragging: false, now: start + .milliseconds(3999)))
        #expect(!settlement.isArranging(isDragging: false, now: start + .seconds(4)))
        settlement.schedule(afterUserDrag: false, now: start + .seconds(3), refresh: { _ in }, adopt: {}, record: {})
        #expect(!settlement.isArranging(isDragging: false, now: start + .seconds(4)))
        settlement.schedule(afterUserDrag: true, now: start + .seconds(3), refresh: { _ in }, adopt: {}, record: {})
        #expect(settlement.isArranging(isDragging: false, now: start + .seconds(4)))
    }

    private typealias Pause = (delay: Duration, resume: CheckedContinuation<Void, any Error>)

    private func pausedSettlement() -> (MenuBarDragSettlement, AsyncStream<Pause>) {
        let pauses = AsyncStream<Pause>.makeStream()
        let settlement = MenuBarDragSettlement { delay in
            try await withCheckedThrowingContinuation { pauses.continuation.yield((delay, $0)) }
        }
        return (settlement, pauses.stream)
    }
}
