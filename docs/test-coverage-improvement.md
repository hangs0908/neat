# 기존 코드베이스 테스트 보강 검증

## 환경과 변경 범위

- 기준 커밋: `658bed790c7bec71eaec257dcd967b61b1bb9676`. macOS 27.0.1, Xcode 27.1, Swift Testing.
- 앱은 Xcode 테스트 타깃, 정책은 루트 SwiftPM, 별도 모듈은 각 패키지 테스트 타깃을 사용한다.
- 기존 앱 CI는 별도 패키지 테스트를 실행하지 않았다. 패키지 6개를 커버리지 워크플로의 독립 매트릭스에 연결했다.
- 프로덕션 코드, 공개 API, 프레임워크, 의존성, Sonar 측정 대상과 제외 목록을 변경하지 않았다.
- 새로운 테스트는 11개 정의, 매개변수 확장 시 27개 조건이다. 기존 프로필 fixture를 확장 파일에서 재사용한다.

## 추가한 검증

| 영역 | 검증 내용 | 조건 수 |
|---|---|---:|
| TaskTimeout 단위 테스트 | 값·원래 오류 전달, 마감 도달, 호출자 취소, 자식 작업 종료 | 4 |
| AXWire 단위·Pipe 통합 테스트 | 짧은 헤더, 빈 프레임, 크기 초과, 본문 누락, 잘못된 JSON·타입, 인코딩 실패 시 부분 쓰기 방지 | 11 |
| 프로필 파일 통합 테스트 | 삭제, 복원 위치의 하한·중간·상한, 활성 상태, 중복 복원, 연결 소유권·이름 캐시, 풍부한 설정의 파일 왕복과 훅 비활성화, 실패 시 원본·출력 보존 | 12 |

프로필 테스트는 실제 JSON 파일과 새 ProfileManager를 사용한다. 가져온 훅은 실행하지 않는다. AX 테스트는 작은 프레임을 미리 쓴 뒤 writer를 닫아 스케줄링에 의존하지 않는다. 시간 제한 테스트는 수동 Clock과 취소 가능한 신호를 사용하며 실제 시간 경과를 기다리지 않는다.

## 실행 결과

- 루트 `./test.command`: 정책 5개와 서명 회귀 검사 3개 통과.
- 패키지 전체: MenuBarModel 353개, ThawConcurrency 8개, ThawLayout 8개, ThawAX 46개, ThawCapture 51개, ThawUI 4개 통과.
- 새 AX·시간 제한 테스트와 프로필 저장 테스트를 각각 3회 반복하여 모두 통과했다.
- 앱 전체 재실행: 1,756개 중 1,755개 통과, 실패 0개, 건너뜀 1개.
- 초기 앱 기준선에서 AutomationSummaryTests/scriptPath가 한국어의 `없음`을 영어 `None`과 비교하여 실패했다. 테스트 기대값만 현재 언어의 표시 문구로 수정했다.
- 첫 변경 후 전체 실행에서 기존 ThawBarPresentationTests/coldFirstShow가 한 번 실패했다. 창 표시 상태가 false였다. 단독 실행과 다음 전체 실행에서는 통과했다. 추가 단독 3회와 전체 재실행도 모두 통과했다. 사용자 조작이 원인이었는지는 확정할 수 없다.
- strict SwiftLint: 659개 파일 위반 0개. actionlint는 기존 사용자 지정 runner `xcode-27`을 등록한 임시 설정으로 통과했다.
- 개발 대화 기록 없는 독립 리뷰: 조치 필요한 문제 없음. 리뷰 에이전트도 새 AX·시간 제한 테스트를 직접 실행했다.

재실행 명령:

```sh
./test.command
swift test --package-path upstream/ThawConcurrency --scratch-path build/PackageTests/ThawConcurrency --disable-xctest --enable-code-coverage --skip-update
swift test --package-path upstream/ThawAX --scratch-path build/PackageTests/ThawAX --disable-xctest --enable-code-coverage --skip-update
xcodebuild test -project upstream/Thaw.xcodeproj -scheme Thaw -destination 'platform=macOS' -derivedDataPath build/Coverage -resultBundlePath build/Coverage.xcresult -enableCodeCoverage YES CODE_SIGNING_ALLOWED=NO
```

앱 빌드 전에 프로젝트 고정 버전 SwiftLint가 PATH에 있어야 한다. 같은 명령으로 나머지 패키지도 실행했다. CI는 패키지별 원시 JSON 보고서를 7일간 보관하고 ThawUI의 CompactSlider revision이 앱 잠금 파일과 같은지 확인한다.

## Line / Branch Coverage

