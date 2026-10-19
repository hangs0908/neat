import Foundation
import Testing
@testable import NeatPolicy

struct NeatPolicyTests {
    @Test("기존 Thaw 프로필 저장소를 사용하지 않는다")
    func profilesHaveIndependentStorage() {
        let support = URL(fileURLWithPath: "/tmp/Application Support", isDirectory: true)
        let directory = NeatPolicy.profilesDirectory(in: support)
        #expect(directory.path == "/tmp/Application Support/Neat/Profiles")
    }

    @Test("처음 발견한 항목과 새 화면에 제품 기본값을 적용한다")
    func defaultsMatchProduct() {
        #expect(NeatPolicy.newItemsSection == "visible")
        #expect(NeatPolicy.useSeparateBar)
        #expect(!NeatPolicy.autoRehide)
        #expect(NeatPolicy.rehideInterval == 5)
    }

    @Test("마지막 조작 이후 연속 5초가 지나야 숨긴다")
    func idleDeadline() {
        var timer = NeatIdleTimer(now: 100)
        let beforeDeadline = timer.shouldHide(now: 104.99, isInteracting: false)
        let atDeadline = timer.shouldHide(now: 105, isInteracting: false)
        #expect(!beforeDeadline)
        #expect(atDeadline)
    }

    @Test("바와 메뉴를 조작하는 동안 시간을 초기화한다")
    func interactionRestartsDeadline() {
        var timer = NeatIdleTimer(now: 0)
        let results = [
            timer.shouldHide(now: 20, isInteracting: true),
            timer.shouldHide(now: 24.99, isInteracting: false),
            timer.shouldHide(now: 25, isInteracting: true),
            timer.shouldHide(now: 29.99, isInteracting: false),
            timer.shouldHide(now: 30, isInteracting: false),
        ]
        #expect(results == [false, false, false, false, true])
    }

    @Test("첫 실행에서만 로그인 시 실행을 초기화한다")
    func loginInitialization() {
        #expect(NeatPolicy.shouldEnableLogin(hasInitialized: false, systemEnabled: false))
        #expect(!NeatPolicy.shouldEnableLogin(hasInitialized: true, systemEnabled: false))
        #expect(!NeatPolicy.shouldEnableLogin(hasInitialized: false, systemEnabled: true))
        #expect(!NeatPolicy.shouldEnableLogin(hasInitialized: true, systemEnabled: true))
    }
}
