import Foundation
import Testing
@testable import Thaw

@MainActor
@Suite("프로필 파일 저장", .serialized)
struct ProfilePersistenceTests {
    @Test("이름을 바꾼 뒤 다시 읽어도 식별자와 설정 및 연결 정보가 유지된다")
    func renamePersistsWithoutChangingContent() throws {
        try withFixture { manager, directory, original in
            manager.activeProfileID = original.id
            let originalMetadata = try #require(manager.profiles.first)

            try manager.renameProfile(id: original.id, to: "변경된 이름")

            let reloaded = ProfileManager(profilesDirectory: directory)
            let renamed = try reloaded.loadProfile(id: original.id)
            let metadata = try #require(reloaded.profiles.first)
            #expect(reloaded.profiles.count == 1)
            #expect(renamed.name == "변경된 이름")
            #expect(renamed.id == original.id)
            #expect(renamed.createdAt == original.createdAt)
            #expect(renamed.modifiedAt > original.modifiedAt)
            #expect(try encoded(contentOf: renamed, using: original) == encoded(original))
            var expectedMetadata = originalMetadata
            expectedMetadata.name = renamed.name
            expectedMetadata.modifiedAt = renamed.modifiedAt
            #expect(metadata == expectedMetadata)
            #expect(try encoded(manager.profiles) == encoded(reloaded.profiles))
            #expect(manager.activeProfileID == original.id)
        }
    }

    @Test("복제본은 별도 식별자로 저장되고 원본 파일과 연결 정보를 바꾸지 않는다")
    func duplicatePersistsIndependentCopy() throws {
        try withFixture { manager, directory, original in
            manager.activeProfileID = original.id
            let originalMetadata = try #require(manager.profiles.first)
            let originalURL = directory.appendingPathComponent("\(original.id).json")
            let originalData = try Data(contentsOf: originalURL)

            try manager.duplicateProfile(id: original.id, newName: "복제본")

            let reloaded = ProfileManager(profilesDirectory: directory)
            #expect(reloaded.profiles.count == 2)
            let metadata = try #require(reloaded.profiles.first { $0.id != original.id })
            let duplicate = try reloaded.loadProfile(id: metadata.id)
            #expect(duplicate.id != original.id)
            #expect(duplicate.name == "복제본")
            #expect(metadata == duplicate.metadata)
            #expect(try encoded(contentOf: duplicate, using: original) == encoded(original))
            #expect(reloaded.profiles.first { $0.id == original.id } == originalMetadata)
            #expect(try Data(contentsOf: originalURL) == originalData)
            #expect(try encoded(manager.profiles) == encoded(reloaded.profiles))
            #expect(manager.activeProfileID == original.id)
        }
    }

    @Test("저장 내용을 교체하면 파일과 수정 시각이 갱신되고 연결 정보는 유지된다")
    func replacementPersistsWithoutApplyingProfile() throws {
        try withFixture { manager, directory, original in
            let activeID = UUID()
            manager.activeProfileID = activeID
            let originalMetadata = try #require(manager.profiles.first)
            var replacement = original
            replacement.generalSettings.showOnHover.toggle()
            replacement.hotkeys["추가 단축키"] = Data([4, 5, 6])
            replacement.modifiedAt = original.modifiedAt.addingTimeInterval(60)

            try manager.replaceProfile(replacement)

            let reloaded = ProfileManager(profilesDirectory: directory)
            #expect(try encoded(reloaded.loadProfile(id: original.id)) == encoded(replacement))
            var expectedMetadata = originalMetadata
            expectedMetadata.modifiedAt = replacement.modifiedAt
            #expect(reloaded.profiles == [expectedMetadata])
            #expect(manager.profiles == reloaded.profiles)
            #expect(manager.activeProfileID == activeID)
            #expect(manager.layoutTask == nil)
        }
    }

