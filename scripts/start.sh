#!/usr/bin/env bash
#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 ldcstc-gif <https://github.com/ldcstc-gif>
# Author: ldcstc-gif — original work — https://github.com/ldcstc-gif/openclaw-free-deploy
#
# ==============================================================================
# OpenClaw multi-channel bot — container entrypoint  (v2)
#
# New in v2 (vs the original single-mode script):
#   * TELEGRAM_MODE = polling | webhook         (#2 webhook support)
#   * CHANNELS      = telegram[,discord,slack]  (#8 multi-channel)
#   * SIGUSR1 triggers an immediate R2 sync      (#7 event-triggered sync)
#   * OTEL_* env vars are forwarded to OpenClaw  (#9 observability)
#
# Order of operations:
#   1. Validate env (provider + at least one channel).
#   2. Restore state from Cloudflare R2 (if configured).
#   3. Generate ~/.openclaw/openclaw.json (channels + model + webhook/polling).
#   4. Start the gateway. In webhook mode the gateway runs on an INTERNAL port
#      and OpenClaw's Telegram webhook listener takes the PUBLIC port (7860).
#   5. Wait for /healthz on the gateway's actual port.
#   6. Background R2 sync loop + SIGUSR1 immediate-sync handler.
#   7. SIGTERM/SIGINT → final R2 flush → graceful gateway shutdown.
#
# Requires bash (uses [[ ]], arrays). Do NOT run under /bin/sh dash.
# ==============================================================================
set -Eeuo pipefail

# ---------- helpers ----------------------------------------------------------
log()  { printf '[start.sh %s] %s\n' "$(date -u +%H:%M:%SZ)" "$*"; }
fail() { printf '\n\033[1;31m[start.sh ERROR]\033[0m %s\n\n' "$*" >&2; exit 1; }

require() {
  local name=$1 hint=${2:-}
  if [[ -z "${!name:-}" ]]; then
    fail "Missing required env var: ${name}${hint:+ — ${hint}}"
  fi
}
mask() { local v=${1:-}; if [[ ${#v} -le 4 ]]; then echo '****'; else echo "****${v: -4}"; fi; }
rand_hex() { head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'; }

# ---------- 1. Validate provider --------------------------------------------
log "Validating environment…"

AI_PROVIDER=${AI_PROVIDER:-claude}
AI_PROVIDER=${AI_PROVIDER,,}
case "$AI_PROVIDER" in
  claude)   require ANTHROPIC_API_KEY "Claude provider selected"; MODEL_DEFAULT="anthropic/claude-sonnet-4-5" ;;
  openai)   require OPENAI_API_KEY    "OpenAI provider selected"; MODEL_DEFAULT="openai/gpt-5" ;;
  gemini)   require GEMINI_API_KEY    "Gemini provider selected"; MODEL_DEFAULT="google/gemini-2.5-pro" ;;
  deepseek) require DEEPSEEK_API_KEY  "DeepSeek provider selected"; MODEL_DEFAULT="deepseek/deepseek-chat" ;;
  *) fail "Unknown AI_PROVIDER='${AI_PROVIDER}'. Use: claude | openai | gemini | deepseek" ;;
esac
MODEL=${MODEL:-$MODEL_DEFAULT}

# ---------- 1b. Validate channels -------------------------------------------
CHANNELS=${CHANNELS:-telegram}
CHANNELS=${CHANNELS,,}
IFS=',' read -r -a CHANNEL_ARR <<< "$CHANNELS"

want_channel() { local c; for c in "${CHANNEL_ARR[@]}"; do [[ "${c// /}" == "$1" ]] && return 0; done; return 1; }

if want_channel telegram; then require TELEGRAM_BOT_TOKEN "telegram is in CHANNELS — get a token from @BotFather"; fi
if want_channel discord;  then require DISCORD_BOT_TOKEN  "discord is in CHANNELS — create a bot at discord.com/developers"; fi
if want_channel slack;    then require SLACK_BOT_TOKEN    "slack is in CHANNELS — needs a bot token (xoxb-…)"; fi

