# Rent95 — production deployment runbook

Everything you need to take the three-repo stack live. Follow one of the
three paths below end-to-end; don't mix and match hosts unless you know why.

---

## 🚧 Before you start

Read this list first. Every item is a hard prerequisite:

- [ ] You own the domain (`rent95.app` in the examples below — substitute yours)
- [ ] A **Stripe account** exists, with Connect Express enabled
      (Stripe Dashboard → Settings → Connect → Get started)
- [ ] A **Cloudinary account** exists (free tier is fine for launch)
- [ ] A **Firebase project** exists with an Android + iOS app registered
- [ ] You have an **Apple Developer account** ($99/yr) and a **Google Play
      Console** account ($25 one-time), if you're shipping mobile
- [ ] You've completed KYC for Stripe payouts
- [ ] You've read `docs/MVP_REVISED.md` — legal risk items still apply

---

## 🎯 Pick your path

| Path | Best for | Monthly cost estimate |
|---|---|---|
| **A. Fly.io** *(recommended)* | Marketplaces that plan to grow; global regions; predictable pricing | ~$25–50 |
| **B. Render blueprint** | Solo devs; one-click infrastructure; least ops overhead | ~$25–40 |
| **C. Roll your own** | You already run infra (AWS/GCP/self-hosted k8s) | Varies |

Every path uses:
- Postgres 16 (Neon / Supabase / Render / Fly)
- Redis 7 (managed)
- Cloudinary for media
- Stripe for payments
- Firebase Cloud Messaging for push

---

## 🅰️ Path A — Fly.io (recommended)

### A.1 — Install & auth

```bash
brew install flyctl        # or curl -L https://fly.io/install.sh | sh
flyctl auth signup         # first time only
flyctl auth login
```

### A.2 — Provision managed Postgres

Fly's own Postgres is fine to start; migrate to Neon or Supabase once your
DB > 5 GB.

```bash
flyctl postgres create --name rent95-db --region iad --initial-cluster-size 1 --vm-size shared-cpu-1x --volume-size 10
# Save the DATABASE_URL it prints — you'll paste it as a secret below.
```

### A.3 — Provision Redis (Upstash is the Fly-blessed option)

```bash
flyctl redis create --name rent95-redis --region iad --plan Free
# Save REDIS_URL.
```

### A.4 — Deploy the API

```bash
cd rent95-api
flyctl launch --no-deploy --copy-config    # accept prompts; do NOT overwrite fly.toml
flyctl secrets set \
  DATABASE_URL='postgresql://…' \
  REDIS_URL='redis://…' \
  JWT_ACCESS_SECRET="$(openssl rand -hex 32)" \
  JWT_REFRESH_SECRET="$(openssl rand -hex 32)" \
  STRIPE_SECRET_KEY='sk_live_…' \
  STRIPE_WEBHOOK_SECRET='whsec_…' \
  STRIPE_CONNECT_CLIENT_ID='ca_…' \
  CLOUDINARY_CLOUD_NAME='rent95' \
  CLOUDINARY_API_KEY='…' \
  CLOUDINARY_API_SECRET='…' \
  FCM_SERVICE_ACCOUNT_JSON_BASE64="$(base64 < /path/to/fcm-service-account.json | tr -d '\n')" \
  SENTRY_DSN='https://…@sentry.io/…' \
  CORS_ORIGINS='https://admin.rent95.app,https://rent95.app' \
  PLATFORM_COMMISSION_PERCENT=10

flyctl deploy
```

Verify: `curl https://rent95-api.fly.dev/health?deep=1` → `{"status":"ok",...}`

### A.5 — Deploy the admin panel

```bash
cd ../rent95-admin
flyctl launch --no-deploy --copy-config
flyctl secrets set \
  API_URL='https://rent95-api.fly.dev' \
  ADMIN_SESSION_SECRET="$(openssl rand -hex 32)"

flyctl deploy
```

Verify: <https://rent95-admin.fly.dev/login>

### A.6 — Point your domains

```bash
# API
flyctl certs create api.rent95.app -a rent95-api
# Admin
flyctl certs create admin.rent95.app -a rent95-admin
```

