# Rent95 — Revised MVP & Feature Plan

> This document reviews the original **"Multi-Category Rental and Sales Marketplace"** specification and revises it into a **shippable MVP**. The full spec is excellent as a north-star, but it is easily 4–8 months of work for a small team. What follows is what actually goes in **v1** so we can ship, learn, and iterate.

---

## 1. Review of the Original Spec — Strengths & Risks

### ✅ What's strong
- **Clear multi-role model** (Guest / Buyer / Seller / Admin / Moderator / Support).
- **Categorized listing model** with `listingType = rent | sale | service | hybrid` is the right abstraction — a single `products` table serves the whole marketplace.
- **Escrow + dispute workflow** is well thought out (§10.3, §12) and matches how Airbnb / Turo / OLX actually operate.
- **Data model (§7)** is sound and normalized. Indexes list in §14.4 is complete.
- **API surface (§8)** is REST-clean and role-scoped.
- **Milestones (§20)** are already logically ordered — we mostly need to *cut*, not resequence.

### ⚠️ Risks / gaps to close before building
| # | Risk | Mitigation |
|---|------|------------|
| R1 | **Scope is huge.** Rent + Sale + Services + hybrid, in one v1, across 10 categories, with escrow + disputes + KYC + chat + push + maps + admin panel is 4–8 person-months. | Cut hard for MVP (see §3 below). Ship rental+sale first, add services in v2. |
| R2 | **Escrow on Stripe requires Stripe Connect** (Express or Custom accounts) + `application_fee` + `transfer_group`. Not "regular" Payment Intents. | Use **Stripe Connect Express** from day one. Razorpay Route for India. |
| R3 | **Razorpay + Stripe together** doubles surface area (2 SDKs, 2 webhooks, 2 payout systems, dual currency logic). | For MVP pick **one region/currency**. Add the second provider in v1.1. |
| R4 | **KYC** is treated as a checkbox, but real KYC needs Persona / Stripe Identity / Sumsub — building it in-house is a multi-week detour. | Use **Stripe Identity** (piggybacks on Connect) or defer KYC to "before first payout" instead of "before first listing". |
| R5 | **Real-time chat over Socket.io** requires sticky sessions + Redis adapter or you'll lose messages when you scale out. | Bake Redis adapter in from day one, even on a single node. |
| R6 | **Multi-category dynamic fields** (`category_fields` + `custom_attributes` JSONB) is powerful but easy to over-engineer. | v1: hardcode ~4 attribute sets (real estate / vehicles / equipment / other). Dynamic admin UI in v2. |
| R7 | **Booking calendar conflict prevention** with quantity > 1 needs pessimistic locking or a scheduling library. Naïve `SELECT ... WHERE date BETWEEN ...` will race. | Use Postgres `SERIALIZABLE` on the booking write path, or a Redis lock per `(product_id, date_range)`. |
| R8 | **Search "PostgreSQL / Elasticsearch / Meilisearch / Algolia"** — leaving it open guarantees rework. | **Decide now: Meilisearch** (self-hosted, cheap, "just works" for MVP). Migrate to Algolia only if traffic demands. |
| R9 | **Admin web panel is a whole second app.** It doubles CI, auth surface, deploy targets. | For MVP: build admin as **role-gated routes inside a Next.js app**, not a separate codebase. |
| R10 | **App store review risk:** marketplaces with user-generated content need report/block/mute + a moderation queue with SLA, or Apple rejects under §1.2. | Ship report + block + admin queue *in the MVP*, not "should-have". Already listed as must-have — keep it there. |
| R11 | **iOS payments:** Apple requires physical/service transactions to use *external* payment (Stripe is fine), **but digital goods must use IAP**. Make sure no digital-only listings sneak in. | Add category rule: `is_digital = false` enforced in admin moderation. |
| R12 | **No offline / poor-network story.** Emerging-market rental apps live and die on this. | Riverpod + `hive` cache for listings feed + optimistic UI in create-listing. Already planned in §5.10, keep it non-negotiable. |

---

## 2. Product Positioning Recommendation

The original name of the app doesn't disambiguate the primary use case. My recommendation:

> **Rent95 — Rent, buy, and book anything. From one app.**
> *Position rental as the primary hook (few competitors do this well) with sale + services as adjacencies.*

**Launch category focus for MVP: Vehicles + Equipment + Electronics + Real-Estate rooms.**
Skip Fashion, Sports, Furniture, Events, Services in v1 — the schema supports them; we just don't feature them, seed them, or admin them yet.

---

## 3. Revised MVP Scope (v1.0 — "Ship in ~10–14 weeks")

