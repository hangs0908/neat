# 드래그 정착 처리의 소유권 정리

## 범위

`MenuBarDragSettlement`가 정착 작업의 교체·취소, 마지막 드래그 종료 시각, 캐시 갱신→분류 채택→순서 기록 순서를 소유한다. 입력 처리는 `noteUserMenuBarDragEnded`에 종료 정보만 전달한다. 기존 실제 이동, 그룹 판정, 분류 채택, 부분 관찰 거부, 임시 표시 해제, 순서 저장 구현은 재사용한다.

시간과 동작은 유지한다. 각 드래그 종료의 500ms 빠른 갱신은 독립 실행하고, 교체 가능한 정착 작업은 1.5초 뒤 실행한다. 진행 중 드래그와 종료 후 4초 동안의 자동 이동 보호를 유지한다. 수동 모드 전환 관찰은 드래그 종료 시각을 갱신하지 않고 분류만 채택한다.

`refactor/drag-settlement`는 최신 `origin/main`의 `dd9eac5`에서 만들었다. main에 아직 없는 선행 드래그 커밋은 합쳤다. 원래 작업 트리의 미커밋 드래그 미리보기 변경 3개 파일을 검증 기준으로 복사했다. 최초 리팩터링 커밋에서는 제외했으나, 최종 PR에는 실제 검증한 소스와 일치하도록 독립 리뷰 후 별도 커밋으로 포함했다. 원래 작업 트리는 수정하지 않았다.

## 자동 검증

검증 환경: macOS 27.0.1, Xcode 27.

- 수정 전 기존 드래그·관찰·순서 테스트를 실행해 통과했다.
- 종료 진입점이 대기 중인 설정창 편집보다 사용자 이동을 우선해야 한다는 새 테스트는 수정 전 단언 실패를 확인했다. 컴파일 실패가 아니다. 근거: `build/verification/drag-settlement/neat-drag-settlement-red.log`.
- 수정 후 관련 네이티브 테스트 62개, 매개변수별 실행 80건 통과, 실패·건너뜀 0건. 새 테스트 6개는 빠른 갱신과 정착의 순서, 수동 관찰, 연속 드래그 교체, 캐시 대기 중 취소, 4초 보호, 종료 진입점의 외부 이동 기록을 확인한다.
- 네이티브 결과: `/Users/hangjin/Desktop/neat/build/DerivedData/Logs/Test/Test-Thaw-2026.10.21_00-30-11-+0900.xcresult`. 요약과 로그는 `build/verification/drag-settlement/`에 복사했다.
- `./test.command`: 정책 테스트 5건과 서명 회귀 검사 3건 통과.
- `sh upstream/scripts/lint.sh --strict`: 659개 파일에서 위반 0건. baseline은 기존 Manager 길이 항목 2개만 감소한 수치로 갱신했다. 예외를 추가하지 않았다.
- 변경 파일에 SwiftFormat을 적용하고 `git diff --check`를 통과했다.

재현 명령:

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  TEST_RUNNER_XCODE_RUNNING_FOR_PREVIEWS=1 \
  xcodebuild test -project upstream/Thaw.xcodeproj -scheme Thaw \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates \
  -only-testing:ThawTests/MenuBarDragSettlementTests \
  -only-testing:ThawTests/ThawBarCommandDragTests \
  -only-testing:ThawTests/SavedOrderMirrorGateTests \
  -only-testing:ThawTests/ManualMembershipTests \
  -only-testing:ThawTests/ObservedMembershipTests \
  -only-testing:ThawTests/LayoutDropCommitTests CODE_SIGNING_ALLOWED=NO
