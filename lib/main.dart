import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Real integrations (Firebase, Stripe, Hive) would be initialised here.
  // Kept optional so the app still runs in mock mode without configuring them.
  //
  // Example (add once your keys and Firebase project are ready):
  //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  //   Stripe.publishableKey = Env.stripePublishableKey;
  //   await Hive.initFlutter();

  runApp(const ProviderScope(child: Rent95App()));
}
