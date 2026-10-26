import 'package:flutter/material.dart';
import '../../../shared/widgets.dart';
import '../data/booking.dart';
import '../data/listing.dart';
import '../data/rental_pricing.dart';
import '../data/store_repository.dart';
import 'booking_detail_screen.dart';

/// Pick dates (booked days greyed out), see the price, send a request.
class RequestRentalScreen extends StatefulWidget {
  final Listing listing;
  const RequestRentalScreen({super.key, required this.listing});

  @override
  State<RequestRentalScreen> createState() => _RequestRentalScreenState();
}

class _RequestRentalScreenState extends State<RequestRentalScreen> {
  Set<String>? _blocked;
  DateTimeRange? _range;
  final _message = TextEditingController();
  bool _sending = false;

  Listing get l => widget.listing;
  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    StoreRepository.instance.blockedDays(l.id).then((b) {
      if (mounted) setState(() => _blocked = b);
    }).catchError((Object e) {
      if (mounted) setState(() => _blocked = {});
    });
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  bool _isBlocked(DateTime d) => _blocked!.contains(dayKey(d));

  /// A day is selectable if it's free, and — once a start is picked — the
  /// range from the start to it has no booked day and fits max days.
  bool _selectable(DateTime day, DateTime? start, DateTime? end) {
    if (_isBlocked(day)) return false;
    if (start != null && end == null && !day.isBefore(start)) {
      if (rentalDays(start, day) > l.maxDays) return false;
      for (var d = start; !d.isAfter(day); d = d.add(const Duration(days: 1))) {
        if (_isBlocked(d)) return false;
      }
    }
    return true;
  }

  Future<void> _pick() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: 180)),
      initialDateRange: _range,
      selectableDayPredicate: _selectable,
      helpText: 'Booked days are greyed out',
    );
    if (r == null) return;
    final days = rentalDays(r.start, r.end);
    if (days < l.minDays) {
      if (mounted) showSnack(context, 'Minimum rental: ${l.minDays} days.');
      return;
    }
    setState(() => _range = r);
  }

  double? get _price => _range == null
      ? null
      : rentalPrice(
          perDay: l.rentPerDay!,
          perWeekend: l.rentPerWeekend,
          perWeek: l.rentPerWeek,
          start: _range!.start,
          end: _range!.end,
        );

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final res = await StoreRepository.instance.requestRental(
        listingId: l.id,
        start: _range!.start,
        end: _range!.end,
        message: _message.text.trim(),
      );
      if (!mounted) return;
      showSnack(context, 'Request sent. The owner has 48 h to answer.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: res.bookingId)),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        showSnack(context, storeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final price = _price;
    final days = _range == null ? 0 : rentalDays(_range!.start, _range!.end);
    return Scaffold(
      appBar: AppBar(title: const Text('Request a rental')),
      body: _blocked == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(width: 56, height: 56, child: coverImage(l.cover)),
                  ),
                  title: Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${euros(l.rentPerDay)}/day · ${l.minDays}–${l.maxDays} days'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pick,
                  icon: const Icon(Icons.date_range),
                  label: Text(_range == null
                      ? 'Choose dates'
                      : '${formatDay(dayKey(_range!.start))} – ${formatDay(dayKey(_range!.end))} · $days day${days > 1 ? 's' : ''}'),
                ),
                if (price != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        _row('$days × ${euros(l.rentPerDay)}', euros(days * l.rentPerDay!)),
                        if (price < days * l.rentPerDay!)
                          _row('Weekly / weekend price applied', '−${euros(days * l.rentPerDay! - price)}',
                              color: Colors.green),
                        const Divider(),
                        _row('Total', euros(price), bold: true),
                        // TODO(deposit): show the deposit hold here once in-app payments exist.
                        const SizedBox(height: 8),
                        Text(
                          'You pay the owner directly at pickup. No deposit is taken in the app.',
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _message,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Message to the owner (optional)',
                    hintText: 'Hi! I\'d like to try padel this weekend…',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The owner has 48 h to accept. At pickup and return you both check the '
                  'item and take photos in the app.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: _range == null || _sending ? null : _send,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _sending
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(price == null ? 'Choose dates' : 'Send request · ${euros(price)}'),
          ),
        ),
      ),
    );
  }

  Widget _row(String a, String b, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(a, style: TextStyle(fontWeight: bold ? FontWeight.w800 : null, color: color))),
          Text(b, style: TextStyle(fontWeight: bold ? FontWeight.w800 : null, color: color)),
        ]),
      );
}
