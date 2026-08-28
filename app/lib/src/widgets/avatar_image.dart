import 'dart:convert';
import 'package:flutter/material.dart';

/// Renders an avatar from either a data: base64 URL or a regular https URL.
class AvatarImage extends StatelessWidget {
  final String? url;
  final double radius;

  const AvatarImage({super.key, required this.url, this.radius = 28});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        child: Icon(Icons.person, size: radius),
      );
    }

    if (url!.startsWith('data:image')) {
      // base64 data URL
      try {
        final comma = url!.indexOf(',');
        final bytes = base64Decode(url!.substring(comma + 1));
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {
        return CircleAvatar(
          radius: radius,
          child: Icon(Icons.person, size: radius),
        );
      }
    }

    // Regular network URL
    return CircleAvatar(
      radius: radius,
      backgroundImage: NetworkImage(url!),
      onBackgroundImageError: (_, __) {},
      child: null,
    );
  }
}
