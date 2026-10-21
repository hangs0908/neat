//
//  UpdateConsentSheet.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

struct UpdateConsentSheet: View {
    var onEnable: () -> Void
    var onDisable: () -> Void

    @State private var isProcessing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("새 버전을 자동으로 확인할까요?")
                .font(.title2.bold())

            Text("Neat이 새 버전을 확인해 알려드립니다. 설치를 선택하기 전에는 다운로드하거나 앱을 재실행하지 않습니다. 설정에서 언제든 끄거나 수동으로 확인할 수 있습니다.")
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("수동으로 확인") {
                    guard !isProcessing else { return }
                    isProcessing = true
                    onDisable()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(isProcessing)
                .buttonStyle(.settingsGlass)
                Button("자동으로 확인") {
                    guard !isProcessing else { return }
                    isProcessing = true
                    onEnable()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isProcessing)
                .buttonStyle(.glassProminent)
            }
        }
        .padding(20)
        // A minimum, not a width: both buttons and the body copy are
        // translated, and several languages run past 380 with a hard frame.
        .frame(minWidth: 380)
    }
}
