//
//  LayoutDropCommitTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit
import MenuBarModel
import Testing
@testable import Thaw

@MainActor
@Suite(.serialized)
struct LayoutDropCommitTests {
    private typealias World = LayoutEditorWorld

    private func drop(
        _ items: [MenuBarItem],
        from source: MenuBarSection.Name,
        to target: MenuBarSection.Name
    ) -> LayoutDropCommit.Drop {
        LayoutDropCommit.Drop(items: items, source: source, target: target, previousTargetOrder: [], targetOrder: items)
    }

    @Test("같은 분류의 드롭은 한 번 완료하며 실행 취소 관리자 없이도 처리한다", arguments: [false, true])
    func sameSectionDropCompletesOnce(withUndo: Bool) {
        let world = World()
        let items = [World.item("First"), World.item("Second")]
        let undoManager = withUndo ? UndoManager() : nil
        undoManager?.groupsByEvent = false
        undoManager?.beginUndoGrouping()
        var completions = 0
        let drop = LayoutDropCommit.Drop(
            items: [items[1]],
            source: .visible,
            target: .visible,
            previousTargetOrder: items,
            targetOrder: items.reversed()
        )

        LayoutDropCommit.commit(drop, appState: world.appState, undoManager: undoManager) {
            completions += 1
        }
        undoManager?.endUndoGrouping()

        #expect(completions == 1)
        #expect((undoManager?.canUndo ?? false) == withUndo)
        undoManager?.removeAllActions()
    }

    @Test
    func aDropOfNothingIsRefused() {
        let world = World()
        #expect(LayoutDropCommit.refuses(drop([], from: .visible, to: .hidden), appState: world.appState))
        #expect(world.appState.layoutFeedback.refusal == nil)
    }

    @Test(arguments: [MenuBarSection.Name.hidden, .alwaysHidden])
    func theThawIconCannotLeaveVisible(target: MenuBarSection.Name) {
        let world = World()
        let thaw = World.item(.visibleControlItem)

        #expect(LayoutDropCommit.refuses(drop([World.item("Other"), thaw], from: .visible, to: target), appState: world.appState))
        #expect(world.appState.layoutFeedback.refusal?.message.contains(Constants.displayName) == true)
    }

    @Test(arguments: MenuBarSection.Name.allCases)
    func anAppItemReordersInsideItsSection(section: MenuBarSection.Name) {
        let world = World()
        #expect(!LayoutDropCommit.refuses(drop([World.item("App")], from: section, to: section), appState: world.appState))
        #expect(world.appState.layoutFeedback.refusal == nil)
    }

    @Test
    func anItemMacOSKeepsInPlaceCannotBeReorderedInVisible() {
        let world = World()
        let divider = World.item(.hiddenControlItem)

        #expect(LayoutDropCommit.refuses(drop([divider], from: .visible, to: .visible), appState: world.appState))
        let expected = LayoutBarFeedbackCenter.itemNotMovable(itemName: divider.displayName)
        #expect(world.appState.layoutFeedback.refusal?.title == expected.title)
    }

    @Test
    func anAppItemMovesToAnotherSection() {
        let world = World()
        #expect(!LayoutDropCommit.refuses(drop([World.item("App")], from: .visible, to: .hidden), appState: world.appState))
        #expect(world.appState.layoutFeedback.refusal == nil)
    }

    @Test
    func aSingleItemThatCannotBeAssignedIsRefused() {
        let world = World()
        let divider = World.item(.hiddenControlItem)

        #expect(LayoutDropCommit.refuses(drop([divider], from: .visible, to: .hidden), appState: world.appState))
        #expect(world.appState.layoutFeedback.refusal != nil)
    }

    @Test
    func aGroupCrossingSectionsIsLeftToTheAssignment() {
        let world = World()
        let group = [World.item("One"), World.item("Two")]
        #expect(!LayoutDropCommit.refuses(drop(group, from: .visible, to: .hidden), appState: world.appState))
    }

    @Test(arguments: [false, true])
    func cancelledSectionMoveDoesNotRecordASuccess(isBatch: Bool) async {
        let world = World()
        let items = [World.item(.visibleControlItem), World.item(.hiddenControlItem)]
        let drop = LayoutDropCommit.Drop(
            items: items,
            source: .visible,
            target: .hidden,
            previousTargetOrder: [],
            targetOrder: items,
            isBatch: isBatch
        )
        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            return await LayoutDropCommit.perform(drop, appState: world.appState)
        }

        #expect(await task.value == false)
        #expect(world.appState.layoutFeedback.refusal == nil)
    }

    @Test(arguments: [false, true])
    func cancelledMenuMoveDoesNotReportAGroupRefusal(asGroup: Bool) async {
        let world = World()
        let items = [World.item(.visibleControlItem)]
        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            return await LayoutDropCommit.move(
                items,
                from: .visible,
                to: .hidden,
                asGroup: asGroup,
                appState: world.appState
            )
        }

        #expect(await task.value == false)
        #expect(world.appState.layoutFeedback.refusal == nil)
    }
}
