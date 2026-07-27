import 'package:flutter_test/flutter_test.dart';

import 'package:rent95/features/uploads/data/upload_types.dart';

void main() {
  group('UploadSignature.fromJson', () {
    test('parses a full signature payload', () {
      final s = UploadSignature.fromJson({
        'signature': 'abc123',
        'timestamp': 1735312800,
        'folder': 'products/user_1',
        'publicId': 'products/user_1/photo_a',
        'apiKey': '123456789012345',
        'cloudName': 'rent95-prod',
        'uploadUrl': 'https://api.cloudinary.com/v1_1/rent95-prod/image/upload',
      });
      expect(s.signature, 'abc123');
      expect(s.timestamp, 1735312800);
      expect(s.folder, 'products/user_1');
      expect(s.publicId, 'products/user_1/photo_a');
      expect(s.apiKey, '123456789012345');
      expect(s.uploadUrl, contains('rent95-prod'));
    });

    test('tolerates null publicId (backend picks one)', () {
      final s = UploadSignature.fromJson({
        'signature': 'abc',
        'timestamp': 1,
        'folder': 'x',
        'apiKey': 'k',
        'cloudName': 'c',
        'uploadUrl': 'https://x',
      });
      expect(s.publicId, isNull);
    });
  });

  group('UploadedMedia.thumbnailUrl', () {
    test('injects transformation params after /upload/', () {
      const m = UploadedMedia(
        publicId: 'products/user_1/abc',
        secureUrl:
            'https://res.cloudinary.com/rent95/image/upload/v1735312800/products/user_1/abc.jpg',
        width: 1200,
        height: 800,
        bytes: 250_000,
        format: 'jpg',
      );
      final t = m.thumbnailUrl(width: 400);
      expect(
        t,
        'https://res.cloudinary.com/rent95/image/upload/w_400,c_fill,g_auto,f_auto,q_auto/v1735312800/products/user_1/abc.jpg',
      );
    });

    test('returns the original URL when /upload/ is not present', () {
      const m = UploadedMedia(
        publicId: 'x',
        secureUrl: 'https://weird.local/image.jpg',
        width: 100,
        height: 100,
        bytes: 1,
        format: 'jpg',
      );
      expect(m.thumbnailUrl(), 'https://weird.local/image.jpg');
    });

    test('accepts a custom width', () {
      const m = UploadedMedia(
        publicId: 'x',
        secureUrl: 'https://res.cloudinary.com/rent95/image/upload/v1/x.jpg',
        width: 100,
        height: 100,
        bytes: 1,
        format: 'jpg',
      );
      expect(m.thumbnailUrl(width: 200), contains('w_200,'));
      expect(m.thumbnailUrl(width: 800), contains('w_800,'));
    });
  });

  group('UploadPurpose wire names', () {
    test('match the enum expected by the backend', () {
      expect(UploadPurpose.listing.wireName, 'listing');
      expect(UploadPurpose.avatar.wireName, 'avatar');
      expect(UploadPurpose.review.wireName, 'review');
    });
  });

  group('UploadProgress', () {
    test('fraction is sent / total', () {
      expect(const UploadProgress(sent: 50, total: 200).fraction, 0.25);
      expect(const UploadProgress(sent: 200, total: 200).fraction, 1.0);
    });

    test('avoids divide-by-zero when total is 0', () {
      expect(const UploadProgress(sent: 0, total: 0).fraction, 0);
    });
  });
}
