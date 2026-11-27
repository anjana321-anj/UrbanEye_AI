/// Build-time configuration. Values are injected with --dart-define and are
/// never hardcoded secrets. Example:
///
///   flutter run --dart-define=API_BASE_URL=https://api.city.gov.np \
///               --dart-define=USE_MOCK_BACKEND=false
///
/// Real API keys (maps, AI vision) must live on the server; the client only
/// talks to the UrbanEye API with a short-lived user token.
class Env {
  Env._();

  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.urbaneye.example');
  static const useMockBackend = bool.fromEnvironment('USE_MOCK_BACKEND', defaultValue: true);

  /// Map tiles. CARTO basemaps are free for low-volume use with attribution.
  static const mapTilesLight = String.fromEnvironment('MAP_TILES_LIGHT',
      defaultValue: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png');
  static const mapTilesDark = String.fromEnvironment('MAP_TILES_DARK',
      defaultValue: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png');
  static const mapAttribution = '© OpenStreetMap contributors © CARTO';

  /// Municipality the client is configured for (multi-tenant ready).
  static const municipalityId = String.fromEnvironment('MUNICIPALITY_ID', defaultValue: 'ktm-metro');

  static const consentVersion = '2026.10';
  static const appVersion = '1.0.0';
}
