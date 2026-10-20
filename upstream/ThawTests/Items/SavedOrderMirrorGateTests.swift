//
//  SavedOrderMirrorGateTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import CoreGraphics
import Foundation
import MenuBarModel
import Testing
@testable import Thaw

/// The live order becomes the saved order only once the bar has been quiet for a while.
@MainActor
@Suite("Saved order mirror gate")
struct SavedOrderMirrorGateTests {
    private let start = ContinuousClock.now
    private let items: Set<String> = ["a", "b", "c"]

    private func at(_ seconds: Double) -> ContinuousClock.Instant {
        start + .milliseconds(Int(seconds * 1000))
    }

    @Test("A quiet bar may be mirrored")
    func quietBarMirrors() {
        let gate = SavedOrderMirrorGate(observesSystem: false)
        #expect(gate.allowsMirror(identifiers: items, restrictionChange: nil, now: at(0)))
        #expect(gate.allowsMirror(identifiers: items, restrictionChange: nil, now: at(3)))
    }

    @Test("An item arriving holds the mirror past the agent's rewrite 10 s later")
    func arrivalHoldsTheMirror() {
        let gate = SavedOrderMirrorGate(observesSystem: false)
        _ = gate.allowsMirror(identifiers: items, restrictionChange: nil, now: at(0))
        #expect(!gate.allowsMirror(identifiers: items.union(["d"]), restrictionChange: nil, now: at(1)))
        #expect(!gate.allowsMirror(identifiers: items.union(["d"]), restrictionChange: nil, now: at(11.5)))
        #expect(gate.allowsMirror(identifiers: items.union(["d"]), restrictionChange: nil, now: at(13.5)))
    }

    @Test("An item leaving holds the mirror too")
    func departureHoldsTheMirror() {
        let gate = SavedOrderMirrorGate(observesSystem: false)
        _ = gate.allowsMirror(identifiers: items, restrictionChange: nil, now: at(0))
        #expect(!gate.allowsMirror(identifiers: ["a", "b"], restrictionChange: nil, now: at(1)))
    }

    @Test("One item swapped for another in the same pass holds the mirror")
    func swapHoldsTheMirror() {
        let gate = SavedOrderMirrorGate(observesSystem: false)
        _ = gate.allowsMirror(identifiers: items, restrictionChange: nil, now: at(0))
        #expect(!gate.allowsMirror(identifiers: ["a", "b", "d"], restrictionChange: nil, now: at(1)))
    }

    @Test("A recent hiding change holds the mirror")
    func restrictionChangeHoldsTheMirror() {
        let gate = SavedOrderMirrorGate(observesSystem: false)
        #expect(!gate.allowsMirror(identifiers: items, restrictionChange: at(1), now: at(2)))
        #expect(gate.allowsMirror(identifiers: items, restrictionChange: at(1), now: at(14)))
    }

    @Test("A wake or display change holds the mirror")
    func systemEventHoldsTheMirror() {
        let gate = SavedOrderMirrorGate(observesSystem: false)
        _ = gate.allowsMirror(identifiers: items, restrictionChange: nil, now: at(0))
        gate.noteDisturbance(at: at(10))
        #expect(!gate.allowsMirror(identifiers: items, restrictionChange: nil, now: at(12)))
        #expect(gate.allowsMirror(identifiers: items, restrictionChange: nil, now: at(23)))
    }

    @Test("사용자 드래그는 최근 화면 변경과 아이콘 추가보다 우선한다", arguments: [false, true])
    func userDragMirrorsDuringQuietPeriod(withArrival: Bool) {
        let key = "MenuBarItemManager.savedSectionOrder"
        let previous = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(previous, forKey: key) }

        let manager = MenuBarItemManager()
        let a = Self.item(x: 150, windowID: 1)
        let b = Self.item(x: 100, windowID: 2)
        var cache = MenuBarItemCache(displayID: nil)
        let draggedItems = [b, a] + (withArrival ? [Self.item(x: 200, windowID: 3)] : [])
        cache[.visible] = [a, b] + Array(draggedItems.dropFirst(2))
        let visibleKey = MenuBarSectionName.visible.rawValue
        manager.savedSectionOrder = [visibleKey: [a, b].map(\.uniqueIdentifier)]
        manager.lastMirroredLiveVisibleIdentifiers = Set([a, b].map(\.uniqueIdentifier))
        manager.savedOrderMirrorGate.noteDisturbance()

