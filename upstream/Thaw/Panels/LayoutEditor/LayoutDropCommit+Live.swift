//
//  LayoutDropCommit+Live.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit
import MenuBarModel

extension LayoutDropCommit {
    static func commit(_ drop: Drop, appState: AppState, undoManager: UndoManager?, finished: @escaping @MainActor () -> Void) {
        guard drop.source != drop.target else {
            reorder(drop, appState: appState, undoManager: undoManager)
            finished()
            return
        }
        ExplicitLayoutEdit.task {
            await seatAndRecord(drop, appState: appState)
            finished()
        }
    }

    /// The same drop awaited to its end, for a caller that reports the outcome.
    /// Returns false when the move path declined it.
    static func perform(_ drop: Drop, appState: AppState) async -> Bool {
        guard drop.source != drop.target else {
            reorder(drop, appState: appState, undoManager: nil)
            return true
        }
        return await ExplicitLayoutEdit.$isActive.withValue(true) {
            await seatAndRecord(drop, appState: appState)
        }
    }

    private static func reorder(_ drop: Drop, appState: AppState, undoManager: UndoManager?) {
        LayoutBarKeyboard.applySectionOrder(
            drop.targetOrder,
            previousOrder: drop.previousTargetOrder,
            section: drop.target,
            appState: appState,
            undoManager: undoManager,
            actionName: String(localized: "Move \(drop.items.first?.displayName ?? "")")
        )
    }

    /// Seats the items before the assertion flips, as for a move from the item menu, then
    /// records the target's membership and order once. Returns whether the record was made.
    @discardableResult
    private static func seatAndRecord(_ drop: Drop, appState: AppState) async -> Bool {
        await move(
            drop.items,
            from: drop.source,
            to: drop.target,
            orderedAs: drop.targetOrder,
            asGroup: drop.items.count > 1 && !drop.isBatch,
            appState: appState
        ) == true
    }

    /// 메뉴 이동은 위치를 지정하지 않으며, 그룹은 목적지의 기존 저장 순서를 따른다.
    /// 이미 안내한 그룹 거절은 nil을 반환해 호출자의 중복 알림을 막는다.
    static func move(
        _ items: [MenuBarItem],
        from source: MenuBarSection.Name,
        to target: MenuBarSection.Name,
        orderedAs order: [MenuBarItem]? = nil,
        asGroup: Bool,
        appState: AppState
    ) async -> Bool? {
        let controller = appState.menuBarManager.sectionController
        var recorded: Bool? = false
        await appState.itemManager.seatItemsForSectionTransition(items, to: target, orderedAs: order) {
            if asGroup {
                recorded = assignGroup(items, from: source, to: target, appState: appState) ? true : nil
                return
            }
            if let item = items.first, items.count == 1 {
                controller.setSection(target, item: item)
            } else if let refusal = appState.menuBarManager.setSection(target, items: items, atomically: true) {
                diagLog.warning("Batch move to \(target.logString) refused: \(refusal)")
                return
            }
            if let order {
                controller.setSectionOrder(from: order, for: target)
                appState.itemManager.scheduleSectionOrderApply(for: target)
            }
            recorded = true
        }
        await appState.itemManager.cacheItemsRegardless(skipRecentMoveCheck: true)
        return recorded
    }

    private static func assignGroup(
        _ items: [MenuBarItem],
        from source: MenuBarSection.Name,
        to target: MenuBarSection.Name,
        appState: AppState
    ) -> Bool {
        guard let refusal = appState.menuBarManager.setSection(target, items: items, atomically: true) else {
            return true
        }
        let sourceItems = appState.itemManager.managedItems(for: source)
        appState.layoutFeedback.post(
            LayoutBarFeedbackCenter.blockedGroupMove(
                groupName: MenuBarSearchItemActions.groupDisplayName(for: items, in: sourceItems, appState: appState),
                section: target,
                refusal: refusal
            )
        )
        return false
    }

    private static let diagLog = DiagLog(category: "LayoutDropCommit")
}
