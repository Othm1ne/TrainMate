import 'package:flutter/material.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/user_repository.dart';
import '../../../shared/widgets.dart';
import 'edit_profile_screen.dart';

/// Shows the signed-in user's profile (editable) or, with [uid], someone else's.
class ProfileScreen extends StatelessWidget {
  final String? uid;
  const ProfileScreen({super.key, this.uid});

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService.instance.uid;
    final isMe = uid == null || uid == myUid;
    if (isMe) return MeBuilder(builder: (_, me) => _ProfileView(profile: me, isMe: true));

    return MeBuilder(
      builder: (_, me) => StreamBuilder<UserProfile?>(
        stream: UserRepository.instance.watch(uid!),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final p = snap.data;
          if (p == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('This profile is no longer available.')),
            );
          }
          return _ProfileView(
            profile: p,
            isMe: false,
            distanceKm: me.distanceKmTo(p.lat, p.lng),
          );
        },
      ),
    );
  }
}

class _ProfileView extends StatelessWidget {
  final UserProfile profile;
  final bool isMe;
  final double? distanceKm;
  const _ProfileView({required this.profile, required this.isMe, this.distanceKm});

  Future<void> _signOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) await AuthService.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = profile;
    final km = formatKm(distanceKm);
    final emailVerified =
        isMe && (AuthService.instance.currentUser?.emailVerified ?? false);
    final badges = [
      if (emailVerified && !p.badges.contains('Verified')) 'Verified',
      ...p.displayBadges,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(isMe ? 'Profile' : p.name),
        centerTitle: true,
        actions: [
          if (isMe) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined), // ✏️ pen icon
              tooltip: 'Edit profile',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditProfileScreen(profile: p)),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'signout') _signOut(context);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'signout',
                  child: Row(children: [
                    Icon(Icons.logout),
                    SizedBox(width: 12),
                    Text('Sign out'),
                  ]),
                ),
              ],
            ),
          ],
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
                Avatar(url: p.photoPath, radius: 40),
                const SizedBox(height: 12),
                Text(p.age > 0 && !isMe ? '${p.name}, ${p.age}' : p.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                if (km.isNotEmpty)
                  Text('$km away', style: TextStyle(color: cs.onSurfaceVariant))
                else if (p.location.isNotEmpty)
                  Text(p.location, style: TextStyle(color: cs.onSurfaceVariant)),
                Text('${p.level} · Joined ${p.joinedYear}',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 16),

            // Completion card
            if (isMe && p.completion < 1) ...[
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
                      Text('${(p.completion * 100).round()}%',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: p.completion,
                        minHeight: 8,
                        color: cs.primary,
                        backgroundColor: cs.primary.withValues(alpha: .15),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Complete your profile to find better matches!',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Badges
            if (badges.isNotEmpty) ...[
              const Text('Badges', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: badges.map((b) {
                  final (color, icon) = switch (b.toLowerCase()) {
                    'verified' => (Colors.blue, Icons.verified),
                    'premium' => (Colors.amber.shade700, Icons.workspace_premium),
                    _ => (Colors.green, Icons.school),
                  };
                  return Chip(
                    avatar: Icon(icon, size: 16, color: Colors.white),
                    label: Text(b, style: const TextStyle(color: Colors.white)),
                    backgroundColor: color,
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // About me
            const Text('About me', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              p.bio.isNotEmpty
                  ? p.bio
                  : (isMe ? 'Tell others about your training goals — tap ✏️.' : 'No bio yet.'),
              style: TextStyle(
                fontSize: 14,
                color: p.bio.isEmpty ? cs.onSurfaceVariant : null,
              ),
            ),

            const SizedBox(height: 20),

            // Sports
            const Text('Sports', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: p.sports
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
