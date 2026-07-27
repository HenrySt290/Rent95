import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';
import '../models/listing.dart';
import '../models/message.dart';
import '../models/notification.dart';
import '../models/order.dart';
import '../models/review.dart';
import '../models/user.dart';

/// A single in-memory store that all mock repositories read from.
///
/// Swapped out at the repository boundary once the real API is live —
/// see `Env.useMocks` and each feature's `*_repository.dart`.
class MockStore {
  MockStore._();
  static final MockStore instance = MockStore._();

  final categories = <Category>[
    const Category(
      id: 'cat_real_estate',
      name: 'Real Estate',
      slug: 'real-estate',
      allowedModes: ['rent', 'sale'],
      iconName: 'apartment',
    ),
    const Category(
      id: 'cat_vehicles',
      name: 'Vehicles',
      slug: 'vehicles',
      allowedModes: ['rent', 'sale'],
      iconName: 'directions_car',
    ),
    const Category(
      id: 'cat_equipment',
      name: 'Equipment',
      slug: 'equipment',
      allowedModes: ['rent', 'sale'],
      iconName: 'build',
    ),
    const Category(
      id: 'cat_electronics',
      name: 'Electronics',
      slug: 'electronics',
      allowedModes: ['rent', 'sale'],
      iconName: 'devices',
    ),
    const Category(
      id: 'cat_services',
      name: 'Services',
      slug: 'services',
      allowedModes: ['service'],
      iconName: 'handyman',
    ),
    const Category(
      id: 'cat_fashion',
      name: 'Fashion',
      slug: 'fashion',
      allowedModes: ['rent', 'sale'],
      iconName: 'checkroom',
    ),
    const Category(
      id: 'cat_sports',
      name: 'Sports',
      slug: 'sports',
      allowedModes: ['rent', 'sale'],
      iconName: 'sports_soccer',
    ),
    const Category(
      id: 'cat_furniture',
      name: 'Furniture',
      slug: 'furniture',
      allowedModes: ['rent', 'sale'],
      iconName: 'chair',
    ),
    const Category(
      id: 'cat_events',
      name: 'Events',
      slug: 'events',
      allowedModes: ['rent'],
      iconName: 'celebration',
    ),
    const Category(
      id: 'cat_other',
      name: 'Other',
      slug: 'other',
      allowedModes: ['rent', 'sale', 'service'],
      iconName: 'more_horiz',
    ),
  ];

