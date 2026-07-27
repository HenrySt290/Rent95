# Production ship-day checklist

Tick each box **in order**. Skipping is fine only if you're absolutely
sure you've done the equivalent by hand.

## 24 hours before launch

- [ ] Full test suite green on `main` in all three repos
- [ ] Merge freeze declared in your team's channel
- [ ] `docs/DEPLOY.md` re-read from top to bottom
- [ ] Stripe account is in **live mode**, not test mode
- [ ] Stripe Connect onboarding link works end-to-end for a real seller
- [ ] Firebase project has APNs key uploaded (iOS) and Google-services JSON
      pulled (Android)
- [ ] All environment variables from `docs/DEPLOY.md#environment-variables`
      are set on production hosts
- [ ] DNS TTL lowered to 300 seconds so rollback is fast

## 1 hour before launch

- [ ] `flyctl deploy` (or Render) — API healthy, `curl /health?deep=1` = 200
- [ ] `flyctl deploy` — admin panel healthy, login works with the seed admin
- [ ] Stripe webhook endpoint reachable, secret matches
- [ ] Sentry receiving test event: `sentry-cli send-event -m "hi from prod"`
- [ ] UptimeRobot monitors created:
  - [ ] `GET https://api.rent95.app/health?deep=1`
  - [ ] `GET https://admin.rent95.app/login`
- [ ] Sanity POST: `curl -X POST /api/auth/register` → succeeds, user visible in admin panel
- [ ] Sanity booking: create a listing as a real seller account, book it
      from the mobile app, complete payment with a live Stripe test card
      (`4242 4242 4242 4242` won't work in live mode — use a real card
      you'll refund)

## Launch

- [ ] Flip DNS A/AAAA records to production hosts
- [ ] Monitor Fly logs for the first 5 minutes:
      `flyctl logs -a rent95-api`
- [ ] Watch Sentry for spikes
- [ ] Post launch tweet 🚀

## First hour post-launch

- [ ] Refund the sanity booking
- [ ] Check Stripe dashboard for real charges — no unexpected declines
- [ ] Refresh admin dashboard — GMV shows the sanity booking
- [ ] Verify Stripe payouts to seller landed in escrow
- [ ] Test a push notification end-to-end
- [ ] Try to break the app: register with a bad email, upload a huge image,
      book overlapping dates — every case should show a friendly error, not a 500

## First 24 hours

- [ ] Review Sentry errors — sort by frequency, triage top 3
- [ ] Check refund rate is 0 or explained
- [ ] Check dispute rate is 0
- [ ] Verify at least one FCM push was delivered
- [ ] Check DB size, connection count via `flyctl postgres`
- [ ] Set DNS TTL back to 3600 seconds

## First week

- [ ] Scale up if p95 latency > 500ms on `/api/products`:
      `flyctl scale count 2 --region iad`
- [ ] Rotate `JWT_ACCESS_SECRET` if you seeded with a demo value
- [ ] Turn on automatic payouts in Stripe Connect
- [ ] Set up an on-call rotation (even if it's just you)

---

## The "oh no" playbook

**Symptom: 502s across the board**
→ `flyctl logs -a rent95-api` — probably the DB pool exhausted.
→ Add `?connection_limit=20` to `DATABASE_URL` and redeploy.

**Symptom: Payments failing with `capture_method: manual` errors**
→ Stripe Connect account not fully onboarded. Log into Stripe → Connect →
  accept remaining agreements.

**Symptom: `flyctl deploy` hangs at release_command**
→ Migration is running. Watch `flyctl logs`. If it's stuck > 5 min,
  the migration is probably locking a table — abort with Ctrl+C, roll back:
  `flyctl releases rollback`.

**Symptom: Admin panel can't login**
→ `API_URL` on the admin points at the wrong hostname, or `CORS_ORIGINS`
  on the API doesn't include the admin's origin.

**Symptom: Push notifications not arriving**
→ Wrong FCM service account. Base64-encode the JSON, run:
  `echo $FCM_SERVICE_ACCOUNT_JSON_BASE64 | base64 -d | jq .project_id` —
  should print your Firebase project id.
