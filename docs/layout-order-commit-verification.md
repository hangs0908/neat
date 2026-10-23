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

## 실제 조작 및 정리 상태

실제 설치 앱 교체·재실행과 사용자 배치 임시 변경은 승인 대기 중이다. 실제 순서 이동·Undo/Redo·상태 복원 검증은 아직 완료하지 않았다.

자동 검사에서 생성된 UUID 테스트 설정 2개는 테스트 종료 후 비어 있음을 확인해 제거했다. 실제 Neat 설정·프로필·서명 키와 기존 공유 빌드 캐시는 보존했다. 별도 테스트 앱이나 로그인·권한 항목은 만들지 않았다.

전체 앱 테스트·외부 모니터 검증·원격 CI·PR 승인·main 병합은 아직 수행하지 않았다.
