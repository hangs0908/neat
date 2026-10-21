//
//  LayoutBarKeyboardTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit
import Testing
@testable import Thaw

@MainActor
@Suite(.serialized)
struct LayoutBarKeyboardTests {
    @Test
    func sectionOrderCanBeUndoneAndRedoneRepeatedly() throws {
        let world = LayoutEditorWorld()
        let items = [LayoutEditorWorld.item("First"), LayoutEditorWorld.item("Second")]
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        undoManager.beginUndoGrouping()
        LayoutBarKeyboard.applySectionOrder(
            items.reversed(),
            previousOrder: items,
            section: .visible,
            appState: world.appState,
            undoManager: undoManager,
            actionName: "순서 변경"
        )
        undoManager.endUndoGrouping()

        for _ in 0 ..< 3 {
            try #require(undoManager.canUndo)
            undoManager.undo()
            try #require(undoManager.canRedo)
            #expect(undoManager.redoActionName == "순서 변경")
            undoManager.redo()
        }
        #expect(undoManager.canUndo)
        undoManager.removeAllActions()
        #expect(!undoManager.canUndo)
        #expect(!undoManager.canRedo)
    }
}
