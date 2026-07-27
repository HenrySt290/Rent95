import 'package:dio/dio.dart';

/// Matches the API's response envelope:
/// ```
/// { "success": true, "data": ..., "pagination"?: {...} }
/// ```
class ApiEnvelope<T> {
  const ApiEnvelope({
    required this.data,
    this.pagination,
  });

  final T data;
  final Pagination? pagination;

  static ApiEnvelope<T> from<T>(
    Response<dynamic> response,
    T Function(Object? raw) decode,
  ) {
    final body = response.data;
    if (body is Map<String, dynamic>) {
      final raw = body['data'];
      final pagRaw = body['pagination'];
      return ApiEnvelope<T>(
        data: decode(raw),
        pagination: pagRaw is Map<String, dynamic>
            ? Pagination.fromJson(pagRaw)
            : null,
      );
    }
    // Fallback: server didn't wrap the payload — decode the whole body.
    return ApiEnvelope<T>(data: decode(body));
  }
}

class Pagination {
  const Pagination({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  bool get hasMore => page < totalPages;

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
        totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      );
}

/// Helper for feature code:
/// ```dart
/// final products = await dio.get('/api/products').then(
///   (r) => decodeList(r, Listing.fromJson),
/// );
/// ```
List<T> decodeList<T>(Response<dynamic> response, T Function(Map<String, dynamic>) fromJson) {
  final env = ApiEnvelope.from<List<dynamic>>(response, (raw) => (raw as List<dynamic>?) ?? const []);
  return env.data
      .map((e) => fromJson((e as Map).cast<String, dynamic>()))
      .toList(growable: false);
}

T decodeObject<T>(Response<dynamic> response, T Function(Map<String, dynamic>) fromJson) {
  final env = ApiEnvelope.from<Map<String, dynamic>>(
    response,
    (raw) => (raw is Map ? raw.cast<String, dynamic>() : <String, dynamic>{}),
  );
  return fromJson(env.data);
}
