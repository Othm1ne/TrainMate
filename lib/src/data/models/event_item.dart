import 'package:cloud_firestore/cloud_firestore.dart';

class EventItem {
  final String id;
  final String title;
  final String category; // a String from allSports
  final DateTime dateTime;
  final String place;
  final double? lat;
  final double? lng;
  final String cover; // URL or local file path
  final String creatorId;
  final List<String> attendeeIds;
  final Map<String, String> attendeePhotos; // uid -> photo URL
  final String description;

  const EventItem({
    required this.id,
    required this.title,
    required this.category,
    required this.dateTime,
    required this.place,
    this.lat,
    this.lng,
    required this.cover,
    this.creatorId = '',
    this.attendeeIds = const [],
    this.attendeePhotos = const {},
    this.description = '',
  });

  int get attendees => attendeeIds.length;

  List<String> get photos =>
      attendeePhotos.values.where((p) => p.isNotEmpty).toList();

  bool isAttending(String uid) => attendeeIds.contains(uid);

  factory EventItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    final dt = m['dateTime'];
    return EventItem(
      id: doc.id,
      title: m['title'] ?? '',
      category: m['category'] ?? '',
      dateTime: dt is Timestamp ? dt.toDate() : DateTime.now(),
      place: m['place'] ?? '',
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
      cover: m['coverUrl'] ?? '',
      creatorId: m['creatorId'] ?? '',
      attendeeIds: List<String>.from(m['attendeeIds'] ?? const []),
      attendeePhotos: Map<String, String>.from(m['attendeePhotos'] ?? const {}),
      description: m['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'category': category,
        'dateTime': Timestamp.fromDate(dateTime),
        'place': place,
        'lat': lat,
        'lng': lng,
        'coverUrl': cover,
        'creatorId': creatorId,
        'attendeeIds': attendeeIds,
        'attendeePhotos': attendeePhotos,
        'description': description,
      };
}
