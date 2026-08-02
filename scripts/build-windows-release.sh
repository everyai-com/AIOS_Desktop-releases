#!/usr/bin/env bash

set -euo pipefail

: "${RELEASE_TAG:?RELEASE_TAG is required}"
: "${SIGNING_MODE:?SIGNING_MODE is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must point to the GitHub Actions output file}"

BUILD_ARGS=(--win --publish never)
if [ "$SIGNING_MODE" = "unsigned" ]; then
  BUILD_ARGS+=("-c.forceCodeSigning=false")
else
  BUILD_ARGS+=("-c.forceCodeSigning=true")
fi
case "$RELEASE_TAG" in
  *-beta*|*-rc*|*-alpha*)
    BUILD_ARGS+=("-c.publish.releaseType=prerelease" "-c.publish.channel=beta")
    ;;
esac

case "$SIGNING_MODE" in
  azure)
    : "${AZURE_CODE_SIGNING_ENDPOINT:?Azure signing endpoint is required}"
    : "${AZURE_CERTIFICATE_PROFILE_NAME:?Azure certificate profile is required}"
    : "${AZURE_CODE_SIGNING_ACCOUNT_NAME:?Azure signing account is required}"
    : "${AZURE_PUBLISHER_NAME:?Azure publisher is required}"
    BUILD_ARGS+=(
      "-c.win.azureSignOptions.endpoint=${AZURE_CODE_SIGNING_ENDPOINT}"
      "-c.win.azureSignOptions.certificateProfileName=${AZURE_CERTIFICATE_PROFILE_NAME}"
      "-c.win.azureSignOptions.codeSigningAccountName=${AZURE_CODE_SIGNING_ACCOUNT_NAME}"
      "-c.win.azureSignOptions.publisherName=${AZURE_PUBLISHER_NAME}"
    )
    ;;
  esigner)
    : "${ESIGNER_CERT_THUMBPRINT:?eSigner certificate thumbprint is required}"
    : "${ESIGNER_PUBLISHER_DN:?eSigner publisher DN is required}"
    BUILD_ARGS+=(
      "-c.win.signtoolOptions.certificateSha1=${ESIGNER_CERT_THUMBPRINT}"
      "-c.win.signtoolOptions.publisherName=${ESIGNER_PUBLISHER_DN}"
      "-c.win.signtoolOptions.rfc3161TimeStampServer=http://ts.ssl.com"
    )
    ;;
  pfx)
    : "${CSC_LINK:?PFX certificate is required}"
    : "${CSC_KEY_PASSWORD:?PFX password is required}"
    ;;
  unsigned)
    ;;
  *)
    echo "::error::Unsupported Windows signing mode: $SIGNING_MODE"
    exit 1
    ;;
esac

echo "mode=$SIGNING_MODE" >> "$GITHUB_OUTPUT"
echo "Building Windows release with $SIGNING_MODE signing."
npm run build
npx electron-builder "${BUILD_ARGS[@]}"
