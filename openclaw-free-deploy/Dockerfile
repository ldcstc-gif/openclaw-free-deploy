# syntax=docker/dockerfile:1.7
#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 ldcstc-gif <https://github.com/ldcstc-gif>
# Author: ldcstc-gif — original work — https://github.com/ldcstc-gif/openclaw-free-deploy
#
# ------------------------------------------------------------------------------
# OpenClaw multi-channel bot — HuggingFace Spaces Docker image  (v2)
#
# This is the FULL build. For ~30s cold starts after the GHCR workflow has
# published an image, swap to Dockerfile.prebuilt (see README "Faster boots").
#
# Constraints:
#   * OpenClaw requires Node 24 (recommended) or 22.19+. Node 20 fails.
#   * HF Spaces exposes ONE port (7860).
#   * The `openclaw` npm package provides: openclaw-gateway, openclaw-cli, openclaw.
# ------------------------------------------------------------------------------
FROM node:24-bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    NODE_ENV=production \
    OPENCLAW_HOME=/home/user/.openclaw \
    OPENCLAW_CONFIG_DIR=/home/user/.openclaw \
    OPENCLAW_WORKSPACE_DIR=/home/user/.openclaw/workspace \
    OPENCLAW_AUTH_PROFILE_SECRET_DIR=/home/user/.config/openclaw \
    OPENCLAW_DISABLE_BONJOUR=1 \
    HOME=/home/user \
    PATH=/home/user/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# tini=PID1 init; curl=health/keepalive; jq=config writes; git=some skills;
# awscli=R2 sync; ca-certs+tzdata=TLS + timestamps.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      tini curl jq git ca-certificates tzdata awscli \
 && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# HF runs the container as uid 1000; mirror it to avoid bind-mount perm errors.
RUN useradd -m -u 1000 -s /bin/bash user \
 && mkdir -p /home/user/.npm-global /home/user/.openclaw/workspace \
             /home/user/.config/openclaw /data \
 && chown -R user:user /home/user /data

USER user
WORKDIR /home/user

# Pin a version for reproducible builds. Override: --build-arg OPENCLAW_VERSION=2026.x.y
ARG OPENCLAW_VERSION=latest
RUN npm config set prefix /home/user/.npm-global \
 && npm install -g openclaw@${OPENCLAW_VERSION} \
 && npm cache clean --force

# #9 (optional) bake the OpenTelemetry diagnostics plugin at build time.
#   docker build --build-arg WITH_OTEL=1 ...
ARG WITH_OTEL=0
RUN if [ "$WITH_OTEL" = "1" ]; then \
      npm install -g @openclaw/diagnostics-otel || \
      echo "WARN: diagnostics-otel install failed; install at runtime instead"; \
    fi

COPY --chown=user:user scripts/start.sh /home/user/start.sh
RUN chmod +x /home/user/start.sh

EXPOSE 7860

# start.sh writes the gateway's actual port to /tmp/openclaw-health-port so this
# static healthcheck works in both polling (7860) and webhook (18789) modes.
HEALTHCHECK --interval=30s --timeout=10s --start-period=150s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:$(cat /tmp/openclaw-health-port 2>/dev/null || echo 7860)/healthz" || exit 1

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/home/user/start.sh"]
