// lib/src/features/events/ui/event_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/services/event_repository.dart';
import '../../../shared/widgets.dart';
import 'events_list_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final EventItem event;
  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late final Stream<EventItem?> _stream =
      EventRepository.instance.watch(widget.event.id);
  bool _busy = false;

  Future<void> _toggleJoin(EventItem e, UserProfile me) async {
    setState(() => _busy = true);
    final joined = e.isAttending(me.uid);
    try {
      joined
          ? await EventRepository.instance.leave(e.id, me.uid)
          : await EventRepository.instance.join(e.id, me);
      if (mounted) showSnack(context, joined ? 'Left event' : 'Joined event');
    } catch (_) {
      if (mounted) showSnack(context, 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(EventItem e) async {
    await Clipboard.setData(ClipboardData(
      text: '${e.title} – ${e.category}\n${_longDate(e.dateTime)} at ${e.place}\nJoin me on TrainMate!',
    ));
    if (mounted) showSnack(context, 'Event details copied to clipboard');
  }

  Future<void> _delete(EventItem e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete event?'),
        content: const Text('Attendees will no longer see it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await EventRepository.instance.delete(e.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return MeBuilder(
      builder: (context, me) => StreamBuilder<EventItem?>(
        stream: _stream,
        initialData: widget.event,
        builder: (context, snap) {
          final e = snap.data;
          if (e == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('This event was deleted.')),
            );
          }
          return _build(context, e, me);
        },
      ),
    );
  }

  Widget _build(BuildContext context, EventItem e, UserProfile me) {
    final cs = Theme.of(context).colorScheme;
    final joined = e.isAttending(me.uid);
    final isCreator = e.creatorId == me.uid;
    final km = formatKm(me.distanceKmTo(e.lat, e.lng));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            leading: const BackButton(),
            pinned: true,
            expandedHeight: 220,
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () => _share(e),
              ),
              if (isCreator)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'delete') _delete(e);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('Delete event')),
                  ],
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  coverImage(e.cover),
                  Container(color: Colors.black.withValues(alpha: .25)),
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
                    CategoryPill(text: e.category),
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
                    if (km.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.map_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text('$km away'),
                    ],
                  ]),
                  const SizedBox(height: 16),
                  Text(
                    e.description.isNotEmpty
                        ? e.description
                        : 'Join us for a ${e.category.toLowerCase()} session. All levels are welcome.',
                    style: TextStyle(color: cs.onSurface.withValues(alpha: .9)),
                  ),
                  const SizedBox(height: 16),
                  Text('Attendees (${e.attendees})',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  AttendeeStack(photos: e.photos),
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
              onPressed: _busy ? null : () => _toggleJoin(e, me),
              style: ElevatedButton.styleFrom(
                backgroundColor: joined ? Colors.grey.shade300 : cs.primary,
                foregroundColor: joined ? Colors.black : cs.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(joined ? 'Leave Event' : 'Join Event'),
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
