import 'dart:convert';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/location_service.dart';
import '../widgets/avatar_image.dart';
import '../widgets/loveorbit_app_bar.dart';
import 'home_pin_picker_screen.dart';
import 'places_screen.dart';
import 'splash_screen.dart' show OrbitMap;

// ── Reverse geocode via Nominatim ─────────────────────────────
Future<String> _placeName(double lat, double lng) async {
  try {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
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
      if (parts.isNotEmpty) return parts.take(3).join(', ');
      return j['display_name']
              ?.toString()
              .split(',')
              .take(3)
              .join(',')
              .trim() ??
          '';
    }
  } catch (_) {}
  return '';
}

// ── Distance helper ───────────────────────────────────────────
String _distanceLabel(double lat1, double lng1, double lat2, double lng2) {
  const calc = Distance();
  final meters = calc(LatLng(lat1, lng1), LatLng(lat2, lng2));
  if (meters < 1000) return '${meters.toStringAsFixed(0)} m apart';
  return '${(meters / 1000).toStringAsFixed(1)} km apart';
}

// ── Battery icon helper ───────────────────────────────────────
IconData _batteryIcon(int level, BatteryState state) {
  if (state == BatteryState.charging || state == BatteryState.full) {
    return Icons.battery_charging_full;
  }
  if (level >= 80) return Icons.battery_full;
  if (level >= 60) return Icons.battery_5_bar;
  if (level >= 40) return Icons.battery_3_bar;
  if (level >= 20) return Icons.battery_2_bar;
  return Icons.battery_1_bar;
}

