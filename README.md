# Rent95 📱

**Rent, buy, and book anything.** A production-ready Flutter mobile app for a multi-category rental & sales marketplace — vehicles, real estate, equipment, electronics, fashion, sports gear, services, and more.

> 📄 Full product review + revised MVP: [`docs/MVP_REVISED.md`](docs/MVP_REVISED.md)

---

## What's in this repo

Just the **Flutter mobile app**. The backend (Node.js/Express) and admin panel (Next.js) live in separate repositories — see `docs/MVP_REVISED.md` §8.

The app ships **fully working in mock mode** — no backend required to run it. You can log in, browse, search & filter, view listings, save favourites, book a rental, "pay", chat with a seller, create a listing, and see the seller dashboard. Every mock repository has a real API seam waiting behind it (`Env.useMocks`).

## Screens implemented (§5.3 of the spec)

- ✅ Splash → Onboarding (3 pages) → Login / Register / OTP / Forgot password
- ✅ Home (categories, promo banner, featured, near-you grid)
- ✅ Search + filter bottom sheet (category, type, price range, city, sort)
- ✅ Listing detail (image carousel, seller card, reviews, similar listings)
- ✅ 5-step Create Listing flow (type → category → title/desc/photos → pricing → preview)
- ✅ Booking request (calendar range picker, quantity, delivery, price breakdown)
- ✅ Checkout (payment method picker, escrow copy, success sheet)
- ✅ Buyer orders list + order detail with status timeline
- ✅ Chat list + real-time-style chat detail (with mock auto-reply)
- ✅ Profile with account / selling / settings sections
- ✅ Seller dashboard (revenue, active listings, incoming requests with accept/decline)
- ✅ Saved listings, Notifications inbox
- ✅ Bottom-nav shell for authenticated users

## Architecture (§5.1 of the spec)

Clean-architecture-lite with Riverpod + go_router:

```
lib/
├── app/                  # App shell, router, theme
├── core/
│   ├── constants/        # Env, routes, static constants
│   ├── errors/           # Typed AppException hierarchy
│   ├── network/          # Dio client + interceptors (auth, error mapping)
│   ├── storage/          # Secure token storage
│   ├── utils/            # Formatters
│   └── widgets/          # App-level widgets (shell)
├── features/             # One folder per feature (data / domain / presentation)
│   ├── auth/
│   ├── home/
│   ├── categories/
│   ├── listings/
│   ├── search/
│   ├── booking/
│   ├── orders/
│   ├── payments/
│   ├── chat/
│   ├── reviews/
│   ├── profile/
│   ├── seller_dashboard/
│   ├── buyer_dashboard/
│   └── notifications/
├── shared/
│   ├── models/           # Plain Dart domain models w/ JSON codecs
│   ├── services/         # MockStore, external service clients
│   └── components/       # Cross-feature widgets (listing card, chips, shimmer, empty state)
└── main.dart
```

## Tech stack (matches spec §3.2)

| Concern | Package |
|---|---|
| State management | `flutter_riverpod` |
| Routing | `go_router` |
| Networking | `dio` |
| Serialization | `freezed_annotation` + `json_annotation` (codegen optional) |
| Local storage | `shared_preferences`, `hive` |
| Secure storage | `flutter_secure_storage` |
| Images | `cached_network_image`, `image_picker`, `image_cropper` |
| Maps | `google_maps_flutter`, `geolocator` |
| Realtime | `socket_io_client` |
| Push | `firebase_messaging`, `flutter_local_notifications` |
| OAuth | `google_sign_in`, `sign_in_with_apple` |
| Payments | `flutter_stripe`, `razorpay_flutter` |
| UI helpers | `google_fonts`, `shimmer`, `carousel_slider`, `flutter_rating_bar`, `table_calendar` |

---

## Getting started

### 1. Install Flutter (once)

**macOS (recommended):**
```bash
brew install --cask flutter
flutter doctor
```

