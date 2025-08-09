import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swipable_stack/swipable_stack.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onOpenPremium;
  const HomeScreen({super.key, this.onOpenPremium});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = SwipableStackController();

  final _profiles = const [
    Profile(
      name: 'Marco',
      age: 28,
      distanceKm: 3,
      imageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e',
      level: 'Intermediate',
      bio: 'Early-morning gym and weekend CrossFit. Open to doubles tennis too!',
      sports: ['Gym', 'CrossFit'],
    ),
    Profile(
      name: 'Lina',
      age: 26,
      distanceKm: 2,
      imageUrl: 'https://images.unsplash.com/photo-1544006659-f0b21884ce1d',
      level: 'Beginner',
      bio: 'New to cycling, love easy park rides and yoga cooldowns.',
      sports: ['Yoga', 'Cycling'],
    ),
    Profile(
      name: 'Ethan',
      age: 24,
      distanceKm: 5,
      imageUrl: 'https://images.unsplash.com/photo-1607746882042-944635dfe10e',
      level: 'Expert',
      bio: 'Former college tennis, now mostly runs 10Ks. Looking for track buddy.',
      sports: ['Tennis', 'Running'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Partner'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.star, color: Colors.amber),
            onPressed: widget.onOpenPremium ?? () {
              // fallback if not provided
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _PremiumStub()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: SwipableStack(
                controller: _controller,
                detectableSwipeDirections: const {
                  SwipeDirection.left,
                  SwipeDirection.right,
                },
                onSwipeCompleted: (index, direction) {
                  if (direction == SwipeDirection.right) {
                    HapticFeedback.mediumImpact();   // like
                  } else if (direction == SwipeDirection.left) {
                    HapticFeedback.selectionClick(); // pass
                  }
                },
                overlayBuilder: (_, __) => const SizedBox.shrink(),
                builder: (_, props) {
                  final i = props.index % _profiles.length;
                  final p = _profiles[i];
                  return _ProfileCard(
                    p,
                    swipeProgress: props.swipeProgress,
                    direction: props.direction,
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
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _controller.next(swipeDirection: SwipeDirection.left);
                  },
                ),
                _circleAction(
                  icon: Icons.check,
                  color: Colors.green,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _controller.next(swipeDirection: SwipeDirection.right);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
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

class Profile {
  final String name;
  final int age;
  final int distanceKm;
  final String imageUrl;
  final String level;   // Beginner | Intermediate | Expert
  final String bio;     // short description
  final List<String> sports;
  const Profile({
    required this.name,
    required this.age,
    required this.distanceKm,
    required this.imageUrl,
    required this.level,
    required this.bio,
    required this.sports,
  });
}

class _ProfileCard extends StatelessWidget {
  final Profile p;
  final double swipeProgress;        // 0..1
  final SwipeDirection? direction;   // left/right/none
  const _ProfileCard(
      this.p, {
        super.key,
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
    final dx = sign * (25.0 * swipeProgress.clamp(0, 1));

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.translate(
            offset: Offset(dx, 0),
            child: Image.network(p.imageUrl, fit: BoxFit.cover),
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
                  '${p.name}, ${p.age}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20),
                ),
                const SizedBox(height: 2),
                Text('${p.distanceKm} km away',
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                // bio / description (2 lines)
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

class _PremiumStub extends StatelessWidget {
  const _PremiumStub();
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text('Premium')), body: Center(child: Text('Premium page…')));
}
