import '../../core/config/env.dart';

/// REST API contract for the production backend.
///
/// The mock repositories in `data/mock` implement the same domain interfaces
/// as the HTTP repositories that will live here, so swapping is a one-line
/// change in `core/di/service_locator.dart`.
///
/// Endpoints (all JSON, all behind `Authorization: Bearer <access token>`):
///
///   POST   /v1/auth/login                 {identifier, password}
///   POST   /v1/auth/oauth/{google|apple}  {idToken}
///   POST   /v1/auth/otp                   {destination}
///   POST   /v1/auth/otp/verify            {destination, code}
///   POST   /v1/auth/password/reset        {destination, code, password}
///   POST   /v1/auth/refresh               {refreshToken}
///   DELETE /v1/users/me                   (account deletion; reports de-identified)
///
///   GET    /v1/reports?citizen=&category=&status=&q=&page=&pageSize=
///   POST   /v1/reports                    multipart: draft JSON + compressed evidence
///   GET    /v1/reports/{id}
///   GET    /v1/reports/nearby?lat=&lng=&category=&radius=
///   POST   /v1/reports/{id}/support
///   POST   /v1/reports/{id}/transitions   {to, note}       (server validates state machine + RBAC)
///   POST   /v1/reports/{id}/assignments   {teamId, eta}
///   POST   /v1/reports/{id}/comments      {body, isQuestion}
///   POST   /v1/reports/{id}/evidence      multipart (signed upload URL in production)
///   POST   /v1/reports/{id}/feedback      {resolved|partial|remains}
///   GET    /v1/audit?reportId=
///
///   GET    /v1/notifications              PATCH /v1/notifications/{id}/read
///   GET    /v1/teams    GET /v1/vehicles  GET /v1/vehicles/{id}/position (SSE/websocket)
///   POST   /v1/waste/pickups              GET /v1/waste/pickups
///   GET    /v1/service-points?kind=water|waste
///   GET    /v1/analytics/city             GET /v1/analytics/snapshot
///   POST   /v1/ai/analyze-report          POST /v1/ai/classify-waste
///
/// Security notes:
///  * Tokens are short-lived; refresh tokens belong in platform secure storage.
///  * Uploads go to pre-signed URLs; the server re-encodes images and strips EXIF.
///  * Rate limiting is enforced server-side per user + per IP (429 → [ApiException]).
///  * No third-party API keys ship in the client; AI & geocoding are proxied.
class ApiClient {
  final String baseUrl;
  String? _accessToken;

  ApiClient({this.baseUrl = Env.apiBaseUrl});

  void setToken(String? token) => _accessToken = token;
  bool get isAuthenticated => _accessToken != null;

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'X-Municipality': Env.municipalityId,
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Uri uri(String path, [Map<String, String>? query]) => Uri.parse('$baseUrl$path').replace(queryParameters: query);
}
