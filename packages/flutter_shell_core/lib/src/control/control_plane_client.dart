import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_shell_core/control_plane_models.dart';

abstract class ControlPlaneApi {
  Future<HostInfo> hostInfo();
  Future<HostInfo> negotiate({
    required List<String> supportedVersions,
    required List<Capability> requiredCapabilities,
  });
  Future<PlatformTunnelStartResult> startPlatformTunnel({
    required PlatformTunnelMode mode,
  });
  Future<List<ProviderDescriptor>> providers();
  Future<List<ProfileRecord>> profiles();
  Future<ProfileRecord> upsertProfile(ProfileRecord profile);
  Future<void> deleteProfile(String profileId);
  Future<List<ResolutionRecord>> resolutions();
  Future<ResolutionRecord> startResolution({
    required String provider,
    required ProviderInputEnvelope input,
    Map<String, dynamic> providerSettings = const <String, dynamic>{},
  });
  Future<ResolutionRecord> cancelResolution(String resolutionId);
  Future<ResolutionExportResult> exportResolution(String resolutionId);
  Future<SessionRecord> materializeResolution({
    required String resolutionId,
    required RuntimeDefaults runtimeDefaults,
  });
  Future<List<SessionRecord>> sessions();
  Future<SessionRecord> startSession({String? profileId, ProfileSpec? spec});
  Future<SessionRecord> stopSession(String sessionId);
  Future<ChallengeRecord> challenge(String challengeId);
  Future<ChallengeRecord> continueChallenge(String challengeId);
  Future<ChallengeRecord> cancelChallenge(String challengeId);
  Future<DiagnosticsBundle> diagnostics(String sessionId);
  Stream<EventRecord> events();
}

class ControlPlaneClient implements ControlPlaneApi {
  ControlPlaneClient({
    required this.baseUri,
    this.timeout = const Duration(seconds: 10),
    HttpClient Function()? httpClientFactory,
  }) : _httpClientFactory = httpClientFactory ?? HttpClient.new;

  factory ControlPlaneClient.localhost({
    String listenAddress = defaultListenAddress,
  }) {
    return ControlPlaneClient(baseUri: Uri.parse('http://$listenAddress'));
  }

  static const String defaultListenAddress = '127.0.0.1:7777';
  static const String contractVersion = '1';

  final Uri baseUri;
  final Duration timeout;
  final HttpClient Function() _httpClientFactory;

  @override
  Future<HostInfo> hostInfo() async {
    final payload = await _jsonRequest('GET', '/v1/host');
    return HostInfo.fromJson(payload);
  }

  @override
  Future<HostInfo> negotiate({
    required List<String> supportedVersions,
    required List<Capability> requiredCapabilities,
  }) async {
    final payload = await _jsonRequest(
      'POST',
      '/v1/negotiate',
      body: <String, dynamic>{
        'supported_versions': supportedVersions,
        'required_capabilities': requiredCapabilities
            .map((capability) => capability.value)
            .toList(growable: false),
      },
    );
    return HostInfo.fromJson(payload);
  }

  @override
  Future<PlatformTunnelStartResult> startPlatformTunnel({
    required PlatformTunnelMode mode,
  }) async {
    final payload = await _jsonRequest(
      'POST',
      '/v1/platform-tunnels/start',
      body: <String, dynamic>{'mode': mode.value},
    );
    return PlatformTunnelStartResult.fromJson(payload);
  }

  @override
  Future<List<ProviderDescriptor>> providers() async {
    final payload = await _jsonRequestList('GET', '/v1/providers');
    return payload.map(ProviderDescriptor.fromJson).toList(growable: false);
  }

  @override
  Future<List<ProfileRecord>> profiles() async {
    final payload = await _jsonRequestList('GET', '/v1/profiles');
    return payload.map(ProfileRecord.fromJson).toList(growable: false);
  }

  @override
  Future<ProfileRecord> upsertProfile(ProfileRecord profile) async {
    final payload = await _jsonRequest(
      'POST',
      '/v1/profiles',
      body: profile.toJson(),
    );
    return ProfileRecord.fromJson(payload);
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    await _request('DELETE', '/v1/profiles/$profileId');
  }

  @override
  Future<List<ResolutionRecord>> resolutions() async {
    final payload = await _jsonRequestList('GET', '/v1/resolutions');
    return payload.map(ResolutionRecord.fromJson).toList(growable: false);
  }

  @override
  Future<ResolutionRecord> startResolution({
    required String provider,
    required ProviderInputEnvelope input,
    Map<String, dynamic> providerSettings = const <String, dynamic>{},
  }) async {
    final payload = await _jsonRequest(
      'POST',
      '/v1/resolutions',
      body: <String, dynamic>{
        'provider': provider,
        'input': input.toJson(),
        if (providerSettings.isNotEmpty) 'provider_settings': providerSettings,
      },
    );
    return ResolutionRecord.fromJson(payload);
  }

  @override
  Future<ResolutionRecord> cancelResolution(String resolutionId) async {
    final payload = await _jsonRequest(
      'POST',
      '/v1/resolutions/$resolutionId/cancel',
    );
    return ResolutionRecord.fromJson(payload);
  }

