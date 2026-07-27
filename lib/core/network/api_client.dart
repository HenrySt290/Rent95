import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/env.dart';
import '../storage/token_storage.dart';
import 'auth_event_bus.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_mapping_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/request_id_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'interceptors/token_refresh_interceptor.dart';

/// Centralized Dio client for Rent95.
///
/// ### Interceptor order matters
///
/// Dio calls request interceptors in the order they're added, and response/
/// error interceptors in **reverse** order. We install them so that:
///
/// ```
/// Request path:  RequestId → Auth → Logging → (network)
/// Response path: (network) → Logging → TokenRefresh → Retry → ErrorMapping
/// ```
///
/// That ordering matters because:
///
/// 1. **TokenRefreshInterceptor must run before ErrorMappingInterceptor** on
///    error — otherwise the 401 gets wrapped in an `UnauthorizedException`
///    before we ever get a chance to refresh and retry.
///
/// 2. **RetryInterceptor must run between refresh and error mapping** so that
///    if the refresh succeeded and the retry *still* fails, it gets one more
///    chance under the retry policy — and only after all that do we surface
///    the typed [AppException] to feature code.
///
/// 3. **RequestId + Auth run first on request** so every outgoing call —
///    including refresh-retries — carries a fresh trace id and the correct
///    Authorization header.
class ApiClient {
  /// Build a fully-configured Dio instance.
  ///
  /// [enableLogging] defaults to `Env.isDev` — flip explicitly if you want
  /// noisy logs in a specific test.
  static Dio create({
    required TokenStorage storage,
    required AuthEventBus events,
    bool? enableLogging,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        // Don't throw on 4xx — we want interceptors to see the response so
        // ErrorMappingInterceptor can produce nice typed errors.
        validateStatus: (status) => status != null && status >= 200 && status < 300,
      ),
    );

    // Order: request-side runs top-to-bottom; response/error-side runs
    // bottom-to-top. See class docs above.
    dio.interceptors.addAll([
      RequestIdInterceptor(),
      AuthInterceptor(storage),
      TokenRefreshInterceptor(
        storage: storage,
        events: events,
        baseUrl: Env.apiBaseUrl,
      ),
      RetryInterceptor(dio: dio),
      ErrorMappingInterceptor(),
      if (enableLogging ?? Env.isDev) LoggingInterceptor(),
    ]);

    return dio;
  }
}

// -----------------------------------------------------------------------------
// Riverpod providers
// -----------------------------------------------------------------------------

/// The one-and-only Dio the whole app should use. Feature repositories depend
/// on this. Kept as a plain `Provider` (not autoDispose) so the connection
/// pool lives across screens.
final apiClientProvider = Provider<Dio>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  final events = ref.watch(authEventBusProvider);
  final dio = ApiClient.create(storage: storage, events: events);
  ref.onDispose(() => dio.close(force: true));
  return dio;
});
