import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../constants/app_routes.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  static const _tabs = [
    _Tab(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home', path: AppRoutes.home),
    _Tab(icon: Icons.search, activeIcon: Icons.search, label: 'Search', path: AppRoutes.search),
    _Tab(icon: Icons.add_box_outlined, activeIcon: Icons.add_box, label: 'Sell', path: AppRoutes.createListing),
    _Tab(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'Messages', path: AppRoutes.messages),
    _Tab(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile', path: AppRoutes.profile),
  ];

  int _indexFor(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _indexFor(location);
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => context.go(_tabs[i].path),
        items: [
          for (final t in _tabs)
            BottomNavigationBarItem(
              icon: Icon(t.icon),
              activeIcon: Icon(t.activeIcon, color: AppColors.primary),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

class _Tab {
  const _Tab({required this.icon, required this.activeIcon, required this.label, required this.path});
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
}
