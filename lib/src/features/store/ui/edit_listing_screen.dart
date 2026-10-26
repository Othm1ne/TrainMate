import 'package:flutter/material.dart';
import '../../../data/models/user_profile.dart';
import '../../../shared/sports.dart';
import '../../../shared/widgets.dart';
import '../data/listing.dart';
import '../data/store_repository.dart';
import 'store_widgets.dart';
import 'verify_screen.dart';

/// Post or edit a listing: Photos → Details → Price & terms → Preview.
class EditListingScreen extends StatefulWidget {
  final UserProfile me;
  final Listing? listing; // null = new listing
  const EditListingScreen({super.key, required this.me, this.listing});

  @override
  State<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
  late final _id = widget.listing?.id ?? StoreRepository.instance.newListingId();
  int _step = 0;
  bool _saving = false;

  late List<String> _photos = [...?widget.listing?.photos];
  late final _title = TextEditingController(text: widget.listing?.title);
  late final _desc = TextEditingController(text: widget.listing?.description);
  late final _brand = TextEditingController(text: widget.listing?.brand);
  late final _size = TextEditingController(text: widget.listing?.size);
  late final _area = TextEditingController(text: widget.listing?.area ?? widget.me.location);
  late String _sport = widget.listing?.sport ??
      (widget.me.sports.isNotEmpty ? widget.me.sports.first : allSports.first);
  late String _category = widget.listing?.category ?? listingCategories.first;
  late String _condition = widget.listing?.condition ?? 'Good';
  late ListingMode _mode = widget.listing?.mode ?? ListingMode.sale;
  late final _salePrice = TextEditingController(text: _num(widget.listing?.salePrice));
  late final _perDay = TextEditingController(text: _num(widget.listing?.rentPerDay));
  late final _perWeekend = TextEditingController(text: _num(widget.listing?.rentPerWeekend));
  late final _perWeek = TextEditingController(text: _num(widget.listing?.rentPerWeek));
  late int _minDays = widget.listing?.minDays ?? 1;
  late int _maxDays = widget.listing?.maxDays ?? 14;
  late bool _canShip = widget.listing?.canShip ?? false;
  late final _shipping = TextEditingController(text: _num(widget.listing?.shippingPrice));

