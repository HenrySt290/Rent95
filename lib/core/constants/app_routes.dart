/// Static route paths used by go_router. Kept as string constants so they can
/// be referenced from anywhere without importing router.dart.
class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String verifyOtp = '/verify-otp';
  static const String forgotPassword = '/forgot-password';

  // Bottom-nav roots
  static const String home = '/home';
  static const String search = '/search';
  static const String createListing = '/create-listing';
  static const String messages = '/messages';
  static const String profile = '/profile';

  // Listings
  static const String listingDetail = '/listing/:id';
  static String listingDetailFor(String id) => '/listing/$id';

  static const String editListing = '/listing/:id/edit';

  // Booking / orders
  static const String bookingRequest = '/listing/:id/book';
  static String bookingRequestFor(String id) => '/listing/$id/book';

  static const String checkout = '/checkout/:orderId';
  static String checkoutFor(String orderId) => '/checkout/$orderId';

  static const String orderDetail = '/orders/:id';
  static String orderDetailFor(String id) => '/orders/$id';

  static const String buyerOrders = '/my/orders';
  static const String savedListings = '/my/saved';

  // Seller
  static const String sellerDashboard = '/seller';
  static const String sellerListings = '/seller/listings';
  static const String sellerRequests = '/seller/requests';
  static const String sellerRevenue = '/seller/revenue';
  static const String sellerAvailability = '/seller/availability';

  // Chat
  static const String chatDetail = '/messages/:conversationId';
  static String chatDetailFor(String id) => '/messages/$id';

  // Misc
  static const String notifications = '/notifications';
  static const String settings = '/profile/settings';
  static const String reviews = '/profile/reviews';
}
