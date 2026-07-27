import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for access + refresh tokens.
///
/// Uses `flutter_secure_storage`, which is backed by:
/// - iOS: Keychain
/// - Android: EncryptedSharedPreferences (Keystore)
/// - macOS / Linux / Windows / Web: platform-specific secure backends
///
/// Reads are cheap (memory + platform channel), but they *do* cross the
/// platform boundary. Interceptors call `readAccessToken` on every request,
/// so we cache the last-known values in memory to avoid the round-trip cost
/// on hot paths. Cache is invalidated on every write.
class TokenStorage {
  TokenStorage(this._storage);
  final FlutterSecureStorage _storage;

  static const _accessKey = 'rent95.access_token';
  static const _refreshKey = 'rent95.refresh_token';

  String? _cachedAccess;
  String? _cachedRefresh;
  bool _bootstrapped = false;
  Completer<void>? _bootstrapCompleter;

  /// Load tokens from secure storage into the in-memory cache. Idempotent.
  Future<void> _ensureBootstrapped() async {
    if (_bootstrapped) return;
    // Coalesce concurrent boot calls.
    if (_bootstrapCompleter != null) {
      await _bootstrapCompleter!.future;
      return;
    }
    _bootstrapCompleter = Completer<void>();
    try {
      _cachedAccess = await _storage.read(key: _accessKey);
      _cachedRefresh = await _storage.read(key: _refreshKey);
      _bootstrapped = true;
      _bootstrapCompleter!.complete();
    } catch (e, st) {
      _bootstrapCompleter!.completeError(e, st);
      _bootstrapCompleter = null;
      rethrow;
    }
  }

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _ensureBootstrapped();
    _cachedAccess = accessToken;
    await _storage.write(key: _accessKey, value: accessToken);
    if (refreshToken != null) {
      _cachedRefresh = refreshToken;
      await _storage.write(key: _refreshKey, value: refreshToken);
    }
  }

  Future<void> saveAccessToken(String accessToken) async {
    await _ensureBootstrapped();
    _cachedAccess = accessToken;
    await _storage.write(key: _accessKey, value: accessToken);
  }

  Future<String?> readAccessToken() async {
    await _ensureBootstrapped();
    return _cachedAccess;
  }

  Future<String?> readRefreshToken() async {
    await _ensureBootstrapped();
    return _cachedRefresh;
  }

  Future<bool> hasTokens() async {
    await _ensureBootstrapped();
    return (_cachedAccess?.isNotEmpty ?? false) &&
        (_cachedRefresh?.isNotEmpty ?? false);
  }

  Future<void> clear() async {
    _cachedAccess = null;
    _cachedRefresh = null;
    _bootstrapped = true;
    await Future.wait<void>([
      _storage.delete(key: _accessKey),
      _storage.delete(key: _refreshKey),
    ]);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(
    const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  );
});
