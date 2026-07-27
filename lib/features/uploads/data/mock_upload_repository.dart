import 'dart:math';

import 'upload_repository.dart';
import 'upload_types.dart';

/// Fake uploader for `USE_MOCKS=true`. Returns a random Unsplash URL after
/// a short delay so create-listing still shows an image, and the progress
/// bar animation still works for the demo.
class MockUploadRepository implements UploadRepository {
  MockUploadRepository();

  final _random = Random();

  @override
  Future<UploadSignature> signature(UploadPurpose purpose) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return UploadSignature(
      signature: 'mock',
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      folder: 'mock/${purpose.wireName}',
      apiKey: 'mock',
      cloudName: 'mock',
      uploadUrl: 'https://mock.local/upload',
    );
  }

  @override
  Future<UploadedMedia> upload({
    required UploadSignature signature,
    required String filePath,
    void Function(UploadProgress progress)? onProgress,
  }) async {
    // Simulate progress in 5 ticks so a spinner/progress bar has something
    // to animate against.
    for (var i = 1; i <= 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      onProgress?.call(UploadProgress(sent: i * 20, total: 100));
    }
    final seed = _random.nextInt(10_000);
    return UploadedMedia(
      publicId: 'mock/${signature.folder}/$seed',
      secureUrl: 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=1200&sig=$seed',
      width: 1200,
      height: 800,
      bytes: 250_000,
      format: 'jpg',
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
