import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/env.dart';
import 'local_notification_service.dart';

/// Small typed payload extracted from a Firebase [RemoteMessage].
///
/// We keep this class so the rest of the app never has to import
/// `firebase_messaging` directly — swapping the transport later (e.g. adding
/// OneSignal alongside FCM) means only [PushService] changes.
@immutable
class PushPayload {
  const PushPayload({
    required this.type,
    required this.data,
    this.title,
    this.body,
    this.entityId,
  });

  final String type;
  final Map<String, String> data;
  final String? title;
  final String? body;
  final String? entityId;

  factory PushPayload.fromRemoteMessage(RemoteMessage m) {
    final data = m.data.map((k, v) => MapEntry(k.toString(), v.toString()));
    return PushPayload(
      type: data['type'] ?? 'system',
      title: m.notification?.title ?? data['title'],
      body: m.notification?.body ?? data['body'],
      entityId: data['entityId'] ??
          data['conversationId'] ??
          data['orderId'] ??
          data['listingId'],
      data: data,
    );
  }
}

// -----------------------------------------------------------------------------
// Background handler
//
// Must be a top-level function (not a method) so Dart can register it in the
// background isolate. Firebase spins up a separate isolate for messages that
// arrive while the app is terminated — nothing from the main isolate is
// available here (no Riverpod, no navigator, no widgets).
// -----------------------------------------------------------------------------
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // We deliberately do NOT do anything heavy here. The system will display
  // the notification banner because the FCM payload contains a `notification`
  // field. All server-sent Rent95 pushes include one, so this handler is only
  // needed to satisfy Firebase's contract that a top-level handler exists.
  if (kDebugMode) {
    // ignore: avoid_print
    print('[Rent95] BG push: ${message.messageId} type=${message.data['type']}');
  }
}

