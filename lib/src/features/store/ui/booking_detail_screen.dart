import 'package:flutter/material.dart';
import '../../../data/models/chat.dart';
import '../../../data/models/user_profile.dart';
import '../../../shared/widgets.dart';
import '../../chat/ui/chat_thread_screen.dart';
import '../../profile/ui/profile_screen.dart';
import '../data/booking.dart';
import '../data/listing.dart';
import '../data/store_repository.dart';
import 'listing_detail_screen.dart';
import 'review_sheet.dart';
import 'store_widgets.dart';

/// One rental, with the actions available to me at its current step.
class BookingDetailScreen extends StatefulWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late final _stream = StoreRepository.instance.watchBooking(widget.bookingId);
  bool _busy = false;
  bool? _reviewed;

  Future<void> _run(Future<void> Function() action, [String? done]) async {
    setState(() => _busy = true);
    try {
      await action();
      if (done != null && mounted) showSnack(context, done);
    } catch (e) {
      if (mounted) showSnack(context, storeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline(Booking b) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline request'),
        content: TextField(
          controller: reason,
          maxLength: 300,
          decoration: const InputDecoration(hintText: 'Reason (optional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Decline')),
        ],
      ),
    );
    if (ok == true) {
      await _run(() => StoreRepository.instance.respondRental(b.id, false, reason: reason.text.trim()),
          'Request declined');
    }
  }

  Future<void> _cancel(Booking b) async {
    final late = b.status == 'accepted' &&
        DateTime.parse('${b.start}T00:00:00').difference(DateTime.now()).inHours < 24;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this rental?'),
        content: Text(late
            ? 'It starts in less than 24 h. Late cancellations are shown on your profile.'
            : 'The other person will be notified.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel rental'),
          ),
        ],
      ),
    );
    if (ok == true) await _run(() => _update(b, 'cancel'), 'Rental cancelled');
  }

  Future<void> _update(Booking b, String action, {List<String> photos = const [], String? note}) =>
      StoreRepository.instance.updateRental(b.id, action, _myUid!, localPhotos: photos, note: note);

  String? _myUid;

  /// Photos (and an optional note) for handover / return / dispute.
  Future<void> _photoStep(Booking b, String action) async {
    final result = await showModalBottomSheet<({List<String> photos, String note})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PhotoStepSheet(action: action),
    );
    if (result == null) return;
    await _run(
      () => _update(b, action, photos: result.photos, note: result.note),
      switch (action) {
        'handover' => 'Handed over. The renter will confirm.',
        'returnOk' => 'Rental completed ✅',
        _ => 'Problem reported. Our team will contact you both.',
      },
    );
  }

  Future<void> _review(Booking b) async {
    final done = await showReviewSheet(
      context,
      reviewContext: 'rental',
      refId: b.id,
      otherName: b.otherInfo(_myUid!).name,
    );
    if (done && mounted) setState(() => _reviewed = true);
  }

  void _openChat(Booking b) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(
            thread: ChatThread(
              id: storeChatIdFor(b.listingId, b.customerId),
              otherUid: b.otherUid(_myUid!),
              name: b.otherInfo(_myUid!).name,
              avatar: b.otherInfo(_myUid!).photoUrl,
              lastMessage: '',
              lastTime: DateTime.now(),
              kind: 'store',
              listingId: b.listingId,
              listingTitle: b.title,
              listingCover: b.cover,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return MeBuilder(
      builder: (context, me) => StreamBuilder<Booking?>(
        stream: _stream,
        builder: (context, snap) {
          final b = snap.data;
          if (b == null) {
            return Scaffold(
              appBar: AppBar(),
              body: Center(
                child: snap.connectionState == ConnectionState.waiting
                    ? const CircularProgressIndicator()
                    : const Text('Booking not found.'),
              ),
            );
          }
          _myUid = me.uid;
          if (_reviewed == null && b.canReview) {
            _reviewed = false;
            StoreRepository.instance.hasReviewed('rental', b.id, me.uid).then((v) {
              if (mounted) setState(() => _reviewed = v);
            });
          }
          return _buildPage(context, b, me);
        },
      ),
    );
  }

  Widget _buildPage(BuildContext context, Booking b, UserProfile me) {
    final cs = Theme.of(context).colorScheme;
    final owner = b.isOwner(me.uid);
    final other = b.otherInfo(me.uid);

    final actions = <Widget>[
      if (owner && b.status == 'requested') ...[
        FilledButton(
          onPressed: _busy ? null : () => _run(() async {
            final s = await StoreRepository.instance.respondRental(b.id, true);
            if (s != 'accepted') throw Exception();
          }, 'Accepted. Arrange the pickup in the chat.'),
          child: const Text('Accept'),
        ),
        OutlinedButton(onPressed: _busy ? null : () => _decline(b), child: const Text('Decline')),
      ],
      if (owner && b.status == 'accepted' && !b.handedOver)
        FilledButton.icon(
          onPressed: _busy ? null : () => _photoStep(b, 'handover'),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Hand over (take photos)'),
        ),
      if (!owner && b.status == 'accepted' && b.handedOver)
        FilledButton(
          onPressed: _busy ? null : () => _run(() => _update(b, 'confirmPickup'), 'Enjoy your session! 💪'),
          child: const Text('I received it'),
        ),
      if (owner && b.status == 'picked_up') ...[
        FilledButton.icon(
          onPressed: _busy ? null : () => _photoStep(b, 'returnOk'),
          icon: const Icon(Icons.check),
          label: const Text('Returned OK'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          onPressed: _busy ? null : () => _photoStep(b, 'dispute'),
          icon: const Icon(Icons.report_problem_outlined),
          label: const Text('Report a problem'),
        ),
      ],
      if (b.canReview && _reviewed == false)
        FilledButton.icon(
          onPressed: () => _review(b),
          icon: const Icon(Icons.star_outline),
          label: Text('Review ${other.name}'),
        ),
      if (['requested', 'accepted'].contains(b.status))
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: _busy ? null : () => _cancel(b),
          child: Text(b.status == 'requested' && !owner ? 'Cancel request' : 'Cancel rental'),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rental'),
        actions: [
          IconButton(
            tooltip: 'Chat',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => _openChat(b),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: b.listingId)),
            ),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(width: 64, height: 64, child: coverImage(b.cover)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  StatusChip.booking(b.status),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          _StatusBanner(b: b, owner: owner),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.date_range),
                title: Text(b.dateLabel),
                subtitle: Text('${b.days} day${b.days > 1 ? 's' : ''}'),
                trailing: Text(euros(b.price),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ),
              // TODO(deposit): show deposit amount and hold status here (V3).
              ListTile(
                leading: Avatar(url: other.photoUrl),
                title: Row(children: [
                  Flexible(child: Text(other.name)),
                  if (other.verified) ...[const SizedBox(width: 4), const VerifiedBadge()],
                ]),
                subtitle: Text(owner ? 'Renter' : 'Owner'),
                trailing: RatingLabel(rating: other.rating, count: other.reviewCount),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen(uid: b.otherUid(me.uid))),
                ),
              ),
            ]),
          ),
          if (b.message.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.format_quote),
                title: Text(b.message),
                subtitle: Text(b.customerInfo.name),
              ),
            ),
          if (b.declineReason != null && b.declineReason!.isNotEmpty)
            Card(child: ListTile(leading: const Icon(Icons.info_outline), title: Text(b.declineReason!))),
          if (b.disputeNote != null)
            Card(
              color: Colors.red.shade50,
              child: ListTile(
                leading: const Icon(Icons.report_problem_outlined, color: Colors.red),
                title: const Text('Problem reported'),
                subtitle: Text(b.disputeNote!),
              ),
            ),
          if (b.handoverPhotos.isNotEmpty) _Photos(title: 'Condition at pickup', urls: b.handoverPhotos),
          if (b.returnPhotos.isNotEmpty) _Photos(title: 'Condition at return', urls: b.returnPhotos),
          const SizedBox(height: 16),
          if (actions.isNotEmpty)
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: actions),
          const SizedBox(height: 16),
          Text(
            'Payment is made directly between you. TrainMate is not a party to the rental.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

String storeChatIdFor(String listingId, String customerUid) => 'store_${listingId}_$customerUid';

class _StatusBanner extends StatelessWidget {
  final Booking b;
  final bool owner;
  const _StatusBanner({required this.b, required this.owner});

  @override
  Widget build(BuildContext context) {
    final text = switch (b.status) {
      'requested' => owner
          ? '${b.customerInfo.name} wants to rent your item. Answer within 48 h.'
          : 'Waiting for ${b.ownerInfo.name} to answer (48 h max).',
      'accepted' => b.handedOver
          ? (owner ? 'Waiting for the renter to confirm pickup.' : 'Check the item and the photos, then confirm you received it.')
          : (owner
              ? 'At pickup, take photos of the item\'s condition and tap "Hand over".'
              : 'Accepted! Agree on the pickup time and place in the chat.'),
      'picked_up' => owner
          ? 'Due back on ${formatDay(b.end)}. When it\'s returned, check it and take photos.'
          : 'Enjoy! Return it by ${formatDay(b.end)}.',
      'completed' => 'Completed. Thanks for renting on TrainMate!',
      'declined' => 'The owner declined this request.',
      'expired' => 'The owner didn\'t answer in time.',
      'cancelled' => 'This rental was cancelled.',
      'disputed' => 'A problem was reported. Our team is looking into it.',
      'resolved' => 'The reported problem has been resolved.',
      _ => '',
    };
    return Text(text);
  }
}

class _Photos extends StatelessWidget {
  final String title;
  final List<String> urls;
  const _Photos({required this.title, required this.urls});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: urls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(child: InteractiveViewer(child: coverImage(urls[i], fit: BoxFit.contain))),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(width: 96, height: 96, child: coverImage(urls[i])),
                ),
              ),
            ),
          ),
        ]),
      );
}

