import 'package:flutter/material.dart';

import '../../app/theme.dart';

class CategoryIconMap {
  const CategoryIconMap._();
  static IconData iconFor(String name) {
    switch (name) {
      case 'apartment':
        return Icons.apartment;
      case 'directions_car':
        return Icons.directions_car;
      case 'build':
        return Icons.build;
      case 'devices':
        return Icons.devices;
      case 'handyman':
        return Icons.handyman;
      case 'checkroom':
        return Icons.checkroom;
      case 'sports_soccer':
        return Icons.sports_soccer;
      case 'chair':
        return Icons.chair;
      case 'celebration':
        return Icons.celebration;
      case 'more_horiz':
        return Icons.more_horiz;
      default:
        return Icons.category;
    }
  }
}

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.iconName,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final String iconName;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: 82,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Icon(
              CategoryIconMap.iconFor(iconName),
              color: selected ? Colors.white : AppColors.primary,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