Color _batteryColor(int level, BatteryState state) {
  if (state == BatteryState.charging || state == BatteryState.full) {
    return Colors.green;
  }
  if (level >= 40) return Colors.green;
  if (level >= 20) return Colors.orange;
  return Colors.red;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LocationPoint? _myLocation;
  bool _locLoading = false;
  String _myPlaceName = '';
  String _partnerPlaceName = '';

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
    if (!mounted) return;
    setState(() {
      _myLocation = pt;
      _locLoading = false;
    });
    if (pt != null) {
      // Update provider so home-arrival detection runs
      context.read<AppProvider>().setMyCurrentLoc(pt.latitude, pt.longitude);
      final name = await _placeName(pt.latitude, pt.longitude);
      if (mounted) setState(() => _myPlaceName = name);
    }
  }

  Future<void> _fetchPartnerPlace(LocationPoint pt) async {
    final name = await _placeName(pt.latitude, pt.longitude);
    if (mounted) setState(() => _partnerPlaceName = name);
  }

  Future<void> _openHomePinPicker() async {
    final p = context.read<AppProvider>();

    // Current GPS to centre the map
    final currentLl = _myLocation != null
        ? LatLng(_myLocation!.latitude, _myLocation!.longitude)
        : null;

    // Existing pin so the picker opens with it already placed
    final existingLl = (p.homeLat != null && p.homeLng != null)
        ? LatLng(p.homeLat!, p.homeLng!)
        : null;

    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => HomePinPickerScreen(
          initial: existingLl,
          currentLocation: currentLl,
        ),
      ),
    );

    if (result == null || !mounted) return;
    await p.setHomePin(result.latitude, result.longitude);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Home pinned! Your partner will see it. 🏠')),
    );
  }

  Future<void> _clearHomePin() async {
    final p = context.read<AppProvider>();
    await p.clearHomePin();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Home pin removed.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final partner = p.partner;
    final partnerPt = p.partnerLatest;

    // Fetch partner place name when it changes
    if (partnerPt != null && _partnerPlaceName.isEmpty) {
      _fetchPartnerPlace(partnerPt);
    }

    final List<LatLng> points = [
      if (_myLocation != null)
        LatLng(_myLocation!.latitude, _myLocation!.longitude),
      if (partnerPt != null) LatLng(partnerPt.latitude, partnerPt.longitude),
    ];

    final LatLng? mapCenter = _myLocation != null
        ? LatLng(_myLocation!.latitude, _myLocation!.longitude)
        : null;

    final String? distanceStr = (_myLocation != null && partnerPt != null)
        ? _distanceLabel(_myLocation!.latitude, _myLocation!.longitude,
            partnerPt.latitude, partnerPt.longitude)
        : null;

    final bool hasMyHome = p.homeLat != null && p.homeLng != null;
    final bool hasPartnerHome =
        p.partnerHomeLat != null && p.partnerHomeLng != null;

    return Scaffold(
      appBar: LoveOrbitAppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.place_outlined),
            tooltip: 'My places',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlacesScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Refresh',
            onPressed: () {
              _myPlaceName = '';
              _partnerPlaceName = '';
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
              NotificationListener<ScrollNotification>(
                onNotification: (_) => true,
                child: OrbitMap(
                  points: points,
                  center: mapCenter,
                  height: 320,
                  myLocation:
                      LatLng(_myLocation!.latitude, _myLocation!.longitude),
                  partnerLocation: partnerPt != null
                      ? LatLng(partnerPt.latitude, partnerPt.longitude)
                      : null,
                  myAvatarUrl: p.user?.avatarUrl,
                  partnerAvatarUrl: p.partner?.avatarUrl,
                  myBorderColor: p.pinBorderColor,
                  myHomePin: hasMyHome ? LatLng(p.homeLat!, p.homeLng!) : null,
                  partnerHomePin: hasPartnerHome
                      ? LatLng(p.partnerHomeLat!, p.partnerHomeLng!)
                      : null,
                  myPlaces: p.savedPlaces
                      .map((pl) => (
                            point: LatLng(pl.lat, pl.lng),
                            label: pl.label,
                          ))
                      .toList(),
                  partnerPlaces: p.partnerPlaces
                      .map((pl) => (
                            point: LatLng(pl.lat, pl.lng),
                            label: pl.label,
                          ))
                      .toList(),
                  todayJourney: p.todayJourney
                      .map((pt) => LatLng(pt.latitude, pt.longitude))
                      .toList(),
                ),
              ),

            const SizedBox(height: 12),

            // ── Distance banner ───────────────────────────────
            if (distanceStr != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite,
                        size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      distanceStr,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // ── Location cards (me + partner) ─────────────────
            if (_myLocation != null || partnerPt != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_myLocation != null)
                    Expanded(
                      child: _LocationCard(
                        label: 'You',
                        avatarUrl: p.user?.avatarUrl,
                        placeName: _myPlaceName,
                        borderColor: p.pinBorderColor,
                        timeAgo: null,
                        isHome: p.amIHome,
                        battery: p.myBattery,
                        batteryState: BatteryState.unknown,
                      ),
                    ),
                  if (_myLocation != null && partnerPt != null)
                    const SizedBox(width: 10),
                  if (partnerPt != null && partner != null)
                    Expanded(
                      child: _LocationCard(
                        label: partner.displayName,
                        avatarUrl: partner.avatarUrl,
                        placeName: _partnerPlaceName,
                        borderColor: Theme.of(context).colorScheme.primary,
                        timeAgo: partnerPt.recordedAt,
                        isHome: p.partnerIsHome,
                        battery: p.partnerBattery,
                        batteryState: p.partnerBatteryState,
                      ),
                    ),
                ],
              ),

            const SizedBox(height: 16),

            // ── Home pin card ─────────────────────────────────
            if (p.isConnected) ...[
              _HomePinCard(
                hasPin: hasMyHome,
                isHome: p.amIHome,
                onSet: _openHomePinPicker,
                onClear: _clearHomePin,
              ),
              const SizedBox(height: 12),
            ],

            // ── Sharing toggle ────────────────────────────────
            if (p.isConnected) ...[
              _SharingCard(),
              const SizedBox(height: 16),
            ],

            // ── No partner nudge ──────────────────────────────
            if (partner == null)
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

// ── Location card ─────────────────────────────────────────────
class _LocationCard extends StatelessWidget {
  final String label;
  final String? avatarUrl;
  final String placeName;
  final Color borderColor;
  final DateTime? timeAgo;
  final bool isHome;
  final int battery;
  final BatteryState batteryState;

  const _LocationCard({
    required this.label,
    required this.avatarUrl,
    required this.placeName,
    required this.borderColor,
    required this.timeAgo,
    required this.isHome,
    required this.battery,
    required this.batteryState,
  });

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    final hasBattery = battery >= 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Name row ──────────────────────────────────────
            Row(children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: AvatarImage(url: avatarUrl, radius: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // At-home badge
              if (isHome)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.home, size: 12, color: Colors.green),
                      SizedBox(width: 2),
                      Text('Home',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.green,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ]),
            const SizedBox(height: 8),

            // ── Place name ────────────────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.place, size: 14, color: borderColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  placeName.isNotEmpty ? placeName : 'Locating…',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),

            // ── Battery + time row ────────────────────────────
            const SizedBox(height: 6),
            Row(
              children: [
                if (hasBattery) ...[
                  Icon(
                    _batteryIcon(battery, batteryState),
                    size: 14,
                    color: _batteryColor(battery, batteryState),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$battery%',
                    style: TextStyle(
                      fontSize: 11,
                      color: _batteryColor(battery, batteryState),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (timeAgo != null)
                  Text(
                    _ago(timeAgo!),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Home pin card ─────────────────────────────────────────────
class _HomePinCard extends StatelessWidget {
  final bool hasPin;
  final bool isHome;
  final VoidCallback onSet;
  final VoidCallback onClear;

  const _HomePinCard({
    required this.hasPin,
    required this.isHome,
    required this.onSet,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isHome
                  ? Colors.green.withValues(alpha: 0.15)
                  : scheme.primaryContainer,
              child: Icon(
                Icons.home,
                color: isHome ? Colors.green : scheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasPin
                        ? (isHome ? 'You\'re home 🏠' : 'Home pin set')
                        : 'Pin your home',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Text(
                    hasPin
                        ? 'Your partner is notified when you arrive.'
                        : 'Let your partner know when you\'re home.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!hasPin)
              FilledButton.icon(
                icon: const Icon(Icons.push_pin, size: 16),
                label: const Text('Pin'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  textStyle: const TextStyle(fontSize: 13),
                ),
                onPressed: onSet,
              )
            else
              OutlinedButton.icon(
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Remove'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  textStyle: const TextStyle(fontSize: 13),
                ),
                onPressed: onClear,
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
