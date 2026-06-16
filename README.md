---
title: OpenClaw Free Deploy
emoji: 🦞
colorFrom: red
colorTo: yellow
sdk: docker
app_port: 7860
pinned: false
license: mit
short_description: "Your own Telegram AI bot, free — Render + Cloudflare R2"
---

# 🦞 openclaw-free-deploy

<p align="center">
  <a href="https://render.com/deploy?repo=https://github.com/ldcstc-gif/openclaw-free-deploy"><img alt="Deploy on Render" src="https://img.shields.io/badge/Deploy%20on-Render-46E3B7?logo=render&logoColor=fff"></a>
  <a href="https://github.com/openclaw/openclaw"><img alt="OpenClaw" src="https://img.shields.io/badge/Powered%20by-OpenClaw-FF5A36"></a>
  <a href="./LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-blue.svg"></a>
  <img alt="Node 24" src="https://img.shields.io/badge/Node-24-339933?logo=node.js&logoColor=fff">
  <img alt="Cost" src="https://img.shields.io/badge/Hosting%20cost-%240%2Fmo-success">
  <a href="https://github.com/ldcstc-gif"><img alt="Author: ldcstc-gif" src="https://img.shields.io/badge/Author-ldcstc--gif-181717?logo=github&logoColor=fff"></a>
</p>

<p align="center">
  <a href="https://render.com/deploy?repo=https://github.com/ldcstc-gif/openclaw-free-deploy"><b>🚀 Deploy your own in ~10 min</b></a> ·
  <a href="#-quick-start--快速上手">Quick start</a> ·
  <a href="#-faq--常见问题">FAQ</a>
</p>

> **EN:** Deploy your own OpenClaw Telegram AI assistant in 10 minutes for **$0/month** — runs on Render.com's free tier, optional Cloudflare R2 for state persistence. Uses Telegram long-polling (no public URL needed) and any of four AI providers.
>
> **中文：** 10 分钟部署你自己的 OpenClaw Telegram AI 助手，**月费 $0** —— 跑在 Render.com 免费版上，可选 Cloudflare R2 做状态持久化。Telegram 走长轮询（不需要公网 URL），可选四家 AI 服务商。

---

## ✨ Why this project / 为什么有这个项目

