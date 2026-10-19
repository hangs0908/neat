# Neat 검증 기록

검증일: 2026-10-19. 환경: macOS 27.0.1 (26A434), Apple Silicon. 원본 Thaw 커밋: `c0afbdbf045eca8b1d276e7493272ee07c3996be`.

## 업데이트 후 권한 재요청 수정

- 설치 앱의 기존 서명은 `Signature=adhoc`, 지정 요구사항은 `cdhash`였다. 아이콘 변경 후에도 권한을 다시 요구하는 원인은 앱 내용마다 달라지는 이 임시 서명이었다. 권한 확인 코드는 시스템의 실제 승인 상태를 읽고 있었다.
- `setup-signing.command`로 사용자 키체인에 Neat 전용 로컬 인증서를 설치했다. 코드 서명 정책으로만 신뢰하며, 같은 명령을 다시 실행했을 때 기존 인증서가 재사용됨을 확인했다. 인증서는 10년 유효하며 삭제·교체 시 권한 재승인이 필요할 수 있다.
- `./build.command`와 설치된 `/Applications/Neat.app`의 엄격한 서명 검증이 통과했다. 최종 지정 요구사항은 bundle ID와 인증서 지문을 사용하며 `cdhash`에 의존하지 않는다.
- 임시 앱 복사본의 리소스를 변경하고 같은 인증서로 다시 서명했다. 두 버전의 CDHash는 서로 달랐지만 지정 요구사항은 동일했고, 양쪽 모두 같은 요구사항으로 `codesign --verify --deep --strict -R` 검증을 통과했다. 설치 앱이나 TCC 데이터베이스를 바꾸지 않는 방식으로 검사했다.
- `./test.command`: 서명 회귀 검사 3건과 기존 정책 테스트 5건 통과. 인증서가 없는 경우 빌드 시작 전 차단, 고정 인증서 사용, 서명 실패 전파를 검사했다. 셸 문법 검사와 독립 리뷰도 통과했다.
- 사용자 인증 후 시스템 설정에서 기존 Neat의 손쉬운 사용·화면 기록 항목만 제거하고 고정 서명된 `/Applications/Neat.app`을 다시 추가했다. 재실행한 앱에서 손쉬운 사용·배치 파일 접근·화면 기록 모두 승인됨과 정상 설정창을 확인했다. 다른 앱의 승인 기록은 변경하지 않았다.
- 실제 업데이트 검증으로 별도 앱 복사본의 `CFBundleVersion`을 `115.1`로 변경하고 같은 인증서로 서명한 뒤 `/Applications/Neat.app`에 설치·실행했다. 재승인 없이 정상 설정창과 세 권한의 승인 상태가 유지됐다. 이후 원래 `115` 빌드로 복원·재실행했을 때도 세 권한이 승인됨으로 유지됐다. 시스템 전체 재부팅은 검사하지 않았다.

## 통과한 검사

- Xcode 27.1 (27A9275)에서 `./build.command`: Release 전체 컴파일·링크, 로컬 서명 및 `codesign --verify --deep --strict` 통과. 최종 산출물은 `build/Neat.app`이며 `/Applications/Neat.app`에도 설치했다.
- 설치된 앱을 실행해 한국어 권한 안내창과 권한 미승인 시 비활성화되는 `Neat 시작` 버튼을 확인했다.
- 손쉬운 사용 설정은 켜져 있어도 앱에서 미승인으로 판정되는 현상을 확인했다. 사용자 인증 후 시스템 설정의 Neat 항목을 제거하고 `/Applications/Neat.app`을 다시 추가하자 앱에서도 승인으로 바뀌었다. 배치 파일 접근·화면 기록까지 모두 승인된 상태에서 `Neat 시작`을 눌러 실제 앱 아이콘이 나열된 설정창을 확인했다. 로그인 시 실행은 켜짐, 5초 자동 닫기는 꺼짐으로 표시됐다.
- Xcode 네이티브 테스트: `LaunchAtLoginSettingTests`, `ThawBarOutsideClickTests`의 매개변수 사례 포함 15건 통과. 실제 앱 자동 시작을 억제하는 `TEST_RUNNER_XCODE_RUNNING_FOR_PREVIEWS=1` 환경에서 실행했다. 로그: `build/native-tests.log`.
- `./test.command`: Swift Testing 5개 통과. 새 아이콘/새 화면 기본값, 5초 경계, 바·메뉴 조작에 따른 타이머 초기화, 로그인 초기화 조건, 독립 프로필 경로를 검사했다.
- SwiftLint 0.65.1의 `scripts/lint.sh --strict`: 포함된 전체 소스 657개 파일, 위반 0건. Command Line Tools의 SourceKit 경로를 `TOOLCHAIN_DIR=/Library/Developer/CommandLineTools`로 지정했다.
- 변경 Swift 파일의 `swiftc -frontend -parse`: 통과. 이는 구문 검사이며 전체 앱의 타입 검사나 링크 성공을 의미하지 않는다.
- `plutil -lint`: Xcode 프로젝트, 앱 Info.plist, 앱 entitlements 통과.
- `git diff --check`, 두 실행 스크립트의 `bash -n`: 통과.
- Xcode 미설치 상황의 `build.command`: 잘못된 성공 결과를 만들지 않고 필요한 Xcode 버전을 안내한 후 종료하는 것을 확인했다.

