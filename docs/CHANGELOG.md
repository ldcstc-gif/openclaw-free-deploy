# Changelog

All notable changes to this project are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/);
this project uses date-based tags (`vYYYY.MM.DD`).

## [Unreleased]

### Added
- **Authorship & provenance:** `NOTICE` and `AUTHORS` files; `SPDX-License-Identifier`
  + `SPDX-FileCopyrightText` headers in every source file; an Author badge and an
  "Author & provenance" section in the README; and `docs/PROVENANCE.md` documenting
  signed-commit / signed-tag / checksum verification.
- **`scripts/gen-checksums.sh`** to generate a `SHA256SUMS` manifest for release
  artifacts (sign it with your key for tamper-evidence).

### Changed
- `LICENSE` copyright holder is now **ldcstc-gif** (https://github.com/ldcstc-gif).

## [v2.0.0] — 2026-06-15

Major optimization pass. The default deployment path is unchanged (polling +
keep-alive), so existing users upgrade safely; everything new is opt-in.

### Added
- **Webhook mode** (`TELEGRAM_MODE=webhook`) as an alternative to long-polling,
  with the gateway on an internal port and the webhook listener on 7860.
- **Cloudflare Worker** now doubles as a hardened Telegram webhook gateway:
  validates `X-Telegram-Bot-Api-Secret-Token` and (optionally) the source IP
  against Telegram's published ranges.
- **Multi-channel support** (`CHANNELS=telegram,discord,slack`).
- **Pre-built GHCR image** via `build-image.yml` + `Dockerfile.prebuilt` for
  ~30s HF cold starts.
- **Trivy** image scanning wired into the build workflow (results in Security tab).
- **lint.yml**: shellcheck + hadolint + actionlint on every push/PR.
- **Dependabot** for GitHub Actions and the Docker base image.
- **docker-compose.yml** for local testing before pushing to HF.
- **Event-triggered R2 sync**: `SIGUSR1` forces an immediate flush.
- **OpenTelemetry passthrough** (`OTEL_EXPORTER_OTLP_ENDPOINT`, etc.) plus an
  optional `--build-arg WITH_OTEL=1`.
- **Cost estimator** (`tools/cost-estimator.html`) — standalone, no deps.
- **set-webhook.sh** to register/inspect/delete the Telegram webhook.
- Community files: `SECURITY.md`, `CONTRIBUTING.md`, issue/PR templates,
  `CHANGELOG.md`, `VERSION`.
- README: one-click deploy button, demo-Space section, FAQ + limitations
  expanded, webhook walkthrough.

### Changed
- Docker `HEALTHCHECK` now reads the gateway's actual port from
  `/tmp/openclaw-health-port`, so it works in both polling and webhook modes.
- `deploy-worker.sh` sets `WEBHOOK_SECRET` / `WEBHOOK_PATH` / `TELEGRAM_IP_CHECK`.

## [v1.0.0] — 2026-06-14

### Added
- Initial release: HF Spaces Docker deploy, Cloudflare R2 persistence,
  Cloudflare Worker reverse proxy, GitHub Actions keep-alive, and provider
  switching across Claude / OpenAI / Gemini / DeepSeek.

[Unreleased]: https://github.com/<OWNER>/openclaw-free-deploy/compare/v2.0.0...HEAD
[v2.0.0]: https://github.com/<OWNER>/openclaw-free-deploy/releases/tag/v2.0.0
[v1.0.0]: https://github.com/<OWNER>/openclaw-free-deploy/releases/tag/v1.0.0
