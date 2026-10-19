#!/bin/bash
set -euo pipefail
umask 077
certificateName="Neat Local Development"
signingIdentity="$(security find-identity -v -p codesigning | awk -F '\"' '$2 == "Neat Local Development" { split($1, fields, " "); print fields[2] }')"
if [[ "$signingIdentity" =~ ^[0-9A-Fa-f]{40}$ ]]; then
    echo "기존 Neat 서명 인증서를 유지합니다: $signingIdentity"
    exit 0
fi
keychainPath="$(security default-keychain -d user | sed 's/^[[:space:]]*"//; s/"[[:space:]]*$//')"
[[ -f "$keychainPath" ]] || { echo "기본 사용자 키체인을 찾지 못했습니다." >&2; exit 1; }
workDir="$(mktemp -d)"
trap 'rm -rf "$workDir"' EXIT

if security find-certificate -c "$certificateName" -p "$keychainPath" > "$workDir/certificate.pem" 2>/dev/null; then
    echo "기존 인증서의 코드 서명 신뢰를 설정합니다. 새 키는 만들지 않습니다."
else
    cat > "$workDir/certificate.conf" <<'CONFIG'
[req]
distinguished_name = subject
x509_extensions = signing
prompt = no
[subject]
CN = Neat Local Development
[signing]
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CONFIG
    /usr/bin/openssl req -new -newkey rsa:3072 -nodes -x509 -sha256 -days 3650 \
        -config "$workDir/certificate.conf" -keyout "$workDir/key.pem" \
        -out "$workDir/certificate.pem" 2> "$workDir/openssl.log"
    /usr/bin/openssl rand -base64 32 > "$workDir/password"
    /usr/bin/openssl pkcs12 -export -inkey "$workDir/key.pem" -in "$workDir/certificate.pem" \
        -name "$certificateName" -passout "file:$workDir/password" -out "$workDir/identity.p12"
    # 개인 키는 사용자 키체인에만 보관하고 codesign에만 접근을 허용한다.
    security import "$workDir/identity.p12" -k "$keychainPath" -f pkcs12 -P "$(cat "$workDir/password")" -x -T /usr/bin/codesign
fi
# 사용자 영역의 코드 서명에만 신뢰를 부여한다.
security add-trusted-cert -r trustRoot -p codeSign -k "$keychainPath" "$workDir/certificate.pem"
signingIdentity="$(security find-identity -v -p codesigning | awk -F '\"' '$2 == "Neat Local Development" { split($1, fields, " "); print fields[2] }')"
[[ "$signingIdentity" =~ ^[0-9A-Fa-f]{40}$ ]] || { echo "서명 인증서가 하나로 확인되지 않습니다. 키체인의 인증서와 개인 키를 확인해 주세요." >&2; exit 1; }
echo "Neat 고정 서명 준비 완료: $signingIdentity"
