// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 ldcstc-gif <https://github.com/ldcstc-gif>
// Author: ldcstc-gif — original work — https://github.com/ldcstc-gif/openclaw-free-deploy

/**
 * cloudflare/worker.js  (v2)
 *
 * Two jobs in one Worker:
 *
 *   1. Telegram webhook gateway  (#2, #5)
 *      POST /telegram-webhook  →  validates the X-Telegram-Bot-Api-Secret-Token
 *      header AND (optionally) the source IP against Telegram's published
 *      ranges, then forwards to the HF Space. Anything failing → 403.
 *
 *   2. Reverse proxy for everything else
 *      bot.yourdomain.com/*  →  <user>-<space>.hf.space/*
 *      Preserves method, headers, body; supports WebSocket upgrades.
 *
 * Bindings (set by deploy-worker.sh):
 *   env.HF_SPACE_URL          required — "https://user-space.hf.space"
 *   env.WEBHOOK_SECRET        optional — must equal the secret OpenClaw uses;
 *                             if unset, webhook secret-check is skipped (NOT
 *                             recommended).
 *   env.WEBHOOK_PATH          optional — default "/telegram-webhook"
 *   env.TELEGRAM_IP_CHECK     optional — "1" to enforce IP allowlist
 *
 * Telegram webhook source ranges (IPv4, per Telegram docs):
 *   149.154.160.0/20  and  91.108.4.0/22
 */

const TELEGRAM_CIDRS = [
  { base: '149.154.160.0', bits: 20 },
  { base: '91.108.4.0',    bits: 22 },
];

function ipv4ToInt(ip) {
  const p = ip.split('.');
  if (p.length !== 4) return null;
  let n = 0;
  for (const octet of p) {
    const v = Number(octet);
    if (!Number.isInteger(v) || v < 0 || v > 255) return null;
    n = (n << 8) | v;
  }
  return n >>> 0;
}

function ipInCidr(ip, base, bits) {
  const a = ipv4ToInt(ip);
  const b = ipv4ToInt(base);
  if (a === null || b === null) return false;
  const mask = bits === 0 ? 0 : (~0 << (32 - bits)) >>> 0;
  return (a & mask) === (b & mask);
}

function isTelegramIp(ip) {
  if (!ip) return false;
  // IPv6 (contains ':') can't be matched against Telegram's IPv4 ranges.
  // Telegram uses IPv4 for webhooks; if we somehow see IPv6, fail closed only
  // when IP check is on AND the secret already passed (handled by caller).
  if (ip.includes(':')) return false;
  return TELEGRAM_CIDRS.some(c => ipInCidr(ip, c.base, c.bits));
}

async function proxyToUpstream(request, env, pathOverride) {
  const upstream = env.HF_SPACE_URL;
  const inUrl  = new URL(request.url);
  const outUrl = new URL(upstream);
  outUrl.pathname = pathOverride || inUrl.pathname;
  outUrl.search   = inUrl.search;

  const headers = new Headers();
  for (const [k, v] of request.headers) {
    const lk = k.toLowerCase();
    if (lk.startsWith('cf-')) continue;
    if (lk === 'x-forwarded-for' || lk === 'x-forwarded-proto' ||
        lk === 'x-real-ip' || lk === 'host') continue;
    headers.set(k, v);
  }
  headers.set('Host', outUrl.host);
  headers.set('X-Forwarded-Host', inUrl.host);
  headers.set('X-Forwarded-Proto', inUrl.protocol.replace(':', ''));
  const clientIp = request.headers.get('cf-connecting-ip');
  if (clientIp) headers.set('X-Forwarded-For', clientIp);

  const init = {
    method: request.method,
    headers,
    body: ['GET', 'HEAD'].includes(request.method) ? undefined : request.body,
    redirect: 'manual',
  };

  let resp;
  try {
    resp = await fetch(outUrl.toString(), init);
  } catch (err) {
    return new Response(`Upstream fetch failed: ${err?.message || err}`,
      { status: 502, headers: { 'content-type': 'text/plain; charset=utf-8' } });
  }

  // WebSocket upgrade passthrough.
  if (resp.status === 101 && resp.webSocket) {
    return new Response(null, { status: 101, webSocket: resp.webSocket, headers: resp.headers });
  }

  const outHeaders = new Headers(resp.headers);
  outHeaders.delete('content-security-policy');
  outHeaders.delete('strict-transport-security');
  return new Response(resp.body, {
    status: resp.status, statusText: resp.statusText, headers: outHeaders,
  });
}

export default {
  async fetch(request, env) {
    if (!env.HF_SPACE_URL) {
      return new Response('Worker misconfigured: HF_SPACE_URL is not set.\n',
        { status: 502, headers: { 'content-type': 'text/plain; charset=utf-8' } });
    }

    const url = new URL(request.url);
    const webhookPath = env.WEBHOOK_PATH || '/telegram-webhook';

    // ---- 1. Telegram webhook ----
    if (request.method === 'POST' && url.pathname === webhookPath) {
      // Secret-token check (Telegram echoes the secret we set via setWebhook).
      if (env.WEBHOOK_SECRET) {
        const got = request.headers.get('x-telegram-bot-api-secret-token');
        if (got !== env.WEBHOOK_SECRET) {
          return new Response('forbidden: bad secret token', { status: 403 });
        }
      }
      // Optional IP allowlist.
      if (env.TELEGRAM_IP_CHECK === '1') {
        const ip = request.headers.get('cf-connecting-ip');
        if (!isTelegramIp(ip)) {
          return new Response('forbidden: source IP not in Telegram ranges', { status: 403 });
        }
      }
      return proxyToUpstream(request, env, webhookPath);
    }

    // ---- 2. Everything else: reverse proxy ----
    return proxyToUpstream(request, env);
  },
};
