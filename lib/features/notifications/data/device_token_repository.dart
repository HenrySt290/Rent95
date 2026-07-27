/// Registers this device's FCM token with the backend so the server can
/// target push notifications to the user.
abstract class DeviceTokenRepository {
  /// Idempotent — the backend upserts on `(token)` and will merge with the
  /// current user id, so re-registering is cheap.
  Future<void> register(String token, {required String platform});

  /// Removes the token server-side so subsequent server pushes don't route to
  /// this device. Called on logout.
  Future<void> revoke(String token);
}
