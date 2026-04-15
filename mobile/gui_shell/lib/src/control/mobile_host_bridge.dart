import 'dart:async';

import 'package:flutter/services.dart';
import 'package:mobile_gui_shell/src/control/control_plane_client.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';

const String _bridgeChannelName =
    'com.defin85.vk_turn_proxy_go/mobile_host_bridge';
const String _browserReturnSignalChannelName =
    'com.defin85.vk_turn_proxy_go/mobile_host_bridge/browser_return_signals';

enum MobileHostLifecycleState { ready, unavailable, incompatible, failed }

class MobileHostConnectionResult {
  const MobileHostConnectionResult({
    required this.state,
    required this.message,
    this.info,
    this.description = '',
  });

  final MobileHostLifecycleState state;
  final String message;
  final HostInfo? info;
  final String description;

  bool get isReady => state == MobileHostLifecycleState.ready;
}

class ResolvedMobileHostConfig {
  const ResolvedMobileHostConfig({
    required this.baseUri,
    required this.description,
  });

  final Uri baseUri;
  final String description;
}

class MobileHostConfigResolutionError implements Exception {
  const MobileHostConfigResolutionError(this.message);

  final String message;

  @override
  String toString() => message;
}

class MobileHostPlatformActionError implements Exception {
  const MobileHostPlatformActionError(this.message);

  final String message;

  @override
  String toString() => message;
}

class MobileBrowserReturnSignal {
  const MobileBrowserReturnSignal({required this.kind, this.uri});

  static MobileBrowserReturnSignal? tryParse(dynamic payload) {
    if (payload is! Map<Object?, Object?>) {
      return null;
    }
    final rawKind = payload['kind'];
    final kind = BrowserReturnSignalKind.fromJson(rawKind as String?);
    if (kind == null) {
      return null;
    }
    final rawUri = payload['uri'];
    final uri = rawUri is String ? rawUri.trim() : '';
    return MobileBrowserReturnSignal(kind: kind, uri: uri.isEmpty ? null : uri);
  }

  final BrowserReturnSignalKind kind;
  final String? uri;
}

abstract class MobileBrowserReturnSignalSource {
  Stream<MobileBrowserReturnSignal> get signals;
  Future<void> dispose();
}

class PlatformMobileBrowserReturnSignalSource
    implements MobileBrowserReturnSignalSource {
  PlatformMobileBrowserReturnSignalSource({EventChannel? eventChannel})
    : _eventChannel =
          eventChannel ?? const EventChannel(_browserReturnSignalChannelName);

  final EventChannel _eventChannel;
  Stream<MobileBrowserReturnSignal>? _signals;

  @override
  Stream<MobileBrowserReturnSignal> get signals => _signals ??= _eventChannel
      .receiveBroadcastStream()
      .map((dynamic payload) => MobileBrowserReturnSignal.tryParse(payload))
      .where((MobileBrowserReturnSignal? signal) => signal != null)
      .cast<MobileBrowserReturnSignal>();

  @override
  Future<void> dispose() async {}
}

class _EmptyMobileBrowserReturnSignalSource
    implements MobileBrowserReturnSignalSource {
  const _EmptyMobileBrowserReturnSignalSource();

  @override
  Stream<MobileBrowserReturnSignal> get signals =>
      const Stream<MobileBrowserReturnSignal>.empty();

  @override
  Future<void> dispose() async {}
}

abstract class MobileHostConfigResolver {
  Future<ResolvedMobileHostConfig?> resolve();
}

abstract class MobilePlatformTunnelPermissionRequester {
  Future<bool> requestPermission({required PlatformTunnelMode mode});
}

class PlatformMobileHostConfigResolver implements MobileHostConfigResolver {
  PlatformMobileHostConfigResolver({MethodChannel? methodChannel})
    : _methodChannel = methodChannel ?? const MethodChannel(_bridgeChannelName);

  final MethodChannel _methodChannel;

