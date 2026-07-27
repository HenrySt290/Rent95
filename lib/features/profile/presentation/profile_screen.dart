import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../shared/components/initial_avatar.dart';
import '../../auth/presentation/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 20),
            Center(
              child: InitialAvatar(
                name: user.fullName,
                imageUrl: user.profileImageUrl,
                radius: 44,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(user.fullName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 4),
            Center(child: Text(user.email, style: const TextStyle(color: AppColors.textSecondary))),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (user.isEmailVerified) _badge('Email verified', Icons.mail),
                if (user.isPhoneVerified) _badge('Phone verified', Icons.phone),
                if (user.role.name == 'seller') _badge('Seller', Icons.storefront),
              ],
            ),
            const SizedBox(height: 24),
            _section('Account', [
              _tile(Icons.shopping_bag_outlined, 'My orders',
                  onTap: () => context.push(AppRoutes.buyerOrders)),
              _tile(Icons.favorite_outline, 'Saved listings',
                  onTap: () => context.push(AppRoutes.savedListings)),
              _tile(Icons.notifications_outlined, 'Notifications',
                  onTap: () => context.push(AppRoutes.notifications)),
              _tile(Icons.star_outline, 'My reviews',
                  onTap: () => context.push(AppRoutes.reviews)),
            ]),
            _section('Selling', [
              _tile(Icons.dashboard_outlined, 'Seller dashboard',
                  onTap: () => context.push(AppRoutes.sellerDashboard)),
              _tile(Icons.add_business_outlined, 'Create a listing',
                  onTap: () => context.go(AppRoutes.createListing)),
            ]),
            _section('Settings', [
              _tile(Icons.settings_outlined, 'Settings',
                  onTap: () => context.push(AppRoutes.settings)),
              _tile(Icons.help_outline, 'Help & support', onTap: () {}),
              _tile(Icons.privacy_tip_outlined, 'Privacy policy', onTap: () {}),
              _tile(Icons.logout, 'Log out',
                  destructive: true,
                  onTap: () async {
                    await ref.read(authControllerProvider.notifier).logout();
                    if (context.mounted) context.go(AppRoutes.onboarding);
                  }),
            ]),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              )),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _tile(IconData icon, String label,
      {VoidCallback? onTap, bool destructive = false}) {
    return ListTile(
      leading: Icon(icon, color: destructive ? AppColors.danger : AppColors.primary),
      title: Text(label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: destructive ? AppColors.danger : AppColors.textPrimary,
          )),
      trailing: destructive ? null : const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}
