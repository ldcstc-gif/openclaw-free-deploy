#!/usr/bin/env bash
#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 ldcstc-gif <https://github.com/ldcstc-gif>
# Author: ldcstc-gif — original work — https://github.com/ldcstc-gif/openclaw-free-deploy
#
# ==============================================================================
# start.sh — HuggingFace Spaces entrypoint for the OFFICIAL OpenClaw image.
#
# Flow:
#   1. validate env + pick provider                (deepseek by default)
#   2. restore /home/node/.openclaw from R2         (state only; never secrets)
#   3. configure non-interactively                  (onboard once + telegram each boot)
#   4. run `openclaw gateway --bind lan --port 7860`
#   5. periodic + on-shutdown R2 sync               (excludes .env, so no key leaks)
#
# Secrets (DEEPSEEK_API_KEY / TELEGRAM_BOT_TOKEN / R2 keys) come from the
# process environment (HF Space Secrets). The provider key is read directly by
# the gateway, and is referenced (not copied) by the auth profile, so it is
# never written to R2.
# ==============================================================================
set -Eeuo pipefail

log()  { printf '[start %s] %s\n' "$(date -u +%H:%M:%SZ)" "$*"; }
fail() { printf '\n\033[1;31m[start ERROR]\033[0m %s\n\n' "$*" >&2; exit 1; }
mask() { local v=${1:-}; if [ ${#v} -le 4 ]; then echo '****'; else echo "****${v: -4}"; fi; }

OPENCLAW=/app/openclaw.mjs
PORT="${PORT:-7860}"
export OPENCLAW_HOME="${OPENCLAW_HOME:-/home/node}"
export OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-/home/node/.openclaw}"
export OPENCLAW_CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-$OPENCLAW_STATE_DIR/openclaw.json}"
export OPENCLAW_CONFIG_DIR="${OPENCLAW_CONFIG_DIR:-$OPENCLAW_STATE_DIR}"
export OPENCLAW_WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-$OPENCLAW_STATE_DIR/workspace}"
mkdir -p "$OPENCLAW_STATE_DIR" "$OPENCLAW_WORKSPACE_DIR"

# ---------- 1. provider -------------------------------------------------------
AI_PROVIDER="${AI_PROVIDER:-deepseek}"
case "$AI_PROVIDER" in
  deepseek)  AUTH_CHOICE="deepseek-api-key"; KEY_VAR="DEEPSEEK_API_KEY" ;;
  openai)    AUTH_CHOICE="openai-api-key";   KEY_VAR="OPENAI_API_KEY" ;;
  gemini)    AUTH_CHOICE="gemini-api-key";   KEY_VAR="GEMINI_API_KEY" ;;
  anthropic) AUTH_CHOICE="apiKey";           KEY_VAR="ANTHROPIC_API_KEY" ;;
  *) fail "Unsupported AI_PROVIDER='$AI_PROVIDER' (use: deepseek|openai|gemini|anthropic)" ;;
esac
[ -n "${!KEY_VAR:-}" ] || fail "$KEY_VAR is not set — add it as a Space Secret (provider=$AI_PROVIDER)."
[ -n "${TELEGRAM_BOT_TOKEN:-}" ] || fail "TELEGRAM_BOT_TOKEN is not set — add it as a Space Secret."

# A token is REQUIRED to bind beyond loopback. Generate an ephemeral one if the
# user didn't set OPENCLAW_GATEWAY_TOKEN (Telegram still works; only the Control
# UI login token rotates per boot).
if [ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]; then
  OPENCLAW_GATEWAY_TOKEN="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  log "OPENCLAW_GATEWAY_TOKEN not set — generated an ephemeral one for this boot."
fi
export OPENCLAW_GATEWAY_TOKEN
log "Provider: ${AI_PROVIDER} (${KEY_VAR}=$(mask "${!KEY_VAR}"))  Port: ${PORT}"

