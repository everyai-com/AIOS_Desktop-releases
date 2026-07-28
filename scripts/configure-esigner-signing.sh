#!/usr/bin/env bash
#
# Configure the exact SSL.com eSigner inputs consumed by release.yml.
# Secret values are read from hidden prompts (or pre-set AIOS_ES_* env
# variables), streamed to `gh secret set` over stdin, and never written to disk
# or placed in command arguments.

set -euo pipefail

REPO="everyai-com/AIOS_Desktop-releases"
DRY_RUN=0
ASSUME_YES=0

usage() {
  echo "Usage: $0 [--repo OWNER/REPO] [--dry-run] [--yes]"
  echo
  echo "Run only after an SSL.com code-signing certificate is validated,"
  echo "enrolled in eSigner, and automated TOTP is enabled."
  echo
  echo "Optional pre-set inputs (useful for a dry-run):"
  echo "  AIOS_ES_USERNAME"
  echo "  AIOS_ES_PASSWORD"
  echo "  AIOS_ES_TOTP_SECRET"
  echo "  AIOS_ES_PUBLISHER_NAME"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)
      [ "$#" -ge 2 ] || { echo "Missing value for --repo" >&2; exit 2; }
      REPO="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --yes)
      ASSUME_YES=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

command -v gh >/dev/null 2>&1 || {
  echo "GitHub CLI (gh) is required." >&2
  exit 1
}
gh auth status >/dev/null

SECRET_NAMES="$(gh secret list --repo "$REPO" --json name --jq '.[].name')"
VARIABLE_NAMES="$(gh variable list --repo "$REPO" --json name --jq '.[].name')"
if grep -Eq '^(WIN_CSC_LINK|WIN_CSC_KEY_PASSWORD|AZURE_TENANT_ID|AZURE_CLIENT_ID|AZURE_CLIENT_SECRET)$' <<<"$SECRET_NAMES" ||
   grep -Eq '^(AZURE_CODE_SIGNING_ENDPOINT|AZURE_CERTIFICATE_PROFILE_NAME|AZURE_CODE_SIGNING_ACCOUNT_NAME|AZURE_PUBLISHER_NAME)$' <<<"$VARIABLE_NAMES"; then
  echo "Another Windows signing mode already has inputs on $REPO." >&2
  echo "Remove every input for that mode before configuring eSigner." >&2
  exit 1
fi

prompt_value() {
  local label="$1"
  local variable_name="$2"
  local current_value="${!variable_name-}"
  if [ -z "$current_value" ]; then
    IFS= read -r -p "$label: " current_value
    printf -v "$variable_name" '%s' "$current_value"
  fi
}

prompt_secret() {
  local label="$1"
  local variable_name="$2"
  local current_value="${!variable_name-}"
  if [ -z "$current_value" ]; then
    IFS= read -r -s -p "$label: " current_value
    echo >&2
    printf -v "$variable_name" '%s' "$current_value"
  fi
}

prompt_value "SSL.com account username" AIOS_ES_USERNAME
prompt_secret "SSL.com account password" AIOS_ES_PASSWORD
prompt_secret "SSL.com automated TOTP secret" AIOS_ES_TOTP_SECRET
prompt_value "Certificate publisher simple name" AIOS_ES_PUBLISHER_NAME

trap 'unset AIOS_ES_PASSWORD AIOS_ES_TOTP_SECRET' EXIT

for VARIABLE_NAME in \
  AIOS_ES_USERNAME \
  AIOS_ES_PASSWORD \
  AIOS_ES_TOTP_SECRET \
  AIOS_ES_PUBLISHER_NAME; do
  VALUE="${!VARIABLE_NAME}"
  if [ -z "$VALUE" ] || [[ "$VALUE" == *$'\n'* ]] || [[ "$VALUE" == *$'\r'* ]]; then
    echo "$VARIABLE_NAME must be one non-empty line." >&2
    exit 1
  fi
done
if [ "${#AIOS_ES_PUBLISHER_NAME}" -lt 2 ]; then
  echo "Certificate publisher simple name is too short." >&2
  exit 1
fi

if [ "$ASSUME_YES" -ne 1 ]; then
  IFS= read -r -p "Configure SSL.com eSigner on $REPO? Type CONFIGURE: " CONFIRMATION
  [ "$CONFIRMATION" = "CONFIGURE" ] || {
    echo "No changes made."
    exit 0
  }
fi

set_secret() {
  local name="$1"
  local value="$2"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] would set secret $name"
  else
    printf '%s' "$value" | gh secret set "$name" --repo "$REPO"
  fi
}

set_variable() {
  local name="$1"
  local value="$2"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] would set variable $name"
  else
    printf '%s' "$value" | gh variable set "$name" --repo "$REPO"
  fi
}

set_secret ES_USERNAME "$AIOS_ES_USERNAME"
set_secret ES_PASSWORD "$AIOS_ES_PASSWORD"
set_secret ES_TOTP_SECRET "$AIOS_ES_TOTP_SECRET"
set_variable ES_PUBLISHER_NAME "$AIOS_ES_PUBLISHER_NAME"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry-run passed. GitHub was not changed."
  exit 0
fi

SECRET_NAMES="$(gh secret list --repo "$REPO" --json name --jq '.[].name')"
VARIABLE_NAMES="$(gh variable list --repo "$REPO" --json name --jq '.[].name')"
for NAME in ES_USERNAME ES_PASSWORD ES_TOTP_SECRET; do
  grep -Fxq "$NAME" <<<"$SECRET_NAMES"
done
grep -Fxq ES_PUBLISHER_NAME <<<"$VARIABLE_NAMES"

echo "SSL.com eSigner inputs are configured on $REPO."
echo "The next release still fails closed unless SSL.com has validated the"
echo "certificate, enabled eSigner automation, and the publisher name matches."
