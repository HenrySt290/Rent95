# Rent95 network layer

Centralized Dio client with:

- **JWT auth** (`AuthInterceptor`) — bearer header attached from `TokenStorage`.
- **Silent token refresh** (`TokenRefreshInterceptor`) — on 401, refreshes and
  retries the original request. Concurrent 401s coalesce into a single refresh.
  Emits `AuthEvent.forceLogout` when the refresh token itself is dead.
- **Idempotent retries** (`RetryInterceptor`) — exponential backoff with jitter
  for network errors and 5xx. Only retries GET/HEAD/OPTIONS by default.
- **Typed errors** (`ErrorMappingInterceptor`) — every `DioException` carries a
  domain-specific `AppException` in `err.error`.
- **Traceability** (`RequestIdInterceptor`) — unique `X-Request-Id` per call,
  plus opt-in `Idempotency-Key` header.
- **Structured logging** (`LoggingInterceptor`) — redacts auth headers and
  sensitive body fields, dev-only by default.

## Usage

```dart
final dio = ref.watch(apiClientProvider);

final response = await dio.get<Map<String, dynamic>>('/api/products');
```

### Making a POST idempotent

For calls that must not double-charge or double-book (bookings, payments):

```dart
await dio.post(
  '/api/orders',
  data: body,
  options: Options(extra: {RequestIdInterceptor.idempotencyKey: uuid.v4()}),
);
```

The server persists the key in `payments.idempotency_key` and returns the
existing record on retry.

### Opting a POST into retries

Not recommended by default, but if you have a POST that is truly safe to retry:

```dart
await dio.post(
  '/api/webhooks/ping',
  options: Options(extra: {RetryInterceptor.retryable: true}),
);
```

### Opting a GET out of retries

For polling endpoints where you want to see failures immediately:

```dart
await dio.get(
  '/api/live/status',
  options: Options(extra: {RetryInterceptor.noRetry: true}),
);
```

### Auth-free requests

For calls that must not send a bearer token (rare):

```dart
await dio.get('/public/manifest.json', options: Options(extra: {
  AuthInterceptor.skipAuth: true,
  TokenRefreshInterceptor.skipRefresh: true,
}));
```

## Decoding responses

The backend wraps everything as `{success, data, pagination?}`. Use the helpers:

```dart
import 'package:rent95/core/network/api_envelope.dart';

final listings = await dio
    .get('/api/products')
    .then((r) => decodeList(r, Listing.fromJson));

final one = await dio
    .get('/api/products/$id')
    .then((r) => decodeObject(r, Listing.fromJson));
```

## Interceptor order

Dio runs request interceptors top-to-bottom and response/error interceptors
bottom-to-top. `ApiClient.create` installs them in the following order so
that behavior is correct:

```
Request:   RequestId → Auth → TokenRefresh → Retry → ErrorMapping → Logging
Response:  Logging ← ErrorMapping ← Retry ← TokenRefresh ← Auth ← RequestId
```

`TokenRefreshInterceptor` sits **before** `ErrorMappingInterceptor` in the
error path so a 401 gets a chance to be refreshed before being wrapped in a
typed `UnauthorizedException`.

## Testing

See `test/network_interceptors_test.dart`. Uses a fake `HttpClientAdapter`
that intercepts calls at the transport layer without any real network.

The `TokenRefreshInterceptor` accepts an optional `refreshDio` for injecting
a test-friendly refresh HTTP client:

```dart
TokenRefreshInterceptor(
  storage: storage,
  events: bus,
  baseUrl: 'https://api.test',
  refreshDio: refreshDio, // uses the same stub adapter in tests
);
```
