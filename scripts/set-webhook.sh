#!/usr/bin/env bash
#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 ldcstc-gif <https://github.com/ldcstc-gif>
# Author: ldcstc-gif — original work — https://github.com/ldcstc-gif/openclaw-free-deploy
#
# ==============================================================================
# scripts/set-webhook.sh — Register (or inspect) the Telegram webhook.  (#2)
#
# OpenClaw registers the webhook automatically on startup in webhook mode. Use
# this script only to re-register after a URL/secret change, or to diagnose.
#
# Usage:
#   PUBLIC_BASE_URL=https://bot.example.com \
#   TELEGRAM_BOT_TOKEN=123:abc \
#   [TELEGRAM_WEBHOOK_SECRET=...] ./scripts/set-webhook.sh [set|info|delete]
#
#   set    (default) — calls setWebhook with the secret token
#   info             — prints current webhook status (getWebhookInfo)
#   delete           — removes the webhook (revert to polling)
# ==============================================================================
set -Eeuo pipefail

ACTION=${1:-set}
: "${TELEGRAM_BOT_TOKEN:?set TELEGRAM_BOT_TOKEN}"
API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"
WEBHOOK_PATH=${TELEGRAM_WEBHOOK_PATH:-/telegram-webhook}

case "$ACTION" in
  info)
    curl -fsS "${API}/getWebhookInfo" | jq .
    ;;
  delete)
    echo "==> Deleting webhook (drop_pending_updates=true)…"
    curl -fsS "${API}/deleteWebhook?drop_pending_updates=true" | jq .
    echo "Done. Set TELEGRAM_MODE=polling and redeploy to use long-polling."
    ;;
  set)
    : "${PUBLIC_BASE_URL:?set PUBLIC_BASE_URL (e.g. https://bot.example.com)}"
    SECRET=${TELEGRAM_WEBHOOK_SECRET:-}
    if [[ -z "$SECRET" && -f "${HOME}/.openclaw/.webhook-secret" ]]; then
      SECRET=$(cat "${HOME}/.openclaw/.webhook-secret")
      echo "==> Using secret from ~/.openclaw/.webhook-secret"
    fi
    URL="${PUBLIC_BASE_URL%/}${WEBHOOK_PATH}"
    echo "==> setWebhook → ${URL}"
    # allowed_updates includes message_reaction so reactions work too.
    curl -fsS -X POST "${API}/setWebhook" \
      --data-urlencode "url=${URL}" \
      ${SECRET:+--data-urlencode "secret_token=${SECRET}"} \
      --data-urlencode 'allowed_updates=["message","edited_message","callback_query","message_reaction"]' \
      | jq .
    echo ""
    echo "Verify with: $0 info"
    ;;
  *)
    echo "Unknown action '$ACTION'. Use: set | info | delete" >&2; exit 2 ;;
esac
