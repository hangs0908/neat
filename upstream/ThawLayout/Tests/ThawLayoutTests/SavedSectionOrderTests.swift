import Testing
import ThawLayout

@Suite("저장 순서 보존과 저장 시점")
struct SavedSectionOrderTests {
    @Test("종료된 항목을 가장 가까운 이웃 옆에 복원한다", arguments: [
        (["b", "d"], ["a", "b", "c", "d", "e"], ["a", "b", "c", "d", "e"]),
        (["d", "b"], ["a", "b", "c", "d", "e"], ["c", "d", "e", "a", "b"]),
        (["new"], ["a", "b"], ["new", "a", "b"]),
        ([String](), ["a", "b"], ["a", "b"]),
        (["b"], ["a", "a", "b"], ["a", "b"]),
    ])
    func closedItemsKeepNeighborPositions(current: [String], saved: [String], expected: [String]) {
        let result = LayoutSolver.planSectionOrder(
            currentInSection: current, oldSavedForSection: saved,
            allCurrentIdentifiers: Set(current), allCurrentBaseIdentifiers: []
        )
        #expect(result == expected)
        #expect(LayoutSolver.planSectionOrder(
            currentInSection: current, oldSavedForSection: result,
            allCurrentIdentifiers: Set(current), allCurrentBaseIdentifiers: []
        ) == expected)
    }

    @Test("다른 섹션으로 이동한 항목과 오래된 인스턴스 및 제목은 되살리지 않는다", arguments: [false, true])
    func staleIdentitiesAreDropped(filterNamespaces: Bool) {
        let result = LayoutSolver.planSectionOrder(
            currentInSection: ["timer:00:30", "multi:item:2"],
            oldSavedForSection: ["moved:item", "multi:item:1", "timer:00:29", "closed:item"],
            allCurrentIdentifiers: ["timer:00:30", "multi:item:2", "moved:item"],
            allCurrentBaseIdentifiers: ["timer:00", "multi:item", "moved:item"],
            allCurrentNamespaces: filterNamespaces ? ["timer", "multi", "moved"] : []
        )
        #expect(result == ["timer:00:30", "multi:item:2", "closed:item"])
    }

    @Test("같은 앱의 변경된 제목은 네임스페이스 필터가 있을 때만 제거한다", arguments: [false, true])
    func namespaceFilterDoesNotDiscardClosedApps(enabled: Bool) {
        let result = LayoutSolver.planSectionOrder(
            currentInSection: ["timer:new"],
            oldSavedForSection: ["timer:old", "timerExtra:item", "closed:item"],
            allCurrentIdentifiers: ["timer:new"], allCurrentBaseIdentifiers: ["timer:new"],
            allCurrentNamespaces: enabled ? ["timer"] : []
        )
        #expect(result == (enabled
                ? ["timer:new", "timerExtra:item", "closed:item"]
                : ["timer:new", "timer:old", "timerExtra:item", "closed:item"]))
    }

    @Test("작업 플래그가 하나라도 켜져 있으면 저장을 차단한다", arguments: 0 ..< 16)
    func persistenceGateCoversEveryFlagCombination(flags: Int) {
        #expect(LayoutSolver.shouldPersistSavedOrder(
            isRestoringItemOrder: flags & 1 != 0,
            isResettingLayout: flags & 2 != 0,
            isInStartupSettling: flags & 4 != 0,
            isApplyingProfileLayout: flags & 8 != 0
        ) == (flags == 0))
    }
}