  @override
  Future<ResolvedMobileHostConfig?> resolve() async {
    try {
      final payload = await _methodChannel.invokeMapMethod<String, dynamic>(
        'resolveHost',
      );
      if (payload == null) {
        throw const MobileHostConfigResolutionError(
          'Native mobile host bridge did not return a host configuration.',
        );
      }
      final baseUrl = (payload['base_url'] as String? ?? '').trim();
      if (baseUrl.isEmpty) {
        throw const MobileHostConfigResolutionError(
          'Native mobile host bridge returned an empty host URL.',
        );
      }
      final uri = Uri.tryParse(baseUrl);
      final validUri =
          uri != null &&
          uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
      if (!validUri) {
        throw MobileHostConfigResolutionError(
          'Native mobile host bridge returned an invalid host URL: $baseUrl',
        );
      }
      final description = (payload['description'] as String? ?? baseUrl).trim();
      return ResolvedMobileHostConfig(
        baseUri: uri,
        description: description.isEmpty ? baseUrl : description,
      );
    } on MissingPluginException {
      throw const MobileHostConfigResolutionError(
        'Native mobile host bridge plugin is unavailable.',
      );
    } on PlatformException catch (error) {
      throw MobileHostConfigResolutionError(
        'Failed to resolve the mobile host bridge from the native platform: ${error.message ?? error.code}',
      );
    } catch (error) {
      throw MobileHostConfigResolutionError(
        'Failed to resolve the mobile host bridge from the native platform: $error',
      );
    }
  }
}

class PlatformMobilePlatformTunnelPermissionRequester
    implements MobilePlatformTunnelPermissionRequester {
  PlatformMobilePlatformTunnelPermissionRequester({
    MethodChannel? methodChannel,
  }) : _methodChannel =
           methodChannel ?? const MethodChannel(_bridgeChannelName);

  final MethodChannel _methodChannel;

  @override
  Future<bool> requestPermission({required PlatformTunnelMode mode}) async {
    try {
      final granted = await _methodChannel.invokeMethod<bool>(
        'requestPlatformTunnelPermission',
        <String, dynamic>{'mode': mode.value},
      );
      return granted ?? false;
    } on MissingPluginException {
      throw const MobileHostPlatformActionError(
        'Native mobile host bridge plugin is unavailable for platform tunnel permission requests.',
      );
    } on PlatformException catch (error) {
      throw MobileHostPlatformActionError(
        'Failed to request native platform tunnel permission: ${error.message ?? error.code}',
      );
    } catch (error) {
      throw MobileHostPlatformActionError(
        'Failed to request native platform tunnel permission: $error',
      );
    }
  }
}

abstract class MobileHostBridge implements ControlPlaneApi {
  Stream<MobileBrowserReturnSignal> get browserReturnSignals;
  Future<MobileHostConnectionResult> ensureReady();
  Future<bool> requestPlatformTunnelPermission({
    required PlatformTunnelMode mode,
  });
  Future<void> dispose();
}

class MobileHostBridgeFactory {
  static Future<MobileHostBridge> fromEnvironment({
    String? configuredBaseUrl,
    MobileHostConfigResolver? resolver,
    MobileBrowserReturnSignalSource? browserReturnSignalSource,
    ControlPlaneApi Function(Uri baseUri)? clientFactory,
  }) async {
    final override =
        (configuredBaseUrl ??
                const String.fromEnvironment('VKTP_MOBILE_HOST_URL'))
            .trim();
    if (override.isNotEmpty) {
      final uri = Uri.tryParse(override);
      if (uri == null) {
        return const UnavailableMobileHostBridge(
          message:
              'VKTP_MOBILE_HOST_URL is not a valid URI for the mobile host bridge.',
          description: 'invalid VKTP_MOBILE_HOST_URL',
        );
      }
      return HttpMobileHostBridge(
        baseUri: uri,
        client: clientFactory?.call(uri),
        description: 'VKTP_MOBILE_HOST_URL',
        browserReturnSignalSource:
            browserReturnSignalSource ??
            PlatformMobileBrowserReturnSignalSource(),
      );
    }

    ResolvedMobileHostConfig? resolved;
    try {
      resolved = await (resolver ?? PlatformMobileHostConfigResolver())
          .resolve();
    } on MobileHostConfigResolutionError catch (error) {
      return UnavailableMobileHostBridge(
        message: error.message,
        description: 'native mobile host bridge',
      );
    } catch (error) {
      return UnavailableMobileHostBridge(
        message:
            'Failed to resolve the mobile host bridge from the native platform: $error',
        description: 'native mobile host bridge',
      );
    }
    if (resolved == null) {
      return const UnavailableMobileHostBridge(
        message:
            'Native mobile host bridge did not provide a control-plane endpoint.',
        description: 'native mobile host bridge',
      );
    }
    return HttpMobileHostBridge(
      baseUri: resolved.baseUri,
      client: clientFactory?.call(resolved.baseUri),
      description: resolved.description,
      browserReturnSignalSource:
          browserReturnSignalSource ??
          PlatformMobileBrowserReturnSignalSource(),
    );
  }
}