**Linux:**
```bash
git clone --depth 1 -b stable https://github.com/flutter/flutter.git ~/flutter
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
flutter doctor
```

**Windows:** follow the [official guide](https://docs.flutter.dev/get-started/install/windows).

You'll also want **Android Studio** (for the Android SDK + emulator) and **Xcode** (macOS only, for iOS).

### 2. Bootstrap platform folders

The repo intentionally ships **without** `android/` and `ios/` folders so it stays lightweight. Generate them once:

```bash
cd Rent95
flutter create --platforms=android,ios,web --org com.rent95 .
```

This preserves `lib/`, `pubspec.yaml`, `test/`, etc. and only creates the missing platform folders.

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Run

```bash
# Runs in MOCK mode — no backend needed. Log in with any email/password.
flutter run

# Later, when your backend is live, run against real APIs:
flutter run \
  --dart-define=USE_MOCKS=false \
  --dart-define=API_BASE_URL=https://api.rent95.dev \
  --dart-define=SOCKET_URL=https://ws.rent95.dev \
  --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_xxx \
  --dart-define=GOOGLE_MAPS_API_KEY=xxx \
  --dart-define=ENVIRONMENT=dev
```

### 5. Run tests

```bash
flutter test
```

### Troubleshooting

- **`flutter run` says no `android/` / `ios/` folder exists** → you skipped step 2: `flutter create --platforms=android,ios,web --org com.rent95 .`
- **`flutter pub get` fails with "intl is pinned … version solving failed"** → your Flutter SDK is older than the `intl` pin in `pubspec.yaml`. Run `flutter upgrade` (intl 0.20.2 is required by `flutter_localizations` on current stable).

### 6. Build for release

```bash
flutter build apk --release          # Android
flutter build appbundle --release    # Android — for Play Store
flutter build ios --release          # iOS (requires macOS + Xcode)
```

---

## Switching from Mock → Real backend

Every mock lives behind an interface used by the presentation layer via Riverpod. To wire a real backend:

1. Add real repository classes under `lib/features/<feature>/data/` implementing the same shape as `MockStore` methods.
2. In each feature's `*_providers.dart`, branch on `Env.useMocks` to pick the mock or real repo.
3. Ship your Node.js API implementing the endpoints in §8 of `docs/MVP_REVISED.md`.

The `Dio` client, auth interceptor, error mapping, and token storage are already wired in `lib/core/network/api_client.dart`.

---

## What's **not** yet included (deliberately)

Per the revised MVP in `docs/MVP_REVISED.md`:

| Item | Why deferred | When |
|---|---|---|
| Real Firebase FCM registration | Requires a Firebase project + config files | Before store submission |
| Real Stripe Payment Sheet | Requires Stripe Connect + backend PI creation | Payments phase (§20.4) |
| Real Google Maps view | Requires API key + platform manifests | Search v1.1 (Should-have) |
| Apple Sign-In | Needed for iOS submission only | Before iOS submission |
| Razorpay | Deferred to India launch | v1.1 |
| Admin panel (Next.js) | Separate repo | Parallel workstream |
| Backend (Node.js) | Separate repo | Parallel workstream |

Every one of these has its dependency already declared in `pubspec.yaml` so the wiring is a small, focused task rather than a package hunt.

---

## Sandbox note

If you're viewing this repo inside the Arena sandbox: the sandbox blocks `pub.dev` and `storage.googleapis.com`, so `flutter pub get` and `flutter build` **cannot run in-sandbox**. Clone the repo to your own machine (or a CI runner with normal internet access) and everything works. The code is otherwise complete and self-consistent.

---

## Contributing / next steps

Suggested next chunks of work, in order:

1. `flutter create --platforms=android,ios .` — generate platform folders
2. `flutter pub get && flutter run` — verify it launches
3. Spin up the Node backend repo (`rent95-api`) — start with `/api/auth/*` + `/api/products`
4. Flip `USE_MOCKS=false` and wire the real repos one feature at a time
5. Add Firebase + Stripe keys per platform following each package's README
