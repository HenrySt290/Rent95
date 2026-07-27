# Backend patches

Small additions to `rent95-api` for features shipped in the mobile app after
the initial scaffold. Apply each on top of the base backend.

## Files in this folder

| File | Where it goes in `rent95-api` | Feature |
|---|---|---|
| `device-token.controller.ts` | `src/controllers/device-token.controller.ts` | FCM push |
| `user.routes.ts` | `src/routes/user.routes.ts` | FCM push |
| `push.service.ts` | `src/services/push.service.ts` | FCM push |
| `uploads.controller.ts` | `src/controllers/uploads.controller.ts` | **Cloudinary uploads** |
| `uploads.routes.ts` | `src/routes/uploads.routes.ts` | **Cloudinary uploads** |

## FCM push

1. `npm install firebase-admin`
2. Add to `.env`: `FCM_SERVICE_ACCOUNT_JSON_BASE64=<base64 of service-account JSON>`
   (or `GOOGLE_APPLICATION_CREDENTIALS=/absolute/path`)
3. In `src/app.ts`: `app.use('/api/users', userRoutes);`
4. Replace direct `prisma.notification.create(...)` calls with
   `notifyUser(userId, {...})` from `services/push.service.ts` — the helper
   persists AND pushes in one call.

## Cloudinary uploads

1. `npm install cloudinary` (~50 KB, no native deps)
2. Confirm your `.env` has the Cloudinary trio (already in `.env.example`):
   ```
   CLOUDINARY_CLOUD_NAME=…
   CLOUDINARY_API_KEY=…
   CLOUDINARY_API_SECRET=…
   ```
3. In `src/app.ts`:
   ```ts
   import uploadsRoutes from './routes/uploads.routes';
   app.use('/api/uploads', uploadsRoutes);
   ```

That's it. The mobile app now hits `POST /api/uploads/signature` to obtain
short-lived credentials, then uploads the file bytes directly to Cloudinary
— **the file never touches our server**, saving bandwidth and giving the
client a real progress bar. Cloudinary applies transformations (thumbnails,
compression) automatically.

### How to send pushes referencing uploaded media

Cloudinary returns a `secure_url` from the direct upload. The mobile app
stores that URL on the product/review/user record via the existing
`POST /api/products`, `POST /api/reviews`, `PATCH /api/users/profile`
endpoints — no additional backend changes needed. The URL is the source of
truth; we never sync it out of Cloudinary.

## The mobile → backend contract for pushes

Push payloads must include a `type` field that maps to a route in
`lib/core/services/notification_router.dart#routeFor`:

| type | entityId | Opens |
|---|---|---|
| `message_received` | conversationId | Chat detail |
| `booking_requested` `booking_accepted` `booking_rejected` `order_started` `order_completed` `payment_success` `payment_failed` `refund_processed` | orderId | Order detail |
| `listing_approved` `listing_rejected` | listingId | Listing detail |
| `review_received` | — | Reviews screen |
| `kyc_approved` `kyc_rejected` `account_verified` `payout_processed` | — | Notifications inbox |
| anything else | — | Notifications inbox |
