import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trainmate/src/data/models/chat.dart';
import 'package:trainmate/src/data/models/user_profile.dart';
import 'package:trainmate/src/data/services/match_repository.dart';
import 'package:trainmate/src/features/onboarding/ui/onboarding_screen.dart';

void main() {
  group('UserProfile', () {
    UserProfile profile({String? photo, String bio = '', List<String> sports = const []}) =>
        UserProfile(
          uid: 'u1',
          name: 'Ethan',
          location: 'Paris, France',
          joinedYear: 2025,
          level: 'Intermediate',
          bio: bio,
          sports: sports,
          badges: const [],
          photoPath: photo,
        );

    test('completion counts picture, level, bio and sports', () {
      expect(profile().completion, 0.25);
      expect(profile(photo: 'https://x/y.jpg', bio: 'Hi', sports: ['Running']).completion, 1.0);
    });

    test('fromMap / toMap round-trip', () {
      final p = UserProfile.fromMap('u1', {
        'name': 'Lina',
        'age': 26,
        'level': 'Beginner',
        'sports': ['Yoga'],
        'lat': 48.85,
        'lng': 2.35,
        'isPremium': true,
      });
      expect(p.name, 'Lina');
      expect(p.age, 26);
      expect(p.isPremium, isTrue);
      expect(p.displayBadges, contains('Premium'));
      expect(p.toMap()['sports'], ['Yoga']);
      expect(p.photoProvider, isNull);
    });

    test('daily likes reset when the date changes', () {
      final p = UserProfile.fromMap('u1', {'likesDate': '2026-01-01', 'likesCount': 7});
      expect(p.likesUsedOn('2026-01-01'), 7);
      expect(p.likesUsedOn('2026-01-02'), 0);
    });
  });

  test('distanceKm Paris → Lyon is about 392 km', () {
    final d = distanceKm(48.8566, 2.3522, 45.7640, 4.8357)!;
    expect(d, closeTo(392, 5));
    expect(distanceKm(null, 2, 3, 4), isNull);
  });

  test('matchScore prefers shared sports, nearby and similar level', () {
    UserProfile u(String level, List<String> sports) => UserProfile(
          uid: level,
          name: level,
          location: '',
          joinedYear: 2026,
          level: level,
          bio: '',
          sports: sports,
          badges: const [],
        );
    final me = u('Intermediate', ['Running', 'Tennis', 'Gym']);
    final perfect = matchScore(me, u('Intermediate', ['Running', 'Tennis', 'Gym']), 0);
    expect(perfect, closeTo(1.0, 1e-9));
    final far = matchScore(me, u('Intermediate', ['Running']), 30);
    final near = matchScore(me, u('Intermediate', ['Running']), 2);
    expect(near, greaterThan(far));
    expect(matchScore(me, u('Expert', ['Running']), 2),
        lessThan(matchScore(me, u('Intermediate', ['Running']), 2)));
  });

  test('chatIdFor is order independent', () {
    expect(chatIdFor('b', 'a'), chatIdFor('a', 'b'));
    expect(chatIdFor('a', 'b'), 'a_b');
  });

  test('todayKey is UTC and pads month and day', () {
    expect(todayKey(DateTime.utc(2026, 3, 7, 23, 30)), '2026-03-07');
  });

  testWidgets('Onboarding shows sign-up and log-in buttons', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    expect(find.text('Meet Your Match'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });
}
