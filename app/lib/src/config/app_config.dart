class AppConfig {
  // Change this to your backend's public URL (e.g. Render/Railway URL).
  // For local dev with an Android emulator use http://10.0.2.2:4000
  // For a real device on the same wifi as your dev machine use http://<your-lan-ip>:4000
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://loveorbit.onrender.com',
  );

  static const String socketUrl = backendUrl;

  // ESRI World Imagery — free satellite tiles, no API key required
  static const String mapTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  // ESRI street/label overlay on top of satellite (roads, place names, barangays)
  static const String mapLabelUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}';

  static const String mapAttribution =
      'Tiles &copy; Esri &mdash; Source: Esri, DigitalGlobe, GeoEye, Earthstar Geographics';
}
