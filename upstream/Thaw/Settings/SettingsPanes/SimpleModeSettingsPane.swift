//
//  SimpleModeSettingsPane.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import MenuBarModel
import SwiftUI
import ThawCapture
import ThawUI

struct SimpleModeSettingsPane: View {
    @Environment(AppState.self) private var appState
    let itemManager: MenuBarItemManager
    @Bindable var settings: GeneralSettings

    var body: some View {
        ThawForm {
            ThawSection {
                VStack(alignment: .leading, spacing: 8) {
                    Text("필요한 아이콘만, 메뉴 막대에.")
                        .font(.title2.weight(.semibold))
                    Text("아이콘을 드래그해 보임과 숨김으로 나누세요. 새 아이콘은 보임에 추가됩니다.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                if appState.menuBarManager.isMenuBarHiddenBySystemUserDefaults {
                    Text("macOS 시스템 설정에서 메뉴 막대 자동 숨기기를 끄면 아이콘을 정리할 수 있습니다.")
                        .foregroundStyle(.secondary)
                } else {
                    FoldedMenuBar(itemManager: itemManager)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
                Text("Neat 아이콘 또는 메뉴 막대의 빈 공간을 클릭하면 숨긴 아이콘이 나타납니다. 바깥을 클릭하면 닫힙니다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ThawSection("동작") {
                Toggle("마지막 조작 이후 5초 뒤 자동으로 닫기", isOn: $settings.autoRehide)
                    .annotation("아이콘 바에 마우스를 올리거나 앱 메뉴를 사용하는 동안에는 닫히지 않습니다.")
                LaunchAtLoginRow()
            }
            ThawSection("권한") {
                ForEach(appState.permissions.allPermissions.filter { $0 !== appState.permissions.controlCenterAppList }) { permission in
                    HStack {
                        PermissionLabel(permission: permission)
                        Spacer()
                        PermissionStatusControl(permission: permission)
                    }
                }
            }
            HStack {
                Text("Neat · Thaw 기반 · GPL-3.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("오픈소스 고지") {
                    appState.openWindow(.acknowledgements)
                }
                .buttonStyle(.link)
            }
            .listRowBackground(Color.clear)
        }
    }
}
