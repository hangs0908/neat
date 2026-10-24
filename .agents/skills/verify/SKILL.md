---
name: verify
description: Neat macOS 앱의 설정창, 메뉴 막대 배치, 숨김 바, 자동 닫기와 로그인 실행을 실제 화면에서 검증하고 증거와 사용자 상태 복원을 기록할 때 사용한다.
---

# Neat 실제 조작 검증

저장소 루트에서 실행한다. 먼저 [AGENTS.md](../../../AGENTS.md)의 검증·리뷰 기준과 [테스트 정리 절차](../../../docs/test-cleanup-procedure.md)를 읽는다. 검증할 경로는 [기능 지도](features/README.md)에서 고른다. 루트 Swift 패키지는 정책 테스트용이며 앱 실행기가 아니다.

## Launch

macOS 27 이상과 전체 Xcode가 필요하다. `README.md`의 지원 환경을 확인한다.

1. `git rev-parse HEAD`, `git status --short`, `ps -axo pid=,command= | rg '/(Neat|Thaw)\.app/Contents/MacOS/'`로 소스와 기존 앱 PID·경로를 기록한다. 기존 Neat·Thaw를 자동 종료하지 않는다.
2. 증거 디렉터리를 만들고 아래 명령을 실행한다. 이미 존재하는 `build/`는 보존한다.

   ```sh
   neatEvidence="$PWD/build/verify-$(date +%Y%m%d-%H%M%S)"
   mkdir -p "$neatEvidence"
   ./build.command > "$neatEvidence/build.log" 2>&1
   ./test.command > "$neatEvidence/policy-tests.log" 2>&1
   ```

   빌드 산출물은 `build/Neat.app`이다. 고정 서명 인증서가 없으면 빌드가 중단된다. `setup-signing.command`는 키체인을 변경하므로 자동 복구 단계로 실행하지 않는다.
3. 기존 앱이 실행 중이면 해당 세션을 재사용한다. 설치본과 새 빌드가 다르면 기존 설치본 검증과 최신 구현 검증을 구분한다. 최신 구현 검증에는 사용자 상태와 설치본 백업을 기록한 후 `README.md`의 설치 절차가 필요하다. 이 스킬의 기본 경로는 설치본 교체·권한 재설정 없이 기존 세션을 이용한다.
4. 설치와 권한 승인이 끝난 단일 세션에서 `open -a /Applications/Neat.app`으로 설정창을 연다. Neat이 꺼져 있었다면 실행 후 새 PID를 기록한다. 다른 메뉴 막대 관리자가 실행 중이면 조작을 중단하고 충돌을 보고한다.
5. 빈 사용자 환경에서는 초기 안내의 손쉬운 사용·화면 캡처·배치 파일 접근 승인을 완료하고 `Neat 시작`으로 진입해야 한다. 로그인 항목 최초 등록도 기록한다. 권한 승인이나 사용자 인증을 수행할 수 없으면 준비 미완료다. 데이터베이스·시드·포트·서버 인증은 없다.
6. 준비 완료는 `SettingsWindow`에서 보임·숨김 아이콘과 필요한 권한의 `Granted` 상태가 관찰되는 것이다. 프로세스 존재만으로 통과시키지 않는다. teardown은 아래 Cleanup을 따른다.

별도 데이터 디렉터리로 OS 메뉴 막대·TCC·로그인 항목을 격리할 수 없다. 두 인스턴스나 두 에이전트가 동시에 조작하지 않는다. 빈 환경 검증은 별도 macOS 사용자 세션에서 수행한다.

## Doctor

조작 전과 이상 증상 발생 시 다음 읽기 전용 검사를 실행한다.

```sh
ps -axo pid=,command= | rg '/(Neat|Thaw)\.app/Contents/MacOS/'
codesign --verify --deep --strict /Applications/Neat.app
shasum -a 256 /Applications/Neat.app/Contents/MacOS/Neat build/Neat.app/Contents/MacOS/Neat
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' /Applications/Neat.app/Contents/Info.plist
```

정확히 하나의 대상 Neat, 번들 ID `local.hangjin.Neat`, 서명 성공을 확인한다. 해시 차이는 최신 빌드 검증으로 보고할 수 없다는 뜻이다. 이어 `getAXState()`에서 `SettingsWindow`와 권한 상태를 확인한다. 권한 안내나 빈 아이콘 목록이면 기능 조작 전에 원인을 해결한다.

## Drive

기존 네이티브 UI 자동화 테스트 드라이버는 없다. Codex에서는 `mcp__cua_repl.js`의 네이티브 App API를 사용한다. 첫 호출은 다음 한 문장이다. 반환되는 도구 문서를 먼저 읽는다.

