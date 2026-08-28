import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/local_store.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';

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

class AppProvider extends ChangeNotifier {
  final _api = ApiService();

  AppUser? user;
  Couple? couple;
  Partner? partner;
  bool sharing = false;
  bool paused = false;
  bool online = false;
  bool syncing = false;
  LocationPoint? partnerLatest;
  List<ChatMessage> messages = [];
  String? _myId;
  StreamSubscription<SyncStatus>? _syncSub;

  // Pin border color preference
  Color _pinBorderColor = kPinBorderColors.first;
  Color get pinBorderColor => _pinBorderColor;

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
  }

  bool get isConnected => couple?.status == 'active' && partner != null;

  Future<void> bootstrap() async {
    await _loadPinColor();
    final tok = await ApiService.token;
    if (tok == null) return;
    try {
      user = await _api.me();
      _myId = user!.id;
      await refreshCouple();
      await loadSharing();
      await loadMessages();
      messages = await LocalStore.cachedMessages();
      SyncService.instance.init(token: tok, onIncomingMessage: _onIncoming);
      _listenSync();
      notifyListeners();
    } catch (e) {
      // Only clear token on auth errors, not network errors
      final msg = e.toString();
      if (msg.contains('unauthorized') || msg.contains('401')) {
        await ApiService.clearToken();
      }
      notifyListeners();
    }
  }

  // ---------- auth ----------
  Future<void> register(String username, String password, String name) async {
    final r = await _api.register(
        username: username, password: password, displayName: name);
    user = r.user;
    _myId = user!.id;
    SyncService.instance.init(token: r.token, onIncomingMessage: _onIncoming);
    _listenSync();
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final r = await _api.login(username: username, password: password);
    user = r.user;
    _myId = user!.id;
    await refreshCouple();
    await loadSharing();
    messages = await LocalStore.cachedMessages();
    SyncService.instance.init(token: r.token, onIncomingMessage: _onIncoming);
    _listenSync();
    notifyListeners();
  }

  Future<void> logout() async {
    await _syncSub?.cancel();
    await LocationService.instance.stopRecording();
    await SyncService.instance.dispose();
    await ApiService.clearToken();
    user = null;
    couple = null;
    partner = null;
    messages = [];
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

  // ---------- couple ----------
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

  // ---------- sharing ----------
  Future<void> loadSharing() async {
    final s = await _api.getSharing();
    sharing = s.sharing;
    paused = s.paused;
    notifyListeners();
  }

  Future<void> setSharing({required bool on, bool? pause}) async {
    sharing = on;
    paused = pause ?? (on ? false : paused);
    await _api.setSharing(sharing: sharing, paused: paused);
    SyncService.instance.emitSharing(sharing: sharing, paused: paused);
    if (on && !paused) {
      await LocationService.instance.startRecording();
    } else {
      await LocationService.instance.stopRecording();
    }
    notifyListeners();
  }

  Future<void> stopSharing() async {
    sharing = false;
    paused = false;
    await _api.setSharing(sharing: false, paused: false);
    await LocationService.instance.stopRecording();
    notifyListeners();
  }

  // ---------- messages ----------
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
    // simple unique id without extra dep cycle
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

  // ---------- history ----------
  Future<void> deleteMyHistory() async {
    await _api.deleteMyLocations();
  }

  // ---------- partner location ----------
  Future<void> refreshPartnerLatest() async {
    if (!isConnected) return;
    try {
      partnerLatest = await _api.partnerLatest();
      notifyListeners();
    } catch (_) {}
  }
}
