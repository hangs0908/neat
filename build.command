#!/bin/bash
set -euo pipefail
neatRoot="$(cd "$(dirname "$0")" && pwd)"
cd "$neatRoot"

# 같은 인증서를 유지해야 업데이트 후에도 macOS가 기존 권한을 연결할 수 있다.
signingIdentity="$(security find-identity -v -p codesigning | awk -F '\"' '$2 == "Neat Local Development" { split($1, fields, " "); print fields[2] }')"
if [[ ! "$signingIdentity" =~ ^[0-9A-Fa-f]{40}$ ]]; then
    echo "고정된 Neat 서명 인증서가 필요합니다. ./setup-signing.command를 먼저 실행해 주세요. 임시 서명으로 대체하지 않습니다." >&2
    exit 1
fi

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
if ! xcodebuild -version >/dev/null 2>&1; then
    echo "Xcode 27 이상이 필요합니다. /Applications/Xcode.app에 설치하고 최초 실행 설정을 완료해 주세요." >&2
    exit 1
fi

export PATH="$neatRoot/.tools/bin:$PATH"
lintVersion="$(cat upstream/.swiftlint-version)"
if ! command -v swiftlint >/dev/null || [[ "$(swiftlint version)" != "$lintVersion" ]]; then
    sh upstream/scripts/install-swiftlint.sh "$neatRoot/.tools/bin"
fi

mkdir -p build
echo "Neat을 빌드합니다. 로그: $neatRoot/build/build.log"
if ! xcodebuild -project upstream/Thaw.xcodeproj -scheme Thaw \
    -configuration Release -destination 'platform=macOS' \
    -derivedDataPath "$neatRoot/build/DerivedData" \
    -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates \
    "CONFIGURATION_BUILD_DIR=$neatRoot/build" \
    CODE_SIGNING_ALLOWED=NO build >build/build.log 2>&1; then
    tail -n 60 build/build.log >&2
    exit 1
fi

codesign --force --deep --sign "$signingIdentity" --timestamp=none --entitlements upstream/Thaw/Thaw.entitlements build/Neat.app
codesign --verify --deep --strict build/Neat.app
echo "빌드 완료: $neatRoot/build/Neat.app"
echo "Neat.app을 응용 프로그램 폴더로 복사한 뒤 실행해 주세요."