# ---------- 2. restore state from R2 -----------------------------------------
R2_ENABLED=0
if [ -n "${S3_ENDPOINT:-}" ] && [ -n "${S3_ACCESS_KEY:-}" ] && [ -n "${S3_SECRET_KEY:-}" ]; then
  R2_ENABLED=1
  S3_BUCKET="${S3_BUCKET:-openclaw-state}"
  S3_PREFIX="${S3_PREFIX:-openclaw}"
  export RCLONE_CONFIG_R2_TYPE=s3
  export RCLONE_CONFIG_R2_PROVIDER=Cloudflare
  export RCLONE_CONFIG_R2_ACCESS_KEY_ID="$S3_ACCESS_KEY"
  export RCLONE_CONFIG_R2_SECRET_ACCESS_KEY="$S3_SECRET_KEY"
  export RCLONE_CONFIG_R2_ENDPOINT="$S3_ENDPOINT"
  export RCLONE_CONFIG_R2_REGION="${S3_REGION:-auto}"
  export RCLONE_CONFIG_R2_NO_CHECK_BUCKET=true
  R2_PATH="r2:${S3_BUCKET}/${S3_PREFIX}"
  R2_FLAGS=(--exclude ".env" --exclude "workspace/tmp/**" --transfers 8 --checkers 8)

  log "R2 enabled ($R2_PATH). Restoring state…"
  # Limit restore to 40s so a slow R2 connection can't delay gateway startup
  # past Render's port-scan window. Non-fatal either way.
  if timeout 40 rclone copy "$R2_PATH" "$OPENCLAW_STATE_DIR" \
       "${R2_FLAGS[@]}" --contimeout 10s --timeout 30s 2>/dev/null; then
    log "R2 restore complete."
  else
    log "R2 restore had no data / timed out / non-fatal error (likely first run)."
  fi
else
  log "R2 NOT configured — state is EPHEMERAL. Set S3_* secrets to persist."
fi

push_to_r2() {
  [ "$R2_ENABLED" -eq 1 ] || return 0
  rclone sync "$OPENCLAW_STATE_DIR" "$R2_PATH" "${R2_FLAGS[@]}" 2>/dev/null
}

# ---------- 3. configure (non-interactive) -----------------------------------
# 3a. Provider/auth/model: onboard ONCE. If state was restored (config already
#     mentions the provider), skip — onboarding picks the correct default model,
#     so we never hard-code a model id.
if [ -f "$OPENCLAW_CONFIG_PATH" ] && grep -q "\"$AI_PROVIDER\"" "$OPENCLAW_CONFIG_PATH" 2>/dev/null; then
  log "Provider already configured in state; skipping onboarding."
else
  log "Onboarding provider=$AI_PROVIDER (non-interactive, secret kept as env ref)…"
  node "$OPENCLAW" onboard --non-interactive --mode local \
    --auth-choice "$AUTH_CHOICE" --secret-input-mode ref --accept-risk \
    --gateway-port "$PORT" --gateway-bind loopback \
    --skip-bootstrap --skip-skills --skip-health \
    || fail "onboard failed — check the flags against 'openclaw onboard --help' in the official image."
fi

# 3b. Telegram channel: write EVERY boot from env (idempotent), so token /
#     allowlist changes always take effect without re-onboarding.
if [ -n "${TELEGRAM_ALLOWED_USER_IDS:-}" ]; then
  ALLOW_JSON="$(printf '%s' "$TELEGRAM_ALLOWED_USER_IDS" \
      | tr ',' '\n' | sed '/^[[:space:]]*$/d;s/^[[:space:]]*//;s/[[:space:]]*$//' \
      | jq -R . | jq -s .)"
  DM_POLICY="allowlist"
  log "Telegram dmPolicy=allowlist (${TELEGRAM_ALLOWED_USER_IDS})"
else
  ALLOW_JSON='[]'
  DM_POLICY="pairing"
  log "WARNING: TELEGRAM_ALLOWED_USER_IDS unset → pairing mode. First DM returns a"
  log "         pairing code; approve with: openclaw pairing approve telegram <code>"
fi