  @override
  Future<ResolutionExportResult> exportResolution(String resolutionId) async {
    final payload = await _jsonRequest(
      'POST',
      '/v1/resolutions/$resolutionId/export',
    );
    return ResolutionExportResult.fromJson(payload);
  }

  @override
  Future<SessionRecord> materializeResolution({
    required String resolutionId,
    required RuntimeDefaults runtimeDefaults,
  }) async {
    final payload = await _jsonRequest(
      'POST',
      '/v1/resolutions/$resolutionId/materialize',
      body: <String, dynamic>{'runtime_defaults': runtimeDefaults.toJson()},
    );
    return SessionRecord.fromJson(payload);
  }

  @override
  Future<List<SessionRecord>> sessions() async {
    final payload = await _jsonRequestList('GET', '/v1/sessions');
    return payload.map(SessionRecord.fromJson).toList(growable: false);
  }

  @override
  Future<SessionRecord> startSession({
    String? profileId,
    ProfileSpec? spec,
  }) async {
    final payload = await _jsonRequest(
      'POST',
      '/v1/sessions',
      body: <String, dynamic>{
        if (profileId != null && profileId.isNotEmpty) 'profile_id': profileId,
        if (spec != null) 'spec': spec.toJson(),
      },
    );
    return SessionRecord.fromJson(payload);
  }

  @override
  Future<SessionRecord> stopSession(String sessionId) async {
    final payload = await _jsonRequest('POST', '/v1/sessions/$sessionId/stop');
    return SessionRecord.fromJson(payload);
  }

  @override
  Future<ChallengeRecord> challenge(String challengeId) async {
    final payload = await _jsonRequest('GET', '/v1/challenges/$challengeId');
    return ChallengeRecord.fromJson(payload);
  }

  @override
  Future<ChallengeRecord> continueChallenge(String challengeId) async {
    final payload = await _jsonRequest(
      'POST',
      '/v1/challenges/$challengeId/continue',
    );
    return ChallengeRecord.fromJson(payload);
  }

  @override
  Future<ChallengeRecord> cancelChallenge(String challengeId) async {
    final payload = await _jsonRequest(
      'POST',
      '/v1/challenges/$challengeId/cancel',
    );
    return ChallengeRecord.fromJson(payload);
  }

  @override
  Future<DiagnosticsBundle> diagnostics(String sessionId) async {
    final payload = await _jsonRequest(
      'GET',
      '/v1/sessions/$sessionId/diagnostics',
    );
    return DiagnosticsBundle.fromJson(payload);
  }

  @override
  Stream<EventRecord> events() async* {
    final client = _httpClientFactory();
    try {
      final request = await client
          .getUrl(_resolve('/v1/events'))
          .timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode >= 400) {
        final body = await response.transform(utf8.decoder).join();
        throw _errorFromBody(response.statusCode, body);
      }
      await for (final line
          in response.transform(utf8.decoder).transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        yield EventRecord.fromJson(jsonDecode(trimmed) as Map<String, dynamic>);
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _jsonRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _request(method, path, body: body);
    if (response.body.isEmpty) {
      return const <String, dynamic>{};
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> _jsonRequestList(
    String method,
    String path,
  ) async {
    final response = await _request(method, path);
    if (response.body.isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    return (jsonDecode(response.body) as List<dynamic>)
        .map((dynamic raw) => raw as Map<String, dynamic>)
        .toList(growable: false);
  }

  Future<_ResponsePayload> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final client = _httpClientFactory();
    try {
      final request = await _open(client, method, path);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(timeout);
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 400) {
        throw _errorFromBody(response.statusCode, responseBody);
      }
      return _ResponsePayload(response.statusCode, responseBody);
    } on SocketException catch (error) {
      throw ControlPlaneError(
        statusCode: 0,
        code: 'connection_failed',
        message: error.message,
      );
    } on TimeoutException {
      throw const ControlPlaneError(
        statusCode: 0,
        code: 'timeout',
        message: 'request timed out',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<HttpClientRequest> _open(
    HttpClient client,
    String method,
    String path,
  ) {
    final uri = _resolve(path);
    switch (method) {
      case 'GET':
        return client.getUrl(uri);
      case 'POST':
        return client.postUrl(uri);
      case 'DELETE':
        return client.deleteUrl(uri);
      default:
        throw ArgumentError.value(method, 'method', 'unsupported HTTP method');
    }
  }

  Uri _resolve(String path) {
    return baseUri.resolve(path);
  }

  ControlPlaneError _errorFromBody(int statusCode, String body) {
    if (body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return ControlPlaneError(
            statusCode: statusCode,
            code: decoded['code'] as String? ?? 'request_failed',
            message: decoded['message'] as String? ?? body,
            action: decoded['action'] as String?,
            field: decoded['field'] as String?,
            violation: decoded['violation'] as String?,
            stage: decoded['stage'] as String?,
            notImplemented: decoded['not_implemented'] as bool? ?? false,
          );
        }
      } on FormatException {
        // Fall back to a raw body message when the upstream response is not JSON.
      }
    }
    return ControlPlaneError(
      statusCode: statusCode,
      code: 'request_failed',
      message: body.isEmpty ? 'HTTP $statusCode' : body,
    );
  }
}

class _ResponsePayload {
  const _ResponsePayload(this.statusCode, this.body);

  final int statusCode;
  final String body;
}
