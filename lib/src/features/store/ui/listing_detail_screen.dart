import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/chat.dart';
import '../../../data/models/user_profile.dart';
import '../../../shared/widgets.dart';
import '../../chat/ui/chat_thread_screen.dart';
import '../../profile/ui/profile_screen.dart';
import '../data/listing.dart';
import '../data/store_repository.dart';
import 'edit_listing_screen.dart';
import 'request_rental_screen.dart';
import 'shop_screen.dart';
import 'store_widgets.dart';

class ListingDetailScreen extends StatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  late final _stream = StoreRepository.instance.watchListing(widget.listingId);
  final _page = PageController();
  int _photo = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    StoreRepository.instance.recordView(widget.listingId);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

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

  void _contact(Listing l) => _run(() async {
        final chatId = await StoreRepository.instance.contactOwner(l.id);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatThreadScreen(
              thread: ChatThread(
                id: chatId,
                otherUid: l.ownerId,
                name: l.ownerInfo.name,
                avatar: l.ownerInfo.photoUrl,
                lastMessage: '',
                lastTime: DateTime.now(),
                kind: 'store',
                listingId: l.id,
                listingTitle: l.title,
                listingCover: l.cover,
              ),
            ),
          ),
        );
      });

  Future<void> _report(Listing l, String myUid) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Report this listing'),
        children: [
          for (final r in ['Prohibited item', 'Counterfeit', 'Scam / suspicious', 'Wrong category', 'Other'])
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, r), child: Text(r)),
        ],
      ),
    );
    if (reason == null) return;
    await FirebaseFirestore.instance.collection('reports').add({
      'type': 'listing',
      'listingId': l.id,
      'reporterId': myUid,
      'reportedId': l.ownerId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) showSnack(context, 'Thanks — our team will review this listing.');
  }

  Future<void> _markSold(Listing l, String myUid) async {
    final buyers = await StoreRepository.instance.interestedBuyers(l.id, myUid);
    if (!mounted) return;
    if (buyers.isEmpty) {
      showSnack(context, 'The buyer must contact you through the app first.');
      return;
    }
    String? buyer = buyers.first.uid;
    String delivery = 'hand';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Mark as sold'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Who bought it?'),
            RadioGroup<String>(
              groupValue: buyer,
              onChanged: (v) => setD(() => buyer = v),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final b in buyers)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: b.uid,
                    secondary: Avatar(url: b.photoUrl),
                    title: Text(b.name),
                  ),
              ]),
            ),
            if (l.canShip) ...[
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'hand', label: Text('Hand delivery')),
                  ButtonSegment(value: 'ship', label: Text('Shipped')),
                ],
                selected: {delivery},
                onSelectionChanged: (s) => setD(() => delivery = s.first),
              ),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
          ],
        ),
      ),
    );
    if (ok == true && buyer != null) {
      await _run(() => StoreRepository.instance.markSold(l.id, buyer!, delivery), 'Marked as sold 🎉');
    }
  }

  Future<void> _boost(Listing l, UserProfile me) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Boost for 7 days'),
        content: Text(
          'Your listing appears first in searches nearby for 7 days.\n\n'
          '${me.isPremium ? 'Premium includes 2 free boosts per month.' : 'Price: ${euros(boostPriceEur)}'}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Boost')),
        ],
      ),
    );
    if (ok == true) {
      // TODO(payments): charge the boost via in-app purchase before calling the server.
      await _run(() => StoreRepository.instance.boost(l.id), 'Boosted for 7 days 🚀');
    }
  }

  Future<void> _ownerAction(Listing l, String action) async {
    if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete listing?'),
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
      await _run(() => StoreRepository.instance.setListingStatus(l.id, 'delete'));
      if (mounted) Navigator.pop(context);
      return;
    }
    await _run(() => StoreRepository.instance.setListingStatus(l.id, action));
  }

  @override
  Widget build(BuildContext context) {
    return MeBuilder(
      builder: (context, me) => StreamBuilder<Listing?>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final l = snap.data;
          if (l == null || l.status == 'removed') {
            return Scaffold(appBar: AppBar(), body: const Center(child: Text('This listing is no longer available.')));
          }
          return _buildPage(context, l, me);
        },
      ),
    );
  }

  Widget _buildPage(BuildContext context, Listing l, UserProfile me) {
    final cs = Theme.of(context).colorScheme;
    final mine = l.ownerId == me.uid;
    final km = formatKm(me.distanceKmTo(l.lat, l.lng));

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(
                  text: '${l.title} – ${listingPriceLabel(l)} on TrainMate (${l.area})'));
              if (context.mounted) showSnack(context, 'Copied to clipboard');
            },
          ),
          if (mine)
            PopupMenuButton<String>(
              onSelected: (a) async {
                if (a == 'edit') {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditListingScreen(me: me, listing: l)),
                  );
                } else if (a == 'sold') {
                  _markSold(l, me.uid);
                } else if (a == 'boost') {
                  _boost(l, me);
                } else {
                  _ownerAction(l, a);
                }
              },
              itemBuilder: (_) => [
                if (l.status != 'sold') const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (l.status == 'active') const PopupMenuItem(value: 'boost', child: Text('Boost')),
                if (l.status == 'active') const PopupMenuItem(value: 'reserve', child: Text('Mark as reserved')),
                if (l.status == 'reserved') const PopupMenuItem(value: 'unreserve', child: Text('Not reserved anymore')),
                if (l.mode.sells && ['active', 'reserved', 'paused'].contains(l.status))
                  const PopupMenuItem(value: 'sold', child: Text('Mark as sold')),
                if (['active', 'reserved'].contains(l.status)) const PopupMenuItem(value: 'pause', child: Text('Pause')),
                if (['paused', 'expired'].contains(l.status))
                  const PopupMenuItem(value: 'resume', child: Text('Put back online')),
                if (l.status != 'sold') const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            )
          else
            PopupMenuButton<String>(
              onSelected: (_) => _report(l, me.uid),
              itemBuilder: (_) => const [PopupMenuItem(value: 'report', child: Text('Report listing'))],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          AspectRatio(
            aspectRatio: 1.2,
            child: Stack(children: [
              PageView.builder(
                controller: _page,
                itemCount: l.photos.isEmpty ? 1 : l.photos.length,
                onPageChanged: (i) => setState(() => _photo = i),
                itemBuilder: (_, i) => l.photos.isEmpty
                    ? Container(color: Colors.grey.shade300)
                    : SizedBox.expand(child: coverImage(l.photos[i])),
              ),
              if (l.photos.length > 1)
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < l.photos.length; i++)
                        Container(
                          margin: const EdgeInsets.all(3),
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _photo ? Colors.white : Colors.white54,
                          ),
                        ),
                    ],
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (mine || l.status != 'active')
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    StatusChip.listing(l.status),
                    if (mine) ...[
                      const SizedBox(width: 8),
                      Text('${l.views} views', style: TextStyle(color: cs.onSurfaceVariant)),
                      if (l.isBoosted) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.rocket_launch, size: 16, color: Colors.orange),
                      ],
                    ],
                  ]),
                ),
              if (mine && l.status == 'pending_review')
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Our team is checking this listing. It will be visible once approved.'),
                ),
              Row(children: [
                ModePill(mode: l.mode),
                const SizedBox(width: 8),
                Text('${l.sport} · ${l.category}', style: TextStyle(color: cs.onSurfaceVariant)),
              ]),
              const SizedBox(height: 8),
              Text(l.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _Prices(l: l),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 4, children: [
                Chip(label: Text(l.condition), avatar: const Icon(Icons.auto_awesome, size: 16)),
                if (l.brand != null) Chip(label: Text(l.brand!)),
                if (l.size != null) Chip(label: Text('Size ${l.size}')),
                Chip(
                  avatar: const Icon(Icons.place_outlined, size: 16),
                  label: Text(km.isEmpty ? l.area : '${l.area} · $km'),
                ),
                if (l.mode.sells)
                  Chip(
                    avatar: const Icon(Icons.local_shipping_outlined, size: 16),
                    label: Text(l.canShip ? 'Hand delivery or shipping' : 'Hand delivery only'),
                  ),
              ]),
              const SizedBox(height: 12),
              Text(l.description),
              const Divider(height: 32),
              _OwnerCard(l: l),
              if (l.isPro) ...[
                const SizedBox(height: 8),
                Text('Pro seller: the 14-day withdrawal right applies.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
              if (!mine) ...[
                const SizedBox(height: 16),
                Text(
                  'Safety tips: meet in a public place, check the item before paying, '
                  'and never pay in advance to someone you don\'t know.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ]),
          ),
        ],
      ),
      bottomNavigationBar: mine || (!l.isAvailable && l.status != 'reserved')
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _contact(l),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Contact'),
                    ),
                  ),
                  if (l.mode.rents && l.isAvailable) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => RequestRentalScreen(listing: l)),
                                ),
                        icon: const Icon(Icons.event_available),
                        label: const Text('Rent'),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
    );
  }
}

