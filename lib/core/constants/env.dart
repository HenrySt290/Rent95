// Environment configuration. Values are compile-time via --dart-define.
class Env {
  const Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.rent95.dev',
  );

  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'https://ws.rent95.dev',
  );

  static const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: '',
  );

  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'dev',
  );

  static bool get isProd => environment == 'production';
  static bool get isDev => environment == 'dev';

  /// When true, the app uses in-memory mock repositories so it runs without a backend.
  /// Set with --dart-define=USE_MOCKS=false once your API is live.
  static const bool useMocks = bool.fromEnvironment('USE_MOCKS', defaultValue: true);
}