Fly prints the DNS records to add. Add them at your registrar; certs
provision automatically in <5 min.

### A.7 — Wire Stripe webhooks

Stripe Dashboard → Developers → Webhooks → **Add endpoint**
- URL: `https://api.rent95.app/api/payments/webhook/stripe`
- Events: `payment_intent.succeeded`, `payment_intent.amount_capturable_updated`,
  `payment_intent.payment_failed`
- Copy the **signing secret** → `flyctl secrets set STRIPE_WEBHOOK_SECRET=whsec_…`
- Redeploy: `flyctl deploy`

### A.8 — Automated deploys

```bash
flyctl auth token
# → paste as FLY_API_TOKEN in each repo's Settings → Secrets → Actions
```

Every push to `main` on `rent95-api` and `rent95-admin` now:
1. Runs the full test suite
2. Builds a Docker image on Fly's remote builder
3. Runs `scripts/release.sh` (Prisma migrate deploy)
4. Rolling-deploys the new image
5. Smoke-tests `/health?deep=1`

---

## 🅱️ Path B — Render blueprint (simplest)

```bash
cd rent95-api
git push origin main
```

1. <https://dashboard.render.com/blueprints> → **New Blueprint**
2. Connect the `rent95-api` repo — Render reads `render.yaml` and provisions
   Postgres + Redis + API in one click.
3. Set the six `sync: false` secrets in the dashboard (`JWT_*`, `STRIPE_*`,
   `CLOUDINARY_*`, `FCM_*`).
4. Repeat for `rent95-admin` (uses its own Dockerfile; no blueprint needed
   — just create a Web Service).

Custom domains + auto-deploy-on-push are one toggle each in the dashboard.

---

## 🅲 Path C — Roll your own

You've got this. The pieces:

- **API image**: `docker build -t rent95-api rent95-api/` → push to your registry
- **Admin image**: `docker build -t rent95-admin rent95-admin/`
- **Postgres 16**: any managed offering (RDS, Cloud SQL, Neon, Supabase)
- **Redis 7**: any managed offering (ElastiCache, Memorystore, Upstash)
- **Migrations**: run `scripts/release.sh` as a pre-deploy job (Kubernetes
  Job, ECS taskDefinition, whatever your platform calls it)
- **Load balancer**: sticky sessions ON for `/socket.io/*`, OFF for `/api/*`
- **Health check**: `GET /health?deep=1`, expect 200

`docker-compose.yml` in `rent95-api/` documents the DB + Redis shape if
you want to run everything on one box during launch week.

---

## 📱 Mobile deploys

### First-time Android setup

1. Generate a signing keystore:
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
     -validity 10000 -alias upload
   ```
2. Base64-encode it: `base64 < upload-keystore.jks | tr -d '\n' | pbcopy`
3. Paste as GitHub secret `ANDROID_KEYSTORE_BASE64`
4. Add `android/key.properties`:
   ```properties
   storePassword=…
   keyPassword=…
   keyAlias=upload
   storeFile=upload-keystore.jks
   ```
5. Google Play Console → API access → link a service account → download
   the JSON key → paste as GitHub secret `PLAY_STORE_JSON_KEY`

### First-time iOS setup

1. Apple Developer → Certificates → generate App Store Distribution cert
2. Set up **Fastlane match**:
   ```bash
   cd Rent95
   bundle exec fastlane match init
   bundle exec fastlane match appstore
   ```
   Match stores the cert + provisioning profile in a private git repo so
   CI can pull them without dealing with keychain export.
3. App Store Connect → generate an API key (JSON) → paste as
   `APP_STORE_CONNECT_API_KEY_JSON`

### Shipping a build

```bash
# Locally
bundle exec fastlane android beta      # → Play Store internal
bundle exec fastlane ios beta          # → TestFlight

