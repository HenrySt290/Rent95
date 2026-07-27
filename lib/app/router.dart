import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_routes.dart';
import '../core/widgets/app_shell.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/onboarding_screen.dart';
import '../features/auth/presentation/otp_verify_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/booking/presentation/booking_request_screen.dart';
import '../features/booking/presentation/checkout_screen.dart';
import '../features/chat/presentation/chat_screens.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/listings/presentation/create_listing_screen.dart';
import '../features/listings/presentation/listing_detail_screen.dart';
import '../features/listings/presentation/saved_listings_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/orders/presentation/orders_screens.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/seller_dashboard/presentation/seller_dashboard_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: _AuthChangeNotifier(ref),
    redirect: (context, state) {
      if (!auth.initialized) return null;

      final loc = state.matchedLocation;
      final loggedIn = auth.isAuthenticated;
      final onPublic = loc == AppRoutes.splash ||
          loc == AppRoutes.onboarding ||
          loc == AppRoutes.login ||
          loc == AppRoutes.register ||
          loc == AppRoutes.verifyOtp ||
          loc == AppRoutes.forgotPassword;

      if (!loggedIn && !onPublic) return AppRoutes.onboarding;
      if (loggedIn && loc == AppRoutes.splash) return AppRoutes.home;
      if (loggedIn && (loc == AppRoutes.onboarding || loc == AppRoutes.login || loc == AppRoutes.register)) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.onboarding, builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (_, __) => const RegisterScreen()),
      GoRoute(path: AppRoutes.verifyOtp, builder: (_, __) => const OtpVerifyScreen()),
      GoRoute(path: AppRoutes.forgotPassword, builder: (_, __) => const ForgotPasswordScreen()),

      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: AppRoutes.home, builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: AppRoutes.search,
            builder: (_, state) => SearchScreen(
              initialCategoryId: state.uri.queryParameters['category'],
            ),
          ),
          GoRoute(path: AppRoutes.createListing, builder: (_, __) => const CreateListingScreen()),
          GoRoute(path: AppRoutes.messages, builder: (_, __) => const ChatListScreen()),
          GoRoute(path: AppRoutes.profile, builder: (_, __) => const ProfileScreen()),
        ],
      ),

      GoRoute(
        path: AppRoutes.listingDetail,
        builder: (_, state) => ListingDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.bookingRequest,
        builder: (_, state) => BookingRequestScreen(listingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        builder: (_, state) => CheckoutScreen(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(
        path: AppRoutes.orderDetail,
        builder: (_, state) => OrderDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: AppRoutes.buyerOrders, builder: (_, __) => const OrderListScreen()),
      GoRoute(path: AppRoutes.savedListings, builder: (_, __) => const SavedListingsScreen()),
      GoRoute(path: AppRoutes.sellerDashboard, builder: (_, __) => const SellerDashboardScreen()),
      GoRoute(
        path: AppRoutes.chatDetail,
        builder: (_, state) =>
            ChatDetailScreen(conversationId: state.pathParameters['conversationId']!),
      ),
      GoRoute(path: AppRoutes.notifications, builder: (_, __) => const NotificationsScreen()),
    ],
    errorBuilder: (_, state) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
});

/// Bridges Riverpod auth state → GoRouter refresh so redirects re-run on login/logout.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}
