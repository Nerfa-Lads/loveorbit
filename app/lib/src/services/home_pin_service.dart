import 'package:shared_preferences/shared_preferences.dart';

class HomePinService {
  static const _latKey = 'home_pin_lat';
  static const _lngKey = 'home_pin_lng';

  /// Save current location as home pin.
  static Future<void> savePin(double lat, double lng) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble(_latKey, lat);
    await sp.setDouble(_lngKey, lng);
  }

  /// Load saved home pin. Returns null if not set.
  static Future<({double lat, double lng})?> loadPin() async {
    final sp = await SharedPreferences.getInstance();
    final lat = sp.getDouble(_latKey);
    final lng = sp.getDouble(_lngKey);
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng);
  }

  /// Remove home pin.
  static Future<void> clearPin() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_latKey);
    await sp.remove(_lngKey);
  }

  /// Returns true if the given point is within [radiusMeters] of the home pin.
  static bool isNearHome(
    double lat,
    double lng,
    double homeLat,
    double homeLng, {
    double radiusMeters = 150,
  }) {
    // Haversine approximation
    const earthR = 6371000.0;
    final dLat = _rad(lat - homeLat);
    final dLng = _rad(lng - homeLng);
    final a = _sin2(dLat / 2) +
        _cos(_rad(homeLat)) * _cos(_rad(lat)) * _sin2(dLng / 2);
    final c = 2 * _asin(_sqrt(a));
    return earthR * c <= radiusMeters;
  }

  static double _rad(double deg) => deg * 3.141592653589793 / 180;
  static double _sin2(double x) => _sin(x) * _sin(x);
  static double _sin(double x) {
    // Taylor series approximation good enough for small angles
    return x - x * x * x / 6 + x * x * x * x * x / 120;
  }

  static double _cos(double x) => 1 - x * x / 2 + x * x * x * x / 24;
  static double _asin(double x) => x + x * x * x / 6;
  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double r = x;
    for (int i = 0; i < 20; i++) {
      r = (r + x / r) / 2;
    }
    return r;
  }
}