class HttpMobileHostBridge implements MobileHostBridge {
  HttpMobileHostBridge({
    required this.baseUri,
    ControlPlaneApi? client,
    MobileBrowserReturnSignalSource? browserReturnSignalSource,
    MobilePlatformTunnelPermissionRequester? platformTunnelPermissionRequester,
    this.description = '',
    this.supportedVersions = const <String>[ControlPlaneClient.contractVersion],
    this.requiredCapabilities = const <Capability>[
      Capability.mobileHostBridge,
      Capability.platformTunnels,
      Capability.profiles,
      Capability.providerRuntimeArtifacts,
      Capability.runtimeExecutionPlanning,
      Capability.sessions,
      Capability.challenges,
      Capability.diagnostics,
      Capability.eventStream,
    ],
  }) : _client = client ?? ControlPlaneClient(baseUri: baseUri),
       _browserReturnSignalSource =
           browserReturnSignalSource ??
           const _EmptyMobileBrowserReturnSignalSource(),
       _platformTunnelPermissionRequester =
           platformTunnelPermissionRequester ??
           PlatformMobilePlatformTunnelPermissionRequester();

  final Uri baseUri;
  final ControlPlaneApi _client;
  final MobileBrowserReturnSignalSource _browserReturnSignalSource;
  final MobilePlatformTunnelPermissionRequester
  _platformTunnelPermissionRequester;
  final String description;
  final List<String> supportedVersions;
  final List<Capability> requiredCapabilities;

  String get _descriptionLabel =>
      description.isEmpty ? baseUri.toString() : description;

  @override
  Stream<MobileBrowserReturnSignal> get browserReturnSignals =>
      _browserReturnSignalSource.signals;

  @override
  Future<ChallengeRecord> cancelChallenge(String challengeId) {
    return _client.cancelChallenge(challengeId);
  }

  @override
  Future<ChallengeRecord> challenge(String challengeId) {
    return _client.challenge(challengeId);
  }

  @override
  Future<ChallengeRecord> continueChallenge(
    String challengeId, {
    ChallengeContinuationSubmission? browserContinuation,
  }) {
    return _client.continueChallenge(
      challengeId,
      browserContinuation: browserContinuation,
    );
  }

  @override
  Future<void> deleteProfile(String profileId) {
    return _client.deleteProfile(profileId);
  }

  @override
  Future<void> deleteProviderConfig(String configId) {
    return _client.deleteProviderConfig(configId);
  }

  @override
  Future<List<ProviderDescriptor>> providers() {
    return _client.providers();
  }

  @override
  Future<List<ProviderConfigRecord>> providerConfigs() {
    return _client.providerConfigs();
  }

  @override
  Future<ProviderConfigRecord> restoreProviderConfig(
    ProviderConfigRecord config,
  ) {
    return _client.restoreProviderConfig(config);
  }

  @override
  Future<List<ResolutionRecord>> resolutions() {
    return _client.resolutions();
  }

  @override
  Future<ResolutionRecord> startResolution({
    required String provider,
    required ProviderInputEnvelope input,
    Map<String, dynamic> providerSettings = const <String, dynamic>{},
  }) {
    return _client.startResolution(
      provider: provider,
      input: input,
      providerSettings: providerSettings,
    );
  }

  @override
  Future<ResolutionRecord> cancelResolution(String resolutionId) {
    return _client.cancelResolution(resolutionId);
  }

  @override
  Future<ResolutionExportResult> exportResolution(String resolutionId) {
    return _client.exportResolution(resolutionId);
  }

  @override
  Future<SessionRecord> materializeResolution({
    required String resolutionId,
    required RuntimeDefaults runtimeDefaults,
    RuntimeExecutionPlan? executionPlan,
  }) {
    return _client.materializeResolution(
      resolutionId: resolutionId,
      runtimeDefaults: runtimeDefaults,
      executionPlan: executionPlan,
    );
  }

