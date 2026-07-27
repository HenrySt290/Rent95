import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import 'socket_client.dart';

/// Watches the auth state and drives the socket lifecycle accordingly.
///
/// Rules:
///   - When the user becomes authenticated → `connect()`
///   - When the user logs out → `disconnect()`
///   - When the user identity changes → reconnect with the new token
///
/// The controller doesn't own any state of its own — it's a side-effect
/// coordinator. Instantiate it once at app boot (see `main.dart`) and forget.
class SocketLifecycleController {
  SocketLifecycleController(this._ref) {
    _sub = _ref.listen<AuthState>(
      authControllerProvider,
      _onAuthStateChanged,
      fireImmediately: true,
    );
  }

  final Ref _ref;
  ProviderSubscription<AuthState>? _sub;
  String? _lastUserId;

  void _onAuthStateChanged(AuthState? previous, AuthState next) {
    // Wait for the bootstrap check to finish so we don't connect with a
    // stale/absent token during app start.
    if (!next.initialized) return;

    final client = _ref.read(socketClientProvider);
    final nextUserId = next.user?.id;

    if (nextUserId == null) {
      // Logged out.
      _lastUserId = null;
      unawaited(client.disconnect());
      return;
    }

    if (nextUserId != _lastUserId) {
      // Fresh login OR account switch — connect with the current token.
      _lastUserId = nextUserId;
      unawaited(client.reconnectWithFreshToken());
    }
  }

  void dispose() {
    _sub?.close();
    _sub = null;
  }
}

/// Attach once at app start so it wires itself to the auth controller.
///
/// ```dart
/// // main.dart
/// runApp(ProviderScope(
///   observers: [], // your existing observers
///   child: Consumer(builder: (ctx, ref, _) {
///     ref.watch(socketLifecycleProvider); // brings it to life
///     return const Rent95App();
///   }),
/// ));
/// ```
final socketLifecycleProvider = Provider<SocketLifecycleController>((ref) {
  final controller = SocketLifecycleController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
