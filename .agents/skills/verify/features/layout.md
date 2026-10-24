# 보임·숨김 배치와 순서 저장

## Sub-features

- 설정창에서 아이콘을 보임·숨김으로 드래그한다.
- 접근성 이동으로 섹션과 순서를 변경한다.
- macOS 메뉴 막대에서 Cmd+드래그한 순서를 보존한다.
- 바 열기·닫기, 시간 경과와 앱 재실행 후 배치를 유지한다. 새 아이콘은 보임에 추가한다.

## How to get to it (user POV)

Neat을 열고 보임·숨김 행을 이용한다. 시스템 메뉴 막대에서는 Cmd를 누른 채 일반 앱 아이콘을 옮긴다.

## Driving it with CUA

Doctor를 통과하고 모든 아이콘의 Description·섹션·좌우 순서를 기록한다. 사용자 앱의 메뉴를 실행하지 않아도 되는 일반 아이콘 하나를 고른다.

설정창 드래그는 최신 스크린샷의 해당 아이콘과 목적 행 사이에서 `neatApp.drag(from, to)`를 호출한다. AX의 `Value: Visible` 또는 `Value: Hidden` 및 순서 변화가 있어야 통과다.

접근성 경로는 해당 아이콘의 최신 인덱스에서 `performSecondaryAction(index, 'Move to 숨김')`을 호출한다. 반대 경로는 실제 노출된 `Move to 보임`을 사용한다. `Move left`·`Move right`도 각각 관찰된 액션으로 실행한다. 섹션과 인접 아이콘 순서를 확인한다.

바를 열었다 닫고 30초 이상 경과한 뒤 같은 순서를 확인한다. 재실행 경로는 기존 세션의 정상 종료·재시작과 상태 복원 범위를 먼저 기록한다. 저장소의 `Neat/Profiles` 관련 파일 변화와 재실행 후 UI를 함께 확인한다. 마지막에 원래 섹션과 전체 순서로 복원한다.

## Gotchas

현재 CUA `drag`에는 Cmd modifier가 없다. 메뉴 막대 원래 재현 경로는 도구 제약으로 미검증 처리한다. 접근성 이동 성공은 드래그 성공이 아니다. `docs/command-drag-verification.md`도 확인한다.

Clock·Control Center처럼 이동 불가한 아이콘을 대상으로 고르지 않는다. macOS 메뉴 막대 자동 숨김이 켜져 있으면 배치 UI 대신 안내가 나온다. 새 아이콘 검증에 실행할 앱이 없으면 실패 사유를 남긴다. 외부 모니터 연결·해제는 별도 실제 장비 검증이 필요하다.

구현은 `FoldedMenuBar.swift`, `Panels/LayoutBar/`와 `Settings/Models/Profiles/`에 있다.
