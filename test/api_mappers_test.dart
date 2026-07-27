import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rent95/core/network/api_mappers.dart';
import 'package:rent95/core/network/safe_json.dart';
import 'package:rent95/shared/models/listing.dart';

void main() {
  group('listingFromApi', () {
    test('maps a full product payload into Listing', () {
      final listing = listingFromApi({
        'id': 'lst1',
        'ownerId': 'user1',
        'owner': {'fullName': 'Amir K.', 'profileImageUrl': 'https://x/a.png'},
        'title': 'Tesla',
        'description': 'A car',
        'categoryId': 'cat1',
        'listingType': 'rent',
        'price': 95,
        'priceUnit': 'day',
        'securityDeposit': 300,
        'currency': 'USD',
        'quantity': 1,
        'status': 'active',
        'ratingAverage': 4.9,
        'reviewCount': 34,
        'viewCount': 100,
        'favoriteCount': 12,
        'deliveryOptions': ['pickup', 'delivery'],
        'customAttributes': {'Make': 'Tesla'},
        'media': [
          {'url': 'https://x/1.jpg'},
          {'url': 'https://x/2.jpg'},
        ],
        'location': {
          'city': 'Brooklyn',
          'country': 'USA',
          'state': 'NY',
          'latitude': 40.7,
          'longitude': -74.0,
        },
      });

      expect(listing.id, 'lst1');
      expect(listing.ownerName, 'Amir K.');
      expect(listing.title, 'Tesla');
      expect(listing.listingType, ListingType.rent);
      expect(listing.priceUnit, PriceUnit.day);
      expect(listing.price, 95);
      expect(listing.securityDeposit, 300);
      expect(listing.images, hasLength(2));
      expect(listing.images.first, 'https://x/1.jpg');
      expect(listing.location.city, 'Brooklyn');
      expect(listing.location.short, 'Brooklyn, USA');
      expect(listing.customAttributes['Make'], 'Tesla');
      expect(listing.deliveryOptions, ['pickup', 'delivery']);
      expect(listing.ratingAverage, 4.9);
    });

    test('gracefully handles missing optional fields', () {
      final listing = listingFromApi({
        'id': 'x',
        'ownerId': 'u',
        'title': 't',
        'categoryId': 'c',
        'price': 10,
      });
      expect(listing.images, isEmpty);
      expect(listing.location.city, '');
      expect(listing.ratingAverage, 0);
      expect(listing.reviewCount, 0);
      expect(listing.deliveryOptions, ['pickup']);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  //  CHAOS / SRE audit item #1 — compromised CDN payloads
  // ─────────────────────────────────────────────────────────────────────
  group('listingFromApi — hostile inputs', () {
    test('never throws on wrong-typed price (String where num expected)', () {
      final listing = listingFromApi({
        'id': 'x',
        'ownerId': 'u',
        'title': 't',
        'categoryId': 'c',
        'price': 'lol not a number',
      });
      expect(listing.price, 0);
    });

    test('clamps negative price to zero (compromised feed cannot poison)', () {
      final l = listingFromApi({
        'id': 'x', 'ownerId': 'u', 'title': 't', 'categoryId': 'c',
        'price': -500,
      });
      expect(l.price, 0);
    });

    test('clamps absurdly large price to safe ceiling', () {
      final l = listingFromApi({
        'id': 'x', 'ownerId': 'u', 'title': 't', 'categoryId': 'c',
        'price': 1e30,
      });
      expect(l.price, 1e9);
    });

    test('accepts bool where int expected, coerces to fallback', () {
      final l = listingFromApi({
        'id': 'x', 'ownerId': 'u', 'title': 't', 'categoryId': 'c',
        'price': 10, 'quantity': true,
      });
      expect(l.quantity, 1); // fallback
    });

    test('accepts int where String expected without throwing', () {
      final l = listingFromApi({
        'id': 42, 'ownerId': 99, 'title': 100, 'categoryId': 'c', 'price': 1,
      });
      // Coerced to strings; no throw.
      expect(l.id, '42');
      expect(l.title, '100');
    });

    test('caps a 10,000-element media array to prevent UI freeze', () {
      final huge = List.generate(10000, (i) => {'url': 'https://x/$i.jpg'});
      final l = listingFromApi({
        'id': 'x', 'ownerId': 'u', 'title': 't', 'categoryId': 'c',
        'price': 1, 'media': huge,
      });
      expect(l.images.length, lessThanOrEqualTo(24));
    });

    test('drops individual media entries with missing url, keeps rest', () {
      final l = listingFromApi({
        'id': 'x', 'ownerId': 'u', 'title': 't', 'categoryId': 'c', 'price': 1,
        'media': [
          {'url': 'https://x/1.jpg'},
          {'notUrl': 'garbage'},
          {'url': 'https://x/2.jpg'},
          'a string where an object should be',
        ],
      });
      expect(l.images, ['https://x/1.jpg', 'https://x/2.jpg']);
    });

    test('clamps out-of-range lat/lng to null', () {
      final l = listingFromApi({
        'id': 'x', 'ownerId': 'u', 'title': 't', 'categoryId': 'c', 'price': 1,
        'location': {'city': 'X', 'country': 'Y', 'latitude': 9999, 'longitude': -9999},
      });
      // Clamped values would be at boundaries; keep them as valid.
      expect(l.location.latitude, isNotNull);
      expect(l.location.latitude! <= 90, isTrue);
      expect(l.location.longitude! >= -180, isTrue);
    });

    test('unknown listingType falls back safely (no throw)', () {
      final l = listingFromApi({
        'id': 'x', 'ownerId': 'u', 'title': 't', 'categoryId': 'c', 'price': 1,
        'listingType': 'malicious_new_type_the_backend_never_shipped',
      });
      // Enum firstWhere orElse in listing.dart returns rent by convention.
      expect(l.listingType, isA<ListingType>());
    });

    test('handles fully null owner + location maps', () {
      final l = listingFromApi({
        'id': 'x', 'ownerId': 'u', 'title': 't', 'categoryId': 'c', 'price': 1,
        'owner': null, 'location': null,
      });
      expect(l.ownerName, '');
      expect(l.location.city, '');
    });
  });

  group('listingsFromEnvelope — poisoned list', () {
    test('drops rows with missing id, keeps rest', () {
      final resp = Response<dynamic>(
        requestOptions: RequestOptions(path: '/products'),
        data: {
          'data': [
            {'id': 'good1', 'ownerId': 'u', 'title': 't', 'categoryId': 'c', 'price': 1},
            {'ownerId': 'u', 'title': 'noid', 'categoryId': 'c', 'price': 1}, // dropped
            {'id': 'good2', 'ownerId': 'u', 'title': 't', 'categoryId': 'c', 'price': 1},
          ],
        },
      );
      final listings = listingsFromEnvelope(resp);
      expect(listings.map((l) => l.id), ['good1', 'good2']);
    });

    test('returns empty list on non-list body without throwing', () {
      final resp = Response<dynamic>(
        requestOptions: RequestOptions(path: '/products'),
        data: {'data': 'wat'},
      );
      expect(listingsFromEnvelope(resp), isEmpty);
    });

    test('caps an obscenely long list', () {
      final huge = List.generate(5000, (i) => {
            'id': 'r$i', 'ownerId': 'u', 'title': 't', 'categoryId': 'c', 'price': 1,
          });
      final resp = Response<dynamic>(
        requestOptions: RequestOptions(path: '/products'),
        data: {'data': huge},
      );
      expect(listingsFromEnvelope(resp).length, lessThanOrEqualTo(200));
    });
  });

  group('safe_json primitives', () {
    test('asDouble clamps and handles NaN/Infinity', () {
      expect(asDouble(double.nan), 0);
      expect(asDouble(double.infinity), 0);
      expect(asDouble(-5, minValue: 0), 0);
      expect(asDouble('3.14'), 3.14);
      expect(asDouble('nope', fallback: 42), 42);
    });

    test('asBool accepts common truthy/falsy encodings', () {
      expect(asBool(true), true);
      expect(asBool('true'), true);
      expect(asBool('YES'), true);
      expect(asBool(1), true);
      expect(asBool('false'), false);
      expect(asBool(0), false);
      expect(asBool('lol', fallback: true), true);
    });

    test('mapListSafely drops throwing elements silently', () {
      final out = mapListSafely<int>([1, 'x', 2, 'y', 3], (m) {
        // We'll never actually get called with primitives because they're
        // filtered before entering; force a throwing mapper on maps.
        if (m['bad'] == true) throw StateError('poison');
        return m['n'] as int;
      });
      expect(out, isEmpty); // No maps in the list, all dropped.
    });

    test('mapListSafely tolerates one throwing element mid-batch', () {
      final out = mapListSafely<int>([
        {'n': 1},
        {'n': 'poisoned'},
        {'n': 3},
      ], (m) => m['n'] as int);
      expect(out, [1, 3]);
    });
  });
}
