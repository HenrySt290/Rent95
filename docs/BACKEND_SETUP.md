# Backend setup — `rent95-api`

The Node.js/Express/Prisma/Postgres backend for Rent95 has been scaffolded in this workspace at `/home/user/rent95-api/`. Because it's a **separate service**, it belongs in its own Git repository.

This doc walks you through:
1. Pushing it to a fresh GitHub repo
2. Running it locally against Postgres + Redis
3. Pointing the Flutter app at it

---

## 1. Push `rent95-api` to GitHub

From your local machine (after pulling this Flutter repo down, or by copying the `rent95-api/` folder from the sandbox):

```bash
# On GitHub, create a new empty repo named "rent95-api" (no README, no gitignore).

cd /path/to/rent95-api
git init
git add .
git commit -m "Initial commit: Rent95 API scaffold"
git branch -M main
git remote add origin git@github.com:YOUR_USERNAME/rent95-api.git
git push -u origin main
```

If you're using the GitHub CLI:

```bash
cd /path/to/rent95-api
git init && git add . && git commit -m "Initial commit: Rent95 API scaffold"
gh repo create rent95-api --private --source=. --remote=origin --push
```

---

## 2. Run it locally

### Prerequisites
- Node.js **≥ 20**
- Docker (for Postgres + Redis)

### Commands

```bash
cd rent95-api

# Install packages
npm install

# Copy env template — defaults work with the docker-compose file
cp .env.example .env

# Start Postgres + Redis in the background
docker compose up -d

# Create the DB schema (Prisma will prompt for a migration name — "init" is fine)
npm run prisma:migrate

# Seed sample data (categories + 3 sellers + 6 listings, admin@rent95.dev / demo1234)
npm run db:seed

# Start the API with hot reload
npm run dev
```

You should see:
```
🚀 Rent95 API listening on http://localhost:4000
```

Smoke test:
```bash
curl http://localhost:4000/health
curl http://localhost:4000/api/products
curl -X POST http://localhost:4000/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"alex@example.com","password":"demo1234"}'
```

---

## 3. Point the Flutter app at your API

Once the API is running, run the mobile app with `USE_MOCKS=false`:

```bash
# In the Rent95 (Flutter) directory
flutter run \
  --dart-define=USE_MOCKS=false \
  --dart-define=API_BASE_URL=http://localhost:4000 \
  --dart-define=SOCKET_URL=http://localhost:4000
```

Notes on hostnames:
| Runtime | Use this instead of `localhost` |
|---|---|
| Android emulator | `http://10.0.2.2:4000` |
| iOS simulator | `http://localhost:4000` ✅ works |
| Physical device on Wi-Fi | Your machine's LAN IP, e.g. `http://192.168.1.42:4000` |

---

## 4. What still needs to happen in the Flutter app

Right now every screen reads from `MockStore`. Turning `USE_MOCKS=false` won't automatically hit the API — we also need real repositories. That's the next work chunk:

1. Add `lib/features/<feature>/data/*_repository.dart` files that call Dio using the routes above.
2. Update each feature's `*_providers.dart` to branch on `Env.useMocks`.
3. Delete the mock reads once the real ones are stable.

I can do this next — just say the word.

---

## 5. What lives where (recap)

| Repo | Purpose |
|---|---|
| **`Rent95`** (this repo) | Flutter mobile app |
| **`rent95-api`** (new) | Node/Express/Prisma backend |
| **`rent95-admin`** (future) | Next.js admin panel |

---

## Sandbox note

If you're viewing this inside the Arena sandbox: the `rent95-api/` folder is at `/home/user/rent95-api/` in this session. Everything is coded, but `npm install` and `docker compose up` need normal outbound internet, so run those commands on your own machine after pushing to GitHub.
