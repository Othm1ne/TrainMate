import 'package:flutter/material.dart';
import '../../../data/models/user_profile.dart';
import '../../../shared/widgets.dart';
import '../data/booking.dart';
import '../data/listing.dart';
import '../data/store_repository.dart';
import 'booking_detail_screen.dart';
import 'review_sheet.dart';
import 'store_widgets.dart';

/// Rentals as owner and as renter (Requests · Upcoming · Active · Past) + sales.
class MyRentalsScreen extends StatelessWidget {
  const MyRentalsScreen({super.key});

  static const _tabs = {
    'Requests': ['requested'],
    'Upcoming': ['accepted'],
    'Active': ['picked_up', 'disputed'],
    'Past': ['completed', 'declined', 'expired', 'cancelled', 'resolved'],
  };

  @override
  Widget build(BuildContext context) => MeBuilder(builder: (context, me) {
        return DefaultTabController(
          length: _tabs.length + 1,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Rentals & purchases'),
              bottom: TabBar(
                isScrollable: true,
                tabs: [for (final t in _tabs.keys) Tab(text: t), const Tab(text: 'Bought & sold')],
              ),
            ),
            body: StreamBuilder<List<Booking>>(
              stream: StoreRepository.instance.myBookings(me.uid),
              builder: (context, snap) {
                if (snap.hasError) return const Center(child: Text('Could not load your rentals.'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                return TabBarView(children: [
                  for (final statuses in _tabs.values)
                    _BookingList(
                      me: me,
                      bookings: snap.data!.where((b) => statuses.contains(b.status)).toList(),
                    ),
                  _SalesList(me: me),
                ]);
              },
            ),
          ),
        );
      });
}

class _BookingList extends StatelessWidget {
  final UserProfile me;
  final List<Booking> bookings;
  const _BookingList({required this.me, required this.bookings});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) return const Center(child: Text('Nothing here.'));
    return ListView.separated(
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final b = bookings[i];
        final owner = b.isOwner(me.uid);
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(width: 52, height: 52, child: coverImage(b.cover)),
          ),
          title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${owner ? 'Lending to' : 'Renting from'} ${b.otherInfo(me.uid).name}\n${b.dateLabel} · ${euros(b.price)}',
          ),
          isThreeLine: true,
          trailing: StatusChip.booking(b.status),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: b.id)),
          ),
        );
      },
    );
  }
}

class _SalesList extends StatelessWidget {
  final UserProfile me;
  const _SalesList({required this.me});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Sale>>(
      stream: StoreRepository.instance.mySales(me.uid),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final sales = snap.data!;
        if (sales.isEmpty) return const Center(child: Text('No purchases or sales yet.'));
        return ListView.separated(
          itemCount: sales.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final s = sales[i];
            final selling = s.sellerId == me.uid;
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(width: 52, height: 52, child: coverImage(s.cover)),
              ),
              title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${selling ? 'Sold' : 'Bought'} · ${euros(s.price)} · '
                  '${s.delivery == 'ship' ? 'shipped' : 'hand delivery'}'),
              trailing: s.canReview
                  ? _ReviewButton(sale: s, myUid: me.uid)
                  : null,
            );
          },
        );
      },
    );
  }
}

class _ReviewButton extends StatefulWidget {
  final Sale sale;
  final String myUid;
  const _ReviewButton({required this.sale, required this.myUid});
  @override
  State<_ReviewButton> createState() => _ReviewButtonState();
}

class _ReviewButtonState extends State<_ReviewButton> {
  late Future<bool> _done = StoreRepository.instance.hasReviewed('sale', widget.sale.id, widget.myUid);

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: _done,
        builder: (context, snap) {
          if (snap.data != false) return const SizedBox.shrink();
          return TextButton(
            onPressed: () async {
              final ok = await showReviewSheet(
                context,
                reviewContext: 'sale',
                refId: widget.sale.id,
                otherName: widget.sale.sellerId == widget.myUid ? 'the buyer' : 'the seller',
              );
              if (ok) setState(() => _done = Future.value(true));
            },
            child: const Text('Review'),
          );
        },
      );
}
