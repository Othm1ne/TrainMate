import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/event_item.dart';


class EventsListScreen extends StatelessWidget {
  const EventsListScreen({super.key});

  Future<void> join(String eventId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.doc('events/$eventId/attendees/$uid')
        .set({'joinedAt': FieldValue.serverTimestamp()});
  }

  Future<void> leave(String eventId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.doc('events/$eventId/attendees/$uid').delete();
  }

  @override
  Widget build(BuildContext context) {
    final events = FirebaseFirestore.instance.collection('events')
        .orderBy('dateTime').snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: events,
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No events yet'));
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final e = docs[i].data();
              final id = docs[i].id;
              final title = e['title'] ?? 'Event';
              final place = e['place'] ?? '';
              final count = e['attendeeCount'] ?? 0;
              return ListTile(
                title: Text(title),
                subtitle: Text('$place • $count going'),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(onPressed: () => join(id), child: const Text('Join')),
                    OutlinedButton(onPressed: () => leave(id), child: const Text('Leave')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
