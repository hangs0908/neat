//
//  PermissionsWindow.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

/// Resolve the stage once per opening in onAppear; init cannot read the environment and would retain launch-time state.
/// Holding it in state prevents the "seen" write from switching to recovery before dismissal.
private struct PermissionsFlowView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Neat을 시작합니다")
                .font(.largeTitle.weight(.semibold))
            Text("아이콘을 정리하려면 손쉬운 사용 권한이 필요합니다. 화면 캡처를 허용하면 실제 메뉴 막대 아이콘을 표시할 수 있습니다.")
                .foregroundStyle(.secondary)
            Text("macOS 27에서는 메뉴 막대 배치 파일 접근도 필요합니다. 접근 요청에서 안내하는 파일 하나를 선택해 주세요.")
                .font(.callout)
                .foregroundStyle(.secondary)
            ForEach(appState.permissions.allPermissions.filter { $0 !== appState.permissions.controlCenterAppList }) { permission in
                HStack {
                    PermissionLabel(permission: permission)
                    Spacer()
                    PermissionStatusControl(permission: permission)
                }
            }
            Spacer(minLength: 0)
            HStack {
                Button("종료") { ApplicationTermination.request() }
                Spacer()
                Button("Neat 시작") {
                    Defaults.set(true, forKey: .hasSeenOnboarding)
                    Defaults.set(Constants.currentOnboardingVersion, forKey: .onboardingVersion)
                    appState.completeFirstLaunchSetup()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(appState.permissions.permissionsState == .missing)
            }
        }
        .padding(32)
        .frame(minWidth: 620, minHeight: 440)
        .onAppear {
            appState.permissions.refreshPermissionsState()
        }
    }
}

/// The window that hosts onboarding and the access recovery screen.
struct PermissionsWindow: Scene {
    let appState: AppState

    var body: some Scene {
        ThawWindow(id: .permissions, appState: appState) {
            PermissionsFlowView()
                .onWindowChange { window in
                    guard let window else {
                        return
                    }
                    // Closing without required grants would strand the app because even its control item is absent.
                    window.standardWindowButton(.closeButton)?.isHidden =
                        appState.permissions.permissionsState == .missing
                    window.standardWindowButton(.zoomButton)?.isHidden = true
                    if let contentView = window.contentView {
                        withMutableCopy(of: contentView.safeAreaInsets) { insets in
                            insets.bottom = -insets.bottom
                            insets.left = -insets.left
                            insets.right = -insets.right
                            insets.top = -insets.top
                            contentView.additionalSafeAreaInsets = insets
                        }
                    }
                }
        }
        // contentMinSize allows resizing beyond the ideal when Larger Text exceeds a step's budget.
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .environment(appState)
        .environment(appState.permissions)
    }
}
