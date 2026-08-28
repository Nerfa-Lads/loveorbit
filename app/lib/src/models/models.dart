class AppUser {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? coupleId;

  AppUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.coupleId,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        username: j['username'] as String? ?? '',
        displayName: j['display_name'] as String? ?? '',
        avatarUrl: j['avatar_url'] as String?,
        coupleId: j['couple_id'] as String?,
      );
}

class Couple {
  final String id;
  final String code;
  final String creatorId;
  final String? partnerId;
  final bool creatorAccepted;
  final bool partnerAccepted;
  final String status; // pending | active | disconnected

  Couple({
    required this.id,
    required this.code,
    required this.creatorId,
    this.partnerId,
    required this.creatorAccepted,
    required this.partnerAccepted,
    required this.status,
  });

  factory Couple.fromJson(Map<String, dynamic> j) => Couple(
        id: j['id'] as String,
        code: j['code'] as String,
        creatorId: j['creator_id'] as String,
        partnerId: j['partner_id'] as String?,
        creatorAccepted: j['creator_accepted'] as bool? ?? false,
        partnerAccepted: j['partner_accepted'] as bool? ?? false,
        status: j['status'] as String? ?? 'pending',
      );
}

class Partner {
  final String id;
  final String displayName;
  final String? avatarUrl;

  Partner({required this.id, required this.displayName, this.avatarUrl});

  factory Partner.fromJson(Map<String, dynamic> j) => Partner(
        id: j['id'] as String,
        displayName: j['display_name'] as String? ?? '',
        avatarUrl: j['avatar_url'] as String?,
      );
}

class LocationPoint {
  final String? id;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final double? altitude;
  final DateTime recordedAt;
  final String clientUid;

  LocationPoint({
    this.id,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    this.heading,
    this.altitude,
    required this.recordedAt,
    required this.clientUid,
  });

  factory LocationPoint.fromJson(Map<String, dynamic> j) => LocationPoint(
        id: j['id'] as String?,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        accuracy: (j['accuracy'] as num?)?.toDouble(),
        speed: (j['speed'] as num?)?.toDouble(),
        heading: (j['heading'] as num?)?.toDouble(),
        altitude: (j['altitude'] as num?)?.toDouble(),
        recordedAt: DateTime.parse(j['recorded_at'] as String).toLocal(),
        clientUid: j['client_uid'] as String? ?? '',
      );

  Map<String, dynamic> toApiJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'speed': speed,
        'heading': heading,
        'altitude': altitude,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
        'client_uid': clientUid,
      };
}

class ChatMessage {
  final String? id;
  final String senderId;
  final String receiverId;
  final String? body;
  final String? mediaId;
  final String? mediaUrl;
  final String? mediaContentType;
  final String status; // sent | delivered | read
  final DateTime createdAt;
  final String clientUid;

  ChatMessage({
    this.id,
    required this.senderId,
    required this.receiverId,
    this.body,
    this.mediaId,
    this.mediaUrl,
    this.mediaContentType,
    required this.status,
    required this.createdAt,
    required this.clientUid,
  });

  bool get isMine => senderId == receiverId ? false : true; // set by provider
  bool get isPhoto => mediaId != null || mediaUrl != null;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String?,
        senderId: j['sender_id'] as String,
        receiverId: j['receiver_id'] as String,
        body: j['body'] as String?,
        mediaId: j['media_id'] as String?,
        mediaUrl: j['media_url'] as String?,
        mediaContentType: j['media_content_type'] as String?,
        status: j['status'] as String? ?? 'sent',
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        clientUid: j['client_uid'] as String? ?? '',
      );

  Map<String, dynamic> toApiJson() => {
        'body': body,
        'media_id': mediaId,
        'created_at': createdAt.toUtc().toIso8601String(),
        'client_uid': clientUid,
      };
}

class Media {
  final String id;
  final String url;
  final String contentType;

  Media({required this.id, required this.url, required this.contentType});

  factory Media.fromJson(Map<String, dynamic> j) => Media(
        id: j['id'] as String,
        url: j['url'] as String,
        contentType: j['content_type'] as String? ?? 'image/jpeg',
      );
}

// ── Saved place ───────────────────────────────────────────────
/// A user-defined location with a personal label (e.g. "Home", "Sister's house").
class SavedPlace {
  final String id;
  final String label;
  final double lat;
  final double lng;

  SavedPlace({
    required this.id,
    required this.label,
    required this.lat,
    required this.lng,
  });

  factory SavedPlace.fromJson(Map<String, dynamic> j) => SavedPlace(
        id: j['id'] as String,
        label: j['label'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'lat': lat,
        'lng': lng,
      };

  SavedPlace copyWith({String? label, double? lat, double? lng}) => SavedPlace(
        id: id,
        label: label ?? this.label,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
      );
}
