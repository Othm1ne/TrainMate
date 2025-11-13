import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecommendationsService {
  final _cf  = FirebaseFunctions.instanceFor(region: 'europe-west1');
  final _db  = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  /// Manually refresh list (calls Cloud Function).
  Future<void> refresh() async {
    await _cf.httpsCallable('refreshRecommendationsForUser').call({});
  }

  /// Live stream of recommendations ordered by score.
  Stream<QuerySnapshot<Map<String, dynamic>>> stream() {
    return _db
        .collection('recommendations')
        .doc(_uid)
        .collection('items')
        .orderBy('score', descending: true)
        .snapshots();
  }

  /// Swipe-right (=like)
  Future<void> like(String otherUid) =>
      _cf.httpsCallable('likeUser').call({'otherUid': otherUid});

  /// Swipe-left (=nope)
  Future<void> nope(String otherUid) =>
      _db.doc('recommendations/$_uid/items/$otherUid').delete();
}
