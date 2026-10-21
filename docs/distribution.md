# 배포 운영

최초 버전은 0.1.0, macOS 27 이상·Apple Silicon용이다. 무료 표준 GitHub Actions runner인 `xcode-27`과 GitHub Releases를 사용한다. 별도 서버·도메인·Developer Program 가입을 전제로 하지 않는다. 공증된 앱이 아니므로 최초 실행에서 macOS의 개별 허용 절차가 필요할 수 있다.

## 배포 전에 확인할 조건

Neat 앱 소스의 GPL과 PlatformRuntimeKit의 라이선스는 별개다. 고정 의존성은 `prk-bin` 1.1.3, 커밋 `02aef190686665e1f01cb3c33e4ce164c1ea4699`이다. 해당 [라이선스 제2항](https://github.com/thaw-app/prk-bin/blob/02aef190686665e1f01cb3c33e4ce164c1ea4699/LICENSE)은 수정한 Thaw 앱 배포에 원저작자의 서면 허가를 요구한다. 비영리 예외는 명시되어 있지 않다. GPL의 추가 허용 조항만으로 이 조건이 해결되었다고 간주하지 않는다. 서면 허가 근거는 이 작업에서 확인하지 못했다.

공개 배포 전에 재배포 권한, 자동 테스트·독립 리뷰·실제 설치 및 업데이트 검증, 최신 PR 승인·CI 통과를 확인한다. 개인 키와 인증서의 비밀 부분을 공개 저장소나 배포 파일에 포함하지 않는다.

## 키와 인증서

앱 서명에는 모든 버전에서 같은 자체 서명 코드 서명 인증서를 사용한다. 키가 바뀌면 기존 권한 연결이 끊길 수 있다. 현재 로컬 개발용 인증서를 배포용으로 무조건 재사용하지 말고 전용 인증서와 개인 키를 PKCS#12 파일로 준비해 안전하게 백업한다. 앱은 Apple Developer ID로 서명·공증한 것으로 표시하지 않는다.

Sparkle 업데이트 키는 앱 인증서와 별개다. 앱에 포함된 공개 키와 맞는 개인 키가 필요하다. 키를 잃으면 공증 없는 기존 앱에 새 키로 자동 업데이트를 전달하지 못할 수 있다. 최초 공개 전에 암호화한 오프라인 백업을 준비한다.

이번 구현용 Sparkle 개인 키는 저장소 밖의 `~/Library/Application Support/NeatRelease/sparkle.key`에 저장했다. 저장소에는 공개 키만 포함한다. 이 파일의 내용은 채팅·로그·PR에 붙이지 않는다.

저장소 Actions secrets에 다음을 설정한다.

| 이름 | 값 |
| --- | --- |
| `NEAT_SIGNING_P12_BASE64` | 고정 배포 인증서와 개인 키가 든 PKCS#12 파일의 Base64 |
| `NEAT_SIGNING_PASSWORD` | 위 파일의 암호 |
| `SPARKLE_PRIVATE_KEY` | Sparkle 개인 키 파일 내용 |

`scripts/build-release.sh`는 이를 임시 키체인으로 읽고, 실패 시 중단하며, 종료 시 임시 키체인을 삭제한다. 업데이트 키와 앱 공개 키가 일치하는지도 검사한다. 사용자 로그인 키체인의 인증서를 교체하거나 기존 앱 권한을 초기화하지 않는다.

## 초안에서 공개까지

1. 변경 PR을 검증하고 사용자가 승인한 후 main에 병합한다.
2. main의 승인된 커밋에 `v0.1.0` 같은 버전 태그를 push한다. 태그를 변경하거나 재사용하지 않는다.
3. `Neat 릴리스 초안` 워크플로가 정적 검사·정책 테스트·네이티브 업데이트 테스트를 실행하고 arm64 Release 앱을 빌드한다. 빌드 번호는 워크플로 실행 번호에 115를 더해 증가시킨다. 같은 릴리스의 재실행은 기존 초안을 조용히 덮어쓰지 않는다.
4. 고정 인증서로 앱을 서명하고 ZIP을 만든다. ZIP에 EdDSA 서명을 생성하고 `appcast.xml`과 `neat.rb`를 만든 뒤, 세 파일을 비공개 릴리스 초안에 첨부한다.
5. 초안 파일로 실제 설치·업데이트·권한 유지·실패 복구를 검증한다. **설치 선택 전에는 앱 교체나 재실행이 없어야 한다.** Sparkle 기본 UI는 다운로드 선택과 설치·재실행 선택을 단계별로 표시할 수 있으며, 무인 설치는 허용하지 않는다.
6. 릴리스 내용을 직접 확인해 GitHub에서 공개한다. 이 단계 전에는 사용자에게 알리지 않는다. 공개할 버전은 기존 공개 버전보다 높은 버전·빌드 번호를 사용하고 최신 릴리스로 지정한다. 과거 버전을 최신 릴리스로 바꾸지 않는다.
7. 공개 후 `releases/latest/download/appcast.xml`에서 업데이트를 확인할 수 있다. 공개 이벤트는 공개 ZIP과 앱캐스트에서 cask를 다시 생성해 `release/homebrew-v…` 브랜치의 PR을 만든다. main에 직접 push하거나 자동 병합하지 않는다.
8. Homebrew 설치를 검증한 뒤 해당 PR을 승인·병합하면 tap이 갱신된다. Actions의 PR 생성 권한이 꺼져 있으면 저장소 설정에서 허용하거나 생성된 cask로 수동 PR을 만든다. `GITHUB_TOKEN`으로 만든 PR의 CI는 자동 실행되지 않을 수 있으므로 별도로 확인한다.

앱 자체 업데이트와 Homebrew는 같은 ZIP을 사용한다. 자체 업데이트를 지원하므로 cask는 `auto_updates true`를 선언한다. 초안 파일은 공개 전에는 익명 다운로드 경로로 접근할 수 없다. 공개 저장소의 워크플로 로그에 비밀 값이 남지 않도록 셸 추적을 켜지 않는다.

## Homebrew 설치 경로

별도 tap 저장소·토큰을 추가하지 않고 이 저장소의 `Casks/neat.rb`를 사용한다. 최초 릴리스와 cask PR 병합 후 다음 명령이 유효해진다. 그전에는 배포 준비 중이다.

```sh
brew tap hangs0908/neat https://github.com/hangs0908/neat
brew install --cask hangs0908/neat/neat
```

업데이트는 앱에서 확인하거나 `brew upgrade --cask hangs0908/neat/neat`로 수행한다. 앱은 brew 명령을 대신 실행하지 않는다. 서명하지 않은 다른 파일로 cask의 체크섬을 대체하거나 Gatekeeper를 전역 비활성화하는 설치 스크립트를 추가하지 않는다.

## 로컬 배포 파일 생성

정확한 키·인증서를 준비한 환경에서 아래 변수를 설정하고 실행한다. 암호나 개인 키 내용을 터미널 명령 기록에 직접 입력하지 않는다.

```sh
export NEAT_SIGNING_P12=/안전한/경로/neat-signing.p12
export SPARKLE_KEY_FILE="$HOME/Library/Application Support/NeatRelease/sparkle.key"
export RELEASE_VERSION=0.1.0
export BUILD_NUMBER=116
# NEAT_SIGNING_PASSWORD는 안전한 비밀 저장소에서 환경 변수로 전달한다.
bash scripts/build-release.sh
```

산출물은 `build/release/`에 생성된다. 빌드 로그는 `build/release-build.log`에 남는다. 일반 개인 개발 빌드는 기존 `./setup-signing.command`, `./build.command` 흐름을 유지한다.
