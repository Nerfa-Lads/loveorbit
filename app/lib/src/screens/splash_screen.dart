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

// Small reusable map widget used across screens.
class OrbitMap extends StatelessWidget {
  final List<LatLng> points;
  final LatLng? center;
  final double zoom;
  final double height;
  // Optional separate marker for "my location" (shown in green)
  // and "partner location" (shown in primary color).
  // If myLocation is set, it's shown as a distinct green pin.
  final LatLng? myLocation;
  final LatLng? partnerLocation;

  const OrbitMap({
    super.key,
    required this.points,
    this.center,
    this.zoom = 14,
    this.height = 220,
    this.myLocation,
    this.partnerLocation,
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
          width: 44,
          height: 44,
          child: const Icon(Icons.my_location, color: Colors.green, size: 36),
        ),
      if (partnerLocation != null)
        Marker(
          point: partnerLocation!,
          width: 44,
          height: 44,
          child: Icon(Icons.location_on, color: scheme.primary, size: 40),
        ),
      // fallback: single marker from points list
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
            // Road labels on top of satellite
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
                    color: scheme.primary.withValues(alpha: 0.6)),
              ]),
            if (markers.isNotEmpty) MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }
}
