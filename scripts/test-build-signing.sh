#!/bin/bash
set -euo pipefail
neatRoot="$(cd "$(dirname "$0")/.." && pwd)"
testDir="$(mktemp -d)"
trap 'rm -rf "$testDir"' EXIT
mkdir -p "$testDir/project/upstream" "$testDir/bin"
cp "$neatRoot/build.command" "$testDir/project/"
printf '1.0\n' > "$testDir/project/upstream/.swiftlint-version"
cat > "$testDir/bin/stub" <<'STUB'
#!/bin/bash
set -eu
commandName="${0##*/}"
printf '%s %s\n' "$commandName" "$*" >> "$TEST_COMMANDS"
case "$commandName" in
    security)
        if [[ "$TEST_SCENARIO" != missing ]]; then
            printf '  1) 0123456789ABCDEF0123456789ABCDEF01234567 "Neat Local Development"\n'
        fi
        ;;
    swiftlint) printf '1.0\n' ;;
    xcodebuild) exit 0 ;;
    codesign)
        if [[ "$TEST_SCENARIO" == signFailure && "$*" == *--sign* ]]; then exit 12; fi
        ;;
esac
STUB
chmod +x "$testDir/bin/stub"
for commandName in security swiftlint xcodebuild codesign; do
    ln -s stub "$testDir/bin/$commandName"
done
export TEST_COMMANDS="$testDir/commands"
for scenario in missing signed signFailure; do
    : > "$TEST_COMMANDS"
    status=0
    env PATH="$testDir/bin:$PATH" TEST_SCENARIO="$scenario" \
        /bin/bash "$testDir/project/build.command" > "$testDir/output" 2>&1 || status=$?
    case "$scenario" in
        missing)
            [[ "$status" -ne 0 ]] || { echo 'FAIL: 인증서 없이 빌드가 성공했습니다.'; exit 1; }
            ! grep -q 'codesign ' "$TEST_COMMANDS"
            ! grep -q 'xcodebuild ' "$TEST_COMMANDS"
            ;;
        signed)
            [[ "$status" -eq 0 ]]
            grep -q -- '--sign 0123456789ABCDEF0123456789ABCDEF01234567' "$TEST_COMMANDS"
            grep -q 'codesign --verify --deep --strict' "$TEST_COMMANDS"
            ;;
        signFailure)
            [[ "$status" -eq 12 ]]
            ! grep -q 'codesign --verify' "$TEST_COMMANDS"
            ! grep -q '빌드 완료' "$testDir/output"
            ;;
    esac
    ! grep -q -- '--sign - ' "$TEST_COMMANDS"
done
echo '서명 회귀 검사 3건 통과: 인증서 누락 차단, 고정 인증서 사용, 서명 실패 전파'
