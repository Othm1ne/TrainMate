import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swipable_stack/swipable_stack.dart';
import '../../../data/models/chat.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/services/match_repository.dart';
import '../../../shared/sports.dart';
import '../../../shared/widgets.dart';
import '../../chat/ui/chat_thread_screen.dart';
import '../../profile/ui/profile_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onOpenPremium;
  const HomeScreen({super.key, this.onOpenPremium});

  @override
  Widget build(BuildContext context) {
    return MeBuilder(builder: (_, me) => _Deck(me: me, onOpenPremium: onOpenPremium));
  }
}

class _Deck extends StatefulWidget {
  final UserProfile me;
  final VoidCallback? onOpenPremium;
  const _Deck({required this.me, this.onOpenPremium});
  @override
  State<_Deck> createState() => _DeckState();
}

class _DeckState extends State<_Deck> {
  var _controller = SwipableStackController();
  DiscoveryFilter _filter = const DiscoveryFilter();
  List<Candidate>? _candidates;
  String? _error;
  int _likesToday = 0;

  UserProfile get _me => widget.me;
  bool get _outOfLikes => !_me.isPremium && _likesToday >= freeDailyLikes;

  @override
  void initState() {
    super.initState();
    _likesToday = _me.likesUsedOn(todayKey());
    _controller.addListener(_onIndexChanged);
    _load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onIndexChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onIndexChanged() => setState(() {});

  Future<void> _load() async {
    setState(() {
      _candidates = null;
      _error = null;
    });
    try {
      final list = await MatchRepository.instance.candidates(_me, _filter);
      if (!mounted) return;
      final old = _controller..removeListener(_onIndexChanged);
      setState(() {
        _controller = SwipableStackController()..addListener(_onIndexChanged);
        _candidates = list;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load people nearby.');
    }
  }

  bool _canSwipe(SwipeDirection direction) {
    if (direction == SwipeDirection.right && _outOfLikes) {
      _showLimitDialog();
      return false;
    }
    return true;
  }

  Future<void> _onSwiped(int index, SwipeDirection direction) async {
    final other = _candidates![index].profile;
    final liked = direction == SwipeDirection.right;
    if (liked) {
      HapticFeedback.mediumImpact(); // like
      setState(() => _likesToday++);
    } else {
      HapticFeedback.selectionClick(); // pass
    }
    try {
      final matched = await MatchRepository.instance.swipe(_me, other, liked);
      if (matched && mounted) _showMatch(other);
    } on LikeLimitReached {
      // Server is the source of truth (e.g. likes used on another device).
      if (!mounted) return;
      setState(() => _likesToday = freeDailyLikes);
      _showLimitDialog();
    } catch (_) {
      if (mounted) showSnack(context, 'Could not save your choice. Check your connection.');
    }
  }

  void _showLimitDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Out of likes for today'),
        content: const Text(
            'Free accounts get $freeDailyLikes likes per day. Go Premium for unlimited likes and see who already liked you.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onOpenPremium?.call();
            },
            child: const Text('Go Premium'),
          ),
        ],
      ),
    );
  }

  void _showMatch(UserProfile other) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("It's a match! 🎉", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Avatar(url: _me.photoPath, radius: 36),
                const SizedBox(width: 12),
                Avatar(url: other.photoPath, radius: 36),
              ],
            ),
            const SizedBox(height: 16),
            Text('You and ${other.name} want to train together.',
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep swiping')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatThreadScreen(
                    thread: ChatThread(
                      id: chatIdFor(_me.uid, other.uid),
                      otherUid: other.uid,
                      name: other.name,
                      avatar: other.photoPath ?? '',
                      lastMessage: '',
                      lastTime: DateTime.now(),
                    ),
                  ),
                ),
              );
            },
            child: const Text('Send a message'),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilters() async {
    final f = await showModalBottomSheet<DiscoveryFilter>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(initial: _filter, mySports: _me.sports),
    );
    if (f != null) {
      _filter = f;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Partner'),
        centerTitle: true,
        leading: IconButton(
          icon: Badge(
            isLabelVisible: _filter.isActive,
            smallSize: 8,
            child: const Icon(Icons.tune),
          ),
          tooltip: 'Filters',
          onPressed: _openFilters,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.star, color: Colors.amber),
            onPressed: widget.onOpenPremium,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _body(),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return _EmptyState(
        icon: Icons.wifi_off,
        text: _error!,
        action: TextButton(onPressed: _load, child: const Text('Retry')),
      );
    }
    final list = _candidates;
    if (list == null) return const Center(child: CircularProgressIndicator());
    if (_controller.currentIndex >= list.length) {
      return _EmptyState(
        icon: Icons.search_off,
        text: list.isEmpty
            ? 'Nobody matches these filters yet. Try widening them or check back later.'
            : "You've seen everyone for now. Check back later!",
        action: TextButton(onPressed: _load, child: const Text('Refresh')),
      );
    }

    return Column(
      children: [
        Expanded(
          child: SwipableStack(
            controller: _controller,
            itemCount: list.length,
            detectableSwipeDirections: const {
              SwipeDirection.left,
              SwipeDirection.right,
            },
            allowVerticalSwipe: false,
            onWillMoveNext: (_, direction) => _canSwipe(direction),
            onSwipeCompleted: _onSwiped,
            overlayBuilder: (_, __) => const SizedBox.shrink(),
            builder: (_, props) {
              final c = list[props.index];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen(uid: c.profile.uid)),
                ),
                child: _ProfileCard(
                  c.profile,
                  distanceKm: c.distanceKm,
                  swipeProgress: props.swipeProgress,
                  direction: props.direction,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _circleAction(
              icon: Icons.close,
              color: Colors.red,
              onTap: () => _controller.next(swipeDirection: SwipeDirection.left),
            ),
            if (!_me.isPremium)
              Text('${(freeDailyLikes - _likesToday).clamp(0, freeDailyLikes)} likes left',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            _circleAction(
              icon: Icons.check,
              color: Colors.green,
              onTap: () {
                if (_canSwipe(SwipeDirection.right)) {
                  _controller.next(swipeDirection: SwipeDirection.right);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _circleAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(16),
        backgroundColor: Colors.white,
        foregroundColor: color,
        elevation: 2,
      ),
      child: Icon(icon, size: 28),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const _EmptyState({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final DiscoveryFilter initial;
  final List<String> mySports;
  const _FilterSheet({required this.initial, required this.mySports});
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  static const _distances = <double?>[null, 5, 10, 25, 50];
  late String? _sport = widget.initial.sport;
  late String? _level = widget.initial.level;
  late double? _maxKm = widget.initial.maxKm;

  @override
  Widget build(BuildContext context) {
    // My sports first, then the rest.
    final sports = [
      ...widget.mySports,
      ...allSports.where((s) => !widget.mySports.contains(s)),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sport', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _sport,
              items: [
                const DropdownMenuItem(value: null, child: Text('Any of my sports')),
                ...sports.map((s) => DropdownMenuItem(value: s, child: Text(s))),
              ],
              onChanged: (v) => setState(() => _sport = v),
            ),
            const SizedBox(height: 16),
            const Text('Level', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [null, ...levels]
                  .map((l) => ChoiceChip(
                        label: Text(l ?? 'Any'),
                        selected: _level == l,
                        onSelected: (_) => setState(() => _level = l),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            const Text('Distance', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _distances
                  .map((d) => ChoiceChip(
                        label: Text(d == null ? 'Any' : '< ${d.toInt()} km'),
                        selected: _maxKm == d,
                        onSelected: (_) => setState(() => _maxKm = d),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, const DiscoveryFilter()),
                  child: const Text('Reset'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    DiscoveryFilter(sport: _sport, level: _level, maxKm: _maxKm),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final UserProfile p;
  final double? distanceKm;
  final double swipeProgress;        // 0..1
  final SwipeDirection? direction;   // left/right/none
  const _ProfileCard(
      this.p, {
        required this.distanceKm,
        required this.swipeProgress,
        required this.direction,
      });

  Color _levelColor() {
    switch (p.level) {
      case 'Beginner': return Colors.lightBlue.shade200;
      case 'Intermediate': return Colors.amber.shade300;
      case 'Expert': return Colors.redAccent.shade200;
      default: return Colors.grey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Parallax: drift opposite swipe
    final isRight = direction == SwipeDirection.right;
    final isLeft  = direction == SwipeDirection.left;
    final sign = isRight ? -1.0 : (isLeft ? 1.0 : 0.0);
    final raw = swipeProgress;
    final safeProgress = raw.isFinite ? raw.clamp(0.0, 1.0).toDouble() : 0.0;
    final dx = sign * (25.0 * safeProgress);
    final km = formatKm(distanceKm);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.translate(
            offset: Offset(dx, 0),
            child: (p.photoPath ?? '').isEmpty
                ? Container(
                    color: Colors.grey.shade300,
                    child: Icon(Icons.person, size: 120, color: Colors.grey.shade500),
                  )
                : coverImage(p.photoPath!),
          ),
          // dark gradient for readability
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
          ),
          // top-left level chip
          Positioned(
            left: 12,
            top: 12,
            child: Chip(
              label: Text(p.level,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              backgroundColor: _levelColor(),
            ),
          ),
          // bottom info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.age > 0 ? '${p.name}, ${p.age}' : p.name,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20),
                ),
                const SizedBox(height: 2),
                Text(km.isEmpty ? p.location : '$km away',
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                // bio / description (2 lines)
                if (p.bio.isNotEmpty)
                  Text(
                    p.bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: p.sports.map((s) => Chip(
                    label: Text(s),
                    backgroundColor: Colors.lightGreen.shade200,
                  )).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