  final listings = <Listing>[
    Listing(
      id: 'lst_001',
      ownerId: 'usr_owner_1',
      ownerName: 'Amir K.',
      title: 'Tesla Model 3 — Long Range',
      description:
          'Well maintained 2022 Tesla Model 3 Long Range. Autopilot enabled, premium interior, '
          'clean and detailed before every rental. Great for weekend trips.',
      categoryId: 'cat_vehicles',
      listingType: ListingType.rent,
      price: 95,
      priceUnit: PriceUnit.day,
      securityDeposit: 300,
      currency: 'USD',
      images: const [
        'https://images.unsplash.com/photo-1553260168-69b041873e65?w=1200',
        'https://images.unsplash.com/photo-1560958089-b8a1929cea89?w=1200',
      ],
      location: const ListingLocation(city: 'Brooklyn', country: 'USA', state: 'NY'),
      customAttributes: const {
        'Make': 'Tesla',
        'Model': 'Model 3',
        'Year': 2022,
        'Seats': 5,
        'Transmission': 'Automatic',
      },
      ratingAverage: 4.9,
      reviewCount: 34,
      deliveryOptions: const ['pickup', 'delivery'],
    ),
    Listing(
      id: 'lst_002',
      ownerId: 'usr_owner_2',
      ownerName: 'Priya S.',
      title: 'Cozy Studio in Williamsburg',
      description:
          'Sunny, quiet studio apartment steps from the L train. Fully furnished, high-speed '
          'Wi-Fi, and a small balcony. Minimum stay 7 nights.',
      categoryId: 'cat_real_estate',
      listingType: ListingType.rent,
      price: 140,
      priceUnit: PriceUnit.day,
      securityDeposit: 500,
      currency: 'USD',
      images: const [
        'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=1200',
        'https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=1200',
      ],
      location: const ListingLocation(city: 'Brooklyn', country: 'USA', state: 'NY'),
      customAttributes: const {
        'Bedrooms': 0,
        'Bathrooms': 1,
        'Furnished': true,
        'Property Type': 'Studio',
      },
      ratingAverage: 4.7,
      reviewCount: 21,
    ),
    Listing(
      id: 'lst_003',
      ownerId: 'usr_owner_3',
      ownerName: 'Rent95 Pro Rentals',
      title: 'Canon EOS R5 + 24-70mm Lens',
      description:
          'Full-frame mirrorless camera with the RF 24-70mm f/2.8 lens. Includes 2 batteries, '
          '128GB CFexpress card, and a hard case. Perfect for weddings and pro shoots.',
      categoryId: 'cat_equipment',
      listingType: ListingType.hybrid,
      price: 65,
      priceUnit: PriceUnit.day,
      securityDeposit: 800,
      currency: 'USD',
      images: const [
        'https://images.unsplash.com/photo-1502920917128-1aa500764cbd?w=1200',
      ],
      location: const ListingLocation(city: 'Manhattan', country: 'USA', state: 'NY'),
      customAttributes: const {
        'Brand': 'Canon',
        'Condition': 'Like new',
        'Includes': 'Body + 24-70mm f/2.8 + 2 batteries',
      },
      ratingAverage: 5.0,
      reviewCount: 12,
    ),
    Listing(
      id: 'lst_004',
      ownerId: 'usr_owner_4',
      ownerName: 'James O.',
      title: 'MacBook Pro 16" M3 Max — 64GB RAM',
      description:
          'Rent-to-try or buy. Barely used MacBook Pro 16-inch with the M3 Max chip. Great for '
          'video editing, 3D, and AI dev work.',
      categoryId: 'cat_electronics',
      listingType: ListingType.hybrid,
      price: 3200,
      priceUnit: PriceUnit.fixed,
      securityDeposit: 0,
      currency: 'USD',
      images: const [
        'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=1200',
      ],
      location: const ListingLocation(city: 'Jersey City', country: 'USA', state: 'NJ'),
      customAttributes: const {
        'Brand': 'Apple',
        'Storage': '2 TB',
        'Warranty': 'AppleCare+ until 2026',
        'Condition': 'Like new',
      },
      ratingAverage: 4.8,
      reviewCount: 9,
    ),
    Listing(
      id: 'lst_005',
      ownerId: 'usr_owner_5',
      ownerName: 'CleanRight NYC',
      title: 'Deep Clean — 2-Bedroom Apartment',
      description:
          'Insured professional cleaning team. Includes kitchen deep clean, bathrooms, all '
          'floors, windows (interior), and appliances. 3-hour appointment.',
      categoryId: 'cat_services',
      listingType: ListingType.service,
      price: 160,
      priceUnit: PriceUnit.fixed,
      currency: 'USD',
      images: const [
        'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=1200',
      ],
      location: const ListingLocation(city: 'Queens', country: 'USA', state: 'NY'),
      customAttributes: const {
        'Duration': '3 hours',
        'Service Area': '10 mi radius',
        'Provider Type': 'Insured team of 2',
      },
      ratingAverage: 4.6,
      reviewCount: 58,
    ),
    Listing(
      id: 'lst_006',
      ownerId: 'usr_owner_6',
      ownerName: 'Sofia R.',
      title: 'Designer Evening Dress — Size M',
      description:
          'Stunning full-length evening dress by a top designer. Rent for a night, dry-cleaned '
          'between rentals. Optional matching clutch.',
      categoryId: 'cat_fashion',
      listingType: ListingType.rent,
      price: 55,
      priceUnit: PriceUnit.day,
      securityDeposit: 150,
      currency: 'USD',
      images: const [
        'https://images.unsplash.com/photo-1490481651871-ab68de25d43d?w=1200',
      ],
      location: const ListingLocation(city: 'Manhattan', country: 'USA', state: 'NY'),
      customAttributes: const {
        'Size': 'M',
        'Color': 'Emerald',
        'Occasion': 'Formal / Gala',
      },
      ratingAverage: 4.9,
      reviewCount: 17,
    ),
  ];

  final favorites = <String>{};

  final orders = <Order>[
    Order(
      id: 'ord_001',
      orderNumber: 'R95-1001',
      buyerId: 'usr_me',
      sellerId: 'usr_owner_1',
      productId: 'lst_001',
      productTitle: 'Tesla Model 3 — Long Range',
      productImage: 'https://images.unsplash.com/photo-1553260168-69b041873e65?w=600',
      orderType: OrderType.rental,
      status: OrderStatus.active,
      startDate: DateTime.now().subtract(const Duration(days: 1)),
      endDate: DateTime.now().add(const Duration(days: 2)),
      subtotal: 285,
      platformFee: 28.50,
      taxAmount: 22.80,
      securityDeposit: 300,
      totalAmount: 636.30,
      currency: 'USD',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      buyerName: 'You',
      sellerName: 'Amir K.',
    ),
  ];

