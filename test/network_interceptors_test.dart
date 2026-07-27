import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rent95/core/errors/app_exception.dart';
import 'package:rent95/core/network/auth_event_bus.dart';
import 'package:rent95/core/network/interceptors/auth_interceptor.dart';
import 'package:rent95/core/network/interceptors/error_mapping_interceptor.dart';
import 'package:rent95/core/network/interceptors/request_id_interceptor.dart';
import 'package:rent95/core/network/interceptors/retry_interceptor.dart';
import 'package:rent95/core/network/interceptors/token_refresh_interceptor.dart';
import 'package:rent95/core/storage/token_storage.dart';

/// In-memory TokenStorage double.
///
/// We `implement` (not `extend`) the concrete class so we don't need a
/// `FlutterSecureStorage` at construction time. Only public members need to
/// be provided; the private cache fields on the real class are library-private
/// and therefore not part of the implicit interface.
class _FakeTokenStorage implements TokenStorage {
  _FakeTokenStorage({String? access, String? refresh})
      : _access = access,
        _refresh = refresh;

  String? _access;
  String? _refresh;

  @override
  Future<String?> readAccessToken() async => _access;
  @override
  Future<String?> readRefreshToken() async => _refresh;
  @override
  Future<bool> hasTokens() async => _access != null && _refresh != null;
  @override
  Future<void> saveTokens({required String accessToken, String? refreshToken}) async {
    _access = accessToken;
    if (refreshToken != null) _refresh = refreshToken;
  }
  @override
  Future<void> saveAccessToken(String accessToken) async {
    _access = accessToken;
  }
  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}

/// Records every call and lets the test decide the response per call.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions opts, int callIndex) handler;
  final List<RequestOptions> calls = [];
  int _idx = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    return handler(options, _idx++);
  }
}

ResponseBody _json(int status, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    _jsonEncode(body),
    status,
    headers: {'content-type': ['application/json']},
  );
}

String _jsonEncode(Object? v) {
  if (v == null) return 'null';
  if (v is String) return '"${v.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  if (v is num || v is bool) return '$v';
  if (v is List) return '[${v.map(_jsonEncode).join(',')}]';
  if (v is Map) {
    return '{${v.entries.map((e) => '"${e.key}":${_jsonEncode(e.value)}').join(',')}}';
  }
  return '"$v"';
}

Dio _newDio() => Dio(
      BaseOptions(
        baseUrl: 'https://api.test',
        validateStatus: (s) => s != null && s >= 200 && s < 300,
      ),
    );

