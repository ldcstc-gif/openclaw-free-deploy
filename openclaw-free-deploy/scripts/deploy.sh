#!/usr/bin/env bash
#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 ldcstc-gif <https://github.com/ldcstc-gif>
# Author: ldcstc-gif — original work — https://github.com/ldcstc-gif/openclaw-free-deploy
#
# ==============================================================================
# scripts/deploy.sh — Push this repo to a HuggingFace Space.
#
# Usage:   ./scripts/deploy.sh <hf-username> <space-name> [hf-token]
# Example: ./scripts/deploy.sh forever openclaw-bot hf_xxxxxxxxxxxx
#
#   1. Creates the Space (Docker SDK) if missing, via the HF API.
#   2. Adds/refreshes a `huggingface` git remote with the token for auth.
#   3. Force-pushes the current branch to the Space's main branch.
#
# HF write token: https://huggingface.co/settings/tokens
# ==============================================================================
set -Eeuo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <hf-username> <space-name> [hf-token]" >&2
  echo "Example: $0 forever openclaw-bot hf_xxx..." >&2
  exit 2
fi

HF_USER=$1
HF_SPACE=$2
HF_TOKEN=${3:-${HF_TOKEN:-}}

[[ -z "$HF_TOKEN" ]] && { echo "ERROR: HF token missing (3rd arg or \$HF_TOKEN)." >&2; \
  echo "       Create one (write scope): https://huggingface.co/settings/tokens" >&2; exit 1; }

git rev-parse --git-dir   >/dev/null 2>&1 || { echo "ERROR: not a git repo. Run git init/add/commit first." >&2; exit 1; }
git rev-parse HEAD        >/dev/null 2>&1 || { echo "ERROR: no commits yet." >&2; exit 1; }

API_BASE=https://huggingface.co/api
SPACE_URL="https://huggingface.co/spaces/${HF_USER}/${HF_SPACE}"

echo "==> Ensuring Space exists: ${HF_USER}/${HF_SPACE}"
http_code=$(curl -s -o /dev/null -w '%{http_code}' \
  -H "Authorization: Bearer ${HF_TOKEN}" \
  "${API_BASE}/spaces/${HF_USER}/${HF_SPACE}")

if [[ "$http_code" == "404" ]]; then
  echo "==> Creating Space (Docker SDK, public)…"
  curl -fsS -X POST \
    -H "Authorization: Bearer ${HF_TOKEN}" -H "Content-Type: application/json" \
    -d "{\"type\":\"space\",\"name\":\"${HF_SPACE}\",\"organization\":null,\"private\":false,\"sdk\":\"docker\"}" \
    "${API_BASE}/repos/create" >/dev/null || { echo "ERROR: Space creation failed." >&2; exit 1; }
  echo "    Created: ${SPACE_URL}"
elif [[ "$http_code" == "200" ]]; then
  echo "    Already exists: ${SPACE_URL}"
else
  echo "ERROR: unexpected HTTP ${http_code} checking Space." >&2; exit 1
fi

REMOTE_URL="https://${HF_USER}:${HF_TOKEN}@huggingface.co/spaces/${HF_USER}/${HF_SPACE}"
if git remote get-url huggingface >/dev/null 2>&1; then
  git remote set-url huggingface "$REMOTE_URL"
else
  git remote add huggingface "$REMOTE_URL"
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "==> Pushing ${CURRENT_BRANCH} → huggingface:main (force)…"
git push --force huggingface "${CURRENT_BRANCH}:main"

cat <<EOF

✅ Deploy complete.
   Build logs: ${SPACE_URL}
   Live URL:   https://${HF_USER}-${HF_SPACE}.hf.space

Set these as Space SECRETS (Settings → Variables and secrets → Secret):
   TELEGRAM_BOT_TOKEN, TELEGRAM_ALLOWED_USER_IDS, AI_PROVIDER,
   <provider>_API_KEY, S3_ENDPOINT, S3_ACCESS_KEY, S3_SECRET_KEY, S3_BUCKET

If using webhook mode also set: TELEGRAM_MODE=webhook, PUBLIC_BASE_URL=<your url>
EOF
