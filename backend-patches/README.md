# Backend patches for FCM

Small additions to `rent95-api` needed to support the mobile app's push
integration. Apply these on top of the initial scaffold.

## Files in this folder

| File | Where it goes in `rent95-api` |
|---|---|
| `device-token.controller.ts` | `src/controllers/device-token.controller.ts` |
| `user.routes.ts` | `src/routes/user.routes.ts` |
| `push.service.ts` | `src/services/push.service.ts` |

Also:

1. In `src/app.ts` add `app.use('/api/users', userRoutes);` alongside the
   other route mounts.
2. `npm install firebase-admin` (Firebase Admin SDK for Node).
3. Add `FCM_SERVICE_ACCOUNT_JSON_BASE64` to your `.env` — base64 of your
   service-account JSON, obtained from Firebase Console → Project settings
   → Service accounts → "Generate new private key". Alternatively set
   `GOOGLE_APPLICATION_CREDENTIALS` to the JSON file's path.

## How to actually send pushes

Wherever your existing code creates a `Notification` row (order accepted,
new chat message, listing approved, etc.), replace `prisma.notification.create({...})`
with a call to the helper:

```ts
import { notifyUser } from '../services/push.service';

await notifyUser(order.buyerId, {
  title: 'Booking accepted',
  body: `${sellerName} accepted your rental request.`,
  type: 'booking_accepted',
  entityId: order.id,
});
```

The helper persists to the DB **and** fans out an FCM push to every device
the user has registered. Failed tokens are cleaned up automatically.

## The mobile → backend contract

Push payloads must include a `type` field that matches one of the strings
in `lib/core/services/notification_router.dart#_routeFor`:

| type | entityId | Opens |
|---|---|---|
| `message_received` | conversationId | Chat detail |
| `booking_requested` `booking_accepted` `booking_rejected` `order_started` `order_completed` `payment_success` `payment_failed` `refund_processed` | orderId | Order detail |
| `listing_approved` `listing_rejected` | listingId | Listing detail |
| `review_received` | — | Reviews screen |
| `kyc_approved` `kyc_rejected` `account_verified` `payout_processed` | — | Notifications inbox |
| anything else | — | Notifications inbox |
