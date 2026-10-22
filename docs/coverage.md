# 테스트 커버리지 배지

README의 배지는 SonarQube Cloud 프로젝트 `hangs0908_neat`의 최신 분석 값을 표시합니다. 원본 Thaw의 수치를 사용하지 않습니다.

## 최초 연결

1. [SonarQube Cloud](https://sonarcloud.io)에 GitHub 계정으로 로그인합니다.
2. `hangs0908` 계정의 `neat` 저장소를 가져와 공개 프로젝트를 만듭니다. 조직 키는 `hangs0908`, 프로젝트 키는 `hangs0908_neat`을 사용합니다. 실제 키가 다르면 `upstream/sonar-project.properties`와 README 배지 URL을 함께 변경합니다.
3. 분석 방법은 GitHub Actions를 선택하고, 자동 분석이 켜져 있으면 끕니다. 커버리지 보고서는 CI 기반 분석으로만 가져올 수 있습니다.
4. 분석 권한이 있는 Sonar 토큰을 생성하고 GitHub 저장소의 `Settings → Secrets and variables → Actions`에 `SONAR_TOKEN`이라는 저장소 시크릿으로 등록합니다. 토큰을 코드·문서·로그에 넣지 않습니다.
5. 이 변경을 승인 후 `main`에 병합하면 첫 분석이 실행됩니다. 이후 필요하면 `Actions → 테스트 커버리지 → Run workflow`에서 `main`을 선택해 다시 실행합니다.

SonarQube 분석이 성공하기 전에는 배지에 정상적인 퍼센트가 표시되지 않을 수 있습니다. 배지를 클릭하면 Neat의 커버리지 상세 페이지로 이동합니다.

## 실행 범위

- PR: 정책 테스트·서명 회귀 검사, 전체 앱의 `Thaw` 스킴 테스트, 커버리지 XML 생성을 실행합니다. Sonar 토큰을 사용하지 않습니다.
- `main` push 및 수동 실행: 같은 검사를 실행한 후 SonarQube Cloud에 결과를 업로드합니다. 일반적인 재실행은 `main`에서 합니다.
- Xcode 27.1과 macOS 27을 제공하는 GitHub 호스팅 `xcode-27` 러너를 사용합니다.
- 커버리지는 Xcode 앱 테스트에서 생성합니다. 루트 `NeatPolicy` 패키지 테스트는 별도로 실행하며, 그 실행 결과를 XML에 합산하지 않습니다.
- 측정 대상과 제외 목록은 `upstream/sonar-project.properties`를 따릅니다. 실제 메뉴 막대·권한이 필요한 일부 코드는 원본부터 제외되어 있으므로, 배지 값은 앱 전체 코드의 실행 비율과 다를 수 있습니다.
- `coverage-report` 아티팩트는 7일간 보관합니다. 보고서 생성·경로 변환 실패 시 분석을 진행하지 않으며, 이전 보고서로 대체하지 않습니다.

GitHub의 테스트 성공과 Sonar 품질 게이트 통과는 별개입니다. 이 워크플로는 분석 결과를 업로드하며, 품질 게이트 통과를 기다리는 병합 차단 조건은 설정하지 않습니다.

## 검증

로컬에서는 `./test.command`로 정책 테스트와 서명 회귀 검사를 실행합니다. 전체 앱 테스트는 앱 실행과 사용자 상태에 영향을 줄 수 있어 이 작업에서는 일회성 GitHub 러너에서 검증합니다.

실제 연결 확인은 GitHub Actions의 성공, Sonar 프로젝트의 분석 시각·커버리지 값, README 배지 표시와 클릭 이동을 각각 확인합니다. 로그인·프로젝트 등록·토큰 설정이나 첫 분석이 남아 있으면 배지 연동 완료로 간주하지 않습니다.
