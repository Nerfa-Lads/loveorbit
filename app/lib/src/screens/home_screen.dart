import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/location_service.dart';
import '../models/models.dart';
import 'splash_screen.dart' show OrbitMap;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LocationPoint? _myLocation;
  bool _locLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchMyLocation();
      context.read<AppProvider>().refreshPartnerLatest();
    });
  }

  Future<void> _fetchMyLocation() async {
    if (_locLoading) return;
    setState(() => _locLoading = true);
    final pt = await LocationService.instance.currentPoint();
    if (mounted) {
      setState(() {
        _myLocation = pt;
        _locLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final partner = p.partner;
    final partnerPt = p.partnerLatest;

    // Build map points: my location + partner location (if available)
    final List<LatLng> points = [
      if (_myLocation != null)
        LatLng(_myLocation!.latitude, _myLocation!.longitude),
      if (partnerPt != null) LatLng(partnerPt.latitude, partnerPt.longitude),
    ];

    final LatLng? mapCenter = _myLocation != null
        ? LatLng(_myLocation!.latitude, _myLocation!.longitude)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Refresh my location',
            onPressed: () {
              _fetchMyLocation();
              p.refreshPartnerLatest();
              p.refreshCouple();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Map ──────────────────────────────────────────
            if (_locLoading && _myLocation == null)
              const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_myLocation == null)
              SizedBox(
                height: 240,
                child: Card(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_off,
                            size: 40, color: Colors.grey),
                        const SizedBox(height: 8),
                        const Text('Location permission needed'),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _fetchMyLocation,
                          child: const Text('Enable location'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              OrbitMap(
                points: points,
                center: mapCenter,
                height: 240,
                myLocation: _myLocation != null
                    ? LatLng(_myLocation!.latitude, _myLocation!.longitude)
                    : null,
                partnerLocation: partnerPt != null
                    ? LatLng(partnerPt.latitude, partnerPt.longitude)
                    : null,
              ),

            const SizedBox(height: 12),

            // ── My location label ─────────────────────────────
            if (_myLocation != null)
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    'You — ${_myLocation!.latitude.toStringAsFixed(5)}, '
                    '${_myLocation!.longitude.toStringAsFixed(5)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey),
                  ),
                ],
              ),

            const SizedBox(height: 16),

            // ── Sharing toggle (only makes sense when connected) ──
            if (p.isConnected) ...[
              _SharingCard(),
              const SizedBox(height: 16),
            ],

            // ── Partner card ──────────────────────────────────
            if (partner != null) ...[
              _PartnerCard(partner: partner, partnerPt: partnerPt, p: p),
            ] else
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(Icons.favorite_border,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  title: const Text('No partner connected yet'),
                  subtitle:
                      const Text('Go to Profile to connect with your partner'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  final dynamic partner;
  final LocationPoint? partnerPt;
  final AppProvider p;

  const _PartnerCard({
    required this.partner,
    required this.partnerPt,
    required this.p,
  });

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: partner.avatarUrl != null
                  ? NetworkImage(partner.avatarUrl!)
                  : null,
              child:
                  partner.avatarUrl == null ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(partner.displayName,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.circle,
                        size: 10, color: p.online ? Colors.green : Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      partnerPt != null
                          ? 'Last seen ${_timeAgo(partnerPt!.recordedAt)}'
                          : (p.online ? 'Online' : 'Offline'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final active = p.sharing && !p.paused;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(active ? Icons.location_on : Icons.location_off,
                  color: active ? Colors.green : Colors.grey),
              const SizedBox(width: 8),
              Text('Location sharing',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Switch(
                value: p.sharing,
                onChanged: (v) => p.setSharing(on: v),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              active
                  ? 'Sharing is ON — your partner can see your location.'
                  : (p.paused
                      ? 'Paused — sharing is temporarily off.'
                      : 'Sharing is OFF.'),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),
            if (p.sharing)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  icon: Icon(p.paused ? Icons.play_arrow : Icons.pause),
                  label: Text(p.paused ? 'Resume' : 'Pause'),
                  onPressed: () => p.setSharing(on: true, pause: !p.paused),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
