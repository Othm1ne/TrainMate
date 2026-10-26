import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/user_profile.dart';
import 'user_repository.dart';

/// Free accounts get this many likes per day; Premium is unlimited.
/// Enforced server-side in functions/src/bootstrap.ts (FREE_DAILY_LIKES).
const freeDailyLikes = 20;

/// Region of the Cloud Functions (functions/src/bootstrap.ts).
final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

class DiscoveryFilter {
  final String? sport; // null = any of my sports
  final String? level; // null = any level
  final double? maxKm; // null = any distance

  const DiscoveryFilter({this.sport, this.level, this.maxKm});

  bool get isActive => sport != null || level != null || maxKm != null;
}

class Candidate {
  final UserProfile profile;
  final double? distanceKm;
  final double score;
  const Candidate(this.profile, this.distanceKm, [this.score = 0]);
}

/// Thrown when a free user is out of likes for today.
class LikeLimitReached implements Exception {}

/// Match quality, higher is better: 60% shared sports, 30% distance
/// (0 at 25 km and beyond), 10% level gap.
double matchScore(UserProfile me, UserProfile other, double? distanceKm) {
  final overlap = other.sports.where(me.sports.contains).length;
  final overlapScore = (overlap / 3).clamp(0.0, 1.0);
  final distanceScore =
      distanceKm == null ? 0.0 : ((25 - distanceKm) / 25).clamp(0.0, 1.0);
  final levelGap =
      (levels.indexOf(me.level) - levels.indexOf(other.level)).abs().clamp(0, 2);
  final levelScore = 1 - levelGap / 2;
  return overlapScore * 0.6 + distanceScore * 0.3 + levelScore * 0.1;
}

class MatchRepository {
  MatchRepository._();
  static final instance = MatchRepository._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> _swipes(String uid) =>
      _db.collection('users').doc(uid).collection('swipes');

  /// People to show on the Home deck: share a sport, not swiped yet,
  /// not blocked either way, best matches first.
  Future<List<Candidate>> candidates(UserProfile me, DiscoveryFilter f) async {
    final sports = f.sport != null ? [f.sport!] : me.sports.take(10).toList();
    Query<Map<String, dynamic>> q = UserRepository.instance.users;
    if (sports.isNotEmpty) q = q.where('sports', arrayContainsAny: sports);
    if (f.level != null) q = q.where('level', isEqualTo: f.level);

    final results = await Future.wait([q.limit(200).get(), _swipes(me.uid).get()]);
    final swiped = results[1].docs.map((d) => d.id).toSet();

    final list = <Candidate>[];
    for (final doc in results[0].docs) {
      if (doc.id == me.uid || swiped.contains(doc.id)) continue;
      final p = UserProfile.fromDoc(doc);
      if (me.blocked.contains(p.uid) || p.blocked.contains(me.uid)) continue;
      final d = me.distanceKmTo(p.lat, p.lng);
      if (f.maxKm != null && (d == null || d > f.maxKm!)) continue;
      list.add(Candidate(p, d, matchScore(me, p, d)));
    }
    list.sort((a, b) => b.score.compareTo(a.score));
    return list;
  }

  /// Records a swipe on the server. Returns true when it created a match.
  /// Throws [LikeLimitReached] when a free user is out of likes.
  Future<bool> swipe(UserProfile me, UserProfile other, bool liked) async {
    try {
      final res = await functions
          .httpsCallable('swipe')
          .call<Map<String, dynamic>>({'toUid': other.uid, 'liked': liked});
      return res.data['matched'] == true;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') throw LikeLimitReached();
      rethrow;
    }
  }

  /// People who liked me and I haven't swiped on yet (Premium feature).
  Future<List<UserProfile>> likedMe(UserProfile me) async {
    final snap = await _db
        .collectionGroup('swipes')
        .where('to', isEqualTo: me.uid)
        .where('liked', isEqualTo: true)
        .get();
    final mine = (await _swipes(me.uid).get()).docs.map((d) => d.id).toSet();
    final ids = snap.docs
        .map((d) => d.data()['from'] as String)
        .where((id) => !mine.contains(id) && !me.blocked.contains(id))
        .toSet();
    final profiles = await Future.wait(ids.map(UserRepository.instance.get));
    return profiles.whereType<UserProfile>().toList();
  }
}