  final conversations = <Conversation>[
    Conversation(
      id: 'conv_001',
      buyerId: 'usr_me',
      sellerId: 'usr_owner_1',
      otherUserName: 'Amir K.',
      productId: 'lst_001',
      orderId: 'ord_001',
      lastMessage: 'The car is parked out front, keys in the lockbox 🚗',
      updatedAt: DateTime.now().subtract(const Duration(minutes: 12)),
      unreadCount: 1,
    ),
    Conversation(
      id: 'conv_002',
      buyerId: 'usr_me',
      sellerId: 'usr_owner_3',
      otherUserName: 'Rent95 Pro Rentals',
      productId: 'lst_003',
      lastMessage: 'Do you have the R5 available next weekend?',
      updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];

  final messages = <String, List<ChatMessage>>{
    'conv_001': [
      ChatMessage(
        id: 'm1',
        conversationId: 'conv_001',
        senderId: 'usr_owner_1',
        type: MessageType.text,
        content: 'Hey! Confirmed your booking for tomorrow.',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        isRead: true,
      ),
      ChatMessage(
        id: 'm2',
        conversationId: 'conv_001',
        senderId: 'usr_me',
        type: MessageType.text,
        content: 'Thanks! What time can I pick it up?',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        isRead: true,
      ),
      ChatMessage(
        id: 'm3',
        conversationId: 'conv_001',
        senderId: 'usr_owner_1',
        type: MessageType.text,
        content: 'The car is parked out front, keys in the lockbox 🚗',
        createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
      ),
    ],
  };

  final notifications = <AppNotification>[
    AppNotification(
      id: 'n1',
      title: 'Booking confirmed',
      body: 'Amir accepted your rental request for the Tesla Model 3.',
      type: AppNotificationType.bookingAccepted,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      entityId: 'ord_001',
    ),
    AppNotification(
      id: 'n2',
      title: 'New message',
      body: 'Amir K.: The car is parked out front, keys in the lockbox.',
      type: AppNotificationType.messageReceived,
      createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
      entityId: 'conv_001',
      isRead: false,
    ),
    AppNotification(
      id: 'n3',
      title: 'Listing approved',
      body: 'Your listing "Canon EOS R5" was approved and is now live.',
      type: AppNotificationType.listingApproved,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  final reviews = <Review>[
    Review(
      id: 'rev1',
      orderId: 'ord_prev1',
      productId: 'lst_001',
      reviewerId: 'usr_buyer_x',
      reviewerName: 'Kenji A.',
      revieweeId: 'usr_owner_1',
      rating: 5,
      comment: 'Great car, super clean and Amir was easy to work with.',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    Review(
      id: 'rev2',
      orderId: 'ord_prev2',
      productId: 'lst_001',
      reviewerId: 'usr_buyer_y',
      reviewerName: 'Lena M.',
      revieweeId: 'usr_owner_1',
      rating: 4,
      comment: 'Nice ride! Handoff took a few extra minutes but no issues.',
      createdAt: DateTime.now().subtract(const Duration(days: 12)),
    ),
  ];

  final AppUser currentUser = const AppUser(
    id: 'usr_me',
    fullName: 'Alex Rivera',
    email: 'alex@example.com',
    phone: '+1 555 010 2222',
    role: UserRole.seller,
    isEmailVerified: true,
    isPhoneVerified: true,
    kycStatus: KycStatus.approved,
    ratingAverage: 4.8,
    reviewCount: 27,
  );

  String _newId(String prefix) {
    final r = Random();
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${r.nextInt(9999)}';
  }

  // -------- Helper API for repositories --------

  Future<List<Listing>> searchListings({
    String? keyword,
    String? categoryId,
    double? minPrice,
    double? maxPrice,
    String? city,
    ListingType? listingType,
    String sort = 'relevance',
  }) async {
    await _fakeDelay();
    var results = listings.where((l) => l.status == ListingStatus.active).toList();
    if (categoryId != null) {
      results = results.where((l) => l.categoryId == categoryId).toList();
    }
    if (keyword != null && keyword.trim().isNotEmpty) {
      final q = keyword.toLowerCase();
      results = results.where((l) =>
          l.title.toLowerCase().contains(q) ||
          l.description.toLowerCase().contains(q)).toList();
    }
    if (minPrice != null) {
      results = results.where((l) => l.price >= minPrice).toList();
    }
    if (maxPrice != null) {
      results = results.where((l) => l.price <= maxPrice).toList();
    }
    if (city != null && city.trim().isNotEmpty) {
      results = results.where((l) => l.location.city.toLowerCase().contains(city.toLowerCase())).toList();
    }
    if (listingType != null) {
      results = results.where((l) =>
          l.listingType == listingType ||
          l.listingType == ListingType.hybrid).toList();
    }
    switch (sort) {
      case 'price_asc':
        results.sort((a, b) => a.price.compareTo(b.price));
      case 'price_desc':
        results.sort((a, b) => b.price.compareTo(a.price));
      case 'rating':
        results.sort((a, b) => b.ratingAverage.compareTo(a.ratingAverage));
      case 'newest':
        results.sort((a, b) => b.id.compareTo(a.id));
    }
    return results;
  }

  Future<Listing> createListing(Listing draft) async {
    await _fakeDelay();
    final created = Listing(
      id: _newId('lst'),
      ownerId: currentUser.id,
      ownerName: currentUser.fullName,
      title: draft.title,
      description: draft.description,
      categoryId: draft.categoryId,
      subcategoryId: draft.subcategoryId,
      listingType: draft.listingType,
      price: draft.price,
      priceUnit: draft.priceUnit,
      securityDeposit: draft.securityDeposit,
      currency: draft.currency,
      quantity: draft.quantity,
      images: draft.images.isEmpty
          ? const ['https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=800']
          : draft.images,
      location: draft.location,
      customAttributes: draft.customAttributes,
      status: ListingStatus.pending,
      deliveryOptions: draft.deliveryOptions,
    );
    listings.insert(0, created);
    return created;
  }

  Future<Order> createOrder({
    required Listing listing,
    required OrderType type,
    DateTime? start,
    DateTime? end,
    int quantity = 1,
  }) async {
    await _fakeDelay();
    final days = (start != null && end != null)
        ? end.difference(start).inDays.clamp(1, 365)
        : 1;
    final subtotal = listing.priceUnit == PriceUnit.fixed
        ? listing.price * quantity
        : listing.price * days * quantity;
    final fee = subtotal * 0.10;
    final tax = subtotal * 0.08;
    final total = subtotal + fee + tax + listing.securityDeposit;
    final order = Order(
      id: _newId('ord'),
      orderNumber: 'R95-${(1000 + orders.length + 1)}',
      buyerId: currentUser.id,
      sellerId: listing.ownerId,
      productId: listing.id,
      productTitle: listing.title,
      productImage: listing.images.first,
      orderType: type,
      status: OrderStatus.pending,
      quantity: quantity,
      startDate: start,
      endDate: end,
      subtotal: subtotal,
      platformFee: fee,
      taxAmount: tax,
      securityDeposit: listing.securityDeposit,
      totalAmount: total,
      currency: listing.currency,
      createdAt: DateTime.now(),
      buyerName: currentUser.fullName,
      sellerName: listing.ownerName,
    );
    orders.insert(0, order);
    return order;
  }

  Future<Order> updateOrderStatus(String orderId, OrderStatus status) async {
    await _fakeDelay();
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) throw StateError('Order not found');
    final updated = orders[idx].copyWith(status: status);
    orders[idx] = updated;
    return updated;
  }

  Future<ChatMessage> sendMessage(String conversationId, String text) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final msg = ChatMessage(
      id: _newId('msg'),
      conversationId: conversationId,
      senderId: currentUser.id,
      type: MessageType.text,
      content: text,
      createdAt: DateTime.now(),
    );
    messages.putIfAbsent(conversationId, () => []).add(msg);
    final ci = conversations.indexWhere((c) => c.id == conversationId);
    if (ci != -1) {
      final c = conversations[ci];
      conversations[ci] = Conversation(
        id: c.id,
        buyerId: c.buyerId,
        sellerId: c.sellerId,
        otherUserName: c.otherUserName,
        otherUserAvatarUrl: c.otherUserAvatarUrl,
        productId: c.productId,
        orderId: c.orderId,
        lastMessage: text,
        updatedAt: DateTime.now(),
        unreadCount: 0,
      );
    }
    return msg;
  }

  Future<void> _fakeDelay() =>
      Future<void>.delayed(const Duration(milliseconds: 250));
}

final mockStoreProvider = Provider<MockStore>((_) => MockStore.instance);
