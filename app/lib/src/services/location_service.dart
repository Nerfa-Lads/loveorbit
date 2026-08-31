import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'local_store.dart';

/// Streams GPS positions and queues them to the local SQLite store (offline-first).
/// The SyncService picks them up and uploads them when online.
class LocationService {
  static final LocationService instance = LocationService._();
  LocationService._();

  final _uuid = const Uuid();
  StreamSubscription<Position>? _sub;
  final _controller = StreamController<LocationPoint>.broadcast();
  Stream<LocationPoint> get stream => _controller.stream;

  bool _recording = false;

  bool get isRecording => _recording;

  Future<bool> ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  Future<void> startRecording() async {
    if (_recording) return;
    final ok = await ensurePermission();
    if (!ok) return;
    _recording = true;
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10, // metres — balance between responsiveness and noise
      ),
    ).listen(_onPosition);
  }

  Future<void> stopRecording() async {
    _recording = false;
    await _sub?.cancel();
    _sub = null;
  }

  void _onPosition(Position p) async {
    // Ignore readings with very poor accuracy (>60m) — filters extreme outliers
    // but still keeps indoor/weak-signal readings (30m was too strict).
    if (p.accuracy > 60) return;

    final point = LocationPoint(
      latitude: p.latitude,
      longitude: p.longitude,
      accuracy: p.accuracy,
      speed: p.speed,
      heading: p.heading,
      altitude: p.altitude,
      recordedAt: p.timestamp.toLocal(),
      clientUid: _uuid.v4(),
    );
    await LocalStore.queueLocation(point);
    _controller.add(point);
  }

  Future<LocationPoint?> currentPoint() async {
    final ok = await ensurePermission();
    if (!ok) return null;
    final p = await Geolocator.getCurrentPosition();
    return LocationPoint(
      latitude: p.latitude,
      longitude: p.longitude,
      accuracy: p.accuracy,
      speed: p.speed,
      heading: p.heading,
      altitude: p.altitude,
      recordedAt: p.timestamp.toLocal(),
      clientUid: _uuid.v4(),
    );
  }

  void dispose() {
    _controller.close();
  }
}
