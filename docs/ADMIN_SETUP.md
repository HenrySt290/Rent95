# Admin panel — `rent95-admin`

Next.js 15 admin panel for Rent95. Third and final piece of the three-repo layout.

## Where the code lives

Inside the Arena sandbox this session created it at `/home/user/rent95-admin/`
and packaged the whole thing as [`rent95-admin.tar.gz`](../rent95-admin.tar.gz)
so it persists past sandbox snapshots.

## Grab + push to GitHub

Same pattern as the backend:

```bash
# 1. Extract the tarball from this repo
cd /somewhere/on/your/machine
tar xzf /path/to/Rent95/rent95-admin.tar.gz
cd rent95-admin

# 2. Push to a fresh GitHub repo
git init
git add .
git commit -m "Initial commit: Rent95 admin scaffold"
git branch -M main
git remote add origin git@github.com:YOUR_USERNAME/rent95-admin.git
git push -u origin main
```

Or with the `gh` CLI:

```bash
gh repo create rent95-admin --private --source=. --remote=origin --push
```

## Run locally

```bash
cd rent95-admin
npm install
cp .env.example .env
# → edit API_URL to point at your running rent95-api

npm run dev
# → http://localhost:3000
```

The panel bounces you to `/login`. Sign in with an account whose `role` is
`admin`, `moderator`, or `support`. The rent95-api seed script creates
`admin@rent95.dev` / `demo1234` for exactly this.

## What's shipped

- Next.js 15 App Router + TypeScript strict + Tailwind
- Server-action login → HttpOnly session cookie, no client-side JWT
- Middleware guard on every `/dashboard/*` route with role check
- Role-based capability matrix (admin / moderator / support see different actions)
- 7 pages: dashboard, users, listings moderation, orders, payments, disputes, categories
- Recharts revenue chart on the overview
- Listings approve/reject flow with reason picker
- Users suspend/activate/ban actions (admin only)
- No component library — just Tailwind + a tiny UI primitives folder
- Dockerfile + GitHub Actions CI

See the panel's own [`README.md`](../rent95-admin.tar.gz) inside the tarball
for the full walkthrough including how to add new pages and capabilities.

## Endpoints it expects from `rent95-api`

Everything the panel calls is already in the initial `rent95-api` scaffold
(see `docs/BACKEND_SETUP.md`):

- `POST /api/auth/login`
- `POST /api/auth/logout`
- `GET  /api/categories`
- `GET  /api/admin/dashboard`
- `GET  /api/admin/users?page=&pageSize=`
- `PATCH /api/admin/users/:id/status`  `{ action }`
- `GET  /api/admin/products?page=&pageSize=&moderationStatus=`
- `PATCH /api/admin/products/:id/moderate`  `{ decision, reason? }`

Two endpoints referenced by the pages but not yet implemented in the initial
backend scaffold (they'll return graceful error banners until you add them):

- `GET /api/admin/orders`
- `GET /api/admin/payments`
- `GET /api/admin/disputes`

These are small — add them alongside the existing admin controller in
`rent95-api/src/controllers/admin.controller.ts`. Wiring pattern is identical
to the ones already there.
