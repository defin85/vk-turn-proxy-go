import 'dart:async';

import 'package:mobile_gui_shell/src/control/control_plane_client.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';

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

abstract class MobileHostBridge implements ControlPlaneApi {
  Future<MobileHostConnectionResult> ensureReady();
  Future<void> dispose();
}

class MobileHostBridgeFactory {
  static MobileHostBridge fromEnvironment() {
    final baseUrl = const String.fromEnvironment('VKTP_MOBILE_HOST_URL');
    if (baseUrl.trim().isNotEmpty) {
      return HttpMobileHostBridge(baseUri: Uri.parse(baseUrl.trim()));
    }
    return const UnavailableMobileHostBridge();
  }
}

class HttpMobileHostBridge implements MobileHostBridge {
  HttpMobileHostBridge({
    required this.baseUri,
    ControlPlaneClient? client,
    this.supportedVersions = const <String>[ControlPlaneClient.contractVersion],
    this.requiredCapabilities = const <Capability>[
      Capability.mobileHostBridge,
      Capability.profiles,
      Capability.sessions,
      Capability.challenges,
      Capability.diagnostics,
      Capability.eventStream,
    ],
  }) : _client = client ?? ControlPlaneClient(baseUri: baseUri);

  final Uri baseUri;
  final ControlPlaneClient _client;
  final List<String> supportedVersions;
  final List<Capability> requiredCapabilities;

  @override
  Future<ChallengeRecord> cancelChallenge(String challengeId) {
    return _client.cancelChallenge(challengeId);
  }

  @override
  Future<ChallengeRecord> challenge(String challengeId) {
    return _client.challenge(challengeId);
  }

  @override
  Future<ChallengeRecord> continueChallenge(String challengeId) {
    return _client.continueChallenge(challengeId);
  }

  @override
  Future<void> deleteProfile(String profileId) {
    return _client.deleteProfile(profileId);
  }

  @override
  Future<DiagnosticsBundle> diagnostics(String sessionId) {
    return _client.diagnostics(sessionId);
  }

  @override
  Future<void> dispose() async {}

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
        );
      }
    } catch (error) {
      return MobileHostConnectionResult(
        state: MobileHostLifecycleState.failed,
        message: '$error',
        description: baseUri.toString(),
      );
    }

    try {
      final negotiated = await _client.negotiate(
        supportedVersions: supportedVersions,
        requiredCapabilities: requiredCapabilities,
      );
      return MobileHostConnectionResult(
        state: MobileHostLifecycleState.ready,
        message: 'Connected to mobile host bridge ${baseUri.toString()}',
        info: negotiated,
        description: baseUri.toString(),
      );
    } on ControlPlaneError catch (error) {
      return MobileHostConnectionResult(
        state: error.incompatibleHost
            ? MobileHostLifecycleState.incompatible
            : MobileHostLifecycleState.unavailable,
        message: error.message,
        info: discoveredInfo,
        description: baseUri.toString(),
      );
    } catch (error) {
      return MobileHostConnectionResult(
        state: MobileHostLifecycleState.failed,
        message: '$error',
        info: discoveredInfo,
        description: baseUri.toString(),
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
}

class UnavailableMobileHostBridge implements MobileHostBridge {
  const UnavailableMobileHostBridge();

  static const String _message =
      'Mobile host bridge is not configured. Wire a native bridge or set VKTP_MOBILE_HOST_URL for development.';

  @override
  Future<ChallengeRecord> cancelChallenge(String challengeId) => _fail();

  @override
  Future<ChallengeRecord> challenge(String challengeId) => _fail();

  @override
  Future<ChallengeRecord> continueChallenge(String challengeId) => _fail();

  @override
  Future<void> deleteProfile(String profileId) => _fail();

  @override
  Future<DiagnosticsBundle> diagnostics(String sessionId) => _fail();

  @override
  Future<void> dispose() async {}

  @override
  Future<MobileHostConnectionResult> ensureReady() async {
    return const MobileHostConnectionResult(
      state: MobileHostLifecycleState.unavailable,
      message: _message,
      description: 'unconfigured mobile bridge',
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
  Future<List<ProfileRecord>> profiles() => _fail();

  @override
  Future<List<SessionRecord>> sessions() => _fail();

  @override
  Future<SessionRecord> startSession({String? profileId, ProfileSpec? spec}) =>
      _fail();

  @override
  Future<SessionRecord> stopSession(String sessionId) => _fail();

  @override
  Future<ProfileRecord> upsertProfile(ProfileRecord profile) => _fail();

  Future<T> _fail<T>() {
    throw const ControlPlaneError(
      statusCode: 0,
      code: 'bridge_unavailable',
      message: _message,
    );
  }
}
