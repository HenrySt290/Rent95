import 'package:flutter_test/flutter_test.dart';

import 'package:rent95/core/network/api_mappers.dart';
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
}
