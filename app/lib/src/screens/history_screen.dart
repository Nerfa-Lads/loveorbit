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
      _mine = await api.myLocations();
      _partner = await api.partnerLocations();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<LocationPoint> get _active => _showMine ? _mine : _partner;

  /// Group points by local calendar day, sorted newest first.
  Map<String, List<LocationPoint>> get _byDay {
    final map = <String, List<LocationPoint>>{};
    for (final pt in _active) {
      final local = pt.recordedAt.toLocal();
      final key =
          '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(pt);
    }
    // sort points within each day oldest→newest (for route drawing)
    for (final pts in map.values) {
      pts.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    }
    // return days newest first
    final sorted = map.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    return Map.fromEntries(sorted);
  }

  @override
  Widget build(BuildContext context) {
    final days = _byDay;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journey History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Mine / Partner toggle ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: true,
                      label: Text('My journeys'),
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

            // ── Content ────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : days.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.route,
                                  size: 56, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text('No journeys recorded yet.'),
                              const SizedBox(height: 4),
                              Text(
                                'Enable location sharing on the Home screen.',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: days.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final key = days.keys.elementAt(i);
                            final pts = days[key]!;
                            return _DayCard(
                              dateKey: key,
                              points: pts,
                              color: _showMine
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.pinkAccent,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete all journey history?'),
        content: Text(_showMine
            ? 'This will permanently delete all your recorded locations.'
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
                await ApiService().deleteMyLocations();
                _load();
              },
              child: const Text('Delete'),
            ),
        ],
      ),
    );
  }
}

// ── One card per day ──────────────────────────────────────────
class _DayCard extends StatefulWidget {
  final String dateKey; // yyyy-MM-dd
  final List<LocationPoint> points;
  final Color color;

  const _DayCard({
    required this.dateKey,
    required this.points,
    required this.color,
  });

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> {
  bool _expanded = false;

  String get _label {
    final parts = widget.dateKey.split('-');
    final date =
        DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    // e.g. "Mon, Aug 28"
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  double get _distanceKm {
    if (widget.points.length < 2) return 0;
    const Distance d = Distance();
    double total = 0;
    for (int i = 1; i < widget.points.length; i++) {
      total += d(
        LatLng(widget.points[i - 1].latitude, widget.points[i - 1].longitude),
        LatLng(widget.points[i].latitude, widget.points[i].longitude),
      );
    }
    return total / 1000;
  }

  String get _timeRange {
    final first = widget.points.first.recordedAt.toLocal();
    final last = widget.points.last.recordedAt.toLocal();
    String fmt(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return '${fmt(first)} – ${fmt(last)}';
  }

  @override
  Widget build(BuildContext context) {
    final pts =
        widget.points.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final km = _distanceKm;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Header (always visible) ───────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: widget.color.withValues(alpha: 0.15),
                    child: Icon(Icons.route, color: widget.color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_label,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                          _timeRange,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  // distance badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        km < 1
                            ? '${(km * 1000).toStringAsFixed(0)} m'
                            : '${km.toStringAsFixed(2)} km',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: widget.color,
                            fontSize: 14),
                      ),
                      Text('${widget.points.length} pts',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded: map + point list ─────────────────────
          if (_expanded) ...[
            const Divider(height: 1),
            // Route map
            SizedBox(
              height: 220,
              child: _RouteMap(points: pts, color: widget.color),
            ),
            // Stats row
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat(
                    icon: Icons.straighten,
                    value: km < 1
                        ? '${(km * 1000).toStringAsFixed(0)} m'
                        : '${km.toStringAsFixed(2)} km',
                    label: 'Distance',
                    color: widget.color,
                  ),
                  _Stat(
                    icon: Icons.schedule,
                    value: _duration,
                    label: 'Duration',
                    color: widget.color,
                  ),
                  _Stat(
                    icon: Icons.pin_drop,
                    value: '${widget.points.length}',
                    label: 'Points',
                    color: widget.color,
                  ),
                ],
              ),
            ),
            // Point timeline
            ...List.generate(widget.points.length, (i) {
              final pt = widget.points[i];
              final isFirst = i == 0;
              final isLast = i == widget.points.length - 1;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(children: [
                      if (!isFirst)
                        Container(
                            width: 2, height: 10, color: Colors.grey.shade300),
                      Icon(
                        isFirst
                            ? Icons.trip_origin
                            : isLast
                                ? Icons.location_on
                                : Icons.circle,
                        size: isFirst || isLast ? 16 : 8,
                        color: isFirst
                            ? Colors.green
                            : isLast
                                ? widget.color
                                : Colors.grey.shade400,
                      ),
                      if (!isLast)
                        Container(
                            width: 2, height: 10, color: Colors.grey.shade300),
                    ]),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${pt.latitude.toStringAsFixed(5)}, '
                              '${pt.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              _fmtTime(pt.recordedAt),
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  String get _duration {
    final d = widget.points.last.recordedAt
        .difference(widget.points.first.recordedAt);
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }

  String _fmtTime(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

// ── Map widget ────────────────────────────────────────────────
class _RouteMap extends StatelessWidget {
  final List<LatLng> points;
  final Color color;

  const _RouteMap({required this.points, required this.color});

  LatLng get _center {
    final lat =
        points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final lng =
        points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(initialCenter: _center, initialZoom: 13),
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
        PolylineLayer(polylines: [
          Polyline(
              points: points,
              strokeWidth: 4,
              color: color.withValues(alpha: 0.85)),
        ]),
        MarkerLayer(markers: [
          Marker(
            point: points.first,
            width: 32,
            height: 32,
            child: const Icon(Icons.trip_origin, color: Colors.green, size: 26),
          ),
          Marker(
            point: points.last,
            width: 36,
            height: 36,
            child: Icon(Icons.location_on, color: color, size: 32),
          ),
        ]),
      ],
    );
  }
}

// ── Stat widget ───────────────────────────────────────────────
class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _Stat(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }
}
