import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, Colors;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_constants.dart';

/// Where a picked image lives on-disk, plus lightweight metadata so the UI
/// can enforce max-size before we bother the upload endpoint.
@immutable
class PickedImage {
  const PickedImage({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final int sizeBytes;
}

/// Wraps `image_picker` + `image_cropper`. Kept as its own service so
/// screens don't have to import the plugins directly and tests can inject
/// a fake picker.
class ImagePickerService {
  ImagePickerService({ImagePicker? picker, ImageCropper? cropper})
      : _picker = picker ?? ImagePicker(),
        _cropper = cropper ?? ImageCropper();

  final ImagePicker _picker;
  final ImageCropper _cropper;

  /// Prompts the user to pick from camera or gallery, then opens the crop UI.
  /// Returns `null` if the user cancelled at any stage.
  ///
  /// [maxBytes] is enforced *before* cropping so we don't waste cycles on
  /// something we'll refuse anyway.
  Future<PickedImage?> pickAndCrop({
    ImageSource source = ImageSource.gallery,
    int maxBytes = AppConstants.maxImageBytes,
    double aspectRatioX = 4,
    double aspectRatioY = 3,
  }) async {
    // 1. Pick. `image_picker` handles permission prompts on both platforms.
    final xfile = await _picker.pickImage(
      source: source,
      // Downscale huge camera photos before we ever leave the picker.
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 85,
    );
    if (xfile == null) return null;

    // 2. Size guard (post-downscale). Rare that this trips, but if the user
    // picked a raw HDR photo from the gallery it might.
    final size = await xfile.length();
    if (size > maxBytes) {
      throw StateError('That image is too large. Please pick one under '
          '${(maxBytes / (1024 * 1024)).toStringAsFixed(1)} MB.');
    }

    // 3. Crop. This step is also where iOS shows the "square vs. free"
    // preset toolbar, which we omit for a more predictable listing look.
    final cropped = await _cropper.cropImage(
      sourcePath: xfile.path,
      aspectRatio: CropAspectRatio(ratioX: aspectRatioX, ratioY: aspectRatioY),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 88,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop photo',
          toolbarColor: const Color(0xFF3B49DF),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.ratio4x3,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop photo',
          aspectRatioLockEnabled: true,
        ),
      ],
    );
    if (cropped == null) return null;

    return PickedImage(
      path: cropped.path,
      name: cropped.path.split('/').last,
      sizeBytes: await _fileSize(cropped.path),
    );
  }

  Future<int> _fileSize(String path) async {
    try {
      final f = XFile(path);
      return f.length();
    } catch (_) {
      return 0;
    }
  }
}

final imagePickerServiceProvider = Provider<ImagePickerService>((_) => ImagePickerService());
