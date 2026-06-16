# syntax=docker/dockerfile:1
#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 ldcstc-gif <https://github.com/ldcstc-gif>
# Author: ldcstc-gif — original work — https://github.com/ldcstc-gif/openclaw-free-deploy
#
# ------------------------------------------------------------------------------
# HuggingFace Spaces image for OpenClaw.
#
# Built ON TOP of the OFFICIAL OpenClaw image (so we never reinvent its CLI):
#   * base provides: WORKDIR /app, USER node (uid 1000), ENTRYPOINT ["tini","-s","--"],
#     and `node openclaw.mjs <subcommand>`.
#   * we only add rclone (R2 sync) + jq (config building) and our start.sh,
#     then override CMD. tini stays PID 1, so signals/zombies are handled.
# ------------------------------------------------------------------------------
FROM ghcr.io/openclaw/openclaw:latest

# --- add the two tools we need (root), then drop back to the node user --------
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends rclone jq ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# entrypoint script
COPY scripts/start.sh /usr/local/bin/openclaw-hf-start.sh
RUN chmod +x /usr/local/bin/openclaw-hf-start.sh \
 && mkdir -p /home/node/.openclaw/workspace /home/node/.config/openclaw \
 && chown -R node:node /home/node/.openclaw /home/node/.config

# --- runtime config -----------------------------------------------------------
ENV OPENCLAW_HOME=/home/node \
    OPENCLAW_STATE_DIR=/home/node/.openclaw \
    OPENCLAW_CONFIG_PATH=/home/node/.openclaw/openclaw.json \
    OPENCLAW_CONFIG_DIR=/home/node/.openclaw \
    OPENCLAW_WORKSPACE_DIR=/home/node/.openclaw/workspace \
    OPENCLAW_DISABLE_BONJOUR=1 \
    PORT=7860

USER node
WORKDIR /app
EXPOSE 7860

# HF probes the port; this also self-heals a wedged gateway.
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=5 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||7860)+'/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

# Keep the base image's ENTRYPOINT (tini); only swap the command.
CMD ["/usr/local/bin/openclaw-hf-start.sh"]
