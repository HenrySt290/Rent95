import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/network/socket_lifecycle.dart';
import 'core/services/push_registrar.dart';
import 'core/services/push_service.dart';
import 'core/services/stripe_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Stripe SDK — safe no-op if STRIPE_PUBLISHABLE_KEY is unset.
  await StripeService.instance.init();

  // Firebase + FCM — safe no-op if google-services.json / GoogleService-Info.plist
  // aren't in place. See docs/FCM_SETUP.md for the one-time platform config.
  await PushService.instance.init();

  runApp(const ProviderScope(child: _AppBootstrap()));
}

/// Wires up the always-on side-effect providers (socket lifecycle, push
/// registrar) before any screen mounts. Without this, they wouldn't exist
/// until something else `ref.watch`ed them.
class _AppBootstrap extends ConsumerWidget {
  const _AppBootstrap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(socketLifecycleProvider);
    ref.watch(pushRegistrarProvider);
    return const Rent95App();
  }
}
