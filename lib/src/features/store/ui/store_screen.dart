import 'dart:async';

import 'package:flutter/material.dart';
import '../../../data/models/user_profile.dart';
import '../../../shared/sports.dart';
import '../../../shared/widgets.dart';
import '../data/booking.dart';
import '../data/listing.dart';
import '../data/rental_pricing.dart';
import '../data/store_repository.dart';
import 'edit_listing_screen.dart';
import 'listing_detail_screen.dart';
import 'my_listings_screen.dart';
import 'my_rentals_screen.dart';
import 'store_widgets.dart';

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) => MeBuilder(builder: (_, me) => _Store(me: me));
}

class _Store extends StatefulWidget {
  final UserProfile me;
  const _Store({required this.me});
  @override
  State<_Store> createState() => _StoreState();
}

class _StoreState extends State<_Store> {
  final _search = TextEditingController();
  Timer? _debounce;
  StoreFilter _filter = const StoreFilter();
  List<FeedItem>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await StoreRepository.instance.feed(widget.me, _filter);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load the store.');
    }
  }

  void _apply(StoreFilter f) {
    setState(() {
      _filter = f;
      _items = null;
    });
    _load();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _apply(_filter.copyWith(query: q)));
  }

  Future<void> _openFilters() async {
    final f = await showModalBottomSheet<StoreFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(initial: _filter, mySports: widget.me.sports),
    );
    if (f != null) _apply(f);
  }

  Future<void> _post() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditListingScreen(me: widget.me)),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.storefront_outlined),
            tooltip: 'My store',
            onSelected: (v) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => v == 'listings' ? const MyListingsScreen() : const MyRentalsScreen(),
              ),
            ),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'listings', child: Text('My listings')),
              PopupMenuItem(value: 'rentals', child: Text('My rentals & purchases')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _post,
        icon: const Icon(Icons.add),
        label: const Text('Sell / Rent out'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: _onSearch,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search racket, bike, board…',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Filters',
                onPressed: _openFilters,
                icon: Badge(
                  isLabelVisible: _filter.activeCount > 0,
                  label: Text('${_filter.activeCount}'),
                  child: const Icon(Icons.tune),
                ),
              ),
            ]),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final d in DealType.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(switch (d) {
                        DealType.any => 'All',
                        DealType.buy => 'Buy',
                        DealType.rent => 'Rent',
                      }),
                      selected: _filter.deal == d,
                      onSelected: (_) => _apply(_filter.copyWith(deal: d)),
                    ),
                  ),
                const VerticalDivider(width: 16, indent: 8, endIndent: 8),
                PopupMenuButton<StoreSort>(
                  initialValue: _filter.sort,
                  onSelected: (s) => _apply(_filter.copyWith(sort: s)),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: StoreSort.relevant, child: Text('For you')),
                    PopupMenuItem(value: StoreSort.nearest, child: Text('Nearest')),
                    PopupMenuItem(value: StoreSort.newest, child: Text('Newest')),
                    PopupMenuItem(value: StoreSort.priceLow, child: Text('Price: low to high')),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.sort, size: 18),
                    label: Text(switch (_filter.sort) {
                      StoreSort.relevant => 'For you',
                      StoreSort.nearest => 'Nearest',
                      StoreSort.newest => 'Newest',
                      StoreSort.priceLow => 'Cheapest',
                    }),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }
    final items = _items;
    if (items == null) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: [
          const SizedBox(height: 80),
          const Icon(Icons.storefront, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            _filter.activeCount > 0 || _filter.query.isNotEmpty
                ? 'Nothing matches. Try widening your filters.'
                : 'No equipment nearby yet.\nBe the first to sell or rent out your gear!',
            textAlign: TextAlign.center,
          ),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.68,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => ListingCard(
          listing: items[i].listing,
          distanceKm: items[i].distanceKm,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: items[i].listing.id)),
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final StoreFilter initial;
  final List<String> mySports;
  const _FilterSheet({required this.initial, required this.mySports});
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late StoreFilter f = widget.initial;
  late final _min = TextEditingController(text: _num(widget.initial.minPrice));
  late final _max = TextEditingController(text: _num(widget.initial.maxPrice));
  static const _distances = <double?>[null, 5, 10, 25, 50];

  static String _num(double? v) => v == null ? '' : v.toStringAsFixed(0);

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 180)),
      initialDateRange: f.from == null ? null : DateTimeRange(start: f.from!, end: f.to!),
      helpText: 'Rental dates',
    );
    if (r != null) {
      setState(() => f = f.copyWith(from: () => r.start, to: () => r.end, deal: DealType.rent));
    }
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) {
    final sports = [...widget.mySports, ...allSports.where((s) => !widget.mySports.contains(s))];
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .85,
        maxChildSize: .95,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            _title('Sport'),
            DropdownButtonFormField<String?>(
              initialValue: f.sport,
              items: [
                const DropdownMenuItem(value: null, child: Text('All sports')),
                ...sports.map((s) => DropdownMenuItem(value: s, child: Text(s))),
              ],
              onChanged: (v) => setState(() => f = f.copyWith(sport: () => v)),
            ),
            _title('Category'),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final c in [null, ...listingCategories])
                ChoiceChip(
                  label: Text(c ?? 'All'),
                  selected: f.category == c,
                  onSelected: (_) => setState(() => f = f.copyWith(category: () => c)),
                ),
            ]),
            _title('Rental dates'),
            OutlinedButton.icon(
              onPressed: _pickDates,
              icon: const Icon(Icons.date_range),
              label: Text(f.from == null
                  ? 'Any dates'
                  : '${formatDay(dayKey(f.from!))} – ${formatDay(dayKey(f.to!))}'),
            ),
            if (f.from != null)
              TextButton(
                onPressed: () => setState(() => f = f.copyWith(from: () => null, to: () => null)),
                child: const Text('Clear dates'),
              ),
            _title(f.deal == DealType.rent ? 'Price per day (€)' : 'Price (€)'),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _min,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Min'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _max,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Max'),
                ),
              ),
            ]),
            _title('Condition'),
            Wrap(spacing: 8, children: [
              for (final c in listingConditions)
                FilterChip(
                  label: Text(c),
                  selected: f.conditions.contains(c),
                  onSelected: (on) => setState(() => f = f.copyWith(
                        conditions: on ? {...f.conditions, c} : ({...f.conditions}..remove(c)),
                      )),
                ),
            ]),
            _title('Distance'),
            Wrap(spacing: 8, children: [
              for (final d in _distances)
                ChoiceChip(
                  label: Text(d == null ? 'Any' : '< ${d.toInt()} km'),
                  selected: f.maxKm == d,
                  onSelected: (_) => setState(() => f = f.copyWith(maxKm: () => d)),
                ),
            ]),
            _title('Seller'),
            Wrap(spacing: 8, children: [
              for (final (v, label) in [(null, 'All'), ('private', 'Private'), ('pro', 'Pro shops')])
                ChoiceChip(
                  label: Text(label),
                  selected: f.sellerType == v,
                  onSelected: (_) => setState(() => f = f.copyWith(sellerType: () => v)),
                ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Can ship'),
              value: f.canShipOnly,
              onChanged: (v) => setState(() => f = f.copyWith(canShipOnly: v)),
            ),
            const SizedBox(height: 16),
            Row(children: [
              TextButton(
                onPressed: () => Navigator.pop(
                    context, StoreFilter(query: widget.initial.query, sort: widget.initial.sort)),
                child: const Text('Reset'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  f.copyWith(
                    minPrice: () => double.tryParse(_min.text.replaceAll(',', '.')),
                    maxPrice: () => double.tryParse(_max.text.replaceAll(',', '.')),
                  ),
                ),
                child: const Text('Show results'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
