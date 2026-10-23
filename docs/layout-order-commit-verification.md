# 배치 순서 확정 소유권 정리 검증

검증일: 2026-10-23. 환경: macOS 27.0.1, Apple Silicon, Xcode 27.1.

## 변경 범위

- `LayoutBarKeyboard.applySectionOrder`를 기존 `LayoutDropCommit`으로 옮겼다. 순서 기록, 명시적 편집 표시, 적용 예약, 펼쳐진 숨김 분류의 즉시 적용, 캐시 갱신 순서는 유지했다.
- Undo 대상도 `LayoutDropCommit.UndoTarget`으로 함께 옮겼다. 핸들러가 대상을 유지하고 대상은 앱 상태·Undo 관리자를 약하게 참조하는 구조를 유지했다. 분류 간 키보드 이동에서도 같은 대상을 사용한다.
- 키보드 이동과 드롭의 호출자를 갱신했다. 분류 간 이동, 드래그 정착, 실제 이동 구현과 설정 저장 형식은 변경하지 않았다.
- 새 추상화·의존성·파일은 제품 코드에 추가하지 않았다. 기존 lint 기준의 두 항목만 줄어든 위치·크기에 맞췄다.

## 자동 검증

- 변경 전 관련 네이티브 테스트 28개, 매개변수별 실행 33건 통과.
- 변경 후 같은 4개 묶음에 로그인 설정·바깥 클릭 회귀 검사를 더해 43개, 매개변수별 실행 50건 통과. 실패·건너뜀 0건.
- 기존 Undo/Redo 3회 반복 검사를 유지했다. 같은 분류의 드롭 완료 통지가 한 번 발생하고 Undo 관리자 유무에 따라 처리되는 검사도 추가했다.
- 테스트의 기본 분류 제어기는 실제 메뉴 막대를 변경하지 않는 구현이다. 이 자동 검사는 실제 화면의 배치·저장 결과를 대신하지 않는다.
- `./test.command`: 서명 회귀 3건과 정책 테스트 5개 통과.
- strict SwiftLint: 660개 파일, 위반 0건. 최초 변경 후 검사는 기존 줄 수 기준 불일치로 중단됐으며, 기존 두 항목 갱신 후 다시 통과했다.
- 변경 Swift 파일의 SwiftFormat 검사와 `git diff --check` 통과.
- 주석·Undo 대상 이름을 제외한 순서 적용 함수의 구현이 변경 전과 같은지 비교했다. 이전 심벌의 호출은 남아 있지 않다.
- `./build.command`: Release 빌드·고정 인증서 서명·엄격 서명 검증 통과. 결과물은 `build/Neat.app`이다.

네이티브 테스트 재현 명령:

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  PATH="$PWD/.tools/bin:$PATH" TEST_RUNNER_XCODE_RUNNING_FOR_PLAYGROUNDS=1 \
  xcodebuild test -project upstream/Thaw.xcodeproj -scheme Thaw \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates \
  -only-testing:ThawTests/LayoutBarKeyboardTests \
  -only-testing:ThawTests/LayoutDropCommitTests \
  -only-testing:ThawTests/LayoutEditorModelTests \
  -only-testing:ThawTests/LayoutBarSelectionTests \
  -only-testing:ThawTests/LaunchAtLoginSettingTests \
  -only-testing:ThawTests/ThawBarOutsideClickTests CODE_SIGNING_ALLOWED=NO
```

## 독립 코드 리뷰

`superpowers:requesting-code-review` 절차로 개발 대화 기록을 전달하지 않은 별도 에이전트가 요구사항·4개 Swift 파일의 diff·관련 호출자·명시적 편집 구현을 읽기 전용으로 검토했다. 조치가 필요한 정확성·회귀·보안 문제는 발견하지 못했다. 리뷰 중 제품 코드를 수정하지 않았다.

독립 리뷰는 자동 테스트·실제 조작을 직접 실행하지 않았으며 lint 기준 갱신은 검토하지 않았다. 기준 파일은 항목 수를 유지하고 두 항목만 변경했음을 별도로 비교했다. 이 리뷰는 원격 CI나 사용자 병합 승인을 대신하지 않는다.

## 실제 조작 — 자동 테스트와 별도

사용자가 최신 설치 앱 교체·재실행과 배치의 임시 변경·복원을 승인한 뒤 수행했다. 설치 실행 파일의 SHA-256은 빌드와 같은 `6ac65649a90fc9a25204b655245fc625ecd5a98187a31e25c5c3cb82061a7306`이며 엄격 서명 검증도 통과했다.

| 실제 조작 | 관찰 결과 |
| --- | --- |
| 설정창의 Shottr에 접근성 `Move right` 실행 | 숨김 순서가 Shottr → Folder Hub에서 Folder Hub → Shottr로 변경됨 |
| 실제 키보드 Cmd+Z, Cmd+Shift+Z/Cmd+Z 3회 반복 | 매번 원래 순서와 변경한 순서 사이를 왕복하며 크래시 없음 |
| Shottr에 Option+오른쪽 화살표, Cmd+Z | 같은 순서 이동과 복원이 확인됨 |
| 다시 순서 변경 후 Cmd+Q로 종료·재실행 | Folder Hub → Shottr 순서가 저장되어 유지됨 |
| Shottr를 왼쪽으로 이동하고 설정창 닫기 | 최초 숨김 순서로 복원됨 |

실제 화면에서 로그인 실행 on, 손쉬운 사용·배치 접근·화면 기록 Granted도 확인했다. 사전/사후 저장값 비교 6건이 통과했다. 보임·숨김 저장 순서 전체, 자동 닫기, 화면별 바 설정, 새 항목 분류가 같고 임시 편집창 설정 키는 제거됐으며 설치 앱은 최신 빌드와 일치한다. 화면별 설정의 JSON 바이트 순서는 달라졌지만 해석한 설정값은 같다. 관찰 캐시·알려진 항목 목록의 정상 갱신은 덮어쓰지 않았다.

근거는 `build/verification/layout-order-commit/ui-verification.log`, `restoration-checks.json`, `native-tests-summary.json`, `automatic-verification.log`에 남겼다. 실제 조작 확인을 자동 테스트 건수에 합산하지 않았다.

## 미검증 범위

좌표 드래그 입력은 아이콘 선택으로만 관찰되어 드래그 재정렬 통과로 계산하지 않았다. 현재 제품의 전용 SwiftUI 드롭 편집창에는 진입하지 못했으며, 그 공통 드롭 진입점은 자동 검사로 검증했다. 실제 화면에서 확인한 것은 동일한 순서 확정 함수를 쓰는 키보드·접근성 이동 경로다. macOS 메뉴 막대 Cmd+드래그·펼쳐진 숨김 바·외부 모니터는 이번 변경에서 수정하지 않았고 별도로 검증하지 않았다.

## 사후 정리

자동 검사에서 생성된 UUID 테스트 설정 2개는 테스트 종료 후 비어 있음을 확인해 제거했으며 잔여가 없었다. 검증용 백업 앱의 경로별 등록을 해제하고 앱·설정 복사본·일회성 링크·임시 기록을 제거했다. 검증용 Finder 창과 Neat 설정창을 닫았다. 별도 테스트 앱 식별자·로그인·권한 항목은 만들지 않았다.

실제 Neat 설정·프로필·서명 키와 기존 공유 빌드 캐시는 보존했다. 최신 설치 앱은 실행 상태로 남겼다. 원격 CI와 사용자 병합 승인은 별도로 확인하며, main 병합은 수행하지 않았다.
