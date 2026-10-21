//
//  AutomaticUpdatesTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI
import Testing
@testable import Thaw

/// 자동 확인과 수동 확인만 제공하고 자동 다운로드를 차단한다.
@MainActor
@Suite("Automatic updates choice")
struct AutomaticUpdatesTests {
    @Test("Neat은 자동 다운로드 선택을 제공하지 않는다")
    func onlyOffersManualOrCheck() {
        #expect(AutomaticUpdates.allCases == [.off, .check])
    }

    @Test("과거 자동 다운로드 설정도 확인 전용으로 읽는다")
    func legacyDownloadPreferenceChecksOnly() {
        #expect(AutomaticUpdates(checks: true, downloads: true) == .check)
    }

    @Test("Neat은 단일 공개 채널만 사용한다")
    func onlyOffersPublicChannel() {
        #expect(UpdateChannel.selectable == [.stable])
        #expect(UpdateChannel.stable.allowedSparkleChannels.isEmpty)
    }

    @Test("Not checking reads as off, whatever the download switch says", arguments: [false, true])
    func notCheckingIsOff(downloads: Bool) {
        #expect(AutomaticUpdates(checks: false, downloads: downloads) == .off)
    }

    @Test("Checking without downloading is check only")
    func checkingOnly() {
        #expect(AutomaticUpdates(checks: true, downloads: false) == .check)
    }

    @Test("다운로드 설정이 남아 있어도 확인 전용이다")
    func checkingAndDownloading() {
        #expect(AutomaticUpdates(checks: true, downloads: true) == .check)
    }

    @Test("Each choice sets both switches", arguments: [
        (AutomaticUpdates.off, false, false),
        (AutomaticUpdates.check, true, false),
    ])
    func choiceSetsBothSwitches(mode: AutomaticUpdates, checks: Bool, downloads: Bool) {
        #expect(mode.checks == checks)
        #expect(mode.downloads == downloads)
    }

    @Test("Each choice has its own label in the picker", arguments: [
        (AutomaticUpdates.off, "Off"),
        (AutomaticUpdates.check, "Check only"),
    ])
    func choiceHasItsOwnLabel(mode: AutomaticUpdates, label: String) {
        #expect(mode.localized == LocalizedStringKey(label))
    }

    @Test("Picking a choice writes both switches and reads back", arguments: AutomaticUpdates.allCases)
    func pickingWritesBothSwitches(mode: AutomaticUpdates) {
        let switches = FakeSwitches()
        switches.automaticUpdates = mode
        #expect(switches.automaticallyChecksForUpdates == mode.checks)
        #expect(switches.automaticallyDownloadsUpdates == mode.downloads)
        #expect(switches.automaticUpdates == mode)
    }

    @Test("The picker can tell the choices apart")
    func choicesAreDistinctRows() {
        #expect(Set(AutomaticUpdates.allCases.map(\.id)).count == AutomaticUpdates.allCases.count)
    }
}

@MainActor
private final class FakeSwitches: AutomaticUpdateSwitches {
    var automaticallyChecksForUpdates = false
    var automaticallyDownloadsUpdates = true
}
