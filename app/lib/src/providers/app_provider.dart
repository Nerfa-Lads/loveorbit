import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/local_store.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';

// How often to run the geofence check while sharing is active.
const Duration _kGeofenceInterval = Duration(seconds: 30);

// Default available pin border colors
const List<Color> kPinBorderColors = [
  Color(0xFF4CAF50), // Green (default)
  Color(0xFFE91E63), // Pink
  Color(0xFF9C27B0), // Purple
  Color(0xFF2196F3), // Blue
  Color(0xFFFF9800), // Orange
  Color(0xFFF44336), // Red
  Color(0xFF00BCD4), // Cyan
  Color(0xFFFFEB3B), // Yellow
  Color(0xFFFFFFFF), // White
  Color(0xFF212121), // Black
];

const String _kPinColorKey = 'pin_border_color';
const String _kHomePinLatKey = 'home_pin_lat';
const String _kHomePinLngKey = 'home_pin_lng';
const String _kSavedPlacesKey = 'saved_places';
const String _kMapStyleKey = 'map_style'; // 'satellite' | 'classic'

class AppProvider extends ChangeNotifier {
  final _api = ApiService();
  final _battery = Battery();

  AppUser? user;
  Couple? couple;
  Partner? partner;
  bool sharing = false;
  bool online = false;
  bool syncing = false;
  LocationPoint? partnerLatest;
  List<ChatMessage> messages = [];
  String? _myId;
  StreamSubscription<SyncStatus>? _syncSub;

  // ── Home pin ──────────────────────────────────────────────
  /// My saved home location. Null if not set.
  double? homeLat;
  double? homeLng;

  /// My last known coordinates (updated whenever HomeScreen fetches location).
  double? _myLat;
  double? _myLng;

  void setMyCurrentLoc(double lat, double lng) {
    _myLat = lat;
    _myLng = lng;
    // Broadcast home:arrived to partner if we just arrived home
    if (amIHome) SyncService.instance.emitHomeArrived();
    // Run full geofence check (home + all saved places)
    _checkGeofences(lat, lng);
    notifyListeners();
  }

  /// True when my current location is within 200 m of my home pin.
  bool get amIHome {
    if (homeLat == null || homeLng == null) return false;
    if (_myLat == null || _myLng == null) return false;
    return _distanceMeters(_myLat!, _myLng!, homeLat!, homeLng!) < 200;
  }

  /// Whether partner is currently at their home pin (received via socket).
  bool partnerIsHome = false;

  /// Partner's home pin coordinates (received via socket when they set/share it).
  double? partnerHomeLat;
  double? partnerHomeLng;

  // ── Saved places ──────────────────────────────────────────
  /// My named places (home, sister's house, etc.).
  List<SavedPlace> savedPlaces = [];

  /// Partner's named places (received via socket).
  List<SavedPlace> partnerPlaces = [];

  // ── Today's journey ───────────────────────────────────────
  /// GPS breadcrumbs recorded since midnight local time.
  /// Used to draw the day's route line on the map.
  final List<LocationPoint> todayJourney = [];
  StreamSubscription<LocationPoint>? _journeySub;

  /// Partner's GPS breadcrumbs for today (received via socket).
  final List<LocationPoint> partnerTodayJourney = [];

  // ── Midnight reset ────────────────────────────────────────
  Timer? _midnightTimer;

  // ── Battery ───────────────────────────────────────────────
  /// My own battery level (0–100). -1 = unknown.
  int myBattery = -1;

  /// Partner's battery level (0–100). -1 = unknown.
  int partnerBattery = -1;

  /// Partner's battery charging state.
  BatteryState partnerBatteryState = BatteryState.unknown;

  StreamSubscription<BatteryState>? _batteryStateSub;

  // ── Geofence ──────────────────────────────────────────────
  /// Tracks which place labels the user was already inside,
  /// so we don't re-fire the same notification on every tick.
  final Set<String> _insidePlaces = {};
  Timer? _geofenceTimer;

  // ── Pin border color preference ───────────────────────────
  Color _pinBorderColor = kPinBorderColors.first;
  Color get pinBorderColor => _pinBorderColor;

  /// Partner's chosen pin border color (received via socket).
  Color partnerPinBorderColor = const Color(0xFF4CAF50);

