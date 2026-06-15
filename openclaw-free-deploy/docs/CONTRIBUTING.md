# Contributing

Thanks for wanting to improve **openclaw-free-deploy**. This is a small,
focused project: it makes [OpenClaw](https://github.com/openclaw/openclaw)
deployable on free infrastructure. Contributions that keep it simple and
free-tier-friendly are very welcome.

## Good first contributions

- **New channel templates** — Discord, Slack, and Telegram are wired up;
  WhatsApp, Signal, Matrix, etc. follow the same pattern in `start.sh`.
- **New host guides** — Render, Fly.io, Railway, Northflank all have free tiers
  and can host the same image.
- **New AI providers** — add a `case` branch in `start.sh` and a row in the
  README model table.
- **Translations** — the README is EN + 中文; more languages help.
- **Real-world cost/perf numbers** — replace my estimates with measured data.

## Local development

```bash
cp .env.example .env       # fill in TELEGRAM_BOT_TOKEN + one provider key
docker compose up --build  # builds the same image HF builds, on :7860
```

Send your bot a DM and confirm it replies. For webhook mode locally, expose
`http://localhost:7860` with `cloudflared tunnel --url http://localhost:7860`
(or ngrok) and set `TELEGRAM_MODE=webhook` + `PUBLIC_BASE_URL=<tunnel-url>`.

## Before you open a PR

CI runs `shellcheck`, `hadolint`, and `actionlint`. Run them locally if you can:

```bash
shellcheck scripts/*.sh
docker run --rm -i hadolint/hadolint < Dockerfile
```

Checklist:

- No secrets committed (`.env`, real tokens, keys).
- New env vars documented in `.env.example` **and** the README.
- Scripts stay `bash` (we use `[[ ]]` and arrays) and start with `set -Eeuo pipefail`.
- Keep it free-tier-friendly — avoid changes that require a paid service to work.

## Style

- Comment the *why*, not the *what*. The scripts already explain their tradeoffs;
  match that tone.
- Prefer clarity over cleverness — beginners read this code.

## Conduct

Be kind. This project exists so people who can't afford a VPS can still run a
personal AI assistant. Keep that spirit.
