import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat.dart';
import '../models/user_profile.dart';
import 'user_repository.dart';

/// Free accounts get this many likes per day; Premium is unlimited.
const freeDailyLikes = 20;

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
  const Candidate(this.profile, this.distanceKm);
}

class MatchRepository {
  MatchRepository._();
  static final instance = MatchRepository._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> _swipes(String uid) =>
      _db.collection('users').doc(uid).collection('swipes');

  /// People to show on the Home deck: share a sport, not swiped yet,
  /// not blocked either way, sorted by distance.
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
      list.add(Candidate(p, d));
    }
    list.sort((a, b) =>
        (a.distanceKm ?? double.infinity).compareTo(b.distanceKm ?? double.infinity));
    return list;
  }

  /// Records a swipe. Returns true when it created a match.
  Future<bool> swipe(UserProfile me, UserProfile other, bool liked) async {
    await _swipes(me.uid).doc(other.uid).set({
      'from': me.uid,
      'to': other.uid,
      'liked': liked,
      'at': FieldValue.serverTimestamp(),
    });
    if (!liked) return false;

    final today = todayKey();
    await UserRepository.instance.users.doc(me.uid).update({
      'likesDate': today,
      'likesCount': me.likesUsedOn(today) + 1,
    });

    final back = await _swipes(other.uid).doc(me.uid).get();
    if (!(back.data()?['liked'] ?? false)) return false;

    await _db.collection('chats').doc(chatIdFor(me.uid, other.uid)).set({
      'members': [me.uid, other.uid],
      'memberInfo': {
        me.uid: {'name': me.name, 'photoUrl': me.photoPath ?? ''},
        other.uid: {'name': other.name, 'photoUrl': other.photoPath ?? ''},
      },
      'lastMessage': 'You matched! Say hi 👋',
      'lastTime': FieldValue.serverTimestamp(),
      'mutedBy': <String>[],
      'blockedBy': <String>[],
    }, SetOptions(merge: true));
    return true;
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