/// Central Firebase Cloud Messaging integration.
///
/// Public shape:
///   - `init()`              — call once from `main.dart` before `runApp`
///   - `requestPermissions()` — async, safe to call multiple times
///   - `getToken()`          — returns the current FCM token (or null)
///   - `tokenStream$`        — emits new tokens as Firebase rotates them
///   - `taps$`               — emits [PushPayload] whenever the user taps a
///                              notification (foreground, background, or
///                              launched-from-terminated)
///   - `foregroundMessages$` — for advanced use; most consumers ignore this
///
/// The service is **safe to call unconditionally** even if Firebase is not
/// configured: `init()` short-circuits and every method returns a no-op or
/// null, so the app boots and demos continue to work with zero setup.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  FirebaseMessaging? _messaging;

  final StreamController<PushPayload> _taps =
      StreamController<PushPayload>.broadcast();
  final StreamController<PushPayload> _foreground =
      StreamController<PushPayload>.broadcast();
  final StreamController<String> _tokenChanges =
      StreamController<String>.broadcast();

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenSub;
  StreamSubscription<String>? _onTokenSub;
  StreamSubscription<String?>? _localTapSub;

  Stream<PushPayload> get taps$ => _taps.stream;
  Stream<PushPayload> get foregroundMessages$ => _foreground.stream;
  Stream<String> get tokenChanges$ => _tokenChanges.stream;

  /// Guaranteed no-op when Firebase isn't configured (no `google-services.json`
  /// / `GoogleService-Info.plist`). This lets the whole app boot in mock mode
  /// with zero platform setup — you'll just never get pushes.
  Future<void> init() async {
    if (_initialized) return;

    try {
      // Initialize Firebase core. If DefaultFirebaseOptions were generated,
      // pass them here instead. We use the platform-default file lookup so
      // we don't need to commit a generated Dart file.
      await Firebase.initializeApp();
    } catch (e) {
      // Missing config files → don't blow up the app; just skip push.
      if (Env.isDev) {
        // ignore: avoid_print
        print(
          '[Rent95] Firebase.initializeApp skipped: $e. '
          'Add google-services.json / GoogleService-Info.plist to enable push. '
          'See docs/FCM_SETUP.md.',
        );
      }
      return;
    }

    _messaging = FirebaseMessaging.instance;

    // The background handler must be registered before any messages can arrive,
    // and it must be a top-level function.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await LocalNotificationService.instance.init();

    // Foreground messages: show a local notification so the user actually sees
    // something. Also broadcast to `foregroundMessages$` for screens that want
    // to react in-place (e.g. chat detail can drop the banner if the user is
    // already looking at the conversation).
    _onMessageSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // App was backgrounded, user tapped a system notification → app resumed.
    _onOpenSub = FirebaseMessaging.onMessageOpenedApp.listen((m) {
      _taps.add(PushPayload.fromRemoteMessage(m));
    });

    // App was terminated, user tapped a notification → app launched.
    // Fire the tap event after the app has had a chance to boot — we let the
    // NotificationRouter buffer these until GoRouter is ready.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      // Defer so any listeners attached during `runApp` don't miss the event.
      scheduleMicrotask(() => _taps.add(PushPayload.fromRemoteMessage(initialMessage)));
    }

    // Token rotation — Firebase periodically issues new tokens. Whenever it
    // does, push the new value so DeviceTokenRegistrar can send it to the API.
    _onTokenSub = _messaging!.onTokenRefresh.listen((token) {
      if (!_tokenChanges.isClosed) _tokenChanges.add(token);
    });

    // Also route taps from the local (foreground-displayed) notification to
    // the same `taps$` stream so consumers only have one thing to watch.
    _localTapSub = LocalNotificationService.instance.taps$.listen((payload) {
      if (payload == null) return;
      // Payload is a compact `type|entityId|convId|orderId` string built by
      // _onForegroundMessage; parse it back into a PushPayload.
      final parts = payload.split('|');
      _taps.add(PushPayload(
        type: parts.isNotEmpty ? parts[0] : 'system',
        entityId: parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null,
        data: <String, String>{
          for (var i = 0; i < parts.length; i++) 'p$i': parts[i],
        },
      ));
    });

    _initialized = true;
  }

  /// Request notification permissions. On iOS this pops the system prompt;
  /// on Android 13+ it triggers `POST_NOTIFICATIONS`. Safe to call multiple
  /// times — subsequent calls no-op if already granted or denied.
  Future<bool> requestPermissions() async {
    if (!_initialized || _messaging == null) return false;
    try {
      final settings = await _messaging!.requestPermission(
        alert: true, badge: true, sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  /// Current FCM token, or null if Firebase isn't configured / the user
  /// declined permissions.
  Future<String?> getToken() async {
    if (!_initialized || _messaging == null) return null;
    try {
      return await _messaging!.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Delete the current token. Called on logout so old device+account
  /// combinations don't keep receiving pushes.
  Future<void> deleteToken() async {
    if (!_initialized || _messaging == null) return;
    try {
      await _messaging!.deleteToken();
    } catch (_) {
      // Best-effort — old token stays orphaned server-side until Firebase
      // expires it, which is fine.
    }
  }

  // ---------------------------------------------------------------------------

  Future<void> _onForegroundMessage(RemoteMessage m) async {
    final payload = PushPayload.fromRemoteMessage(m);
    _foreground.add(payload);

    // Only show a local banner if the FCM payload had a `notification` field
    // (that's what carries the display title/body). Data-only messages are
    // routed through streams silently.
    final title = payload.title;
    final body = payload.body;
    if (title == null && body == null) return;

    // Compact payload string so we can reconstruct the tap payload later.
    final serialized = '${payload.type}|${payload.entityId ?? ''}';

    await LocalNotificationService.instance.show(
      id: m.messageId?.hashCode ?? DateTime.now().microsecondsSinceEpoch % 0x7FFFFFFF,
      title: title ?? 'Rent95',
      body: body ?? '',
      payload: serialized,
    );
  }

  @visibleForTesting
  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onOpenSub?.cancel();
    await _onTokenSub?.cancel();
    await _localTapSub?.cancel();
    await _taps.close();
    await _foreground.close();
    await _tokenChanges.close();
  }
}
final pushServiceProvider = Provider<PushService>((_) => PushService.instance);
