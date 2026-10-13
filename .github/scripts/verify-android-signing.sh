#!/usr/bin/env bash
set -euo pipefail

if [[ "${CI:-}" != true || -z "${RUNNER_TEMP:-}" ]]; then
  echo 'This signing smoke test runs only on an ephemeral CI runner.' >&2
  exit 1
fi
if [[ -e android/key.properties ]]; then
  echo 'Refusing to overwrite an existing android/key.properties.' >&2
  exit 1
fi

fixture_dir=$(mktemp -d "$RUNNER_TEMP/neural-idle-signing-test.XXXXXX")
cleanup() {
  rm -f -- android/key.properties "$fixture_dir/fixture.jks" \
    "$fixture_dir/fallback.log" "$fixture_dir/environment.log" \
    "$fixture_dir/local.log" "$fixture_dir/keytool.log" \
    "$RUNNER_TEMP/neural-idle-signing/release-keystore.jks"
  rmdir -- "$fixture_dir"
}
trap cleanup EXIT

signing_report() {
  (cd android && ./gradlew --no-daemon :app:signingReport --console=plain) > "$1" 2>&1 || {
    cat "$1"
    return 1
  }
}
release_block() {
  awk '/^Variant: release$/{found=1} found{print} found && /^----------/{exit}' "$1"
}

signing_report "$fixture_dir/fallback.log"
release_block "$fixture_dir/fallback.log" | grep -F 'Config: debug'

# Deliberately disposable fixture credentials, never a production signing key.
keytool -genkeypair -noprompt -storetype JKS -keyalg RSA -keysize 2048 \
  -validity 1 -alias ci-signing -dname 'CN=Neural Idle CI' \
  -keystore "$fixture_dir/fixture.jks" -storepass ci-fixture-only \
  -keypass ci-fixture-only > "$fixture_dir/keytool.log" 2>&1
fingerprint=$(keytool -J-Duser.language=en -J-Duser.country=US -list -v \
  -keystore "$fixture_dir/fixture.jks" -storepass ci-fixture-only \
  -alias ci-signing 2>/dev/null | sed -n 's/.*SHA256: //p')
test -n "$fingerprint"

export ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_BASE64=$(base64 -w 0 "$fixture_dir/fixture.jks")
export ANDROID_KEYSTORE_PASSWORD=ci-fixture-only
export ANDROID_KEY_ALIAS=ci-signing
export ANDROID_KEY_PASSWORD=ci-fixture-only
signing_report "$fixture_dir/environment.log"
release_block "$fixture_dir/environment.log" | grep -F 'Config: release'
release_block "$fixture_dir/environment.log" | grep -F "SHA-256: $fingerprint"

unset ANDROID_KEYSTORE_BASE64 ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD
printf 'storeFile=%s\nstorePassword=ci-fixture-only\nkeyAlias=ci-signing\nkeyPassword=ci-fixture-only\n' \
  "$fixture_dir/fixture.jks" > android/key.properties
signing_report "$fixture_dir/local.log"
release_block "$fixture_dir/local.log" | grep -F 'Config: release'
release_block "$fixture_dir/local.log" | grep -F "SHA-256: $fingerprint"
echo 'Verified debug fallback and matching release certificates for both signing sources.'
