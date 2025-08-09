import 'dart:io';
import 'package:flutter/material.dart';
import 'edit_profile_screen.dart';

class UserProfile {
  final String name;
  final String location; // auto-detected (read-only)
  final int joinedYear;
  final String level; // Beginner | Intermediate | Expert
  final String bio;
  final List<String> sports;
  final List<String> badges; // e.g. ["Verified","Coach"]
  final String? photoPath;   // local file path or network URL

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

  // Simple completion score: picture, level, bio, ≥1 sport
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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Sample data – replace with Firestore later
  UserProfile _profile = const UserProfile(
    name: 'Ethan',
    location: 'San Francisco, CA',
    joinedYear: 2022,
    level: 'Intermediate',
    bio: 'Runner and weekend tennis. Up for early sessions!',
    sports: ['Basketball', 'Tennis', 'Running'],
    badges: ['Verified', 'Coach'],
    photoPath:
    'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?w=512&q=80',
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined), // ✏️ pen icon
            tooltip: 'Edit profile',
            onPressed: () async {
              final updated = await Navigator.push<UserProfile>(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(profile: _profile),
                ),
              );
              if (updated != null) setState(() => _profile = updated);
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Column(
              children: [
                CircleAvatar(radius: 40, backgroundImage: _profile.photoProvider),
                const SizedBox(height: 12),
                Text(_profile.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(_profile.location, style: TextStyle(color: cs.onSurfaceVariant)),
                Text('Joined ${_profile.joinedYear}',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 16),

            // Completion card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: kElevationToShadow[1],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Expanded(
                      child: Text('Profile Completion',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Text('${(_profile.completion * 100).round()}%',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _profile.completion,
                      minHeight: 8,
                      color: cs.primary,
                      backgroundColor: cs.primary.withOpacity(.15),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Complete your profile to find better matches!',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Badges
            const Text('Badges', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _profile.badges.map((b) {
                final isVerified = b.toLowerCase() == 'verified';
                final color = isVerified ? Colors.blue : Colors.green;
                final icon = isVerified ? Icons.verified : Icons.school;
                return Chip(
                  avatar: Icon(icon, size: 16, color: Colors.white),
                  label: Text(b, style: const TextStyle(color: Colors.white)),
                  backgroundColor: color,
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // About me
            const Text('About me', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(_profile.bio, style: const TextStyle(fontSize: 14)),

            const SizedBox(height: 20),

            // Sports
            const Text('Sports', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _profile.sports
                  .map((s) => Chip(
                label: Text(s),
                backgroundColor: Colors.grey.shade200,
              ))
                  .toList(),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
