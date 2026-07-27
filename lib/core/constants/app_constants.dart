class AppConstants {
  const AppConstants._();

  static const String appName = 'Rent95';
  static const String appTagline = 'Rent, buy, and book anything.';

  // Pagination
  static const int defaultPageSize = 20;

  // Media
  static const int maxListingImages = 8;
  static const int maxImageBytes = 5 * 1024 * 1024; // 5 MB

  // Reviews
  static const int minRating = 1;
  static const int maxRating = 5;

  // Bookings
  static const Duration paymentLockDuration = Duration(minutes: 15);
  static const Duration sellerResponseSla = Duration(hours: 24);

  // Support
  static const String supportEmail = 'support@rent95.dev';
  static const String privacyUrl = 'https://rent95.dev/privacy';
  static const String termsUrl = 'https://rent95.dev/terms';
}