```

## 독립 리뷰

`superpowers:requesting-code-review`에 따라 개발 대화 기록 없는 별도 에이전트에 요구사항과 이번 diff를 전달했다. 읽기 전용으로 호출 순서, 취소, 참조 수명, 기존 판정·저장 조건을 검토했으며 조치가 필요한 정확성·회귀·보안 문제는 발견하지 못했다. 리뷰 에이전트는 테스트나 실제 조작을 실행하지 않았다.

## Release 빌드

`./build.command`로 Release 빌드·고정 인증서 서명·엄격 서명 검증을 통과했다. 결과물은 `/Users/hangjin/Desktop/neat-worktrees/drag-settlement/build/Neat.app`이다. 실행 파일 SHA-256은 `889f591c33afbba6c570a3846d3e45cda755e65861f9c3dc8ccf7289ae454a14`이다. 사용자 승인 후 `/Applications/Neat.app`에 설치·실행했다. 설치본의 SHA-256도 위 값과 일치하며 엄격 서명 검증을 다시 통과했다.

## 실제 조작 검증 — 2026-10-21

사용자가 CGEvent 도구 재사용, 최신 앱 교체·재실행, 실제 아이콘 배치 임시 변경·복원을 승인한 뒤 수행했다. `/private/tmp/neat-ui-verification info`에서 입력·화면 캡처 권한을 확인했다. 아래는 자동 테스트와 별개로 실제 설치 앱에서 수행한 조작이다.

증거 경로는 모두 `build/verification/drag-settlement/ui/` 기준이다.

| 실제 조작 | 관찰한 결과 | 근거 |
| --- | --- | --- |
| 히든바에서 Shottr, Folder Hub를 Cmd 드래그로 연속 꺼내기 | 바를 다시 열지 않고 두 항목이 보임으로 이동했다. 이동 중 다른 숨김 항목은 실제 메뉴바에 펼쳐지지 않았다. | `shottr-during.png`, `second-during.png`, `two-visible.png`, `two-visible.plist` |
| 드롭 후 15초 대기 | 두 항목의 저장 분류·순서가 같고 Shottr가 Neat 오른쪽에 유지됐다. | `after-15s.log`, `after-15s.plist` |
| 실제 메뉴바의 Shottr를 Neat 왼쪽으로 놓은 뒤 0.92초 만에 오른쪽으로 다시 이동 | 두 번째 드롭 뒤 5초 대기해도 최신 위치와 보임 분류가 유지됐다. 각 조작 직전에 AX 좌표를 다시 읽었다. | `rapid-v2-actions.log`, `rapid-v2-middle.log`, `rapid-v2-result.log`, `rapid-v2-result.png` |
| 실제 메뉴바의 Shottr를 Neat 왼쪽으로 Cmd 드래그 | 5초 후 실제 메뉴바에서 사라지고 숨김 분류·순서에 기록됐다. | `native-hide-v2-actions.log`, `native-hidden-v2.png`, `native-hidden-v2.plist` |
| 히든바의 Shottr를 메뉴바로 끄는 도중 Escape | 놓은 뒤에도 분류·순서가 변하지 않았다. | `cancel-during.png`, `cancel-result.png`, `cancel-result.plist` |
| 다시 연 바에서 메뉴바 아래 잘못된 위치로 드롭 | 분류·순서가 변하지 않았다. | `invalid-during.png`, `invalid-result.plist` |
| 취소 후 Shottr를 다시 유효한 메뉴바 위치로 드롭 | 다음 제스처가 정상 처리돼 Shottr가 Neat 오른쪽에 표시됐다. | `retry-during.png`, `retry-result.log`, `retry-result.png` |
| Neat 종료·재실행 및 12초 대기 | 테스트 배치의 저장 분류·순서가 재실행 전과 같고 Shottr가 보임에 유지됐다. | `before-relaunch.plist`, `after-relaunch.plist`, `relaunch-position.log`, `relaunch-result.png` |

최초 바 폭 변경으로 아이콘을 놓친 시도와, 첫 빠른 왕복에서 두 번째 드롭이 Neat 아이콘 내부에 떨어진 시도는 통과로 계산하지 않았다. 후자는 중간 안내를 정정하고 실제 좌표를 다시 읽는 `rapid-v2` 절차로 재검증했다. 제품 코드는 이번 실제 조작 검증에서 수정하지 않았다.

## 사용자 상태 복원

검증 전 설치 앱과 환경설정을 `ui/Neat-before.app`, `ui/preferences-before.plist`에 보관했다. 설정 화면에서 Shottr와 Folder Hub를 숨김으로 되돌리고, 숨김 순서를 Shottr → Folder Hub → Karabiner → 올ㅋ사전 → Telegram → 카카오톡 → Alfred → Magnet → Muse로 복원했다. `restored-settings.png`가 화면 근거다.

현재 관찰에서 제외된 기존 저장 항목도 남기기 위해 Neat 종료 후 `MenuBarItemManager.savedSectionOrder` 한 키만 검증 전 값으로 복원했다. 다른 설정은 일괄 덮어쓰지 않았다. 다시 실행해 12초 대기한 뒤 보임·숨김 저장 기록 전체와 자동 닫기 설정이 사전 값과 같은지 확인했다. 로그인 시 실행도 설정 화면에서 계속 켜짐을 확인했다. 최종 Neat 아이콘 AX 위치는 사전과 같은 x=1053…1096이며, 테스트에 사용한 두 아이콘은 숨김에 있다.

최종 근거: `restored-final.plist`, `restored-final.log`, `restored-final.png`. 결과 대조 10개 항목은 `results.json`에 기록했고 모두 통과했다. 이 대조는 실제 실행 증거의 확인이며 별도 제품 자동 테스트 건수에 합산하지 않는다. 최신 설치 앱은 실행 상태로 유지했다.

## 미수행 범위

전체 앱 테스트·Sonar 커버리지·외부 모니터 검증·원격 CI·PR 승인·main 병합은 수행하지 않았다. 실제 조작은 현재 단일 내장 화면에서 검증했다. 원래 작업 트리의 사용자 미커밋 변경은 보존했다. 작업 브랜치는 원격에 push했고 PR #2를 생성했다. 원격 CI 결과와 병합 승인은 별도로 확인해야 한다.


## 최종 PR 소스 일치 확인 — 2026-10-21

초기 PR에서 제외한 드래그 미리보기 변경 3개 파일을 별도 커밋으로 포함했다. 포함 전 diff가 실제 조작 검증 때 보관한 `/tmp/neat-drag-preview-baseline.patch`와 바이트 단위로 같음을 `cmp`로 확인했다. 위 Release 빌드와 실제 조작 검증은 최종 PR의 제품 소스 전체를 대상으로 수행한 결과다. 검증 뒤 제품 소스를 추가 수정하지 않았다.

`superpowers:requesting-code-review`에 따라 개발 대화 기록 없는 별도 리뷰 에이전트가 세 파일 및 호출부·이벤트 모니터·기존 드래그 감시 경로를 읽기 전용으로 검토했다. 조치가 필요한 정확성·회귀·보안 문제는 없었으며, 검토에서 제외한 동작도 없었다. 이 리뷰는 실행 검증을 대신하지 않는다.

최종 소스로 기존 6개 테스트 묶음에 CI의 `LaunchAtLoginSettingTests`, `ThawBarOutsideClickTests`를 추가해 재실행했다. 네이티브 테스트 76개, 매개변수별 실행 95건 통과, 실패·건너뜀 0건이다. 명령은 위 재현 명령에 `-only-testing:ThawTests/LaunchAtLoginSettingTests -only-testing:ThawTests/ThawBarOutsideClickTests`를 추가했다.

근거: `/tmp/neat-pr-final-tests.log`, `/tmp/neat-pr-final-test-summary.json`, `/Users/hangjin/Desktop/neat/build/DerivedData/Logs/Test/Test-Thaw-2026.10.21_01-00-19-+0900.xcresult`. 빌드 앱과 설치 앱의 실행 파일 SHA-256은 여전히 위 검증 값과 같다. 테스트 결과와 요약은 `build/verification/drag-settlement/`에도 보관했다.
