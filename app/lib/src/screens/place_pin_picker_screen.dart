import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/app_config.dart';
import '../models/models.dart';
import '../services/location_service.dart';

/// Full-screen map picker for a named saved place.
/// Returns a [SavedPlace] on confirm, or null on cancel.
class PlacePinPickerScreen extends StatefulWidget {
  /// Pass an existing place to edit it, or null to create a new one.
  final SavedPlace? existing;

  /// Used to centre the map when opening without an existing pin.
  final LatLng? currentLocation;

  const PlacePinPickerScreen({
    super.key,
    this.existing,
    this.currentLocation,
  });

  @override
  State<PlacePinPickerScreen> createState() => _PlacePinPickerScreenState();
}

class _PlacePinPickerScreenState extends State<PlacePinPickerScreen> {
  LatLng? _picked;
  String _addressHint = '';
  bool _resolving = false;
  final MapController _mapController = MapController();
  late final TextEditingController _labelCtrl;
  final _formKey = GlobalKey<FormState>();

  // Quick-pick label suggestions
  static const _suggestions = [
    ('🏠', 'Home'),
    ('👩‍👧', "Sister's house"),
    ('👨‍👩‍👦', "Parents' house"),
    ('💼', 'Work'),
    ('🏫', 'School'),
    ('🏋️', 'Gym'),
    ('⛪', 'Church'),
    ('🛒', 'Market'),
  ];

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.existing?.label ?? '');
    if (widget.existing != null) {
      _picked = LatLng(widget.existing!.lat, widget.existing!.lng);
      _resolveAddress(_picked!);
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  // ── Reverse geocode ───────────────────────────────────────
  Future<void> _resolveAddress(LatLng pt) async {
    setState(() {
      _resolving = true;
      _addressHint = '';
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
          addr['road'] ?? addr['pedestrian'] ?? addr['footway'] ?? '',
          addr['suburb'] ??
              addr['neighbourhood'] ??
              addr['city_district'] ??
              '',
          addr['city'] ?? addr['town'] ?? addr['municipality'] ?? '',
        ].where((s) => s.isNotEmpty).toList();
        if (mounted) {
          setState(() => _addressHint = parts.isNotEmpty
              ? parts.take(3).join(', ')
              : (j['display_name']
                      ?.toString()
                      .split(',')
                      .take(2)
                      .join(',')
                      .trim() ??
                  ''));
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _onMapTap(TapPosition _, LatLng pt) {
    setState(() {
      _picked = pt;
      _addressHint = '';
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
      _addressHint = '';
    });
    _resolveAddress(ll);
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    if (_picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap the map to place a pin first.')),
      );
      return;
    }
    final label = _labelCtrl.text.trim();
    final place = SavedPlace(
      id: widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      label: label,
      lat: _picked!.latitude,
      lng: _picked!.longitude,
    );
    Navigator.pop(context, place);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEditing = widget.existing != null;

    final center = (widget.existing != null
            ? LatLng(widget.existing!.lat, widget.existing!.lng)
            : null) ??
        widget.currentLocation ??
        const LatLng(14.5995, 120.9842);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit place' : 'Add a place'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _confirm,
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Map ───────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 16,
              minZoom: 3,
              maxZoom: 19,
              onTap: _onMapTap,
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
                      width: 60,
                      height: 68,
                      child: _PlaceDropPin(color: scheme.primary),
                    ),
                  ],
                ),
            ],
          ),

          // ── Instruction banner ───────────────────────────
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
                          'Tap the map to place a pin',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Bottom form panel ────────────────────────────
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
              padding: EdgeInsets.fromLTRB(
                  20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // drag handle
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

                    // ── Address hint ───────────────────────
                    if (_picked != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Icon(Icons.place, size: 14, color: scheme.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _resolving
                                  ? Text('Looking up address…',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade400))
                                  : Text(
                                      _addressHint.isNotEmpty
                                          ? _addressHint
                                          : '${_picked!.latitude.toStringAsFixed(5)}, '
                                              '${_picked!.longitude.toStringAsFixed(5)}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ),
                            // allow re-tap
                            TextButton(
                              style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap),
                              onPressed: () => setState(() => _picked = null),
                              child: const Text('Move',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),

                    // ── Label field ────────────────────────
                    TextFormField(
                      controller: _labelCtrl,
                      autofocus: isEditing,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Place name',
                        hintText: 'e.g. Home, Sister\'s house, Work…',
                        prefixIcon:
                            Icon(Icons.label_outline, color: scheme.primary),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter a name for this place'
                          : null,
                    ),

                    const SizedBox(height: 10),

                    // ── Quick-pick chips ───────────────────
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: <Widget>[
                          for (final s in _suggestions)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                label: Text('${s.$1} ${s.$2}',
                                    style: const TextStyle(fontSize: 12)),
                                onPressed: () =>
                                    _labelCtrl.text = '${s.$1} ${s.$2}',
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Save button ────────────────────────
                    FilledButton.icon(
                      icon: const Icon(Icons.push_pin, size: 18),
                      label: Text(isEditing ? 'Update place' : 'Save place'),
                      onPressed: _confirm,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── My location FAB ──────────────────────────────
          Positioned(
            right: 16,
            bottom: 260,
            child: FloatingActionButton.small(
              heroTag: 'placeLocFab',
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

// ── Place drop pin ────────────────────────────────────────────
class _PlaceDropPin extends StatelessWidget {
  final Color color;
  const _PlaceDropPin({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
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
          child: const Icon(Icons.place, color: Colors.white, size: 26),
        ),
        CustomPaint(
          size: const Size(14, 7),
          painter: _Pointer(color: color),
        ),
      ],
    );
  }
}

class _Pointer extends CustomPainter {
  final Color color;
  const _Pointer({required this.color});

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
  bool shouldRepaint(_Pointer old) => old.color != color;
}
