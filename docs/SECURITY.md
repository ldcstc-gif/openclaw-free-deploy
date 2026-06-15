# Security Policy

## Scope

This repository is **deployment glue** — Dockerfile, scripts, a Cloudflare
Worker, and CI. It does not contain the OpenClaw agent itself. Vulnerabilities
in OpenClaw should be reported to the [OpenClaw project](https://github.com/openclaw/openclaw/security).

Report issues in *this* repo's scripts/Worker/CI by opening a private security
advisory — on the repo's GitHub page go to **Security ▸ Advisories ▸ Report a
vulnerability** — or a regular issue if it's low-risk.

## Handling secrets — read this before deploying

This stack handles several long-lived secrets. Treat all of them like passwords.

| Secret | Blast radius if leaked |
| --- | --- |
| `TELEGRAM_BOT_TOKEN` | Full control of your bot; an attacker can read/send messages |
| `ANTHROPIC_API_KEY` / other provider keys | Billed API usage on your account |
| `S3_ACCESS_KEY` / `S3_SECRET_KEY` | Read/write/delete on your R2 bucket |
| `HF_TOKEN` | Push to your HF Spaces / repos |
| `TELEGRAM_WEBHOOK_SECRET` | Lets an attacker forge webhook calls |

Hard rules baked into this repo:

- `.env` and `cloudflare/wrangler.toml` are **git-ignored**. Never force-add them.
- On HuggingFace, set everything as **Secrets**, not **Variables** (Variables
  are world-readable on public Spaces).
- `start.sh` exports provider keys to child processes only; it never writes them
  to `~/.aws/credentials` or any file that R2 sync would upload.
- Use a **dedicated, low-limit API key** for the bot — don't reuse your main key.
  This caps the damage if the container or logs are ever exposed.

## Recommended hardening

- Set `TELEGRAM_ALLOWED_USER_IDS` to lock the bot to your own user ID.
- In webhook mode, set `WEBHOOK_SECRET` and `TELEGRAM_IP_CHECK=1` on the Worker.
- Keep the OpenClaw Control UI **off the public internet** (the default in
  webhook mode; in polling mode, don't expose port 7860 beyond the proxy).
- Review OpenClaw's own [security guide](https://docs.openclaw.ai/gateway/security)
  before enabling tools that run shell commands.

## Supported versions

This is a template repo; only the latest `main` is maintained. Pin a release tag
in your fork if you need stability.
