import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../data/models/user_profile.dart';
import '../../../data/services/match_repository.dart' show functions;
import '../../../data/services/storage_service.dart';
import 'booking.dart';
import 'listing.dart';

enum StoreSort { relevant, nearest, newest, priceLow }

enum DealType { any, buy, rent }

class StoreFilter {
  final String query;
  final String? sport;
  final String? category;
  final DealType deal;
  final double? minPrice;
  final double? maxPrice;
  final Set<String> conditions;
  final double? maxKm;
  final bool canShipOnly;
  final String? sellerType; // private | pro
  final DateTime? from; // rent dates
  final DateTime? to;
  final StoreSort sort;

  const StoreFilter({
    this.query = '',
    this.sport,
    this.category,
    this.deal = DealType.any,
    this.minPrice,
    this.maxPrice,
    this.conditions = const {},
    this.maxKm,
    this.canShipOnly = false,
    this.sellerType,
    this.from,
    this.to,
    this.sort = StoreSort.relevant,
  });

  /// Number of active filters (for the badge on the filter button).
  int get activeCount => [
        sport != null,
        category != null,
        deal != DealType.any,
        minPrice != null || maxPrice != null,
        conditions.isNotEmpty,
        maxKm != null,
        canShipOnly,
        sellerType != null,
        from != null,
      ].where((x) => x).length;

  StoreFilter copyWith({
    String? query,
    String? Function()? sport,
    String? Function()? category,
    DealType? deal,
    double? Function()? minPrice,
    double? Function()? maxPrice,
    Set<String>? conditions,
    double? Function()? maxKm,
    bool? canShipOnly,
    String? Function()? sellerType,
    DateTime? Function()? from,
    DateTime? Function()? to,
    StoreSort? sort,
  }) =>
      StoreFilter(
        query: query ?? this.query,
        sport: sport != null ? sport() : this.sport,
        category: category != null ? category() : this.category,
        deal: deal ?? this.deal,
        minPrice: minPrice != null ? minPrice() : this.minPrice,
        maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
        conditions: conditions ?? this.conditions,
        maxKm: maxKm != null ? maxKm() : this.maxKm,
        canShipOnly: canShipOnly ?? this.canShipOnly,
        sellerType: sellerType != null ? sellerType() : this.sellerType,
        from: from != null ? from() : this.from,
        to: to != null ? to() : this.to,
        sort: sort ?? this.sort,
      );
}

class FeedItem {
  final Listing listing;
  final double? distanceKm;
  const FeedItem(this.listing, this.distanceKm);
}

/// Message from a Cloud Function error, for snackbars.
String storeError(Object e) {
  if (e is FirebaseFunctionsException) return e.message ?? 'Something went wrong.';
  return 'Something went wrong. Check your connection.';
}

