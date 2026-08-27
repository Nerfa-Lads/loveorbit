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
  const OrbitMap({
    super.key,
    required this.points,
    this.center,
    this.zoom = 14,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final c = center ?? (points.isNotEmpty ? points.last : const LatLng(0, 0));
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(initialCenter: c, initialZoom: zoom),
          children: [
            TileLayer(
              urlTemplate: AppConfig.mapTileUrl,
              subdomains: const ['a', 'b', 'c'],
            ),
            if (points.isNotEmpty)
              PolylineLayer(polylines: [
                Polyline(
                    points: points,
                    strokeWidth: 4,
                    color: Theme.of(context).colorScheme.primary),
              ]),
            if (points.isNotEmpty)
              MarkerLayer(markers: [
                Marker(
                  point: points.last,
                  width: 40,
                  height: 40,
                  child: Icon(Icons.location_on,
                      color: Theme.of(context).colorScheme.primary, size: 40),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}
