#!/usr/bin/env node
/* eslint-disable no-console */
/**
 * Static config audit — sanity-checks the *shape* of production env vars
 * before deploy. Runs anywhere Node runs; no network calls; no secrets.
 *
 * What this catches:
 *   • CORS_ORIGINS missing / empty / contains '*' / has non-https origins
 *   • JWT secrets too short / equal to each other
 *   • FCM_SERVICE_ACCOUNT_JSON_BASE64 that doesn't base64-decode or isn't JSON
 *   • Cloudinary keys with obviously wrong shapes
 *   • Stripe keys used against wrong environment (sk_test on prod, etc.)
 *   • Common typo patterns (trailing whitespace, wrapped-in-quotes)
 *
 * Usage:
 *   NODE_ENV=production \
 *   CORS_ORIGINS=… \
 *   JWT_ACCESS_SECRET=… \
 *   … \
 *   node scripts/verify-config.mjs
 *
 * Or, on Fly:
 *   flyctl ssh console -a rent95-api -C 'node /app/scripts/verify-config.mjs'
 *
 * Exit codes:
 *   0  — all checks passed
 *   1  — one or more critical mis-configurations found
 */

const R = '\x1b[31m', G = '\x1b[32m', Y = '\x1b[33m', B = '\x1b[34m', D = '\x1b[2m', X = '\x1b[0m';
const TTY = process.stdout.isTTY;
const c = (s, code) => (TTY ? `${code}${s}${X}` : s);

let failures = 0;
let warnings = 0;

const pass = (msg) => console.log(`  ${c('OK  ', G)}${msg}`);
const warn = (msg) => { warnings++; console.log(`  ${c('WARN', Y)} ${msg}`); };
const fail = (msg) => { failures++; console.log(`  ${c('FAIL', R)} ${msg}`); };
const info = (msg) => console.log(`  ${c('·   ', B)}${msg}`);
const section = (t) => console.log(`\n${c('▎ ' + t, '\x1b[1m')}`);

const env = process.env;
const isProd = env.NODE_ENV === 'production';

console.log(c(`Rent95 static config audit — NODE_ENV=${env.NODE_ENV || '(unset)'}\n`, '\x1b[1m'));

if (!isProd) {
  warn('NODE_ENV is not "production" — some checks below are advisory only.');
}

// ---------------------------------------------------------------------------
// CORS_ORIGINS
// ---------------------------------------------------------------------------
section('CORS_ORIGINS');
{
  const raw = env.CORS_ORIGINS ?? '';
  const list = raw.split(',').map((s) => s.trim()).filter(Boolean);

  if (list.length === 0) {
    (isProd ? fail : warn)('CORS_ORIGINS is empty — API will reject every browser request in prod');
  } else {
    pass(`${list.length} origin(s) configured`);
  }

  for (const origin of list) {
    if (origin === '*') {
      fail(`wildcard "*" is present — CATASTROPHIC with credentials: true`);
    } else if (!/^https:\/\//.test(origin) && !/^http:\/\/localhost/.test(origin)) {
      (isProd ? fail : warn)(`origin "${origin}" is not https:// (localhost exempt)`);
    } else if (origin !== origin.trim() || / /.test(origin)) {
      fail(`origin "${origin}" has whitespace — split on commas but each entry must be clean`);
    } else if (/\/$/.test(origin)) {
      warn(`origin "${origin}" has trailing slash — browsers send Origin without trailing slash, this will never match`);
    } else {
      pass(`  ${origin}`);
    }
  }
}

