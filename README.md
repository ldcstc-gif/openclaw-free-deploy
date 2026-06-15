---
title: OpenClaw Free Deploy
emoji: 🦞
colorFrom: red
colorTo: yellow
sdk: docker
app_port: 7860
pinned: false
license: mit
short_description: "Your own Telegram AI bot, free — HF Spaces + Cloudflare R2"
---

# 🦞 openclaw-free-deploy

<p align="center">
  <a href="https://huggingface.co/new-space?template=docker"><img alt="Deploy on HF Spaces" src="https://img.shields.io/badge/Deploy%20on-HuggingFace%20Spaces-FFD21E?logo=huggingface&logoColor=000"></a>
  <a href="https://workers.cloudflare.com/"><img alt="Cloudflare Workers" src="https://img.shields.io/badge/Edge-Cloudflare%20Workers-F38020?logo=cloudflare&logoColor=fff"></a>
  <a href="https://github.com/openclaw/openclaw"><img alt="OpenClaw" src="https://img.shields.io/badge/Powered%20by-OpenClaw-FF5A36"></a>
  <a href="./LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-blue.svg"></a>
  <img alt="Node 24" src="https://img.shields.io/badge/Node-24-339933?logo=node.js&logoColor=fff">
  <img alt="Cost" src="https://img.shields.io/badge/Hosting%20cost-%240%2Fmo-success">
  <a href="https://github.com/ldcstc-gif"><img alt="Author: ldcstc-gif" src="https://img.shields.io/badge/Author-ldcstc--gif-181717?logo=github&logoColor=fff"></a>
</p>

<p align="center">
  <!-- One-click: replace <OWNER> below with your GitHub user/org -->
  <a href="https://huggingface.co/new-space?template=docker"><b>🚀 Deploy your own in ~10 min</b></a> ·
  <a href="#-quick-start--快速上手">Quick start</a> ·
  <a href="./tools/cost-estimator.html">💰 Cost estimator</a> ·
  <a href="#-faq--常见问题">FAQ</a>
</p>

> **EN:** Deploy your own OpenClaw Telegram AI assistant in 10 minutes, with **zero server cost** — runs on HuggingFace Spaces, persists state to Cloudflare R2, fronted by your own Cloudflare-managed domain. Supports polling **and** webhook modes, multi-channel (Telegram / Discord / Slack), and four AI providers.
>
> **中文：** 10 分钟部署你自己的 OpenClaw Telegram AI 助手，**零服务器成本** — 跑在 HuggingFace Spaces，状态存到 Cloudflare R2，套上你自己的 Cloudflare 自定义域名。支持长轮询和 **webhook** 两种模式、多渠道（Telegram / Discord / Slack）、四家 AI 服务商。

---

## 🎬 Live demo / 在线演示

**EN.** A reference deployment lives here (best-effort, may sleep): **`https://<your-demo-space>.hf.space`** — replace with your own once deployed, or DM the demo bot **@your_demo_bot** on Telegram. *(Maintainers: drop your demo links here so visitors can try before they deploy.)*

**中文。** 这里放一个参考部署（尽力维护，可能会休眠）：**`https://<你的演示-space>.hf.space`** —— 部署后替换成你自己的，或在 Telegram 上找演示 bot **@your_demo_bot** 试用。*（维护者：把你的演示链接放这里，让访客先试再部署。）*

---

## ✨ Why this project / 为什么有这个项目