    @Test("저장할 수 없는 설정은 오류를 반환하고 기존 파일과 목록을 보존한다")
    func encodingFailurePreservesSavedProfile() throws {
        try withFixture { manager, directory, original in
            let profileURL = directory.appendingPathComponent("\(original.id).json")
            let manifestURL = directory.appendingPathComponent("profiles.json")
            let profileData = try Data(contentsOf: profileURL)
            let manifestData = try Data(contentsOf: manifestURL)
            let metadata = manager.profiles
            var replacement = original
            replacement.appearanceConfiguration.leftMargin = .infinity

            #expect(throws: EncodingError.self) {
                try manager.replaceProfile(replacement)
            }

            #expect(try Data(contentsOf: profileURL) == profileData)
            #expect(try Data(contentsOf: manifestURL) == manifestData)
            #expect(manager.profiles == metadata)
            let reloaded = ProfileManager(profilesDirectory: directory)
            #expect(try encoded(reloaded.loadProfile(id: original.id)) == encoded(original))
            #expect(reloaded.profiles == metadata)
        }
    }

    @Test("없거나 손상된 프로필의 이름 변경과 복제는 저장 목록을 변경하지 않는다", arguments: [true, false], [true, false])
    func invalidSourcePreservesManifest(rename: Bool, corrupt: Bool) throws {
        try withFixture { manager, directory, original in
            let profileURL = directory.appendingPathComponent("\(original.id).json")
            let manifestURL = directory.appendingPathComponent("profiles.json")
            let manifestData = try Data(contentsOf: manifestURL)
            let metadata = manager.profiles
            manager.activeProfileID = original.id
            if corrupt {
                try Data("손상된 프로필".utf8).write(to: profileURL)
            } else {
                try FileManager.default.removeItem(at: profileURL)
            }
            let filesBefore = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()

            #expect(throws: (any Error).self) {
                if rename {
                    try manager.renameProfile(id: original.id, to: "변경 시도")
                } else {
                    try manager.duplicateProfile(id: original.id, newName: "복제 시도")
                }
            }

            #expect(try Data(contentsOf: manifestURL) == manifestData)
            #expect(manager.profiles == metadata)
            #expect(manager.activeProfileID == original.id)
            #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted() == filesBefore)
            #expect(ProfileManager(profilesDirectory: directory).profiles == metadata)
            if corrupt {
                #expect(try Data(contentsOf: profileURL) == Data("손상된 프로필".utf8))
            }
        }
    }

    private func withFixture(_ body: (ProfileManager, URL, Profile) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NeatProfilePersistenceTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                Issue.record("테스트 프로필 폴더 정리 실패: \(error)")
            }
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var original = try decoder.decode(Profile.self, from: Data("{\"name\":\"원본\"}".utf8))
        original.createdAt = Date(timeIntervalSince1970: 1_600_000_000)
        original.modifiedAt = original.createdAt
        original.generalSettings.showOnHover.toggle()
        original.advancedSettings.showMenuBarTooltips.toggle()
        original.hotkeys = ["단축키": Data([1, 2, 3])]
        original.displayConfigurations = ["TEST-DISPLAY": .defaultConfiguration.withItemSpacingOffset(7)]
        original.globalDisplayConfiguration = .defaultConfiguration.withGridColumns(7)
        original.confirmSpacingRelaunch.toggle()
        original.unconfirmedSpacingProfileScope = .allProfiles
        original.spacingApplyMode = .writeOnly
        original.appearanceConfiguration.leftMargin = 13
        original.menuBarLayout.savedSectionOrder = ["hidden": ["test.item"]]
        original.menuBarLayout.pinnedHiddenBundleIDs = ["test.hidden"]
        original.menuBarLayout.pinnedAlwaysHiddenBundleIDs = ["test.alwaysHidden"]
        original.menuBarLayout.customNames = ["test.item": "테스트 항목"]
        original.menuBarLayout.itemSectionMap = ["test.item": "hidden"]
        original.menuBarLayout.itemOrder = ["hidden": ["test.item"]]
        original.menuBarLayout.newItemsPlacement = .init(
            sectionKey: "hidden", anchorIdentifier: "test.item", relation: .rightOfAnchor
        )
        original.menuBarLayout.itemHotkeys = ["test.item": Data([7, 8, 9])]
        original.menuBarLayout.itemGroups = .init(
            groups: [.init(name: "테스트 그룹", memberIdentifiers: ["test.item", "test.other"], isCollapsed: true)],
            suppressedAutomaticNamespaces: ["test.suppressed"]
        )
        original.automation = ProfileAutomation(
            preHook: HookScript(path: "/test-only/pre.sh", timeoutSeconds: 12, isEnabled: false),
            postHook: HookScript(path: "/test-only/post.scpt", timeoutSeconds: 3, isEnabled: false)
        )
        var metadata = original.metadata
        metadata.associatedDisplayUUID = "TEST-DISPLAY"
        metadata.associatedDisplayName = "테스트 화면"
        metadata.associatedSpaceKey = "TEST-SPACE"
        metadata.associatedSpaceName = "테스트 공간"
        try encoded(original).write(to: directory.appendingPathComponent("\(original.id).json"))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode([metadata]).write(to: directory.appendingPathComponent("profiles.json"))
        try body(ProfileManager(profilesDirectory: directory), directory, original)
    }

    private func encoded(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    private func encoded(contentOf profile: Profile, using original: Profile) throws -> Data {
        try encoded(Profile(
            id: original.id,
            name: original.name,
            createdAt: original.createdAt,
            modifiedAt: original.modifiedAt,
            content: profile.content
        ))
    }
}