        manager.recordUserDraggedVisibleOrder(from: cache, inventory: Self.snapshot(cache.managedItems), sectionAssignment: [:], displays: Self.displays)

        #expect(manager.savedSectionOrder[visibleKey] == draggedItems.map(\.uniqueIdentifier))
        #expect(UserDefaults.standard.dictionary(forKey: key)?[visibleKey] as? [String] == draggedItems.map(\.uniqueIdentifier))
    }

    @Test("드래그 기록은 펼친 숨김 아이콘과 오버플로 기록을 보존한다")
    func userDragPreservesConcealedSlots() {
        let key = "MenuBarItemManager.savedSectionOrder"
        let previous = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(previous, forKey: key) }
        let manager = MenuBarItemManager()
        let a = Self.item(x: 150, windowID: 1)
        let b = Self.item(x: 100, windowID: 2)
        let hidden = Self.item(x: 125, windowID: 3)
        let overflow = Self.item(x: -1, windowID: 4)
        var cache = MenuBarItemCache(displayID: nil)
        cache[.visible] = [a, b, hidden]
        cache[.hidden] = [overflow]
        let assignment: [String: MenuBarSectionName] = [hidden.uniqueIdentifier: .hidden]
        let visibleKey = MenuBarSectionName.visible.rawValue
        let hiddenKey = MenuBarSectionName.hidden.rawValue
        manager.savedSectionOrder = [visibleKey: [a, hidden, overflow, b].map(\.uniqueIdentifier), hiddenKey: [hidden.uniqueIdentifier]]
        manager.authoredLayoutSourceOverride = AuthoredLayoutSource(
            sectionAssignment: assignment, sectionItemOrder: [.visible: [a, overflow, b].map(\.uniqueIdentifier)]
        )

        #expect(manager.recordUserDraggedVisibleOrder(from: cache, inventory: Self.snapshot(cache.managedItems), sectionAssignment: assignment, displays: Self.displays))

        #expect(manager.savedSectionOrder[visibleKey] == [b, a, overflow].map(\.uniqueIdentifier))
        #expect(manager.savedSectionOrder[hiddenKey] == [hidden.uniqueIdentifier])
    }

    @Test("불안정한 좌표나 서로 다른 화면의 좌표는 드래그 순서로 저장하지 않는다", arguments: [0.0, 2000.0])
    func userDragRejectsUnsettledGeometry(x: Double) {
        let manager = MenuBarItemManager()
        var cache = MenuBarItemCache(displayID: nil)
        cache[.visible] = [Self.item(x: 100, windowID: 1), Self.item(x: x, y: x == 0 ? 3.5 : -396.5, windowID: 2)]
        let saved = [MenuBarSectionName.visible.rawValue: ["old"]]
        manager.savedSectionOrder = saved
        #expect(!manager.recordUserDraggedVisibleOrder(from: cache, inventory: Self.snapshot(cache.managedItems), sectionAssignment: [:], displays: Self.displays))
        #expect(manager.savedSectionOrder == saved)
    }

    @Test("부분 관찰은 이전 좌표를 드래그 순서로 확정하지 않는다")
    func partialInventoryCannotRecordDrag() {
        let manager = MenuBarItemManager()
        var cache = MenuBarItemCache(displayID: nil)
        cache[.visible] = [Self.item(x: 100)]
        let saved = [MenuBarSectionName.visible.rawValue: ["old"]]
        manager.savedSectionOrder = saved
        #expect(!manager.recordUserDraggedVisibleOrder(from: cache, inventory: .unavailable, sectionAssignment: [:], displays: Self.displays))
        #expect(manager.savedSectionOrder == saved)
    }

    private static func snapshot(_ items: [MenuBarItem]) -> MenuBarItemAXProvider.InventorySnapshot {
        .init(items: items, freshItems: items, completed: true, hasFreshKnownInventory: true, hasFreshMoveInventory: true)
    }

    @Test("The quiet rule on its own")
    func quietRule() {
        #expect(SavedOrderMirrorGate.isQuiet(now: at(10), events: [nil, at(2)], quietPeriod: .seconds(5)))
        #expect(!SavedOrderMirrorGate.isQuiet(now: at(10), events: [at(2), at(8)], quietPeriod: .seconds(5)))
        #expect(SavedOrderMirrorGate.isQuiet(now: at(10), events: [], quietPeriod: .seconds(5)))
    }

    @Test("A revealed section holds the mirror, and the hold outlasts the reveal")
    func revealedSectionHoldsTheMirror() {
        let gate = SavedOrderMirrorGate(observesSystem: false)
        #expect(gate.allowsMirror(identifiers: items, restrictionChange: nil, now: at(0)))
        #expect(!gate.allowsMirror(identifiers: items, restrictionChange: nil, sectionRevealed: true, now: at(1)))
        #expect(!gate.allowsMirror(identifiers: items, restrictionChange: nil, sectionRevealed: true, now: at(20)))
        #expect(!gate.allowsMirror(identifiers: items, restrictionChange: nil, now: at(25)))
        #expect(gate.allowsMirror(identifiers: items, restrictionChange: nil, now: at(32.5)))
    }

    @Test("An item with a transient frame holds the mirror past the moment it settles")
    func transientFrameHoldsTheMirror() {
        let gate = SavedOrderMirrorGate(observesSystem: false)
        #expect(gate.allowsMirror(identifiers: items, restrictionChange: nil, now: at(0)))
        #expect(!gate.allowsMirror(identifiers: items, restrictionChange: nil, transientFrame: "a at x 0", now: at(1)))
        #expect(!gate.allowsMirror(identifiers: items, restrictionChange: nil, now: at(12.5)))
        #expect(gate.allowsMirror(identifiers: items, restrictionChange: nil, now: at(13.5)))
    }

    private static let displays = [
        CGRect(x: 0, y: 0, width: 1920, height: 1080),
        CGRect(x: 1920, y: -400, width: 1920, height: 1080),
    ]

    private static func item(x: CGFloat, y: CGFloat = 3.5, width: CGFloat = 24, onScreen: Bool = true, windowID: CGWindowID = 1) -> MenuBarItem {
        MenuBarItem(
            tag: MenuBarItemTag(namespace: .string("com.example.app\(windowID)"), title: "Item-0", instanceIndex: 0),
            windowID: windowID,
            ownerPID: pid_t(windowID),
            sourcePID: pid_t(windowID),
            bounds: CGRect(x: x, y: y, width: width, height: 24),
            title: "Item-0",
            isOnScreen: onScreen
        )
    }

    @Test("Frames on a bar, on a higher display's bar, or parked are settled")
    func settledFrames() {
        let items = [
            Self.item(x: 1700, windowID: 1),
            Self.item(x: 3500, y: -396.5, windowID: 2),
            Self.item(x: -1, windowID: 3),
            Self.item(x: 7, y: 1068, windowID: 4),
            Self.item(x: 0, width: 0, windowID: 5),
            Self.item(x: 0, onScreen: false, windowID: 6),
        ]
        #expect(SavedOrderMirrorGate.transientFrame(among: items, displays: Self.displays) == nil)
    }

    @Test("A frame at x == 0 is transient")
    func zeroXIsTransient() throws {
        let found = try #require(SavedOrderMirrorGate.transientFrame(among: [Self.item(x: 1700), Self.item(x: 0, windowID: 2)], displays: Self.displays))
        #expect(found.contains("com.example.app2"))
    }

    @Test("A frame above its display's bar is transient")
    func aboveTheBarIsTransient() {
        #expect(SavedOrderMirrorGate.transientFrame(among: [Self.item(x: 1700, y: -30)], displays: Self.displays) != nil)
        #expect(SavedOrderMirrorGate.transientFrame(among: [Self.item(x: 3500, y: -430)], displays: Self.displays) != nil)
    }

    @Test("A frame over no display is transient")
    func offEveryDisplayIsTransient() {
        #expect(SavedOrderMirrorGate.transientFrame(among: [Self.item(x: 5000)], displays: Self.displays) != nil)
    }

    @Test("With no displays known nothing can be judged")
    func noDisplays() {
        #expect(SavedOrderMirrorGate.transientFrame(among: [Self.item(x: 0)], displays: []) == nil)
    }
}
