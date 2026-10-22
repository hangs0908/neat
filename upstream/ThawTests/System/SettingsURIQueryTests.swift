import Foundation
import Testing
@testable import Thaw

extension SettingsURIResponseSuites {
    @MainActor
    @Suite("설정 URI 입력과 조회")
    struct SettingsURIQueryTests {
        private let displayUUID = "11111111-1111-1111-1111-111111111111"

        @Test("조회 응답은 저장된 값과 자료형 및 요청 식별자를 전달한다", arguments: [
            "showOnHover", "rehideInterval", "rehideStrategy", "useThawBar", "useIceBar",
            "gridColumns", "thawBarLocation", "thawBarLayout", "alwaysShowHiddenItems",
        ])
        func queryReturnsStoredValue(key: String) async throws {
            let capture = URIDeliveryCapture()
            try await capture.run {
                try SettingsStorageFixture.run { _, _ in
                    Defaults.set(true, forKey: .showOnHover)
                    Defaults.set(22.0, forKey: .rehideInterval)
                    Defaults.set(RehideStrategy.timed.rawValue, forKey: .rehideStrategy)
                    let configuration = DisplayThawBarConfiguration.defaultConfiguration
                        .withUseThawBar(false).withGridColumns(7).withAlwaysShowHiddenItems(true)
                        .withThawBarLocation(.mousePointer).withThawBarLayout(.grid)
                    try Defaults.set(JSONEncoder().encode([displayUUID: configuration]), forKey: .displayThawBarConfigurations)
                    try Defaults.set(JSONEncoder().encode(DisplayThawBarConfiguration.defaultConfiguration), forKey: .globalDisplayConfiguration)

                    #expect(SettingsURIHandler.handleGet(
                        key: key, displayUUID: displayUUID, callback: "neat-test://response", broadcast: false, requestId: "query-1"
                    ))

                    #expect(capture.openedURLs.count == 1)
                    #expect(capture.broadcasts.isEmpty)
                    let response = try capture.callbackResponse()
                    let canonicalKey = key == "useIceBar" ? "useThawBar" : key
                    #expect(response["requestId"] as? String == "query-1")
                    #expect(response["status"] as? String == "success")
                    #expect(response["key"] as? String == canonicalKey)
                    var data = try #require(response["data"] as? [String: Any])
                    if canonicalKey == "thawBarLocation" {
                        // 목록 보완을 막지 않도록 요청한 위치의 매핑만 검증한다.
                        let values = try #require(data.removeValue(forKey: "validValues") as? [String: Int])
                        #expect(values["mousePointer"] == 1)
                    }
                    let expected: [String: Any] = switch canonicalKey {
                    case "showOnHover": ["value": true, "type": "boolean"]
                    case "rehideInterval": ["value": 22.0, "type": "double", "range": ["min": 1, "max": 300]]
                    case "rehideStrategy": ["value": "timed", "rawValue": 1, "type": "enum", "validValues": ["smart": 0, "timed": 1, "focusedApp": 2]]
                    case "useThawBar": ["value": false, "type": "boolean"]
                    case "alwaysShowHiddenItems": ["value": true, "type": "boolean"]
                    case "gridColumns": ["value": 7, "type": "integer", "range": ["min": 2, "max": 10]]
                    case "thawBarLocation": ["value": "mousePointer", "rawValue": 1, "type": "enum"]
                    case "thawBarLayout": ["value": "grid", "rawValue": 2, "type": "enum", "validValues": ["horizontal": 0, "vertical": 1, "grid": 2]]
                    default: [:]
                    }
                    #expect(NSDictionary(dictionary: data) == NSDictionary(dictionary: expected))
                }
            }
        }

        @Test("잘못된 조회 요청은 요청 식별자가 포함된 오류 응답을 반환한다", arguments: [nil, "notASetting", "display"] as [String?])
        func invalidQueryReturnsError(key: String?) async throws {
            let capture = URIDeliveryCapture()
            try await capture.run {
                try SettingsStorageFixture.run { _, _ in
                    #expect(SettingsURIHandler.handleGet(
                        key: key, displayUUID: nil, callback: "neat-test://response", broadcast: false, requestId: "invalid-1"
                    ))
                    let response = try capture.callbackResponse()
                    #expect(response["requestId"] as? String == "invalid-1")
                    #expect(response["status"] as? String == "error")
                    #expect(response["error"] as? String != nil)
                    #expect(response["data"] == nil)
                    #expect(capture.openedURLs.count == 1)
                }
            }
        }

        @Test("공개 알림에는 설정값을 보내지 않고 응답 수단이 없으면 조회를 거절한다")
        func broadcastDoesNotExposeSettings() async throws {
            let capture = URIDeliveryCapture()
            try await capture.run {
                try SettingsStorageFixture.run { _, _ in
                    Defaults.set(true, forKey: .showOnHover)
                    #expect(!SettingsURIHandler.handleGet(key: "showOnHover", displayUUID: nil, callback: nil, broadcast: false, requestId: "none"))
                    #expect(capture.broadcasts.isEmpty)
                    #expect(capture.openedURLs.isEmpty)
                    #expect(SettingsURIHandler.handleGet(key: "showOnHover", displayUUID: nil, callback: nil, broadcast: true, requestId: "ack-1"))
                    let response = try capture.broadcastResponse()
                    #expect(Set(response.keys) == ["requestId", "status", "message"])
                    #expect(response["requestId"] as? String == "ack-1")
                    #expect(response["status"] as? String == "ack")
                    #expect(capture.broadcasts.count == 1)
                    #expect(capture.openedURLs.isEmpty)
                }
            }
        }

        @Test("잘못된 값은 저장소 변경 없이 거절한다", arguments: [
            ("showOnHover", "maybe"), ("rehideStrategy", "invalid"), ("useThawBar", "maybe"),
            ("thawBarLayout", "diagonal"), ("thawBarLocation", "somewhere"), ("gridColumns", "3.5"),
        ])
        func invalidValueDoesNotWrite(key: String, value: String) throws {
            try SettingsStorageFixture.run { store, name in
                let before = store.persistentDomain(forName: name) as NSDictionary?
                #expect(!SettingsURIHandler.handleSet(key: key, value: value, sender: nil))
                #expect(store.persistentDomain(forName: name) as NSDictionary? == before)
            }
        }
    }
}
