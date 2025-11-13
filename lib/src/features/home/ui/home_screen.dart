import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // CHANGE THIS TO true to bypass backend and see the UI with sample data.
  static const bool useMockData = false;

  bool _loading = true;
  String? _error;
  String _stage = 'init';
  List<Recommendation> _items = [];

  late final FirebaseFunctions _functions =
  FirebaseFunctions.instanceFor(region: 'europe-west1');

  void _setStage(String s) {
    _stage = s;
    // Prints to console – please paste these back to me if it fails.
    // Example: STAGE: gps.requestPermission
    // (Do not remove; this is how we’ll know where it stops.)
    // ignore: avoid_print
    print('STAGE: $s');
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
      _stage = 'init';
    });

    try {
      if (useMockData) {
        _setStage('mock.fill');
        await Future<void>.delayed(const Duration(milliseconds: 300));
        _items = _mock();
        _loading = false;
        setState(() {});
        return;
      }

      // 0) Check that user is signed in
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _loading = false;
        _error = 'Not signed in (authStateChanges returned null).';
        setState(() {});
        return;
      }

      // 1) Ensure location service is enabled
      _setStage('gps.isServiceEnabled');
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        _loading = false;
        _error =
        'Location services are OFF.\nTap "Open location settings", enable it, then Retry.';
        setState(() {});
        return;
      }

      // 2) Ask for permission (handle denied and forever)
      _setStage('gps.checkPermission');
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _setStage('gps.requestPermission');
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        _loading = false;
        _error =
        'Location permission is permanently denied.\nTap "Open app settings" and grant permission.';
        setState(() {});
        return;
      }
      if (perm == LocationPermission.denied) {
        _loading = false;
        _error = 'Location permission denied.';
        setState(() {});
        return;
      }

      // 3) Get a position with a hard timeout; fall back to last known
      _setStage('gps.getCurrentPosition');
      Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          timeLimit: const Duration(seconds: 12),
        );
      } on TimeoutException {
        _setStage('gps.getLastKnownPosition');
        final last = await Geolocator.getLastKnownPosition();
        if (last == null) {
          throw 'Could not get GPS fix (timed out) and no last known position.';
        }
        pos = last;
      }

      // 4) setUserLocation (Cloud Function)
      _setStage('cf.setUserLocation');
      await _functions
          .httpsCallable('setUserLocation')
          .call({'lat': pos.latitude, 'lng': pos.longitude})
          .timeout(const Duration(seconds: 12));

      // 5) refreshRecommendationsForUser (Cloud Function)
      _setStage('cf.refreshRecommendations');
      await _functions
          .httpsCallable('refreshRecommendationsForUser')
          .call({'uid': uid})
          .timeout(const Duration(seconds: 15));

      // 6) Read Firestore
      _setStage('fs.fetchRecommendations');
      final snap = await FirebaseFirestore.instance
          .collection('recommendations')
          .doc(uid)
          .collection('items')
          .orderBy('score', descending: true)
          .limit(20)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 10));

      _items = snap.docs
          .map((d) => Recommendation.fromMap(d.id, d.data()))
          .toList();

      _setStage('done');
      _loading = false;
      setState(() {});
    } catch (e, st) {
      // ignore: avoid_print
      print('ERROR: $_stage -> $e\n$st');
      _loading = false;
      _error = 'Stage: $_stage\n$e';
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommendations'),
        centerTitle: true,
        actions: [
          if (!useMockData)
            IconButton(
              tooltip: 'Use mock data (temp)',
              onPressed: () {
                setState(() {
                  _error = null;
                  _loading = false;
                  _items = _mock();
                  _stage = 'mock.view';
                });
              },
              icon: const Icon(Icons.bug_report_outlined),
            ),
        ],
      ),
      body: _loading
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text('Stage: $_stage'),
          ],
        ),
      )
          : (_error != null)
          ? _ErrorView(
        message: _error!,
        stage: _stage,
        onRetry: _bootstrap,
      )
          : (_items.isEmpty)
          ? _EmptyView(onRefresh: _bootstrap)
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final r = _items[i];
          return Material(
            color: cs.surface,
            elevation: 1,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  r.photoUrl ??
                      'https://picsum.photos/seed/${r.id}/200/200',
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 64,
                    height: 64,
                    color: cs.surfaceVariant,
                  ),
                ),
              ),
              title: Text(
                '${r.name ?? 'Athlete'}${r.age != null ? ', ${r.age}' : ''}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (r.distanceKm != null)
                    Text(_distanceText(r.distanceKm!)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: -8,
                    children: (r.sports ?? const [])
                        .take(4)
                        .map((s) => Chip(
                      label: Text(s,
                          style: const TextStyle(
                              fontSize: 12)),
                      materialTapTargetSize:
                      MaterialTapTargetSize
                          .shrinkWrap,
                    ))
                        .toList(),
                  ),
                ],
              ),
              trailing: Text(
                (r.score ?? 0).toStringAsFixed(2),
                style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w700),
              ),
            ),
          );
        },
      ),
    );
  }

  String _distanceText(double km) {
    if (km < 1) return '${(km * 1000).round()} m away';
    return '${km.toStringAsFixed(1)} km away';
  }

  List<Recommendation> _mock() => List.generate(
    8,
        (i) => Recommendation(
      id: 'm$i',
      name: 'Marco $i',
      age: 28 + i,
      score: 0.78 - i * 0.03,
      distanceKm: 1.2 + i * 0.4,
      sports: const ['Gym', 'CrossFit', 'Running'],
      photoUrl: 'https://picsum.photos/seed/m$i/300/300',
    ),
  );
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyView({required this.onRefresh});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('No recommendations yet'),
        const SizedBox(height: 8),
        ElevatedButton(onPressed: onRefresh, child: const Text('Refresh'))
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final String stage;
  final VoidCallback onRetry;
  const _ErrorView({
    required this.message,
    required this.stage,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 48),
        const SizedBox(height: 12),
        Text('Stage: $stage', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Wrap(spacing: 12, children: [
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          TextButton(
              onPressed: () => Geolocator.openLocationSettings(),
              child: const Text('Open location settings')),
          TextButton(
              onPressed: () => Geolocator.openAppSettings(),
              child: const Text('Open app settings')),
        ])
      ]),
    );
  }
}

class Recommendation {
  final String id;
  final String? name;
  final int? age;
  final double? score;
  final double? distanceKm;
  final List<String>? sports;
  final String? photoUrl;

  Recommendation({
    required this.id,
    this.name,
    this.age,
    this.score,
    this.distanceKm,
    this.sports,
    this.photoUrl,
  });

  factory Recommendation.fromMap(String id, Map<String, dynamic> map) {
    return Recommendation(
      id: id,
      name: map['name'] as String?,
      age:
      (map['age'] is int) ? map['age'] as int : (map['age'] as num?)?.toInt(),
      score: (map['score'] as num?)?.toDouble(),
      distanceKm: (map['distanceKm'] as num?)?.toDouble(),
      sports: (map['sports'] as List?)?.map((e) => e.toString()).toList(),
      photoUrl: map['photoUrl'] as String?,
    );
  }
}
