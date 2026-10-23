import Foundation
import Testing
@testable import Thaw

extension ProfilePersistenceTests {
    @Test("삭제 후 재로딩하면 파일과 목록에서 제거되고 다른 프로필은 유지된다")
    func deletePersistsWithoutTouchingPeers() throws {
        try withPeers { manager, directory, original in
            let peer = try #require(manager.profiles.last)
            let peerURL = directory.appendingPathComponent("\(peer.id).json")
            let peerData = try Data(contentsOf: peerURL)
            manager.activeProfileID = peer.id

            try manager.deleteProfile(id: original.id)

            let reloaded = ProfileManager(profilesDirectory: directory)
            #expect(reloaded.profiles.map(\.name) == ["두번째", "세번째"])
            #expect(manager.profiles == reloaded.profiles)
            #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("\(original.id).json").path))
            #expect(try Data(contentsOf: peerURL) == peerData)
            #expect(manager.activeProfileID == peer.id)
            #expect(manager.layoutTask == nil)
        }
    }

    @Test("복원은 위치를 범위 안으로 제한하고 원래 내용과 활성 상태를 보존한다", arguments: [-1, 1, 99], [false, true])
    func restorePreservesIdentityAndPosition(index: Int, wasActive: Bool) throws {
        try withPeers { manager, directory, original in
            let metadata = try #require(manager.profiles.first)
            let activeID = try #require(manager.profiles.last?.id)
            manager.activeProfileID = activeID
            try manager.deleteProfile(id: original.id)

            try manager.restoreProfile(original, metadata: metadata, at: index, wasActive: wasActive)

            let reloaded = ProfileManager(profilesDirectory: directory)
            let expectedNames = index < 0 ? ["원본", "두번째", "세번째"] :
                (index == 1 ? ["두번째", "원본", "세번째"] : ["두번째", "세번째", "원본"])
            #expect(reloaded.profiles.map(\.name) == expectedNames)
            #expect(reloaded.profiles.first { $0.id == original.id } == metadata)
            #expect(try encoded(reloaded.loadProfile(id: original.id)) == encoded(original))
            #expect(manager.profiles == reloaded.profiles)
            #expect(manager.activeProfileID == (wasActive ? original.id : activeID))
            #expect(manager.layoutTask == nil)
        }
    }

    @Test("재복원은 중복 없이 연결 소유권을 되찾고 경쟁 프로필의 이름 캐시도 비운다")
    func restoreReclaimsAssociationsWithoutDuplicates() throws {
        try withPeers { manager, directory, original in
            let metadata = try #require(manager.profiles.first)
            let peerID = manager.profiles[1].id
            let untouched = manager.profiles[2]
            try manager.deleteProfile(id: original.id)
            manager.setAssociatedDisplay(uuid: "TEST-DISPLAY", displayName: "임시 화면", forProfileID: peerID)
            manager.setAssociatedSpace(key: "TEST-SPACE", spaceName: "임시 공간", forProfileID: peerID)

            try manager.restoreProfile(original, metadata: metadata, at: 1, wasActive: false)
            try manager.restoreProfile(original, metadata: metadata, at: 0, wasActive: false)

            let reloaded = ProfileManager(profilesDirectory: directory)
            #expect(reloaded.profiles.map(\.name) == ["두번째", "원본", "세번째"])
            let peer = try #require(reloaded.profiles.first { $0.id == peerID })
            #expect(peer.associatedDisplayUUID == nil)
            #expect(peer.associatedDisplayName == nil)
            #expect(peer.associatedSpaceKey == nil)
            #expect(peer.associatedSpaceName == nil)
            #expect(reloaded.profiles.filter { $0.id == original.id } == [metadata])
            #expect(reloaded.profiles.last == untouched)
            #expect(manager.profiles == reloaded.profiles)
        }
    }

    @Test("파일 내보내기와 새 저장소 가져오기는 모든 설정을 보존하고 외부 훅만 비활성화한다")
    func importRoundTripsRichContentWithoutApprovingHooks() throws {
        try withFixture { manager, directory, original in
            var exported = original
            exported.automation?.preHook?.isEnabled = true
            exported.automation?.postHook?.isEnabled = true
            try manager.replaceProfile(exported)
            let file = directory.appendingPathComponent("export.json")
            try manager.exportProfile(id: original.id, to: file)
            let destination = directory.appendingPathComponent("imported", isDirectory: true)
            let importer = ProfileManager(profilesDirectory: destination)

            try importer.importProfile(from: file)

            let reloaded = ProfileManager(profilesDirectory: destination)
            #expect(reloaded.profiles.count == 1)
            let metadata = try #require(reloaded.profiles.first)
            let imported = try reloaded.loadProfile(id: metadata.id)
            #expect(imported.id != original.id)
            #expect(imported.name == original.name)
            #expect(try encoded(contentOf: imported, using: original) == encoded(original))
            #expect(metadata.associatedDisplayUUID == "TEST-DISPLAY")
            #expect(metadata.associatedDisplayName == "테스트 화면")
            #expect(metadata.associatedSpaceKey == "TEST-SPACE")
            #expect(metadata.associatedSpaceName == "테스트 공간")
            #expect(try encoded(importer.profiles) == encoded(reloaded.profiles))
            #expect(importer.activeProfileID == nil)
            #expect(importer.layoutTask == nil)
            #expect(try encoded(manager.loadProfile(id: original.id)) == encoded(exported))
        }
    }

    @Test("손상되거나 없는 가져오기 파일은 기존 파일과 목록을 변경하지 않는다", arguments: [false, true])
    func failedImportPreservesStore(missing: Bool) throws {
        try withFixture { manager, directory, original in
            let file = directory.appendingPathComponent("invalid.json")
            if !missing {
                try Data("{invalid".utf8).write(to: file)
            }
            let before = try storeContents(directory)
            let metadata = manager.profiles

            #expect(throws: (any Error).self) { try manager.importProfile(from: file) }

            #expect(try storeContents(directory) == before)
            #expect(manager.profiles == metadata)
            #expect(ProfileManager(profilesDirectory: directory).profiles == metadata)
            #expect(try encoded(manager.loadProfile(id: original.id)) == encoded(original))
        }
    }

    @Test("원본 파일이 없는 내보내기는 기존 출력 파일을 덮어쓰지 않는다")
    func failedExportPreservesDestination() throws {
        try withFixture { manager, directory, original in
            let file = directory.appendingPathComponent("export.json")
            try Data("기존 출력".utf8).write(to: file)
            try FileManager.default.removeItem(at: directory.appendingPathComponent("\(original.id).json"))
            let before = try storeContents(directory)
            let metadata = manager.profiles

            #expect(throws: (any Error).self) { try manager.exportProfile(id: original.id, to: file) }

            #expect(try storeContents(directory) == before)
            #expect(manager.profiles == metadata)
        }
    }

    private func withPeers(_ body: (ProfileManager, URL, Profile) throws -> Void) throws {
        try withFixture { manager, directory, original in
            var metadata = manager.profiles
            for name in ["두번째", "세번째"] {
                let peer = Profile(name: name, content: original.content)
                try encoded(peer).write(to: directory.appendingPathComponent("\(peer.id).json"))
                metadata.append(peer.metadata)
            }
            try encoded(metadata).write(to: directory.appendingPathComponent("profiles.json"))
            try body(ProfileManager(profilesDirectory: directory), directory, original)
        }
    }

    private func storeContents(_ directory: URL) throws -> [String: Data] {
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        return try Dictionary(uniqueKeysWithValues: files.map {
            try ($0, Data(contentsOf: directory.appendingPathComponent($0)))
        })
    }
}
