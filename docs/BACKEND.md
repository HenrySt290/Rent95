# Companion backend — `rent95-api`

The Node.js + Express + Prisma + Postgres backend for this app has been scaffolded at:

```
/home/user/rent95-api/
```

It's ready to push to its own GitHub repo. See [`docs/BACKEND_SETUP.md`](BACKEND_SETUP.md) for the exact commands to push it, spin it up locally, and connect the Flutter app to it.

## Quick summary of what's in it

- Full REST API matching this app's spec (auth, categories, products, orders, payments, reviews, chat, admin)
- Stripe Connect Express integration with escrow (`capture_method: 'manual'`)
- Socket.io realtime chat + notifications, with Redis adapter for horizontal scale
- Prisma schema covering every table in `docs/MVP_REVISED.md` §7
- Deterministic seed script that matches this app's `MockStore` data
- Docker Compose for local Postgres + Redis
- GitHub Actions CI + Dockerfile

**47 files**, TypeScript strict mode, production-ready.