# ---------- ports & mode -----------------------------------------------------
PUBLIC_PORT=${PORT:-7860}                       # HF Spaces requires 7860
TELEGRAM_MODE=${TELEGRAM_MODE:-polling}
TELEGRAM_MODE=${TELEGRAM_MODE,,}

if [[ "$TELEGRAM_MODE" == "webhook" ]]; then
  # In webhook mode the OpenClaw Telegram webhook listener takes the public
  # port, and the gateway (Control UI + /healthz) moves to an internal port.
  GATEWAY_PORT=${GATEWAY_INTERNAL_PORT:-18789}
else
  GATEWAY_PORT=$PUBLIC_PORT
fi

# Record the gateway port so the Docker HEALTHCHECK (which can't read our env)
# can find it in either mode.
echo "$GATEWAY_PORT" > /tmp/openclaw-health-port 2>/dev/null || true

R2_SYNC_INTERVAL=${R2_SYNC_INTERVAL:-300}

log "Provider:      ${AI_PROVIDER}  (model: ${MODEL})"
log "Channels:      ${CHANNELS}"
log "Telegram mode: ${TELEGRAM_MODE}"
log "Public port:   ${PUBLIC_PORT}   Gateway port: ${GATEWAY_PORT}"
want_channel telegram && log "Telegram token: $(mask "$TELEGRAM_BOT_TOKEN")"

# ---------- 2. Restore from R2 ----------------------------------------------
R2_ENABLED=0
if [[ -n "${S3_ENDPOINT:-}" && -n "${S3_ACCESS_KEY:-}" && -n "${S3_SECRET_KEY:-}" ]]; then
  R2_ENABLED=1
  S3_BUCKET=${S3_BUCKET:-openclaw-data}
  S3_REGION=${S3_REGION:-auto}
  S3_PREFIX=${S3_PREFIX:-openclaw-state}
  export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY
  export AWS_SECRET_ACCESS_KEY=$S3_SECRET_KEY
  export AWS_DEFAULT_REGION=$S3_REGION
  export AWS_EC2_METADATA_DISABLED=true

  log "R2 enabled (bucket=${S3_BUCKET}, prefix=${S3_PREFIX}). Restoring…"
  if aws --endpoint-url "$S3_ENDPOINT" s3 sync \
       "s3://${S3_BUCKET}/${S3_PREFIX}/" "${OPENCLAW_HOME}/" \
       --no-progress --only-show-errors 2>/dev/null; then
    log "R2 restore complete."
  else
    log "R2 restore had non-fatal errors (likely first run / empty bucket)."
  fi
else
  log "R2 NOT configured — state is EPHEMERAL. Set S3_* to persist across restarts."
fi

push_to_r2() {
  [[ $R2_ENABLED -eq 1 ]] || return 0
  aws --endpoint-url "$S3_ENDPOINT" s3 sync \
      "${OPENCLAW_HOME}/" "s3://${S3_BUCKET}/${S3_PREFIX}/" \
      --delete --no-progress --only-show-errors 2>/dev/null
}

# ---------- 3. Build openclaw.json ------------------------------------------
mkdir -p "$OPENCLAW_HOME" "$OPENCLAW_WORKSPACE_DIR" "$OPENCLAW_AUTH_PROFILE_SECRET_DIR"
CONFIG_FILE="${OPENCLAW_HOME}/openclaw.json"

CHANNELS_JSON='{}'
merge_channel() {
  # merge_channel <json-fragment>  → merges into CHANNELS_JSON
  CHANNELS_JSON=$(jq -s '.[0] * .[1]' <(printf '%s' "$CHANNELS_JSON") <(printf '%s' "$1"))
}

