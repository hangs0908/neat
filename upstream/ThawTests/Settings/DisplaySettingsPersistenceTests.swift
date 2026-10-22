import Foundation
import Testing
@testable import Thaw

@MainActor
@Suite("디스플레이 설정 저장", .serialized)
struct DisplaySettingsPersistenceTests {
    private let firstID = "11111111-1111-1111-1111-111111111111"
    private let secondID = "22222222-2222-2222-2222-222222222222"
    private let orphanID = "33333333-3333-3333-3333-333333333333"

    @Test("한 화면의 설정만 변경하고 다른 화면과 전역 템플릿은 보존한다")
    func updatePersistsOnlyTargetDisplay() throws {
        try SettingsStorageFixture.run { _, _ in
            let manager = DisplaySettingsManager()
            let first = DisplayThawBarConfiguration.defaultConfiguration.withUseThawBar(false).withItemSpacingOffset(3)
            let second = DisplayThawBarConfiguration.defaultConfiguration.withGridColumns(6)
            let global = DisplayThawBarConfiguration.defaultConfiguration.withItemSpacingOffset(9)
            manager.configurations = [firstID: first, secondID: second]
            manager.globalConfiguration = global

            manager.updateConfiguration(forDisplayUUID: firstID) { $0.withGridColumns(8) }

            let expected = [firstID: first.withGridColumns(8), secondID: second]
            #expect(manager.configurations == expected)
            let reloaded = DisplaySettingsManager()
            #expect(reloaded.configurations == expected)
            #expect(reloaded.globalConfiguration == global)
            #expect(reloaded.lastPersistenceFailure == nil)
        }
    }

    @Test("저장되지 않은 화면은 전역 템플릿을 사용하고 수정 시 해당 화면에만 저장한다")
    func newDisplayInheritsGlobalTemplate() throws {
        try SettingsStorageFixture.run { _, _ in
            let manager = DisplaySettingsManager()
            let global = DisplayThawBarConfiguration.defaultConfiguration.withUseThawBar(false).withGridColumns(9).withItemSpacingOffset(7)
            manager.globalConfiguration = global
            #expect(manager.configuration(forUUID: firstID) == global)
            #expect(DisplaySettingsManager.resolvedConfiguration(displayUUID: nil, configurations: [:], globalConfiguration: global) == global)

            manager.updateConfiguration(forDisplayUUID: firstID) { $0.withAlwaysShowHiddenItems(true) }

            let reloaded = DisplaySettingsManager()
            #expect(reloaded.configurations == [firstID: global.withAlwaysShowHiddenItems(true)])
            #expect(reloaded.configuration(forUUID: secondID) == global)
            #expect(reloaded.globalConfiguration == global)
        }
    }

    @Test("전체 적용은 연결이 끊긴 알려진 화면도 갱신하고 이름 없는 저장 데이터는 보존한다")
    func globalTemplateAppliesToKnownDisplays() throws {
        try SettingsStorageFixture.run { _, _ in
            let manager = DisplaySettingsManager()
            let original = DisplayThawBarConfiguration.defaultConfiguration.withGridColumns(3)
            let global = DisplayThawBarConfiguration.defaultConfiguration.withUseThawBar(false).withGridColumns(8).withItemSpacingOffset(6)
            manager.configurations = [firstID: original, secondID: original, orphanID: original]
            manager.knownDisplays = [firstID: KnownDisplay(name: "화면 A", hasNotch: true), secondID: KnownDisplay(name: "화면 B", hasNotch: false)]
            manager.globalConfiguration = global
            let expectedTargets = Set(manager.connectedDisplays().map(\.id)).union([firstID, secondID])

            let targets = manager.applyGlobalToAllKnownDisplays()

            #expect(Set(targets) == expectedTargets)
            #expect(targets.count == expectedTargets.count)
            let reloaded = DisplaySettingsManager()
            for target in expectedTargets {
                #expect(reloaded.configurations[target] == global)
            }
            #expect(reloaded.configurations.count == expectedTargets.count + 1)
            #expect(reloaded.configurations[orphanID] == original)
            #expect(reloaded.knownDisplays == manager.knownDisplays)
            #expect(reloaded.globalConfiguration == global)
        }
    }

    @Test("손상된 화면별 저장 데이터는 덮어쓰지 않고 정상 전역 템플릿으로 조회한다")
    func corruptConfigurationsKeepGlobalFallback() throws {
        try SettingsStorageFixture.run { _, _ in
            let corrupt = Data("손상된 설정".utf8)
            let global = DisplayThawBarConfiguration.defaultConfiguration.withGridColumns(9)
            Defaults.set(corrupt, forKey: .displayThawBarConfigurations)
            try Defaults.set(JSONEncoder().encode(global), forKey: .globalDisplayConfiguration)

            let manager = DisplaySettingsManager()

            #expect(manager.configurations.isEmpty)
            #expect(manager.configuration(forUUID: firstID) == global)
            #expect(Defaults.data(forKey: .displayThawBarConfigurations) == corrupt)
            #expect(manager.lastPersistenceFailure == nil)
        }
    }
}