  // ── Map style preference ──────────────────────────────────
  String _mapStyle = 'satellite'; // 'satellite' | 'classic'
  String get mapStyle => _mapStyle;

  /// Base tile URL for the currently selected map style.
  String get mapTileUrl => _mapStyle == 'classic'
      ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
      : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  /// Label overlay — only used on satellite; classic OSM already has labels.
  String get mapLabelUrl => _mapStyle == 'classic'
      ? ''
      : 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}';

  // ─────────────────────────────────────────────────────────
  bool get isConnected => couple?.status == 'active' && partner != null;

  // ── Bootstrap ─────────────────────────────────────────────
  Future<void> bootstrap() async {
    await _loadPinColor();
    await _loadHomePin();
    await _loadSavedPlaces();
    await _loadMapStyle();
    final tok = await ApiService.token;
    if (tok == null) return;
    try {
      user = await _api.me();
      _myId = user!.id;
      await refreshCouple();
      await loadSharing();
      await loadMessages();
      messages = await LocalStore.cachedMessages();
      SyncService.instance.init(
        token: tok,
        onIncomingMessage: _onIncoming,
        onPartnerBattery: _onPartnerBattery,
        onPartnerIsHome: _onPartnerIsHome,
        onPartnerHomePin: _onPartnerHomePin,
        onPartnerPlaces: _onPartnerPlaces,
        onPartnerLocation: addPartnerJourneyPoint,
        onPartnerPinColor: _onPartnerPinColor,
      );
      _listenSync();
      await _initBattery();
      _startJourneyTracking();
      // Share our pin color with partner on connect
      SyncService.instance.emitPinColor(_pinBorderColor);
      notifyListeners();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('unauthorized') || msg.contains('401')) {
        await ApiService.clearToken();
      }
      notifyListeners();
    }
  }

  // ── Pin color ─────────────────────────────────────────────
  Future<void> _loadPinColor() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getInt(_kPinColorKey);
    if (val != null) {
      _pinBorderColor = Color(val);
      notifyListeners();
    }
  }

  Future<void> setPinBorderColor(Color color) async {
    _pinBorderColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPinColorKey, color.toARGB32());
    // Broadcast chosen color to partner
    SyncService.instance.emitPinColor(color);
  }

  // ── Map style ─────────────────────────────────────────────
  Future<void> _loadMapStyle() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_kMapStyleKey);
    if (val != null) {
      _mapStyle = val;
      notifyListeners();
    }
  }

  Future<void> setMapStyle(String style) async {
    _mapStyle = style;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMapStyleKey, style);
  }

  // ── Home pin ──────────────────────────────────────────────
  Future<void> _loadHomePin() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_kHomePinLatKey);
    final lng = prefs.getDouble(_kHomePinLngKey);
    if (lat != null && lng != null) {
      homeLat = lat;
      homeLng = lng;
      notifyListeners();
    }
  }

  /// Save a home pin at the given coordinates and notify partner via socket.
  Future<void> setHomePin(double lat, double lng) async {
    homeLat = lat;
    homeLng = lng;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kHomePinLatKey, lat);
    await prefs.setDouble(_kHomePinLngKey, lng);
    SyncService.instance.emitHomePin(lat: lat, lng: lng);
    notifyListeners();
  }

  /// Remove the home pin.
  Future<void> clearHomePin() async {
    homeLat = null;
    homeLng = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHomePinLatKey);
    await prefs.remove(_kHomePinLngKey);
    notifyListeners();
  }

  // ── Battery ───────────────────────────────────────────────
  Future<void> _initBattery() async {
    try {
      myBattery = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      SyncService.instance.emitBattery(
        level: myBattery,
        state: _batteryStateString(state),
      );
    } catch (_) {}

    _batteryStateSub?.cancel();
    _batteryStateSub = _battery.onBatteryStateChanged.listen((_) async {
      try {
        myBattery = await _battery.batteryLevel;
        final state = await _battery.batteryState;
        SyncService.instance.emitBattery(
          level: myBattery,
          state: _batteryStateString(state),
        );
        notifyListeners();
      } catch (_) {}
    });
  }

  void _onPartnerBattery(int level, String state) {
    partnerBattery = level;
    partnerBatteryState = _parseBatteryState(state);
    notifyListeners();
  }

  void _onPartnerIsHome(bool isHome) {
    partnerIsHome = isHome;
    notifyListeners();
    if (isHome && partner != null) {
      NotificationService.notify(
        title: '${partner!.displayName} is home 🏠',
        body: 'They just arrived at their home location.',
      );
    }
  }

  void _onPartnerHomePin(double lat, double lng) {
    partnerHomeLat = lat;
    partnerHomeLng = lng;
    notifyListeners();
  }

  void _onPartnerPlaces(List<SavedPlace> places) {
    partnerPlaces = places;
    notifyListeners();
  }

  void _onPartnerPinColor(int colorValue) {
    partnerPinBorderColor = Color(colorValue);
    notifyListeners();
  }

  // ── Saved places ──────────────────────────────────────────
  Future<void> _loadSavedPlaces() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSavedPlacesKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        savedPlaces = list
            .map((e) => SavedPlace.fromJson(e as Map<String, dynamic>))
            .toList();
        notifyListeners();
      } catch (_) {}
    }
  }

  Future<void> _persistSavedPlaces() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kSavedPlacesKey,
      jsonEncode(savedPlaces.map((p) => p.toJson()).toList()),
    );
  }

  Future<void> addSavedPlace(SavedPlace place) async {
    savedPlaces = [...savedPlaces, place];
    await _persistSavedPlaces();
    SyncService.instance.emitPlaces(savedPlaces);
    notifyListeners();
  }

  Future<void> updateSavedPlace(SavedPlace place) async {
    savedPlaces = savedPlaces.map((p) => p.id == place.id ? place : p).toList();
    await _persistSavedPlaces();
    SyncService.instance.emitPlaces(savedPlaces);
    notifyListeners();
  }

  Future<void> removeSavedPlace(String id) async {
    savedPlaces = savedPlaces.where((p) => p.id != id).toList();
    await _persistSavedPlaces();
    SyncService.instance.emitPlaces(savedPlaces);
    notifyListeners();
  }

  // ── Today's journey ───────────────────────────────────────
  void _startJourneyTracking() {
    _journeySub?.cancel();
    // Seed with today's points already in SQLite pending queue
    _seedTodayJourney();
    // Then listen live to the GPS stream
    _journeySub = LocationService.instance.stream.listen((pt) {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      if (pt.recordedAt.isAfter(midnight)) {
        todayJourney.add(pt);
        notifyListeners();
        // Run geofence check on every new GPS point too
        _checkGeofences(pt.latitude, pt.longitude);
      }
    });
    // Also start the periodic geofence timer
    _startGeofenceTimer();
    // Schedule trail reset at next midnight
    _scheduleMidnightReset();
  }

  Future<void> _seedTodayJourney() async {
    final all = await LocalStore.pendingLocations();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final today = all.where((p) => p.recordedAt.isAfter(midnight)).toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    if (today.isNotEmpty) {
      todayJourney.addAll(today);
      notifyListeners();
    }
  }

  // ── Midnight reset ────────────────────────────────────────
  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight =
        DateTime(now.year, now.month, now.day + 1); // next calendar day
    final delay = nextMidnight.difference(now);
    _midnightTimer = Timer(delay, () {
      todayJourney.clear();
      partnerTodayJourney.clear();
      _insidePlaces.clear();
      notifyListeners();
      // Schedule the next day's reset
      _scheduleMidnightReset();
    });
  }

  // ── Geofence ──────────────────────────────────────────────
  void _startGeofenceTimer() {
    _geofenceTimer?.cancel();
    _geofenceTimer = Timer.periodic(_kGeofenceInterval, (_) async {
      if (_myLat == null || _myLng == null) return;
      _checkGeofences(_myLat!, _myLng!);
    });
  }

  void _stopGeofenceTimer() {
    _geofenceTimer?.cancel();
    _geofenceTimer = null;
  }

  /// Check whether the user has entered or left any saved place (including home).
  /// Fires a notification on entry and emits home:arrived if at home pin.
  void _checkGeofences(double lat, double lng) {
    const double radius = 200; // metres
    final currentlyInside = <String>{};

    // Check home pin
    if (homeLat != null && homeLng != null) {
      final d = _distanceMeters(lat, lng, homeLat!, homeLng!);
      if (d < radius) {
        currentlyInside.add('__home__');
        if (!_insidePlaces.contains('__home__')) {
          // Just entered home
          SyncService.instance.emitHomeArrived();
          NotificationService.notify(
            title: 'You\'re home 🏠',
            body: 'Welcome back!',
          );
        }
      }
    }

    // Check all saved places
    for (final place in savedPlaces) {
      final d = _distanceMeters(lat, lng, place.lat, place.lng);
      if (d < radius) {
        currentlyInside.add(place.id);
        if (!_insidePlaces.contains(place.id)) {
          // Just entered this place
          NotificationService.notify(
            title: 'You arrived at ${place.label}',
            body: 'Your partner can see your location.',
          );
        }
      }
    }

    _insidePlaces
      ..clear()
      ..addAll(currentlyInside);
  }

  /// Add a partner location point to today's trail.
  void addPartnerJourneyPoint(LocationPoint pt) {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    if (pt.recordedAt.isAfter(midnight)) {
      partnerTodayJourney.add(pt);
      notifyListeners();
    }
  }

  /// Returns the label of the nearest saved place within [radiusMeters],
  /// or null if nothing is close enough.
  String? nearestPlaceLabel(double lat, double lng,
      {double radiusMeters = 150}) {
    SavedPlace? nearest;
    double minDist = double.infinity;
    for (final place in savedPlaces) {
      final d = _distanceMeters(lat, lng, place.lat, place.lng);
      if (d < radiusMeters && d < minDist) {
        minDist = d;
        nearest = place;
      }
    }
    return nearest?.label;
  }

  /// Same lookup against partner's saved places.
  String? partnerNearestPlaceLabel(double lat, double lng,
      {double radiusMeters = 150}) {
    SavedPlace? nearest;
    double minDist = double.infinity;
    for (final place in partnerPlaces) {
      final d = _distanceMeters(lat, lng, place.lat, place.lng);
      if (d < radiusMeters && d < minDist) {
        minDist = d;
        nearest = place;
      }
    }
    return nearest?.label;
  }

  BatteryState _parseBatteryState(String s) {
    switch (s) {
      case 'charging':
        return BatteryState.charging;
      case 'full':
        return BatteryState.full;
      case 'discharging':
        return BatteryState.discharging;
      default:
        return BatteryState.unknown;
    }
  }

  String _batteryStateString(BatteryState s) {
    switch (s) {
      case BatteryState.charging:
        return 'charging';
      case BatteryState.full:
        return 'full';
      case BatteryState.discharging:
        return 'discharging';
      default:
        return 'unknown';
    }
  }

  // ── Auth ──────────────────────────────────────────────────
  Future<void> register(String username, String password, String name) async {
    final r = await _api.register(
        username: username, password: password, displayName: name);
    user = r.user;
    _myId = user!.id;
    SyncService.instance.init(
      token: r.token,
      onIncomingMessage: _onIncoming,
      onPartnerBattery: _onPartnerBattery,
      onPartnerIsHome: _onPartnerIsHome,
      onPartnerHomePin: _onPartnerHomePin,
      onPartnerPlaces: _onPartnerPlaces,
      onPartnerLocation: addPartnerJourneyPoint,
      onPartnerPinColor: _onPartnerPinColor,
    );
    _listenSync();
    await _initBattery();
    _startJourneyTracking();
    SyncService.instance.emitPinColor(_pinBorderColor);
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final r = await _api.login(username: username, password: password);
    user = r.user;
    _myId = user!.id;
    await refreshCouple();
    await loadSharing();
    messages = await LocalStore.cachedMessages();
    SyncService.instance.init(
      token: r.token,
      onIncomingMessage: _onIncoming,
      onPartnerBattery: _onPartnerBattery,
      onPartnerIsHome: _onPartnerIsHome,
      onPartnerHomePin: _onPartnerHomePin,
      onPartnerPlaces: _onPartnerPlaces,
      onPartnerLocation: addPartnerJourneyPoint,
      onPartnerPinColor: _onPartnerPinColor,
    );
    _listenSync();
    await _initBattery();
    _startJourneyTracking();
    SyncService.instance.emitPinColor(_pinBorderColor);
    notifyListeners();
  }

  Future<void> logout() async {
    await _syncSub?.cancel();
    await _batteryStateSub?.cancel();
    await _journeySub?.cancel();
    _journeySub = null;
    _stopGeofenceTimer();
    _insidePlaces.clear();
    _midnightTimer?.cancel();
    _midnightTimer = null;
    await LocationService.instance.stopRecording();
    await SyncService.instance.dispose();
    await ApiService.clearToken();
    user = null;
    couple = null;
    partner = null;
    messages = [];
    partnerBattery = -1;
    partnerIsHome = false;
    partnerHomeLat = null;
    partnerHomeLng = null;
    partnerPlaces = [];
    todayJourney.clear();
    partnerTodayJourney.clear();
    notifyListeners();
  }

  Future<void> updateProfile({String? name, String? avatarUrl}) async {
    user = await _api.updateProfile(displayName: name, avatarUrl: avatarUrl);
    notifyListeners();
  }

  Future<void> uploadAvatar(String filePath) async {
    user = await _api.uploadAvatar(filePath);
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await _api.deleteAccount();
    await logout();
  }

  // ── Couple ────────────────────────────────────────────────
  Future<Couple> createCouple() async {
    final c = await _api.createCouple();
    couple = c;
    notifyListeners();
    return c;
  }

  Future<void> joinCouple(String code) async {
    await _api.joinCouple(code);
    await refreshCouple();
  }

  Future<void> refreshCouple() async {
    final r = await _api.myCouple();
    couple = r.couple;
    partner = r.partner;
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _api.disconnect();
    couple = null;
    partner = null;
    partnerLatest = null;
    await stopSharing();
    notifyListeners();
  }

  // ── Sharing ───────────────────────────────────────────────
  Future<void> loadSharing() async {
    final s = await _api.getSharing();
    sharing = s.sharing;
    notifyListeners();
  }

  Future<void> setSharing({required bool on}) async {
    sharing = on;
    await _api.setSharing(sharing: sharing, paused: false);
    SyncService.instance.emitSharing(sharing: sharing, paused: false);
    if (on) {
      await LocationService.instance.startRecording();
      _startGeofenceTimer();
    } else {
      await LocationService.instance.stopRecording();
      _stopGeofenceTimer();
    }
    notifyListeners();
  }

  Future<void> stopSharing() async {
    sharing = false;
    await _api.setSharing(sharing: false, paused: false);
    await LocationService.instance.stopRecording();
    _stopGeofenceTimer();
    notifyListeners();
  }

  // ── Messages ──────────────────────────────────────────────
  Future<void> loadMessages() async {
    try {
      final m = await _api.messages(limit: 100);
      messages = m;
      for (final msg in m) {
        await LocalStore.cacheMessage(msg);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> sendMessage(String body) async {
    if (partner == null) return;
    final m = ChatMessage(
      senderId: _myId!,
      receiverId: partner!.id,
      body: body,
      status: 'pending',
      createdAt: DateTime.now(),
      clientUid: _uuid(),
    );
    await LocalStore.queueMessage(m);
    messages = [...messages, m];
    notifyListeners();
    if (online) {
      try {
        SyncService.instance.emitMessage(m);
        final saved = await _api.sendMessages([m]);
        if (saved.contains(m.clientUid)) {
          await LocalStore.clearMessages([m.clientUid]);
        }
      } catch (_) {}
    }
  }

  void _onIncoming(ChatMessage m) {
    if (m.receiverId != _myId) return;
    messages = [...messages, m];
    notifyListeners();
    NotificationService.notify(
      title: partner?.displayName ?? 'LoveOrbit',
      body: m.isPhoto ? 'Sent a photo' : (m.body ?? ''),
    );
    _api.markStatus([m.id!], 'delivered');
  }

  String _uuid() {
    return DateTime.now().microsecondsSinceEpoch.toString() +
        (partner?.id.hashCode ?? 0).toString();
  }

  void _listenSync() {
    _syncSub?.cancel();
    _syncSub = SyncService.instance.status.listen((s) {
      online = s.online;
      syncing = s.syncing;
      notifyListeners();
    });
  }

  // ── History ───────────────────────────────────────────────
  Future<void> deleteMyHistory() async {
    await _api.deleteMyLocations();
  }

  // ── Partner location ──────────────────────────────────────
  Future<void> refreshPartnerLatest() async {
    if (!isConnected) return;
    try {
      partnerLatest = await _api.partnerLatest();
      notifyListeners();
    } catch (_) {}
  }

  // ── Helpers ───────────────────────────────────────────────
  /// Haversine distance in metres.
  static double _distanceMeters(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * math.pi / 180;
}