  @override
  Future<DiagnosticsBundle> diagnostics(String sessionId) {
    return _client.diagnostics(sessionId);
  }

  @override
  Future<void> dispose() async {
    await _browserReturnSignalSource.dispose();
  }

  @override
  Future<MobileHostConnectionResult> ensureReady() async {
    HostInfo? discoveredInfo;
    try {
      discoveredInfo = await _client.hostInfo();
    } on ControlPlaneError catch (error) {
      if (error.incompatibleHost) {
        return MobileHostConnectionResult(
          state: MobileHostLifecycleState.incompatible,
          message: error.message,
          description: _descriptionLabel,
        );
      }
    } catch (error) {
      return MobileHostConnectionResult(
        state: MobileHostLifecycleState.failed,
        message: '$error',
        description: _descriptionLabel,
      );
    }

    try {
      final negotiated = await _client.negotiate(
        supportedVersions: supportedVersions,
        requiredCapabilities: requiredCapabilities,
      );
      return MobileHostConnectionResult(
        state: MobileHostLifecycleState.ready,
        message: 'Connected to mobile host bridge $baseUri',
        info: negotiated,
        description: _descriptionLabel,
      );
    } on ControlPlaneError catch (error) {
      return MobileHostConnectionResult(
        state: error.incompatibleHost
            ? MobileHostLifecycleState.incompatible
            : MobileHostLifecycleState.unavailable,
        message: error.message,
        info: discoveredInfo,
        description: _descriptionLabel,
      );
    } catch (error) {
      return MobileHostConnectionResult(
        state: MobileHostLifecycleState.failed,
        message: '$error',
        info: discoveredInfo,
        description: _descriptionLabel,
      );
    }
  }

  @override
  Stream<EventRecord> events() => _client.events();

  @override
  Future<HostInfo> hostInfo() => _client.hostInfo();

  @override
  Future<HostInfo> negotiate({
    required List<String> supportedVersions,
    required List<Capability> requiredCapabilities,
  }) {
    return _client.negotiate(
      supportedVersions: supportedVersions,
      requiredCapabilities: requiredCapabilities,
    );
  }

  @override
  Future<PlatformTunnelStartResult> startPlatformTunnel({
    required PlatformTunnelMode mode,
    String? resolutionId,
    RuntimeDefaults? runtimeDefaults,
    RuntimeExecutionPlan? executionPlan,
    PlatformTunnelApplicationRoutingPolicy applicationRoutingPolicy =
        PlatformTunnelApplicationRoutingPolicy.allApps,
    List<String> allowedPackages = const <String>[],
    List<String> disallowedPackages = const <String>[],
  }) {
    return _client.startPlatformTunnel(
      mode: mode,
      resolutionId: resolutionId,
      runtimeDefaults: runtimeDefaults,
      executionPlan: executionPlan,
      applicationRoutingPolicy: applicationRoutingPolicy,
      allowedPackages: allowedPackages,
      disallowedPackages: disallowedPackages,
    );
  }

  @override
  Future<PlatformTunnelStartResult> resumePlatformTunnel({
    required String startupAttemptId,
  }) {
    return _client.resumePlatformTunnel(startupAttemptId: startupAttemptId);
  }

  @override
  Future<PlatformTunnelStopResult> stopPlatformTunnel({
    required PlatformTunnelMode mode,
  }) {
    return _client.stopPlatformTunnel(mode: mode);
  }

  @override
  Future<bool> requestPlatformTunnelPermission({
    required PlatformTunnelMode mode,
  }) {
    return _platformTunnelPermissionRequester.requestPermission(mode: mode);
  }

  @override
  Future<List<ProfileRecord>> profiles() => _client.profiles();

  @override
  Future<List<SessionRecord>> sessions() => _client.sessions();

  @override
  Future<SessionRecord> startSession({String? profileId, ProfileSpec? spec}) {
    return _client.startSession(profileId: profileId, spec: spec);
  }

  @override
  Future<SessionRecord> stopSession(String sessionId) {
    return _client.stopSession(sessionId);
  }

  @override
  Future<ProfileRecord> upsertProfile(ProfileRecord profile) {
    return _client.upsertProfile(profile);
  }

  @override
  Future<ProviderConfigRecord> upsertProviderConfig(
    ProviderConfigRecord config,
  ) {
    return _client.upsertProviderConfig(config);
  }
}

