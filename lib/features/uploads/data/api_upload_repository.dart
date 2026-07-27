import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/interceptors/auth_interceptor.dart';
import '../../../core/network/interceptors/token_refresh_interceptor.dart';
import 'upload_repository.dart';
import 'upload_types.dart';

/// Real implementation:
///
///   - Signature endpoint uses the app-wide authenticated Dio (`_apiDio`)
///     because it's on our backend.
///
///   - The direct-to-Cloudinary upload uses a **separate**, un-authenticated
///     Dio (`_uploadDio`). Reasons:
///
///       1. We don't want our Bearer JWT leaking to Cloudinary.
///       2. Cloudinary doesn't accept our token anyway — the signature IS
///          the auth.
///       3. `TokenRefreshInterceptor` would misfire on a Cloudinary 401.
///          A separate Dio avoids that whole failure mode.
class ApiUploadRepository implements UploadRepository {
  ApiUploadRepository({required Dio apiDio})
      : _apiDio = apiDio,
        _uploadDio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(seconds: 30),
        ));

  final Dio _apiDio;
  final Dio _uploadDio;

  @override
  Future<UploadSignature> signature(UploadPurpose purpose) async {
    final res = await _apiDio.post<Map<String, dynamic>>(
      '/api/uploads/signature',
      data: {'purpose': purpose.wireName},
    );
    return decodeObject(res, UploadSignature.fromJson);
  }

  @override
  Future<UploadedMedia> upload({
    required UploadSignature signature,
    required String filePath,
    void Function(UploadProgress progress)? onProgress,
  }) async {
    final form = FormData.fromMap(<String, dynamic>{
      'api_key': signature.apiKey,
      'timestamp': signature.timestamp,
      'signature': signature.signature,
      'folder': signature.folder,
      if (signature.publicId != null) 'public_id': signature.publicId,
      // File field name must be `file` — that's Cloudinary's contract.
      'file': await MultipartFile.fromFile(filePath),
    });

    final res = await _uploadDio.post<Map<String, dynamic>>(
      signature.uploadUrl,
      data: form,
      // Explicitly skip our auth chain — this Dio has no interceptors, but
      // the extras are ignored anyway. Left as documentation for readers.
      options: Options(extra: const {
        AuthInterceptor.skipAuth: true,
        TokenRefreshInterceptor.skipRefresh: true,
      }),
      onSendProgress: onProgress == null
          ? null
          : (sent, total) => onProgress(UploadProgress(sent: sent, total: total)),
    );

    final body = res.data;
    if (body == null) {
      throw StateError('Cloudinary returned an empty body');
    }
    return UploadedMedia(
      publicId: body['public_id'] as String,
      secureUrl: body['secure_url'] as String,
      width: (body['width'] as num).toInt(),
      height: (body['height'] as num).toInt(),
      bytes: (body['bytes'] as num).toInt(),
      format: body['format'] as String,
    );
  }

  @override
  Future<UploadedMedia> uploadFile({
    required UploadPurpose purpose,
    required String filePath,
    void Function(UploadProgress progress)? onProgress,
  }) async {
    final sig = await signature(purpose);
    return upload(signature: sig, filePath: filePath, onProgress: onProgress);
  }
}
