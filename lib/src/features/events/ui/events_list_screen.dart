// lib/src/features/events/ui/events_list_screen.dart
import 'package:flutter/material.dart';
import '../../../data/models/event_item.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/services/event_repository.dart';
import '../../../shared/sports.dart';
import '../../../shared/widgets.dart';
import 'create_event_screen.dart';
import 'event_detail_screen.dart';

export '../../../data/models/event_item.dart';

class EventsListScreen extends StatelessWidget {
  const EventsListScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      MeBuilder(builder: (_, me) => _EventsList(me: me));
}

class _EventsList extends StatefulWidget {
  final UserProfile me;
  const _EventsList({required this.me});
  @override
  State<_EventsList> createState() => _EventsListState();
}

class _EventsListState extends State<_EventsList> {
  String? _filter; // null = All, 'mine' = events I'm going to, else a sport
  final _events = EventRepository.instance.upcoming();

  Future<void> _openCreate() async {
    final created = await Navigator.push<EventItem>(
      context,
      MaterialPageRoute(builder: (_) => CreateEventScreen(creator: widget.me)),
    );
    if (created != null && mounted) showSnack(context, 'Event created');
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
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
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        tooltip: 'Create event',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _CategoryChips(value: _filter, onChanged: (v) => setState(() => _filter = v)),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<EventItem>>(
              stream: _events,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(child: Text('Could not load events.'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data!.where((e) {
                  if (_filter == null) return true;
                  if (_filter == _mine) return e.isAttending(me.uid);
                  return e.category == _filter;
                }).toList();

                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _filter == _mine
                            ? "You haven't joined any upcoming events yet."
                            : 'No upcoming events here yet.\nCreate the first one!',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _EventCard(
                    item: list[i],
                    distanceKm: me.distanceKmTo(list[i].lat, list[i].lng),
                    going: list[i].isAttending(me.uid),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => EventDetailScreen(event: list[i])),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

const _mine = '__mine__';

// Horizontal scrollable chips: "All", "Going" + every sport from shared list.
class _CategoryChips extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _CategoryChips({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cats = [null, _mine, ...allSports]; // null = All
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) {
          final cat = cats[i];
          final selected = value == cat;
          final label = cat == null ? 'All' : (cat == _mine ? 'Going' : cat);
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
  final double? distanceKm;
  final bool going;
  final VoidCallback onTap;
  const _EventCard({
    required this.item,
    required this.distanceKm,
    required this.going,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final km = formatKm(distanceKm);
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
                  child: coverImage(item.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.title,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        if (going)
                          const Icon(Icons.check_circle, size: 16, color: Colors.green),
                      ],
                    ),
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
                        if (km.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.map_outlined, size: 16),
                          const SizedBox(width: 4),
                          Text(km, style: TextStyle(color: cs.onSurfaceVariant)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        AttendeeStack(photos: item.photos, size: 22),
                        const SizedBox(width: 8),
                        Text('${item.attendees} attending',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        const Spacer(),
                        CategoryPill(text: item.category),
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

  String _formatDate(DateTime dt) {
    final weekday = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][dt.weekday - 1];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$weekday ${dt.day}, $hour:${dt.minute.toString().padLeft(2, "0")} $ampm';
  }
}

class AttendeeStack extends StatelessWidget {
  final List<String> photos;
  final double size;
  const AttendeeStack({super.key, required this.photos, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final shown = photos.take(6).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: (size * 0.6) * (shown.length - 1) + size,
      height: size,
      child: Stack(
        children: [
          for (int i = 0; i < shown.length; i++)
            Positioned(
              left: i * (size * 0.6),
              child: Avatar(url: shown[i], radius: size / 2),
            ),
        ],
      ),
    );
  }
}

class CategoryPill extends StatelessWidget {
  final String text;
  const CategoryPill({super.key, required this.text});
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
