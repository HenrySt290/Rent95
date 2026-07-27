# Backend integration tests

The `rent95-api` scaffold now ships with a full integration test suite —
7 files, ~50 assertions, running against a real Postgres via Vitest +
Supertest. See `rent95-api/README.md` § **Testing** for the full walkthrough.

## Where to find the tests

Inside the `rent95-api.tar.gz` bundled with this repo:

```
rent95-api/
├── tests/
│   ├── unit/
│   │   └── utils.test.ts             ← fast, no DB
│   ├── integration/
│   │   ├── auth.test.ts              ← register/login/refresh rotation, hashing
│   │   ├── products.test.ts          ← search filters, pagination, viewCount++, RBAC
│   │   ├── orders.test.ts            ← escrow math, overlap prevention, transitions
│   │   ├── reviews.test.ts           ← post-completion, one-per-order, rating avg
│   │   ├── messaging.test.ts         ← conversations + messages, RBAC
│   │   ├── admin.test.ts             ← dashboard, moderate, suspend + reactivate
│   │   └── categories.test.ts        ← list/tree/health/404 handler
│   └── support/
│       ├── global-setup.ts           ← runs `prisma migrate deploy` once
│       ├── reset-db.ts               ← TRUNCATE … RESTART IDENTITY CASCADE before each test
│       ├── factories.ts              ← createUser / createCategory / createProduct
│       └── http.ts                   ← testApp() + tokenFor() + authed() helpers
├── .env.test                          ← test-only config (committed, no secrets)
├── docker-compose.test.yml            ← isolated Postgres on port 5433, tmpfs data
└── .github/workflows/ci.yml           ← Postgres service + typecheck + lint + tests
```

## How to run

```bash
cd rent95-api
docker compose -f docker-compose.test.yml up -d
DATABASE_URL='postgresql://rent95:rent95@localhost:5433/rent95_test?schema=public' \
  npx prisma db push --skip-generate
npm run test:integration
```

Or just push to GitHub — the CI workflow does all of the above automatically.

## What made this non-trivial

Three things needed sorting out:

1. **Rate limits.** Production defaults (20 auth calls per 15 min) would
   have blown up around the 4th test file. Neutered them in test mode via
   `isTest` — the middleware still runs, but the ceiling is 100 000.

2. **Shared Postgres across tests.** Vitest defaults to parallel workers,
   which would race on truncating tables. Config forces
   `pool: 'forks', singleFork: true` for integration; unit tests stay parallel.

3. **View-count assertion.** `GET /api/products/:id` fires an `await` update
   on view count, so by the time supertest resolves, the DB is consistent.
   No sleep-and-hope logic needed.

## Coverage summary

| Endpoint | Cases covered |
|---|---|
| `POST /api/auth/register` | happy path (hashed pw, no leak), 409 dup, 422 validation |
| `POST /api/auth/login` | happy path, wrong pw, unknown email — same 401 shape |
| `POST /api/auth/refresh-token` | rotation + revocation + replay rejection |
| `GET /api/auth/me` | valid, no bearer, garbage bearer |
| `GET /api/products` | active+approved filter, category filter, price range, sort, pagination |
| `GET /api/products/:id` | happy path, viewCount++, 404 |
| `POST /api/products` | seller create, buyer 403, 422 |
| `POST /api/products/:id/favorite` | toggle on/off, counter update, 401 |
| `POST /api/orders` | server-side price math, self-book rejected, overlap detection, valid non-overlap, end-before-start, quantity>inventory |
| `PATCH /api/orders/:id/status` | seller accept, buyer forbidden, stranger 403, illegal transition |
| `GET /api/buyer/orders` `GET /api/seller/orders` | scoped to caller |
| `POST /api/reviews` | happy path + rating recompute, avg over multiple, not-completed 400, non-buyer 403, dup 400 |
| `GET /api/products/:id/reviews` | public |
| `POST /api/conversations` | create + reuse-on-repeat, self-message 400 |
| `GET /api/conversations` | scoped |
| `POST /api/conversations/:id/messages` | happy path + lastMessage update, outsider 403, content-or-media validation |
| `GET /api/admin/dashboard` | metrics, role gating |
| `PATCH /api/admin/products/:id/moderate` | approve, reject with reason |
| `PATCH /api/admin/users/:id/status` | suspend + reactivate |
| `GET /api/categories` `/tree` | active filter + sort, parent→children shape |
| `/health` | smoke |
| Unknown routes | JSON 404 with `code: 'route_not_found'` |

**~50 assertions total, ~5–8s to run the full suite locally**.
