import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/components/empty_state.dart';
import '../../../shared/models/notification.dart';
import '../data/notification_providers.dart';

final _notificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  return ref.watch(notificationRepositoryProvider).list();
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_notificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? const EmptyStateView(
                icon: Icons.notifications_none,
                title: 'No notifications',
                message: "You're all caught up.",
              )
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final n = list[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Icon(_iconFor(n.type), color: AppColors.primary),
                    ),
                    title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(n.body),
                    trailing: Text(Formatters.relative(n.createdAt),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    onTap: () {
                      ref.read(notificationRepositoryProvider).markRead(n.id);
                    },
                  );
                },
              ),
      ),
    );
  }

  IconData _iconFor(AppNotificationType t) {
    switch (t) {
      case AppNotificationType.messageReceived:
        return Icons.chat_bubble_outline;
      case AppNotificationType.bookingAccepted:
      case AppNotificationType.bookingRequested:
        return Icons.event_available;
      case AppNotificationType.paymentSuccess:
        return Icons.payment;
      case AppNotificationType.listingApproved:
        return Icons.check_circle_outline;
      case AppNotificationType.reviewReceived:
        return Icons.star_outline;
      default:
        return Icons.notifications;
    }
  }
}
