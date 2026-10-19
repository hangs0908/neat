//
//  NeatPolicy.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Foundation

nonisolated enum NeatPolicy {
    static let newItemsSection = "visible"
    static let useSeparateBar = true
    static let autoRehide = false
    static let rehideInterval: TimeInterval = 5

    static func profilesDirectory(in applicationSupport: URL) -> URL {
        applicationSupport.appendingPathComponent("Neat/Profiles", isDirectory: true)
    }

    static func shouldEnableLogin(hasInitialized: Bool, systemEnabled: Bool) -> Bool {
        !hasInitialized && !systemEnabled
    }
}

nonisolated struct NeatIdleTimer {
    private var lastInteraction: TimeInterval

    init(now: TimeInterval) {
        lastInteraction = now
    }

    mutating func shouldHide(now: TimeInterval, isInteracting: Bool) -> Bool {
        if isInteracting {
            lastInteraction = now
            return false
        }
        return now - lastInteraction >= NeatPolicy.rehideInterval
    }
}
