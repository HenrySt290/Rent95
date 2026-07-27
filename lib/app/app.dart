import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/services/notification_router.dart';
import 'router.dart';
import 'theme.dart';

class Rent95App extends ConsumerWidget {
  const Rent95App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Hand the live GoRouter to the [NotificationRouter] so any push tap
    // that arrived during app boot (or arrives from now on) gets converted
    // into a proper in-app navigation. Attaching from `build` is safe because
    // the operation is idempotent and cheap.
    ref.read(notificationRouterProvider).attach(router);

    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
