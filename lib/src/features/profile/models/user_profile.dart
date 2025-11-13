// lib/src/features/profile/model/user_profile.dart
import 'dart:io';
import 'package:flutter/material.dart';

class UserProfile {
  final String name;
  final String location;
  final int joinedYear;
  final String level;
  final String bio;
  final List<String> sports;
  final List<String> badges;
  final String? photoPath;

  const UserProfile({
    required this.name,
    required this.location,
    required this.joinedYear,
    required this.level,
    required this.bio,
    required this.sports,
    required this.badges,
    this.photoPath,
  });

  UserProfile copyWith({
    String? name,
    String? location,
    int? joinedYear,
    String? level,
    String? bio,
    List<String>? sports,
    List<String>? badges,
    String? photoPath,
  }) {
    return UserProfile(
      name: name ?? this.name,
      location: location ?? this.location,
      joinedYear: joinedYear ?? this.joinedYear,
      level: level ?? this.level,
      bio: bio ?? this.bio,
      sports: sports ?? this.sports,
      badges: badges ?? this.badges,
      photoPath: photoPath ?? this.photoPath,
    );
  }

  double get completion {
    int have = 0;
    if (photoPath != null && photoPath!.isNotEmpty) have++;
    if (level.isNotEmpty) have++;
    if (bio.trim().isNotEmpty) have++;
    if (sports.isNotEmpty) have++;
    return have / 4.0;
  }

  ImageProvider get photoProvider {
    if (photoPath == null || photoPath!.isEmpty) {
      return const AssetImage('assets/images/avatar_placeholder.png');
    }
    if (photoPath!.startsWith('http')) return NetworkImage(photoPath!);
    return FileImage(File(photoPath!));
  }
}

