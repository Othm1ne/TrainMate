import 'package:flutter/material.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/services/match_repository.dart';
import '../../../data/services/user_repository.dart';
import '../../../shared/widgets.dart';
import '../../profile/ui/profile_screen.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MeBuilder(
      builder: (context, me) => Scaffold(
        appBar: AppBar(title: const Text('Premium'), centerTitle: true),
        body: me.isPremium ? _LikedYou(me: me) : _Upsell(me: me),
      ),
    );
  }
}

class _Upsell extends StatefulWidget {
  final UserProfile me;
  const _Upsell({required this.me});
  @override
  State<_Upsell> createState() => _UpsellState();
}

class _UpsellState extends State<_Upsell> {
  bool _yearly = true;
  bool _busy = false;

  static const _perks = [
    (Icons.all_inclusive, 'Unlimited likes', 'No daily cap of $freeDailyLikes likes.'),
    (Icons.favorite, 'See who liked you', 'Match instantly with people who already liked you.'),
    (Icons.workspace_premium, 'Premium badge', 'Stand out on your profile.'),
    (Icons.tune, 'Advanced filters', 'Filter partners by sport, level and distance.'),
  ];

  Future<void> _upgrade() async {
    setState(() => _busy = true);
    try {
      await UserRepository.instance.setPremium(widget.me.uid, true);
      if (mounted) showSnack(context, 'Welcome to TrainMate Premium! ⭐');
    } catch (_) {
      if (mounted) showSnack(context, 'Upgrade failed. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.workspace_premium, size: 64, color: Colors.amber),
        const SizedBox(height: 8),
        Text('TrainMate Premium',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Find your training partner faster.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant)),
        const SizedBox(height: 24),
        for (final (icon, title, subtitle) in _perks)
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.amber.shade100,
              child: Icon(icon, color: Colors.amber.shade800),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(subtitle),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _PlanCard(
                title: 'Monthly',
                price: '€9.99',
                period: '/ month',
                selected: !_yearly,
                onTap: () => setState(() => _yearly = false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PlanCard(
                title: 'Yearly',
                price: '€59.99',
                period: '/ year',
                tag: 'Save 50%',
                selected: _yearly,
                onTap: () => setState(() => _yearly = true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _upgrade,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.amber.shade700,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Upgrade now', style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 8),
        Text('Cancel anytime.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final String? tag;
  final bool selected;
  final VoidCallback onTap;
  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    this.tag,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.amber.shade700 : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          color: selected ? Colors.amber.shade50 : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (tag != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(tag!,
                        style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(price, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text(period, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _LikedYou extends StatefulWidget {
  final UserProfile me;
  const _LikedYou({required this.me});
  @override
  State<_LikedYou> createState() => _LikedYouState();
}

class _LikedYouState extends State<_LikedYou> {
  late Future<List<UserProfile>> _future = MatchRepository.instance.likedMe(widget.me);

  Future<void> _respond(UserProfile other, bool liked) async {
    final matched = await MatchRepository.instance.swipe(widget.me, other, liked);
    if (!mounted) return;
    if (matched) showSnack(context, "It's a match with ${other.name}! Check your chats.");
    setState(() => _future = MatchRepository.instance.likedMe(widget.me));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _future = MatchRepository.instance.likedMe(widget.me));
        await _future;
      },
      child: FutureBuilder<List<UserProfile>>(
        future: _future,
        builder: (context, snap) {
          final header = ListTile(
            leading: const Icon(Icons.workspace_premium, color: Colors.amber, size: 32),
            title: const Text("You're Premium ⭐",
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Unlimited likes are on. Here is who already liked you:'),
          );
          if (snap.hasError) {
            return ListView(children: [header, const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Could not load likes.', textAlign: TextAlign.center),
            )]);
          }
          if (!snap.hasData) {
            return ListView(children: [
              header,
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ]);
          }
          final people = snap.data!;
          return ListView(
            children: [
              header,
              const Divider(),
              if (people.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No new likes yet. Keep your profile complete to get noticed!',
                      textAlign: TextAlign.center),
                ),
              for (final p in people)
                ListTile(
                  leading: Avatar(url: p.photoPath),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${p.level} · ${p.sports.take(3).join(', ')}'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProfileScreen(uid: p.uid)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _respond(p, false),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _respond(p, true),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