```js
let neatApp = await cua.getApp('/Applications/Neat.app');
```

`getAXState()`에서 실제 라벨·Description·Secondary Actions를 읽고 해당 호출에서 얻은 인덱스로 `click(index)` 또는 `performSecondaryAction(index, action)`을 실행한다. 조작 후 다시 `getAXState()`를 읽는다. 숫자를 다음 관찰 이후 재사용하지 않는다. 화면 좌표는 최신 스크린샷에서 결정한다.

안전한 첫 검증은 [오픈소스 고지](features/notices.md)다. 설정창의 `오픈소스 고지` 링크를 클릭하고 페이지 전환 후 내용이 바뀌는지 확인한다. 단순 창 표시만으로 기능을 검증하지 않는다.

웹페이지 조작이 필요한 검증은 `ego-browser` 스킬을 먼저 읽는다. 외부 링크를 여는 것은 고지 검증에 필요하지 않다. macOS 메뉴 막대 Cmd+드래그는 `drag(from, to)`에 modifier 인자가 없어 현재 API만으로 검증할 수 없다. 설정창의 이동 동작으로 대체 통과시키지 않는다.

## Evidence

`neatEvidence` 디렉터리에 baseline, 조작 순서와 시각, 조작 전후 AX 텍스트, 스크린샷, 빌드·테스트 로그와 정리 결과를 보존한다. CUA 런타임에서 다음과 같이 저장한다. `evidencePath`에는 이번 실행에서 만든 `neatEvidence`의 절대 경로를 넣는다.

```js
var fs = await import('node:fs/promises');
await fs.writeFile(evidencePath + '/state.txt', await neatApp.getAXState({disableDiffing: true}));
await fs.writeFile(evidencePath + '/state.png', await neatApp.getScreenshot({emit: false}));
```

파일명은 조작 단계별로 달리하여 덮어쓰지 않는다. 저장 기능이 없으면 도구 출력과 최소 재현 기록을 남기고 스크린샷 파일 부재를 명시한다.

실제 사용자 진입점별로 조작과 결과를 모두 기록한다. 배치·설정 변경은 재열기·재실행 후 유지 여부와 저장 결과도 확인한다. 사용자 파일을 internal setter나 테스트 엔드포인트로 바꾼 결과는 UI 검증이 아니다. 외부 앱 메뉴는 열기·닫기까지만 검증하고 메시지 전송 같은 부작용은 실행하지 않는다. 모킹은 기존 production 경계에서만 허용한다.

시스템 등록·파일 저장을 검증한다면 화면 결과와 실제 등록·파일 변화도 함께 기록한다. dry-run이라는 이름을 신뢰하지 말고 변경된 파일·프로세스·등록을 관찰한다. 자동 테스트 결과, 실제 조작 결과, 미검증 경로를 분리한다. 보고용 최소 기록은 `docs/`에 남기고 개인정보가 있는 원본 증거는 Git에 올리지 않는다.

## Cleanup

실패한 시도도 같은 정리를 수행한다. 시작 전에 창·배치 순서·스위치·권한·로그인 상태, 생성 예정 경로·식별자를 기록한다.

1. 이번 검증에서 연 고지창과 설정창을 닫는다. 기존에 열려 있던 창은 원래 상태로 유지한다. 변경한 배치와 스위치는 같은 UI 경로로 복원하고 다시 읽어 확인한다.
2. 기존 프로세스는 남긴다. 이번 실행이 시작한 앱만 PID·실행 경로를 재확인하고 정상 종료한다. 강제 종료가 필요하면 기록한 PID만 대상으로 삼는다. 이름으로 일괄 종료하지 않는다.
3. 이번 실행에서 만든 scratch와 임시 앱만 제거한다. 기존 `build/Neat.app`, DerivedData, 사용자 프로필, 서명 키와 다른 작업 파일은 보존한다. 설치·권한·로그인 항목을 변경했다면 연결된 정리 절차 전체를 적용한다.
4. 기록한 PID·경로·시스템 등록과 최종 UI 상태를 재검사한다. 복원을 확인하지 못하면 정리 미완료다. 결과를 `결과.md`에 기록하고 `test -s "$neatEvidence/결과.md"`로 정리 후 증거 존재도 확인한다. 증거 디렉터리는 삭제하지 않는다.

## Helpers

추가 실행 스크립트는 없다. 빌드는 `./build.command`, 자동 테스트는 `./test.command`, 실제 조작은 CUA를 사용한다. 자동 테스트는 UI 조작을 대체하지 않는다. 테스트 수행도 프로젝트 기준에 따라 독립 리뷰 대상이다.
