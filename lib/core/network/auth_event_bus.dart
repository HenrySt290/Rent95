import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Events emitted by the network layer that the app-level auth state cares about.
///
/// The Dio [TokenRefreshInterceptor] emits [AuthEvent.forceLogout] whenever the
/// refresh token itself is invalid or expired — the only correct response is to
/// wipe local session and bounce the user back to the login screen.
enum AuthEvent { forceLogout }

/// Broadcast-style event bus. Kept intentionally tiny — anything richer belongs
/// in Riverpod state proper. This is only for cross-layer decoupling (Dio ↔ auth
/// controller) so the network layer doesn't have to `ref.read` into feature code.
class AuthEventBus {
  final StreamController<AuthEvent> _controller =
      StreamController<AuthEvent>.broadcast();

  Stream<AuthEvent> get stream => _controller.stream;

  void emit(AuthEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  void dispose() => _controller.close();
}

final authEventBusProvider = Provider<AuthEventBus>((ref) {
  final bus = AuthEventBus();
  ref.onDispose(bus.dispose);
  return bus;
});
