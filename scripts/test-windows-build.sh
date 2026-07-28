#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER="$SCRIPT_DIR/build-windows-release.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/aios-windows-build.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

mkdir -p "$TEST_ROOT/bin"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$TEST_ROOT/bin/npm"
# shellcheck disable=SC2016 # The generated stub must expand these at runtime.
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$@" > "$ARGS_OUT"' > "$TEST_ROOT/bin/npx"
chmod +x "$TEST_ROOT/bin/npm" "$TEST_ROOT/bin/npx"

run_build() {
  : > "$TEST_ROOT/output"
  : > "$TEST_ROOT/args"
  env -i \
    PATH="$TEST_ROOT/bin:$PATH" \
    GITHUB_OUTPUT="$TEST_ROOT/output" \
    ARGS_OUT="$TEST_ROOT/args" \
    "$@" \
    "$BUILDER" >/dev/null
}

expect_build_failure() {
  if run_build "$@" 2>/dev/null; then
    echo "Expected Windows build argument validation to fail." >&2
    return 1
  fi
}

run_build \
  RELEASE_TAG=v9.9.9-beta \
  SIGNING_MODE=esigner \
  ESIGNER_CERT_THUMBPRINT=ABC123 \
  ESIGNER_PUBLISHER_DN="CN=SAPHAARE LABS PRIVATE LIMITED, O=SAPHAARE LABS PRIVATE LIMITED, C=IN"
grep -Fxq -- "-c.publish.channel=beta" "$TEST_ROOT/args"
grep -Fxq -- "-c.win.signtoolOptions.certificateSha1=ABC123" "$TEST_ROOT/args"
grep -Fxq -- "-c.win.signtoolOptions.publisherName=CN=SAPHAARE LABS PRIVATE LIMITED, O=SAPHAARE LABS PRIVATE LIMITED, C=IN" "$TEST_ROOT/args"
grep -Fxq -- "-c.win.signtoolOptions.rfc3161TimeStampServer=http://ts.ssl.com" "$TEST_ROOT/args"
grep -Fxq "mode=esigner" "$TEST_ROOT/output"

run_build \
  RELEASE_TAG=v9.9.9 \
  SIGNING_MODE=azure \
  AZURE_CODE_SIGNING_ENDPOINT=https://example.codesigning.azure.net \
  AZURE_CERTIFICATE_PROFILE_NAME=profile \
  AZURE_CODE_SIGNING_ACCOUNT_NAME=account \
  AZURE_PUBLISHER_NAME=publisher
grep -Fxq -- "-c.win.azureSignOptions.endpoint=https://example.codesigning.azure.net" "$TEST_ROOT/args"
grep -Fxq -- "-c.forceCodeSigning=true" "$TEST_ROOT/args"

run_build \
  RELEASE_TAG=v9.9.9 \
  SIGNING_MODE=pfx \
  CSC_LINK=base64 \
  CSC_KEY_PASSWORD=password
grep -Fxq -- "-c.forceCodeSigning=true" "$TEST_ROOT/args"
if grep -Fq -- "-c.win.azureSignOptions" "$TEST_ROOT/args" ||
   grep -Fq -- "-c.win.signtoolOptions" "$TEST_ROOT/args"; then
  echo "PFX mode leaked another signing mode's arguments." >&2
  exit 1
fi

expect_build_failure RELEASE_TAG=v9.9.9 SIGNING_MODE=unknown
expect_build_failure RELEASE_TAG=v9.9.9 SIGNING_MODE=esigner
expect_build_failure RELEASE_TAG=v9.9.9 SIGNING_MODE=azure
expect_build_failure RELEASE_TAG=v9.9.9 SIGNING_MODE=pfx

echo "Seven Windows build-argument cases passed."