// ---------------------------------------------------------------------------
// JWT secrets
// ---------------------------------------------------------------------------
section('JWT secrets');
{
  const access = env.JWT_ACCESS_SECRET || '';
  const refresh = env.JWT_REFRESH_SECRET || '';

  if (access.length < 32) fail(`JWT_ACCESS_SECRET length ${access.length} < 32 (recommend openssl rand -hex 32 → 64)`);
  else if (access.length < 64) warn(`JWT_ACCESS_SECRET length ${access.length} — 64 (hex-32-bytes) is the recommended floor`);
  else pass(`JWT_ACCESS_SECRET length ${access.length}`);

  if (refresh.length < 32) fail(`JWT_REFRESH_SECRET length ${refresh.length} < 32`);
  else if (refresh.length < 64) warn(`JWT_REFRESH_SECRET length ${refresh.length} — recommend 64`);
  else pass(`JWT_REFRESH_SECRET length ${refresh.length}`);

  if (access && refresh && access === refresh) {
    fail('JWT_ACCESS_SECRET === JWT_REFRESH_SECRET — must be distinct');
  } else if (access && refresh) {
    pass('access and refresh secrets are distinct');
  }

  // Weak-value detection: if the secret is "changeme" or an obvious placeholder.
  for (const [name, val] of [['JWT_ACCESS_SECRET', access], ['JWT_REFRESH_SECRET', refresh]]) {
    if (/(change[-_ ]?me|placeholder|example|test-secret|foo|bar|password)/i.test(val)) {
      fail(`${name} looks like a placeholder value`);
    }
  }
}

// ---------------------------------------------------------------------------
// Stripe
// ---------------------------------------------------------------------------
section('Stripe');
{
  const sk = env.STRIPE_SECRET_KEY || '';
  const wh = env.STRIPE_WEBHOOK_SECRET || '';

  if (!sk) {
    (isProd ? fail : warn)('STRIPE_SECRET_KEY is unset');
  } else if (!/^sk_(live|test)_[A-Za-z0-9]{20,}$/.test(sk)) {
    fail(`STRIPE_SECRET_KEY doesn't match sk_(live|test)_… shape`);
  } else if (isProd && sk.startsWith('sk_test_')) {
    fail('STRIPE_SECRET_KEY is a TEST key but NODE_ENV=production');
  } else if (!isProd && sk.startsWith('sk_live_')) {
    fail('STRIPE_SECRET_KEY is a LIVE key but NODE_ENV!=production — pull the plug NOW');
  } else {
    pass(`STRIPE_SECRET_KEY ${sk.startsWith('sk_live_') ? 'LIVE' : 'test'} mode, correct shape`);
  }

  if (!wh) {
    (isProd ? fail : warn)('STRIPE_WEBHOOK_SECRET is unset');
  } else if (!/^whsec_[A-Za-z0-9]{20,}$/.test(wh)) {
    fail(`STRIPE_WEBHOOK_SECRET doesn't match whsec_… shape`);
  } else {
    pass('STRIPE_WEBHOOK_SECRET shape looks valid');
  }

  // A common misconfig: the two keys accidentally swapped.
  if (sk.startsWith('whsec_')) fail('STRIPE_SECRET_KEY starts with whsec_ — keys swapped?');
  if (wh.startsWith('sk_'))    fail('STRIPE_WEBHOOK_SECRET starts with sk_ — keys swapped?');
}

// ---------------------------------------------------------------------------
// Cloudinary
// ---------------------------------------------------------------------------
section('Cloudinary');
{
  const cloud = env.CLOUDINARY_CLOUD_NAME || '';
  const key = env.CLOUDINARY_API_KEY || '';
  const secret = env.CLOUDINARY_API_SECRET || '';

  if (!cloud) (isProd ? fail : warn)('CLOUDINARY_CLOUD_NAME unset');
  else if (!/^[a-z0-9][a-z0-9-]*$/i.test(cloud)) fail(`CLOUDINARY_CLOUD_NAME "${cloud}" has odd characters`);
  else pass(`cloud name "${cloud}"`);

  if (!key)    (isProd ? fail : warn)('CLOUDINARY_API_KEY unset');
  else if (!/^\d{10,}$/.test(key))  warn(`CLOUDINARY_API_KEY doesn't look like a numeric string`);
  else pass(`API key looks well-formed (${key.length} digits)`);

  if (!secret) (isProd ? fail : warn)('CLOUDINARY_API_SECRET unset');
  else if (secret.length < 20) fail(`CLOUDINARY_API_SECRET length ${secret.length} < 20 — probably truncated`);
  else pass(`API secret length ${secret.length}`);
}