# Or in CI (Actions → Mobile release → Run workflow)
```

Fastlane runs `flutter test` first — if a test fails, the build never uploads.

---

## 🔐 Environment variables — the full list

Kept in one place so you can grep. **Bold** ones are secrets that must
NOT be committed. Everything else can go in `.env.example`.

### `rent95-api`

| Var | Where | Notes |
|---|---|---|
| `NODE_ENV` | Public | Always `production` in prod |
| `PORT` | Public | Container port; Fly maps 443 → this |
| `DATABASE_URL` | **Secret** | Postgres 16 |
| `REDIS_URL` | **Secret** | Redis 7 |
| `JWT_ACCESS_SECRET` | **Secret** | `openssl rand -hex 32` |
| `JWT_REFRESH_SECRET` | **Secret** | Distinct from access secret |
| `STRIPE_SECRET_KEY` | **Secret** | `sk_live_…` |
| `STRIPE_WEBHOOK_SECRET` | **Secret** | `whsec_…` from dashboard |
| `STRIPE_CONNECT_CLIENT_ID` | **Secret** | `ca_…` |
| `CLOUDINARY_CLOUD_NAME` | Public-ish | Displayed in URLs |
| `CLOUDINARY_API_KEY` | Public-ish | Not a secret; signature is |
| `CLOUDINARY_API_SECRET` | **Secret** | Never send to client |
| `FCM_SERVICE_ACCOUNT_JSON_BASE64` | **Secret** | Firebase Admin credentials |
| `SENTRY_DSN` | **Secret-ish** | Contains project token |
| `CORS_ORIGINS` | Public | Comma-separated admin + mobile web origins |
| `PLATFORM_COMMISSION_PERCENT` | Public | Default 10 |

### `rent95-admin`

| Var | Notes |
|---|---|
| `API_URL` | `https://api.rent95.app` |
| `ADMIN_SESSION_SECRET` | Signs the HttpOnly session cookie; `openssl rand -hex 32` |
| `NODE_ENV` | `production` |

### Flutter (via `--dart-define`)

| Var | Notes |
|---|---|
| `API_BASE_URL` | `https://api.rent95.app` |
| `SOCKET_URL` | Same host, ws://… scheme managed by socket.io |
| `STRIPE_PUBLISHABLE_KEY` | `pk_live_…` |
| `GOOGLE_MAPS_API_KEY` | From Google Cloud Console |
| `USE_MOCKS` | `false` |
| `ENVIRONMENT` | `production` |

---

## 📊 Monitoring — the minimum viable setup

- **Sentry** (free tier is enough for launch): set `SENTRY_DSN` on the API +
  admin, and add `@sentry/node` to `rent95-api/package.json`. See
  `src/config/sentry.ts`.
- **Uptime**: `https://api.rent95.app/health?deep=1` on 60-second polling.
  UptimeRobot free tier does this.
- **Fly metrics**: `flyctl metrics -a rent95-api` for CPU / memory /
  request rate. Enough for the first 6 months.
- **Log tail during launch week**: `flyctl logs -a rent95-api -a rent95-admin`

---

## 🪃 Rollback

Fly keeps the last 10 releases. To roll back:

```bash
flyctl releases list -a rent95-api
flyctl releases rollback <version> -a rent95-api
```

If the rollback is because of a bad migration, first roll back the
migration file on `main`, then redeploy — you can't reliably reverse an
already-applied Prisma migration.

---

## 💰 Realistic monthly cost at launch

| Service | Path A (Fly) | Path B (Render) |
|---|---|---|
| API compute | $5 (1× shared-cpu-1x/512M) | $7 (starter) |
| Admin compute | ~$1 (auto-sleep) | $7 |
| Postgres | $2 (1× shared-cpu-1x/1GB) | $7 |
| Redis | Free (Upstash) | $10 |
| Cloudinary | Free tier (25 GB storage, 25 GB bandwidth) | same |
| Firebase FCM | Free | same |
| Domain | $12/yr | same |
| Sentry | Free tier | same |
| **Total** | **~$8/mo** | **~$31/mo** |

Both paths scale gracefully with traffic. Budget an extra ~$50/mo per
100 concurrent users beyond the free thresholds.

---

## ✅ Ship-day checklist

See `docs/PRODUCTION_CHECKLIST.md` — 30 items to tick off in order.
