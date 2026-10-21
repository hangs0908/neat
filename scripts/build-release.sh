#!/bin/bash
set -euo pipefail
neatRoot="$(cd "$(dirname "$0")/.." && pwd)"
cd "$neatRoot"

: "${NEAT_SIGNING_P12:?고정된 배포 인증서 파일이 필요합니다.}"
: "${NEAT_SIGNING_PASSWORD:?배포 인증서 암호가 필요합니다.}"
: "${SPARKLE_KEY_FILE:?업데이트 서명 키 파일이 필요합니다.}"
: "${RELEASE_VERSION:?공개 버전이 필요합니다.}"
: "${BUILD_NUMBER:?증가하는 빌드 번호가 필요합니다.}"
[[ "$RELEASE_VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]
[[ -s "$NEAT_SIGNING_P12" && -s "$SPARKLE_KEY_FILE" ]]
[[ "$(uname -m)" == arm64 ]]

signingDir="$(mktemp -d)"
keychain="$signingDir/release.keychain-db"
cleanup() {
    security delete-keychain "$keychain" >/dev/null 2>&1 || true
    rm -rf "$signingDir"
}
trap cleanup EXIT
keychainPassword="$(/usr/bin/openssl rand -hex 24)"
security create-keychain -p "$keychainPassword" "$keychain"
security unlock-keychain -p "$keychainPassword" "$keychain"
security import "$NEAT_SIGNING_P12" -k "$keychain" -P "$NEAT_SIGNING_PASSWORD" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychainPassword" "$keychain" >/dev/null
signingIdentity="$(/usr/bin/openssl pkcs12 -in "$NEAT_SIGNING_P12" -passin env:NEAT_SIGNING_PASSWORD -clcerts -nokeys |
    /usr/bin/openssl x509 -noout -fingerprint -sha1 | tr -d ':' | cut -d= -f2)"
[[ "$signingIdentity" =~ ^[0-9A-Fa-f]{40}$ ]]

mkdir -p build/release
xcodebuild build -project upstream/Thaw.xcodeproj -scheme Thaw \
    -configuration Release -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath build/ReleaseDerivedData \
    -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates \
    CONFIGURATION_BUILD_DIR="$neatRoot/build/release" \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO \
    MARKETING_VERSION="$RELEASE_VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    >build/release-build.log 2>&1
appPath="$neatRoot/build/release/Neat.app"
publicKey="$(swift -e 'import CryptoKit; import Foundation; let seed = Data(base64Encoded: try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8))!; print(try Curve25519.Signing.PrivateKey(rawRepresentation: seed).publicKey.rawRepresentation.base64EncodedString())' "$SPARKLE_KEY_FILE")"
[[ "$publicKey" == "$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$appPath/Contents/Info.plist")" ]]
codesign --force --deep --sign "$signingIdentity" --keychain "$keychain" --timestamp=none \
    --entitlements upstream/Thaw/Thaw.entitlements "$appPath"
codesign --verify --deep --strict "$appPath"
[[ "$(lipo -archs "$appPath/Contents/MacOS/Neat")" == arm64 ]]

sparkleBin="$neatRoot/build/ReleaseDerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin"
archive="$neatRoot/build/release/Neat-$RELEASE_VERSION.zip"
ditto -c -k --sequesterRsrc --keepParent "$appPath" "$archive"
signature="$("$sparkleBin/sign_update" --ed-key-file "$SPARKLE_KEY_FILE" -p "$archive")"
python3 scripts/release-metadata.py create "$archive" "$RELEASE_VERSION" "$BUILD_NUMBER" "$signature"
echo "배포 초안 파일 준비 완료: build/release (공증되지 않은 앱)"
