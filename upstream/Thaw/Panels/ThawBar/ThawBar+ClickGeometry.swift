//
//  ThawBar+ClickGeometry.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit

extension ThawBarPanel {
    /// The live status window can move displays before the AX cache catches up.
    /// Consuming that icon's mouse-down would close the panel before its action toggles it open again.
    static nonisolated func isControlItemClick(
        appKitLocation: CGPoint,
        liveControlItemFrame: CGRect?,
        quartzLocation: CGPoint?,
        cachedControlItemFrame: CGRect?
    ) -> Bool {
        if let liveControlItemFrame, liveControlItemFrame.contains(appKitLocation) {
            return true
        }
        if let quartzLocation, let cachedControlItemFrame {
            return cachedControlItemFrame.contains(quartzLocation)
        }
        return false
    }
}