class StoreRepository {
  StoreRepository._();
  static final instance = StoreRepository._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _listings => _db.collection('listings');

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) async {
    final res = await functions.httpsCallable(name).call<Map<String, dynamic>>(data);
    return Map<String, dynamic>.from(res.data);
  }

  // ---- Feed ----------------------------------------------------------------

  Future<List<FeedItem>> feed(UserProfile me, StoreFilter f) async {
    Query<Map<String, dynamic>> q = _listings.where('status', isEqualTo: 'active');
    if (f.sport != null) q = q.where('sport', isEqualTo: f.sport);
    final snap = await q.orderBy('createdAt', descending: true).limit(300).get();

    final text = f.query.trim().toLowerCase();
    double? priceOf(Listing l) => switch (f.deal) {
          DealType.buy => l.salePrice,
          DealType.rent => l.rentPerDay,
          DealType.any => l.salePrice ?? l.rentPerDay,
        };

    var items = <FeedItem>[];
    for (final doc in snap.docs) {
      final l = Listing.fromDoc(doc);
      if (l.ownerId == me.uid) continue;
      if (text.isNotEmpty &&
          !'${l.title} ${l.brand ?? ''} ${l.description} ${l.sport} ${l.category}'
              .toLowerCase()
              .contains(text)) {
        continue;
      }
      if (f.category != null && l.category != f.category) continue;
      if (f.deal == DealType.buy && !l.mode.sells) continue;
      if (f.deal == DealType.rent && !l.mode.rents) continue;
      final price = priceOf(l);
      if (f.minPrice != null && (price == null || price < f.minPrice!)) continue;
      if (f.maxPrice != null && (price == null || price > f.maxPrice!)) continue;
      if (f.conditions.isNotEmpty && !f.conditions.contains(l.condition)) continue;
      if (f.canShipOnly && !l.canShip) continue;
      if (f.sellerType != null && l.sellerType != f.sellerType) continue;
      final km = me.distanceKmTo(l.lat, l.lng);
      if (f.maxKm != null && (km == null || km > f.maxKm!)) continue;
      items.add(FeedItem(l, km));
    }

    if (f.from != null && f.to != null) items = await _availableOn(items, f.from!, f.to!);

    int bySort(FeedItem a, FeedItem b) {
      switch (f.sort) {
        case StoreSort.nearest:
          return (a.distanceKm ?? double.infinity).compareTo(b.distanceKm ?? double.infinity);
        case StoreSort.newest:
          return b.listing.createdAt.compareTo(a.listing.createdAt);
        case StoreSort.priceLow:
          return (priceOf(a.listing) ?? double.infinity)
              .compareTo(priceOf(b.listing) ?? double.infinity);
        case StoreSort.relevant:
          // My sports first, then nearest.
          final mine = (me.sports.contains(b.listing.sport) ? 1 : 0) -
              (me.sports.contains(a.listing.sport) ? 1 : 0);
          if (mine != 0) return mine;
          return (a.distanceKm ?? double.infinity).compareTo(b.distanceKm ?? double.infinity);
      }
    }

    items.sort((a, b) {
      // Boosted ("Sponsored") listings always come first.
      final boost = (b.listing.isBoosted ? 1 : 0) - (a.listing.isBoosted ? 1 : 0);
      return boost != 0 ? boost : bySort(a, b);
    });
    return items;
  }

  /// Keeps rentable listings with no booked day between [from] and [to].
  Future<List<FeedItem>> _availableOn(List<FeedItem> items, DateTime from, DateTime to) async {
    final start = _key(from), end = _key(to);
    final rentable = items.where((i) => i.listing.mode.rents).take(60).toList();
    final free = await Future.wait(rentable.map((i) async {
      final s = await _listings
          .doc(i.listing.id)
          .collection('blocked')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: start)
          .where(FieldPath.documentId, isLessThanOrEqualTo: end)
          .limit(1)
          .get();
      return s.docs.isEmpty;
    }));
    return [for (var i = 0; i < rentable.length; i++) if (free[i]) rentable[i]];
  }

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---- Listings ------------------------------------------------------------

  Stream<Listing?> watchListing(String id) => _listings
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? Listing.fromDoc(d) : null)
      .handleError((_) {}); // listing no longer readable (sold to someone else / removed)

  Stream<List<Listing>> myListings(String uid) => _listings
      .where('ownerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Listing.fromDoc).where((l) => l.status != 'removed').toList());

  Stream<List<Listing>> publicListingsOf(String uid) => _listings
      .where('ownerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Listing.fromDoc).where((l) => l.isAvailable).toList());

  Stream<List<Listing>> shopListings(String shopId) => _listings
      .where('shopId', isEqualTo: shopId)
      .where('status', isEqualTo: 'active')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Listing.fromDoc).toList());

  String newListingId() => _listings.doc().id;

  /// Uploads new local photos, then saves through the server.
  /// Returns the resulting status (active / pending_review / …).
  Future<String> saveListing(Listing draft, String uid) async {
    final photos = <String>[];
    for (var i = 0; i < draft.photos.length; i++) {
      final p = draft.photos[i];
      photos.add(p.startsWith('http')
          ? p
          : (await StorageService.instance.upload(
              p, 'listings/$uid/${draft.id}/${DateTime.now().millisecondsSinceEpoch}_$i.jpg'))!);
    }
    final payload = draft.toSavePayload()..['photos'] = photos;
    final res = await _call('saveListing', payload);
    return res['status'] as String;
  }

  Future<void> setListingStatus(String id, String action) =>
      _call('setListingStatus', {'listingId': id, 'action': action});

  Future<bool> boost(String id) async => (await _call('boostListing', {'listingId': id}))['free'] == true;

  Future<String> contactOwner(String listingId) async =>
      (await _call('contactOwner', {'listingId': listingId}))['chatId'] as String;

  Future<void> markSold(String listingId, String buyerUid, String delivery) =>
      _call('markSold', {'listingId': listingId, 'buyerUid': buyerUid, 'delivery': delivery});

  Future<void> recordView(String listingId) =>
      _call('viewListing', {'listingId': listingId}).catchError((_) => <String, dynamic>{});

  /// People who contacted me about this listing (for "Mark as sold").
  Future<List<({String uid, String name, String photoUrl})>> interestedBuyers(
      String listingId, String ownerUid) async {
    final snap = await _db
        .collection('chats')
        .where('members', arrayContains: ownerUid)
        .where('listingId', isEqualTo: listingId)
        .get();
    return snap.docs.map((d) {
      final m = d.data();
      final other = List<String>.from(m['members']).firstWhere((u) => u != ownerUid);
      final info = Map<String, dynamic>.from((m['memberInfo'] as Map?)?[other] ?? const {});
      return (uid: other, name: (info['name'] ?? '') as String, photoUrl: (info['photoUrl'] ?? '') as String);
    }).toList();
  }

  // ---- Rentals -------------------------------------------------------------

  Future<Set<String>> blockedDays(String listingId) async {
    final res = await _call('listingAvailability', {'listingId': listingId});
    return Set<String>.from(res['blocked'] as List);
  }

  Future<({String bookingId, double price})> requestRental({
    required String listingId,
    required DateTime start,
    required DateTime end,
    required String message,
  }) async {
    final res = await _call('requestRental', {
      'listingId': listingId,
      'start': _key(start),
      'end': _key(end),
      'message': message,
    });
    return (bookingId: res['bookingId'] as String, price: (res['price'] as num).toDouble());
  }

  Future<String> respondRental(String bookingId, bool accept, {String? reason}) async =>
      (await _call('respondRental', {'bookingId': bookingId, 'accept': accept, 'reason': reason}))['status']
          as String;

  /// [localPhotos] are uploaded under bookings/{uid}/{bookingId}/ first.
  Future<void> updateRental(String bookingId, String action, String uid,
      {List<String> localPhotos = const [], String? note}) async {
    final urls = <String>[];
    for (var i = 0; i < localPhotos.length; i++) {
      urls.add((await StorageService.instance.upload(localPhotos[i],
          'bookings/$uid/$bookingId/${action}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg'))!);
    }
    await _call('updateRental', {'bookingId': bookingId, 'action': action, 'photos': urls, 'note': note});
  }

  Stream<Booking?> watchBooking(String id) => _db
      .collection('bookings')
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? Booking.fromDoc(d) : null);

  Stream<List<Booking>> myBookings(String uid) => _db
      .collection('bookings')
      .where('members', arrayContains: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Booking.fromDoc).toList());

  /// Bookings between me and the other chat member for one listing.
  Stream<List<Booking>> bookingsForListing(String uid, String listingId) => _db
      .collection('bookings')
      .where('members', arrayContains: uid)
      .where('listingId', isEqualTo: listingId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Booking.fromDoc).toList());

  Stream<List<Sale>> mySales(String uid) => _db
      .collection('sales')
      .where('members', arrayContains: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Sale.fromDoc).toList());

  // ---- Reviews -------------------------------------------------------------

  Future<bool> submitReview(String context, String refId, int stars, String text) async =>
      (await _call('submitReview', {'context': context, 'refId': refId, 'stars': stars, 'text': text}))['revealed'] ==
      true;

  Stream<List<Review>> reviewsOf(String uid) => _db
      .collection('reviews')
      .where('targetUid', isEqualTo: uid)
      .where('visible', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(Review.fromDoc).toList());

  Future<bool> hasReviewed(String context, String refId, String uid) async =>
      (await _db.doc('reviews/${context}_${refId}_$uid').get()).exists;

  // ---- Verification & shops ------------------------------------------------

  Future<({bool verified, List<String> missing})> refreshVerification() async {
    final res = await _call('refreshVerification', {});
    return (verified: res['verified'] == true, missing: List<String>.from(res['missing'] ?? const []));
  }

  Future<void> applyForShop(Map<String, dynamic> details) => _call('applyForShop', details);

  Stream<Shop?> watchShop(String id) => _db
      .collection('shops')
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? Shop.fromDoc(d) : null)
      .handleError((_) {});
}
