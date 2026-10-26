import 'package:flutter/material.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/user_repository.dart';
import '../../../shared/widgets.dart';
import '../../premium/ui/premium_screen.dart';
import '../../store/data/booking.dart';
import '../../store/data/listing.dart';
import '../../store/data/store_repository.dart';
import '../../store/ui/listing_detail_screen.dart';
import '../../store/ui/my_listings_screen.dart';
import '../../store/ui/my_rentals_screen.dart';
import '../../store/ui/shop_screen.dart';
import '../../store/ui/store_widgets.dart';
import '../../store/ui/verify_screen.dart';
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
    final badges = [
      if (p.verified && !p.badges.contains('Verified')) 'Verified',
      if (p.hasApprovedShop) 'Pro shop',
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
                const SizedBox(height: 4),
                RatingLabel(rating: p.rating, count: p.reviewCount, size: 14),
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
                    'pro shop' => (Colors.indigo, Icons.storefront),
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

            const SizedBox(height: 20),
            if (isMe) ...[
              const Text('My store', style: TextStyle(fontWeight: FontWeight.w700)),
              _MyStoreLinks(profile: p),
              const SizedBox(height: 12),
            ],
            _ListingsSection(uid: p.uid, isMe: isMe),
            _ReviewsSection(uid: p.uid),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _MyStoreLinks extends StatelessWidget {
  final UserProfile profile;
  const _MyStoreLinks({required this.profile});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    void open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    final shopLabel = switch (p.shopStatus) {
      'approved' => 'My pro shop',
      'pending' => 'Pro shop · waiting for approval',
      'suspended' => 'Pro shop · suspended',
      _ => 'Open a pro shop',
    };
    return Column(children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.sell_outlined),
        title: const Text('My listings'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => open(const MyListingsScreen()),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.event_available_outlined),
        title: const Text('Rentals & purchases'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => open(const MyRentalsScreen()),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(p.verified ? Icons.verified : Icons.verified_outlined, color: Colors.blue),
        title: Text(p.verified ? 'Verified' : 'Get verified'),
        subtitle: p.verified ? null : const Text('Required to rent out equipment'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => open(const VerifyScreen()),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.storefront_outlined),
        title: Text(shopLabel),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => open(p.shopId != null && p.shopStatus != 'rejected'
            ? ShopScreen(shopId: p.shopId!)
            : const ShopApplyScreen()),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.workspace_premium, color: Colors.amber.shade700),
        title: Text(p.isPremium ? 'Premium' : 'Go Premium'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => open(const PremiumScreen()),
      ),
    ]);
  }
}

class _ListingsSection extends StatelessWidget {
  final String uid;
  final bool isMe;
  const _ListingsSection({required this.uid, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Listing>>(
      stream: StoreRepository.instance.publicListingsOf(uid),
      builder: (context, snap) {
        final list = snap.data ?? const [];
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isMe ? 'My items for sale & rent' : 'Items for sale & rent',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => SizedBox(
                width: 150,
                child: ListingCard(
                  listing: list[i],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: list[i].id)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ]);
      },
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  final String uid;
  const _ReviewsSection({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Review>>(
      stream: StoreRepository.instance.reviewsOf(uid),
      builder: (context, snap) {
        final list = snap.data ?? const [];
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Reviews (${list.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
          for (final r in list.take(10))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Avatar(url: r.authorPhoto),
              title: Row(children: [
                Flexible(child: Text(r.authorName, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                for (var i = 0; i < 5; i++)
                  Icon(i < r.stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 14, color: Colors.amber.shade700),
              ]),
              subtitle: Text([
                if (r.text.isNotEmpty) r.text,
                '${r.context == 'rental' ? 'Rental' : 'Sale'} · ${r.title}',
              ].join('\n')),
            ),
        ]);
      },
    );
  }
}
