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

- **SSL.com eSigner CKA (preferred for AIOS's Indian legal entity):**
  repository secrets `ES_USERNAME`, `ES_PASSWORD`, `ES_TOTP_SECRET`; repository
  variable `ES_PUBLISHER_NAME`, set to the exact certificate SimpleName/CN. CI
  derives the full distinguished name from that one selected certificate.
- **Azure Artifact Signing Public Trust (eligible geographies only):** repository secrets
  `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`; repository
  variables `AZURE_CODE_SIGNING_ENDPOINT`,
  `AZURE_CERTIFICATE_PROFILE_NAME`, `AZURE_CODE_SIGNING_ACCOUNT_NAME`, and
  `AZURE_PUBLISHER_NAME`.
- **Exportable PFX legacy fallback:** repository secrets `WIN_CSC_LINK` (base64
  certificate) and `WIN_CSC_KEY_PASSWORD`. Current publicly trusted code-signing
  certificates normally require a hardware token or cloud HSM and are not
  exportable PFX files.

Partial configuration, multiple modes at once, no signing identity, an untrusted
signature, a missing timestamp, mixed publisher certificates, or a manifest
hash mismatch all fail before Windows artifacts are uploaded. The build also
sets electron-builder's `forceCodeSigning` gate, so signing failure stops
packaging before the independent PowerShell checks run.

For SAPHAARE LABS PRIVATE LIMITED, purchase and validate an SSL.com OV code
signing certificate, enroll it in eSigner, and enable automated eSigner TOTP.
SSL.com's [eSigner CI guide](https://www.ssl.com/how-to/how-to-integrate-esigner-cka-with-ci-cd-tools-for-automated-code-signing/)
documents this cloud-HSM flow. Before ordering, make the company's legal name,
address, and reachable phone verifiable through a qualified independent source;
SSL.com's [organization-validation guide](https://www.ssl.com/guide/d-u-n-s-numbers-and-business-listings-for-code-signing-certificate-validation/)
recommends a D-U-N-S listing and explains the additional ID check for younger
organizations. Then run:

```bash
./scripts/configure-esigner-signing.sh --dry-run
./scripts/configure-esigner-signing.sh
```

The configurator prompts locally, streams credentials to GitHub over stdin,
refuses another signer mode, and never writes credentials to disk. It
intentionally does not trigger a release. Before cutting a Desktop tag, run the
non-publishing certificate probe:

```bash
gh workflow run windows-signing-readiness.yml \
  --repo everyai-com/AIOS_Desktop-releases \
  --ref main
gh run list \
  --repo everyai-com/AIOS_Desktop-releases \
  --workflow windows-signing-readiness.yml \
  --limit 1
# Then copy that run ID:
gh run watch <run-id> \
  --repo everyai-com/AIOS_Desktop-releases \
  --exit-status
```

The readiness workflow is accepted only from `main`. It loads the expected
cloud-HSM identity, signs a disposable executable on `windows-latest`, and
requires trusted Authenticode, the exact selected thumbprint/full DN, and an
RFC3161 timestamp. It publishes nothing. The release workflow downloads SSL.com's
public eSigner CKA v1.0.7 archive by a pinned SHA-256, loads exactly one matching
certificate into the ephemeral runner's CurrentUser store, and lets
electron-builder sign through Windows signtool.

Azure remains available for identities in Microsoft's supported Public Trust
geographies. India is not currently listed for either organization or
individual Public Trust onboarding in Microsoft's
[Artifact Signing quickstart](https://learn.microsoft.com/en-us/azure/artifact-signing/quickstart)
and [FAQ](https://learn.microsoft.com/en-us/azure/artifact-signing/faq). For an
eligible identity, after Microsoft approval and the service principal receives
the certificate-profile signer role, run:

```bash
./scripts/configure-azure-signing.sh --dry-run
./scripts/configure-azure-signing.sh
```

Rerun `release.yml` for the selected source tag only after the chosen
configurator's dry-run and GitHub name checks pass.

Every release-infrastructure PR runs `validate.yml`. It lints both workflows,
ShellChecks every Bash script, executes the signing-mode and build-argument
matrices, and performs a no-credential Windows installation of the
checksum-pinned eSigner CKA package after verifying the installer's own trusted
Authenticode signature. The certificate-backed signing operation remains the
final release gate.

See [.github/workflows/release.yml](.github/workflows/release.yml) for the build orchestration.
