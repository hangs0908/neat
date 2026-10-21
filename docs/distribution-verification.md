# 배포·업데이트 검증 기록

2026-10-21, macOS 27.0.1(26A434), Apple Silicon, Xcode 27.1에서 수행했다. 구현 커밋은 `e6eed05`이며 아래 기록은 공개 배포 완료 판정이 아니다.

## 자동 검사

| 검사 | 결과 |
| --- | --- |
| `./test.command` | 로컬 서명 회귀 3건, 릴리스 메타데이터 3건, Swift 정책 5건 통과 |
| 선택한 네이티브 테스트 | AutomaticUpdatesTests·SettingsProcessAppSideTests·LaunchAtLoginSettingTests·ThawBarOutsideClickTests·LayoutBarKeyboardTests 총 37회 통과 |
| `sh upstream/scripts/lint.sh --strict` | 659파일, 위반 0건 |
| 수정 Swift 파일 SwiftFormat | 수정 내용 형식 검사 통과. AppState의 기존 한 줄 조건문은 포맷 시 기존 길이 기준선을 벗어나므로 무관한 포맷 변경을 보존하지 않았다. |
| ShellCheck·`bash -n` | 배포 빌드 스크립트 통과 |
| Actionlint | 워크플로 통과. 설치 버전이 최신 공식 runner `xcode-27`을 몰라 해당 라벨 경고만 제외하고 검사했다. 기존 CI도 같은 runner를 사용한다. |
| Release 빌드·서명 | `scripts/build-release.sh` 실제 실행 성공. arm64, 0.1.0, build 116, GitCommitSHA e6eed05. 자체 서명·deep strict 서명 검증·EdDSA ZIP 서명·앱캐스트·cask 생성 성공 |

원시 로그는 작업 디렉터리의 `build/verification/`과 `build/release-build.log`에 있다. 네이티브 테스트 결과는 `build/DerivedData/Logs/Test/`의 xcresult에도 있다. 로그와 배포 파일은 Git에 넣지 않았다.

## 독립 코드 리뷰

별도 에이전트에 개발 대화 기록 없이 요구사항과 `446bcfe..3a2a04c` diff를 전달했다. 리뷰 중 코드를 수정하지 않았다. 별도 설정 프로세스에서 동의해도 본체 updater가 시작되지 않는 문제 1건을 보고했다.

`remoteConsentStartsUpdater`와 `forwardingProcessDoesNotStartUpdater`가 수정 전 실패하는 것을 확인했고, `e6eed05`에서 본체가 동의 변경에 따라 시작하고 별도 설정 프로세스는 대신 시작하지 않도록 수정했다. 수정 후 위 37회 테스트가 통과했다. 그 밖의 검토 범위에서 리뷰 에이전트가 확정한 추가 버그·회귀·보안 문제는 없었다. 수정 뒤 추가 독립 재리뷰를 수행했다고 주장하지 않는다.

## 실제 조작

Homebrew는 임시 tap `neat-tests/rehearsal`과 `build/InstalledApps`를 사용했다. 최종 배포 스크립트로 만든 실제 Release ZIP에서 cask를 생성하고 로컬 파일 URL로 설치했다. 설치·앱 복사·체크섬·macOS 27 및 arm64 조건 확인과 제거가 성공했다. 임시 tap과 설치 앱을 제거하고 개발자 모드 변경을 복원했다. 공개 GitHub 다운로드·격리 속성에 따른 Gatekeeper 최초 실행은 이 검사로 대체하지 않는다.

GUI는 실제 최신 Debug 모듈의 `SettingsWindow`, 동의 시트, `SimpleModeSettingsPane`, `UpdatesManager`와 Sparkle을 별도 진입점으로 실행했다. 테스트 식별자는 `local.hangjin.Neat.UpdateTest`다. 전체 메뉴 막대 초기화와 로그인 항목 등록을 실행하지 않아 기존 사용자 메뉴 배치·설정·앱·권한을 건드리지 않았다. 서버는 127.0.0.1에만 바인딩했다. 운영 피드와 운영 앱 식별자는 변경하지 않았다.

| 직접 수행한 조작 | 관찰 결과 |
| --- | --- |
| 동의 시트에서 ‘수동으로 확인’ 클릭 | 자동 확인 스위치 꺼짐, 수동 확인 버튼 활성 |
| 서버가 404인 상태에서 ‘업데이트 확인…’ 클릭 | 오류 대화상자 표시. 닫은 뒤 기존 앱 사용 가능 |
| 서명된 0.1.1 피드에서 수동 확인 | 현재 0.1.0과 새 0.1.1을 표시. 설치 선택 전 서버에는 앱캐스트 요청만 있고 ZIP 요청은 없었음 |
| ‘업데이트 설치’ 클릭 | ZIP 다운로드·검증·압축 해제 후 ‘설치 & 재실행’ 버튼 표시 |
| 위 버튼을 누르기 전 번들 확인 | 여전히 build 116, 자동 확인 설정 꺼짐 |
| ‘설치 & 재실행’ 클릭 | 기존 프로세스 종료·새 프로세스 실행. 설정에 0.1.1, 번들에 build 117 확인. 자동 확인 꺼짐 유지 |
| 설정 스위치 켜기·끄기 | 실제 화면과 저장값이 일치 |
| 테스트 동의 상태를 비우고 ‘자동으로 확인’ 클릭 | 자동 확인 스위치 켜짐 |
| 업데이트 후 수동 확인 | ‘0.1.1이 현재 최신 버전’ 안내 |
| 0.1.2 ZIP을 서명한 뒤 일부를 변조하고 설치 선택 | ‘업데이트가 잘못 서명되어 유효성 검사를 할 수 없습니다’ 안내. 기존 0.1.1 유지 |

CUA로 동의 시트·업데이트 안내·변조 거부 화면을 캡처했고 접근성 트리에서 버튼 상태와 버전을 확인했다. 이는 자동 테스트 결과와 구분되는 실제 클릭 검사다. 테스트 전용 환경을 사용했으므로 전체 앱의 최초 권한 부여 흐름을 검증한 것으로 간주하지 않는다.

## 남은 검증과 배포 조건

- 테스트 앱에 새 손쉬운 사용·화면 기록 권한을 부여하는 승인을 요청했다. 승인 전에는 권한 부여와 업데이트 후 권한 유지 검증을 진행하지 않는다. 기존 Neat 권한을 초기화해 대신 검사하지 않는다.
- 공개 릴리스 전 초안 비노출, 공개 후 GitHub 피드 다운로드, 공개 이벤트의 tap PR 생성, 실제 공개 파일의 최초 설치를 확인해야 한다. 이번 작업에서는 태그·공개 릴리스·main 병합을 실행하지 않는다.
- Actions secrets 3개는 해당 저장소에 등록했다. 키·인증서는 저장소 밖 `~/Library/Application Support/NeatRelease/`에 보관한다.
- 저장소의 Actions PR 생성·승인 허용 설정은 현재 꺼져 있다. tap PR 자동 생성에는 설정 변경이 필요하며, 임의로 봇 승인 권한을 확장하지 않았다.
- 고정 PlatformRuntimeKit 수정본 배포에 필요한 서면 허가는 확인되지 않았다. [배포 운영 문서](distribution.md)를 따른다.
- 전체 upstream 네이티브 테스트·SonarCloud 80% 신규 커버리지·원격 CI 통과는 위 로컬 검사로 대체하지 않는다.
