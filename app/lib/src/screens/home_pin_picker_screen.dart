import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/app_config.dart';
import '../services/location_service.dart';

/// Full-screen map that lets the user tap anywhere to place their home pin.
/// Returns the chosen [LatLng] if the user confirms, or null if they cancel.
class HomePinPickerScreen extends StatefulWidget {
  /// Pre-selected coordinates (existing pin). Null when setting for the first time.
  final LatLng? initial;

  /// The user's current GPS location, used to centre the map on first open.
  final LatLng? currentLocation;

  const HomePinPickerScreen({
    super.key,
    this.initial,
    this.currentLocation,
  });

  @override
  State<HomePinPickerScreen> createState() => _HomePinPickerScreenState();
}

class _HomePinPickerScreenState extends State<HomePinPickerScreen> {
  LatLng? _picked;
  String _addressLabel = '';
  bool _resolving = false;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
    if (_picked != null) _resolveAddress(_picked!);
  }

  // ── Reverse geocode the tapped point ─────────────────────
  Future<void> _resolveAddress(LatLng pt) async {
    setState(() {
      _resolving = true;
      _addressLabel = 'Looking up address…';
    });
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=${pt.latitude}&lon=${pt.longitude}'
        '&zoom=18&addressdetails=1',
      );
      final res = await http.get(uri, headers: {
        'User-Agent': 'LoveOrbit/1.0 (contact: loveorbit.app)',
      }).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = j['address'] as Map<String, dynamic>? ?? {};
        final parts = <String>[
          addr['road'] ??
              addr['pedestrian'] ??
              addr['footway'] ??
              addr['path'] ??
              '',
          addr['city_district'] ??
              addr['suburb'] ??
              addr['neighbourhood'] ??
              addr['quarter'] ??
              addr['village'] ??
              '',
          addr['city'] ??
              addr['town'] ??
              addr['municipality'] ??
              addr['county'] ??
              '',
        ].where((s) => s.isNotEmpty).toList();

        final label = parts.isNotEmpty
            ? parts.take(3).join(', ')
            : (j['display_name']
                    ?.toString()
                    .split(',')
                    .take(3)
                    .join(',')
                    .trim() ??
                '');
        if (mounted) setState(() => _addressLabel = label);
      } else {
        if (mounted) setState(() => _addressLabel = '');
      }
    } catch (_) {
      if (mounted) setState(() => _addressLabel = '');
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _onTap(TapPosition _, LatLng pt) {
    setState(() {
      _picked = pt;
      _addressLabel = '';
    });
    _resolveAddress(pt);
  }

  Future<void> _goToMyLocation() async {
    final pt = await LocationService.instance.currentPoint();
    if (pt == null || !mounted) return;
    final ll = LatLng(pt.latitude, pt.longitude);
    _mapController.move(ll, 17);
    setState(() {
      _picked = ll;
      _addressLabel = '';
    });
    _resolveAddress(ll);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Map initial centre: existing pin → current GPS → fallback (0,0)
    final center = widget.initial ??
        widget.currentLocation ??
        const LatLng(14.5995, 120.9842); // Manila as safe fallback

    return Scaffold(
      // ── App bar ─────────────────────────────────────────────
      appBar: AppBar(
        title: const Text('Pick your home'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_picked != null)
            TextButton(
              onPressed: () => Navigator.pop(context, _picked),
              child: const Text(
                'Confirm',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),

      // ── Body: map + bottom sheet ─────────────────────────────
      body: Stack(
        children: [
          // ── Full-screen map ──────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 16,
              minZoom: 3,
              maxZoom: 19,
              onTap: _onTap,
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
              if (_picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _picked!,
                      width: 56,
                      height: 64,
                      child: _HomeDrop(color: scheme.primary),
                    ),
                  ],
                ),
            ],
          ),

          // ── Instruction banner (shown when no pin yet) ───────
          if (_picked == null)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Material(
                borderRadius: BorderRadius.circular(12),
                elevation: 3,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.touch_app, color: scheme.primary, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Tap anywhere on the map to place your home pin',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Address + confirm bottom panel ───────────────────
          if (_picked != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child:
                              Icon(Icons.home, color: scheme.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Home location',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              _resolving
                                  ? Row(children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: scheme.primary),
                                      ),
                                      const SizedBox(width: 6),
                                      Text('Looking up address…',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade500)),
                                    ])
                                  : Text(
                                      _addressLabel.isNotEmpty
                                          ? _addressLabel
                                          : '${_picked!.latitude.toStringAsFixed(5)}, '
                                              '${_picked!.longitude.toStringAsFixed(5)}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _picked = null),
                            child: const Text('Move pin'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.home, size: 18),
                            label: const Text('Set as home'),
                            onPressed: () => Navigator.pop(context, _picked),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // ── My location FAB ──────────────────────────────────
          Positioned(
            right: 16,
            bottom: _picked != null ? 180 : 24,
            child: FloatingActionButton.small(
              heroTag: 'myLocationFab',
              onPressed: _goToMyLocation,
              tooltip: 'My location',
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated home-drop pin ────────────────────────────────────
class _HomeDrop extends StatelessWidget {
  final Color color;
  const _HomeDrop({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.home, color: Colors.white, size: 24),
        ),
        // Pointer triangle
        CustomPaint(
          size: const Size(14, 7),
          painter: _DropPointer(color: color),
        ),
      ],
    );
  }
}

class _DropPointer extends CustomPainter {
  final Color color;
  const _DropPointer({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      ui.Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_DropPointer old) => old.color != color;
}
