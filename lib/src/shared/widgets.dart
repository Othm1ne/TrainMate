import 'dart:io';
import 'package:flutter/material.dart';
import '../data/models/user_profile.dart';
import '../data/services/auth_service.dart';
import '../data/services/user_repository.dart';

/// Rebuilds with the signed-in user's live profile.
class MeBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, UserProfile me) builder;
  const MeBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: UserRepository.instance.watch(AuthService.instance.uid),
      builder: (context, snap) {
        final me = snap.data;
        if (me == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return builder(context, me);
      },
    );
  }
}

/// Circle avatar for a URL or local path, with a person icon fallback.
class Avatar extends StatelessWidget {
  final String? url;
  final double radius;
  const Avatar({super.key, required this.url, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final u = url ?? '';
    final ImageProvider? image = u.isEmpty
        ? null
        : u.startsWith('http') || u.startsWith('blob:')
            ? NetworkImage(u)
            : FileImage(File(u)) as ImageProvider;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade300,
      backgroundImage: image,
      onBackgroundImageError: image == null ? null : (_, __) {},
      child: image == null
          ? Icon(Icons.person, size: radius, color: Colors.grey.shade600)
          : null,
    );
  }
}

/// Network URL or local file, with a grey placeholder.
Widget coverImage(String cover, {BoxFit fit = BoxFit.cover}) {
  final placeholder = Container(color: Colors.grey.shade300);
  if (cover.isEmpty) return placeholder;
  if (cover.startsWith('http') || cover.startsWith('blob:')) {
    return Image.network(
      cover,
      fit: fit,
      loadingBuilder: (c, child, p) => p == null ? child : placeholder,
      errorBuilder: (c, e, s) => placeholder,
    );
  }
  return Image.file(File(cover), fit: fit, errorBuilder: (c, e, s) => placeholder);
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String formatKm(double? km) {
  if (km == null) return '';
  if (km < 1) return '< 1 km';
  return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
}