// ---------------------------------------------------------------------------
// FCM
// ---------------------------------------------------------------------------
section('Firebase (FCM_SERVICE_ACCOUNT_JSON_BASE64)');
{
  const b64 = env.FCM_SERVICE_ACCOUNT_JSON_BASE64 || '';
  if (!b64) {
    warn('FCM_SERVICE_ACCOUNT_JSON_BASE64 unset — push notifications will be disabled');
  } else {
    let json;
    try {
      json = Buffer.from(b64, 'base64').toString('utf-8');
    } catch (e) {
      fail(`base64 decode threw: ${e.message}`);
      json = null;
    }
    if (json) {
      let parsed;
      try {
        parsed = JSON.parse(json);
      } catch (e) {
        fail(`decoded string is not JSON: ${e.message}`);
      }
      if (parsed) {
        const required = ['type', 'project_id', 'private_key', 'client_email'];
        const missing = required.filter((k) => !parsed[k]);
        if (missing.length) {
          fail(`FCM JSON is missing required fields: ${missing.join(', ')}`);
        } else if (parsed.type !== 'service_account') {
          fail(`FCM JSON type="${parsed.type}", expected "service_account"`);
        } else {
          pass(`FCM decodes to ${parsed.project_id} (${parsed.client_email})`);
        }
        // Common paste error: private_key line-breaks escaped as literal '\n'
        // in the decoded string (i.e. the JSON was double-encoded).
        if (parsed.private_key && !parsed.private_key.includes('\n')) {
          warn('FCM private_key does not contain real newlines — the JSON may have been double-escaped');
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Sentry
// ---------------------------------------------------------------------------
section('Sentry');
{
  const dsn = env.SENTRY_DSN || '';
  if (!dsn) {
    (isProd ? warn : info)('SENTRY_DSN unset — errors will only reach stdout');
  } else if (!/^https:\/\/[a-f0-9]+@[^/]+\/\d+$/.test(dsn)) {
    fail('SENTRY_DSN does not match https://<key>@<host>/<project>');
  } else {
    pass('SENTRY_DSN shape looks valid');
  }
}

// ---------------------------------------------------------------------------
// Admin session (rent95-admin only)
// ---------------------------------------------------------------------------
section('Admin panel');
{
  const secret = env.ADMIN_SESSION_SECRET || '';
  if (!secret) {
    (isProd ? fail : warn)('ADMIN_SESSION_SECRET unset');
  } else if (secret.length < 32) {
    fail(`ADMIN_SESSION_SECRET length ${secret.length} < 32`);
  } else if (secret === env.JWT_ACCESS_SECRET || secret === env.JWT_REFRESH_SECRET) {
    fail('ADMIN_SESSION_SECRET reuses an API-side secret — must be its own value');
  } else {
    pass(`ADMIN_SESSION_SECRET length ${secret.length}`);
  }
}

// ---------------------------------------------------------------------------
// Common-typo catchall
// ---------------------------------------------------------------------------
section('Common typo detection');
{
  const suspects = [
    'CORS_ORIGINS', 'STRIPE_SECRET_KEY', 'STRIPE_WEBHOOK_SECRET',
    'JWT_ACCESS_SECRET', 'JWT_REFRESH_SECRET',
    'CLOUDINARY_API_SECRET', 'DATABASE_URL', 'REDIS_URL',
  ];
  let hits = 0;
  for (const name of suspects) {
    const val = env[name] ?? '';
    if (val && (val.startsWith('"') || val.startsWith("'") || val.endsWith('"') || val.endsWith("'"))) {
      fail(`${name} is wrapped in quotes — .env files strip them, but Fly secrets don't`);
      hits++;
    }
    if (val && val !== val.trim()) {
      fail(`${name} has leading/trailing whitespace`);
      hits++;
    }
  }
  if (hits === 0) pass('no obvious quoting / whitespace issues');
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
console.log('\n' + c('══════════════════════════════════', '\x1b[1m'));
console.log(`  ${c('Warn:', Y)} ${warnings}   ${c('Fail:', R)} ${failures}`);
console.log(c('══════════════════════════════════', '\x1b[1m'));

if (failures > 0) {
  console.log(`\n${c('Fix the above before deploying to production.', R)}`);
  process.exit(1);
}
process.exit(0);
