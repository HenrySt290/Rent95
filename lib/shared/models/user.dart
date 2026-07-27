import 'package:flutter/foundation.dart';

/// Role a user can hold. Kept as an enum so we can switch on it exhaustively.
enum UserRole { buyer, seller, admin, moderator, support }

UserRole userRoleFromString(String v) => UserRole.values.firstWhere(
      (e) => e.name == v,
      orElse: () => UserRole.buyer,
    );

enum KycStatus { notSubmitted, pending, approved, rejected }

@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.profileImageUrl,
    this.role = UserRole.buyer,
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
    this.kycStatus = KycStatus.notSubmitted,
    this.ratingAverage = 0,
    this.reviewCount = 0,
    this.defaultCurrency = 'USD',
    this.language = 'en',
    this.createdAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? profileImageUrl;
  final UserRole role;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final KycStatus kycStatus;
  final double ratingAverage;
  final int reviewCount;
  final String defaultCurrency;
  final String language;
  final DateTime? createdAt;

  bool get isSeller => role == UserRole.seller;
  bool get isAdmin => role == UserRole.admin;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        fullName: json['fullName'] as String? ?? json['full_name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String?,
        profileImageUrl: json['profileImageUrl'] as String? ?? json['profile_image_url'] as String?,
        role: userRoleFromString(json['role'] as String? ?? 'buyer'),
        isEmailVerified: json['isEmailVerified'] as bool? ?? false,
        isPhoneVerified: json['isPhoneVerified'] as bool? ?? false,
        ratingAverage: (json['ratingAverage'] as num?)?.toDouble() ?? 0,
        reviewCount: json['reviewCount'] as int? ?? 0,
        defaultCurrency: json['defaultCurrency'] as String? ?? 'USD',
        language: json['language'] as String? ?? 'en',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'profileImageUrl': profileImageUrl,
        'role': role.name,
        'isEmailVerified': isEmailVerified,
        'isPhoneVerified': isPhoneVerified,
        'ratingAverage': ratingAverage,
        'reviewCount': reviewCount,
      };

  AppUser copyWith({
    String? fullName,
    String? profileImageUrl,
    UserRole? role,
    bool? isEmailVerified,
    bool? isPhoneVerified,
    KycStatus? kycStatus,
  }) {
    return AppUser(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email,
      phone: phone,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      role: role ?? this.role,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      kycStatus: kycStatus ?? this.kycStatus,
      ratingAverage: ratingAverage,
      reviewCount: reviewCount,
      defaultCurrency: defaultCurrency,
      language: language,
      createdAt: createdAt,
    );
  }
}
