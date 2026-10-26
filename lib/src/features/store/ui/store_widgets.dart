import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/widgets.dart';
import '../data/booking.dart';
import '../data/listing.dart';

class VerifiedBadge extends StatelessWidget {
  final double size;
  const VerifiedBadge({super.key, this.size = 16});
  @override
  Widget build(BuildContext context) =>
      Tooltip(message: 'Verified', child: Icon(Icons.verified, size: size, color: Colors.blue));
}

class ProBadge extends StatelessWidget {
  const ProBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: Colors.indigo, borderRadius: BorderRadius.circular(6)),
        child: const Text('PRO',
            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
      );
}

class RatingLabel extends StatelessWidget {
  final double? rating;
  final int count;
  final double size;
  const RatingLabel({super.key, required this.rating, required this.count, this.size = 13});
  @override
  Widget build(BuildContext context) {
    if (rating == null || count == 0) {
      return Text('New', style: TextStyle(fontSize: size, color: Colors.grey.shade600));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.star_rounded, size: size + 3, color: Colors.amber.shade700),
      const SizedBox(width: 2),
      Text('${rating!.toStringAsFixed(1)} ($count)', style: TextStyle(fontSize: size)),
    ]);
  }
}

class ModePill extends StatelessWidget {
  final ListingMode mode;
  const ModePill({super.key, required this.mode});
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (mode) {
      ListingMode.sale => ('For sale', Colors.green),
      ListingMode.rent => ('For rent', Colors.deepPurple),
      ListingMode.both => ('Sale · Rent', Colors.teal),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: .9), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip({super.key, required this.label, required this.color});

  factory StatusChip.booking(String status) => StatusChip(
        label: bookingStatusLabels[status] ?? status,
        color: switch (status) {
          'requested' => Colors.orange,
          'accepted' => Colors.blue,
          'picked_up' => Colors.deepPurple,
          'completed' || 'resolved' => Colors.green,
          'disputed' => Colors.red,
          _ => Colors.grey,
        },
      );

  factory StatusChip.listing(String status) => StatusChip(
        label: listingStatusLabels[status] ?? status,
        color: switch (status) {
          'active' => Colors.green,
          'pending_review' => Colors.orange,
          'reserved' => Colors.blue,
          'sold' => Colors.indigo,
          _ => Colors.grey,
        },
      );

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

/// Grid card used in the Store feed and on profiles/shop pages.
class ListingCard extends StatelessWidget {
  final Listing listing;
  final double? distanceKm;
  final VoidCallback onTap;
  const ListingCard({super.key, required this.listing, this.distanceKm, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = listing;
    final cs = Theme.of(context).colorScheme;
    final km = formatKm(distanceKm);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(fit: StackFit.expand, children: [
                coverImage(l.cover),
                Positioned(left: 6, top: 6, child: ModePill(mode: l.mode)),
                if (l.isBoosted)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                      child: const Text('Sponsored',
                          style: TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listingPriceLabel(l),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(l.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 2),
                  Row(children: [
                    if (l.isPro) ...[const ProBadge(), const SizedBox(width: 4)],
                    if (l.ownerInfo.verified && !l.isPro) ...[
                      const VerifiedBadge(size: 13),
                      const SizedBox(width: 4)
                    ],
                    Expanded(
                      child: Text(
                        [if (km.isNotEmpty) km else l.area, if (l.canShip) 'ships'].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal list of photos (URLs or local paths) with add/remove.
class PhotoPickerRow extends StatelessWidget {
  final List<String> photos;
  final int max;
  final ValueChanged<List<String>> onChanged;
  const PhotoPickerRow({super.key, required this.photos, required this.max, required this.onChanged});

  Future<void> _add(BuildContext context) async {
    final picker = ImagePicker();
    // Phones: offer the camera (condition photos are taken on the spot).
    final source = kIsWeb
        ? ImageSource.gallery
        : await showModalBottomSheet<ImageSource>(
            context: context,
            builder: (ctx) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take a photo'),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ]),
            ),
          );
    if (source == null) return;
    final List<XFile> picked = source == ImageSource.camera
        ? [?await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85)]
        : await picker.pickMultiImage(maxWidth: 1600, imageQuality: 85, limit: max - photos.length);
    if (picked.isEmpty) return;
    onChanged([...photos, ...picked.map((x) => x.path)].take(max).toList());
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < photos.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(width: 96, height: 96, child: coverImage(photos[i])),
                ),
                if (i == 0)
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      color: Colors.black54,
                      child: const Text('Cover', style: TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const CircleAvatar(
                      radius: 11,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                    onPressed: () => onChanged([...photos]..removeAt(i)),
                  ),
                ),
              ]),
            ),
          if (photos.length < max)
            InkWell(
              onTap: () => _add(context),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 96,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo_outlined),
                    const SizedBox(height: 4),
                    Text('${photos.length}/$max', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

InputDecoration storeFieldDeco(String hint, {String? suffix, String? helper}) => InputDecoration(
      hintText: hint,
      labelText: hint,
      suffixText: suffix,
      helperText: helper,
      filled: true,
      fillColor: Colors.grey.shade200,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