class UnavailableMobileHostBridge implements MobileHostBridge {
  const UnavailableMobileHostBridge({
    this.message = _defaultMessage,
    this.description = 'unconfigured mobile bridge',
  });

  static const String _defaultMessage =
      'Mobile host bridge is not configured. Package a compatible loopback host or set VKTP_MOBILE_HOST_URL for development.';

  final String message;
  final String description;

  @override
  Stream<MobileBrowserReturnSignal> get browserReturnSignals =>
      const Stream<MobileBrowserReturnSignal>.empty();

  @override
  Future<ChallengeRecord> cancelChallenge(String challengeId) => _fail();

  @override
  Future<ChallengeRecord> challenge(String challengeId) => _fail();

  @override
  Future<ChallengeRecord> continueChallenge(
    String challengeId, {
    ChallengeContinuationSubmission? browserContinuation,
  }) => _fail();

  @override
  Future<void> deleteProfile(String profileId) => _fail();

  @override
  Future<void> deleteProviderConfig(String configId) => _fail();

  @override
  Future<ResolutionRecord> cancelResolution(String resolutionId) => _fail();

  @override
  Future<PlatformTunnelStopResult> stopPlatformTunnel({
    required PlatformTunnelMode mode,
  }) => _fail();

  @override
  Future<DiagnosticsBundle> diagnostics(String sessionId) => _fail();

  @override
  Future<void> dispose() async {}

  @override
  Future<MobileHostConnectionResult> ensureReady() async {
    return MobileHostConnectionResult(
      state: MobileHostLifecycleState.unavailable,
      message: message,
      description: description,
    );
  }

  @override
  Stream<EventRecord> events() => const Stream<EventRecord>.empty();

  @override
  Future<HostInfo> hostInfo() => _fail();

  @override
  Future<HostInfo> negotiate({
    required List<String> supportedVersions,
    required List<Capability> requiredCapabilities,
  }) => _fail();

  @override
  Future<ResolutionExportResult> exportResolution(String resolutionId) =>
      _fail();

  @override
  Future<PlatformTunnelStartResult> startPlatformTunnel({
    required PlatformTunnelMode mode,
    String? resolutionId,
    RuntimeDefaults? runtimeDefaults,
    RuntimeExecutionPlan? executionPlan,
    PlatformTunnelApplicationRoutingPolicy applicationRoutingPolicy =
        PlatformTunnelApplicationRoutingPolicy.allApps,
    List<String> allowedPackages = const <String>[],
    List<String> disallowedPackages = const <String>[],
  }) => _fail();

  @override
  Future<PlatformTunnelStartResult> resumePlatformTunnel({
    required String startupAttemptId,
  }) => _fail();

  @override
  Future<bool> requestPlatformTunnelPermission({
    required PlatformTunnelMode mode,
  }) => _fail();

  @override
  Future<List<ProfileRecord>> profiles() => _fail();

  @override
  Future<List<ProviderConfigRecord>> providerConfigs() => _fail();

  @override
  Future<List<ProviderDescriptor>> providers() => _fail();

  @override
  Future<ProviderConfigRecord> restoreProviderConfig(
    ProviderConfigRecord config,
  ) => _fail();

  @override
  Future<List<ResolutionRecord>> resolutions() => _fail();

  @override
  Future<List<SessionRecord>> sessions() => _fail();

  @override
  Future<ResolutionRecord> startResolution({
    required String provider,
    required ProviderInputEnvelope input,
    Map<String, dynamic> providerSettings = const <String, dynamic>{},
  }) => _fail();

  @override
  Future<SessionRecord> startSession({String? profileId, ProfileSpec? spec}) =>
      _fail();

  @override
  Future<SessionRecord> materializeResolution({
    required String resolutionId,
    required RuntimeDefaults runtimeDefaults,
    RuntimeExecutionPlan? executionPlan,
  }) => _fail();

  @override
  Future<SessionRecord> stopSession(String sessionId) => _fail();

  @override
  Future<ProfileRecord> upsertProfile(ProfileRecord profile) => _fail();

  @override
  Future<ProviderConfigRecord> upsertProviderConfig(
    ProviderConfigRecord config,
  ) => _fail();

  Future<T> _fail<T>() {
    throw ControlPlaneError(
      statusCode: 0,
      code: 'bridge_unavailable',
      message: message,
    );
  }
}
