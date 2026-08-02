#!/usr/bin/env bash

set -euo pipefail

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must point to the GitHub Actions output file}"

ESIGNER_VALUES=(
  "${ES_USERNAME:-}"
  "${ES_PASSWORD:-}"
  "${ES_TOTP_SECRET:-}"
  "${ES_PUBLISHER_NAME:-}"
)
AZURE_VALUES=(
  "${AZURE_TENANT_ID:-}"
  "${AZURE_CLIENT_ID:-}"
  "${AZURE_CLIENT_SECRET:-}"
  "${AZURE_CODE_SIGNING_ENDPOINT:-}"
  "${AZURE_CERTIFICATE_PROFILE_NAME:-}"
  "${AZURE_CODE_SIGNING_ACCOUNT_NAME:-}"
  "${AZURE_PUBLISHER_NAME:-}"
)

ESIGNER_SET=0
for VALUE in "${ESIGNER_VALUES[@]}"; do
  if [ -n "$VALUE" ]; then ESIGNER_SET=$((ESIGNER_SET + 1)); fi
done
AZURE_SET=0
for VALUE in "${AZURE_VALUES[@]}"; do
  if [ -n "$VALUE" ]; then AZURE_SET=$((AZURE_SET + 1)); fi
done
PFX_SET=0
if [ -n "${CSC_LINK:-}" ]; then PFX_SET=$((PFX_SET + 1)); fi
if [ -n "${CSC_KEY_PASSWORD:-}" ]; then PFX_SET=$((PFX_SET + 1)); fi

if [ "$ESIGNER_SET" -ne 0 ] && [ "$ESIGNER_SET" -ne "${#ESIGNER_VALUES[@]}" ]; then
  echo "::error::SSL.com eSigner is partially configured; all three ES_* secrets and ES_PUBLISHER_NAME are required."
  exit 1
fi
if [ "$AZURE_SET" -ne 0 ] && [ "$AZURE_SET" -ne "${#AZURE_VALUES[@]}" ]; then
  echo "::error::Azure Artifact Signing is partially configured; all three AZURE_* secrets and all four AZURE_* repository variables are required."
  exit 1
fi
if [ "$PFX_SET" -eq 1 ]; then
  echo "::error::PFX signing is partially configured; both WIN_CSC_LINK and WIN_CSC_KEY_PASSWORD are required."
  exit 1
fi

COMPLETE_MODES=0
SIGNING_MODE=""
if [ "$ESIGNER_SET" -eq "${#ESIGNER_VALUES[@]}" ]; then
  COMPLETE_MODES=$((COMPLETE_MODES + 1))
  SIGNING_MODE="esigner"
fi
if [ "$AZURE_SET" -eq "${#AZURE_VALUES[@]}" ]; then
  COMPLETE_MODES=$((COMPLETE_MODES + 1))
  SIGNING_MODE="azure"
fi
if [ "$PFX_SET" -eq 2 ]; then
  COMPLETE_MODES=$((COMPLETE_MODES + 1))
  SIGNING_MODE="pfx"
fi

if [ "$COMPLETE_MODES" -eq 0 ]; then
  if [ "${ALLOW_UNSIGNED_WINDOWS:-}" = "1" ]; then
    echo "::warning::No Windows signing identity configured; ALLOW_UNSIGNED_WINDOWS=1 is set, building UNSIGNED. Users will see SmartScreen warnings."
    echo "mode=unsigned" >> "$GITHUB_OUTPUT"
    echo "Selected unsigned build (explicit opt-in)."
    exit 0
  fi
  echo "::error::No trusted Windows signing identity is configured; refusing to build an unsigned public release. Set repo variable ALLOW_UNSIGNED_WINDOWS=1 to override."
  exit 1
fi
if [ "$COMPLETE_MODES" -ne 1 ]; then
  echo "::error::Multiple Windows signing modes are configured; select exactly one publisher identity."
  exit 1
fi

echo "mode=$SIGNING_MODE" >> "$GITHUB_OUTPUT"
echo "Selected $SIGNING_MODE signing."
