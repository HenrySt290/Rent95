# Security test suites — CORS gate + payload boundary + AES-GCM tamper

Two dedicated test files were added to lock the security patches from
`docs/SECURITY_AUDIT.md` behind CI. Both tarballs updated.

## What changed

The security audit shipped an HMAC-signed admin session cookie. This
follow-up upgraded it to **full AES-256-GCM authenticated encryption**
because the audit test spec explicitly wanted `aes-256-gcm` decipher
semantics — GCM's auth tag is a stronger integrity primitive than a
separate HMAC segment (single decrypt call catches tampering, no
constant-time compare bugs possible in userland).

### `rent95-admin/lib/session.ts`
Rewrote the codec:
```
wire format:  <b64url(iv)>.<b64url(ciphertext)>.<b64url(authTag)>
key:          SHA-256(ADMIN_SESSION_SECRET)      — deterministic 32 bytes
iv:           randomBytes(12)                    — fresh per write
authTag:      16 bytes (GCM default)
```
Exports `_encryptSession` and `_decryptSession` for direct test access
(prefixed with underscore to signal "not for consumers").

### `rent95-admin/middleware.ts`
Uses Web Crypto AES-GCM (Edge-safe). Concatenates ciphertext+tag before
`crypto.subtle.decrypt`, since WebCrypto expects them combined (unlike
Node's split).

## Tests added

### `rent95-api/tests/integration/security.test.ts` — 8 assertions

**CORS gate — audit C2:**
- Unapproved origin (`evil.example.com`) → no ACAO reflection, status 200 or 500.
- No-Origin request (server-to-server, mobile native) → 200, no ACAO header.
- Preflight OPTIONS from unapproved origin → no ACAO reflection.
- Approved origin (via `beforeAll` env rewrite + `vi.resetModules()`) → 200
  with exact-match ACAO, `Access-Control-Allow-Credentials: true`, and
  `Vary: Origin` for cache-safety.
- Preflight from approved origin → 204 with expected methods (POST/GET)
  and headers (authorization/content-type) allowlisted.

**Payload boundary — audit H1:**
- 110 KB JSON body to `/api/auth/login` → 413 Payload Too Large.
- Normal body (< 100 KB) → passes parser, reaches auth service, 401s.
- 110 KB urlencoded body → 413 (both parsers capped).

### `rent95-admin/tests/session.test.ts` — 11 assertions

**Happy path (3):**
- Encrypt → decrypt round-trip preserves every field.
- Wire format is exactly `<b64url>.<b64url>.<b64url>`, all base64url alphabet.
- Fresh IV per encryption: same payload encrypted twice yields distinct
  ciphertexts. Proves `randomBytes(12)` isn't hard-coded.

**Tamper resistance (6):**
- Flipped low bit in the auth-tag segment → `null` (GCM tag mismatch).
- Flipped low bit in ciphertext → `null`.
- Flipped low bit in IV → `null` (plaintext decrypts differently, tag fails).
- Truncated cookie (2 segments) → `null`.
- Garbage strings (`''`, `'....'`, `'AAA.BBB.CCC'`) → `null`.
- Cookie encrypted under a different `ADMIN_SESSION_SECRET` → `null`
  (uses `vi.resetModules()` to re-import with a fresh key).

**Staleness (2):**
- Fresh iat (1 s old) → decrypts.
- Iat older than 60 days → `null` even if MAC is valid (defence-in-depth
  vs. browser Max-Age bypass by cookie replay).

## Vitest infrastructure for rent95-admin

Previously the admin panel had no Vitest config. Added:
- `vitest.config.ts` — node env, aliases `@/` → project root, setup file
- `tests/setup.ts` — sets `ADMIN_SESSION_SECRET` **before** any `lib/`
  import so `session.ts`'s boot guard is satisfied. Also `vi.mock`s
  `server-only` into a no-op so `lib/session.ts` imports cleanly under
  the node runtime.
- `package.json` scripts: `test`, `test:watch`.
- `.github/workflows/ci.yml` now runs `npm test` before `npm run build`.

## What was NOT changed and why

- **HMAC keying stayed available in test-mode only? No.** The whole
  cookie codec is GCM. There's no fallback HMAC path — a mixed codec
  would be a versioning nightmare in production. If we ever rotate
  ciphers, we add a version byte.
- **`server-only` mock in tests** — Next.js's `server-only` package
  throws when imported in client bundles. Vitest running node-side
  doesn't trigger that, but the module still needs to resolve. The
  `vi.mock('server-only', () => ({}))` in `tests/setup.ts` handles it.
- **Approved-origin test uses `vi.resetModules`** — the cleanest way to
  force `config/env.ts` to re-parse `CORS_ORIGINS` mid-test without
  restarting the whole Vitest worker. Contained to that describe block
  via `beforeAll`/`afterAll`.

## Running the tests

```bash
# API
cd rent95-api
docker compose -f docker-compose.test.yml up -d
npm run test:integration
# → security.test.ts + security-headers.test.ts

# Admin
cd rent95-admin
npm test
# → session.test.ts (11 assertions, ~2s local)
```
