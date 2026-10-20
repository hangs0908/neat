//
//  ThawBarCommandDragTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import AppKit
import MenuBarModel
import Testing
@testable import Thaw

@MainActor
struct ThawBarCommandDragTests {
    private let control = CGRect(x: 200, y: 0, width: 24, height: 24)
    private let items = [CGRect(x: 200, y: 0, width: 24, height: 24), CGRect(x: 250, y: 0, width: 24, height: 24)]

    @Test("Neat 오른쪽의 드롭 위치에 아이콘을 삽입한다")
    func insertionMatchesDropPosition() {
        #expect(ThawBarCommandDrag.visibleInsertionIndex(at: CGPoint(x: 230, y: 12), control: control, items: items, screenMaxX: 400) == 1)
        #expect(ThawBarCommandDrag.visibleInsertionIndex(at: CGPoint(x: 280, y: 12), control: control, items: items, screenMaxX: 400) == 2)
    }

    @Test("히든바 안이나 Neat 왼쪽에 놓으면 꺼내지 않는다", arguments: [
        CGPoint(x: 230, y: 50), CGPoint(x: 190, y: 12), CGPoint(x: 210, y: 12), CGPoint(x: 410, y: 12),
    ])
    func invalidVisibleDropIsIgnored(point: CGPoint) {
        #expect(ThawBarCommandDrag.visibleInsertionIndex(at: point, control: control, items: items, screenMaxX: 400) == nil)
    }

    @Test("Neat 왼쪽으로 이동한 항목만 숨긴다")
    func hiddenDropRequiresActualMove() {
        let left = CGRect(x: 170, y: 0, width: 24, height: 24)
        let right = CGRect(x: 230, y: 0, width: 24, height: 24)
        #expect(ThawBarCommandDrag.isHiddenDrop(item: left, control: control, point: CGPoint(x: 180, y: 12)))
        #expect(!ThawBarCommandDrag.isHiddenDrop(item: right, control: control, point: CGPoint(x: 180, y: 12)))
        #expect(!ThawBarCommandDrag.isHiddenDrop(item: left, control: control, point: CGPoint(x: 280, y: 12)))
        #expect(!ThawBarCommandDrag.isHiddenDrop(item: left, control: control, point: CGPoint(x: 210, y: 12)))
        #expect(!ThawBarCommandDrag.isHiddenDrop(item: left, control: control, point: CGPoint(x: 180, y: 50)))
        #expect(!ThawBarCommandDrag.isHiddenDrop(item: left, control: .zero, point: CGPoint(x: 180, y: 12)))
    }

    @Test("Cmd 클릭만으로 원래 앱 메뉴를 열지 않는다")
    func commandPressDoesNotClickItem() throws {
        let item = MenuBarItem(
            tag: MenuBarItemTag(namespace: .string("com.example.test"), title: "test", instanceIndex: 0),
            windowID: 1, ownerPID: 1, sourcePID: 1,
            bounds: control, title: "test", isOnScreen: true
        )
        var clicks = 0
        let view = ThawBarItemClickView.Represented(
            item: item, tooltipDelay: 1,
            leftClickAction: { clicks += 1 }, rightClickAction: {}, onHover: { _ in }
        )
        let down = try #require(NSEvent.mouseEvent(
            with: .leftMouseDown, location: .zero, modifierFlags: .command, timestamp: 0,
            windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        ))
        let up = try #require(NSEvent.mouseEvent(
            with: .leftMouseUp, location: .zero, modifierFlags: .command, timestamp: 0.1,
            windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 0
        ))
        view.mouseDown(with: down)
        view.mouseUp(with: up)
        #expect(clicks == 0)
    }

    @Test("시스템 드래그 없이 놓은 좌표로 한 번만 이동한다")
    func commandDragCommitsOnRelease() throws {
        let view = makeDragView()
        var drops: [CGPoint] = []
        view.commandDropAction = { drops.append($0) }
        view.mouseDown(with: try mouseEvent(.leftMouseDown))
        view.mouseDragged(with: try mouseEvent(.leftMouseDragged))
        #expect(drops.isEmpty)
        view.mouseUp(with: try mouseEvent(.leftMouseUp))
        view.mouseUp(with: try mouseEvent(.leftMouseUp))
        #expect(drops == [CGPoint(x: 20, y: 30)])
    }

    @Test("Escape 취소 후 계속 끌거나 놓아도 이동하거나 클릭하지 않는다")
    func cancelledCommandDragDoesNotCommit() throws {
        let view = makeDragView()
        var drops = 0
        var clicks = 0
        view.commandDropAction = { _ in drops += 1 }
        view.leftClickAction = { clicks += 1 }
        view.mouseDown(with: try mouseEvent(.leftMouseDown))
        view.mouseDragged(with: try mouseEvent(.leftMouseDragged))
        view.cancelOperation(nil)
        view.mouseDragged(with: try mouseEvent(.leftMouseDragged))
        view.mouseUp(with: try mouseEvent(.leftMouseUp))
        #expect(drops == 0)
        #expect(clicks == 0)
        // 취소 상태는 다음 제스처까지 남지 않는다.
        view.mouseDown(with: try mouseEvent(.leftMouseDown))
        view.mouseDragged(with: try mouseEvent(.leftMouseDragged))
        view.mouseUp(with: try mouseEvent(.leftMouseUp))
        #expect(drops == 1)
    }

    @Test("바가 먼저 닫혀 Escape를 소비해도 드래그를 취소한다")
    func closingBarCancelsCommandDrag() throws {
        let window = NSPanel(contentRect: CGRect(x: 100, y: 100, width: 60, height: 60), styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let view = makeDragView()
        window.contentView = view
        var drops = 0
        view.commandDropAction = { _ in drops += 1 }
        view.mouseDown(with: try mouseEvent(.leftMouseDown))
        view.mouseDragged(with: try mouseEvent(.leftMouseDragged))
        window.close()
        view.mouseUp(with: try mouseEvent(.leftMouseUp))
        #expect(drops == 0)
        window.contentView = nil
    }

    private func makeDragView() -> ThawBarItemClickView.Represented {
        let item = MenuBarItem(
            tag: MenuBarItemTag(namespace: .string("com.example.test"), title: "test", instanceIndex: 0),
            windowID: 1, ownerPID: 1, sourcePID: 1, bounds: control, title: "test", isOnScreen: true
        )
        let view = ThawBarItemClickView.Represented(item: item, tooltipDelay: 1, leftClickAction: {}, rightClickAction: {}, onHover: { _ in })
        return view
    }

    private func mouseEvent(_ type: NSEvent.EventType) throws -> NSEvent {
        try #require(NSEvent.mouseEvent(
            with: type, location: CGPoint(x: 20, y: 30), modifierFlags: .command, timestamp: 0,
            windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        ))
    }

}
