import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
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
/// **Chaos behavior** (per SRE audit item #2 — mid-upload network dropout):
/// If an in-flight upload fails, the tile transitions to a `Failed — tap
/// to retry` state **preserving the local file path**. The parent form's
/// [TextEditingController]s (title, description, price, etc.) are never
/// touched by this widget, so a failure inside PhotoUploaderGrid never
/// wipes the user's typed input. A tapped retry re-runs the upload against
/// the same picked local file — no re-pick required.
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

/// A single active-or-failed upload entry. Kept keyed by localPath in a Map
/// so parallel uploads (grid + drag-drop batches) each animate independently.
class _UploadEntry {
  _UploadEntry({required this.localPath})
      : progress = 0,
        failed = false,
        errorMessage = null;

  final String localPath;
  double progress;
  bool failed;
  String? errorMessage;
}

class _PhotoUploaderGridState extends ConsumerState<PhotoUploaderGrid> {
  /// Local, in-flight OR failed uploads keyed by the temp path. Failed
  /// entries stay in the map so the tile can render `Failed — tap to retry`
  /// without losing the picked file.
  final Map<String, _UploadEntry> _entries = <String, _UploadEntry>{};
  String? _pickerError;

  /// Only in-flight (not-yet-failed) entries count toward the cap so a
  /// user can retry a failed upload without hitting the ceiling.
  int get _activeCount => _entries.values.where((e) => !e.failed).length;

  bool get _atCap =>
      widget.urls.length + _activeCount >= widget.maxImages;

  Future<void> _pickAndUpload(ImageSource source) async {
    setState(() => _pickerError = null);
    String? pickedPath;
    try {
      final picker = ref.read(imagePickerServiceProvider);
      final picked = await picker.pickAndCrop(source: source);
      if (picked == null) return;
      pickedPath = picked.path;

      setState(() => _entries[picked.path] = _UploadEntry(localPath: picked.path));
      await _runUpload(picked.path);
    } on StateError catch (e) {
      // Size guard from ImagePickerService — this is a picker-side error,
      // not an upload retry candidate. Show inline.
      if (!mounted) return;
      setState(() {
        if (pickedPath != null) _entries.remove(pickedPath);
        _pickerError = e.message;
      });
    }
  }

  /// The actual upload attempt — separated so a `retry` on a failed tile
  /// reuses the same code path.
  Future<void> _runUpload(String path) async {
    final entry = _entries[path];
    if (entry == null) return;

    // Reset transient failure flags but KEEP the file path.
    setState(() {
      entry.failed = false;
      entry.errorMessage = null;
      entry.progress = 0;
    });

    try {
      final uploaded = await ref.read(uploadRepositoryProvider).uploadFile(
            purpose: widget.purpose,
            filePath: path,
            onProgress: (p) {
              if (!mounted) return;
              setState(() => entry.progress = p.fraction);
            },
          );

      if (!mounted) return;
      // Scoped removal — only clear THIS upload's ghost tile (audit R5).
      setState(() => _entries.remove(path));
      widget.onChange([...widget.urls, uploaded.secureUrl]);
    } on NetworkException catch (e) {
      // Explicit dropout / timeout / connectionError case.
      // KEEP the entry so the tile can show retry state.
      if (!mounted) return;
      setState(() {
        entry.failed = true;
        entry.errorMessage =
            'No connection. Tap to retry — your photo is saved locally.';
        // Non-null but non-null-safe check: log for observability.
        _lastError = e;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        entry.failed = true;
        entry.errorMessage = e.message.isEmpty
            ? 'Upload failed. Tap to retry.'
            : '${e.message}. Tap to retry.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        entry.failed = true;
        entry.errorMessage = 'Upload failed. Tap to retry.';
      });
    }
  }

  // Kept for potential telemetry hook; assigning is deliberately unused.
  // ignore: unused_field
  Object? _lastError;

  void _remove(int index) {
    final next = List<String>.from(widget.urls)..removeAt(index);
    widget.onChange(next);
  }

  void _cancelFailed(String path) {
    setState(() => _entries.remove(path));
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
    final failedCount = _entries.values.where((e) => e.failed).length;
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
            for (final entry in _entries.values)
              if (entry.failed)
                _FailedTile(
                  localPath: entry.localPath,
                  message: entry.errorMessage ?? 'Failed — tap to retry',
                  onRetry: () => _runUpload(entry.localPath),
                  onCancel: () => _cancelFailed(entry.localPath),
                )
              else
                _UploadingTile(
                  localPath: entry.localPath,
                  progress: entry.progress,
                ),
            if (!_atCap) _AddTile(onTap: _openPickerSheet),
          ],
        ),
        if (_pickerError != null) ...[
          const SizedBox(height: 8),
          Text(_pickerError!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12)),
        ],
        const SizedBox(height: 4),
        Text(
          '${widget.urls.length}/${widget.maxImages} photos'
          '${_activeCount > 0 ? ' · $_activeCount uploading' : ''}'
          '${failedCount > 0 ? ' · $failedCount failed' : ''}',
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
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  builder: (_, v, __) => CircularProgressIndicator(
                    value: v <= 0 ? null : v,
                    strokeWidth: 3,
                    color: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailedTile extends StatelessWidget {
  const _FailedTile({
    required this.localPath,
    required this.message,
    required this.onRetry,
    required this.onCancel,
  });
  final String localPath;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    Widget bg;
    try {
      bg = Image.file(File(localPath), fit: BoxFit.cover);
    } catch (_) {
      bg = Container(color: AppColors.border);
    }
    return Tooltip(
      message: message,
      child: SizedBox(
        width: 88,
        height: 88,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Opacity(opacity: 0.35, child: bg),
              ),
            ),
            Positioned.fill(
              child: InkWell(
                onTap: onRetry,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.danger, width: 1.2),
                    color: Colors.black.withValues(alpha: 0.15),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh, color: Colors.white, size: 22),
                      SizedBox(height: 2),
                      Text(
                        'Retry',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: InkWell(
                onTap: onCancel,
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        ),
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
