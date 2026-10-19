//
//  ThawBarCommandDrag.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import AppKit
import MenuBarModel

@MainActor
enum ThawBarCommandDrag {
    // 좌표는 항목 캐시와 같은 Quartz 전역 좌표를 사용한다.
    static func visibleInsertionIndex(at point: CGPoint, control: CGRect, items: [CGRect], screenMaxX: CGFloat) -> Int? {
        guard !control.isEmpty, point.y >= control.minY, point.y <= control.maxY,
              point.x >= control.maxX, point.x < screenMaxX
        else { return nil }
        return items.firstIndex { point.x < $0.midX } ?? items.count
    }

    static func isHiddenDrop(item: CGRect, control: CGRect, point: CGPoint) -> Bool {
        !item.isEmpty && !control.isEmpty && item.midY >= control.minY && item.midY <= control.maxY
            && point.y >= control.minY && point.y <= control.maxY && point.x < control.minX && item.midX < control.minX
    }

    static func drop(_ item: MenuBarItem, at point: CGPoint, appState: AppState) {
        let manager = appState.itemManager
        guard let control = manager.managedItems.first(where: \.tag.matchesVisibleControlItem),
              let mainScreen = NSScreen.screens.first else { return }
        let bounds = Bridging.getWindowBounds(for: control.windowID) ?? control.bounds
        // 별도 바의 드래그 종료 위치는 AppKit 좌표이므로 화면 배치를 보존해 변환한다.
        let quartz = CGPoint(x: point.x, y: mainScreen.frame.maxY - point.y)
        guard let screen = NSScreen.screens.first(where: { screen in
            let frame = screen.frame
            let quartzFrame = CGRect(x: frame.minX, y: mainScreen.frame.maxY - frame.maxY, width: frame.width, height: frame.height)
            return quartzFrame.contains(CGPoint(x: bounds.midX, y: bounds.midY))
        }) else { return }
        let controller = appState.menuBarManager.sectionController
        let members = movingItems(item, appState: appState)
        let movingIDs = Set(members.map(\.uniqueIdentifier))
        let previous = controller.displayOrdered(manager.managedItems(for: .visible), in: .visible)
        let ordered = previous.filter { !movingIDs.contains($0.uniqueIdentifier) && $0.isOnScreen }
            .filter { $0.bounds.midY >= bounds.minY && $0.bounds.midY <= bounds.maxY && $0.bounds.midX >= screen.frame.minX && $0.bounds.midX < screen.frame.maxX }
            .sorted { $0.bounds.minX < $1.bounds.minX }
        guard let index = visibleInsertionIndex(at: quartz, control: bounds, items: ordered.map(\.bounds), screenMaxX: screen.frame.maxX) else { return }
        var order = previous.filter { !movingIDs.contains($0.uniqueIdentifier) }
        let insertion = index < ordered.count ? order.firstIndex(of: ordered[index]) ?? order.endIndex : order.endIndex
        order.insert(contentsOf: members, at: insertion)
        let drop = LayoutDropCommit.Drop(
            items: members,
            source: controller.section(for: item),
            target: .visible,
            previousTargetOrder: previous,
            targetOrder: order,
            isBatch: true
        )
        guard !LayoutDropCommit.refuses(drop, appState: appState) else { return }
        LayoutDropCommit.commit(drop, appState: appState, undoManager: nil, finished: {})
    }

    static func adoptNativeDrop(_ item: MenuBarItem?, at point: CGPoint?, appState: AppState) async {
        guard let item, let point,
              let current = appState.itemManager.managedItem(withTag: item.tag),
              let control = appState.itemManager.managedItems.first(where: \.tag.matchesVisibleControlItem),
              isHiddenDrop(item: current.bounds, control: control.bounds, point: point)
        else { return }
        let controller = appState.menuBarManager.sectionController
        let members = movingItems(current, appState: appState)
        let previous = controller.ordered(appState.itemManager.managedItems(for: .hidden), in: .hidden)
        let drop = LayoutDropCommit.Drop(
            items: members,
            source: controller.section(for: current),
            target: .hidden,
            previousTargetOrder: previous,
            targetOrder: previous + members,
            isBatch: true
        )
        guard !LayoutDropCommit.refuses(drop, appState: appState) else { return }
        _ = await LayoutDropCommit.perform(drop, appState: appState)
    }

    private static func movingItems(_ item: MenuBarItem, appState: AppState) -> [MenuBarItem] {
        let controller = appState.menuBarManager.sectionController
        let items = controller.ordered(appState.itemManager.managedItems(for: controller.section(for: item)), in: controller.section(for: item))
        guard let group = appState.itemGroupManager.resolvedGroup(containing: item, in: items) else { return [item] }
        return group.memberIndices.compactMap { items.indices.contains($0) ? items[$0] : nil }
    }
}