| 동일 범위 측정 | 개선 전 | 개선 후 |
|---|---:|---:|
| 앱 Sonar 대상 337개 파일 | 12,298 / 27,341 (44.98%) | 12,338 / 27,341 (45.13%) |
| ProfileManager | 289 / 1,006 (28.73%) | 329 / 1,006 (32.70%) |
| ThawConcurrency 자체 Sources | 129 / 166 (77.71%) | 159 / 166 (95.78%) |
| TaskTimeout | 0 / 31 (0%) | 30 / 31 (96.77%) |
| ThawAX 자체 Sources | 258 / 498 (51.81%) | 266 / 498 (53.41%) |
| AXWire | 67 / 80 (83.75%) | 75 / 80 (93.75%) |

나머지 패키지 자체 Sources는 전후 동일하다: MenuBarModel 55.98%, ThawLayout 15.52%, ThawCapture 16.75%, ThawUI 0%. ThawUI의 기존 테스트는 소스 스타일 검사이므로 UI 실행 커버리지를 만들지 않는다.

앱 수치는 CI와 같은 xcresultparser 2.0.1 XML을 정규화하고 기존 Sonar 범위로 필터링한 로컬 비교다. 파일 수와 분모를 고정했다. 공개 main의 마지막 Sonar 값 45.3%와는 실행 환경·실행 시점이 다르므로 직접 전후 비교하지 않는다. 패키지 수치는 앱 배지에 합산하지 않는다.

**Branch Coverage: 전후 모두 N/A.** 실제 생성 XML에는 조건별 속성이 없고 패키지 LLVM JSON의 branches.count도 0이다. 이를 0% 또는 완전 검증으로 해석하지 않는다. 위 조건 표가 이번에 검증한 분기 시나리오이며, 도구 교체는 하지 않았다.

## 별도로 재현한 기존 결함

### AXWire가 잘린 유효 JSON 본문을 허용함

`upstream/ThawAX/Sources/ThawAXCore/AXWire.swift:83`에서 본문 길이를 다시 확인하지 않는다. readExactly는 EOF에서 부분 데이터를 반환할 수 있다.

실제 Pipe에 바이트 `[0, 0, 0, 2, 49]`를 쓰고 writer를 닫은 뒤 Int로 읽으면 `declared=2 actual=1 result=Optional(1)`이다. 기대하는 프레임 오류 대신 유효 값으로 수락하여 잘못된 길이 선언을 놓친다. `.truncated` 기대의 실패 재현이며, 현재 동작을 정상으로 고정하는 테스트는 추가하지 않았다.

### manifest 기록 실패 후 프로필 이름이 부분 변경됨

`upstream/Thaw/Settings/Models/Profiles/ProfileManager.swift:556`에서 프로필 파일과 메모리를 변경한 뒤 564줄에서 manifest를 기록한다.

기존 fixture에서 profiles.json 바이트를 보관하고 해당 경로를 디렉터리로 바꾼 뒤 renameProfile을 호출하면 오류가 발생한다. 디렉터리를 지우고 원래 manifest를 복구한 새 manager에서는 목록의 이름은 `원본`이나 프로필 파일의 이름은 `실패한 이름 변경`이다. 기존 manager의 메모리도 새 이름으로 남는다. 임시 테스트에서 원상 보존 기대가 실패하는 것을 확인했다.

이 재현은 테스트용 UUID 폴더에서만 수행했다. 실패 테스트는 병합 대상 스위트에서 분리했다. 다른 CRUD의 유사 실패 가능성은 이번에 확정하지 않았으며, 트랜잭션·복구 정책을 포함한 프로덕션 수정은 후속 작업이다.

## 남은 범위와 정리

실제 메뉴 막대 이동·HID, AX helper 프로세스 왕복, 화면 캡처와 UI 렌더링의 실행 검증은 추가하지 않았다. 이 영역은 권한과 실시간 시스템 상태에 의존하므로 더미 호출로 커버리지를 채우지 않았다. 이번 변경은 테스트와 CI이므로 사용자 화면의 수동 조작 검증은 수행하지 않았다.

실행 중 생성된 UUID 테스트 preferences 473개를 실행 시간·테스트 접두어로 식별해 삭제하고 잔여 0개를 확인했다. 해당 UUID의 캐시·지원 폴더·HTTPStorages·저장 상태 및 새 프로필 임시 폴더도 남지 않았다. 작업용 앱의 LaunchServices 등록을 해제하고 빌드·도구·임시 재현 파일·패키지 생성 디렉터리를 제거했다. 보고서와 최소 검증 로그만 남겼다. 실제 설치된 Neat와 사용자 프로필은 정리 대상에서 제외했다. 새 권한이나 로그인 항목을 등록하지 않았다.
