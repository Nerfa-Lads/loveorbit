import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'splash_screen.dart' show OrbitMap;

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
    final pts = _active.map((p) => LatLng(p.latitude, p.longitude)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Location history'), actions: [
        IconButton(
            icon: const Icon(Icons.delete_outline), onPressed: _confirmDelete),
      ]),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                      child: _DateButton(
                          label: 'From',
                          value: _from,
                          onPick: (d) => setState(() => _from = d))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _DateButton(
                          label: 'To',
                          value: _to,
                          onPick: (d) => setState(() => _to = d))),
                  IconButton(icon: const Icon(Icons.search), onPressed: _load),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Mine')),
                  ButtonSegment(value: false, label: Text('Partner')),
                ],
                selected: {_showMine},
                onSelectionChanged: (s) => setState(() => _showMine = s.first),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : pts.isEmpty
                      ? const Center(child: Text('No locations recorded.'))
                      : ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            OrbitMap(points: pts, height: 260, zoom: 12),
                            const SizedBox(height: 12),
                            Text('${_active.length} points',
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 8),
                            ..._active.map((p) => ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.place, size: 18),
                                  title: Text(
                                      '${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}'),
                                  subtitle:
                                      Text(p.recordedAt.toLocal().toString()),
                                )),
                          ],
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
        title: const Text('Delete history?'),
        content: Text(_showMine
            ? 'Delete your location history${_from != null || _to != null ? ' in this date range' : ''}? This cannot be undone.'
            : 'You can only delete your own history.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
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
      child: Text(value == null
          ? label
          : '$label: ${value!.toLocal().toString().substring(0, 10)}'),
    );
  }
}
