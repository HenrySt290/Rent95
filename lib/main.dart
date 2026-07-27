import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/network/socket_lifecycle.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Real integrations (Firebase, Stripe, Hive) would be initialised here.
  // Kept optional so the app still runs in mock mode without configuring them.
  //
  // Example (add once your keys and Firebase project are ready):
  //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  //   Stripe.publishableKey = Env.stripePublishableKey;
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
