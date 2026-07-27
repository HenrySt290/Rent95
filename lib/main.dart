import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/network/socket_lifecycle.dart';
import 'core/services/stripe_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Stripe SDK — safe to call unconditionally. If STRIPE_PUBLISHABLE_KEY is
  // unset (mock mode) it's a friendly no-op and the checkout screen will
  // surface a "not configured" message if the user reaches it.
  await StripeService.instance.init();

  // Real integrations left as clearly-marked TODOs:
  //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  //   await Hive.initFlutter();

  runApp(const ProviderScope(child: _AppBootstrap()));
}

/// Tiny wrapper widget whose only job is to spin up the [socketLifecycleProvider]
/// so it starts watching auth state *before* any screen mounts. Without this,
/// the socket controller wouldn't exist until something else `ref.watch`ed it.
class _AppBootstrap extends ConsumerWidget {
  const _AppBootstrap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(socketLifecycleProvider);
    return const Rent95App();
  }
}
