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
    String? resolutionId,
    RuntimeDefaults? runtimeDefaults,
    RuntimeExecutionPlan? executionPlan,
    TransportProfileReference? transportProfile,
    PlatformTunnelApplicationRoutingPolicy applicationRoutingPolicy =
        PlatformTunnelApplicationRoutingPolicy.allApps,
    PlatformTunnelUnderlayRoutePolicy underlayRoutePolicy =
        PlatformTunnelUnderlayRoutePolicy.standard,
    List<String> allowedPackages = const <String>[],
    List<String> disallowedPackages = const <String>[],
  });
  Future<PlatformTunnelStartResult> resumePlatformTunnel({
    required String startupAttemptId,
  });
  Future<PlatformTunnelStopResult> stopPlatformTunnel({
    required PlatformTunnelMode mode,
  });
  Future<List<ProviderDescriptor>> providers();
  Future<List<ProviderConfigRecord>> providerConfigs();
  Future<ProviderConfigRecord> upsertProviderConfig(
    ProviderConfigRecord config,
  );
  Future<ProviderConfigRecord> restoreProviderConfig(
    ProviderConfigRecord config,
  );
  Future<void> deleteProviderConfig(String configId);
  Future<List<TransportProfileStatus>> transportProfiles();
  Future<TransportProfileStatus> importTransportProfile(
    TransportProfileImportRequest request,
  );
  Future<void> forgetTransportProfile(String profileId);
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
    RuntimeExecutionPlan? executionPlan,
  });
  Future<List<SessionRecord>> sessions();
  Future<SessionRecord> startSession({String? profileId, ProfileSpec? spec});
  Future<SessionRecord> stopSession(String sessionId);
  Future<ChallengeRecord> challenge(String challengeId);
  Future<ChallengeRecord> continueChallenge(
    String challengeId, {
    ChallengeContinuationSubmission? browserContinuation,
  });
  Future<ChallengeRecord> cancelChallenge(String challengeId);
  Future<DiagnosticsBundle> diagnostics(String sessionId);
  Stream<EventRecord> events();
}

class ControlPlaneClient implements ControlPlaneApi {
  ControlPlaneClient({
    required this.baseUri,
    this.timeout = const Duration(seconds: 10),
    this.localeTagProvider,
    HttpClient Function()? httpClientFactory,
  }) : _httpClientFactory = httpClientFactory ?? HttpClient.new;

  factory ControlPlaneClient.localhost({
    String listenAddress = defaultListenAddress,
    String? Function()? localeTagProvider,
  }) {
    return ControlPlaneClient(
      baseUri: Uri.parse('http://$listenAddress'),
      localeTagProvider: localeTagProvider,
    );
  }

  static const String defaultListenAddress = '127.0.0.1:7777';
  static const String contractVersion = '1';