# ---- Telegram ----
if want_channel telegram; then
  if [[ -n "${TELEGRAM_ALLOWED_USER_IDS:-}" ]]; then
    TG_DM_POLICY=allowlist
    TG_ALLOW_JSON=$(printf '%s' "$TELEGRAM_ALLOWED_USER_IDS" \
      | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | jq -R . | jq -s .)
    log "Telegram dmPolicy=allowlist (${TELEGRAM_ALLOWED_USER_IDS})"
  else
    TG_DM_POLICY=pairing
    TG_ALLOW_JSON='[]'
    log "WARNING: TELEGRAM_ALLOWED_USER_IDS unset → pairing mode. First DM gets a"
    log "         pairing code, not an answer. Approve via:"
    log "         openclaw-cli pairing approve telegram <code>"
  fi

  if [[ "$TELEGRAM_MODE" == "webhook" ]]; then
    require PUBLIC_BASE_URL "webhook mode needs the public https URL Telegram will call (e.g. https://bot.example.com or https://user-space.hf.space)"
    WEBHOOK_SECRET=${TELEGRAM_WEBHOOK_SECRET:-$(rand_hex)}
    WEBHOOK_PATH=${TELEGRAM_WEBHOOK_PATH:-/telegram-webhook}
    # Persist the generated secret so the CF Worker / setWebhook can reuse it.
    echo "$WEBHOOK_SECRET" > "${OPENCLAW_HOME}/.webhook-secret"
    log "Telegram webhook → ${PUBLIC_BASE_URL}${WEBHOOK_PATH} (secret: $(mask "$WEBHOOK_SECRET"))"
    TG_FRAGMENT=$(jq -n \
      --arg t "$TELEGRAM_BOT_TOKEN" --arg p "$TG_DM_POLICY" --argjson a "$TG_ALLOW_JSON" \
      --arg url "${PUBLIC_BASE_URL}${WEBHOOK_PATH}" --arg sec "$WEBHOOK_SECRET" \
      --arg wpath "$WEBHOOK_PATH" --argjson wport "$PUBLIC_PORT" \
      '{telegram:{enabled:true,botToken:$t,dmPolicy:$p,allowFrom:$a,
                  webhookUrl:$url,webhookSecret:$sec,webhookPath:$wpath,
                  webhookHost:"0.0.0.0",webhookPort:$wport}}')
  else
    TG_FRAGMENT=$(jq -n \
      --arg t "$TELEGRAM_BOT_TOKEN" --arg p "$TG_DM_POLICY" --argjson a "$TG_ALLOW_JSON" \
      '{telegram:{enabled:true,botToken:$t,dmPolicy:$p,allowFrom:$a}}')
  fi
  merge_channel "$TG_FRAGMENT"
fi

# ---- Discord (token only; pairing default) ----
if want_channel discord; then
  log "Discord channel enabled."
  merge_channel "$(jq -n --arg t "$DISCORD_BOT_TOKEN" \
    '{discord:{enabled:true,botToken:$t,dmPolicy:"pairing"}}')"
fi

# ---- Slack (bot + optional app token) ----
if want_channel slack; then
  log "Slack channel enabled."
  merge_channel "$(jq -n --arg b "$SLACK_BOT_TOKEN" --arg a "${SLACK_APP_TOKEN:-}" \
    '{slack:({enabled:true,botToken:$b,dmPolicy:"pairing"} +
             (if $a != "" then {appToken:$a} else {} end))}')"
fi

jq -n --arg model "$MODEL" --argjson channels "$CHANNELS_JSON" \
  '{agents:{defaults:{model:$model}},
    channels:$channels,
    gateway:{mode:"local",bind:"lan"}}' > "$CONFIG_FILE"
log "Wrote ${CONFIG_FILE}"

