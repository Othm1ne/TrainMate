// lib/src/features/events/ui/events_list_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'event_detail_screen.dart';
import 'create_event_screen.dart';
import '../../../shared/sports.dart';

class EventItem {
  final String id;
  final String title;
  final String category; // now a String from allSports
  final DateTime dateTime;
  final String place;
  final double distanceKm;
  final String cover; // URL or local file path
  final int attendees;
  final List<String> attendeePhotos;
  final String description;

  const EventItem({
    required this.id,
    required this.title,
    required this.category,
    required this.dateTime,
    required this.place,
    required this.distanceKm,
    required this.cover,
    required this.attendees,
    required this.attendeePhotos,
    this.description = '',
  });
}

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key});
  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  String? _filter; // null = All

  final _items = <EventItem>[
    EventItem(
      id: '1',
      title: 'Morning Run',
      category: 'Running',
      dateTime: DateTime.now().add(const Duration(days: 1, hours: 7)),
      place: 'Central Park',
      distanceKm: 2.7,
      cover: 'https://picsum.photos/seed/run/1200/800',
      attendees: 12,
      attendeePhotos: [
        'https://picsum.photos/seed/a1/100/100',
        'https://picsum.photos/seed/a2/100/100',
        'https://picsum.photos/seed/a3/100/100',
      ],
    ),
    EventItem(
      id: '2',
      title: 'Pickup Basketball',
      category: 'Basketball',
      dateTime: DateTime.now().add(const Duration(days: 2, hours: 18)),
      place: 'Prospect Courts',
      distanceKm: 4.0,
      cover: 'https://picsum.photos/seed/ball/1200/800',
      attendees: 8,
      attendeePhotos: [
        'https://picsum.photos/seed/b1/100/100',
        'https://picsum.photos/seed/b2/100/100',
      ],
    ),
    EventItem(
      id: '3',
      title: 'Sunset Yoga',
      category: 'Yoga',
      dateTime: DateTime.now().add(const Duration(days: 3, hours: 19)),
      place: 'Riverside Lawn',
      distanceKm: 1.6,
      cover: 'https://picsum.photos/seed/yoga/1200/800',
      attendees: 20,
      attendeePhotos: [
        'https://picsum.photos/seed/y1/100/100',
        'https://picsum.photos/seed/y2/100/100',
        'https://picsum.photos/seed/y3/100/100',
      ],
    ),
  ];

  Future<void> _openCreate() async {
    final created = await Navigator.push<EventItem>(
      context,
      MaterialPageRoute(builder: (_) => const CreateEventScreen()),
    );
    if (created != null) {
      setState(() => _items.insert(0, created));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event created')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filter == null
        ? _items
        : _items.where((e) => e.category == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'create') _openCreate();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'create',
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline),
                    SizedBox(width: 12),
                    Text('Create event'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _CategoryChips(value: _filter, onChanged: (v) => setState(() => _filter = v)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: list.length,
              itemBuilder: (_, i) => _EventCard(
                item: list[i],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EventDetailScreen(event: list[i])),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Horizontal scrollable chips: "All" + every sport from shared list.
class _CategoryChips extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _CategoryChips({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cats = [null, ...allSports]; // null = All
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) {
          final cat = cats[i];
          final selected = value == cat;
          final label = cat ?? 'All';
          return ChoiceChip(
            selected: selected,
            label: Text(label),
            onSelected: (_) => onChanged(cat),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: cats.length,
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventItem item;
  final VoidCallback onTap;
  const _EventCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 78,
                  height: 78,
                  child: _coverWidget(item.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.place,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 16),
                        const SizedBox(width: 4),
                        Text(_formatDate(item.dateTime),
                            style: TextStyle(color: cs.onSurfaceVariant)),
                        const SizedBox(width: 12),
                        const Icon(Icons.map_outlined, size: 16),
                        const SizedBox(width: 4),
                        Text('${item.distanceKm.toStringAsFixed(1)} km',
                            style: TextStyle(color: cs.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _AttendeeStack(photos: item.attendeePhotos),
                        const SizedBox(width: 8),
                        Text('${item.attendees} attending',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        const Spacer(),
                        _CategoryPill(text: item.category),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverWidget(String cover) {
    final isHttp = cover.startsWith('http');
    final placeholder = Container(color: Colors.grey.shade300);
    if (isHttp) {
      return Image.network(
        cover,
        fit: BoxFit.cover,
        loadingBuilder: (c, child, p) => p == null ? child : placeholder,
        errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported),
      );
    } else {
      return Image.file(
        File(cover),
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => placeholder,
      );
    }
  }

  String _formatDate(DateTime dt) {
    final weekday = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][dt.weekday - 1];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$weekday, $hour:${dt.minute.toString().padLeft(2, "0")} $ampm';
  }
}

class _AttendeeStack extends StatelessWidget {
  final List<String> photos;
  const _AttendeeStack({required this.photos});

  @override
  Widget build(BuildContext context) {
    const size = 22.0;
    return SizedBox(
      width: (size * 0.6) * photos.length + size,
      height: size,
      child: Stack(
        children: [
          for (int i = 0; i < photos.length; i++)
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
