import 'package:cloud_functions/cloud_functions.dart';

class Fn {
  static final _fns = FirebaseFunctions.instance;

  static Future<void> setUserLocation(double lat, double lng) async {
    await _fns.httpsCallable('setUserLocation').call({'lat': lat, 'lng': lng});
  }

  static Future<void> refreshRecommendations() async {
    await _fns.httpsCallable('refreshRecommendationsForUser').call();
  }

  static Future<void> likeUser(String toUid) async {
    await _fns.httpsCallable('likeUser').call({'toUid': toUid});
  }
}
