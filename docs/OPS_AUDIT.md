# Rent95 operational audit — findings + runbook

## The honest disclosure

You asked for a **live operational audit**. From inside this sandbox I
can't perform one — the sandbox has no outbound connection to
`rent95.app`, Stripe, Cloudinary, Fly, Firebase, or Sentry, and I don't
(and shouldn't) hold your credentials.

What this doc ships instead:

1. **What I CAN verify statically** — the code paths that will be
   exercised by the live audit.  ✅ Verified below.
2. **What YOU need to run** — the `scripts/preflight-audit.sh` script,
   which performs the actual live checks against your deployed stack.
3. **Manual verification steps** for human-in-the-loop items (Stripe
   Dashboard, Fly Postgres console, Firebase Console) that no script
   can automate cleanly.

---

## ✅ Statically verified from the codebase

### 1. Health endpoint contract

`rent95-api/src/routes/health.ts` exposes:
- `GET /health` — shallow, returns `{ status: 'ok', ts }` in <1ms
- `GET /health?deep=1` — pings Postgres with `SELECT 1`, returns
  `{ status: 'ok', ts, checks: { server: 'ok', database: 'ok' } }`
  on success; **503 with `checks.database: {error}`** on failure

The `preflight-audit.sh` script asserts both the 200 status AND
`checks.database === 'ok'`.

### 2. CORS strict callback

`rent95-api/src/app.ts` uses a callback-based origin check that:
- Allows requests with no Origin header (server-to-server, mobile native)
- Allows exact matches in the `Set(corsOrigins)`
- Throws for everything else → the request never gets ACAO reflected

The tests `security.test.ts` exercise both approved + unapproved paths.

### 3. Environment schema enforcement (Zod superRefine)

`rent95-api/src/config/env.ts` marks these fields REQUIRED when
`NODE_ENV=production`:

```
CORS_ORIGINS
STRIPE_SECRET_KEY
STRIPE_WEBHOOK_SECRET
CLOUDINARY_CLOUD_NAME
CLOUDINARY_API_KEY
CLOUDINARY_API_SECRET
JWT_ACCESS_SECRET (min 32 chars, distinct from refresh)
JWT_REFRESH_SECRET (min 32 chars, distinct from access)
```

**And** rejects at boot if `CORS_ORIGINS` contains `*` or any non-https
value. Missing → immediate `process.exit(1)`. No dangerous defaults.

### 4. Log redaction paths (28 pino paths + 4 regex patterns)

`rent95-api/src/config/log-redaction.ts` scrubs:
- `*.password`, `*.token`, `*.refreshToken`, `*.accessToken`, `*.apiKey`,
  `*.secret`, `*.client_secret`, `*.otp`, `*.cvv`, `*.cardNumber`, `*.iban`, …
- `req.headers.authorization`, `req.headers.cookie`, `req.headers.stripe-signature`
- `err.request.data`, `err.config.data`, `err.response.data`, `err.meta.target`
- Regex: `Bearer …`, `sk_(live|test)_…`, `pi_…_secret_…`, JWT-shaped tokens

### 5. Sentry `beforeSend` hook wired

`rent95-api/src/config/sentry.ts` installs a `beforeSend` that:
- Scrubs `event.request.data` / `.headers` / `.cookies`
- Blank-writes cookies (`event.request.cookies = '[REDACTED]'`)
- Walks `event.extra` + `event.contexts` recursively with a
  sensitive-key regex
- Runs `event.message` through the same regex list as pino

**No `err` object is ever sent raw to Sentry.**

### 6. Prisma pool config (default, but production-safe)

The Prisma client at `rent95-api/src/config/prisma.ts` uses a singleton
pattern with default pool size (max = `num_cpus * 2 + 1`). For our
single-machine `shared-cpu-1x` on Fly that's 3 connections — well under
the free-tier Postgres 20-connection cap. Documented in `fly.toml`.

---

## 🔴 What NEEDS live verification (you run these)

### Step 1 — Static config check FIRST (no network needed)

Run before every deploy. Fails on shape mismatches, wrong-mode keys,
weak secrets, quoting issues:

```bash
# Locally against your .env.production:
NODE_ENV=production $(cat .env.production | grep -v '^#' | xargs) \
  node scripts/verify-config.mjs

# On Fly against the actual live config:
fly ssh console -a rent95-api -C \
  'NODE_ENV=production node /app/scripts/verify-config.mjs'
```

Exits 1 on any critical misconfig; safe to gate deploys on this.

### Step 2 — Preflight against the live infrastructure

Copy `.audit-env.example` → `.audit-env`, fill in with production values
(read-only tokens where possible), then:

```bash
./scripts/preflight-audit.sh
```

The script runs 7 blocks in order:

| Block | Checks |
|---|---|
| 1. LB + HTTPS | TLS cert not expiring in < 21d, HSTS/CSP/X-Frame present, x-powered-by absent, `/health?deep=1` returns 200 with DB pool ok |
| 2. CORS gate | Every approved origin gets exact reflection; a decoy `evil.example.com` gets NO reflection and NEVER `*` |
| 3. Stripe | Webhook endpoint registered at exactly `$API_HOST/api/payments/webhook/stripe`, `status=enabled`, subscribes to `payment_intent.succeeded` + `.payment_failed` + `.amount_capturable_updated` |
| 4. FCM | Base64 decodes to valid JSON with `type: service_account` + `project_id` + `client_email` + `private_key` (with real newlines, not double-escaped) |
| 5. Cloudinary | `GET /v1_1/{cloud}/usage` returns 200 with the configured key + secret |
| 6. Fly Postgres | Snapshots enabled on volumes; PITR runbook printed |
| 7. Sentry canary | Fires a test event with a decoy `password` field to verify redaction end-to-end |

### Step 3 — Backup + PITR

Fly-managed Postgres has snapshots on by default (5-day retention). Bump
to 30 days and verify WAL archiving:

```bash
FLY_PG_APP=rent95-db ./scripts/db-backup-setup.sh
```

Also review the "Point-in-time recovery runbook" the script prints at
the end.

### Step 4 — Manual Dashboard checks

These have no clean automation — do them by hand from the checklist below.

#### Stripe Dashboard
1. https://dashboard.stripe.com/webhooks → confirm the entry for
   `https://api.rent95.app/api/payments/webhook/stripe`
2. Click "Send test webhook" → `payment_intent.succeeded`
3. Fly logs should show `payment_intent.succeeded` and the order flip to
   `paid` — `fly logs -a rent95-api | grep payment_intent`
4. If signature verification fails, the webhook secret is wrong. Regenerate
   from the dashboard's "Signing secret" reveal.

#### Firebase Console
1. https://console.firebase.google.com → your project → Cloud Messaging
2. Confirm APNs key uploaded (iOS pushes fail silently otherwise)
3. "Send test message" → paste a real device FCM token from
   `SELECT token FROM device_tokens LIMIT 1` on prod DB
4. Confirm the phone rings

#### Cloudinary Dashboard
1. https://cloudinary.com/console → Settings → Upload
2. Confirm `Unsigned` upload presets are **disabled** — we use signed uploads only
3. Confirm your cloud name matches `CLOUDINARY_CLOUD_NAME` in Fly secrets

#### Sentry
1. Load a page in the admin panel with the browser dev-tools Network tab open
2. Force an error (e.g. tweak a request query string to trigger a 500)
3. Confirm the Sentry event arrives
4. Click into the event → **the request body's `password` field should show
   `[REDACTED]`** — NOT the plaintext value

---

## 🟠 Known deferrals (v1.1)

- **Multi-region Postgres reads** — currently single-region `iad`. Latency
  from `syd` / `sin` will be 200+ms.
- **Cloudinary → S3 backup mirror** — media is one-copy-only right now.
  Cloudinary's own durability is 99.999999999%, but a $0.02/GB nightly S3
  sync is cheap insurance.
- **Blackbox HTTP monitoring** — set up an UptimeRobot / Better Stack
  monitor hitting `/health?deep=1` every 60s from ≥3 regions. Should
  fire a page ≤ 2 min after a soft outage.
- **Rate-limit metric export** — express-rate-limit stores counters in
  memory. Redis-backed store lets us alert on "429 rate exceeding X/min".

---

## What the audit script prints on a healthy launch

```
Rent95 preflight audit — 2025-…

▎ 1. HTTPS + Load-balancer registration
  OK  TLS certificate valid (89 days remaining)
  OK  HSTS header present (max-age=63072000; includeSubDomains; preload)
  OK  CSP header present
  OK  X-Frame-Options: DENY
  OK  x-powered-by header absent
  OK  Referrer-Policy: no-referrer
  OK  deep health check 200 + Postgres pool open

▎ 2. CORS gate
  OK  approved origin reflected exactly: https://admin.rent95.app
  OK  approved origin reflected exactly: https://rent95.app
  OK  unapproved origin refused (no ACAO header)
  OK  preflight allows POST + authorization for https://admin.rent95.app

▎ 3. Stripe webhook registration
  OK  webhook endpoint registered: we_… → https://api.rent95.app/…/webhook/stripe
  OK    subscribes to payment_intent.succeeded
  OK    subscribes to payment_intent.payment_failed
  OK    subscribes to payment_intent.amount_capturable_updated
  OK    status=enabled

▎ 4. Firebase Admin credentials
  OK  FCM service account decodes (rent95-prod, firebase-adminsdk@…)

▎ 5. Cloudinary credentials
  OK  Cloudinary API key + secret authenticate against cloud 'rent95-prod'

▎ 6. Fly Postgres backup posture
  OK  Fly PG cluster 'rent95-db' has 1 volume(s) (snapshots enabled by default)

▎ 7. Sentry canary event
  OK  Sentry accepted canary event — check UI for [REDACTED] on 'password' field

══════════════════════════════════
  Pass: 15   Warn: 0   Fail: 0
══════════════════════════════════
```

## What the audit script prints when things are broken

The output will show explicit failures with the exact ops response. A
`FAIL` line ends with what to run to fix it (e.g. `flyctl secrets set …`
or `stripe webhook_endpoints update …`).
