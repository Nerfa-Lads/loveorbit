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
            Image.asset(
              'assets/applogo.png',
              width: 80,
              height: 80,
              fit: BoxFit.contain,
            ),
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

// ── Home pin marker ───────────────────────────────────────────
class _HomePinMarker extends StatelessWidget {
  final Color color;
  const _HomePinMarker({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(Icons.home, color: color, size: 18),
    );
  }
}

// ── Named pin data holder ─────────────────────────────────────
typedef NamedPin = ({LatLng point, String label});

// ── Labelled place marker ─────────────────────────────────────
class _LabelledPlaceMarker extends StatelessWidget {
  final String label;
  final Color color;
  const _LabelledPlaceMarker({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label bubble
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 6,
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Down arrow
        Icon(Icons.arrow_drop_down, color: color, size: 18),
      ],
    );
  }
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
  final Color? myBorderColor;
  final LatLng? myHomePin;
  final LatLng? partnerHomePin;

  /// My named saved places — shown as labelled pins on the map.
  final List<NamedPin> myPlaces;

  /// Partner's saved places — shown with a different tint.
  final List<NamedPin> partnerPlaces;

  /// Today's GPS breadcrumbs — drawn as a route line.
  final List<LatLng> todayJourney;

  const OrbitMap({
    super.key,
    required this.points,
    this.center,
    this.zoom = 16,
    this.height = 220,
    this.myLocation,
    this.partnerLocation,
    this.myAvatarUrl,
    this.partnerAvatarUrl,
    this.myBorderColor,
    this.myHomePin,
    this.partnerHomePin,
    this.myPlaces = const [],
    this.partnerPlaces = const [],
    this.todayJourney = const [],
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = center ??
        myLocation ??
        (points.isNotEmpty ? points.first : const LatLng(0, 0));

    final myPinColor = myBorderColor ?? Colors.green;

    final markers = <Marker>[
      if (myLocation != null)
        Marker(
          point: myLocation!,
          width: 50,
          height: 56,
          child: _AvatarMarker(
            avatarUrl: myAvatarUrl,
            borderColor: myPinColor,
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
      // ── Home pin markers ──────────────────────────────────
      if (myHomePin != null)
        Marker(
          point: myHomePin!,
          width: 40,
          height: 40,
          child: _HomePinMarker(color: myPinColor),
        ),
      if (partnerHomePin != null)
        Marker(
          point: partnerHomePin!,
          width: 40,
          height: 40,
          child: _HomePinMarker(color: scheme.primary),
        ),
      // ── Named saved places (mine) ──────────────────────
      for (final pin in myPlaces)
        Marker(
          point: pin.point,
          width: 100,
          height: 52,
          child: _LabelledPlaceMarker(
            label: pin.label,
            color: myPinColor,
          ),
        ),
      // ── Partner's named places ─────────────────────────
      for (final pin in partnerPlaces)
        Marker(
          point: pin.point,
          width: 100,
          height: 52,
          child: _LabelledPlaceMarker(
            label: pin.label,
            color: scheme.primary,
          ),
        ),
    ];

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: c,
            initialZoom: zoom,
            minZoom: 3,
            maxZoom: 19,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: AppConfig.mapTileUrl,
              tileProvider: NetworkTileProvider(
                headers: {
                  'User-Agent': 'LoveOrbit/1.0 (contact: loveorbit.app)',
                },
              ),
            ),
            if (AppConfig.mapLabelUrl.isNotEmpty)
              TileLayer(
                urlTemplate: AppConfig.mapLabelUrl,
                tileProvider: NetworkTileProvider(
                  headers: {
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
            // ── Today's journey trail ──────────────────────
            if (todayJourney.length > 1)
              PolylineLayer(polylines: [
                Polyline(
                  points: todayJourney,
                  strokeWidth: 3,
                  color: myPinColor.withValues(alpha: 0.75),
                ),
              ]),
            if (markers.isNotEmpty) MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }
}
