import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/models.dart';

class ApiService {
  static const _tokenKey = 'jwt_token';
  static String? _token;

  static Future<String?> get token async {
    if (_token != null) return _token;
    final sp = await SharedPreferences.getInstance();
    _token = sp.getString(_tokenKey);
    return _token;
  }

  static Future<void> saveToken(String t) async {
    _token = t;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_tokenKey, t);
  }

  static Future<void> clearToken() async {
    _token = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_tokenKey);
  }

  Uri _uri(String path) => Uri.parse('${AppConfig.backendUrl}$path');

  Future<Map<String, String>> get _authHeaders async => {
        'Content-Type': 'application/json',
        if (await token != null) 'Authorization': 'Bearer ${await token}',
      };

  // ---------- auth ----------
  Future<({String token, AppUser user})> register({
    required String username,
    required String password,
    required String displayName,
  }) async {
    final res = await http.post(_uri('/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'display_name': displayName,
        }));
    final j = _parse(res);
    await saveToken(j['token'] as String);
    return (token: j['token'] as String, user: AppUser.fromJson(j['user']));
  }

  Future<({String token, AppUser user})> login({
    required String username,
    required String password,
  }) async {
    final res = await http.post(_uri('/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}));
    final j = _parse(res);
    await saveToken(j['token'] as String);
    return (token: j['token'] as String, user: AppUser.fromJson(j['user']));
  }

  Future<AppUser> me() async {
    final res =
        await http.get(_uri('/api/auth/me'), headers: await _authHeaders);
    final j = _parse(res);
    return AppUser.fromJson(j['user']);
  }

  Future<AppUser> updateProfile(
      {String? displayName, String? avatarUrl}) async {
    final res = await http.put(_uri('/api/auth/profile'),
        headers: await _authHeaders,
        body:
            jsonEncode({'display_name': displayName, 'avatar_url': avatarUrl}));
    final j = _parse(res);
    return AppUser.fromJson(j['user']);
  }

  Future<void> deleteAccount() async {
    final res = await http.delete(_uri('/api/auth/account'),
        headers: await _authHeaders);
    _parse(res);
    await clearToken();
  }

  // ---------- couples ----------
  Future<Couple> createCouple() async {
    final res = await http.post(_uri('/api/couples/create'),
        headers: await _authHeaders);
    final j = _parse(res);
    return Couple.fromJson(j['couple']);
  }

  Future<Couple> joinCouple(String code) async {
    final res = await http.post(_uri('/api/couples/join'),
        headers: await _authHeaders, body: jsonEncode({'code': code}));
    final j = _parse(res);
    return Couple.fromJson(j['couple']);
  }

  Future<({Couple? couple, Partner? partner})> myCouple() async {
    final res =
        await http.get(_uri('/api/couples/me'), headers: await _authHeaders);
    final j = _parse(res);
    final couple = j['couple'] == null ? null : Couple.fromJson(j['couple']);
    final partner =
        j['partner'] == null ? null : Partner.fromJson(j['partner']);
    return (couple: couple, partner: partner);
  }

  Future<void> disconnect() async {
    final res = await http.post(_uri('/api/couples/disconnect'),
        headers: await _authHeaders);
    _parse(res);
  }

  // ---------- locations ----------
  Future<List<String>> uploadLocations(List<LocationPoint> points) async {
    final res = await http.post(_uri('/api/locations'),
        headers: await _authHeaders,
        body:
            jsonEncode({'points': points.map((p) => p.toApiJson()).toList()}));
    final j = _parse(res);
    return List<String>.from(j['saved_uids'] as List? ?? []);
  }

  Future<List<LocationPoint>> myLocations(
      {DateTime? from, DateTime? to}) async {
    final q = <String, String>{};
    if (from != null) q['from'] = from.toUtc().toIso8601String();
    if (to != null) q['to'] = to.toUtc().toIso8601String();
    final res = await http.get(_uri('/api/locations/me?${_query(q)}'),
        headers: await _authHeaders);
    final j = _parse(res);
    return (j['points'] as List).map((e) => LocationPoint.fromJson(e)).toList();
  }

  Future<List<LocationPoint>> partnerLocations(
      {DateTime? from, DateTime? to}) async {
    final q = <String, String>{};
    if (from != null) q['from'] = from.toUtc().toIso8601String();
    if (to != null) q['to'] = to.toUtc().toIso8601String();
    final res = await http.get(_uri('/api/locations/partner?${_query(q)}'),
        headers: await _authHeaders);
    final j = _parse(res);
    return (j['points'] as List).map((e) => LocationPoint.fromJson(e)).toList();
  }

  Future<LocationPoint?> partnerLatest() async {
    final res = await http.get(_uri('/api/locations/partner/latest'),
        headers: await _authHeaders);
    final j = _parse(res);
    return j['point'] == null ? null : LocationPoint.fromJson(j['point']);
  }

  Future<void> deleteMyLocations({DateTime? from, DateTime? to}) async {
    final q = <String, String>{};
    if (from != null) q['from'] = from.toUtc().toIso8601String();
    if (to != null) q['to'] = to.toUtc().toIso8601String();
    final res = await http.delete(_uri('/api/locations/me?${_query(q)}'),
        headers: await _authHeaders);
    _parse(res);
  }

  Future<({bool sharing, bool paused})> getSharing() async {
    final res = await http.get(_uri('/api/locations/sharing'),
        headers: await _authHeaders);
    final j = _parse(res);
    return (
      sharing: j['sharing'] as bool? ?? false,
      paused: j['paused'] as bool? ?? false
    );
  }

  Future<void> setSharing({required bool sharing, required bool paused}) async {
    final res = await http.put(_uri('/api/locations/sharing'),
        headers: await _authHeaders,
        body: jsonEncode({'sharing': sharing, 'paused': paused}));
    _parse(res);
  }

  // ---------- messages ----------
  Future<List<ChatMessage>> messages(
      {int limit = 100, DateTime? before}) async {
    final q = <String, String>{'limit': limit.toString()};
    if (before != null) q['before'] = before.toUtc().toIso8601String();
    final res = await http.get(_uri('/api/messages?${_query(q)}'),
        headers: await _authHeaders);
    final j = _parse(res);
    return (j['messages'] as List).map((e) => ChatMessage.fromJson(e)).toList();
  }

  Future<List<String>> sendMessages(List<ChatMessage> msgs) async {
    final res = await http.post(_uri('/api/messages'),
        headers: await _authHeaders,
        body:
            jsonEncode({'messages': msgs.map((m) => m.toApiJson()).toList()}));
    final j = _parse(res);
    return (j['saved'] as List? ?? [])
        .map((e) => e['client_uid'] as String)
        .toList();
  }

  Future<void> markStatus(List<String> ids, String status) async {
    final res = await http.post(_uri('/api/messages/status'),
        headers: await _authHeaders,
        body: jsonEncode({'message_ids': ids, 'status': status}));
    _parse(res);
  }

  // ---------- avatar ----------
  Future<AppUser> uploadAvatar(String filePath) async {
    final tok = await token ?? '';
    final req = http.MultipartRequest('POST', _uri('/api/auth/avatar'));
    req.headers['Authorization'] = 'Bearer $tok';
    req.files.add(await http.MultipartFile.fromPath('avatar', filePath));

    final streamed = await req.send().timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode >= 400) {
      String msg = 'upload_failed';
      try {
        final j = jsonDecode(res.body);
        msg = j['error'] as String? ?? msg;
      } catch (_) {}
      switch (msg) {
        case 'file_too_large':
          throw ApiException('Image is too large (max 5 MB).', res.statusCode);
        case 'images_only':
          throw ApiException('Only image files are allowed.', res.statusCode);
        case 'no_file':
          throw ApiException(
              'No file was received by the server.', res.statusCode);
        case 'unauthorized':
          throw ApiException(
              'Session expired. Please log in again.', res.statusCode);
        default:
          throw ApiException('Upload failed: $msg', res.statusCode);
      }
    }

    final j = _parse(res);
    return AppUser.fromJson(j['user']);
  }

  // ---------- media ----------
  Future<Media> uploadMedia(String filePath) async {
    final req = http.MultipartRequest('POST', _uri('/api/media'));
    req.headers['Authorization'] = 'Bearer ${await token ?? ''}';
    req.files.add(await http.MultipartFile.fromPath('photo', filePath));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    final j = _parse(res);
    return Media.fromJson(j['media']);
  }

  // ---------- devices ----------
  Future<void> registerDevice(String token,
      {String platform = 'android'}) async {
    final res = await http.post(_uri('/api/devices'),
        headers: await _authHeaders,
        body: jsonEncode({'token': token, 'platform': platform}));
    _parse(res);
  }

  // ---------- helpers ----------
  String _query(Map<String, String> q) => q.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');

  dynamic _parse(http.Response res) {
    final body = res.body.isEmpty ? '{}' : res.body;
    final j = jsonDecode(body);
    if (res.statusCode >= 400) {
      throw ApiException(j['error'] ?? 'request_failed', res.statusCode);
    }
    return j;
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}
