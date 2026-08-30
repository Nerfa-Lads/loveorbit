import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/location_service.dart';
import '../widgets/avatar_image.dart';
import '../widgets/loveorbit_app_bar.dart';
import 'places_screen.dart';
import 'splash_screen.dart' show OrbitMap, computeDwellPoints;

// ── Reverse geocode using native platform geocoder ────────────
// Android uses Google's geocoding service — accurate for PH barangays.
Future<String> _placeName(double lat, double lng) async {
  try {
    final placemarks = await placemarkFromCoordinates(lat, lng)
        .timeout(const Duration(seconds: 8));
    if (placemarks.isEmpty) return '';
    final p = placemarks.first;

    // Build label: subLocality (barangay) → locality (city/municipality)
    // → subAdministrativeArea (district) → administrativeArea (province)
    final parts = <String>[
      if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
      if ((p.locality ?? '').isNotEmpty) p.locality!,
      if ((p.subAdministrativeArea ?? '').isNotEmpty &&
          p.subAdministrativeArea != p.locality)
        p.subAdministrativeArea!,
    ].take(3).toList();

    if (parts.isNotEmpty) return parts.join(', ');

    // fallback to thoroughfare (street) + locality
    final fallback = <String>[
      if ((p.thoroughfare ?? '').isNotEmpty) p.thoroughfare!,
      if ((p.locality ?? '').isNotEmpty) p.locality!,
    ];
    return fallback.join(', ');
  } catch (_) {
    return '';
  }
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
  LatLng? _stableCenter; // only updated when user has moved significantly
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
    if (pt != null) {
      final newLl = LatLng(pt.latitude, pt.longitude);
      // Only update stable center if we don't have one yet, or user moved >50m
      if (_stableCenter == null) {
        _stableCenter = newLl;
      } else {
        const calc = Distance();
        final moved = calc(_stableCenter!, newLl);
        if (moved > 50) _stableCenter = newLl;
      }
      setState(() {
        _myLocation = pt;
        _locLoading = false;
        _myPlaceName = '';
      });
      context.read<AppProvider>().setMyCurrentLoc(pt.latitude, pt.longitude);
      final name = await _placeName(pt.latitude, pt.longitude);
      if (mounted) setState(() => _myPlaceName = name);
    } else {
      setState(() => _locLoading = false);
    }
  }

  Future<void> _fetchPartnerPlace(LocationPoint pt) async {
    final name = await _placeName(pt.latitude, pt.longitude);
    if (mounted) setState(() => _partnerPlaceName = name);
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

    final LatLng? mapCenter = _stableCenter ??
        (_myLocation != null
            ? LatLng(_myLocation!.latitude, _myLocation!.longitude)
            : null);

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
                  partnerBorderColor: p.partnerPinBorderColor,
                  myLabel: 'You',
                  partnerLabel: partner?.displayName,
                  tileUrl: p.mapTileUrl,
                  labelUrl: p.mapLabelUrl,
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
                  partnerTodayJourney: p.partnerTodayJourney
                      .map((pt) => LatLng(pt.latitude, pt.longitude))
                      .toList(),
                  myDwellPoints: computeDwellPoints(
                    p.todayJourney
                        .map((pt) => (
                              point: LatLng(pt.latitude, pt.longitude),
                              time: pt.recordedAt,
                            ))
                        .toList(),
                  ),
                  partnerDwellPoints: computeDwellPoints(
                    p.partnerTodayJourney
                        .map((pt) => (
                              point: LatLng(pt.latitude, pt.longitude),
                              time: pt.recordedAt,
                            ))
                        .toList(),
                  ),
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
                        phoneActive: true,
                        movementMode: p.myMovementMode,
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
                        phoneActive: p.partnerPhoneActive,
                        movementMode: p.partnerMovementMode,
                      ),
                    ),
                ],
              ),

            const SizedBox(height: 16),

            // ── Sharing toggle — only shown when sharing is OFF ──
            if (p.isConnected && !p.sharing) ...[
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
  final bool? phoneActive;
  final MovementMode movementMode;

  const _LocationCard({
    required this.label,
    required this.avatarUrl,
    required this.placeName,
    required this.borderColor,
    required this.timeAgo,
    required this.isHome,
    required this.battery,
    required this.batteryState,
    this.phoneActive,
    this.movementMode = MovementMode.unknown,
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
              // Phone active status
              if (phoneActive != null) ...[
                const SizedBox(width: 4),
                _PhoneStatusBadge(active: phoneActive!),
              ],
              // Movement badge
              if (movementMode != MovementMode.unknown &&
                  movementMode != MovementMode.still) ...[
                const SizedBox(width: 4),
                _MovementBadge(mode: movementMode),
              ],
              // At-home badge
              if (isHome) ...[
                const SizedBox(width: 4),
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
              ],
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

// ── Movement badge ────────────────────────────────────────────
class _MovementBadge extends StatelessWidget {
  final MovementMode mode;
  const _MovementBadge({required this.mode});

  String get _emoji {
    switch (mode) {
      case MovementMode.walking:
        return '🚶';
      case MovementMode.running:
        return '🏃';
      case MovementMode.vehicle:
        return '🚗';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(_emoji, style: const TextStyle(fontSize: 11)),
    );
  }
}

// ── Phone status badge ────────────────────────────────────────
class _PhoneStatusBadge extends StatelessWidget {
  final bool active;
  const _PhoneStatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: active
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active
              ? Colors.green.withValues(alpha: 0.4)
              : Colors.grey.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.smartphone,
            size: 11,
            color: active ? Colors.green : Colors.grey.shade500,
          ),
          const SizedBox(width: 2),
          Text(
            active ? '' : 'zzz',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: active ? Colors.green : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sharing card ──────────────────────────────────────────────
class _SharingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return Card(
      color: Colors.orange.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.location_off, color: Colors.orange, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location sharing is OFF',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.orange),
                  ),
                  Text(
                    'Your partner can\'t see your location. Turn it on in Privacy.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
                minimumSize: const Size(0, 34),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                textStyle: const TextStyle(fontSize: 12),
              ),
              onPressed: () => p.setSharing(on: true),
              child: const Text('Turn on'),
            ),
          ],
        ),
      ),
    );
  }
}
