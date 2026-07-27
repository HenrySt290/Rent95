import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/image_picker_service.dart';
import '../../features/uploads/data/upload_providers.dart';
import '../../features/uploads/data/upload_types.dart';

/// A composable photo picker + uploader.
///
/// Given a list of already-uploaded image URLs (via [urls]) it renders each
/// as a thumbnail; the trailing tile is a "+" button that:
///   1. opens the platform picker
///   2. crops to 4:3
///   3. requests a signed URL from our backend
///   4. uploads directly to Cloudinary with progress
///   5. calls [onChange] with the new list of remote URLs
///
/// Errors and progress are rendered inline on the tile so the parent
/// screen doesn't have to wire snackbars for each upload.
class PhotoUploaderGrid extends ConsumerStatefulWidget {
  const PhotoUploaderGrid({
    super.key,
    required this.urls,
    required this.onChange,
    this.purpose = UploadPurpose.listing,
    this.maxImages = AppConstants.maxListingImages,
  });

  final List<String> urls;
  final ValueChanged<List<String>> onChange;
  final UploadPurpose purpose;
  final int maxImages;

  @override
  ConsumerState<PhotoUploaderGrid> createState() => _PhotoUploaderGridState();
}

class _PhotoUploaderGridState extends ConsumerState<PhotoUploaderGrid> {
  /// Local, in-flight uploads keyed by the temp path so we can render them
  /// alongside the already-uploaded URLs. Removed once the upload resolves.
  final Map<String, double> _inFlight = <String, double>{};
  String? _error;

  bool get _atCap =>
      widget.urls.length + _inFlight.length >= widget.maxImages;

  Future<void> _pickAndUpload(ImageSource source) async {
    setState(() => _error = null);
    try {
      final picker = ref.read(imagePickerServiceProvider);
      final picked = await picker.pickAndCrop(source: source);
      if (picked == null) return;

      setState(() => _inFlight[picked.path] = 0);

      final uploaded = await ref
          .read(uploadRepositoryProvider)
          .uploadFile(
            purpose: widget.purpose,
            filePath: picked.path,
            onProgress: (p) {
              if (!mounted) return;
              setState(() => _inFlight[picked.path] = p.fraction);
            },
          );

      if (!mounted) return;
      setState(() => _inFlight.remove(picked.path));
      widget.onChange([...widget.urls, uploaded.secureUrl]);
    } on StateError catch (e) {
      // From the size guard in ImagePickerService.
      setState(() => _error = e.message);
    } catch (e) {
      setState(() {
        _error = 'Upload failed: $e';
        // Any lingering ghost thumbnail clears on error too.
        _inFlight.clear();
      });
    }
  }

  void _remove(int index) {
    final next = List<String>.from(widget.urls)..removeAt(index);
    widget.onChange(next);
  }

  Future<void> _openPickerSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickAndUpload(source);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < widget.urls.length; i++)
              _ThumbnailTile(
                imageUrl: widget.urls[i],
                onRemove: () => _remove(i),
              ),
            for (final entry in _inFlight.entries)
              _UploadingTile(localPath: entry.key, progress: entry.value),
            if (!_atCap) _AddTile(onTap: _openPickerSheet),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
        ],
        const SizedBox(height: 4),
        Text(
          '${widget.urls.length}/${widget.maxImages} photos'
          '${_inFlight.isNotEmpty ? ' · ${_inFlight.length} uploading' : ''}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _ThumbnailTile extends StatelessWidget {
  const _ThumbnailTile({required this.imageUrl, required this.onRemove});
  final String imageUrl;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.network(imageUrl, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadingTile extends StatelessWidget {
  const _UploadingTile({required this.localPath, required this.progress});
  final String localPath;
  final double progress;

  @override
  Widget build(BuildContext context) {
    // We can show the local file as a background so the user sees WHICH
    // photo is uploading. Wrapped in a try/catch since File() can throw
    // synchronously on some platforms.
    Widget bg;
    try {
      bg = Image.file(File(localPath), fit: BoxFit.cover);
    } catch (_) {
      bg = Container(color: AppColors.border);
    }
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Opacity(opacity: 0.6, child: bg),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary),
            SizedBox(height: 4),
            Text('Add photo',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
