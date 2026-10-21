#!/bin/bash
set -euo pipefail
neatRoot="$(cd "$(dirname "$0")" && pwd)"
cd "$neatRoot"
bash scripts/test-build-signing.sh
python3 scripts/test-release-metadata.py

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
developerPath="$(xcode-select -p)"
if [[ -z "${DEVELOPER_DIR:-}" && "$developerPath" == /Library/Developer/CommandLineTools ]]; then
    frameworkPath="$developerPath/Library/Developer/Frameworks"
    exec swift test --disable-xctest --scratch-path "$neatRoot/build/PolicyTests" \
        -Xswiftc -F -Xswiftc "$frameworkPath" \
        -Xlinker -F -Xlinker "$frameworkPath" \
        -Xlinker -rpath -Xlinker "$frameworkPath" \
        -Xlinker -rpath -Xlinker "$developerPath/Library/Developer/usr/lib"
fi
exec swift test --disable-xctest --scratch-path "$neatRoot/build/PolicyTests"
