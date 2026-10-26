import 'package:cloud_firestore/cloud_firestore.dart';

/// Keep in sync with functions/src/store/constants.ts.
const listingCategories = [
  'Racket', 'Ball', 'Bike', 'Board', 'Protection', 'Clothing', 'Shoes',
  'Fitness machine', 'Camping/Hiking', 'Other',
];
const listingConditions = ['New', 'Like new', 'Good', 'Fair'];
const freeActiveListings = 20;
const maxListingPhotos = 8;
const boostPriceEur = 1.99; // TODO(payments): in-app purchase

enum ListingMode { sale, rent, both }

extension ListingModeX on ListingMode {
  bool get sells => this != ListingMode.rent;
  bool get rents => this != ListingMode.sale;
  String get label => switch (this) {
        ListingMode.sale => 'Sell',
        ListingMode.rent => 'Rent out',
        ListingMode.both => 'Sell or rent',
      };
}

class OwnerInfo {
  final String name;
  final String photoUrl;
  final double? rating;
  final int reviewCount;
  final bool verified;
  const OwnerInfo({
    this.name = '',
    this.photoUrl = '',
    this.rating,
    this.reviewCount = 0,
    this.verified = false,
  });

  factory OwnerInfo.fromMap(Map<String, dynamic>? m) => OwnerInfo(
        name: m?['name'] ?? '',
        photoUrl: m?['photoUrl'] ?? '',
        rating: (m?['rating'] as num?)?.toDouble(),
        reviewCount: (m?['reviewCount'] as num?)?.toInt() ?? 0,
        verified: m?['verified'] == true,
      );
}

class Listing {
  final String id;
  final String ownerId;
  final OwnerInfo ownerInfo;
  final String title;
  final String description;
  final String sport;
  final String category;
  final String condition;
  final String? brand;
  final String? size;
  final ListingMode mode;
  final double? salePrice;
  final double? rentPerDay;
  final double? rentPerWeekend;
  final double? rentPerWeek;
  final int minDays;
  final int maxDays;
  final bool canShip;
  final double? shippingPrice;
  final List<String> photos;
  final String area;
  final double? lat;
  final double? lng;
  final String sellerType; // private | pro
  final String? shopId;
  final String status;
  final DateTime? boostedUntil;
  final int views;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final List<String> moderationFlags;

  const Listing({
    required this.id,
    required this.ownerId,
    this.ownerInfo = const OwnerInfo(),
    required this.title,
    required this.description,
    required this.sport,
    required this.category,
    required this.condition,
    this.brand,
    this.size,
    required this.mode,
    this.salePrice,
    this.rentPerDay,
    this.rentPerWeekend,
    this.rentPerWeek,
    this.minDays = 1,
    this.maxDays = 14,
    this.canShip = false,
    this.shippingPrice,
    this.photos = const [],
    this.area = '',
    this.lat,
    this.lng,
    this.sellerType = 'private',
    this.shopId,
    this.status = 'active',
    this.boostedUntil,
    this.views = 0,
    required this.createdAt,
    this.expiresAt,
    this.moderationFlags = const [],
  });

  String get cover => photos.isEmpty ? '' : photos.first;
  bool get isPro => sellerType == 'pro';
  bool get isBoosted => boostedUntil != null && boostedUntil!.isAfter(DateTime.now());
  bool get isAvailable => status == 'active';

  factory Listing.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    double? d(String k) => (m[k] as num?)?.toDouble();
    DateTime? t(String k) => (m[k] as Timestamp?)?.toDate();
    return Listing(
      id: doc.id,
      ownerId: m['ownerId'] ?? '',
      ownerInfo: OwnerInfo.fromMap(m['ownerInfo'] as Map<String, dynamic>?),
      title: m['title'] ?? '',
      description: m['description'] ?? '',
      sport: m['sport'] ?? '',
      category: m['category'] ?? '',
      condition: m['condition'] ?? '',
      brand: m['brand'],
      size: m['size'],
      mode: ListingMode.values.firstWhere((e) => e.name == m['mode'],
          orElse: () => ListingMode.sale),
      salePrice: d('salePrice'),
      rentPerDay: d('rentPerDay'),
      rentPerWeekend: d('rentPerWeekend'),
      rentPerWeek: d('rentPerWeek'),
      minDays: (m['minDays'] as num?)?.toInt() ?? 1,
      maxDays: (m['maxDays'] as num?)?.toInt() ?? 14,
      canShip: m['canShip'] == true,
      shippingPrice: d('shippingPrice'),
      photos: List<String>.from(m['photos'] ?? const []),
      area: m['area'] ?? '',
      lat: d('lat'),
      lng: d('lng'),
      sellerType: m['sellerType'] ?? 'private',
      shopId: m['shopId'],
      status: m['status'] ?? 'active',
      boostedUntil: t('boostedUntil'),
      views: (m['views'] as num?)?.toInt() ?? 0,
      createdAt: t('createdAt') ?? DateTime.now(),
      expiresAt: t('expiresAt'),
      moderationFlags: List<String>.from(m['moderationFlags'] ?? const []),
    );
  }

  /// Payload for the `saveListing` Cloud Function (photos already uploaded).
  Map<String, dynamic> toSavePayload() => {
        'id': id,
        'title': title,
        'description': description,
        'sport': sport,
        'category': category,
        'condition': condition,
        'brand': brand,
        'size': size,
        'mode': mode.name,
        'salePrice': mode.sells ? salePrice : null,
        'rentPerDay': mode.rents ? rentPerDay : null,
        'rentPerWeekend': mode.rents ? rentPerWeekend : null,
        'rentPerWeek': mode.rents ? rentPerWeek : null,
        'minDays': minDays,
        'maxDays': maxDays,
        'canShip': mode.sells && canShip,
        'shippingPrice': mode.sells && canShip ? shippingPrice : null,
        'photos': photos,
        'area': area,
      };
}

/// "€120", "€8.50".
String euros(num? v) {
  if (v == null) return '';
  return v == v.roundToDouble() ? '€${v.toInt()}' : '€${v.toStringAsFixed(2)}';
}

/// Short price for cards: "€120", "€8/day", "€120 · €8/day".
String listingPriceLabel(Listing l) => switch (l.mode) {
      ListingMode.sale => euros(l.salePrice),
      ListingMode.rent => '${euros(l.rentPerDay)}/day',
      ListingMode.both => '${euros(l.salePrice)} · ${euros(l.rentPerDay)}/day',
    };

const listingStatusLabels = {
  'active': 'Active',
  'pending_review': 'In review',
  'reserved': 'Reserved',
  'paused': 'Paused',
  'sold': 'Sold',
  'removed': 'Deleted',
  'expired': 'Expired',
};