  static String _num(double? v) =>
      v == null ? '' : (v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2));
  static double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    for (final c in [_title, _desc, _brand, _size, _area, _salePrice, _perDay, _perWeekend, _perWeek, _shipping]) {
      c.dispose();
    }
    super.dispose();
  }

  Listing _draft() => Listing(
        id: _id,
        ownerId: widget.me.uid,
        title: _title.text.trim(),
        description: _desc.text.trim(),
        sport: _sport,
        category: _category,
        condition: _condition,
        brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
        size: _size.text.trim().isEmpty ? null : _size.text.trim(),
        mode: _mode,
        salePrice: _parse(_salePrice),
        rentPerDay: _parse(_perDay),
        rentPerWeekend: _parse(_perWeekend),
        rentPerWeek: _parse(_perWeek),
        minDays: _minDays,
        maxDays: _maxDays,
        canShip: _canShip,
        shippingPrice: _parse(_shipping),
        photos: _photos,
        area: _area.text.trim(),
        lat: widget.me.lat,
        lng: widget.me.lng,
        sellerType: widget.me.hasApprovedShop ? 'pro' : 'private',
        createdAt: DateTime.now(),
      );

  /// Client-side checks mirroring the server, so errors show on the right step.
  String? _validate(int step) {
    switch (step) {
      case 0:
        return _photos.isEmpty ? 'Add at least one photo.' : null;
      case 1:
        if (_title.text.trim().length < 5) return 'Title: at least 5 characters.';
        if (_desc.text.trim().length < 20) return 'Description: at least 20 characters.';
        return null;
      case 2:
        if (_mode.rents && !widget.me.verified) return 'Get verified to rent out equipment.';
        if (_mode.sells && (_parse(_salePrice) ?? 0) <= 0) return 'Enter a sale price.';
        if (_mode.rents && (_parse(_perDay) ?? 0) <= 0) return 'Enter a price per day.';
        if (_mode.sells && _canShip && _parse(_shipping) == null) return 'Enter the shipping price.';
        if (_area.text.trim().length < 2) return 'Enter the pickup area.';
        return null;
    }
    return null;
  }

  void _next() {
    final err = _validate(_step);
    if (err != null) {
      showSnack(context, err);
      return;
    }
    if (_step < 3) setState(() => _step++);
  }

  Future<void> _save() async {
    for (var s = 0; s < 3; s++) {
      final err = _validate(s);
      if (err != null) {
        setState(() => _step = s);
        showSnack(context, err);
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final status = await StoreRepository.instance.saveListing(_draft(), widget.me.uid);
      if (!mounted) return;
      showSnack(
        context,
        status == 'pending_review'
            ? 'Saved. Your listing will be visible once our team has reviewed it.'
            : widget.listing == null
                ? 'Your listing is live 🎉'
                : 'Listing updated',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, storeError(e));
      }
    }
  }

  Future<void> _getVerified() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const VerifyScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.listing == null ? 'New listing' : 'Edit listing')),
      body: Stepper(
        currentStep: _step,
        onStepTapped: (s) => setState(() => _step = s),
        onStepContinue: _step == 3 ? (_saving ? null : _save) : _next,
        onStepCancel: _step == 0 ? null : () => setState(() => _step--),
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(children: [
            FilledButton(
              onPressed: details.onStepContinue,
              child: _saving
                  ? const SizedBox(
                      height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_step == 3 ? (widget.listing == null ? 'Publish' : 'Save') : 'Next'),
            ),
            if (details.onStepCancel != null)
              TextButton(onPressed: details.onStepCancel, child: const Text('Back')),
          ]),
        ),
        steps: [
          Step(
            title: const Text('Photos'),
            subtitle: Text('${_photos.length}/$maxListingPhotos · first one is the cover'),
            isActive: _step >= 0,
            content: PhotoPickerRow(
              photos: _photos,
              max: maxListingPhotos,
              onChanged: (p) => setState(() => _photos = p),
            ),
          ),
          Step(title: const Text('Details'), isActive: _step >= 1, content: _details()),
          Step(title: const Text('Price & terms'), isActive: _step >= 2, content: _terms()),
          Step(title: const Text('Preview'), isActive: _step >= 3, content: _preview()),
        ],
      ),
    );
  }

  Widget _details() {
    return Column(children: [
      TextField(
        controller: _title,
        maxLength: 80,
        textCapitalization: TextCapitalization.sentences,
        decoration: storeFieldDeco('Title', helper: 'e.g. "Bullpadel Vertex 03 padel racket"'),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _desc,
        minLines: 3,
        maxLines: 8,
        maxLength: 2000,
        textCapitalization: TextCapitalization.sentences,
        decoration: storeFieldDeco('Description', helper: 'Condition details, what is included, why you sell…'),
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: _sport,
        decoration: storeFieldDeco('Sport'),
        items: allSports.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: (v) => setState(() => _sport = v ?? _sport),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: _category,
        decoration: storeFieldDeco('Category'),
        items: listingCategories.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: (v) => setState(() => _category = v ?? _category),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: Wrap(spacing: 8, children: [
          for (final c in listingConditions)
            ChoiceChip(
              label: Text(c),
              selected: _condition == c,
              onSelected: (_) => setState(() => _condition = c),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: _brand, decoration: storeFieldDeco('Brand (optional)'))),
        const SizedBox(width: 12),
        Expanded(child: TextField(controller: _size, decoration: storeFieldDeco('Size (optional)'))),
      ]),
    ]);
  }

  Widget _terms() {
    final me = widget.me;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SegmentedButton<ListingMode>(
        segments: const [
          ButtonSegment(value: ListingMode.sale, label: Text('Sell')),
          ButtonSegment(value: ListingMode.rent, label: Text('Rent out')),
          ButtonSegment(value: ListingMode.both, label: Text('Both')),
        ],
        selected: {_mode},
        onSelectionChanged: (s) => setState(() => _mode = s.first),
      ),
      if (_mode.rents && !me.verified)
        Card(
          color: Colors.blue.shade50,
          margin: const EdgeInsets.only(top: 12),
          child: ListTile(
            leading: const Icon(Icons.verified_outlined, color: Colors.blue),
            title: const Text('Renting out is for verified members'),
            subtitle: const Text('Confirm your email and phone number — it takes a minute.'),
            trailing: TextButton(onPressed: _getVerified, child: const Text('Verify')),
          ),
        ),
      if (_mode.sells) ...[
        const SizedBox(height: 16),
        TextField(
          controller: _salePrice,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: storeFieldDeco('Sale price', suffix: '€'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('I can ship it'),
          subtitle: const Text('Hand delivery is always possible. You arrange shipping with the buyer.'),
          value: _canShip,
          onChanged: (v) => setState(() => _canShip = v),
        ),
        if (_canShip)
          TextField(
            controller: _shipping,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: storeFieldDeco('Shipping price', suffix: '€'),
          ),
      ],
      if (_mode.rents) ...[
        const SizedBox(height: 16),
        const Text('Rental prices', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: _perDay,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: storeFieldDeco('Per day', suffix: '€'),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _perWeekend,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: storeFieldDeco('Weekend (optional)', suffix: '€'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _perWeek,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: storeFieldDeco('Week (optional)', suffix: '€'),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const Text('Rental length'),
          const Spacer(),
          DropdownButton<int>(
            value: _minDays,
            items: [for (var i = 1; i <= 7; i++) DropdownMenuItem(value: i, child: Text('min $i d'))],
            onChanged: (v) => setState(() {
              _minDays = v!;
              if (_maxDays < _minDays) _maxDays = _minDays;
            }),
          ),
          const SizedBox(width: 12),
          DropdownButton<int>(
            value: _maxDays,
            items: [
              for (final i in {1, 2, 3, 5, 7, 14, 21, 30, 60, 90}.where((i) => i >= _minDays))
                DropdownMenuItem(value: i, child: Text('max $i d')),
            ],
            onChanged: (v) => setState(() => _maxDays = v!),
          ),
        ]),
        // TODO(deposit): deposit amount field, collected in-app with V3 payments.
        Text(
          'No deposit is collected in the app yet. Check the item carefully with the renter at pickup and return.',
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
      const SizedBox(height: 16),
      TextField(
        controller: _area,
        decoration: storeFieldDeco('Pickup area', helper: 'Neighbourhood or city. Give the exact address only in the chat.'),
      ),
      if (me.hasApprovedShop)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('This listing will show your Pro badge. The 14-day withdrawal right applies.'),
        ),
    ]);
  }

  Widget _preview() {
    final l = _draft();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 200,
        height: 290,
        child: ListingCard(listing: l, onTap: () {}),
      ),
      const SizedBox(height: 12),
      Text(
        'By publishing you confirm the item is not on the prohibited list '
        '(supplements, medication, weapons, counterfeits, used underwear, crashed helmets).',
        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ]);
  }
}