  final Uri baseUri;
  final Duration timeout;
  final String? Function()? localeTagProvider;
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
    String? resolutionId,
    RuntimeDefaults? runtimeDefaults,
    RuntimeExecutionPlan? executionPlan,
    TransportProfileReference? transportProfile,
    PlatformTunnelApplicationRoutingPolicy applicationRoutingPolicy =
        PlatformTunnelApplicationRoutingPolicy.allApps,
    PlatformTunnelUnderlayRoutePolicy underlayRoutePolicy =
        PlatformTunnelUnderlayRoutePolicy.standard,
    List<String> allowedPackages = const <String>[],
    List<String> disallowedPackages = const <String>[],
  }) async {
    final payload = await _jsonRequest(
      'POST',
      '/v1/platform-tunnels/start',
      body: <String, dynamic>{
        if (resolutionId != null && resolutionId.trim().isNotEmpty)
          'resolution_id': resolutionId.trim(),
        if (runtimeDefaults != null)
          'runtime_defaults': runtimeDefaults.toJson(),
        'mode': mode.value,
        if (executionPlan != null) 'execution_plan': executionPlan.toJson(),
        if (transportProfile != null && !transportProfile.isEmpty)
          'transport_profile': transportProfile.toJson(),
        if (_modeSupportsApplicationRouting(mode))
          'application_routing_policy': applicationRoutingPolicy.value,
        if (_modeSupportsUnderlayRoutePolicy(mode))
          'underlay_route_policy': underlayRoutePolicy.value,
        if (_modeSupportsApplicationRouting(mode) && allowedPackages.isNotEmpty)
          'allowed_packages': allowedPackages,
        if (_modeSupportsApplicationRouting(mode) &&
            disallowedPackages.isNotEmpty)
          'disallowed_packages': disallowedPackages,
      },
    );
    return PlatformTunnelStartResult.fromJson(payload);
  }

  @override
  Future<PlatformTunnelStartResult> resumePlatformTunnel({
    required String startupAttemptId,
  }) async {
    final payload = await _jsonRequest(
      'POST',
      '/v1/platform-tunnels/resume',
      body: <String, dynamic>{'startup_attempt_id': startupAttemptId},
    );
    return PlatformTunnelStartResult.fromJson(payload);
  }

  @override
  Future<PlatformTunnelStopResult> stopPlatformTunnel({
    required PlatformTunnelMode mode,
  }) async {
    final payload = await _jsonRequest(
      'POST',
      '/v1/platform-tunnels/stop',
      body: <String, dynamic>{'mode': mode.value},
    );
    return PlatformTunnelStopResult.fromJson(payload);
  }

  @override
  Future<List<ProviderDescriptor>> providers() async {
    final payload = await _jsonRequestList('GET', '/v1/providers');
    return payload.map(ProviderDescriptor.fromJson).toList(growable: false);
  }

  @override
  Future<List<ProviderConfigRecord>> providerConfigs() async {
    final payload = await _jsonRequestList('GET', '/v1/provider-configs');
    return payload.map(ProviderConfigRecord.fromJson).toList(growable: false);
  }

  @override
  Future<ProviderConfigRecord> upsertProviderConfig(
    ProviderConfigRecord config,
  ) async {
    final payload = await _jsonRequest(
      'POST',
      '/v1/provider-configs',
      body: config.toJson(),
    );
    return ProviderConfigRecord.fromJson(payload);
  }

  @override
  Future<ProviderConfigRecord> restoreProviderConfig(
    ProviderConfigRecord config,
  ) async {
    final payload = await _jsonRequest(
      'POST',
      '/v1/provider-configs:restore',
      body: config.toJson(),
    );
    return ProviderConfigRecord.fromJson(payload);
  }

  @override
  Future<void> deleteProviderConfig(String configId) async {
    await _request('DELETE', '/v1/provider-configs/$configId');
  }

  @override
  Future<List<TransportProfileStatus>> transportProfiles() async {
    final payload = await _jsonRequestList('GET', '/v1/transport-profiles');
    return payload.map(TransportProfileStatus.fromJson).toList(growable: false);
  }

  @override
  Future<TransportProfileStatus> importTransportProfile(
    TransportProfileImportRequest request,
  ) async {
    final payload = await _jsonRequest(
      'POST',
      '/v1/transport-profiles',
      body: request.toJson(),
    );
    return TransportProfileStatus.fromJson(payload);
  }

  @override
  Future<void> forgetTransportProfile(String profileId) async {
    await _request('DELETE', '/v1/transport-profiles/$profileId');
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
    RuntimeExecutionPlan? executionPlan,
  }) async {
    final payload = await _jsonRequest(
      'POST',
      '/v1/resolutions/$resolutionId/materialize',
      body: <String, dynamic>{
        'runtime_defaults': runtimeDefaults.toJson(),
        if (executionPlan != null) 'execution_plan': executionPlan.toJson(),
      },
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
  Future<ChallengeRecord> continueChallenge(
    String challengeId, {
    ChallengeContinuationSubmission? browserContinuation,
  }) async {
    final payload = await _jsonRequest(
      'POST',
      '/v1/challenges/$challengeId/continue',
      body: browserContinuation == null || browserContinuation.isEmpty
          ? null
          : <String, dynamic>{
              'browser_continuation': browserContinuation.toJson(),
            },
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
      _applyHeaders(request);
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

  bool _modeSupportsApplicationRouting(PlatformTunnelMode mode) {
    return mode == PlatformTunnelMode.androidVpnService;
  }

  bool _modeSupportsUnderlayRoutePolicy(PlatformTunnelMode mode) {
    return mode == PlatformTunnelMode.androidVpnService ||
        mode == PlatformTunnelMode.windowsWintun;
  }

  Future<_ResponsePayload> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final client = _httpClientFactory();
    try {
      final request = await _open(client, method, path);
      _applyHeaders(request);
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

  void _applyHeaders(HttpClientRequest request) {
    final localeTag = localeTagProvider?.call()?.trim() ?? '';
    if (localeTag.isEmpty) {
      return;
    }
    request.headers.set(HttpHeaders.acceptLanguageHeader, localeTag);
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
            requestedExecutionPlan:
                decoded['requested_execution_plan'] is Map<String, dynamic>
                ? RuntimeExecutionPlan.fromJson(
                    decoded['requested_execution_plan'] as Map<String, dynamic>,
                  )
                : null,
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
