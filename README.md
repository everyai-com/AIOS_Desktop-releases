# AIOS Desktop — Releases

Public release artifacts for [AIOS Desktop](https://aios.app).

Source code lives in the private `everyai-com/AIOS_Desktop` repo; this repo exists so:
- Releases are publicly downloadable without authentication
- Auto-update via `electron-updater` works for end users
- GitHub Actions can build for free (public repos get unlimited Actions minutes)

## Latest release

See [Releases](https://github.com/everyai-com/AIOS_Desktop-releases/releases).

## Download

| Platform | File |
|---|---|
| **macOS (Apple Silicon)** | `AIOS-Desktop-<version>-arm64.dmg` |
| **macOS (Intel)** | `AIOS-Desktop-<version>.dmg` |
| **Windows** | `AIOS-Desktop-Setup-<version>.exe` |

## How releases get here

1. Bump version in `everyai-com/AIOS_Desktop` (private) and tag `v*.*.*`
2. Tag-push fires a tiny dispatcher workflow on the private repo
3. The dispatcher sends a `repository_dispatch` event here
4. This repo's `release.yml` checks out the source via SSH deploy key and
   builds Mac arm64 + Mac x64 + Windows in parallel
5. New releases remain drafts while the workflow verifies the final stapled
   Mac DMGs, a trusted and timestamped Windows Authenticode signature, updater
   manifests, public asset names, sizes, and SHA-256 digests
6. The release becomes public only after every platform gate passes

## Windows signing inputs

The Windows build accepts exactly one signing mode:

- **Azure Trusted Signing (preferred):** repository secrets
  `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`; repository
  variables `AZURE_CODE_SIGNING_ENDPOINT`,
  `AZURE_CERTIFICATE_PROFILE_NAME`, `AZURE_CODE_SIGNING_ACCOUNT_NAME`, and
  `AZURE_PUBLISHER_NAME`.
- **Exportable PFX fallback:** repository secrets `WIN_CSC_LINK` (base64
  certificate) and `WIN_CSC_KEY_PASSWORD`.

Partial configuration, both modes at once, no signing identity, an untrusted
signature, a missing timestamp, mixed publisher certificates, or a manifest
hash mismatch all fail before Windows artifacts are uploaded. The build also
sets electron-builder's `forceCodeSigning` gate, so signing failure stops
packaging before the independent PowerShell checks run.

After Microsoft approves the identity and the service principal has the
certificate-profile signer role, run:

```bash
./scripts/configure-azure-signing.sh --dry-run
./scripts/configure-azure-signing.sh
```

The configurator prompts locally, streams secrets to GitHub over stdin, refuses
an existing PFX signer, and never writes credentials to disk. It intentionally
does not trigger a release; rerun `release.yml` for the selected source tag only
after its dry-run and GitHub name checks pass.

See [.github/workflows/release.yml](.github/workflows/release.yml) for the build orchestration.
