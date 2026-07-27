import 'upload_types.dart';

/// Data source for direct-to-Cloudinary media uploads.
///
/// Two-step flow:
///
///   1. `signature(purpose)` — ask our backend for a short-lived signed
///      Cloudinary URL + signature. The backend does the API-secret HMAC
///      because we don't want the secret on-device.
///
///   2. `upload(...)` — POST the file bytes directly to Cloudinary using
///      those credentials. The file **never touches our server**, which
///      saves bandwidth and gives the client a real progress bar.
///
/// See `docs/UPLOADS_SETUP.md` for the platform config (Android/iOS
/// permissions, iOS Info.plist keys, Cloudinary account setup).
abstract class UploadRepository {
  /// Ask the backend to sign an upload. Cheap — safe to call once per file.
  Future<UploadSignature> signature(UploadPurpose purpose);

  /// Perform the multipart POST to Cloudinary. Reports progress via
  /// [onProgress] so the UI can show a per-file percentage.
  Future<UploadedMedia> upload({
    required UploadSignature signature,
    required String filePath,
    void Function(UploadProgress progress)? onProgress,
  });

  /// Convenience: one-shot signature + upload.
  Future<UploadedMedia> uploadFile({
    required UploadPurpose purpose,
    required String filePath,
    void Function(UploadProgress progress)? onProgress,
  });
}
