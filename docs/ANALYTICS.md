# Real analytics — time-series infrastructure

Replaces the placeholder chart generator on the admin dashboard with a
production-shape analytics endpoint backed by Postgres time-series queries.

## The endpoint

```
GET /api/admin/analytics?range=7d|14d|30d|90d   (default: 14d)
```

Returns a single response containing everything the dashboard renders:

```jsonc
{
  "range": { "from": "2025-01-13", "to": "2025-01-27", "days": 14 },
  "gmv":         { "total": 12480, "currency": "USD", "series": [...], "delta": { "percent": 12.4, "vs": "previous_period" } },
  "newUsers":    { "total": 87,   "series": [...], "delta": {...} },
  "newListings": { "total": 42,   "series": [...], "delta": {...} },
  "orders": {
    "total": 156,
    "series": [...],
    "byStatus": { "paid": 88, "completed": 45, "refunded": 8, "disputed": 3, ... },
    "delta": {...}
  },
  "paymentSuccessRate": 0.972,
  "refundRate": 0.051,
  "disputeRate": 0.019,
  "topCategories": [
    { "id": "cat_...", "name": "Vehicles", "gmv": 5230, "orderCount": 42 },
    ...
  ]
}
```

Every `series` is an array of `{ day: 'YYYY-MM-DD', value: number }` — **zero-filled
by Postgres** via `generate_series` + `LEFT JOIN` so the frontend never has
to gap-fill.

## Why time-series in raw SQL

Prisma's aggregations can't group by a date-truncated timestamp, so we drop
to `$queryRaw` with `Prisma.sql` tagged templates:

```sql
SELECT
  gs.day::date AS day,
  COALESCE(SUM(o.total_amount), 0)::text AS value
FROM generate_series(
  date_trunc('day', $1::timestamp),
  date_trunc('day', $2::timestamp),
  '1 day'
) AS gs(day)
LEFT JOIN orders o
  ON date_trunc('day', o.created_at) = gs.day
  AND o.status IN ('paid', 'active', 'completed')
GROUP BY gs.day
ORDER BY gs.day
```

- Zero-day rows come back with `value = 0` — no client gap-filling.
- All bucketing happens in UTC. Timezone conversion in SQL would blow
  away the `created_at` index; the frontend renders local time from the
  ISO date string instead.
- **GMV counts only paid/active/completed** — refunded and disputed money
  isn't marketplace revenue.

## Delta chips (period-over-period)

Every headline metric compares the requested window to the immediately-
preceding window of equal length. The dashboard renders it as a small
`▲ 12.4%` or `▼ 3.1%` chip next to the value.

- Zero previous → `delta: null` → chip hidden (avoids ±∞% ugliness).
- Clamped to ±9 999.9% so a first-week launch doesn't blow the layout.

## Rates: null when the denominator is zero

`paymentSuccessRate`, `refundRate`, `disputeRate` all return `null` rather
than `0` when there's no data in the window. That way the panel can render
`—` for "no data yet" instead of a misleading `0.0%` or `100%`.

## Test coverage

`tests/integration/analytics.test.ts` — **13 assertions**:

- RBAC (buyer 403, admin 200)
- Zero-fill: empty window returns exactly N buckets, all zero
- GMV filter: only paid/active/completed count
- Out-of-window rows never leak in
- Per-day bucketing for new users, new listings, orders
- `orders.byStatus` breakdown
- `refundRate` / `disputeRate` as fractions in [0, 1]
- `paymentSuccessRate` from Payment.status (captured + authorized ÷ all)
- `topCategories` ranked by GMV with tie-break by order count
- `delta.percent` positive vs negative
- `delta = null` when previous window has zero
- Unknown `?range=` values fall back to 14d without 422-ing

Each test uses `backdateOrder / backdateUser / backdateProduct / backdatePayment`
helpers that overwrite `created_at` post-insert, letting us drop rows into
specific historical days deterministically.

## Frontend

`rent95-admin/app/dashboard/page.tsx` is now driven entirely by the
analytics endpoint:

- **Range picker** (`components/ui/range-picker.tsx`) — 4 preset buttons,
  URL-driven (`?range=…`) so links are shareable.
- **6 stat cards** with delta chips on the 4 windowed ones (GMV / users /
  listings / orders).
- **4 rate cards** with red/amber/green intent based on health thresholds
  (payment ≥95% success = green, refund <5% = green, dispute <2% = green).
- **4 time-series line charts** — GMV, new users, new listings, all
  fetched from the same `?range=…` response, plus an orders-by-status
  bar chart.
- **Top categories table** at the bottom.

The `StatCard` component grew a `delta` prop that renders a colour-coded
percentage chip inline with the value.

## Deploy notes

- No new indexes needed — the existing `orders(created_at)` /
  `users(created_at)` / `products(created_at)` btrees are enough for
  a 90-day window on a few million rows. If you push to a year+ window
  in the future, add a BRIN index on the `created_at` columns.
- The endpoint fires **~10 queries in parallel** per request. On a
  small local DB the whole call returns in ~30 ms. On a real box with
  a warm cache, budget for 100–200 ms.
- Redis caching not yet wired — the response is expensive but only for
  admin users. If it becomes a bottleneck, cache for 60 s with the range
  as key.

## What still uses the old `/api/admin/dashboard`

The non-windowed rollup cards (Total users, Total listings, Open disputes)
still fetch from `/api/admin/dashboard` because they're deliberately
"all-time" numbers. Both endpoints coexist and the page fires them in
parallel.
