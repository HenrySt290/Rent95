/// Types shared between the signature call and the multipart upload.

/// Purpose scope — must match the enum in `uploads.controller.ts`.
enum UploadPurpose { listing, avatar, review }

extension UploadPurposeWire on UploadPurpose {
  String get wireName {
    switch (this) {
      case UploadPurpose.listing:
        return 'listing';
      case UploadPurpose.avatar:
        return 'avatar';
      case UploadPurpose.review:
        return 'review';
    }
  }
}

/// What the signature endpoint returns.
class UploadSignature {
  const UploadSignature({
    required this.signature,
    required this.timestamp,
    required this.folder,
    required this.apiKey,
    required this.cloudName,
    required this.uploadUrl,
    this.publicId,
  });

  final String signature;
  final int timestamp;
  final String folder;
  final String apiKey;
  final String cloudName;
  final String uploadUrl;
  final String? publicId;

  factory UploadSignature.fromJson(Map<String, dynamic> j) => UploadSignature(
        signature: j['signature'] as String,
        timestamp: (j['timestamp'] as num).toInt(),
        folder: j['folder'] as String,
        apiKey: j['apiKey'] as String,
        cloudName: j['cloudName'] as String,
        uploadUrl: j['uploadUrl'] as String,
        publicId: j['publicId'] as String?,
      );
}

/// What Cloudinary returns after a successful upload. Only a handful of
/// fields matter to us; kept minimal to avoid churn if Cloudinary adds
/// new fields (they do so often, always additively).
class UploadedMedia {
  const UploadedMedia({
    required this.publicId,
    required this.secureUrl,
    required this.width,
    required this.height,
    required this.bytes,
    required this.format,
  });

  final String publicId;
  final String secureUrl;
  final int width;
  final int height;
  final int bytes;
  final String format;

  /// Convenience: derive a smaller thumbnail URL via Cloudinary's URL-based
  /// transformation feature. No API call needed — Cloudinary generates the
  /// derivative on the first fetch and CDN-caches it forever.
  ///
  /// `f_auto,q_auto` = best format for the client, auto-quality compression.
  /// `w_400,c_fill,g_auto` = 400px wide, smart crop that keeps faces/subject.
  String thumbnailUrl({int width = 400}) {
    // Splice `w_{width},c_fill,g_auto,f_auto,q_auto` into the URL right
    // after `/upload/`. This is the documented way to build transformations
    // client-side without needing the SDK.
    const marker = '/upload/';
    final i = secureUrl.indexOf(marker);
    if (i == -1) return secureUrl;
    final head = secureUrl.substring(0, i + marker.length);
    final tail = secureUrl.substring(i + marker.length);
    return '${head}w_$width,c_fill,g_auto,f_auto,q_auto/$tail';
  }
}

/// Progress reported during a multipart upload.
class UploadProgress {
  const UploadProgress({required this.sent, required this.total});
  final int sent;
  final int total;
  double get fraction => total > 0 ? sent / total : 0;
}
