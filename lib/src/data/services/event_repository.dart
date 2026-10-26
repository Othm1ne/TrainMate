import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event_item.dart';
import '../models/user_profile.dart';
import 'location_service.dart';
import 'storage_service.dart';

class EventRepository {
  EventRepository._();
  static final instance = EventRepository._();

  CollectionReference<Map<String, dynamic>> get _events =>
      FirebaseFirestore.instance.collection('events');

  /// Upcoming events, soonest first (started less than 3 hours ago included).
  Stream<List<EventItem>> upcoming() => _events
      .where('dateTime',
          isGreaterThan: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(hours: 3))))
      .orderBy('dateTime')
      .snapshots()
      .map((s) => s.docs.map(EventItem.fromDoc).toList());

  Stream<EventItem?> watch(String id) => _events
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? EventItem.fromDoc(d) : null);

  /// Creates the event with its creator as first attendee.
  Future<EventItem> create(EventItem draft, UserProfile creator) async {
    final doc = _events.doc();
    final coverUrl = await StorageService.instance
        .upload(draft.cover, 'events/${doc.id}/cover.jpg');
    final coords = await LocationService.instance.geocode(draft.place);
    final item = EventItem(
      id: doc.id,
      title: draft.title,
      category: draft.category,
      dateTime: draft.dateTime,
      place: draft.place,
      lat: coords?.$1,
      lng: coords?.$2,
      cover: coverUrl ?? 'https://picsum.photos/seed/${doc.id}/1200/800',
      creatorId: creator.uid,
      attendeeIds: [creator.uid],
      attendeePhotos: {creator.uid: creator.photoPath ?? ''},
      description: draft.description,
    );
    await doc.set({...item.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    return item;
  }

  Future<void> join(String eventId, UserProfile me) => _events.doc(eventId).update({
        'attendeeIds': FieldValue.arrayUnion([me.uid]),
        'attendeePhotos.${me.uid}': me.photoPath ?? '',
      });

  Future<void> leave(String eventId, String uid) => _events.doc(eventId).update({
        'attendeeIds': FieldValue.arrayRemove([uid]),
        'attendeePhotos.$uid': FieldValue.delete(),
      });

  Future<void> delete(String eventId) => _events.doc(eventId).delete();
}