class _Prices extends StatelessWidget {
  final Listing l;
  const _Prices({required this.l});

  @override
  Widget build(BuildContext context) {
    final big = Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800);
    final small = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (l.mode.sells)
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(euros(l.salePrice), style: big),
          if (l.canShip && l.shippingPrice != null)
            Text('  + ${euros(l.shippingPrice)} shipping', style: small),
        ]),
      if (l.mode.rents)
        Wrap(spacing: 16, children: [
          Text('${euros(l.rentPerDay)} / day', style: l.mode.sells ? null : big),
          if (l.rentPerWeekend != null) Text('${euros(l.rentPerWeekend)} / weekend', style: small),
          if (l.rentPerWeek != null) Text('${euros(l.rentPerWeek)} / week', style: small),
          Text('${l.minDays}–${l.maxDays} days', style: small),
        ]),
    ]);
  }
}

class _OwnerCard extends StatelessWidget {
  final Listing l;
  const _OwnerCard({required this.l});

  @override
  Widget build(BuildContext context) {
    final o = l.ownerInfo;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Avatar(url: o.photoUrl, radius: 24),
      title: Row(children: [
        Flexible(child: Text(o.name, overflow: TextOverflow.ellipsis)),
        if (o.verified) ...[const SizedBox(width: 4), const VerifiedBadge()],
        if (l.isPro) ...[const SizedBox(width: 4), const ProBadge()],
      ]),
      subtitle: RatingLabel(rating: o.rating, count: o.reviewCount),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => l.isPro && l.shopId != null
              ? ShopScreen(shopId: l.shopId!)
              : ProfileScreen(uid: l.ownerId),
        ),
      ),
    );
  }
}