void main() {
  group('AuthInterceptor', () {
    test('attaches Bearer token from storage', () async {
      final dio = _newDio()..interceptors.add(AuthInterceptor(_FakeTokenStorage(access: 'abc')));
      final adapter = _StubAdapter((_, __) async => _json(200, {'success': true, 'data': null}));
      dio.httpClientAdapter = adapter;

      await dio.get<dynamic>('/api/products');
      expect(adapter.calls.single.headers['Authorization'], 'Bearer abc');
    });

    test('skips header when skipAuth flag is set', () async {
      final dio = _newDio()..interceptors.add(AuthInterceptor(_FakeTokenStorage(access: 'abc')));
      final adapter = _StubAdapter((_, __) async => _json(200, {'success': true}));
      dio.httpClientAdapter = adapter;

      await dio.get<dynamic>(
        '/api/products',
        options: Options(extra: {AuthInterceptor.skipAuth: true}),
      );
      expect(adapter.calls.single.headers['Authorization'], isNull);
    });
  });

  group('RequestIdInterceptor', () {
    test('adds X-Request-Id header', () async {
      final dio = _newDio()..interceptors.add(RequestIdInterceptor());
      final adapter = _StubAdapter((_, __) async => _json(200, {}));
      dio.httpClientAdapter = adapter;

      await dio.get<dynamic>('/foo');
      final id = adapter.calls.single.headers['X-Request-Id'];
      expect(id, isA<String>());
      expect((id as String).length, greaterThan(10));
    });

    test('propagates Idempotency-Key from extra', () async {
      final dio = _newDio()..interceptors.add(RequestIdInterceptor());
      final adapter = _StubAdapter((_, __) async => _json(200, {}));
      dio.httpClientAdapter = adapter;

      await dio.post<dynamic>(
        '/orders',
        data: {'productId': 'x'},
        options: Options(extra: {RequestIdInterceptor.idempotencyKey: 'idem-123'}),
      );
      expect(adapter.calls.single.headers['Idempotency-Key'], 'idem-123');
    });
  });

  group('ErrorMappingInterceptor', () {
    test('maps 401 → UnauthorizedException', () async {
      final dio = _newDio()..interceptors.add(ErrorMappingInterceptor());
      dio.httpClientAdapter = _StubAdapter((_, __) async => _json(401, {'message': 'nope'}));

      try {
        await dio.get<dynamic>('/x');
        fail('expected throw');
      } on DioException catch (e) {
        expect(e.error, isA<UnauthorizedException>());
      }
    });

    test('maps 422 → ValidationException with field errors', () async {
      final dio = _newDio()..interceptors.add(ErrorMappingInterceptor());
      dio.httpClientAdapter = _StubAdapter((_, __) async => _json(422, {
            'message': 'Validation failed',
            'errors': {
              'email': ['is required'],
              'password': ['too short'],
            },
          }));

      try {
        await dio.post<dynamic>('/x', data: {});
        fail('expected throw');
      } on DioException catch (e) {
        expect(e.error, isA<ValidationException>());
        final v = e.error! as ValidationException;
        expect(v.fields!['email'], 'is required');
        expect(v.fields!['password'], 'too short');
      }
    });

    test('maps 5xx → ServerException', () async {
      final dio = _newDio()..interceptors.add(ErrorMappingInterceptor());
      dio.httpClientAdapter = _StubAdapter((_, __) async => _json(503, {'message': 'try later'}));

      try {
        await dio.get<dynamic>('/x');
        fail('expected throw');
      } on DioException catch (e) {
        expect(e.error, isA<ServerException>());
      }
    });
  });

  group('RetryInterceptor', () {
    test('retries GET on 503 up to maxRetries then gives up', () async {
      final dio = _newDio();
      dio.interceptors.add(RetryInterceptor(dio: dio, maxRetries: 2, baseDelay: Duration.zero));
      final adapter = _StubAdapter((_, __) async => _json(503, {'message': 'nope'}));
      dio.httpClientAdapter = adapter;

      try {
        await dio.get<dynamic>('/x');
      } on DioException catch (_) {}

      expect(adapter.calls.length, 3, reason: '1 initial + 2 retries');
    });

    test('does not retry POST by default', () async {
      final dio = _newDio();
      dio.interceptors.add(RetryInterceptor(dio: dio, baseDelay: Duration.zero));
      final adapter = _StubAdapter((_, __) async => _json(503, {}));
      dio.httpClientAdapter = adapter;

      try {
        await dio.post<dynamic>('/x');
      } on DioException catch (_) {}
      expect(adapter.calls.length, 1);
    });

    test('retries POST when retryable flag is set', () async {
      final dio = _newDio();
      dio.interceptors.add(RetryInterceptor(dio: dio, maxRetries: 1, baseDelay: Duration.zero));
      final adapter = _StubAdapter((_, __) async => _json(502, {}));
      dio.httpClientAdapter = adapter;

      try {
        await dio.post<dynamic>(
          '/x',
          options: Options(extra: {RetryInterceptor.retryable: true}),
        );
      } on DioException catch (_) {}
      expect(adapter.calls.length, 2);
    });

    test('opts out with noRetry flag', () async {
      final dio = _newDio();
      dio.interceptors.add(RetryInterceptor(dio: dio, baseDelay: Duration.zero));
      final adapter = _StubAdapter((_, __) async => _json(503, {}));
      dio.httpClientAdapter = adapter;

      try {
        await dio.get<dynamic>(
          '/x',
          options: Options(extra: {RetryInterceptor.noRetry: true}),
        );
      } on DioException catch (_) {}
      expect(adapter.calls.length, 1);
    });

    test('recovers when a later attempt succeeds', () async {
      final dio = _newDio();
      dio.interceptors.add(RetryInterceptor(dio: dio, baseDelay: Duration.zero));
      final adapter = _StubAdapter(
        (_, i) async => i < 1 ? _json(503, {}) : _json(200, {'ok': true}),
      );
      dio.httpClientAdapter = adapter;

      final r = await dio.get<dynamic>('/x');
      expect(r.statusCode, 200);
      expect(adapter.calls.length, 2);
    });
  });

  group('TokenRefreshInterceptor', () {
    /// Wire everything so *both* the outer Dio and the internal refresh Dio
    /// share the same stub adapter — that's how we can assert end-to-end that
    /// the interceptor refreshes, retries, and hands back the fresh response.
    ({Dio dio, _StubAdapter adapter, AuthEventBus bus, _FakeTokenStorage storage}) _wire({
      required Future<ResponseBody> Function(RequestOptions, int) handler,
      String? access = 'old',
      String? refresh = 'r1',
    }) {
      final storage = _FakeTokenStorage(access: access, refresh: refresh);
      final bus = AuthEventBus();
      final adapter = _StubAdapter(handler);

      final refreshDio = _newDio()..httpClientAdapter = adapter;

      final dio = _newDio()..httpClientAdapter = adapter;
      dio.interceptors.addAll([
        AuthInterceptor(storage),
        TokenRefreshInterceptor(
          storage: storage,
          events: bus,
          baseUrl: 'https://api.test',
          refreshDio: refreshDio,
        ),
      ]);
      return (dio: dio, adapter: adapter, bus: bus, storage: storage);
    }

    test('refreshes on 401 and retries the original request', () async {
      final w = _wire(handler: (opts, i) async {
        if (opts.path.contains('refresh-token')) {
          return _json(200, {
            'success': true,
            'data': {'accessToken': 'new-access', 'refreshToken': 'new-refresh'},
          });
        }
        final authHeader = opts.headers['Authorization'];
        if (authHeader == 'Bearer new-access') {
          return _json(200, {'success': true, 'data': {'hello': 'world'}});
        }
        return _json(401, {'message': 'expired'});
      });

      final r = await w.dio.get<dynamic>('/api/data');
      expect(r.statusCode, 200);
      expect(await w.storage.readAccessToken(), 'new-access');
      expect(await w.storage.readRefreshToken(), 'new-refresh');

      final paths = w.adapter.calls.map((c) => c.path).toList();
      expect(paths.where((p) => p.contains('/api/data')).length, 2,
          reason: 'the original request should be tried twice: before and after refresh');
      expect(paths.where((p) => p.contains('refresh-token')).length, 1);
    });

    test('coalesces concurrent 401s into a single refresh (single-flight)', () async {
      var refreshCount = 0;
      final w = _wire(handler: (opts, i) async {
        if (opts.path.contains('refresh-token')) {
          refreshCount++;
          // Add a tiny delay so 2 outer calls both hit the refresh path.
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return _json(200, {
            'success': true,
            'data': {'accessToken': 'new-access', 'refreshToken': 'r2'},
          });
        }
        final authHeader = opts.headers['Authorization'];
        if (authHeader == 'Bearer new-access') {
          return _json(200, {'success': true, 'data': null});
        }
        return _json(401, {});
      });

      final results = await Future.wait<Response<dynamic>>([
        w.dio.get<dynamic>('/api/a'),
        w.dio.get<dynamic>('/api/b'),
        w.dio.get<dynamic>('/api/c'),
      ]);

      expect(results.every((r) => r.statusCode == 200), true);
      expect(refreshCount, 1, reason: 'only one /refresh-token call for concurrent 401s');
    });

    test('emits forceLogout when refresh token is missing', () async {
      final w = _wire(
        handler: (opts, i) async => _json(401, {'message': 'expired'}),
        refresh: null,
      );

      final events = <AuthEvent>[];
      final sub = w.bus.stream.listen(events.add);
      addTearDown(sub.cancel);

      try {
        await w.dio.get<dynamic>('/api/data');
      } on DioException catch (_) {}

      // Give the async refresh path a beat to finish.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(events, contains(AuthEvent.forceLogout));
      expect(await w.storage.readAccessToken(), isNull);
    });

    test('emits forceLogout when refresh endpoint returns 401', () async {
      final w = _wire(handler: (opts, i) async {
        if (opts.path.contains('refresh-token')) {
          return _json(401, {'message': 'refresh token invalid'});
        }
        return _json(401, {'message': 'expired'});
      });

      final events = <AuthEvent>[];
      final sub = w.bus.stream.listen(events.add);
      addTearDown(sub.cancel);

      try {
        await w.dio.get<dynamic>('/api/data');
      } on DioException catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(events, contains(AuthEvent.forceLogout));
      expect(await w.storage.readAccessToken(), isNull);
    });

    test('does not attempt refresh for auth endpoints', () async {
      final w = _wire(handler: (_, __) async => _json(401, {'message': 'bad creds'}));

      try {
        await w.dio.post<dynamic>('/api/auth/login', data: {'email': 'a', 'password': 'b'});
      } on DioException catch (_) {}

      // Only the login call itself — no refresh attempt.
      expect(w.adapter.calls.map((c) => c.path).toList(), ['/api/auth/login']);
    });

    test('does not retry indefinitely — a second 401 gives up', () async {
      final w = _wire(handler: (opts, i) async {
        if (opts.path.contains('refresh-token')) {
          return _json(200, {
            'success': true,
            'data': {'accessToken': 'new-access'},
          });
        }
        return _json(401, {'message': 'still expired'});
      });

      try {
        await w.dio.get<dynamic>('/api/data');
        fail('expected throw');
      } on DioException catch (_) {}

      // 1 initial 401, 1 refresh, 1 retry that also 401s = 3 calls.
      expect(w.adapter.calls.length, 3);
    });
  });
}
