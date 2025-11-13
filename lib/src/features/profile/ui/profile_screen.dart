import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../services/firestore_service.dart';
import 'edit_profile_screen.dart';
import '../models/user_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await FirestoreService.getCurrentUserProfile();
    setState(() {
      _profile = data;
      _loading = false;
    });
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm logout'),
        content: const Text('Do you really want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout')),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseAuth.instance.signOut();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('No profile found. Please complete your setup.')),
      );
    }

    final p = _profile!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit profile',
            onPressed: () async {
              final updated = await Navigator.push<UserProfile>(
                context,
                MaterialPageRoute(builder: (_) => EditProfileScreen(profile: p)),
              );
              if (updated != null) {
                await FirestoreService.updateUserProfile(updated);
                setState(() => _profile = updated);
              }
            },
          ),
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
                CircleAvatar(radius: 40, backgroundImage: p.photoProvider),
                const SizedBox(height: 12),
                Text(p.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(p.location, style: TextStyle(color: cs.onSurfaceVariant)),
                Text('Joined ${p.joinedYear}', style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 16),

            // Completion
            _buildCompletionCard(p, cs),

            const SizedBox(height: 20),
            _buildChipsSection('Badges', p.badges),
            const SizedBox(height: 20),
            _buildSection('About me', p.bio),
            const SizedBox(height: 20),
            _buildChipsSection('Sports', p.sports),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionCard(UserProfile p, ColorScheme cs) => Container(
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
          const Expanded(child: Text('Profile Completion', style: TextStyle(fontWeight: FontWeight.w600))),
          Text('${(p.completion * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: p.completion,
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
  );

  Widget _buildChipsSection(String title, List<String> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((e) => Chip(label: Text(e))).toList(),
      ),
    ],
  );

  Widget _buildSection(String title, String content) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(content, style: const TextStyle(fontSize: 14)),
    ],
  );
}