기존 lint 기준 정보에는 새 항목을 추가하지 않았다. 기능 축소로 줄어든 기존 파일·타입의 크기와 위치만 갱신했다.

선택한 네이티브 테스트 재현 명령:

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  PATH="$PWD/.tools/bin:$PATH" TEST_RUNNER_XCODE_RUNNING_FOR_PREVIEWS=1 \
  xcodebuild test -project upstream/Thaw.xcodeproj -scheme Thaw \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates \
  -only-testing:ThawTests/LaunchAtLoginSettingTests \
  -only-testing:ThawTests/ThawBarOutsideClickTests CODE_SIGNING_ALLOWED=NO
```

## 독립 코드 리뷰

`superpowers:requesting-code-review` 절차로 개발 대화 기록을 제공하지 않은 별도 리뷰 에이전트가 요구사항, Git diff, 새 파일을 읽기 전용으로 검토했다.

기존 Thaw의 프로필 저장소와 자동 프로필 적용 경로를 공유하는 문제 1건을 발견했다. 프로필 자동 적용을 중단하고 프로필 저장소, Focus 알림, 로그 경로를 Neat으로 분리했다. 경로 회귀 테스트를 추가했고 수정 재검토에서 조치가 필요한 문제는 없었다. 리뷰 중 코드를 수정하지 않았다.

Xcode 설치 후 테스트 빌드에서 발견된 기존 프로젝트 연결 문제도 수정했다. 테스트 타깃에서 호스트와 중복 연결된 정적 `ThawAXCore`를 제거하고, 앱이 직접 사용하는 `ThawConcurrency` 제품의 연결을 명시했다. 개발 대화 없는 별도 에이전트의 읽기 전용 재검토에서 조치가 필요한 문제는 없었다. 최종 설정으로 Release 빌드를 다시 통과했다.

## 수행하지 못한 검사

처음에는 Xcode 미설치로 전체 빌드를 진행하지 못했으나, 사용자 설치 후 전체 앱 빌드와 위 네이티브 테스트를 완료했다. 다음은 아직 완료하지 않았다.

- 기존 앱 전체 테스트 실행 (선택한 회귀 테스트만 실행)
- 실제 아이콘 드래그, 앱 재시작 후 배치 복원, 두 클릭 트리거와 바깥 클릭
- 실제 앱 메뉴 사용 중 보호, 5초 자동 닫기의 화면 동작
- 실제 로그인 항목 등록, 권한 승인·복구 및 외부 모니터 연결/해제
- 전체 앱의 새 코드 80% 커버리지 확인

실행 가능한 Neat.app을 설치하고 모든 권한의 승인 인식 및 설정창의 실제 아이콘 표시까지 확인했다. 실제 아이콘 이동·별도 바의 메뉴 조작·외부 모니터 검증은 완료하지 않았다. 기존 Thaw를 자동으로 종료하거나 기존 Thaw의 권한·설정을 초기화하지 않았다.


## 메뉴 막대 아이콘 교체

- 앱 아이콘의 두 줄 메뉴 바 도형을 단색 SVG 템플릿으로 적용했다. 닫힌 상태는 아래 바 윤곽선, 열린 상태는 채운 바를 사용한다.
- 기존 `Ice Cube`, `IceCubeStroke`, `IceCubeFill` 저장 식별자를 유지해 기존 설정에서도 새 리소스를 사용한다. 선택기에 표시하는 이름은 Neat으로 바꿨다.
- 컴파일된 앱 리소스를 AppKit으로 로드해 두 상태의 템플릿 속성, 25×15.68pt 크기, 투명 배경과 도형 렌더링을 확인했다. 변경한 Swift 파일의 엄격한 lint 검사를 통과했다.
- 독립 리뷰에서 조치가 필요한 문제는 발견되지 않았다. 이번 변경은 표시 리소스와 선택기 명칭에 한정하며 아이콘 클릭이나 배치 로직은 변경하지 않았다.
- 아이콘 교체 후 Release 빌드·고정 서명·엄격한 서명 검증을 통과했다. `/Applications/Neat.app`에 업데이트하고 재실행했다. 설치본과 빌드본의 `Assets.car` SHA-256이 일치한다. 실제 메뉴 막대에서의 클릭 동작은 재검사하지 않았다.


## Cmd+드래그 순서 되돌림 수정

- 일반 배치 저장은 섹션이 펼쳐져 있거나 최근 화면 변화가 있으면 보류되지만, 자동 구조 복원은 이전 저장 순서를 사용할 수 있었다. 기본 드래그 설정은 숨김 섹션을 펼치며 Neat의 자동 닫기는 꺼져 있어, 드래그가 끝나도 일반 저장 경로가 계속 막힐 수 있었다.
- 기존 드래그 종료 후 1.5초 안정화 경로에서 새 전체 관찰을 확보하고, authored Visible 구성원의 실제 좌표 순서를 기록한다. 기존 순서 계산과 오버플로 투영을 재사용해 숨김 섹션·종료된 앱·오버플로 슬롯을 보존하며, 런타임 컨트롤러에도 같은 순서를 전달한다. 자동 구조 정규화는 사용자 배치 보호 기간 동안 대기한다.
- 원본 코드에서 사용자 드래그 우선순위 회귀 검사 두 사례의 실패를 확인했다. 최종 네이티브 테스트는 7개 관련 스위트의 69사례가 통과했다. 새 회귀 검사는 6사례이며 화면 변화·새 아이콘 도착·숨김 섹션 간 이동·오버플로 보존·불안정한 좌표·여러 화면의 좌표·부분 관찰 거부를 검사한다. 로그: `build/drag-red-tests.log`, `build/drag-green-tests.log`.
- 엄격한 SwiftLint 검사: 전체 657개 파일, 위반 0건. 로그: `build/drag-lint.log`. 기존 lint 기준 정보는 이번 수정에서 변경하지 않았다.
- 개발 대화 기록 없는 별도 에이전트의 독립 리뷰에서 드래그 중 펼친 섹션, 다른 섹션으로 옮긴 아이콘의 재삽입, 부분 관찰 사용 문제를 수정했다. 최종 재검토에서 추가 조치가 필요한 문제는 발견되지 않았다. 리뷰 중에는 소스를 수정하지 않았다.
- 실제 메뉴 막대의 아이콘을 옮기는 검사는 수행하지 않았다. 전체 테스트 모음, 외부 모니터의 실제 연결·해제, 전체 새 코드 커버리지 수치는 검사하지 않았다.
- `./build.command`의 Release 빌드·고정 인증서 서명·엄격한 서명 검증이 통과했다. `/Applications/Neat.app`에 설치하고 다시 실행했으며, 설치본과 빌드본의 실행 파일 SHA-256이 일치한다. 업데이트 전후 지정 요구사항은 동일하며 설치본의 서명 검증도 통과했다. Neat와 캡처 서비스·AX 헬퍼의 실행을 확인했다.

### 실제 UI 조작 추가 확인

- 설치된 Neat 설정창을 Finder에서 직접 열었다. 현재 세 권한의 Granted 표시와 보임·숨김 아이콘 목록이 표시됨을 확인했다.
- 설정창의 Muse 아이콘에 노출된 실제 접근성 이동 동작으로 RunCat Neo 오른쪽으로 옮겼다. 화면에서 순서 변경과 30초 이상 유지됨을 확인했다. 같은 UI 동작으로 테스트 전 순서로 되돌린 뒤 다시 30초 후 원래 순서를 확인하고 설정창을 닫았다. 숨김 목록과 동작 스위치는 변경하지 않았다.
- 설정창의 좌표 기반 드래그 시도는 순서 변경을 확인하지 못했으므로 성공으로 계산하지 않았다.
- 메뉴 막대 Cmd+드래그 검사는 아직 미완료다. Computer Use 도구의 SystemUIServer·Control Center 연결은 timeoutReached로 실패했고 Neat의 창 캡처는 메뉴 막대 전체를 포함하지 않는다. 문서화된 drag API에는 Cmd modifier 인자가 없다. 도구 지침상 대체 UI 자동화는 사용자가 해당 기술을 명시적으로 요청해야 하므로 CGEvent·screencapture 사용 허용을 요청했다. 이 검사가 완료되기 전까지 실제 재현 경로의 해결을 확정하지 않는다.
