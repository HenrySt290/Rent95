import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/env.dart';

/// Wrapper around `flutter_local_notifications`.
///
/// Why we need this even though we're already using FCM:
///
/// When the app is in the **foreground**, Firebase Messaging does NOT show a
/// system notification — you just get a `RemoteMessage` in your handler. If
/// we want the user to actually *see* a notification banner during that time
/// (they usually do — a new chat message needs to be visible even if the app
/// is open), we manually pop it via `flutter_local_notifications`.
///
/// When the app is **backgrounded or terminated**, iOS/Android show the FCM
/// notification themselves and this class is not involved.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final StreamController<String?> _taps = StreamController<String?>.broadcast();

  /// Emits the `payload` string whenever the user taps a locally-displayed
  /// notification. Consumers turn this into a route in [NotificationRouter].
  Stream<String?> get taps$ => _taps.stream;

  bool _initialized = false;

  static const _androidChannel = AndroidNotificationChannel(
    'rent95_general',
    'General notifications',
    description: 'Messages, bookings, payments, and other Rent95 alerts.',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    // iOS: we do NOT request permissions here — that happens in
    // `PushService.requestPermissions()` so we only ask once.
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);

    try {
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          if (!_taps.isClosed) _taps.add(response.payload);
        },
      );

      // Ensure the Android channel exists so `Importance.high` actually
      // produces a heads-up notification.
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(_androidChannel);

      _initialized = true;
    } catch (e) {
      if (Env.isDev) {
        // ignore: avoid_print
        print('[Rent95] LocalNotificationService.init failed: $e');
      }
    }
  }

  /// Show a heads-up banner. Called by [PushService] on foreground FCM messages.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) return;
    try {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
        payload: payload,
      );
    } catch (e) {
      if (Env.isDev) {
        // ignore: avoid_print
        print('[Rent95] LocalNotificationService.show failed: $e');
      }
    }
  }

  @visibleForTesting
  Future<void> dispose() async {
    await _taps.close();
  }
}

final localNotificationServiceProvider = Provider<LocalNotificationService>((_) {
  return LocalNotificationService.instance;
});
