import 'package:flutter/foundation.dart';

enum ListingType { rent, sale, service, hybrid }

ListingType listingTypeFromString(String v) => ListingType.values.firstWhere(
      (e) => e.name == v,
      orElse: () => ListingType.rent,
    );

enum PriceUnit { hour, day, week, month, fixed }

PriceUnit priceUnitFromString(String v) => PriceUnit.values.firstWhere(
      (e) => e.name == v,
      orElse: () => PriceUnit.day,
    );

enum ListingCondition { newItem, likeNew, good, fair, used }

enum ListingStatus { draft, pending, active, rejected, paused, sold, archived }

ListingStatus listingStatusFromString(String v) => ListingStatus.values.firstWhere(
      (e) => e.name == v,
      orElse: () => ListingStatus.pending,
    );

@immutable
class ListingLocation {
  const ListingLocation({
    required this.city,
    required this.country,
    this.address,
    this.state,
    this.postalCode,
    this.latitude,
    this.longitude,
  });

  final String city;
  final String country;
  final String? address;
  final String? state;
  final String? postalCode;
  final double? latitude;
  final double? longitude;

  factory ListingLocation.fromJson(Map<String, dynamic> json) => ListingLocation(
        city: json['city'] as String? ?? '',
        country: json['country'] as String? ?? '',
        address: json['address'] as String?,
        state: json['state'] as String?,
        postalCode: json['postalCode'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'city': city,
        'country': country,
        'address': address,
        'state': state,
        'postalCode': postalCode,
        'latitude': latitude,
        'longitude': longitude,
      };

  String get short => [city, country].where((e) => e.isNotEmpty).join(', ');
}

@immutable
class Listing {
  const Listing({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.listingType,
    required this.price,
    required this.currency,
    required this.images,
    required this.location,
    this.subcategoryId,
    this.ownerAvatarUrl,
    this.priceUnit = PriceUnit.day,
    this.securityDeposit = 0,
    this.quantity = 1,
    this.condition,
    this.customAttributes = const {},
    this.status = ListingStatus.active,
    this.ratingAverage = 0,
    this.reviewCount = 0,
    this.viewCount = 0,
    this.favoriteCount = 0,
    this.deliveryOptions = const ['pickup'],
    this.createdAt,
  });

  final String id;
  final String ownerId;
  final String ownerName;
  final String? ownerAvatarUrl;
  final String title;
  final String description;
  final String categoryId;
  final String? subcategoryId;
  final ListingType listingType;
  final double price;
  final PriceUnit priceUnit;
  final double securityDeposit;
  final String currency;
  final int quantity;
  final ListingCondition? condition;
  final List<String> images;
  final ListingLocation location;
  final Map<String, dynamic> customAttributes;
  final ListingStatus status;
  final double ratingAverage;
  final int reviewCount;
  final int viewCount;
  final int favoriteCount;
  final List<String> deliveryOptions;
  final DateTime? createdAt;

  bool get isRental => listingType == ListingType.rent || listingType == ListingType.hybrid;
  bool get isSale => listingType == ListingType.sale || listingType == ListingType.hybrid;
  bool get isService => listingType == ListingType.service;

  String get priceUnitLabel {
    switch (priceUnit) {
      case PriceUnit.hour:
        return '/hour';
      case PriceUnit.day:
        return '/day';
      case PriceUnit.week:
        return '/week';
      case PriceUnit.month:
        return '/month';
      case PriceUnit.fixed:
        return '';
    }
  }

  factory Listing.fromJson(Map<String, dynamic> json) => Listing(
        id: json['id'] as String,
        ownerId: json['ownerId'] as String,
        ownerName: json['ownerName'] as String? ?? '',
        ownerAvatarUrl: json['ownerAvatarUrl'] as String?,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        categoryId: json['categoryId'] as String,
        subcategoryId: json['subcategoryId'] as String?,
        listingType: listingTypeFromString(json['listingType'] as String? ?? 'rent'),
        price: (json['price'] as num).toDouble(),
        priceUnit: priceUnitFromString(json['priceUnit'] as String? ?? 'day'),
        securityDeposit: (json['securityDeposit'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] as String? ?? 'USD',
        quantity: json['quantity'] as int? ?? 1,
        images: List<String>.from(json['images'] as List? ?? const []),
        location: ListingLocation.fromJson(
          (json['location'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        customAttributes: Map<String, dynamic>.from(
          json['customAttributes'] as Map? ?? const {},
        ),
        status: listingStatusFromString(json['status'] as String? ?? 'active'),
        ratingAverage: (json['ratingAverage'] as num?)?.toDouble() ?? 0,
        reviewCount: json['reviewCount'] as int? ?? 0,
        viewCount: json['viewCount'] as int? ?? 0,
        favoriteCount: json['favoriteCount'] as int? ?? 0,
        deliveryOptions: List<String>.from(json['deliveryOptions'] as List? ?? const ['pickup']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'ownerName': ownerName,
        'title': title,
        'description': description,
        'categoryId': categoryId,
        'subcategoryId': subcategoryId,
        'listingType': listingType.name,
        'price': price,
        'priceUnit': priceUnit.name,
        'securityDeposit': securityDeposit,
        'currency': currency,
        'quantity': quantity,
        'images': images,
        'location': location.toJson(),
        'customAttributes': customAttributes,
        'status': status.name,
        'ratingAverage': ratingAverage,
        'reviewCount': reviewCount,
        'deliveryOptions': deliveryOptions,
      };
}
