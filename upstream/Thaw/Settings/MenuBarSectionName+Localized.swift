//
//  MenuBarSectionName+Localized.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import MenuBarModel
import SwiftUI

nonisolated extension MenuBarSectionName {
    var localized: LocalizedStringKey {
        switch self {
        case .visible: LocalizedStringKey("보임")
        case .hidden: LocalizedStringKey("숨김")
        case .alwaysHidden: LocalizedStringKey("항상 숨김")
        }
    }
}
