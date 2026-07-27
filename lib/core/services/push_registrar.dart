import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/notifications/data/device_token_repository.dart';
import '../../features/notifications/data/notification_providers.dart';
import 'push_service.dart';

/// Side-effect coordinator that keeps the device's FCM token in sync with
/// the currently-logged-in user.
///
/// Lifecycle:
///
/// - **On login** — request permissions if we haven't yet, fetch the current
///   token, and POST it to the backend so this user is targetable.
///
/// - **On token rotation** (Firebase reissues periodically) — replace the
///   old token registration with the new one.
///
/// - **On logout** — DELETE the token server-side so the account we just
///   logged out of doesn't keep receiving pushes on this device.
///
/// The registrar is a Provider so it starts on app boot (kick-started from
/// [_AppBootstrap] in `main.dart`) and lives for the whole session.
class PushRegistrar {
  PushRegistrar(this._ref) {
    _authSub = _ref.listen<AuthState>(
      authControllerProvider,
      _onAuthChanged,
      fireImmediately: true,
    );
    _tokenSub = _ref.read(pushServiceProvider).tokenChanges$.listen(_onTokenChanged);
  }

  final Ref _ref;
  ProviderSubscription<AuthState>? _authSub;
  StreamSubscription<String>? _tokenSub;

  /// User id we last registered a token for. When it changes we know we need
  /// to re-register with the new session's token.
  String? _lastUserId;

  /// The last FCM token we successfully POSTed. Kept so we can DELETE the
  /// exact same value on logout.
  String? _lastRegisteredToken;

  DeviceTokenRepository get _repo => _ref.read(deviceTokenRepositoryProvider);
  PushService get _push => _ref.read(pushServiceProvider);

  void _onAuthChanged(AuthState? previous, AuthState next) {
    if (!next.initialized) return;
    final nextUserId = next.user?.id;

    if (nextUserId == null) {
      // Logged out — revoke and forget.
      final oldToken = _lastRegisteredToken;
      _lastUserId = null;
      _lastRegisteredToken = null;
      if (oldToken != null) {
        unawaited(_safeRevoke(oldToken));
      }
      // Wipe the FCM token itself so a future signed-out session on the same
      // device doesn't reuse it.
      unawaited(_push.deleteToken());
      return;
    }

    if (nextUserId == _lastUserId) return; // no-op — same user
    _lastUserId = nextUserId;
    unawaited(_registerCurrentToken());
  }

  Future<void> _onTokenChanged(String token) async {
    if (_lastUserId == null) return; // no session to attach to yet
    if (token == _lastRegisteredToken) return;

    // Revoke the old token first so we don't leave a zombie registration.
    final old = _lastRegisteredToken;
    _lastRegisteredToken = token;
    if (old != null) await _safeRevoke(old);
    await _safeRegister(token);
  }

  Future<void> _registerCurrentToken() async {
    // On first login we also need to ask for permissions. Not a blocking
    // failure if the user says no — we just won't have a token to register.
    await _push.requestPermissions();
    final token = await _push.getToken();
    if (token == null || token.isEmpty) return;
    _lastRegisteredToken = token;
    await _safeRegister(token);
  }

  Future<void> _safeRegister(String token) async {
    try {
      await _repo.register(token, platform: _platformString());
    } catch (e) {
      // Non-critical — the app still works, just no pushes until next boot.
      if (kDebugMode) {
        // ignore: avoid_print
        print('[Rent95] Device-token register failed: $e');
      }
    }
  }

  Future<void> _safeRevoke(String token) async {
    try {
      await _repo.revoke(token);
    } catch (_) {
      // See above — best-effort.
    }
  }

  String _platformString() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  void dispose() {
    _authSub?.close();
    _authSub = null;
    _tokenSub?.cancel();
    _tokenSub = null;
  }
}

final pushRegistrarProvider = Provider<PushRegistrar>((ref) {
  final registrar = PushRegistrar(ref);
  ref.onDispose(registrar.dispose);
  return registrar;
});
