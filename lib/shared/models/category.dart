import 'package:flutter/foundation.dart';

@immutable
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.slug,
    required this.allowedModes,
    this.iconName = 'category',
    this.parentId,
    this.description,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String slug;
  final List<String> allowedModes; // rent | sale | service | hybrid
  final String iconName;
  final String? parentId;
  final String? description;
  final int sortOrder;
  final bool isActive;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        allowedModes: List<String>.from(json['allowedModes'] as List? ?? const []),
        iconName: json['iconName'] as String? ?? 'category',
        parentId: json['parentId'] as String?,
        description: json['description'] as String?,
        sortOrder: json['sortOrder'] as int? ?? 0,
        isActive: json['isActive'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'allowedModes': allowedModes,
        'iconName': iconName,
        'parentId': parentId,
      };
}
