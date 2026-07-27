// Safe JSON coercion helpers.
//
// Rent95 talks to a Prisma-shaped backend today, a Cloudinary CDN for media,
// and (post-launch) potentially third-party affiliate feeds. Any of those
// upstreams can, in principle, ship us garbage: a compromised proxy could
// inject a String where a bool belongs, a negative price where a positive
// one must be, or a 400 KB nested array that ArgumentError-explodes deep in
// our tree.
//
// The rule everywhere in this file: NEVER throw for shape mismatch. Return
// the caller's default. Let a `fromJson` skip a corrupted field instead of
// aborting the entire response — one bad row must not brick a whole feed.
//
// This is coupled with `listingsFromEnvelope`, which now wraps each record
// in its own try/catch so a single poisoned item is dropped, not the list.

import 'dart:developer' as developer;

/// Coerce to non-null String, dropping to [fallback] on any shape mismatch.
String asString(Object? v, {String fallback = ''}) {
  if (v is String) return v;
  if (v == null) return fallback;
  // Numbers/bools sometimes leak through JSON casts; stringify defensively.
  return v.toString();
}

/// Coerce to nullable String, returning null for empty/missing/non-string.
String? asStringOrNull(Object? v) {
  if (v is String) return v.isEmpty ? null : v;
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

/// Coerce to double. Negative values are clamped to [minValue] (default 0)
/// so a compromised feed can never inject a negative price.
double asDouble(
  Object? v, {
  double fallback = 0,
  double minValue = 0,
  double maxValue = 1e12,
}) {
  double n;
  if (v is num) {
    n = v.toDouble();
  } else if (v is String) {
    n = double.tryParse(v) ?? fallback;
  } else {
    n = fallback;
  }
  if (n.isNaN || n.isInfinite) return fallback;
  if (n < minValue) return minValue;
  if (n > maxValue) return maxValue;
  return n;
}

/// Coerce to int with the same clamping semantics as [asDouble].
int asInt(
  Object? v, {
  int fallback = 0,
  int minValue = 0,
  int maxValue = 1 << 31,
}) {
  int n;
  if (v is int) {
    n = v;
  } else if (v is num) {
    n = v.toInt();
  } else if (v is String) {
    n = int.tryParse(v) ?? fallback;
  } else {
    n = fallback;
  }
  if (n < minValue) return minValue;
  if (n > maxValue) return maxValue;
  return n;
}

/// Coerce to bool. Accepts native bool, 0/1, and 'true'/'false' strings.
/// Anything else falls back — never throws.
bool asBool(Object? v, {bool fallback = false}) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase().trim();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
  }
  return fallback;
}

/// Coerce to `Map<String, dynamic>`, returning an empty map on mismatch.
Map<String, dynamic> asMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.cast<String, dynamic>();
  return const <String, dynamic>{};
}

/// Coerce to `Map<String, dynamic>?`, returning null on mismatch.
Map<String, dynamic>? asMapOrNull(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.cast<String, dynamic>();
  return null;
}

/// Coerce to `List<dynamic>`, hard-capped at [maxLength] elements so a
/// hostile server can't stall the UI with a 1M-element nested array.
List<dynamic> asList(Object? v, {int maxLength = 500}) {
  if (v is! List) return const <dynamic>[];
  if (v.length <= maxLength) return v;
  developer.log(
    'asList: capped list at $maxLength (was ${v.length})',
    name: 'safe_json',
  );
  return v.take(maxLength).toList(growable: false);
}

/// Map every element of a JSON list to [T], DROPPING any element whose
/// mapper throws. Returns the successfully-mapped elements only.
///
/// This is the load-bearing safety net: a single corrupted record inside
/// a paginated feed no longer poisons the whole page.
List<T> mapListSafely<T>(
  Object? raw,
  T Function(Map<String, dynamic>) mapper, {
  int maxLength = 500,
  String context = '',
}) {
  final list = asList(raw, maxLength: maxLength);
  final out = <T>[];
  for (var i = 0; i < list.length; i++) {
    final el = list[i];
    if (el is! Map) continue;
    try {
      out.add(mapper(el.cast<String, dynamic>()));
    } catch (e, st) {
      // One bad row must not brick the list. Log for triage and move on.
      developer.log(
        'mapListSafely: dropped element $i${context.isEmpty ? '' : ' in $context'} — $e',
        name: 'safe_json',
        stackTrace: st,
        level: 900, // WARNING
      );
    }
  }
  return out;
}

/// Coerce to `List<String>`, silently dropping non-string entries and
/// capping length. Used for tag arrays, URL arrays, etc.
List<String> asStringList(Object? v, {int maxLength = 100}) {
  final list = asList(v, maxLength: maxLength);
  return list.whereType<String>().toList(growable: false);
}
