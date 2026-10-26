import 'package:cloud_firestore/cloud_firestore.dart';
import 'listing.dart';
import 'rental_pricing.dart';

/// requested → accepted → picked_up → completed (+ declined, expired,
/// cancelled, disputed, resolved). See functions/src/store/rentals.ts.
class Booking {
  final String id;
  final String listingId;
  final String ownerId;
  final String customerId;
  final OwnerInfo ownerInfo;
  final OwnerInfo customerInfo;
  final String start; // yyyy-mm-dd
  final String end;
  final int days;
  final double price;
  // TODO(deposit): show deposit + depositStatus once payments exist (V3).
  final String status;
  final String message;
  final String? declineReason;
  final String title;
  final String cover;
  final List<String> handoverPhotos;
  final List<String> returnPhotos;
  final bool handedOver;
  final String? disputeNote;
  final DateTime createdAt;
  final DateTime? reviewDeadline;

  const Booking({
    required this.id,
    required this.listingId,
    required this.ownerId,
    required this.customerId,
    required this.ownerInfo,
    required this.customerInfo,
    required this.start,
    required this.end,
    required this.days,
    required this.price,
    required this.status,
    this.message = '',
    this.declineReason,
    required this.title,
    required this.cover,
    this.handoverPhotos = const [],
    this.returnPhotos = const [],
    this.handedOver = false,
    this.disputeNote,
    required this.createdAt,
    this.reviewDeadline,
  });

  factory Booking.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    final snap = Map<String, dynamic>.from(m['listingSnapshot'] ?? const {});
    return Booking(
      id: doc.id,
      listingId: m['listingId'] ?? '',
      ownerId: m['ownerId'] ?? '',
      customerId: m['customerId'] ?? '',
      ownerInfo: OwnerInfo.fromMap(m['ownerInfo'] as Map<String, dynamic>?),
      customerInfo: OwnerInfo.fromMap(m['customerInfo'] as Map<String, dynamic>?),
      start: m['start'] ?? '',
      end: m['end'] ?? '',
      days: (m['days'] as num?)?.toInt() ?? 1,
      price: (m['price'] as num?)?.toDouble() ?? 0,
      status: m['status'] ?? 'requested',
      message: m['message'] ?? '',
      declineReason: m['declineReason'],
      title: snap['title'] ?? '',
      cover: snap['cover'] ?? '',
      handoverPhotos: List<String>.from(m['handoverPhotos'] ?? const []),
      returnPhotos: List<String>.from(m['returnPhotos'] ?? const []),
      handedOver: m['handedOverAt'] != null,
      disputeNote: m['disputeNote'],
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewDeadline: (m['reviewDeadline'] as Timestamp?)?.toDate(),
    );
  }

  bool isOwner(String uid) => ownerId == uid;
  bool members(String a, String b) =>
      (ownerId == a && customerId == b) || (ownerId == b && customerId == a);
  String otherUid(String uid) => uid == ownerId ? customerId : ownerId;
  OwnerInfo otherInfo(String uid) => uid == ownerId ? customerInfo : ownerInfo;

  bool get isOpen => const ['requested', 'accepted', 'picked_up'].contains(status);
  bool get canReview =>
      status == 'completed' &&
      reviewDeadline != null &&
      reviewDeadline!.isAfter(DateTime.now());

  String get dateLabel {
    final s = formatDay(start), e = formatDay(end);
    return start == end ? s : '$s – $e';
  }
}

class Sale {
  final String id;
  final String listingId;
  final String sellerId;
  final String buyerId;
  final double price;
  final String delivery; // hand | ship
  final String title;
  final String cover;
  final DateTime createdAt;
  final DateTime? reviewDeadline;

  const Sale({
    required this.id,
    required this.listingId,
    required this.sellerId,
    required this.buyerId,
    required this.price,
    required this.delivery,
    required this.title,
    required this.cover,
    required this.createdAt,
    this.reviewDeadline,
  });

  factory Sale.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    final snap = Map<String, dynamic>.from(m['listingSnapshot'] ?? const {});
    return Sale(
      id: doc.id,
      listingId: m['listingId'] ?? '',
      sellerId: m['sellerId'] ?? '',
      buyerId: m['buyerId'] ?? '',
      price: (m['price'] as num?)?.toDouble() ?? 0,
      delivery: m['delivery'] ?? 'hand',
      title: snap['title'] ?? '',
      cover: snap['cover'] ?? '',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewDeadline: (m['reviewDeadline'] as Timestamp?)?.toDate(),
    );
  }

  bool get canReview => reviewDeadline != null && reviewDeadline!.isAfter(DateTime.now());
}

class Review {
  final String id;
  final String authorUid;
  final String authorName;
  final String authorPhoto;
  final int stars;
  final String text;
  final String context; // rental | sale
  final String title;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.authorPhoto,
    required this.stars,
    required this.text,
    required this.context,
    required this.title,
    required this.createdAt,
  });

  factory Review.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    final a = Map<String, dynamic>.from(m['authorInfo'] ?? const {});
    return Review(
      id: doc.id,
      authorUid: m['authorUid'] ?? '',
      authorName: a['name'] ?? '',
      authorPhoto: a['photoUrl'] ?? '',
      stars: (m['stars'] as num?)?.toInt() ?? 0,
      text: m['text'] ?? '',
      context: m['context'] ?? 'rental',
      title: m['title'] ?? '',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class Shop {
  final String id;
  final String ownerUid;
  final String companyName;
  final String siret;
  final String address;
  final String email;
  final String phone;
  final String? termsUrl;
  final String? description;
  final String status; // pending | approved | rejected | suspended

  const Shop({
    required this.id,
    required this.ownerUid,
    required this.companyName,
    required this.siret,
    required this.address,
    required this.email,
    required this.phone,
    this.termsUrl,
    this.description,
    required this.status,
  });

  factory Shop.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return Shop(
      id: doc.id,
      ownerUid: m['ownerUid'] ?? '',
      companyName: m['companyName'] ?? '',
      siret: m['siret'] ?? '',
      address: m['address'] ?? '',
      email: m['email'] ?? '',
      phone: m['phone'] ?? '',
      termsUrl: m['termsUrl'],
      description: m['description'],
      status: m['status'] ?? 'pending',
    );
  }
}

const bookingStatusLabels = {
  'requested': 'Requested',
  'accepted': 'Accepted',
  'picked_up': 'In progress',
  'completed': 'Completed',
  'declined': 'Declined',
  'expired': 'Expired',
  'cancelled': 'Cancelled',
  'disputed': 'Problem reported',
  'resolved': 'Resolved',
};

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "14 Nov" from "2026-11-14".
String formatDay(String day) {
  if (day.length != 10) return day;
  final d = parseDayKey(day);
  return '${d.day} ${_months[d.month - 1]}';
}
