#!/usr/bin/env bash
#
# Configure the exact Azure Trusted Signing inputs consumed by release.yml.
# Secret values are read from a hidden prompt (or pre-set AIOS_AZURE_* env
# variables), streamed to `gh secret set` over stdin, and never written to disk
# or placed in command arguments.

set -euo pipefail

REPO="everyai-com/AIOS_Desktop-releases"
DRY_RUN=0
ASSUME_YES=0

usage() {
  echo "Usage: $0 [--repo OWNER/REPO] [--dry-run] [--yes]"
  echo
  echo "Interactive mode prompts for the Azure tenant, service principal,"
  echo "Trusted Signing account/profile/endpoint, and validated publisher."
  echo "Use --dry-run to validate all inputs without changing GitHub."
  echo
  echo "Optional pre-set inputs (useful for a dry-run):"
  echo "  AIOS_AZURE_TENANT_ID"
  echo "  AIOS_AZURE_CLIENT_ID"
  echo "  AIOS_AZURE_CLIENT_SECRET"
  echo "  AIOS_AZURE_CODE_SIGNING_ENDPOINT"
  echo "  AIOS_AZURE_CERTIFICATE_PROFILE_NAME"
  echo "  AIOS_AZURE_CODE_SIGNING_ACCOUNT_NAME"
  echo "  AIOS_AZURE_PUBLISHER_NAME"
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

PFX_SECRETS="$(gh secret list --repo "$REPO" --json name --jq '.[].name')"
if grep -Eq '^(WIN_CSC_LINK|WIN_CSC_KEY_PASSWORD)$' <<<"$PFX_SECRETS"; then
  echo "PFX signing secrets already exist on $REPO." >&2
  echo "Remove that complete signer mode before configuring Azure." >&2
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

prompt_value "Azure tenant ID" AIOS_AZURE_TENANT_ID
prompt_value "Azure service-principal client ID" AIOS_AZURE_CLIENT_ID
if [ -z "${AIOS_AZURE_CLIENT_SECRET:-}" ]; then
  IFS= read -r -s -p "Azure service-principal client secret: " AIOS_AZURE_CLIENT_SECRET
  echo >&2
fi
prompt_value "Trusted Signing endpoint (https://<region>.codesigning.azure.net)" AIOS_AZURE_CODE_SIGNING_ENDPOINT
prompt_value "Trusted Signing certificate profile name" AIOS_AZURE_CERTIFICATE_PROFILE_NAME
prompt_value "Trusted Signing account name" AIOS_AZURE_CODE_SIGNING_ACCOUNT_NAME
prompt_value "Validated publisher name (exact certificate subject)" AIOS_AZURE_PUBLISHER_NAME

trap 'unset AIOS_AZURE_CLIENT_SECRET' EXIT

UUID_PATTERN='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
if [[ ! "$AIOS_AZURE_TENANT_ID" =~ $UUID_PATTERN ]]; then
  echo "Azure tenant ID must be a UUID." >&2
  exit 1
fi
if [[ ! "$AIOS_AZURE_CLIENT_ID" =~ $UUID_PATTERN ]]; then
  echo "Azure client ID must be a UUID." >&2
  exit 1
fi
if [ -z "$AIOS_AZURE_CLIENT_SECRET" ]; then
  echo "Azure client secret cannot be empty." >&2
  exit 1
fi
if [[ ! "$AIOS_AZURE_CODE_SIGNING_ENDPOINT" =~ ^https://[A-Za-z0-9.-]+\.codesigning\.azure\.net/?$ ]]; then
  echo "Trusted Signing endpoint must be an HTTPS *.codesigning.azure.net URL." >&2
  exit 1
fi
AIOS_AZURE_CODE_SIGNING_ENDPOINT="${AIOS_AZURE_CODE_SIGNING_ENDPOINT%/}"

RESOURCE_NAME_PATTERN='^[A-Za-z0-9][A-Za-z0-9._-]{1,127}$'
if [[ ! "$AIOS_AZURE_CERTIFICATE_PROFILE_NAME" =~ $RESOURCE_NAME_PATTERN ]]; then
  echo "Certificate profile name contains unsupported characters." >&2
  exit 1
fi
if [[ ! "$AIOS_AZURE_CODE_SIGNING_ACCOUNT_NAME" =~ $RESOURCE_NAME_PATTERN ]]; then
  echo "Trusted Signing account name contains unsupported characters." >&2
  exit 1
fi
if [ "${#AIOS_AZURE_PUBLISHER_NAME}" -lt 2 ] || [[ "$AIOS_AZURE_PUBLISHER_NAME" == *$'\n'* ]]; then
  echo "Validated publisher name must be one non-empty line." >&2
  exit 1
fi

if [ "$ASSUME_YES" -ne 1 ]; then
  IFS= read -r -p "Configure Azure Trusted Signing on $REPO? Type CONFIGURE: " CONFIRMATION
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

set_secret AZURE_TENANT_ID "$AIOS_AZURE_TENANT_ID"
set_secret AZURE_CLIENT_ID "$AIOS_AZURE_CLIENT_ID"
set_secret AZURE_CLIENT_SECRET "$AIOS_AZURE_CLIENT_SECRET"
set_variable AZURE_CODE_SIGNING_ENDPOINT "$AIOS_AZURE_CODE_SIGNING_ENDPOINT"
set_variable AZURE_CERTIFICATE_PROFILE_NAME "$AIOS_AZURE_CERTIFICATE_PROFILE_NAME"
set_variable AZURE_CODE_SIGNING_ACCOUNT_NAME "$AIOS_AZURE_CODE_SIGNING_ACCOUNT_NAME"
set_variable AZURE_PUBLISHER_NAME "$AIOS_AZURE_PUBLISHER_NAME"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry-run passed. GitHub was not changed."
  exit 0
fi

SECRET_NAMES="$(gh secret list --repo "$REPO" --json name --jq '.[].name')"
VARIABLE_NAMES="$(gh variable list --repo "$REPO" --json name --jq '.[].name')"
for NAME in AZURE_TENANT_ID AZURE_CLIENT_ID AZURE_CLIENT_SECRET; do
  grep -Fxq "$NAME" <<<"$SECRET_NAMES"
done
for NAME in \
  AZURE_CODE_SIGNING_ENDPOINT \
  AZURE_CERTIFICATE_PROFILE_NAME \
  AZURE_CODE_SIGNING_ACCOUNT_NAME \
  AZURE_PUBLISHER_NAME; do
  grep -Fxq "$NAME" <<<"$VARIABLE_NAMES"
done

echo "Azure Trusted Signing inputs are configured on $REPO."
echo "The next release run will still fail closed unless Microsoft accepts the"
echo "identity, role assignment, certificate profile, and final signatures."
