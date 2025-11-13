// lib/src/features/events/ui/event_detail_screen.dart
import 'package:flutter/material.dart';
import '../model/event_item.dart';



class EventDetailScreen extends StatefulWidget {
  final EventItem event;
  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _joined = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            leading: const BackButton(),
            pinned: true,
            expandedHeight: 220,
            actions: [
              IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
              IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(e.cover, fit: BoxFit.cover),
                  Container(color: Colors.black.withOpacity(.25)),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        e.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    _CategoryPill(text: e.category),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.place_outlined, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text(e.place)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.calendar_today_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text(_longDate(e.dateTime)),
                    const SizedBox(width: 12),
                    const Icon(Icons.map_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text('${e.distanceKm.toStringAsFixed(1)} km away'),
                  ]),
                  const SizedBox(height: 16),
                  Text(
                    'Join us for a refreshing ${e.category.toLowerCase()} session. '
                        'All levels are welcome. We meet at the main entrance.',
                    style: TextStyle(color: cs.onSurface.withOpacity(.9)),
                  ),
                  const SizedBox(height: 16),
                  Text('Attendees (${e.attendees}${_joined ? '+1' : ''})',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _AttendeeStack(photos: e.attendeePhotos),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() => _joined = !_joined);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_joined ? 'Joined event' : 'Left event')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _joined ? Colors.grey.shade300 : cs.primary,
                foregroundColor: _joined ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(_joined ? 'Leave Event' : 'Join Event'),
            ),
          ),
        ),
      ),
    );
  }

  String _longDate(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final m = months[dt.month - 1];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$m ${dt.day}, $hour:${dt.minute.toString().padLeft(2, "0")} $ampm';
  }
}

class _CategoryPill extends StatelessWidget {
  final String text;
  const _CategoryPill({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.lightBlue.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _AttendeeStack extends StatelessWidget {
  final List<String> photos;
  const _AttendeeStack({required this.photos});
  @override
  Widget build(BuildContext context) {
    final size = 28.0;
    final maxShown = photos.length.clamp(0, 6);
    return SizedBox(
      height: size,
      child: Stack(
        children: [
          for (int i = 0; i < maxShown; i++)
            Positioned(
              left: i * (size * 0.6),
              child: CircleAvatar(
                radius: size / 2,
                backgroundImage: NetworkImage(photos[i]),
              ),
            ),
        ],
      ),
    );
  }
}