**EN.** [OpenClaw](https://github.com/openclaw/openclaw) is a brilliant self-hosted personal AI agent, but its docs assume you have an always-on VPS or Mac. This repo packages OpenClaw into a free, hostable stack so anyone with a GitHub account can run it without paying for a server.

**中文。** [OpenClaw](https://github.com/openclaw/openclaw) 是优秀的自托管 AI 助手框架，但官方文档默认你有 7×24 的 VPS 或 Mac。本仓库把它封装成**完全免费的托管方案**：有 GitHub 账号就能跑。

---

## 🏗️ Architecture / 架构

```
   Telegram user 📱
         │
         │ HTTPS long-polling (no public URL needed)
         ▼
   ┌──────────────────────────────────────────────────┐
   │   Render.com Web Service  (Docker, port 7860)    │
   │   ┌──────────────────────────────────────────┐   │
   │   │  openclaw gateway  ← brain (Node 24)     │   │
   │   │  /healthz · Control UI · Telegram channel │   │
   │   └──────────────────────────────────────────┘   │
   │   start.sh: R2 restore → run → R2 sync(↻/USR1)   │
   └──────────────┬───────────────────────────────────┘
                  │  S3-compatible
                  ▼
   ┌────────────────────────┐       ┌──────────────────────┐
   │  Cloudflare R2 (opt)   │       │  GitHub Actions cron │
   │  openclaw-state/...    │       │  pings /healthz      │
   │  persists across boots │       │  every 25 min        │
   └────────────────────────┘       └──────────────────────┘
```

---

## 🚀 Quick start / 快速上手

**EN.** Five steps, ~10 minutes. Validated on Render's free tier with DeepSeek.
**中文。** 共 5 步，约 10 分钟。Render 免费版 + DeepSeek 验证可用。

### Step 1 — Telegram bot / Telegram bot

**EN.** DM **@BotFather** → `/newbot` → copy the **HTTP API token** (`123456789:ABC...`). Then DM **@userinfobot** → copy your numeric **user ID**.
**中文。** 私聊 **@BotFather** → `/newbot` → 复制 **HTTP API token**。再私聊 **@userinfobot** → 记下你的纯数字 **user ID**。

> ⚠️ Treat the token like a password. / token 等于密码。

### Step 2 — AI API key / AI API Key

| Provider     | Sign up                                                | Cost / 费用                |
| ------------ | ------------------------------------------------------ | -------------------------- |
| **DeepSeek** | [platform.deepseek.com](https://platform.deepseek.com) | ✅ cheapest, validated      |
| **Gemini**   | [aistudio.google.com](https://aistudio.google.com)     | ✅ generous free tier        |
| **OpenAI**   | [platform.openai.com](https://platform.openai.com)     | billing required            |
| **Claude**   | [console.anthropic.com](https://console.anthropic.com) | billing required            |

**EN.** This repo defaults to **DeepSeek** (cheapest paid, ~$0.14/1M tokens). Pick another by setting `AI_PROVIDER` accordingly.
**中文。** 仓库默认 **DeepSeek**（最便宜，约 ¥1/1M token）。要换其他模型，把 `AI_PROVIDER` 改成对应值即可。

### Step 3 — (Optional) Cloudflare R2 bucket / R2 桶（可选）

**EN.** Skip this if you don't mind re-pairing after a Render restart. With R2 your state survives restarts/redeploys.

1. [dash.cloudflare.com](https://dash.cloudflare.com) → **R2** (10 GB free, no card required).
2. **Create bucket** → name `openclaw-state`.
3. **Manage R2 API tokens** → **Create** (Object Read & Write).
4. Copy **Access Key ID**, **Secret Access Key**, and the **S3 endpoint** (`https://<ACCOUNT_ID>.r2.cloudflarestorage.com`).

**中文。** 不配也能跑，只是 Render 重启后要重新 onboard。配上 R2 后状态自动保存。

1. [dash.cloudflare.com](https://dash.cloudflare.com) → **R2**（10 GB 免费，不绑卡）。
2. **Create bucket** → 命名 `openclaw-state`。
3. **Manage R2 API tokens** → **Create**（Object Read & Write）。
4. 复制 **Access Key ID**、**Secret Access Key**、**S3 endpoint**。

### Step 4 — Deploy to Render / 部署到 Render

**EN.**
1. [render.com](https://render.com) → sign in with GitHub.
2. **New +** → **Web Service** → connect this repo (or your fork).
3. Render auto-detects `render.yaml`. Confirm:
   - **Runtime:** Docker · **Branch:** `main` · **Region:** Singapore (closest to Asia) · **Instance:** Free
4. **Environment Variables** → click **Add from .env** and paste:

   ```env
   AI_PROVIDER=deepseek
   DEEPSEEK_API_KEY=sk-...your-new-key...
   TELEGRAM_BOT_TOKEN=123456789:ABC...your-bot-token...
   TELEGRAM_ALLOWED_USER_IDS=123456789
   OPENCLAW_GATEWAY_TOKEN=run-`openssl rand -hex 32`-and-paste-output
   PORT=7860
   OPENCLAW_DISABLE_BONJOUR=1
   ```

   Add the four `S3_*` vars too if you did Step 3.

5. Click **Deploy Web Service**. First build takes ~3-5 min. When the dashboard shows **Live** (green), DM your bot — it should reply within seconds.

**中文。**
1. [render.com](https://render.com) → 用 GitHub 登录。
2. **New +** → **Web Service** → 连接本仓库（或你的 fork）。
3. Render 会自动识别 `render.yaml`。确认：
   - **Runtime：** Docker · **Branch：** `main` · **Region：** Singapore（离亚洲近） · **Instance：** Free
4. **Environment Variables** → 点 **Add from .env**，粘贴上面那段（把示例值换成你自己的真实值）。如果做了第 3 步，加上 `S3_*` 四个变量。
5. 点 **Deploy Web Service**。首次构建约 3-5 分钟。状态变 **Live**（绿色）后给 bot 发消息，几秒内会回复。

### Step 5 — Keep-alive / 保活

**EN.** Render's free tier sleeps after 15 min of HTTP inactivity. A GitHub Action in this repo pings every 25 min to keep it warm.

1. Copy your service URL from the Render dashboard (e.g. `https://openclaw-free-deploy.onrender.com`).
2. In your GitHub fork: **Settings → Secrets and variables → Actions → New repository secret**.
3. Name: `SERVICE_URL`, Value: your Render URL.
4. **Actions** tab → **keep-alive** → **Run workflow** to test manually.

**中文。** Render 免费版 15 分钟无 HTTP 请求会休眠。仓库内置的 GitHub Action 每 25 分钟 ping 一次保活。

1. 从 Render 控制台复制你的服务 URL（如 `https://openclaw-free-deploy.onrender.com`）。
2. 在 GitHub fork 里：**Settings → Secrets and variables → Actions → New repository secret**。
3. Name 填 `SERVICE_URL`，Value 填 Render URL。
4. **Actions** 页 → **keep-alive** → **Run workflow** 手动跑一次测试。

> ⏱️ **Cold start note / 冷启动说明：** Even with keep-alive, a cold start can take 50-90s. The bot still receives messages reliably (Telegram queues them) — just expect a delay if it just woke up.
>
> 即使有保活，冷启动可能要 50-90 秒。bot 不会丢消息（Telegram 服务端会缓存），只是刚醒来时回复会慢。

---

## 🌍 Other hosts / 其他托管选项

**EN.** Render is what this repo is validated against. Two alternatives we tried:

- **HuggingFace Spaces** — image builds fine, but HF Spaces' free tier **blocks outbound TCP to `api.telegram.org`**. Telegram polling will fail with `UND_ERR_CONNECT_TIMEOUT`. Don't bother unless HF lifts that restriction.
- **Any VPS** — `docker compose up -d` with this repo's `Dockerfile` works on any host that has Docker. No sleep, no cold starts. Costs whatever the VPS costs.

**中文。** Render 是本仓库验证过的部署目标。其他试过的：

- **HuggingFace Spaces** —— 镜像构建没问题，但 HF 免费版**封了到 `api.telegram.org` 的出站 TCP**。Telegram 长轮询会一直 `UND_ERR_CONNECT_TIMEOUT`。除非 HF 改政策，否则别走这条路。
- **任意 VPS** —— 有 Docker 的机器都能 `docker compose up -d` 跑起来。不休眠、不冷启动，但 VPS 要钱。

---

## 🤖 Model comparison / 模型对比

Approximate, mid-2026. Always check current pricing.

| Provider     | Default model     | Speed | ~Cost / 1M in/out | Notes |
| ------------ | ----------------- | ----- | ----------------- | ----- |
| **DeepSeek** | deepseek-chat     | ⚡⚡   | $0.14 / $0.28     | Best value, default |
| **Gemini**   | gemini-2.5-pro    | ⚡⚡⚡  | free tier         | Long context |
| **Claude**   | claude-sonnet-4-5 | ⚡⚡⚡  | $3 / $15          | Thoughtful, careful |
| **OpenAI**   | gpt-5             | ⚡⚡   | $5 / $15          | Versatile |

To switch: set `AI_PROVIDER` to `deepseek` / `gemini` / `anthropic` / `openai` and put the matching `*_API_KEY` env var in Render.

---

## 💰 Cost breakdown / 成本明细

| Component / 组件 | Free tier / 免费额度 | Covers / 覆盖 |
| --- | --- | --- |
| Render Web Service | 512 MB RAM / 0.1 CPU, sleeps when idle | the container |
| Cloudflare R2 | 10 GB, 1M ops/mo, no egress fee | persistent state (optional) |
| GitHub Actions | unlimited (public repos) | keep-alive + lint |
| Telegram Bot API | unlimited | messaging |

**Total infra: $0/month.** AI API usage is your only cost (a few cents per day for personal use on DeepSeek).

---

## ❓ FAQ / 常见问题

<details><summary><b>EN: Bot replies with a "pairing code", not an answer.</b></summary>

OpenClaw's default DM policy. Set `TELEGRAM_ALLOWED_USER_IDS` to your numeric ID (DM @userinfobot to get it) and trigger a redeploy from Render.
</details>
<details><summary><b>中文：bot 第一次回我的是"配对码"。</b></summary>

OpenClaw 默认策略。把 `TELEGRAM_ALLOWED_USER_IDS` 设成你的数字 ID（私聊 @userinfobot 拿到），在 Render 上重新部署一次。
</details>

<details><summary><b>EN: Render said "Live" but the bot doesn't reply.</b></summary>

Check **Logs** on the Render dashboard. The startup script prints `[start ...] Ready. DM your Telegram bot.` when ready. If you see `[start ERROR]` instead, the message tells you which secret is missing or wrong.
</details>
<details><summary><b>中文：Render 显示 Live 了但 bot 不回。</b></summary>

去 Render 控制台看 **Logs**。启动脚本就绪时会打印 `[start ...] Ready. DM your Telegram bot.`。如果看到 `[start ERROR]`，红字会告诉你哪个 secret 漏了或错了。
</details>

<details><summary><b>EN: Service slept and lost my conversations.</b></summary>

With R2 configured, state restores on next boot (up to the last sync — default every 5 min, or instantly on SIGUSR1/shutdown). Without R2, conversations are ephemeral. Lower `R2_SYNC_INTERVAL` to shrink the window.
</details>
<details><summary><b>中文：服务休眠后会话丢了。</b></summary>

配了 R2 就会在下次启动恢复（恢复到上次同步，默认 5 分钟，或 SIGUSR1/关机时即时同步）。没配 R2 则会话临时存在内存。调小 `R2_SYNC_INTERVAL` 缩短丢失窗口。
</details>

<details><summary><b>EN: First message after sleep takes forever.</b></summary>

Render free-tier cold-start is 50-90s. The bot will reply once warm — your message isn't lost. To minimize: keep the keep-alive workflow on, or upgrade to Render's $7/mo Starter (no sleep).
</details>
<details><summary><b>中文：睡醒后第一条消息回得特别慢。</b></summary>

Render 免费版冷启动 50-90 秒。bot 醒了就会回，消息不会丢。要缩短：保活工作流别关，或升级 $7/月 Starter 套餐（不休眠）。
</details>

<details><summary><b>EN: Can I use HuggingFace Spaces instead?</b></summary>

The image builds on HF, but HF's free Spaces block outbound traffic to `api.telegram.org`, so Telegram polling fails. Use Render (or any VPS) instead.
</details>
<details><summary><b>中文：能用 HuggingFace Spaces 替代吗？</b></summary>

镜像能在 HF 上构建，但 HF 免费版封了 `api.telegram.org` 的出站，长轮询会一直超时。用 Render（或任意 VPS）替代。
</details>

<details><summary><b>EN: Is this against any TOS?</b></summary>

Render free Web Services target side-projects and small bots — scale beyond personal use → paid tier. Telegram personal bots are fine (no bulk/scraping). Each AI provider's AUP allows personal assistant use.
</details>
<details><summary><b>中文：会违反 TOS 吗？</b></summary>

Render 免费 Web Service 面向小项目和 bot —— 规模上去用付费档。Telegram 个人 bot 没问题（别群发/爬数据）。各 AI 服务商 AUP 都允许个人助手用途。
</details>

---

## ⚠️ Known limitations / 已知限制

1. **Render free tier sleeps.** Keep-alive helps; R2 makes restarts transparent.
2. **R2 sync window.** Up to `R2_SYNC_INTERVAL` seconds lost in a hard crash. Lower it (more writes) or trigger SIGUSR1.
3. **No OAuth providers.** ChatGPT/Codex OAuth needs a browser; only API-key providers work headless.
4. **GH cron is best-effort.** Pings may skew ±15 min; 25-min cadence gives slack.
5. **Single instance per token.** Two services with the same `TELEGRAM_BOT_TOKEN` → `getUpdates` 409 conflicts.
6. **HF Spaces won't work.** Free tier blocks Telegram API. Not a fix-able issue from our side.

---

## 🛠️ Troubleshooting / 排错

- **`getMe returned 401`** — wrong `TELEGRAM_BOT_TOKEN`. Re-copy from BotFather.
- **`getUpdates conflict 409`** — another instance polling the same token. Stop it (kill any local `docker compose` runs, old HF Spaces, etc.).
- **Healthcheck times out during deploy** — first build is slow (~5 min on free tier). Check build logs.
- **R2 `InvalidAccessKeyId`** — token lacks R2 read+write. Regenerate (Step 3).
- **No group replies** — Telegram privacy mode on by default; make bot admin or `/setprivacy` disable in @BotFather.
- **`[start ERROR] DEEPSEEK_API_KEY is not set`** — env var name doesn't match `AI_PROVIDER`. For `AI_PROVIDER=deepseek` you need `DEEPSEEK_API_KEY`; for `openai` you need `OPENAI_API_KEY`, etc.

More: [OpenClaw troubleshooting](https://docs.openclaw.ai/channels/troubleshooting).

---

## 🧪 Local development / 本地开发

```bash
cp .env.example .env       # fill TELEGRAM_BOT_TOKEN + one provider key
docker compose up --build  # same image Render builds, on :7860
```

The local volume `openclaw_state` persists state across `docker compose down/up`, so you don't need R2 for local testing.

---

## 🗂️ Repository layout / 仓库结构

```text
openclaw-free-deploy/
├── README.md             # this file
├── Dockerfile            # what Render (and HF, and local) builds
├── render.yaml           # Render IaC (auto-detected on first deploy)
├── docker-compose.yml    # local testing:  docker compose up --build
├── .env.example          # copy → fill in your keys
├── LICENSE
│
├── scripts/
│   └── start.sh          # entrypoint: configure + R2 restore/sync + run gateway
│
├── tools/
│   └── cost-estimator.html   # offline cost calculator (open in a browser)
│
├── docs/                 # CHANGELOG · CONTRIBUTING · SECURITY · VERSION
│
└── .github/
    ├── workflows/        # keep-alive · build-image (GHCR) · lint
    ├── ISSUE_TEMPLATE/
    └── dependabot.yml
```

---

## 🤝 Contributing / 贡献

See [docs/CONTRIBUTING.md](./docs/CONTRIBUTING.md). New host targets, providers, translations, and real cost/perf numbers all welcome. Security: [docs/SECURITY.md](./docs/SECURITY.md).

---

## 🪪 Author & provenance / 作者与原创

**English.** Original work by **[ldcstc-gif](https://github.com/ldcstc-gif)**, MIT-licensed. Canonical repo: `github.com/ldcstc-gif/openclaw-free-deploy`. Authorship is declared in [NOTICE](./NOTICE), [AUTHORS](./AUTHORS), [LICENSE](./LICENSE), and an `SPDX-FileCopyrightText` header in every source file. Verifiable proof is **signed commits + signed release tags** plus a signed `SHA256SUMS` — see **[docs/PROVENANCE.md](./docs/PROVENANCE.md)**.

**中文。** 本项目为 **[ldcstc-gif](https://github.com/ldcstc-gif)** 的原创作品，MIT 许可。官方仓库：`github.com/ldcstc-gif/openclaw-free-deploy`。署名见 [NOTICE](./NOTICE)、[AUTHORS](./AUTHORS)、[LICENSE](./LICENSE) 以及每个源文件头部的 `SPDX-FileCopyrightText`。可验证证据是**签名提交 + 签名发布标签**外加签名的 `SHA256SUMS`——方法见 **[docs/PROVENANCE.md](./docs/PROVENANCE.md)**。

---

## 📜 License / 许可

MIT — see [LICENSE](./LICENSE). Not affiliated with OpenClaw, Anthropic, Cloudflare, Render, or HuggingFace.
MIT 许可，详见 [LICENSE](./LICENSE)。与上述各公司无附属关系。

---

<p align="center">🦞 Powered by <a href="https://github.com/openclaw/openclaw">OpenClaw</a> · made for the free-tier crowd</p>
