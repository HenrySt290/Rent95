# Firebase Cloud Messaging setup

`PushService` boots cleanly with **no Firebase config** — `Firebase.initializeApp()`
throws, the service quietly skips setup, and the app runs as normal (just with
no push). Once you're ready to ship real notifications, follow the steps below.

Applied **after** `flutter create --platforms=android,ios .`.

---

## 1. Create a Firebase project

1. <https://console.firebase.google.com> → **Add project**
2. Add an **Android app** with package name `com.rent95.rent95` (or whatever
   `applicationId` you set in `android/app/build.gradle`)
3. Add an **iOS app** with bundle id `com.rent95.rent95` (or your Xcode value)

## 2. Download config files

- **Android** → `google-services.json` → drop into `android/app/`
- **iOS** → `GoogleService-Info.plist` → drop into `ios/Runner/` (drag into
  Xcode so it's added to the target, or use Xcode's *Add Files to "Runner"…*)

Both files are safe to commit — they carry only public Firebase project IDs.

## 3. Android — `android/build.gradle` (project-level)

```gradle
plugins {
    // ...existing plugins
    id "com.google.gms.google-services" version "4.4.2" apply false
}
```

## 4. Android — `android/app/build.gradle` (app-level)

```gradle
plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
    id "com.google.gms.google-services"   // ← ADD THIS at the bottom
}

android {
    defaultConfig {
        minSdkVersion 21     // FCM requirement
        // ...
    }
}
```

## 5. Android — `android/app/src/main/AndroidManifest.xml`

Add inside `<application>`:

```xml
<!-- Default channel used when the app is in the background (i.e. we can't
     control the channel from the client). Must match rent95_general in
     LocalNotificationService and push.service.ts. -->
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="rent95_general" />

<!-- Optional: default icon shown when the payload doesn't override one. -->
<meta-data
    android:name="com.google.firebase.messaging.default_notification_icon"
    android:resource="@mipmap/ic_launcher" />
```

Android 13+ also requires runtime `POST_NOTIFICATIONS` permission — the
`firebase_messaging` package requests it automatically when
`FirebaseMessaging.instance.requestPermission()` is called, which the app
does on first login via `PushRegistrar._registerCurrentToken`.

## 6. iOS — `ios/Runner/Info.plist`

```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

## 7. iOS — Push capability

1. Open `ios/Runner.xcworkspace` in Xcode
2. Runner target → **Signing & Capabilities** → **+ Capability** → **Push Notifications**
3. Then → **+ Capability** → **Background Modes** → check **Remote notifications**

## 8. iOS — APNs key

1. <https://developer.apple.com/account/resources/authkeys> → **+**
2. Enable "Apple Push Notifications service (APNs)"
3. Download the `.p8` file (only downloadable once!)
4. Firebase Console → Project settings → **Cloud Messaging** → **APNs Authentication Key** → **Upload**
5. Paste your Key ID and Team ID

Without this step, iOS pushes are silently dropped by Apple's servers.

## 9. Backend — Firebase Admin SDK

The server sends pushes via Firebase Admin. See `backend-patches/README.md`
in this repo — it walks through:

- `npm install firebase-admin`
- Generating a service-account key
- Adding `FCM_SERVICE_ACCOUNT_JSON_BASE64` to `.env`
- The `notifyUser()` helper that combines DB persist + push in one call

## 10. Testing

The Firebase console has a test-send UI: **Engage → Messaging → New campaign
→ Notifications**. Or from the command line:

```bash
# Grab your token from the debug console — the app prints it once on first login.
# Or: install `pip install requests` and use the FCM v1 REST API.

curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=YOUR_LEGACY_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "DEVICE_TOKEN",
    "notification": {"title": "Hello", "body": "Test from curl"},
    "data": {"type": "message_received", "entityId": "conv_001"}
  }'
```

(FCM v1 API is preferred over the legacy `key=` header for new projects —
Firebase Admin SDK handles that for you server-side.)

## 11. Verifying the flow

1. Log into the mobile app on a physical device (simulators don't do push).
2. Watch the debug console for a line like
   `PushRegistrar registering token: fXn9Q…`.
3. Fire a test message from the Firebase console → target that token.
4. If the app is **foregrounded**: the banner appears via
   `LocalNotificationService` — tap it → deep-link fires via
   `NotificationRouter`.
5. If the app is **backgrounded**: the OS shows a system notification →
   tap → app resumes → `NotificationRouter` routes.
6. If the app is **terminated**: tap → app launches cold →
   `FirebaseMessaging.instance.getInitialMessage()` picks up the payload →
   `NotificationRouter` buffers it until `MaterialApp.router` mounts, then
   navigates.

## What to expect if you skip all of this

The app runs exactly as before — mock mode / dev mode / Stripe mode all
work. `PushService.init()` catches the missing-config error, logs a friendly
line in debug mode, and every subsequent call returns null / false / no-op.
Users just never get pushes. Fix that by completing steps 1–8.
