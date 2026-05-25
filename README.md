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
4. This repo's `release.yml` checks out the source via SSH deploy key, builds Mac arm64 + Mac x64 + Windows in parallel, and publishes here

See [.github/workflows/release.yml](.github/workflows/release.yml) for the build orchestration.