TG_BATCH="$(jq -n --arg t "$TELEGRAM_BOT_TOKEN" --arg p "$DM_POLICY" --argjson allow "$ALLOW_JSON" '[
  {path:"plugins.entries.telegram.enabled", value:true},
  {path:"channels.telegram.enabled",        value:true},
  {path:"channels.telegram.botToken",       value:$t},
  {path:"channels.telegram.dmPolicy",       value:$p},
  {path:"channels.telegram.allowFrom",      value:$allow}
]')"
node "$OPENCLAW" config set --batch-json "$TG_BATCH" \
  || fail "telegram config set failed."
log "Telegram channel configured."

# 3c. Pre-approve a Control UI device so the browser doesn't prompt for pairing
#     on every new deployment. Set CONTROL_UI_DEVICE_ID to the UUID shown in
#     the "Device pairing required" dialog.
if [ -n "${CONTROL_UI_DEVICE_ID:-}" ]; then
  if node "$OPENCLAW" devices approve "$CONTROL_UI_DEVICE_ID" 2>/dev/null; then
    log "Control UI device pre-approved: ${CONTROL_UI_DEVICE_ID}."
  else
    log "Control UI device approve skipped (may already be approved)."
  fi
fi

# 3d. Control UI allowed origins: whitelist PUBLIC_BASE_URL so the browser-based
#     UI can connect. Written every boot so URL changes take effect automatically.
if [ -n "${PUBLIC_BASE_URL:-}" ]; then
  ORIGIN="${PUBLIC_BASE_URL%/}"
  ORIGINS_JSON="$(jq -n --arg o "$ORIGIN" '[$o]')"
  if node "$OPENCLAW" config set --batch-json \
      "[{\"path\":\"gateway.controlUi.allowedOrigins\",\"value\":${ORIGINS_JSON}}]"; then
    log "Control UI origin whitelisted: ${ORIGIN}."
  else
    log "Control UI origin config failed (non-fatal)."
  fi
fi

# ---------- 4. start the gateway ---------------------------------------------
log "Starting gateway on 0.0.0.0:${PORT} (--bind lan)…"
node "$OPENCLAW" gateway --bind lan --port "$PORT" &
GATEWAY_PID=$!

log "Waiting for /healthz…"
for i in $(seq 1 90); do
  if node -e "fetch('http://127.0.0.1:${PORT}/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))" 2>/dev/null; then
    log "Gateway healthy after ${i}s."
    break
  fi
  kill -0 "$GATEWAY_PID" 2>/dev/null || fail "Gateway exited during startup (see logs above)."
  sleep 1
  [ "$i" -eq 90 ] && fail "Gateway did not become healthy within 90s."
done

# ---------- 5. R2 sync loop + signals ----------------------------------------
SYNC_PID=""
if [ "$R2_ENABLED" -eq 1 ]; then
  R2_SYNC_INTERVAL="${R2_SYNC_INTERVAL:-300}"
  if [ "$R2_SYNC_INTERVAL" -gt 0 ]; then
    ( while sleep "$R2_SYNC_INTERVAL"; do
        if push_to_r2; then log "R2 sync OK."; else log "R2 sync failed (continuing)."; fi
      done ) &
    SYNC_PID=$!
    log "Periodic R2 sync every ${R2_SYNC_INTERVAL}s (pid=$SYNC_PID)."
  fi
  trap 'log "SIGUSR1 → immediate R2 sync"; push_to_r2 && log "R2 sync OK." || log "R2 sync failed."' USR1
fi

shutdown() {
  log "Termination signal — shutting down…"
  if [ "$R2_ENABLED" -eq 1 ]; then log "Final R2 sync…"; push_to_r2 || true; fi
  [ -n "$SYNC_PID" ] && kill "$SYNC_PID" 2>/dev/null || true
  if kill -0 "$GATEWAY_PID" 2>/dev/null; then kill -TERM "$GATEWAY_PID"; wait "$GATEWAY_PID" 2>/dev/null || true; fi
  log "Bye."
  exit 0
}
trap shutdown TERM INT

log "Ready. DM your Telegram bot."
wait "$GATEWAY_PID"
