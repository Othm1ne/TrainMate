import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/widgets.dart';
import '../data/booking.dart';
import '../data/listing.dart';
import '../data/store_repository.dart';
import 'listing_detail_screen.dart';
import 'store_widgets.dart';
import 'verify_screen.dart';

/// Public page of an approved pro shop, with DSA trader details.
class ShopScreen extends StatelessWidget {
  final String shopId;
  const ShopScreen({super.key, required this.shopId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Shop?>(
      stream: StoreRepository.instance.watchShop(shopId),
      builder: (context, snap) {
        final shop = snap.data;
        if (shop == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: snap.connectionState == ConnectionState.waiting
                  ? const CircularProgressIndicator()
                  : const Text('This shop is not available.'),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(shop.companyName)),
          body: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const ProBadge(),
                    const SizedBox(width: 8),
                    if (shop.status != 'approved') StatusChip(label: shop.status, color: Colors.orange),
                  ]),
                  if (shop.description != null) ...[const SizedBox(height: 8), Text(shop.description!)],
                  const SizedBox(height: 8),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Seller information'),
                    children: [
                      _info(Icons.business, shop.companyName),
                      _info(Icons.badge_outlined, 'SIRET ${shop.siret}'),
                      _info(Icons.place_outlined, shop.address),
                      _info(Icons.email_outlined, shop.email),
                      _info(Icons.phone_outlined, shop.phone),
                      if (shop.termsUrl != null) _info(Icons.description_outlined, shop.termsUrl!),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Professional seller: the 14-day withdrawal right and legal warranties apply.'),
                      ),
                    ],
                  ),
                ]),
              ),
            ),
            StreamBuilder<List<Listing>>(
              stream: StoreRepository.instance.shopListings(shopId),
              builder: (context, snap) {
                final list = snap.data ?? const [];
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.68,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => ListingCard(
                        listing: list[i],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: list[i].id)),
                        ),
                      ),
                      childCount: list.length,
                    ),
                  ),
                );
              },
            ),
          ]),
        );
      },
    );
  }

  Widget _info(IconData icon, String text) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, size: 20),
        title: Text(text),
      );
}

/// "Open a pro shop" form (spec §4.4). Admin approves it in the console.
class ShopApplyScreen extends StatefulWidget {
  const ShopApplyScreen({super.key});
  @override
  State<ShopApplyScreen> createState() => _ShopApplyScreenState();
}

class _ShopApplyScreenState extends State<ShopApplyScreen> {
  final _c = {
    for (final k in ['companyName', 'siret', 'address', 'email', 'phone', 'termsUrl', 'description'])
      k: TextEditingController(),
  };
  bool _sending = false;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await StoreRepository.instance.applyForShop({
        for (final e in _c.entries) e.key: e.value.text.trim().isEmpty ? null : e.value.text.trim(),
      });
      if (!mounted) return;
      showSnack(context, 'Application sent. We\'ll check your details within 2 working days.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        showSnack(context, storeError(e));
      }
    }
  }

  Widget _field(String key, String label, {String? helper, TextInputType? type, int maxLines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _c[key],
          keyboardType: type,
          maxLines: maxLines,
          inputFormatters: key == 'siret' ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))] : null,
          decoration: storeFieldDeco(label, helper: helper),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return MeBuilder(builder: (context, me) {
      if (!me.verified) {
        return Scaffold(
          appBar: AppBar(title: const Text('Open a pro shop')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Get verified first: pro shops are run by verified members.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const VerifyScreen())),
                  child: const Text('Get verified'),
                ),
              ]),
            ),
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Open a pro shop')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'For sports shops and rental businesses. Your listings get a Pro badge and no listing limit. '
              'EU law requires us to show these details to customers.',
            ),
            const SizedBox(height: 16),
            _field('companyName', 'Company name'),
            _field('siret', 'SIRET (14 digits)', type: TextInputType.number),
            _field('address', 'Business address', maxLines: 2),
            _field('email', 'Contact email', type: TextInputType.emailAddress),
            _field('phone', 'Contact phone', type: TextInputType.phone),
            _field('termsUrl', 'Terms / returns policy link (optional)',
                type: TextInputType.url, helper: 'https://…'),
            _field('description', 'Shop description (optional)', maxLines: 3),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Send application'),
            ),
          ],
        ),
      );
    });
  }
}
