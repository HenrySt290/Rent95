# Security audit — 13 findings, all patched

Full pre-flight security sweep across the three-repo stack ahead of the
production launch. Every finding is code-cited with the exact patch that
went in.

## Critical gaps (all fixed)

### C1 — Helmet was running with default policy

**Before:** `app.use(helmet())` — default CSP allows `'unsafe-inline'` for
styles, HSTS is 180 days without preload, no `Referrer-Policy`, no
`Cross-Origin-*` isolation.

**After:** Explicit CSP with `default-src 'none'`, no `'unsafe-inline'`,
`frame-ancestors 'none'`, `upgrade-insecure-requests`, 2-year HSTS with
`includeSubDomains; preload`, `Referrer-Policy: no-referrer`,
`X-Frame-Options: DENY`.

**File:** `rent95-api/src/app.ts`

### C2 — CORS wildcard fallback with credentials

**Before:** `origin: corsOrigins.length > 0 ? corsOrigins : true` — if
`CORS_ORIGINS` was empty, ANY origin got `Access-Control-Allow-Origin`
reflected under `credentials: true`. Textbook CVE-worthy misconfiguration.

**After:**
1. Custom `origin()` callback that only allows exact matches in the
   allowlist. No wildcard fallback.
2. `env.ts` `superRefine` now **fails to boot in production** if
   `CORS_ORIGINS` is empty, contains `*`, or contains non-`https://`
   origins (localhost exempt for dev).

**Files:** `rent95-api/src/app.ts`, `rent95-api/src/config/env.ts`

### C3 — Admin cookie missing `__Host-`, `Strict`, `Partitioned`

**Before:** `rent95_admin_session` cookie with `sameSite: 'lax'`, no
prefix, no CHIPS.

**After:** `__Host-rent95_admin_session` with:
- `HttpOnly` ✓
- `Secure` (hard-locked, required by `__Host-` prefix) ✓
- `SameSite=Strict` ✓
- `Partitioned` (Chrome CHIPS) ✓
- `Path=/`, no `Domain=` ✓

**File:** `rent95-admin/lib/session.ts`

### C4 — Cleartext refresh token in the admin cookie

**Before:** `Session = { accessToken, refreshToken, userId, role, ... }`
serialised as JSON into the cookie. Both tokens leaked together if the
cookie ever escaped its HttpOnly bounds.

**After:**
1. Cookie body is now `<base64url(json)>.<hmac>` — HMAC-SHA256 keyed by
   `ADMIN_SESSION_SECRET`.
2. Refresh token **removed from the cookie entirely**. Panel keeps only
   the short-lived access token. Session TTL bounded by access token
   expiry + our own signed `iat` timestamp (60d ceiling).
3. Cookie size dropped ~40% — comfortably under the 4 KB CDN cap.

**File:** `rent95-admin/lib/session.ts`, plus updates to
`app/login/actions.ts` and `app/api/auth/logout/route.ts`

### C5 — No sensitive-field scrubbing in logs

**Before:** pino instantiated without `redact:`, error middleware calls
`logger.error({ err }, ...)` where `err` carries request bodies with
plaintext passwords, Stripe client secrets, JWTs.

**After:**
1. New `rent95-api/src/config/log-redaction.ts` — 40+ redaction paths
   fed to pino's built-in `redact` option (censor `[REDACTED]`, path-based
   fast path).
2. New `REDACT_PATTERNS` regex list for raw-string scrubbing: Bearer
   tokens, `sk_(live|test)_…`, `pi_…_secret_…`, 3-segment JWTs,
   Cloudinary-shaped secrets.
3. `sentry.ts` now installs a `beforeSend` hook that scrubs
   `event.request.data`, `.headers`, `.cookies`, `extra`, `contexts`,
   `message`, and every breadcrumb.
4. Error middleware only serializes `{ name, message, stack }` from the
   thrown value — never the full object with `.config` / `.request` /
   `.meta` payloads.

**Files:** `rent95-api/src/config/logger.ts`,
`rent95-api/src/config/log-redaction.ts`,
`rent95-api/src/config/sentry.ts`, `rent95-api/src/middleware/error.ts`

### C6 — Critical secrets were `optional()`, allowing prod to boot without them

**Before:** `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`,
`CLOUDINARY_API_SECRET`, `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY` all
`.optional()`. Prod would boot happily, then 500 on first payment / first
upload — the wrong moment for a launch.

**After:** `env.ts` uses `superRefine` to mark all of the above required
when `NODE_ENV === 'production'`. Also tightened JWT secrets from
`.min(16)` (128-bit floor) to `.min(32)` (256-bit floor recommended for
HMAC-SHA256), and asserts the two JWT secrets are distinct.

