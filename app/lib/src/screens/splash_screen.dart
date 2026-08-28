import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/app_config.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite,
                size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('LoveOrbit',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Always connected, wherever we are.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey)),
            const SizedBox(height: 40),
            const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      ),
    );
  }
}

// ── Avatar map marker ─────────────────────────────────────────
class _AvatarMarker extends StatelessWidget {
  final String? avatarUrl;
  final Color borderColor;
  final IconData fallbackIcon;

  const _AvatarMarker({
    this.avatarUrl,
    required this.borderColor,
    required this.fallbackIcon,
  });

  ImageProvider? _imageProvider() {
    if (avatarUrl == null || avatarUrl!.isEmpty) return null;
    if (avatarUrl!.startsWith('data:image')) {
      try {
        final comma = avatarUrl!.indexOf(',');
        final bytes = base64Decode(avatarUrl!.substring(comma + 1));
        return MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(avatarUrl!);
  }

  @override
  Widget build(BuildContext context) {
    final img = _imageProvider();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 2.5),
            color: borderColor.withValues(alpha: 0.15),
            image: img != null
                ? DecorationImage(image: img, fit: BoxFit.cover)
                : null,
          ),
          child: img == null
              ? Icon(fallbackIcon, color: borderColor, size: 22)
              : null,
        ),
        // Small triangle pointer
        CustomPaint(
          size: const Size(12, 6),
          painter: _TrianglePainter(color: borderColor),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

// ── Reusable map widget ───────────────────────────────────────
class OrbitMap extends StatelessWidget {
  final List<LatLng> points;
  final LatLng? center;
  final double zoom;
  final double height;
  final LatLng? myLocation;
  final LatLng? partnerLocation;
  final String? myAvatarUrl;
  final String? partnerAvatarUrl;

  const OrbitMap({
    super.key,
    required this.points,
    this.center,
    this.zoom = 14,
    this.height = 220,
    this.myLocation,
    this.partnerLocation,
    this.myAvatarUrl,
    this.partnerAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = center ??
        myLocation ??
        (points.isNotEmpty ? points.first : const LatLng(0, 0));

    final markers = <Marker>[
      if (myLocation != null)
        Marker(
          point: myLocation!,
          width: 50,
          height: 56,
          child: _AvatarMarker(
            avatarUrl: myAvatarUrl,
            borderColor: Colors.green,
            fallbackIcon: Icons.person,
          ),
        ),
      if (partnerLocation != null)
        Marker(
          point: partnerLocation!,
          width: 50,
          height: 56,
          child: _AvatarMarker(
            avatarUrl: partnerAvatarUrl,
            borderColor: scheme.primary,
            fallbackIcon: Icons.favorite,
          ),
        ),
      if (myLocation == null && partnerLocation == null && points.isNotEmpty)
        Marker(
          point: points.last,
          width: 44,
          height: 44,
          child: Icon(Icons.location_on, color: scheme.primary, size: 40),
        ),
    ];

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(initialCenter: c, initialZoom: zoom),
          children: [
            TileLayer(
              urlTemplate: AppConfig.mapTileUrl,
              tileProvider: NetworkTileProvider(
                headers: const {
                  'User-Agent': 'LoveOrbit/1.0 (contact: loveorbit.app)',
                },
              ),
            ),
            TileLayer(
              urlTemplate: AppConfig.mapLabelUrl,
              tileProvider: NetworkTileProvider(
                headers: const {
                  'User-Agent': 'LoveOrbit/1.0 (contact: loveorbit.app)',
                },
              ),
            ),
            if (points.length > 1)
              PolylineLayer(polylines: [
                Polyline(
                  points: points,
                  strokeWidth: 4,
                  color: scheme.primary.withValues(alpha: 0.6),
                ),
              ]),
            if (markers.isNotEmpty) MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }
}
