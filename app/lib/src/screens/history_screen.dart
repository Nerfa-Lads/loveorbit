import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/app_config.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime? _from;
  DateTime? _to;
  List<LocationPoint> _mine = [];
  List<LocationPoint> _partner = [];
  bool _loading = false;
  bool _showMine = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ApiService();
      _mine = await api.myLocations(from: _from, to: _to);
      _partner = await api.partnerLocations(from: _from, to: _to);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<LocationPoint> get _active => _showMine ? _mine : _partner;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pts = _active.map((p) => LatLng(p.latitude, p.longitude)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journey History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Date filter ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _DateButton(
                      label: 'From',
                      value: _from,
                      onPick: (d) => setState(() => _from = d),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DateButton(
                      label: 'To',
                      value: _to,
                      onPick: (d) => setState(() => _to = d),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: 'Search',
                    onPressed: _load,
                  ),
                ],
              ),
            ),

            // ── Mine / Partner toggle ──────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: true,
                      label: Text('My journey'),
                      icon: Icon(Icons.person)),
                  ButtonSegment(
                      value: false,
                      label: Text("Partner's"),
                      icon: Icon(Icons.favorite)),
                ],
                selected: {_showMine},
                onSelectionChanged: (s) => setState(() => _showMine = s.first),
              ),
            ),

            // ── Map + list ─────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : pts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.route,
                                  size: 56, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                'No journey recorded yet.',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Enable location sharing on the Home screen.',
                                style: TextStyle(
                                    color: Colors.grey.shade400, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            // ── Route map ───────────────────────
                            _RouteMap(
                              points: pts,
                              color: _showMine
                                  ? scheme.primary
                                  : Colors.pinkAccent,
                              height: 280,
                            ),
                            const SizedBox(height: 12),

                            // ── Summary ──────────────────────────
                            _RouteSummary(points: _active),
                            const SizedBox(height: 12),

                            // ── Point list ───────────────────────
                            ...List.generate(_active.length, (i) {
                              final pt = _active[i];
                              final isFirst = i == 0;
                              final isLast = i == _active.length - 1;
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Timeline dot
                                  Column(children: [
                                    if (!isFirst)
                                      Container(
                                          width: 2,
                                          height: 12,
                                          color: Colors.grey.shade300),
                                    Icon(
                                      isFirst
                                          ? Icons.trip_origin
                                          : isLast
                                              ? Icons.location_on
                                              : Icons.circle,
                                      size: isFirst || isLast ? 18 : 10,
                                      color: isFirst
                                          ? Colors.green
                                          : isLast
                                              ? scheme.primary
                                              : Colors.grey.shade400,
                                    ),
                                    if (!isLast)
                                      Container(
                                          width: 2,
                                          height: 12,
                                          color: Colors.grey.shade300),
                                  ]),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${pt.latitude.toStringAsFixed(5)}, '
                                            '${pt.longitude.toStringAsFixed(5)}',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500),
                                          ),
                                          Text(
                                            _formatTime(pt.recordedAt),
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final local = t.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final timeStr =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    if (day == today) return 'Today $timeStr';
    final diff = today.difference(day).inDays;
    if (diff == 1) return 'Yesterday $timeStr';
    return '${local.day}/${local.month}/${local.year} $timeStr';
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete journey history?'),
        content: Text(_showMine
            ? 'This will permanently delete your location history${_from != null || _to != null ? ' in this date range' : ''}.'
            : 'You can only delete your own history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (_showMine)
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await ApiService().deleteMyLocations(from: _from, to: _to);
                _load();
              },
              child: const Text('Delete'),
            ),
        ],
      ),
    );
  }
}

// ── Route map with polyline trace ─────────────────────────────
class _RouteMap extends StatelessWidget {
  final List<LatLng> points;
  final Color color;
  final double height;

  const _RouteMap(
      {required this.points, required this.color, required this.height});

  LatLng get _center {
    final lat =
        points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final lng =
        points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(initialCenter: _center, initialZoom: 13),
          children: [
            TileLayer(
              urlTemplate: AppConfig.mapTileUrl,
              subdomains: const ['a', 'b', 'c'],
            ),
            // Full route polyline
            PolylineLayer(polylines: [
              Polyline(
                points: points,
                strokeWidth: 4,
                color: color.withOpacity(0.8),
              ),
            ]),
            // Start marker (green)
            MarkerLayer(markers: [
              Marker(
                point: points.first,
                width: 36,
                height: 36,
                child: const Icon(Icons.trip_origin,
                    color: Colors.green, size: 28),
              ),
              // End marker (primary color)
              Marker(
                point: points.last,
                width: 40,
                height: 40,
                child: Icon(Icons.location_on, color: color, size: 36),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────
class _RouteSummary extends StatelessWidget {
  final List<LocationPoint> points;
  const _RouteSummary({required this.points});

  double _totalDistanceKm() {
    if (points.length < 2) return 0;
    const Distance d = Distance();
    double total = 0;
    for (int i = 1; i < points.length; i++) {
      total += d(
        LatLng(points[i - 1].latitude, points[i - 1].longitude),
        LatLng(points[i].latitude, points[i].longitude),
      );
    }
    return total / 1000;
  }

  @override
  Widget build(BuildContext context) {
    final km = _totalDistanceKm();
    final duration = points.last.recordedAt.difference(points.first.recordedAt);
    final hours = duration.inHours;
    final mins = duration.inMinutes % 60;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Stat(
              icon: Icons.straighten,
              value: km < 1
                  ? '${(km * 1000).toStringAsFixed(0)} m'
                  : '${km.toStringAsFixed(2)} km',
              label: 'Distance',
            ),
            _Stat(
              icon: Icons.schedule,
              value: hours > 0 ? '${hours}h ${mins}m' : '${mins}m',
              label: 'Duration',
            ),
            _Stat(
              icon: Icons.pin_drop,
              value: '${points.length}',
              label: 'Points',
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _Stat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;
  const _DateButton(
      {required this.label, required this.value, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2024),
          lastDate: DateTime.now(),
        );
        if (d != null) onPick(d);
      },
      child: Text(
        value == null
            ? label
            : '$label: ${value!.toLocal().toString().substring(0, 10)}',
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
