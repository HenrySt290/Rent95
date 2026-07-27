import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/network/socket_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/components/empty_state.dart';
import '../../../shared/models/notification.dart';
import '../data/notification_providers.dart';

final _notificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  return ref.watch(notificationRepositoryProvider).list();
});

/// Auto-invalidates the notification list whenever a `notification_received`
/// arrives over the socket, so the inbox is always fresh in real time.
final _notificationsSocketBridge = Provider.autoDispose<void>((ref) {
  final client = ref.watch(socketClientProvider);
  final sub = client.notifications$.listen((_) {
    ref.invalidate(_notificationsProvider);
  });
  ref.onDispose(sub.cancel);
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(_notificationsSocketBridge);
    final async = ref.watch(_notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationRepositoryProvider).markAllRead();
              ref.invalidate(_notificationsProvider);
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? const EmptyStateView(
                icon: Icons.notifications_none,
                title: 'No notifications',
                message: "You're all caught up.",
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(_notificationsProvider);
                  await ref.read(_notificationsProvider.future);
                },
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final n = list[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: Icon(_iconFor(n.type), color: AppColors.primary),
                      ),
                      title: Text(n.title,
                          style: TextStyle(
                            fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                          )),
                      subtitle: Text(n.body),
                      trailing: Text(Formatters.relative(n.createdAt),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      onTap: () {
                        ref.read(notificationRepositoryProvider).markRead(n.id);
                        ref.invalidate(_notificationsProvider);
                      },
                    );
                  },
                ),
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
