import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../widgets/loveorbit_app_bar.dart';
import 'splash_screen.dart' show computeDwellPoints;

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
      // connectedAt = when the couple became active.
      // - My own history: show everything from connection date onward
      //   (pre-connection locations were never shared, no point surfacing them).
      // - Partner history: ONLY from connection date onward — they had no
      //   obligation to share before you were connected.
      final connectedAt = context.read<AppProvider>().couple?.connectedAt;

      _mine = await api.myLocations(from: connectedAt);
      _partner = await api.partnerLocations(from: connectedAt);
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
    final p = context.watch<AppProvider>();
    final connectedAt = p.couple?.connectedAt;

    return Scaffold(
      appBar: LoveOrbitAppBar(
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
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
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
            // ── Connection date note ───────────────────────────
            if (connectedAt != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.link, size: 13, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      'Showing journeys from ${_fmtDate(connectedAt)} — when you connected',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
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
                                  ? p.pinBorderColor
                                  : p.partnerPinBorderColor,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtDate(DateTime d) {
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
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
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

  /// Reverse-geocoded labels keyed by index.
  /// Populated lazily when the card is expanded.
  final Map<int, String> _placeNames = {};
  bool _geocoding = false;

  /// Reverse-geocode a single (lat, lng) into a human-readable string.
  static Future<String> _geocode(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 8));
      if (marks.isEmpty) return '';
      final p = marks.first;
      final parts = <String>[
        if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
        if ((p.locality ?? '').isNotEmpty) p.locality!,
        if ((p.subAdministrativeArea ?? '').isNotEmpty &&
            p.subAdministrativeArea != p.locality)
          p.subAdministrativeArea!,
      ].take(2).toList();
      if (parts.isNotEmpty) return parts.join(', ');
      final fb = <String>[
        if ((p.thoroughfare ?? '').isNotEmpty) p.thoroughfare!,
        if ((p.locality ?? '').isNotEmpty) p.locality!,
      ];
      return fb.join(', ');
    } catch (_) {
      return '';
    }
  }

  /// Geocode all points when the card expands (runs once).
  Future<void> _loadPlaceNames() async {
    if (_geocoding || _placeNames.length == widget.points.length) return;
    _geocoding = true;
    for (int i = 0; i < widget.points.length; i++) {
      if (_placeNames.containsKey(i)) continue;
      final pt = widget.points[i];
      final name = await _geocode(pt.latitude, pt.longitude);
      if (!mounted) return;
      setState(() => _placeNames[i] = name);
    }
    _geocoding = false;
  }

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
    final km = _distanceKm;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Header (always visible) ───────────────────────
          InkWell(
            onTap: () {
              setState(() => _expanded = !_expanded);
              if (_expanded) _loadPlaceNames();
            },
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
              child: _RouteMap(points: widget.points, color: widget.color),
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
              final placeName = _placeNames[i];
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
                            // Show place name if geocoded, else a loading shimmer
                            placeName == null
                                ? Container(
                                    height: 12,
                                    width: 120,
                                    margin: const EdgeInsets.only(top: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  )
                                : Text(
                                    placeName.isNotEmpty
                                        ? placeName
                                        : 'Unknown location',
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
  final List<LocationPoint> points;
  final Color color;

  const _RouteMap({required this.points, required this.color});

  List<LatLng> get _latLngs =>
      points.map((p) => LatLng(p.latitude, p.longitude)).toList();

  LatLng get _center {
    final lls = _latLngs;
    final lat = lls.map((p) => p.latitude).reduce((a, b) => a + b) / lls.length;
    final lng =
        lls.map((p) => p.longitude).reduce((a, b) => a + b) / lls.length;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final lls = _latLngs;
    final dwells = computeDwellPoints(
      points
          .map((pt) => (
                point: LatLng(pt.latitude, pt.longitude),
                time: pt.recordedAt,
              ))
          .toList(),
    );

    return FlutterMap(
      options: MapOptions(initialCenter: _center, initialZoom: 13),
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
        PolylineLayer(polylines: [
          Polyline(
              points: lls,
              strokeWidth: 4,
              color: color.withValues(alpha: 0.85)),
        ]),
        // Dwell markers
        if (dwells.isNotEmpty)
          MarkerLayer(
            markers: [
              for (final dw in dwells)
                Marker(
                  point: dw.point,
                  width: 52,
                  height: 36,
                  child: _DwellBadge(color: color, duration: dw.duration),
                ),
            ],
          ),
        MarkerLayer(markers: [
          Marker(
            point: lls.first,
            width: 32,
            height: 32,
            child: const Icon(Icons.trip_origin, color: Colors.green, size: 26),
          ),
          Marker(
            point: lls.last,
            width: 36,
            height: 36,
            child: Icon(Icons.location_on, color: color, size: 32),
          ),
        ]),
      ],
    );
  }
}

// ── Dwell badge for history map (same visual as _DwellMarker) ─
class _DwellBadge extends StatelessWidget {
  final Color color;
  final Duration duration;
  const _DwellBadge({required this.color, required this.duration});

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
