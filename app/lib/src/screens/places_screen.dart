import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/location_service.dart';
import '../widgets/loveorbit_app_bar.dart';
import 'place_pin_picker_screen.dart';

class PlacesScreen extends StatelessWidget {
  const PlacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const LoveOrbitAppBar(screenTitle: 'My places'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPicker(context, null),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Add place'),
      ),
      body: SafeArea(
        child: p.savedPlaces.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined,
                        size: 60, color: Colors.grey.shade300),
                    const SizedBox(height: 14),
                    Text('No places saved yet',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.grey)),
                    const SizedBox(height: 6),
                    Text(
                      'Add places like Home, Sister\'s house or Work\nso your partner knows where you are.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      icon: const Icon(Icons.add_location_alt),
                      label: const Text('Add a place'),
                      onPressed: () => _openPicker(context, null),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                itemCount: p.savedPlaces.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final place = p.savedPlaces[i];
                  return _PlaceCard(
                    place: place,
                    color: scheme.primary,
                    onEdit: () => _openPicker(context, place),
                    onDelete: () => _confirmDelete(context, p, place),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context, SavedPlace? existing) async {
    final p = context.read<AppProvider>();

    // Centre on current GPS if available
    LatLng? currentLl;
    final pt = await LocationService.instance.currentPoint();
    if (pt != null) currentLl = LatLng(pt.latitude, pt.longitude);

    if (!context.mounted) return;

    final result = await Navigator.push<SavedPlace>(
      context,
      MaterialPageRoute(
        builder: (_) => PlacePinPickerScreen(
          existing: existing,
          currentLocation: currentLl,
        ),
      ),
    );

    if (result == null || !context.mounted) return;
    if (existing == null) {
      await p.addSavedPlace(result);
    } else {
      await p.updateSavedPlace(result);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(existing == null
              ? '📍 "${result.label}" saved!'
              : '✅ "${result.label}" updated!')),
    );
  }

  void _confirmDelete(BuildContext context, AppProvider p, SavedPlace place) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove place?'),
        content: Text(
            'Remove "${place.label}" from your saved places? Your partner will no longer see it on the map.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await p.removeSavedPlace(place.id);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// ── Place card ────────────────────────────────────────────────
class _PlaceCard extends StatelessWidget {
  final SavedPlace place;
  final Color color;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlaceCard({
    required this.place,
    required this.color,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Mini map preview ────────────────────────────
          SizedBox(
            height: 110,
            child: _MiniPlaceMap(
              point: LatLng(place.lat, place.lng),
              color: color,
            ),
          ),
          // ── Label + actions ─────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.place, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Text(
                        '${place.lat.toStringAsFixed(4)}, '
                        '${place.lng.toStringAsFixed(4)}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 20, color: Colors.red.shade300),
                  onPressed: onDelete,
                  tooltip: 'Remove',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mini map for each place card ──────────────────────────────
class _MiniPlaceMap extends StatelessWidget {
  final LatLng point;
  final Color color;

  const _MiniPlaceMap({required this.point, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FlutterMap(
        options: MapOptions(
          initialCenter: point,
          initialZoom: 16,
          interactionOptions:
              const InteractionOptions(flags: InteractiveFlag.none),
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
          MarkerLayer(
            markers: [
              Marker(
                point: point,
                width: 40,
                height: 40,
                child: Icon(Icons.place, color: color, size: 36),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