**EN.** [OpenClaw](https://github.com/openclaw/openclaw) is a brilliant self-hosted personal AI agent, but its docs assume you have an always-on VPS or Mac. This repo packages OpenClaw into a free, hostable stack so anyone with a GitHub account can run it without paying for a server, managing TLS, or losing state on restart.

**中文。** [OpenClaw](https://github.com/openclaw/openclaw) 是非常优秀的自托管 AI 助手框架，但官方文档默认你有一台 7×24 的 VPS 或 Mac。本仓库把它封装成**完全免费的托管方案**：有 GitHub 账号就能跑，不用买服务器、不用管 TLS、重启也不丢会话。

---

## 🏗️ Architecture / 架构

```
                    ┌─────────────────┐
   Telegram user    │   @YourBot      │
       📱  ──────►  │  (Telegram App) │
                    └────────┬────────┘
                             │
            ┌────────────────┴─────────────────┐
            │                                   │
   POLLING (default)                    WEBHOOK (advanced)
   bot polls api.telegram.org           Telegram → CF Worker → Space
            │                                   │ (secret + IP check)
            ▼                                   ▼
   ┌──────────────────────────────────────────────────┐
   │   HuggingFace Space  (Docker, port 7860)         │
   │   ┌──────────────────────────────────────────┐   │
   │   │  openclaw-gateway   ← brain (Node 24)    │   │
   │   │  /healthz · /readyz · Control UI          │   │
   │   │  channels: telegram[,discord,slack]       │   │
   │   └──────────────────────────────────────────┘   │
   │   start.sh: R2 restore → run → R2 sync(↻/USR1)   │
   └──────────────┬─────────────────────────┬─────────┘
                  │                         │
              HTTPS / WSS              S3-compatible
                  ▼                         ▼
   ┌────────────────────────┐   ┌─────────────────────┐
   │  Cloudflare Worker     │   │  Cloudflare R2      │
   │  bot.yourdomain.com    │   │  openclaw-data/...  │
   │  proxy + webhook gate  │   │  (persists state)   │
   └────────────────────────┘   └─────────────────────┘
                  ▲
                  │  every 25 min
   ┌──────────────┴─────────┐
   │  GitHub Actions cron   │  + build-image (GHCR) + lint + Dependabot
   │  (keep-alive ping)     │
   └────────────────────────┘
```

Every provider is **free at personal-bot volumes** — see [Cost breakdown](#-cost-breakdown--成本明细).

---

## 🚀 Quick start / 快速上手

**EN.** Seven steps, ~15 min total. Steps 6–7 are optional polish.
**中文。** 共 7 步，约 15 分钟。第 6–7 步是可选锦上添花。

| #   | Step / 步骤                                | Where / 在哪做           |
| --- | ------------------------------------------ | ------------------------ |
| 1   | Fork this repo / Fork 本仓库               | GitHub                   |
| 2   | Create Telegram bot / 创建 Telegram bot    | Telegram → @BotFather    |
| 3   | Get an AI API key / 获取 AI API Key        | Anthropic / OpenAI / …   |
| 4   | Create R2 bucket / 创建 R2 桶              | Cloudflare               |
| 5   | Deploy to HF Space / 部署到 HF Space       | HuggingFace              |
| 6   | (Optional) Custom domain / 自定义域名      | Cloudflare               |
| 7   | Turn on keep-alive / 开启保活              | GitHub Actions           |

### Step 1 — Fork / Fork

**EN.** Click **Fork** (top-right). You need your own copy so the keep-alive and build workflows run on your account's (free, unlimited for public repos) Actions quota.
**中文。** 点右上角 **Fork**。需要 fork 是因为保活/构建定时任务跑在你账号下（公开仓库 Actions 无限免费）。

### Step 2 — Telegram bot / Telegram bot

**EN.** DM **@BotFather** → `/newbot` → copy the **HTTP API token** (`123456789:ABC...`). Then DM **@userinfobot** → copy your numeric **user ID**.
**中文。** 私聊 **@BotFather** → `/newbot` → 复制 **HTTP API token**（`123456789:ABC...`）。再私聊 **@userinfobot** → 记下你的纯数字 **user ID**。

> ⚠️ Treat the token like a password. / token 等于密码。

### Step 3 — AI API key / AI API Key

| Provider     | Sign up                                                | Free tier? / 免费档        |
| ------------ | ------------------------------------------------------ | -------------------------- |
| **Claude**   | [console.anthropic.com](https://console.anthropic.com) | ❌ promo credits don't count |
| **OpenAI**   | [platform.openai.com](https://platform.openai.com)     | ❌ billing required          |
| **Gemini**   | [aistudio.google.com](https://aistudio.google.com)     | ✅ generous free tier        |
| **DeepSeek** | [platform.deepseek.com](https://platform.deepseek.com) | ✅ cheapest paid             |

**EN.** True $0 → **Gemini**. Best quality → **Claude**. Best value → **DeepSeek**. Estimate your spend with the [cost estimator](./tools/cost-estimator.html).
**中文。** 真零成本选 **Gemini**；质量最好选 **Claude**；性价比选 **DeepSeek**。用[费用估算器](./tools/cost-estimator.html)算算。

### Step 4 — Cloudflare R2 bucket / R2 桶

**EN.**
1. [dash.cloudflare.com](https://dash.cloudflare.com) → **R2** (10 GB free, no card for R2-only).
2. **Create bucket** → name `openclaw-data`.
3. **Manage R2 API tokens** → **Create** (Object Read & Write).
4. Copy **Access Key ID**, **Secret Access Key**, and the **S3 endpoint** (`https://<ACCOUNT_ID>.r2.cloudflarestorage.com`).

**中文。**
1. [dash.cloudflare.com](https://dash.cloudflare.com) → **R2**（10 GB 免费，单开 R2 不绑卡）。
2. **Create bucket** → 命名 `openclaw-data`。
3. **Manage R2 API tokens** → **Create**（Object Read & Write）。
4. 复制 **Access Key ID**、**Secret Access Key**、**S3 endpoint**（`https://<ACCOUNT_ID>.r2.cloudflarestorage.com`）。

> 📸 *Screenshot: Cloudflare → R2 → API tokens dialog (the three values).*

### Step 5 — Deploy to HF Space / 部署到 HF Space

**EN.**
1. [huggingface.co](https://huggingface.co) → ➕ **New Space** → SDK: **Docker**, License: MIT.
2. **Settings → Variables and secrets → New secret** (use **Secret**, not Variable):

   | Name | Value |
   | --- | --- |
   | `TELEGRAM_BOT_TOKEN` | Step 2 |
   | `TELEGRAM_ALLOWED_USER_IDS` | your numeric ID |
   | `AI_PROVIDER` | `claude`/`openai`/`gemini`/`deepseek` |
   | `ANTHROPIC_API_KEY` (or your provider's) | Step 3 |
   | `S3_ENDPOINT` / `S3_ACCESS_KEY` / `S3_SECRET_KEY` | Step 4 |
   | `S3_BUCKET` | `openclaw-data` |

3. Push:
   ```bash
   git clone https://github.com/<you>/openclaw-free-deploy.git
   cd openclaw-free-deploy
   ./scripts/deploy.sh <hf-username> openclaw-bot <hf-token>   # token: write scope
   ```
4. Watch build logs (~5 min first time). When you see `Ready. Message your bot…`, DM your bot.

**中文。**
1. [huggingface.co](https://huggingface.co) → ➕ **New Space** → SDK 选 **Docker**，License 选 MIT。
2. **Settings → Variables and secrets → New secret**（选 **Secret** 不是 Variable），逐条加上表里的值。
3. 推送（同上命令，把 `<you>` 换成你的用户名，HF token 用 write 权限）。
4. 看构建日志（首次约 5 分钟），出现 `Ready. Message your bot…` 后去 Telegram 私聊 bot。

> 📸 *Screenshot: HF "Variables and secrets" page.*
> 💡 **Faster boots:** after your first push, the `build-image` workflow publishes a prebuilt image to GHCR. Switch to `Dockerfile.prebuilt` to cut cold starts from ~5 min to ~30 s — see [Faster boots](#-faster-boots--加速冷启动).

### Step 6 — (Optional) Custom domain / 自定义域名

**EN.** Cosmetic — the Space already works at `https://<user>-<space>.hf.space`.
1. Have a domain in Cloudflare DNS. `npx wrangler login` once.
2. `./scripts/deploy-worker.sh bot.yourdomain.com https://<user>-<space>.hf.space`
3. Cloudflare → DNS → CNAME `bot` → `100::`, proxy **ON**.

**中文。** 纯装饰 —— Space 默认就能用 `https://<user>-<space>.hf.space` 访问。步骤同左。

### Step 7 — Keep-alive / 保活

**EN.** Fork → **Settings → Secrets and variables → Actions → New repository secret**: `SPACE_URL = https://<user>-openclaw-bot.hf.space`. The workflow pings every 25 min; trigger manually from the **Actions** tab to test.
**中文。** 进 fork → **Settings → Secrets and variables → Actions → New repository secret**：`SPACE_URL = https://<user>-openclaw-bot.hf.space`。每 25 分钟自动 ping，可在 **Actions** 页手动触发测试。

---

## 🔀 Polling vs Webhook / 两种模式

**EN.** Default is **polling** — simplest, zero config, works everywhere. **Webhook** is opt-in for power users.

| | Polling (default) | Webhook |
| --- | --- | --- |
| Setup | none | needs `PUBLIC_BASE_URL` + Worker |
| Space can sleep | needs keep-alive awake | wakes on message (still ping to avoid cold-start drops) |
| Conflicts | one instance per token | one instance per token |
| Best for | beginners, single Space | custom domain + hardened ingress |

**Enable webhook:** set Space secrets `TELEGRAM_MODE=webhook` and `PUBLIC_BASE_URL=https://bot.yourdomain.com`, deploy the Worker with the secret:
```bash
WEBHOOK_SECRET=$(cat ~/.openclaw/.webhook-secret) TELEGRAM_IP_CHECK=1 \
  ./scripts/deploy-worker.sh bot.yourdomain.com https://<user>-<space>.hf.space
# OpenClaw self-registers the webhook; to re-register or inspect:
PUBLIC_BASE_URL=https://bot.yourdomain.com TELEGRAM_BOT_TOKEN=... ./scripts/set-webhook.sh info
```
> ⚠️ On HF, webhook mode keeps the **gateway/Control UI on an internal port** (not public); only the webhook endpoint is exposed on 7860. That's intentional and more secure.

**中文。** 默认 **polling**（长轮询）—— 零配置、到处能跑；**webhook** 是高级可选项。设 Space 密钥 `TELEGRAM_MODE=webhook` + `PUBLIC_BASE_URL=...`，再带 secret 部署 Worker（命令同左）。HF 上 webhook 模式会把 **网关/Control UI 放在内部端口**（不公开），只暴露 webhook 端点，这是有意为之、更安全。

---

## 📡 Multi-channel / 多渠道

**EN.** Set `CHANNELS=telegram,discord,slack` and provide each channel's token (`DISCORD_BOT_TOKEN`, `SLACK_BOT_TOKEN`/`SLACK_APP_TOKEN`). Telegram is fully featured; Discord/Slack start in pairing mode. Adding a new channel = one `case` in `start.sh` (PRs welcome).
**中文。** 设 `CHANNELS=telegram,discord,slack` 并提供各自 token。Telegram 功能最全，Discord/Slack 默认 pairing 模式。加新渠道只需在 `start.sh` 里加一个分支（欢迎 PR）。

---

## ⚡ Faster boots / 加速冷启动

**EN.** The `build-image` workflow pushes `ghcr.io/<owner>/openclaw-free-deploy:latest` on every change. To use it on HF:
```bash
# edit Dockerfile.prebuilt: replace <OWNER> with your GitHub user
git mv Dockerfile Dockerfile.fullbuild
git mv Dockerfile.prebuilt Dockerfile
git commit -am "use prebuilt image" && ./scripts/deploy.sh <user> openclaw-bot <token>
```
Cold start: ~5 min → ~30 s.
**中文。** `build-image` 工作流每次改动都会推镜像到 GHCR。HF 上改用 `Dockerfile.prebuilt`（把 `<OWNER>` 换成你的 GitHub 用户名，重命名为 `Dockerfile`），冷启动从约 5 分钟降到约 30 秒。

---

## 📊 Observability / 可观测性

**EN.** Set `OTEL_EXPORTER_OTLP_ENDPOINT` (+ `OTEL_EXPORTER_OTLP_HEADERS` for auth) to a free OTLP/HTTP collector (Grafana Cloud, Honeycomb, Axiom). Install the `@openclaw/diagnostics-otel` plugin (or build with `--build-arg WITH_OTEL=1`). See [OpenClaw OTel docs](https://docs.openclaw.ai/gateway/opentelemetry).
**中文。** 设 `OTEL_EXPORTER_OTLP_ENDPOINT`（鉴权用 `OTEL_EXPORTER_OTLP_HEADERS`）指向免费 OTLP/HTTP collector；装 `@openclaw/diagnostics-otel` 插件（或 build 时 `--build-arg WITH_OTEL=1`）。

---

## 🤖 Model comparison / 模型对比

Approximate, mid-2026. Always check current pricing.

| Provider     | Default model     | Speed | ~Cost / 1M in/out | Notes |
| ------------ | ----------------- | ----- | ----------------- | ----- |
| **Claude**   | claude-sonnet-4-5 | ⚡⚡⚡  | $3 / $15          | Thoughtful, careful |
| **OpenAI**   | gpt-5             | ⚡⚡   | $5 / $15          | Versatile |
| **Gemini**   | gemini-2.5-pro    | ⚡⚡⚡  | **free tier**     | Long context |
| **DeepSeek** | deepseek-chat     | ⚡⚡   | $0.14 / $0.28     | Best value |

➡️ Plug your own usage into the **[interactive cost estimator](./tools/cost-estimator.html)**.

---

## 💰 Cost breakdown / 成本明细

| Component / 组件 | Free tier / 免费额度 | Covers / 覆盖 |
| --- | --- | --- |
| HuggingFace Spaces (Docker) | 16 GB RAM, 2 vCPU, sleeps when idle | the container |
| Cloudflare R2 | 10 GB, 1M ops/mo, no egress fee | persistent state |
| Cloudflare Workers | 100K req/day | proxy + webhook gate |
| Cloudflare DNS | unlimited | your domain |
| GitHub Actions | unlimited (public repos) | keep-alive + build + lint |
| GHCR | unlimited (public) | prebuilt image |
| Telegram Bot API | unlimited | messaging |

**Total infra: $0/month.** AI API usage is your only cost.

---

## ❓ FAQ / 常见问题

<details><summary><b>EN: Bot replies with a "pairing code", not an answer.</b></summary>

OpenClaw's default DM policy. Set `TELEGRAM_ALLOWED_USER_IDS` to your numeric ID and redeploy.
</details>
<details><summary><b>中文：bot 第一次回我的是"配对码"。</b></summary>

OpenClaw 默认策略。把 `TELEGRAM_ALLOWED_USER_IDS` 设成你的数字 ID 后重新部署。
</details>

<details><summary><b>EN: Space slept and lost my conversations.</b></summary>

With R2 configured, state restores on next boot (up to the last sync — default 5 min, or instantly on SIGUSR1/shutdown). Without R2, conversations are ephemeral. Lower `R2_SYNC_INTERVAL` to shrink the window.
</details>
<details><summary><b>中文：Space 休眠后会话丢了。</b></summary>

配了 R2 就会在下次启动恢复（恢复到上次同步，默认 5 分钟，或 SIGUSR1/关机时即时同步）。没配 R2 则会话临时存在内存。调小 `R2_SYNC_INTERVAL` 缩短丢失窗口。
</details>

<details><summary><b>EN: Polling or webhook — which should I pick?</b></summary>

Start with polling (default). Switch to webhook only if you want a custom domain with hardened ingress and want the Space to sleep between messages. See [Polling vs Webhook](#-polling-vs-webhook--两种模式).
</details>
<details><summary><b>中文：选 polling 还是 webhook？</b></summary>

先用默认 polling。想要自定义域名 + 更严格入口、并让 Space 消息间隙休眠，再切 webhook。
</details>

<details><summary><b>EN: Can I add Discord / WhatsApp / Slack?</b></summary>

Discord and Slack are built in via `CHANNELS`. Others follow the same `start.sh` pattern — see [docs.openclaw.ai/channels](https://docs.openclaw.ai/channels).
</details>
<details><summary><b>中文：能加 Discord / WhatsApp / Slack 吗？</b></summary>

Discord、Slack 已内置（用 `CHANNELS`）。其他渠道照 `start.sh` 同样写法加。
</details>

<details><summary><b>EN: Is this against any TOS?</b></summary>

HF free Spaces target ML demos, not 24/7 bots — scale beyond personal use → paid Space. Telegram personal bots are fine (no bulk/scraping). Each AI provider's AUP allows personal assistant use. Read HF's [content policy](https://huggingface.co/content-guidelines).
</details>
<details><summary><b>中文：会违反 TOS 吗？</b></summary>

HF 免费 Space 面向 ML demo，不是 24/7 bot —— 规模上去用付费 Space。Telegram 个人 bot 没问题（别群发/爬数据）。各 AI 服务商 AUP 都允许个人助手用途。
</details>

---

## ⚠️ Known limitations / 已知限制

1. **HF free tier sleeps.** Keep-alive helps but restarts still happen — R2 makes them transparent.
2. **R2 sync window.** Up to `R2_SYNC_INTERVAL` seconds lost in a hard crash. Lower it (more writes) or trigger SIGUSR1.
3. **No OAuth providers.** ChatGPT/Codex OAuth needs a browser; only API-key providers work headless.
4. **GH cron is best-effort.** Pings may skew ±15 min; 25-min cadence gives slack.
5. **Single instance per token.** Two Spaces with the same `TELEGRAM_BOT_TOKEN` → `getUpdates` 409 conflicts.
6. **Webhook on HF.** Single exposed port means the Control UI isn't public in webhook mode (by design).

---

## 🛠️ Troubleshooting / 排错

- **`getMe returned 401`** — wrong `TELEGRAM_BOT_TOKEN`. Re-copy from BotFather.
- **`getUpdates conflict 409`** — another instance polling the same token. Stop it.
- **Healthcheck times out** — first build is slow (~5 min). Check build logs.
- **R2 `InvalidAccessKeyId`** — token lacks R2 read+write. Regenerate (Step 4).
- **No group replies** — Telegram privacy mode on by default; make bot admin or `/setprivacy` disable.
- **Webhook not firing** — run `./scripts/set-webhook.sh info`; check the Worker has `WEBHOOK_SECRET`.

More: [OpenClaw troubleshooting](https://docs.openclaw.ai/channels/troubleshooting).

---

## 🧪 Local development / 本地开发

```bash
cp .env.example .env       # fill TELEGRAM_BOT_TOKEN + one provider key
docker compose up --build  # same image HF builds, on :7860
```
For webhook locally: `cloudflared tunnel --url http://localhost:7860`, then set `TELEGRAM_MODE=webhook` + `PUBLIC_BASE_URL=<tunnel-url>`.

---

## 🗂️ Repository layout / 仓库结构

**English.** Grouped by purpose. The files at the repo **root** must stay there — HuggingFace Spaces and GitHub look them up by exact path (HF builds `./Dockerfile` and reads `./README.md`; GitHub only runs `.github/`).

```text
openclaw-free-deploy/
├── README.md             # this file · also the HF Space config  (root-required)
├── Dockerfile            # HF Spaces builds this                 (root-required)
├── Dockerfile.prebuilt   # optional: skip the build, use the GHCR image
├── docker-compose.yml    # local testing:  docker compose up --build
├── .env.example          # copy → fill in your keys
├── LICENSE
├── .gitignore · .dockerignore
│
├── scripts/              # everything around the container
│   ├── start.sh          #   entrypoint: config + R2 restore/sync + gateway
│   ├── deploy.sh         #   push to a HuggingFace Space
│   ├── deploy-worker.sh  #   deploy the Cloudflare Worker
│   └── set-webhook.sh    #   register / inspect the Telegram webhook
│
├── cloudflare/
│   └── worker.js         # reverse proxy + webhook gate (secret + IP check)
│
├── tools/
│   └── cost-estimator.html   # offline cost calculator (open in a browser)
│
├── docs/                 # CHANGELOG · CONTRIBUTING · SECURITY · VERSION
│
└── .github/              # CI + templates                        (path-required)
    ├── workflows/        #   keep-alive · build-image (GHCR) · lint
    ├── ISSUE_TEMPLATE/
    ├── PULL_REQUEST_TEMPLATE.md
    └── dependabot.yml
```

**中文。** 按用途归类。**根目录**那几个文件必须留在根目录——HuggingFace 和 GitHub 按固定路径查找（HF 构建 `./Dockerfile`、读取 `./README.md`；GitHub 只识别 `.github/`）。其余按功能收进 `scripts/`、`cloudflare/`、`tools/`、`docs/`。

---

## 🤝 Contributing / 贡献

See [docs/CONTRIBUTING.md](./docs/CONTRIBUTING.md). Channels, providers, hosts, translations, and real cost/perf numbers all welcome. Security: [docs/SECURITY.md](./docs/SECURITY.md).

---

## 🪪 Author & provenance / 作者与原创

**English.** Original work by **[ldcstc-gif](https://github.com/ldcstc-gif)**, MIT-licensed. Canonical repo: `github.com/ldcstc-gif/openclaw-free-deploy`. Authorship is declared in [NOTICE](./NOTICE), [AUTHORS](./AUTHORS), [LICENSE](./LICENSE), and an `SPDX-FileCopyrightText` header in every source file. Plaintext notices can be edited by anyone who forks, so the *verifiable* proof is **signed commits + signed release tags** (GitHub shows "Verified") plus a signed `SHA256SUMS` — see **[docs/PROVENANCE.md](./docs/PROVENANCE.md)**. Under MIT you may reuse this commercially, but the copyright notice must be retained.

**中文。** 本项目为 **[ldcstc-gif](https://github.com/ldcstc-gif)** 的原创作品，MIT 许可。官方仓库：`github.com/ldcstc-gif/openclaw-free-deploy`。署名见 [NOTICE](./NOTICE)、[AUTHORS](./AUTHORS)、[LICENSE](./LICENSE) 以及每个源文件头部的 `SPDX-FileCopyrightText`。纯文本声明谁 fork 都能改，所以*可验证*的证据是：**签名提交 + 签名发布标签**（GitHub 显示 Verified）外加签名的 `SHA256SUMS`——方法见 **[docs/PROVENANCE.md](./docs/PROVENANCE.md)**。依 MIT 可商用，但必须保留版权声明。

---

## 📜 License / 许可

MIT — see [LICENSE](./LICENSE). Not affiliated with OpenClaw, Anthropic, Cloudflare, or HuggingFace.
MIT 许可，详见 [LICENSE](./LICENSE)。与上述各公司无附属关系。

---

<p align="center">🦞 Powered by <a href="https://github.com/openclaw/openclaw">OpenClaw</a> · made for the free-tier crowd</p>
