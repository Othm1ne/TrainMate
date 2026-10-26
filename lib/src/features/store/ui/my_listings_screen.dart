import 'package:flutter/material.dart';
import '../../../shared/widgets.dart';
import '../data/listing.dart';
import '../data/store_repository.dart';
import 'edit_listing_screen.dart';
import 'listing_detail_screen.dart';
import 'store_widgets.dart';

class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context) => MeBuilder(builder: (context, me) {
        return Scaffold(
          appBar: AppBar(title: const Text('My listings')),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => EditListingScreen(me: me))),
            child: const Icon(Icons.add),
          ),
          body: StreamBuilder<List<Listing>>(
            stream: StoreRepository.instance.myListings(me.uid),
            builder: (context, snap) {
              if (snap.hasError) return const Center(child: Text('Could not load your listings.'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final list = snap.data!;
              final live = list
                  .where((l) => ['active', 'pending_review', 'reserved', 'paused'].contains(l.status))
                  .length;
              final unlimited = me.isPremium || me.hasApprovedShop;
              return ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  ListTile(
                    title: Text(unlimited
                        ? '$live active listings'
                        : '$live / $freeActiveListings active listings'),
                    subtitle: unlimited ? null : const Text('Go Premium for unlimited listings.'),
                  ),
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Nothing here yet. Sell or rent out the gear you don\'t use!',
                          textAlign: TextAlign.center),
                    ),
                  for (final l in list)
                    ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(width: 56, height: 56, child: coverImage(l.cover)),
                      ),
                      title: Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Row(children: [
                        StatusChip.listing(l.status),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text('${listingPriceLabel(l)} · ${l.views} views',
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (l.isBoosted) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.rocket_launch, size: 14, color: Colors.orange),
                        ],
                      ]),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: l.id)),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      });
}
