import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/functions.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _init = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_init) return;
    _init = true;
    // Ask location once, send to server, refresh recos
    final perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
      return;
    }
    final pos = await Geolocator.getCurrentPosition();
    await Fn.setUserLocation(pos.latitude, pos.longitude);
    await Fn.refreshRecommendations();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final recos = FirebaseFirestore.instance
        .collection('users').doc(uid).collection('recommendations')
        .orderBy('score', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Recommendations')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: recos,
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No matches yet — try again later.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final r = docs[i].data();
              final otherUid = r['uid'] as String;
              final name = r['displayName'] ?? 'Athlete';
              final photo = r['photoURL'] as String?;
              final sports = (r['sports'] as List?)?.cast<String>() ?? const [];
              final distance = (r['distanceKm'] ?? 0).toDouble();
              final reason = r['reason'] ?? '';
              final level = r['level'] ?? '—';

              return Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: InkWell(
                  onTap: () {}, // TODO: open profile
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (photo != null) AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(photo, fit: BoxFit.cover),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(name,
                                      style: const TextStyle(
                                          fontSize: 18, fontWeight: FontWeight.w600)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(.10),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(level, style: const TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: -8,
                              children: sports.take(5).map((s) => Chip(
                                label: Text(s),
                                visualDensity: VisualDensity.compact,
                              )).toList(),
                            ),
                            const SizedBox(height: 6),
                            Text('${distance.toStringAsFixed(1)} km away • $reason',
                                style: const TextStyle(color: Colors.black54)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      // TODO: pass
                                    },
                                    icon: const Icon(Icons.close),
                                    label: const Text('Pass'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      HapticFeedback.mediumImpact();
                                      await Fn.likeUser(otherUid);
                                    },
                                    icon: const Icon(Icons.favorite),
                                    label: const Text('Like'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