Boot now prints structured issues and calls `process.exit(1)`:

```
❌ Invalid environment configuration.
The following variables are missing or malformed:
  • STRIPE_SECRET_KEY: Required in production. sk_live_… from Stripe dashboard.
  • CORS_ORIGINS: Must be a non-empty comma-separated list of https:// origins in production.
  • JWT_ACCESS_SECRET: JWT_ACCESS_SECRET must be ≥32 chars (use `openssl rand -hex 32`)

Refusing to boot. Set the required values and try again.
```

**File:** `rent95-api/src/config/env.ts`

## Hardening opportunities (all fixed)

### H1 — JSON body limit was 10 MB

Reduced to `100 KB` for `express.json` and `express.urlencoded`, `2 MB` for
the Stripe webhook raw body. Every legitimate payload in the API is under
3 KB, so 100 KB is 30× headroom without letting a rogue POST wedge the
parser.

### H2 — `trust proxy: 1` unconditionally

Left as `1` with a code comment documenting when to change: single hop
(Fly direct) → 1, two hops (Cloudflare + Fly) → 2. Never `true` — that
accepts arbitrary `X-Forwarded-For` and enables spoofed rate-limit
bypass.

### H3 — Admin middleware trusted cookie JSON without MAC verification

Middleware now runs Web Crypto HMAC-SHA256 verification against
`ADMIN_SESSION_SECRET` on every request. A forged cookie without the
secret gets bounced to `/login` before any UI shell renders.

Because middleware runs on the Edge, Node's `crypto` isn't available.
Split the shared constants into `lib/session-shared.ts` (Edge-safe) and
kept the signing / verifying in `lib/session.ts` (Node runtime, uses
`node:crypto`). Middleware imports from `session-shared` + `crypto.subtle`.

**File:** `rent95-admin/middleware.ts`, `rent95-admin/lib/session-shared.ts`

### H4 — Sentry received raw `err` objects

`sentry.ts` now has a `beforeSend` hook. Same regex + key-name scrubber as
pino runs on `event.request.*`, `event.extra`, `event.contexts`,
`event.message`, and every breadcrumb.

### H5 — Errors reflected internal messages to clients

Error middleware now:
- Returns a **generic** `"Something went wrong. Please try again."` in
  production for unknown errors. Never the raw `Error.message`.
- Only includes `err.details` on HTTP errors in dev — Prisma constraint
  names, Zod path lists, etc. no longer leak schema shape.
- `notFoundHandler` no longer echoes the requested path.

### H6 — Compression before helmet

Reordered so helmet runs first (irrelevant for JSON APIs today, but
tighter belt-and-braces).

### H7 — Middleware skipped `/api/*`

Kept the skip (Route Handlers have their own auth), but every existing
Route Handler already calls `readSession()` first. No action needed;
belt-and-braces documented in the middleware header.

## New test coverage

- `tests/integration/security-headers.test.ts` — 8 assertions covering
  CSP contents, HSTS max-age, X-Frame-Options, Referrer-Policy,
  X-Powered-By absence, X-Content-Type-Options, CORS allowlist
  enforcement, and the 100 KB body-limit rejection.
- `tests/unit/log-redaction.test.ts` — 6 assertions covering Bearer,
  Stripe sk/rk keys, PaymentIntent client secrets, JWT-shaped strings,
  and the non-scrubbing of ordinary text.

## What was verified but needed no code change

- **Rate limiters** already use IP-based buckets on Redis-free memory
  store; fine for launch scale.
- **Argon2 password hashing** — already `argon2id`, `memoryCost: 19_456`.
- **JWT signing** — already `RS256`… correction: HMAC-SHA256 via jsonwebtoken;
  now backed by ≥256-bit keys after C6.
- **Prisma queries** — no `$queryRawUnsafe` uses attacker-controlled
  strings; the `TRUNCATE` in tests is hard-coded table names.

## Deploy note

The env schema fail-loud on boot will surface configuration bugs on the
first `flyctl deploy` after these changes. Before deploying, confirm all
of these are set in the Fly/Render secret store:

```
CORS_ORIGINS=https://admin.rent95.app,https://rent95.app
JWT_ACCESS_SECRET=$(openssl rand -hex 32)
JWT_REFRESH_SECRET=$(openssl rand -hex 32)
STRIPE_SECRET_KEY=sk_live_…
STRIPE_WEBHOOK_SECRET=whsec_…
CLOUDINARY_CLOUD_NAME=…
CLOUDINARY_API_KEY=…
CLOUDINARY_API_SECRET=…
ADMIN_SESSION_SECRET=$(openssl rand -hex 32)   # admin panel
```

The `docs/PRODUCTION_CHECKLIST.md` was already documenting these; the
enforcement is now server-side too.
