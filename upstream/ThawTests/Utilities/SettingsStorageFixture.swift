import Foundation
import Testing
@testable import Thaw

@MainActor
enum SettingsStorageFixture {
    /// 전역 저장소 교체 중 다른 테스트가 끼어들지 않도록 본문은 동기 실행한다.
    static func run(_ body: (UserDefaults, String) throws -> Void) throws {
        let name = "NeatSettingsStorageTests.\(UUID().uuidString)"
        let store = try #require(UserDefaults(suiteName: name))
        let previousStore = Defaults.store
        let previousCenter = SettingsURIHandler.settingsChangeNotificationCenter
        Defaults.store = store
        SettingsURIHandler.settingsChangeNotificationCenter = NotificationCenter()
        defer {
            SettingsURIHandler.settingsChangeNotificationCenter = previousCenter
            Defaults.store = previousStore
            ScratchDefaults.remove(name)
            #expect(!FileManager.default.fileExists(atPath: URL.libraryDirectory.appending(path: "Preferences/\(name).plist").path))
        }
        try Defaults.set(JSONEncoder().encode([String: DisplayThawBarConfiguration]()), forKey: .displayThawBarConfigurations)
        try body(store, name)
    }
}