class _PhotoStepSheet extends StatefulWidget {
  final String action; // handover | returnOk | dispute
  const _PhotoStepSheet({required this.action});
  @override
  State<_PhotoStepSheet> createState() => _PhotoStepSheetState();
}

class _PhotoStepSheetState extends State<_PhotoStepSheet> {
  List<String> _photos = [];
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _dispute => widget.action == 'dispute';

  @override
  Widget build(BuildContext context) {
    final ready = _dispute ? _note.text.trim().length >= 10 : _photos.isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          switch (widget.action) {
            'handover' => 'Photos of the item at pickup',
            'returnOk' => 'Photos of the item at return',
            _ => 'What went wrong?',
          },
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(_dispute
            ? 'Describe the damage or missing parts and add photos. Our team will contact you both.'
            : '1 to 4 photos showing its condition. They protect both of you.'),
        const SizedBox(height: 12),
        PhotoPickerRow(photos: _photos, max: 4, onChanged: (p) => setState(() => _photos = p)),
        if (_dispute) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Description (10+ characters)'),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: ready ? () => Navigator.pop(context, (photos: _photos, note: _note.text.trim())) : null,
            child: Text(switch (widget.action) {
              'handover' => 'Hand over',
              'returnOk' => 'Confirm return',
              _ => 'Report problem',
            }),
          ),
        ),
      ]),
    );
  }
}
