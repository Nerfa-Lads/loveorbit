import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart' show Color;
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';
import '../models/models.dart';
import 'api_service.dart';
import 'local_store.dart';

/// Watches connectivity and uploads pending locations, messages, and media
/// when the internet returns. Never deletes pending rows until the server
/// confirms success.
class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  final _api = ApiService();
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _online = false;
  bool _syncing = false;
  io.Socket? _socket;

  bool get online => _online;

  Future<void> syncNow() => _syncAll();

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get status => _statusController.stream;

  void init({
    String? token,
    void Function(ChatMessage)? onIncomingMessage,
    void Function(int level, String state)? onPartnerBattery,
    void Function(bool isHome)? onPartnerIsHome,
    void Function(double lat, double lng)? onPartnerHomePin,
    void Function(List<SavedPlace> places)? onPartnerPlaces,
    void Function(LocationPoint)? onPartnerLocation,
    void Function(int colorValue)? onPartnerPinColor,
    void Function(bool active)? onPartnerPhoneActive,
    void Function(String label)? onPartnerPlaceArrived,
    void Function(String mode)? onPartnerMovement,
  }) {
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final connected = !results.contains(ConnectivityResult.none);
      if (connected && !_online) {
        _online = true;
        _syncAll();
      } else if (!connected) {
        _online = false;
      }
      _statusController.add(SyncStatus(_online, _syncing));
    });

    // initial check
    Connectivity().checkConnectivity().then((results) {
      _online = !results.contains(ConnectivityResult.none);
      if (_online) _syncAll();
      _statusController.add(SyncStatus(_online, _syncing));
    });

    if (token != null) {
      connectSocket(
        token,
        onIncomingMessage,
        onPartnerBattery: onPartnerBattery,
        onPartnerIsHome: onPartnerIsHome,
        onPartnerHomePin: onPartnerHomePin,
        onPartnerPlaces: onPartnerPlaces,
        onPartnerLocation: onPartnerLocation,
        onPartnerPinColor: onPartnerPinColor,
        onPartnerPhoneActive: onPartnerPhoneActive,
        onPartnerPlaceArrived: onPartnerPlaceArrived,
        onPartnerMovement: onPartnerMovement,
      );
    }
  }

  void connectSocket(
    String token,
    void Function(ChatMessage)? onIncomingMessage, {
    void Function(String displayName)? onPartnerArrived,
    void Function(int level, String state)? onPartnerBattery,
    void Function(bool isHome)? onPartnerIsHome,
    void Function(double lat, double lng)? onPartnerHomePin,
    void Function(List<SavedPlace> places)? onPartnerPlaces,
    void Function(LocationPoint)? onPartnerLocation,
    void Function(int colorValue)? onPartnerPinColor,
    void Function(bool active)? onPartnerPhoneActive,
    void Function(String label)? onPartnerPlaceArrived,
    void Function(String mode)? onPartnerMovement,
  }) {
    _socket?.dispose();
    _socket = io.io(
        AppConfig.socketUrl,
        io.OptionBuilder()
            .setAuth({'token': token})
            .disableAutoConnect()
            .enableReconnection()
            .build());
    _socket!.connect();

    // ── Incoming chat message ──────────────────────────────
    _socket!.on('message:new', (data) {
      try {
        final m = ChatMessage.fromJson(data as Map<String, dynamic>);
        LocalStore.cacheMessage(m);
        onIncomingMessage?.call(m);
      } catch (_) {}
    });

    _socket!.on('message:status', (data) {
      try {
        final d = data as Map<String, dynamic>;
        final status = d['status'] as String;
        final clientUid = d['client_uid'] as String?;
        if (clientUid != null) {
          LocalStore.updateMessageStatus(clientUid, status);
        }
      } catch (_) {}
    });

    _socket!.on('location:update', (data) {
      try {
        if (data == null) return;
        final d = data as Map<String, dynamic>;
        final pt = LocationPoint.fromJson(d);
        onPartnerLocation?.call(pt);
      } catch (_) {}
    });
    _socket!.on('sharing:toggle', (_) {});

    // ── Partner arrived home (legacy event) ───────────────
    _socket!.on('home:arrived', (data) {
      try {
        final d = data as Map<String, dynamic>;
        final name = d['display_name'] as String? ?? 'Your partner';
        onPartnerArrived?.call(name);
        onPartnerIsHome?.call(true);
      } catch (_) {}
    });

    // ── Partner home pin set ───────────────────────────────
    _socket!.on('home:pin', (data) {
      try {
        final d = data as Map<String, dynamic>;
        final lat = (d['lat'] as num?)?.toDouble();
        final lng = (d['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          onPartnerHomePin?.call(lat, lng);
        }
      } catch (_) {}
    });

    // ── Partner battery update ─────────────────────────────
    _socket!.on('battery:update', (data) {
      try {
        final d = data as Map<String, dynamic>;
        final level = (d['level'] as num?)?.toInt() ?? -1;
        final state = d['state'] as String? ?? 'unknown';
        onPartnerBattery?.call(level, state);
      } catch (_) {}
    });

    // ── Partner saved places ───────────────────────────────
    _socket!.on('places:sync', (data) {
      try {
        final raw = data is String ? jsonDecode(data) : data;
        final list = (raw as List<dynamic>)
            .map((e) => SavedPlace.fromJson(e as Map<String, dynamic>))
            .toList();
        onPartnerPlaces?.call(list);
      } catch (_) {}
    });

    // ── Partner pin color ──────────────────────────────────
    _socket!.on('pin:color', (data) {
      try {
        final d = data as Map<String, dynamic>;
        final value = (d['color'] as num?)?.toInt();
        if (value != null) onPartnerPinColor?.call(value);
      } catch (_) {}
    });

    // ── Partner phone active state ─────────────────────────
    _socket!.on('phone:active', (data) {
      try {
        final d = data as Map<String, dynamic>;
        final active = d['active'] as bool? ?? false;
        onPartnerPhoneActive?.call(active);
      } catch (_) {}
    });

    // ── Partner arrived at a named place ───────────────────
    _socket!.on('place:arrived', (data) {
      try {
        final d = data as Map<String, dynamic>;
        final label = d['label'] as String? ?? '';
        if (label.isNotEmpty) onPartnerPlaceArrived?.call(label);
      } catch (_) {}
    });

    // ── Partner movement mode ──────────────────────────────
    _socket!.on('movement:update', (data) {
      try {
        final d = data as Map<String, dynamic>;
        final mode = d['mode'] as String? ?? 'unknown';
        onPartnerMovement?.call(mode);
      } catch (_) {}
    });
  }

  // ── Emitters ──────────────────────────────────────────────

  void emitMessage(ChatMessage m) {
    _socket?.emit('message:send', m.toApiJson());
  }

  void emitSharing({required bool sharing, required bool paused}) {
    _socket?.emit('sharing:toggle', {'sharing': sharing, 'paused': paused});
  }

  /// Broadcast that the user has arrived at their home pin.
  void emitHomeArrived() {
    _socket?.emit('home:arrived',
        {'timestamp': DateTime.now().toUtc().toIso8601String()});
  }

  /// Broadcast that the user has arrived at a named saved place.
  void emitPlaceArrived(String label) {
    _socket?.emit('place:arrived', {
      'label': label,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Share the user's home pin coordinates with their partner.
  void emitHomePin({required double lat, required double lng}) {
    _socket?.emit('home:pin', {
      'lat': lat,
      'lng': lng,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Broadcast current battery level to partner.
  void emitBattery({required int level, String state = 'unknown'}) {
    _socket?.emit('battery:update', {'level': level, 'state': state});
  }

  /// Broadcast saved places list to partner.
  void emitPlaces(List<SavedPlace> places) {
    _socket?.emit(
      'places:sync',
      places.map((p) => p.toJson()).toList(),
    );
  }

  /// Broadcast chosen pin border color to partner.
  void emitPinColor(Color color) {
    _socket?.emit('pin:color', {'color': color.toARGB32()});
  }

  /// Broadcast current movement mode to partner.
  void emitMovement(dynamic mode) {
    _socket?.emit('movement:update', {'mode': (mode as dynamic).name});
  }

  /// Broadcast whether the app is in the foreground (phone is active/in-use).
  void emitPhoneActive(bool active) {
    _socket?.emit('phone:active', {'active': active});
  }

  // ── Sync ──────────────────────────────────────────────────
  Future<void> _syncAll() async {
    if (_syncing) return;
    _syncing = true;
    _statusController.add(SyncStatus(_online, _syncing));
    try {
      await _syncLocations();
      await _syncMedia();
      await _syncMessages();
    } finally {
      _syncing = false;
      _statusController.add(SyncStatus(_online, _syncing));
    }
  }

  Future<void> _syncLocations() async {
    final pending = await LocalStore.pendingLocations();
    if (pending.isEmpty) return;
    try {
      final saved = await _api.uploadLocations(pending);
      await LocalStore.clearLocations(saved);
    } catch (_) {}
  }

  Future<void> _syncMessages() async {
    final myId = (await _api.me()).id;
    final pending = await LocalStore.pendingMessages(myId);
    if (pending.isEmpty) return;
    try {
      final saved = await _api.sendMessages(pending);
      await LocalStore.clearMessages(saved);
      for (final m in pending) {
        emitMessage(m);
      }
    } catch (_) {}
  }

  Future<void> _syncMedia() async {
    final rows = await LocalStore.pendingMedia();
    for (final r in rows) {
      final localPath = r['local_path'] as String;
      final clientUid = r['client_uid'] as String;
      try {
        await _api.uploadMedia(localPath);
        await LocalStore.clearMedia(clientUid);
      } catch (_) {
        break;
      }
    }
  }

  Future<void> dispose() async {
    await _connSub?.cancel();
    _socket?.dispose();
    await _statusController.close();
  }
}

class SyncStatus {
  final bool online;
  final bool syncing;
  SyncStatus(this.online, this.syncing);
}
