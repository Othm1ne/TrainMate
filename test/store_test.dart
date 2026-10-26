import 'package:flutter_test/flutter_test.dart';
import 'package:trainmate/src/features/store/data/booking.dart';
import 'package:trainmate/src/features/store/data/listing.dart';
import 'package:trainmate/src/features/store/data/rental_pricing.dart';

// Same cases as functions/src/store/store.test.ts: the app's preview price
// must equal what the server stores.
void main() {
  DateTime d(String s) => parseDayKey(s);

  group('rentalPrice', () {
    test('daily', () {
      expect(rentalPrice(perDay: 8, start: d('2026-11-10'), end: d('2026-11-12')), 24);
    });

    test('week package, including partial weeks when cheaper', () {
      double p(String a, String b) =>
          rentalPrice(perDay: 10, perWeek: 50, start: d(a), end: d(b));
      expect(p('2026-11-02', '2026-11-08'), 50);
      expect(p('2026-11-02', '2026-11-07'), 50);
      expect(p('2026-11-02', '2026-11-04'), 30);
      expect(p('2026-11-02', '2026-11-10'), 70);
    });

    test('weekend package', () {
      expect(isWeekendRental(d('2026-11-14'), d('2026-11-15')), isTrue);
      expect(isWeekendRental(d('2026-11-13'), d('2026-11-15')), isTrue);
      expect(isWeekendRental(d('2026-11-15'), d('2026-11-16')), isFalse);
      expect(rentalPrice(perDay: 10, perWeekend: 15, start: d('2026-11-13'), end: d('2026-11-15')), 15);
      expect(rentalPrice(perDay: 10, perWeekend: 15, start: d('2026-11-15'), end: d('2026-11-16')), 20);
    });

    test('rounds to cents', () {
      expect(rentalPrice(perDay: 3.333, start: d('2026-11-10'), end: d('2026-11-12')), 10);
    });

    test('day helpers', () {
      expect(rentalDays(d('2026-12-30'), d('2027-01-02')), 4);
      expect(dayKey(DateTime(2026, 3, 7)), '2026-03-07');
      expect(formatDay('2026-11-14'), '14 Nov');
    });
  });

  group('listing', () {
    final l = Listing(
      id: 'abc1234567',
      ownerId: 'u1',
      title: 'Padel racket',
      description: 'Bullpadel, very good condition',
      sport: 'Padel',
      category: 'Racket',
      condition: 'Good',
      mode: ListingMode.both,
      salePrice: 120,
      rentPerDay: 8.5,
      canShip: true,
      shippingPrice: 7,
      createdAt: DateTime(2026),
    );

    test('price labels', () {
      expect(euros(120), '€120');
      expect(euros(8.5), '€8.50');
      expect(listingPriceLabel(l), '€120 · €8.50/day');
    });

    test('save payload only sends fields that apply to the mode', () {
      final rentOnly = Listing(
        id: l.id, ownerId: l.ownerId, title: l.title, description: l.description,
        sport: l.sport, category: l.category, condition: l.condition,
        mode: ListingMode.rent, salePrice: 120, rentPerDay: 8, canShip: true, shippingPrice: 7,
        createdAt: l.createdAt,
      ).toSavePayload();
      expect(rentOnly['salePrice'], isNull);
      expect(rentOnly['canShip'], isFalse);
      expect(rentOnly['shippingPrice'], isNull);
      expect(rentOnly['rentPerDay'], 8);
      expect(l.toSavePayload()['shippingPrice'], 7);
    });
  });
}
