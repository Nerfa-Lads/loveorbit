import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(init);
  }

  static Future<void> notify({
    required String title,
    required String body,
    int id = 0,
  }) async {
    const android = AndroidNotificationDetails(
      'loveorbit', 'LoveOrbit',
      importance: Importance.high,
      priority: Priority.high,
    );
    const platform = NotificationDetails(android: android);
    await _plugin.show(id, title, body, platform);
  }
}
