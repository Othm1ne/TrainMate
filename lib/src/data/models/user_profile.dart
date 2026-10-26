import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const levels = ['Beginner', 'Intermediate', 'Expert'];

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final int age;
  final String location; // auto-detected city (read-only)
  final double? lat;
  final double? lng;
  final int joinedYear;
  final String level; // Beginner | Intermediate | Expert
  final String bio;
  final List<String> sports;
  final List<String> badges; // e.g. ["Verified","Coach"]
  final String? photoPath; // local file path or network URL
  final bool isPremium;
  final List<String> blocked; // uids this user blocked
  final String likesDate; // yyyy-mm-dd of likesCount
  final int likesCount; // likes sent on likesDate
  // Store trust fields (server-managed, see functions/src/store).
  final bool verified; // email + phone + photo/name
  final double? rating;
  final int reviewCount;
  final String? shopId;
  final String? shopStatus; // pending | approved | rejected | suspended
  final bool storeSuspended;

  const UserProfile({
    this.uid = '',
    required this.name,
    this.email = '',
    this.age = 0,
    required this.location,
    this.lat,
    this.lng,
    required this.joinedYear,
    required this.level,
    required this.bio,
    required this.sports,
    required this.badges,
    this.photoPath,
    this.isPremium = false,
    this.blocked = const [],
    this.likesDate = '',
    this.likesCount = 0,
    this.verified = false,
    this.rating,
    this.reviewCount = 0,
    this.shopId,
    this.shopStatus,
    this.storeSuspended = false,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> m) {
    final created = m['createdAt'];
    return UserProfile(
      uid: uid,
      name: m['name'] ?? '',
      email: m['email'] ?? '',
      age: (m['age'] as num?)?.toInt() ?? 0,
      location: m['location'] ?? '',
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
      joinedYear: created is Timestamp
          ? created.toDate().year
          : DateTime.now().year,
      level: m['level'] ?? 'Beginner',
      bio: m['bio'] ?? '',
      sports: List<String>.from(m['sports'] ?? const []),
      badges: List<String>.from(m['badges'] ?? const []),
      photoPath: m['photoUrl'],
      isPremium: m['isPremium'] ?? false,
      blocked: List<String>.from(m['blocked'] ?? const []),
      likesDate: m['likesDate'] ?? '',
      likesCount: (m['likesCount'] as num?)?.toInt() ?? 0,
      verified: m['verified'] == true,
      rating: (m['rating'] as num?)?.toDouble(),
      reviewCount: (m['reviewCount'] as num?)?.toInt() ?? 0,
      shopId: m['shopId'],
      shopStatus: m['shopStatus'],
      storeSuspended: m['storeSuspended'] == true,
    );
  }

  bool get hasApprovedShop => shopStatus == 'approved' && shopId != null;

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      UserProfile.fromMap(doc.id, doc.data() ?? const {});

  /// Fields the user edits themselves. Server-managed fields (createdAt,
  /// likes counters, premium, blocked) are written elsewhere. The email is
  /// deliberately not stored: profiles are readable by every user.
  Map<String, dynamic> toMap() => {
        'name': name,
        'age': age,
        'location': location,
        'lat': lat,
        'lng': lng,
        'level': level,
        'bio': bio,
        'sports': sports,
        'badges': badges,
        'photoUrl': photoPath,
      };

  UserProfile copyWith({
    String? name,
    String? location,
    int? joinedYear,
    int? age,
    String? level,
    String? bio,
    List<String>? sports,
    List<String>? badges,
    String? photoPath,
    bool? isPremium,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      email: email,
      age: age ?? this.age,
      location: location ?? this.location,
      lat: lat,
      lng: lng,
      joinedYear: joinedYear ?? this.joinedYear,
      level: level ?? this.level,
      bio: bio ?? this.bio,
      sports: sports ?? this.sports,
      badges: badges ?? this.badges,
      photoPath: photoPath ?? this.photoPath,
      isPremium: isPremium ?? this.isPremium,
      blocked: blocked,
      likesDate: likesDate,
      likesCount: likesCount,
      verified: verified,
      rating: rating,
      reviewCount: reviewCount,
      shopId: shopId,
      shopStatus: shopStatus,
      storeSuspended: storeSuspended,
    );
  }

  // Simple completion score: picture, level, bio, ≥1 sport
  double get completion {
    int have = 0;
    if (photoPath != null && photoPath!.isNotEmpty) have++;
    if (level.isNotEmpty) have++;
    if (bio.trim().isNotEmpty) have++;
    if (sports.isNotEmpty) have++;
    return have / 4.0;
  }

  /// Badges shown on the profile: stored ones plus derived ones.
  List<String> get displayBadges => [
        ...badges,
        if (isPremium && !badges.contains('Premium')) 'Premium',
      ];

  /// Null when there is no picture, so callers can show an icon instead.
  ImageProvider? get photoProvider {
    if (photoPath == null || photoPath!.isEmpty) return null;
    if (photoPath!.startsWith('http')) return NetworkImage(photoPath!);
    return FileImage(File(photoPath!));
  }

  /// Likes already sent today (resets when the date changes).
  int likesUsedOn(String today) => likesDate == today ? likesCount : 0;

  double? distanceKmTo(double? otherLat, double? otherLng) =>
      distanceKm(lat, lng, otherLat, otherLng);
}

/// Great-circle distance in km, or null when a coordinate is missing.
double? distanceKm(double? lat1, double? lng1, double? lat2, double? lng2) {
  if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
    return null;
  }
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// yyyy-mm-dd in UTC, matching the server's daily like counter.
String todayKey([DateTime? now]) {
  final d = (now ?? DateTime.now()).toUtc();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
