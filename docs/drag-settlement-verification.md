# 드래그 정착 처리의 소유권 정리

## 범위

`MenuBarDragSettlement`가 정착 작업의 교체·취소, 마지막 드래그 종료 시각, 캐시 갱신→분류 채택→순서 기록 순서를 소유한다. 입력 처리는 `noteUserMenuBarDragEnded`에 종료 정보만 전달한다. 기존 실제 이동, 그룹 판정, 분류 채택, 부분 관찰 거부, 임시 표시 해제, 순서 저장 구현은 재사용한다.

시간과 동작은 유지한다. 각 드래그 종료의 500ms 빠른 갱신은 독립 실행하고, 교체 가능한 정착 작업은 1.5초 뒤 실행한다. 진행 중 드래그와 종료 후 4초 동안의 자동 이동 보호를 유지한다. 수동 모드 전환 관찰은 드래그 종료 시각을 갱신하지 않고 분류만 채택한다.

`refactor/drag-settlement`는 최신 `origin/main`의 `dd9eac5`에서 만들었다. main에 아직 없는 선행 드래그 커밋은 합쳤다. 원래 작업 트리의 미커밋 드래그 미리보기 변경 3개 파일은 검증 기준으로만 복사했고 이번 리팩터링 커밋에 포함하지 않는다. 원래 작업 트리는 수정하지 않았다.

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

## 남은 검증

Release 빌드·서명 결과와 실제 조작 결과는 검증 후 추가한다. 실제 조작은 아직 미완료다. 현재 CUA는 Neat의 1픽셀 창만 반환하며 Cmd를 유지한 드래그 입력을 제공하지 않는다. 기존 `/private/tmp/neat-ui-verification`의 CGEvent 도구 재사용과 실제 사용자 배치 임시 변경·복원은 실행 전 승인이 필요하다.

남은 항목은 최신 앱 실행, 히든바→메뉴바 연속 이동, 메뉴바→숨김 이동, 취소, 드롭 후 대기, 재실행 후 분류·순서 유지와 사용자 상태 원상 복원이다. 자동 테스트 통과를 실제 조작 검증으로 대신하지 않는다. 전체 앱 테스트·Sonar 커버리지·원격 CI·PR 승인·main 병합은 수행하지 않았다.