# ---------- provider + OTEL env exports -------------------------------------
case "$AI_PROVIDER" in
  claude)   export ANTHROPIC_API_KEY ;;
  openai)   export OPENAI_API_KEY ;;
  gemini)   export GEMINI_API_KEY GOOGLE_API_KEY="$GEMINI_API_KEY" ;;
  deepseek) export DEEPSEEK_API_KEY
            export OPENAI_API_KEY="$DEEPSEEK_API_KEY"
            export OPENAI_BASE_URL="${DEEPSEEK_BASE_URL:-https://api.deepseek.com/v1}" ;;
esac

# #9 Observability: forward OTEL config if present. Requires the
# @openclaw/diagnostics-otel plugin to be installed + enabled (see README).
if [[ -n "${OTEL_EXPORTER_OTLP_ENDPOINT:-}" ]]; then
  export OTEL_EXPORTER_OTLP_ENDPOINT
  export OTEL_EXPORTER_OTLP_PROTOCOL="${OTEL_EXPORTER_OTLP_PROTOCOL:-http/protobuf}"
  export OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-openclaw-gateway}"
  [[ -n "${OTEL_EXPORTER_OTLP_HEADERS:-}" ]] && export OTEL_EXPORTER_OTLP_HEADERS
  log "OpenTelemetry export → ${OTEL_EXPORTER_OTLP_ENDPOINT}"
fi

# ---------- 4. Start gateway -------------------------------------------------
log "Starting openclaw-gateway on :${GATEWAY_PORT}…"
openclaw-gateway --port "$GATEWAY_PORT" --host 0.0.0.0 &
GATEWAY_PID=$!

# ---------- 5. Wait for readiness -------------------------------------------
log "Waiting for /healthz on :${GATEWAY_PORT}…"
for i in {1..90}; do
  if curl -fsS "http://127.0.0.1:${GATEWAY_PORT}/healthz" >/dev/null 2>&1; then
    log "Gateway healthy after ${i}s."; break
  fi
  kill -0 "$GATEWAY_PID" 2>/dev/null || fail "Gateway exited during startup. See logs above."
  sleep 1
  [[ $i -eq 90 ]] && fail "Gateway did not become healthy within 90s."
done

if [[ "$TELEGRAM_MODE" == "webhook" ]]; then
  log "Webhook mode active. OpenClaw registers the webhook with Telegram on"
  log "startup. If messages don't arrive, run scripts/set-webhook.sh to re-register."
fi

# ---------- 6. R2 sync loop + SIGUSR1 immediate sync ------------------------
if [[ $R2_ENABLED -eq 1 ]]; then
  # Periodic loop
  if [[ $R2_SYNC_INTERVAL -gt 0 ]]; then
    ( while sleep "$R2_SYNC_INTERVAL"; do
        if push_to_r2; then log "R2 sync OK."; else log "R2 sync failed (continuing)."; fi
      done ) &
    SYNC_PID=$!
    log "Periodic R2 sync every ${R2_SYNC_INTERVAL}s (pid=${SYNC_PID})."
  fi
  # #7 Event-triggered: `kill -USR1 1` (or from a skill) flushes immediately.
  trap 'log "SIGUSR1 → immediate R2 sync"; if push_to_r2; then log "R2 sync OK."; else log "R2 sync failed."; fi' SIGUSR1
  log "Send SIGUSR1 to PID 1 to force an immediate R2 sync."
fi

# ---------- 7. Graceful shutdown --------------------------------------------
shutdown() {
  log "Caught termination signal — shutting down…"
  if [[ $R2_ENABLED -eq 1 ]]; then log "Final R2 sync…"; push_to_r2 || true; fi
  if [[ -n "${SYNC_PID:-}" ]]; then kill "$SYNC_PID" 2>/dev/null || true; fi
  if kill -0 "$GATEWAY_PID" 2>/dev/null; then kill -TERM "$GATEWAY_PID"; wait "$GATEWAY_PID" 2>/dev/null || true; fi
  log "Bye."; exit 0
}
trap shutdown SIGTERM SIGINT

log "Ready. Message your bot on: ${CHANNELS}."
wait "$GATEWAY_PID"
