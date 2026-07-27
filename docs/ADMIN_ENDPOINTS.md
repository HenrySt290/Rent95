# Admin endpoints — completed

The three admin panel pages that were rendering an "endpoint not wired yet"
banner now have real backend endpoints. Also added the moderation-queue
listing endpoint the listings page was falling back for, plus a full
dispute-resolution flow.

All changes ship in the updated `rent95-api.tar.gz` and `rent95-admin.tar.gz`
attached to this repo.

## New / expanded endpoints in `rent95-api`

| Endpoint | Roles | Purpose |
|---|---|---|
| `GET /api/admin/products` | admin, mod, support | Full moderation queue (all statuses, not just approved). Oldest-pending-first. Filters: `moderationStatus`, `status`, `listingType`, `keyword`. |
| `GET /api/admin/orders` | admin, mod, support | Paginated order table. Filters: `status`, `orderType`, `buyerId`, `sellerId`, `keyword`. Includes buyer/seller/product relations. |
| `GET /api/admin/payments` | **admin only** | Escrow + platform-fee breakdown. Filters: `status`, `escrowStatus`, `provider`. Moderators/support 403 — financial data is compartmentalised. |
| `GET /api/admin/disputes` | admin, mod, support | Every dispute with order + raisedBy + against relations. Open ones first, then most recently updated. Filter: `status`. |
| `PATCH /api/admin/disputes/:id/resolve` | admin, mod | Resolve in favour of buyer, seller, or partially. Runs the order/payment state change in a single Prisma transaction. |
| `PATCH /api/admin/users/:id/status` | **admin only (tightened)** | Was open to all staff; now matches the panel's capability matrix. |

## The dispute resolution state machine

`PATCH /api/admin/disputes/:id/resolve` accepts:

```json
{
  "resolution": "refund_buyer | release_seller | partial_refund | reject",
  "note": "Free-text audit trail",
  "partialRefundAmount": 40  // required for partial_refund
}
```

Side effects, in one transaction:

| Resolution | order.status | payment.status | payment.escrowStatus |
|---|---|---|---|
| `refund_buyer` | `refunded` | `refunded` | `refunded` |
| `release_seller` | `completed` | (unchanged in TX; Stripe capture called after commit) | released via `releaseEscrow()` |
| `partial_refund` | `refunded` | `partially_refunded` | `refunded` |
| `reject` | unchanged | unchanged | unchanged |

`releaseEscrow()` runs *outside* the transaction so we don't hold DB locks
while waiting on Stripe. If Stripe fails, the dispute is still resolved —
that's an ops issue to retry, not a reason to revert the admin's decision.

## New role gates enforced server-side

Matches the capability matrix already documented in
`rent95-admin/lib/session.ts`:

- `admin`-only: `suspend_user`, `view_payments`, `refund_payment`, `manage_categories`
- `admin` + `moderator`: `moderate_listing`, `resolve_dispute`
- `admin` + `moderator` + `support`: `view_users`, `view_listings`, `view_orders`, `view_disputes`, `view_dashboard`

Every write endpoint now runs `requireRole(...)` matching its capability.
Read endpoints stay open to all three roles.

## Coverage

`tests/integration/admin-extended.test.ts` — **25 new assertions**:

- Orders: RBAC (buyer 403, admin 200), pagination, filter by status /
  orderType / sellerId, relations included, unknown filter ignored
- Payments: RBAC (moderator + support 403, admin 200), filter by
  escrowStatus / provider, relations included
- Disputes: RBAC, filter by status, relations included
- Dispute resolution:
  - refund_buyer → order refunded + payment refunded + escrow refunded
  - release_seller → order completed + escrow released
  - partial_refund → payment.partially_refunded + amount recorded in note
  - partial_refund without amount → 400
  - reject → dispute rejected + order untouched
  - re-resolving a closed dispute → 400
  - support role blocked from resolving → 403
  - unknown resolution → 400
  - unknown dispute id → 404
- Moderation queue: shows all statuses, filter to pending only, FIFO order,
  keyword search across title + description

Also tightened `admin.test.ts#support role can VIEW users but cannot suspend`
from "either 200 or 403" to a hard `.toBe(403)` now that the route is gated.

## Panel updates

`rent95-admin/app/dashboard/disputes/`:
- `actions.ts` — server action calling the new resolve endpoint
- `dispute-actions.tsx` — client component that expands into an inline
  resolve panel with buttons for the four resolutions, note textarea, and
  a partial-refund amount input
- `page.tsx` — shows a resolution column on closed disputes and an
  Actions column on open ones (only rendered when the caller has the
  `resolve_dispute` capability)

## Run the new tests

```bash
cd rent95-api
docker compose -f docker-compose.test.yml up -d
npm run test:integration
# → new file: tests/integration/admin-extended.test.ts (25 assertions)
```

## Three-repo status

| Repo | Ship state |
|---|---|
| **`Rent95`** (Flutter mobile) | ✅ Complete v1 |
| **`rent95-api`** (Node backend) | ✅ **Every endpoint the admin panel references now exists + tested** |
| **`rent95-admin`** (Next.js panel) | ✅ Disputes now has a working resolve flow |
