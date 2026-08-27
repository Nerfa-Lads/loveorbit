class AppConfig {
  // Change this to your backend's public URL (e.g. Render/Railway URL).
  // For local dev with an Android emulator use http://10.0.2.2:4000
  // For a real device on the same wifi as your dev machine use http://<your-lan-ip>:4000
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://loveorbit.onrender.com',
  );

  static const String socketUrl = backendUrl;

  static const String mapTileUrl =
      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String mapAttribution = '&copy; OpenStreetMap contributors';
}
