#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELECTOR="$SCRIPT_DIR/select-windows-signing-mode.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/aios-signing-mode.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

expect_success() {
  local expected_mode="$1"
  shift
  : > "$TEST_ROOT/output"
  env -i PATH="$PATH" GITHUB_OUTPUT="$TEST_ROOT/output" "$@" "$SELECTOR" >/dev/null
  grep -Fxq "mode=$expected_mode" "$TEST_ROOT/output"
}

expect_failure() {
  : > "$TEST_ROOT/output"
  if env -i PATH="$PATH" GITHUB_OUTPUT="$TEST_ROOT/output" "$@" "$SELECTOR" >/dev/null 2>&1; then
    echo "Expected selector failure, but it passed." >&2
    return 1
  fi
}

expect_failure
expect_failure ES_USERNAME=user
expect_failure AZURE_TENANT_ID=tenant
expect_failure CSC_LINK=base64
expect_success esigner \
  ES_USERNAME=user \
  ES_PASSWORD=pass \
  ES_TOTP_SECRET=totp \
  ES_PUBLISHER_NAME="SAPHAARE LABS PRIVATE LIMITED"
expect_success azure \
  AZURE_TENANT_ID=tenant \
  AZURE_CLIENT_ID=client \
  AZURE_CLIENT_SECRET=secret \
  AZURE_CODE_SIGNING_ENDPOINT=https://example.codesigning.azure.net \
  AZURE_CERTIFICATE_PROFILE_NAME=profile \
  AZURE_CODE_SIGNING_ACCOUNT_NAME=account \
  AZURE_PUBLISHER_NAME=publisher
expect_success pfx CSC_LINK=base64 CSC_KEY_PASSWORD=secret
expect_failure \
  ES_USERNAME=user \
  ES_PASSWORD=pass \
  ES_TOTP_SECRET=totp \
  ES_PUBLISHER_NAME=publisher \
  AZURE_TENANT_ID=tenant \
  AZURE_CLIENT_ID=client \
  AZURE_CLIENT_SECRET=secret \
  AZURE_CODE_SIGNING_ENDPOINT=https://example.codesigning.azure.net \
  AZURE_CERTIFICATE_PROFILE_NAME=profile \
  AZURE_CODE_SIGNING_ACCOUNT_NAME=account \
  AZURE_PUBLISHER_NAME=publisher
expect_failure \
  ES_USERNAME=user \
  ES_PASSWORD=pass \
  ES_TOTP_SECRET=totp \
  ES_PUBLISHER_NAME=publisher \
  CSC_LINK=base64 \
  CSC_KEY_PASSWORD=secret

echo "Nine Windows signing-mode cases passed."
