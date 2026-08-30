import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

/// Local SQLite store for offline-first data.
/// Tables:
///   locations_pending  — GPS points not yet confirmed by server
///   messages_pending   — chat messages not yet confirmed by server
///   media_pending      — photo files queued for upload
///   messages_local     — cache of recent messages for offline viewing
class LocalStore {
  static Database? _db;

  static Future<Database> db() async {
    if (_db != null) return _db!;
    final docs = await getApplicationDocumentsDirectory();
    final path = p.join(docs.path, 'loveorbit.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE locations_pending (
            client_uid TEXT PRIMARY KEY,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            accuracy REAL,
            speed REAL,
            heading REAL,
            altitude REAL,
            recorded_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE messages_pending (
            client_uid TEXT PRIMARY KEY,
            receiver_id TEXT NOT NULL,
            body TEXT,
            media_id TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE media_pending (
            client_uid TEXT PRIMARY KEY,
            local_path TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE messages_local (
            id TEXT PRIMARY KEY,
            sender_id TEXT NOT NULL,
            receiver_id TEXT NOT NULL,
            body TEXT,
            media_url TEXT,
            media_content_type TEXT,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL,
            client_uid TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  // ---------- locations ----------
  static Future<void> queueLocation(LocationPoint pt) async {
    final d = await db();
    await d.insert(
        'locations_pending',
        {
          'client_uid': pt.clientUid,
          'latitude': pt.latitude,
          'longitude': pt.longitude,
          'accuracy': pt.accuracy,
          'speed': pt.speed,
          'heading': pt.heading,
          'altitude': pt.altitude,
          'recorded_at': pt.recordedAt.toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<LocationPoint>> pendingLocations() async {
    final d = await db();
    final rows = await d.query('locations_pending', orderBy: 'recorded_at ASC');
    return rows
        .map((r) => LocationPoint(
              latitude: r['latitude'] as double,
              longitude: r['longitude'] as double,
              accuracy: r['accuracy'] as double?,
              speed: r['speed'] as double?,
              heading: r['heading'] as double?,
              altitude: r['altitude'] as double?,
              recordedAt: DateTime.parse(r['recorded_at'] as String).toLocal(),
              clientUid: r['client_uid'] as String,
            ))
        .toList();
  }

  static Future<void> clearLocations(List<String> clientUids) async {
    if (clientUids.isEmpty) return;
    final d = await db();
    final placeholders = List.filled(clientUids.length, '?').join(',');
    await d.rawDelete(
      'DELETE FROM locations_pending WHERE client_uid IN ($placeholders)',
      clientUids,
    );
  }

  /// Delete ALL rows from locations_pending regardless of upload status.
  static Future<void> clearAllPendingLocations() async {
    final d = await db();
    await d.delete('locations_pending');
  }

  // ---------- messages ----------
  static Future<void> queueMessage(ChatMessage m) async {
    final d = await db();
    await d.insert(
        'messages_pending',
        {
          'client_uid': m.clientUid,
          'receiver_id': m.receiverId,
          'body': m.body,
          'media_id': m.mediaId,
          'created_at': m.createdAt.toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
    await cacheMessage(m);
  }

  static Future<List<ChatMessage>> pendingMessages(String myId) async {
    final d = await db();
    final rows = await d.query('messages_pending', orderBy: 'created_at ASC');
    return rows
        .map((r) => ChatMessage(
              senderId: myId,
              receiverId: r['receiver_id'] as String,
              body: r['body'] as String?,
              mediaId: r['media_id'] as String?,
              createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
              clientUid: r['client_uid'] as String,
              status: 'pending',
            ))
        .toList();
  }

  static Future<void> clearMessages(List<String> clientUids) async {
    if (clientUids.isEmpty) return;
    final d = await db();
    final placeholders = List.filled(clientUids.length, '?').join(',');
    await d.rawDelete(
      'DELETE FROM messages_pending WHERE client_uid IN ($placeholders)',
      clientUids,
    );
  }

  static Future<void> cacheMessage(ChatMessage m) async {
    final d = await db();
    await d.insert(
        'messages_local',
        {
          'id': m.id ?? m.clientUid,
          'sender_id': m.senderId,
          'receiver_id': m.receiverId,
          'body': m.body,
          'media_url': m.mediaUrl,
          'media_content_type': m.mediaContentType,
          'status': m.status,
          'created_at': m.createdAt.toUtc().toIso8601String(),
          'client_uid': m.clientUid,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<ChatMessage>> cachedMessages() async {
    final d = await db();
    final rows = await d.query('messages_local', orderBy: 'created_at ASC');
    return rows
        .map((r) => ChatMessage(
              id: r['id'] as String?,
              senderId: r['sender_id'] as String,
              receiverId: r['receiver_id'] as String,
              body: r['body'] as String?,
              mediaUrl: r['media_url'] as String?,
              mediaContentType: r['media_content_type'] as String?,
              status: r['status'] as String? ?? 'sent',
              createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
              clientUid: r['client_uid'] as String,
            ))
        .toList();
  }

  static Future<void> updateMessageStatus(
      String clientUid, String status) async {
    final d = await db();
    await d.rawUpdate(
      'UPDATE messages_local SET status = ? WHERE client_uid = ?',
      [status, clientUid],
    );
  }

  // ---------- media ----------
  static Future<void> queueMedia(String clientUid, String localPath) async {
    final d = await db();
    await d.insert(
        'media_pending',
        {
          'client_uid': clientUid,
          'local_path': localPath,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> pendingMedia() async {
    final d = await db();
    return d.query('media_pending', orderBy: 'created_at ASC');
  }

  static Future<void> clearMedia(String clientUid) async {
    final d = await db();
    await d.delete('media_pending',
        where: 'client_uid = ?', whereArgs: [clientUid]);
  }
}
