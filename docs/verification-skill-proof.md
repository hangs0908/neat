# verify 스킬 실행 기록

2026-10-24, macOS 로컬 사용자 세션에서 `.agents/skills/verify/SKILL.md`의 기존 세션 경로를 실행했다. 앱 소스·설치본·권한·로그인 항목은 변경하지 않았다.

## 빌드와 자동 검사

- `./build.command`의 Release 빌드와 고정 서명 검증이 통과했다.
- `./test.command`의 서명 회귀 검사 3건과 정책 테스트 5건이 통과했다.
- 설치본의 엄격한 서명 검증과 번들 ID `local.hangjin.Neat`을 확인했다.
- 기본 Python의 PyYAML 부재로 validator 최초 실행은 실패했다. 프로젝트 의존성을 바꾸지 않고 `uv run --no-project --with pyyaml python /Users/hangjin/.codex/skills/.system/skill-creator/scripts/quick_validate.py .agents/skills/verify`로 재실행해 `Skill is valid!`을 확인했다. 로컬 링크와 정리 후 증거 파일·본문 검사도 통과했다.

## 실제 조작

기존 `/Applications/Neat.app` PID 49746을 재사용했다. 최초 관찰에는 설정창이 없었으며 `open -a /Applications/Neat.app`으로 열었다. SettingsWindow에 아이콘 목록과 권한 3개 Granted가 표시됐다.

CUA로 `오픈소스 고지`를 클릭했다. Credits의 감사 문구를 확인하고 Origins를 클릭해 Ice·Jordan Baird와 Barometer 본문으로 전환됨을 확인했다. Licenses를 클릭해 AXSwift·CompactSlider·Sparkle 등의 번들 라이선스 본문을 확인했다. 외부 링크는 열지 않았다.

증거는 Git에서 제외된 `build/verify-skill-evidence/`의 `settings-before.txt`, `credits.txt`, `origins.txt`, `licenses.txt`와 각 PNG에 있다. 페이지 전환 순서는 이 문단과 CUA 도구 기록에 남겼다.

## 정리

이번에 연 고지창과 설정창을 닫았다. 전후 AX에서 보임·숨김의 아이콘 순서와 두 스위치 값이 동일함을 비교했다. 기존 Neat 프로세스는 같은 PID로 실행 중이며 새 앱 프로세스·임시 앱·시스템 등록은 만들지 않았다. 사용자 프로필과 서명 키를 보존했다. `settings-after.txt`, `cleanup-ui.txt`와 증거 PNG가 정리 후 남아 있음을 확인했다.

## 검증 한계

새 빌드 실행 파일 SHA-256은 `44e32c23b00b832809781643fa76b79e92179ed355c81208ff67d340f030ae3e`, 설치본은 `6ac65649a90fc9a25204b655245fc625ecd5a98187a31e25c5c3cb82061a7306`이다. UI 결과는 기존 설치본에 대한 증거이며 최신 빌드의 실제 조작 통과로 간주하지 않는다.

기존 세션에는 이미 앱 설치, 서명 인증서, 승인된 권한, 로그인 항목과 사용자 배치가 준비돼 있었다. 빈 사용자 세션의 설치·최초 권한·로그인 항목 등록, 새 빌드 교체 실행은 미검증이다. 배치 이동, 메뉴 막대 Cmd+드래그, 숨김 바, 타이머, 로그인 동작과 외부 모니터는 이번 실행 범위에 포함하지 않았다.
