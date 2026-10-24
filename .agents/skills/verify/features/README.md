# Neat 기능 지도

| 기능 | 진입점 | 증명할 결과 |
| --- | --- | --- |
| [배치](layout.md) | 설정창 드래그·접근성 이동, macOS Cmd+드래그 | 보임·숨김과 순서 저장·복원 |
| [숨김 바와 자동 닫기](hidden-bar.md) | Neat 아이콘, 메뉴 막대 빈 공간 | 두 진입점, 앱 메뉴, 바깥 클릭, 5초 타이머 |
| [로그인 실행](login.md) | 설정창 로그인 스위치, 첫 실행 | 시스템 등록과 선택 유지 |
| [오픈소스 고지](notices.md) | 설정창 오픈소스 고지 링크 | Credits·Origins·Licenses 내용 전환 |

각 파일의 모든 진입점이 전체 기능 검증 범위다. 한 경로만 검사했다면 해당 경로만 통과로 기록한다. 외부 모니터가 없거나 필수 아이콘·권한이 없으면 이유와 미검증 범위를 보고한다. 소스 근거는 `README.md`, `upstream/Thaw/Settings/SettingsPanes/SimpleModeSettingsPane.swift`와 각 파일에 적힌 구현이다.
