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
  final String? label; // optional name shown above the pin

  const _AvatarMarker({
    this.avatarUrl,
    required this.borderColor,
    required this.fallbackIcon,
    this.label,
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
        // ── Name label above the avatar ──────────────────
        if (label != null && label!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 3),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: borderColor,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: borderColor.withValues(alpha: 0.45),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Text(
              label!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        // ── Avatar circle ────────────────────────────────
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
        // ── Triangle pointer ─────────────────────────────
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

// ── Dwell point ───────────────────────────────────────────────
/// A location where the user lingered for [duration] (≥ 1 h).
typedef DwellPoint = ({LatLng point, Duration duration});

/// Scan a sorted list of GPS points and return clusters where the user
/// stayed within [radiusMeters] for at least [minDwell].
/// Each returned [DwellPoint] uses the centroid of the cluster.
List<DwellPoint> computeDwellPoints(
  List<({LatLng point, DateTime time})> pts, {
  double radiusMeters = 100,
  Duration minDwell = const Duration(hours: 1),
}) {
  if (pts.length < 2) return [];
  const dist = Distance();
  final result = <DwellPoint>[];

  int i = 0;
  while (i < pts.length) {
    // Accumulate points that stay within radiusMeters of pts[i]
    final anchor = pts[i].point;
    int j = i + 1;
    while (j < pts.length && dist(anchor, pts[j].point) <= radiusMeters) {
      j++;
    }
    // pts[i..j-1] are all within radius of anchor
    final elapsed = pts[j - 1].time.difference(pts[i].time);
    if (elapsed >= minDwell) {
      // Compute centroid
      double lat = 0, lng = 0;
      for (int k = i; k < j; k++) {
        lat += pts[k].point.latitude;
        lng += pts[k].point.longitude;
      }
      final n = j - i;
      result.add((
        point: LatLng(lat / n, lng / n),
        duration: elapsed,
      ));
    }
    // Advance past the cluster (or just one step if no cluster)
    i = j > i + 1 ? j : i + 1;
  }
  return result;
}

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

// ── Dwell marker (circle on the trail) ───────────────────────
class _DwellMarker extends StatelessWidget {
  final Color color;
  final Duration duration;

  const _DwellMarker({required this.color, required this.duration});

  String get _label {
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Duration badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4),
            ],
          ),
          child: Text(
            _label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 2),
        // Circle dot
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: color, width: 2.5),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 4),
            ],
          ),
        ),
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
  final String? myLabel;
  final String? partnerLabel;
  final List<NamedPin> myPlaces;
  final List<NamedPin> partnerPlaces;
  final List<LatLng> todayJourney;
  final List<LatLng> partnerTodayJourney;
  final Color? partnerBorderColor;
  final List<DwellPoint> myDwellPoints;
  final List<DwellPoint> partnerDwellPoints;

  /// Override tile URLs (pass from AppProvider for user-chosen style).
  /// Falls back to AppConfig satellite tiles if null.
  final String? tileUrl;
  final String? labelUrl;

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
    this.partnerBorderColor,
    this.myHomePin,
    this.partnerHomePin,
    this.myLabel,
    this.partnerLabel,
    this.myPlaces = const [],
    this.partnerPlaces = const [],
    this.todayJourney = const [],
    this.partnerTodayJourney = const [],
    this.myDwellPoints = const [],
    this.partnerDwellPoints = const [],
    this.tileUrl,
    this.labelUrl,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = center ??
        myLocation ??
        (points.isNotEmpty ? points.first : const LatLng(0, 0));

    final myPinColor = myBorderColor ?? Colors.green;
    final partnerPinColor = partnerBorderColor ?? scheme.primary;

    final resolvedTile = tileUrl ?? AppConfig.mapTileUrl;
    final resolvedLabel = labelUrl ?? AppConfig.mapLabelUrl;

    final markers = <Marker>[
      if (myLocation != null)
        Marker(
          point: myLocation!,
          width: 80,
          height: 76,
          child: _AvatarMarker(
            avatarUrl: myAvatarUrl,
            borderColor: myPinColor,
            fallbackIcon: Icons.person,
            label: myLabel,
          ),
        ),
      if (partnerLocation != null)
        Marker(
          point: partnerLocation!,
          width: 80,
          height: 76,
          child: _AvatarMarker(
            avatarUrl: partnerAvatarUrl,
            borderColor: partnerPinColor,
            fallbackIcon: Icons.favorite,
            label: partnerLabel,
          ),
        ),
      if (myLocation == null && partnerLocation == null && points.isNotEmpty)
        Marker(
          point: points.last,
          width: 44,
          height: 44,
          child: Icon(Icons.location_on, color: partnerPinColor, size: 40),
        ),
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
          child: _HomePinMarker(color: partnerPinColor),
        ),
      for (final pin in myPlaces)
        Marker(
          point: pin.point,
          width: 100,
          height: 52,
          child: _LabelledPlaceMarker(label: pin.label, color: myPinColor),
        ),
      for (final pin in partnerPlaces)
        Marker(
          point: pin.point,
          width: 100,
          height: 52,
          child: _LabelledPlaceMarker(label: pin.label, color: partnerPinColor),
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
              urlTemplate: resolvedTile,
              tileProvider: NetworkTileProvider(
                headers: {
                  'User-Agent': 'LoveOrbit/1.0 (contact: loveorbit.app)'
                },
              ),
            ),
            if (resolvedLabel.isNotEmpty)
              TileLayer(
                urlTemplate: resolvedLabel,
                tileProvider: NetworkTileProvider(
                  headers: {
                    'User-Agent': 'LoveOrbit/1.0 (contact: loveorbit.app)'
                  },
                ),
              ),
            if (points.length > 1)
              PolylineLayer(polylines: [
                Polyline(
                  points: points,
                  strokeWidth: 4,
                  color: partnerPinColor.withValues(alpha: 0.6),
                ),
              ]),
            if (todayJourney.length > 1)
              PolylineLayer(polylines: [
                Polyline(
                  points: todayJourney,
                  strokeWidth: 3,
                  color: myPinColor.withValues(alpha: 0.75),
                ),
              ]),
            if (partnerTodayJourney.length > 1)
              PolylineLayer(polylines: [
                Polyline(
                  points: partnerTodayJourney,
                  strokeWidth: 3,
                  color: partnerPinColor.withValues(alpha: 0.75),
                ),
              ]),
            // ── Dwell markers ─────────────────────────────
            if (myDwellPoints.isNotEmpty)
              MarkerLayer(
                markers: [
                  for (final dw in myDwellPoints)
                    Marker(
                      point: dw.point,
                      width: 52,
                      height: 36,
                      child: _DwellMarker(
                          color: myPinColor, duration: dw.duration),
                    ),
                ],
              ),
            if (partnerDwellPoints.isNotEmpty)
              MarkerLayer(
                markers: [
                  for (final dw in partnerDwellPoints)
                    Marker(
                      point: dw.point,
                      width: 52,
                      height: 36,
                      child: _DwellMarker(
                          color: partnerPinColor, duration: dw.duration),
                    ),
                ],
              ),
            if (markers.isNotEmpty) MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }
}