### 3.1 IN — must exist to launch
- Email + phone OTP auth, Google Sign-In (skip Apple until iOS submission)
- Profile: name, avatar, default address, single phone
- **4 seed categories** (Vehicles, Equipment, Electronics, Real Estate) with fixed attribute sets
- Product listing: create / edit / pause / delete (owner only)
- Media upload (images only, max 8) via Cloudinary signed uploads (S3 in v1.1)
- Search: keyword + category + price range + city + sort (relevance/newest/price)
- Listing detail with availability calendar (rentals) or "Buy Now" (sales)
- Booking / Order lifecycle: `pending → accepted → paid → active → completed`
- **Payments: Stripe Connect Express only.** USD only. Escrow via `manual` capture + `transfer` on completion.
- Buyer dashboard (upcoming, active, completed)
- Seller dashboard (listings, incoming requests, revenue, availability)
- Real-time chat (order-scoped + listing-inquiry-scoped)
- Reviews (buyer→seller, seller→buyer, 1–5 stars + text, post-completion only)
- Push notifications (FCM) + in-app inbox
- Report listing / user / message → admin queue
- Admin panel (Next.js): user table, listing moderation queue, order search, dispute list, payouts view
- Report-to-resolution SLA visible in admin

### 3.2 OUT — deferred to v1.1 / v2
- **Services booking** (whole category)
- **Fashion / Sports / Furniture / Events** categories
- **Razorpay + INR** (deliver in v1.1 with India launch)
- Apple Sign-In (add before iOS submission)
- Full KYC document upload UI (use Stripe Identity handoff instead)
- Map search (list view only in v1; map is Should-Have)
- Escrow *auto-release* after N days (v1 does manual admin release)
- Multi-currency, multi-language
- Delivery partner integration, insurance, subscriptions, promoted listings
- AI moderation, dynamic pricing
- Multi-vendor storefronts (single-seller pages exist; branded storefronts do not)
- Wallet / stored balance
- Custom category admin CRUD UI (seed via migration + JSON)

### 3.3 Deferred but "code the seam"
Design the schema and API to *support* the OUT items now, so v1.1 is additive, not a refactor:
- `products.listing_type` already has `service` and `hybrid` values → don't remove.
- `orders.order_type` already has `service` → keep.
- `category_fields` table exists but seeded, not admin-editable.
- `payments.provider` enum accepts `razorpay` — hidden in UI.

---

## 4. Revised Milestones

| Phase | Weeks | Deliverable |
|-------|-------|-------------|
| **0. Foundation** | 1–2 | Repos, CI, Postgres+Prisma, S3+Cloudinary, Sentry, Flutter scaffold, design tokens |
| **1. Auth & Profile** | 3 | Email/phone/Google login, JWT + refresh rotation, profile, addresses |
| **2. Listings** | 4–5 | Categories seeded, create/edit/pause listing, media upload, search+filter, listing detail |
| **3. Booking + Stripe** | 6–8 | Availability calendar, booking flow, Stripe Connect Express, escrow, refunds |
| **4. Chat + Notifications** | 9 | Socket.io chat, FCM push, in-app inbox |
| **5. Reviews + Reports** | 10 | Post-order reviews, moderation queue plumbing |
| **6. Admin (Next.js)** | 10–11 | Moderation, users, orders, payouts, disputes |
| **7. Harden + Launch** | 12–14 | Perf, security review, store metadata, closed beta, launch |

---

## 5. Non-Functional Requirements (kept from spec)

- API p95 < 500ms on cached reads; search p95 < 800ms.
- All uploads via signed URLs; no raw file bytes through the API.
- All webhooks signature-verified and idempotent.
- Row-level authorization on every read that returns another user's data.
- No card data ever touches our servers (Stripe.js / Payment Sheet on device).
- Backups: daily Postgres snapshot, 30-day retention.
- Observability: Sentry (client + server), structured JSON logs, Grafana Loki or hosted equivalent.

---

## 6. Team Assumption

This plan assumes: 1 Flutter dev, 1 backend dev, 1 admin/frontend dev (part-time), 1 designer (part-time), 1 PM/QA. Half that team roughly doubles the timeline. Doubling the team does **not** halve the timeline — Brooks's law applies especially to marketplace platforms.

---

## 7. Success Metrics for MVP

- **Supply-side:** 100 verified sellers, 500 approved listings, 4 categories live.
- **Demand-side:** 1 000 monthly active buyers, D30 retention ≥ 20%.
- **Marketplace health:** GMV ≥ $50 K / mo, refund rate < 5%, dispute rate < 2%, first-time-message-to-booking ≥ 15%.
- **Ops:** listing moderation SLA < 4 h, dispute-first-response SLA < 24 h.

---

## 8. What lives in *this* repo (`Rent95`)

Just the **Flutter mobile app**. Backend and admin panel are separate repos (recommended):
- `rent95-api` — Node.js + Express + Prisma
- `rent95-admin` — Next.js
- `rent95-app` — this repo (Flutter)

A monorepo (Turborepo / Nx) is fine later; three repos is faster to start.
