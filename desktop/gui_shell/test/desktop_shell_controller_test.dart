import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gui_shell/src/control/control_plane_client.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/desktop_handoff_adapter.dart';
import 'package:gui_shell/src/control/desktop_host_supervisor.dart';
import 'package:gui_shell/src/control/desktop_shell_controller.dart';
import 'package:gui_shell/src/control/profile_draft.dart';
import 'package:gui_shell/src/control/shell_state_store.dart';

const BuildIdentity _testGuiBuild = BuildIdentity(
  product: 'vk-turn-proxy-go',
  version: '0.1.0',
  buildNumber: '1',
  revision: 'gui123456789',
  role: 'gui_shell',
  target: 'windows/x64',
);

const BuildIdentity _testHostBuild = BuildIdentity(
  product: 'vk-turn-proxy-go',
  version: '0.1.0',
  buildNumber: '1',
  revision: 'deadbeefcafe',
  role: 'clientd',
  target: 'windows/amd64',
);

const HostInfo _readyHostInfo = HostInfo(
  contractVersion: '1',
  build: _testHostBuild,
  capabilities: <Capability>[
    Capability.desktopSidecar,
    Capability.platformTunnels,
    Capability.profiles,
    Capability.providerResolutionHandoff,
    Capability.sessions,
    Capability.challenges,
    Capability.diagnostics,
    Capability.eventStream,
  ],
  platformTunnels: <PlatformTunnelCapability>[
    PlatformTunnelCapability(
      mode: PlatformTunnelMode.windowsWintun,
      available: false,
      missingPrerequisite: PlatformTunnelPrerequisite.hostImplementation,
      message: 'desktop sidecar does not implement system tunnel startup yet',
    ),
  ],
);

void main() {
  test('controller restores active challenge details during refresh', () async {
    final api = _FakeControlPlaneApi(
      profiles: <ProfileRecord>[
        ProfileRecord(id: 'profile-1', name: 'alpha', spec: _profileSpec()),
      ],
      sessions: <SessionRecord>[
        SessionRecord(
          id: 'session-1',
          profileId: 'profile-1',
          profileName: 'alpha',
          profile: _profileSpec(),
          state: SessionState.challengeRequired,
          activeChallengeId: 'challenge-1',
          startedAt: DateTime.utc(2026, 4, 5, 17, 0),
          updatedAt: DateTime.utc(2026, 4, 5, 17, 1),
        ),
      ],
      challenges: <String, ChallengeRecord>{
        'challenge-1': ChallengeRecord(
          id: 'challenge-1',
          sessionId: 'session-1',
          provider: 'vk',
          stage: 'provider_resolve',
          kind: 'browser',
          prompt: 'continue in browser',
          openUrl: 'https://vk.com/call/join/test',
          status: ChallengeStatus.pending,
          createdAt: DateTime.utc(2026, 4, 5, 17, 0),
          updatedAt: DateTime.utc(2026, 4, 5, 17, 1),
        ),
      },
    );
    final controller = DesktopShellController(
      api: api,
      supervisor: _SequencedHostSupervisor(const <HostConnectionResult>[
        HostConnectionResult(
          state: HostLifecycleState.ready,
          message: 'ready',
          info: _readyHostInfo,
        ),
      ]),
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(api.challengeRequests, <String>['challenge-1']);
    expect(controller.sessions, hasLength(1));
    final challenge = controller.activeChallengeFor(controller.sessions.single);
    expect(challenge?.id, 'challenge-1');
    expect(challenge?.prompt, 'continue in browser');
  });

  test(
    'controller clears active challenge after challenge-updated completion event',
    () async {
      final api = _FakeControlPlaneApi(
        profiles: <ProfileRecord>[
          ProfileRecord(id: 'profile-1', name: 'alpha', spec: _profileSpec()),
        ],
        sessions: <SessionRecord>[
          SessionRecord(
            id: 'session-1',
            profileId: 'profile-1',
            profileName: 'alpha',
            profile: _profileSpec(),
            state: SessionState.challengeRequired,
            activeChallengeId: 'challenge-1',
            startedAt: DateTime.utc(2026, 4, 5, 17, 0),
            updatedAt: DateTime.utc(2026, 4, 5, 17, 1),
          ),
        ],
        challenges: <String, ChallengeRecord>{
          'challenge-1': ChallengeRecord(
            id: 'challenge-1',
            sessionId: 'session-1',
            provider: 'vk',
            stage: 'provider_resolve',
            kind: 'browser',
            prompt: 'continue in browser',
            openUrl: 'https://vk.com/call/join/test',
            status: ChallengeStatus.pending,
            createdAt: DateTime.utc(2026, 4, 5, 17, 0),
            updatedAt: DateTime.utc(2026, 4, 5, 17, 1),
          ),
        },
      );
      final controller = DesktopShellController(
        api: api,
        supervisor: _SequencedHostSupervisor(const <HostConnectionResult>[
          HostConnectionResult(
            state: HostLifecycleState.ready,
            message: 'ready',
            info: _readyHostInfo,
          ),
        ]),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      api.emitEvent(
        EventRecord(
          id: 'event-2',
          timestamp: DateTime.utc(2026, 4, 5, 17, 2),
          sessionId: 'session-1',
          type: EventType.challengeUpdated,
          challenge: ChallengeRecord(
            id: 'challenge-1',
            sessionId: 'session-1',
            provider: 'vk',
            stage: 'provider_resolve',
            kind: 'browser',
            prompt: 'continue in browser',
            openUrl: 'https://vk.com/call/join/test',
            status: ChallengeStatus.completed,
            createdAt: DateTime.utc(2026, 4, 5, 17, 0),
            updatedAt: DateTime.utc(2026, 4, 5, 17, 2),
          ),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.sessions.single.activeChallengeId, isEmpty);
      expect(controller.activeChallengeFor(controller.sessions.single), isNull);
    },
  );

  test(
    'controller blocks and asks the supervisor to recover when host access is lost',
    () async {
      final api = _FakeControlPlaneApi(
        profiles: <ProfileRecord>[
          ProfileRecord(id: 'profile-1', name: 'alpha', spec: _profileSpec()),
        ],
        sessions: const <SessionRecord>[],
      );
      final supervisor = _SequencedHostSupervisor(const <HostConnectionResult>[
        HostConnectionResult(
          state: HostLifecycleState.ready,
          message: 'ready',
          info: _readyHostInfo,
        ),
        HostConnectionResult(
          state: HostLifecycleState.unavailable,
          message: 'local host disappeared',
        ),
      ]);
      final controller = DesktopShellController(
        api: api,
        supervisor: supervisor,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      api.failReads = true;

      await controller.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(supervisor.calls, 2);
      expect(controller.status, ShellStatus.blocked);
      expect(controller.hostConnection?.state, HostLifecycleState.unavailable);
      expect(controller.notice, contains('local host disappeared'));
    },
  );

  test(
    'controller does not attempt session mutations while host is blocked',
    () async {
      final api = _FakeControlPlaneApi(
        profiles: <ProfileRecord>[
          ProfileRecord(id: 'profile-1', name: 'alpha', spec: _profileSpec()),
        ],
        sessions: const <SessionRecord>[],
      );
      final controller = DesktopShellController(
        api: api,
        supervisor: _SequencedHostSupervisor(const <HostConnectionResult>[
          HostConnectionResult(
            state: HostLifecycleState.unavailable,
            message: 'local host unavailable',
          ),
        ]),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      controller.selectProfile('profile-1');
      await controller.startSelectedProfile();

      expect(api.startSessionCalls, 0);
      expect(controller.notice, contains('local host unavailable'));
    },
  );

  test(
    'controller restores persisted profiles, draft, and runtime defaults into the host',
    () async {
      final persistedProfile = ProfileRecord(
        id: 'profile-1',
        name: 'saved',
        spec: _profileSpec(),
      );
      final api = _FakeControlPlaneApi(
        profiles: const <ProfileRecord>[],
        resolutions: <ResolutionRecord>[_resolutionRecord()],
        sessions: const <SessionRecord>[],
      );
      final store = _FakeShellStateStore(
        loaded: DesktopShellState(
          profiles: <ProfileRecord>[persistedProfile],
          selectedProfileId: 'profile-1',
          draft: ProfileDraft(
            id: 'profile-1',
            name: 'saved draft',
            spec: _profileSpec().copyWith(link: 'generic-turn://saved'),
          ),
          runtimeDefaults: const RuntimeDefaults(
            listenAddress: '127.0.0.1:9101',
            peerAddress: '127.0.0.1:56100',
            turnServer: 'override.example.test',
            turnPort: '5349',
            bindInterface: '127.0.0.1',
            mode: TransportMode.udp,
            useDtls: false,
            logLevel: 'debug',
          ),
        ),
      );
      final controller = DesktopShellController(
        api: api,
        supervisor: _SequencedHostSupervisor(const <HostConnectionResult>[
          HostConnectionResult(
            state: HostLifecycleState.ready,
            message: 'ready',
            info: _readyHostInfo,
          ),
        ]),
        stateStore: store,
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(api.upsertedProfiles, hasLength(1));
      expect(api.upsertedProfiles.single.id, 'profile-1');
      expect(controller.profiles, hasLength(1));
      expect(controller.selectedProfileId, 'profile-1');
      expect(controller.draft.name, 'saved draft');
      expect(controller.draft.spec.link, 'generic-turn://saved');

      await controller.materializeResolution('resolution-1');

      expect(api.materializeResolutionDefaults, hasLength(1));
      expect(
        api.materializeResolutionDefaults.single.listenAddress,
        '127.0.0.1:9101',
      );
      expect(
        api.materializeResolutionDefaults.single.peerAddress,
        '127.0.0.1:56100',
      );
      expect(
        api.materializeResolutionDefaults.single.turnServer,
        'override.example.test',
      );
      expect(api.materializeResolutionDefaults.single.turnPort, '5349');
      expect(
        api.materializeResolutionDefaults.single.bindInterface,
        '127.0.0.1',
      );
      expect(api.materializeResolutionDefaults.single.mode, TransportMode.udp);
      expect(api.materializeResolutionDefaults.single.useDtls, isFalse);
      expect(api.materializeResolutionDefaults.single.logLevel, 'debug');
    },
  );

  test(
    'controller persists profiles, selection, and draft mutations',
    () async {
      final api = _FakeControlPlaneApi(
        profiles: <ProfileRecord>[
          ProfileRecord(id: 'profile-1', name: 'alpha', spec: _profileSpec()),
        ],
        sessions: const <SessionRecord>[],
      );
      final store = _FakeShellStateStore();
      final controller = DesktopShellController(
        api: api,
        supervisor: _SequencedHostSupervisor(const <HostConnectionResult>[
          HostConnectionResult(
            state: HostLifecycleState.ready,
            message: 'ready',
            info: _readyHostInfo,
          ),
        ]),
        stateStore: store,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      controller.selectProfile('profile-1');
      controller.updateDraft(
        controller.draft.copyWith(
          name: 'edited alpha',
          spec: controller.draft.spec.copyWith(
            link: 'generic-turn://edited',
            listenAddress: '127.0.0.1:9201',
            peerAddress: '127.0.0.1:56100',
            turnServer: 'override.example.test',
            turnPort: '5349',
            bindInterface: '127.0.0.1',
            mode: TransportMode.tcp,
            useDtls: false,
            logLevel: 'debug',
          ),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(store.savedStates, isNotEmpty);
      final saved = store.savedStates.last;
      expect(saved.profiles, hasLength(1));
      expect(saved.selectedProfileId, 'profile-1');
      expect(saved.draft.name, 'edited alpha');
      expect(saved.draft.spec.link, 'generic-turn://edited');
      expect(saved.runtimeDefaults.listenAddress, '127.0.0.1:9201');
      expect(saved.runtimeDefaults.peerAddress, '127.0.0.1:56100');
      expect(saved.runtimeDefaults.turnServer, 'override.example.test');
      expect(saved.runtimeDefaults.turnPort, '5349');
      expect(saved.runtimeDefaults.bindInterface, '127.0.0.1');
      expect(saved.runtimeDefaults.mode, TransportMode.tcp);
      expect(saved.runtimeDefaults.useDtls, isFalse);
      expect(saved.runtimeDefaults.logLevel, 'debug');
    },
  );

  test(
    'controller starts, copies, and materializes typed resolutions',
    () async {
      final api = _FakeControlPlaneApi(
        profiles: const <ProfileRecord>[],
        resolutions: const <ResolutionRecord>[],
        sessions: const <SessionRecord>[],
      );
      final handoff = _FakeDesktopHandoffAdapter();
      final controller = DesktopShellController(
        api: api,
        supervisor: _SequencedHostSupervisor(const <HostConnectionResult>[
          HostConnectionResult(
            state: HostLifecycleState.ready,
            message: 'ready',
            info: _readyHostInfo,
          ),
        ]),
        handoffAdapter: handoff,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      controller.updateDraft(
        controller.draft.copyWith(
          spec: controller.draft.spec.copyWith(
            provider: 'vk',
            link: 'https://vk.com/call/join/fresh',
            interactiveProvider: true,
            turnServer: 'override.example.test',
            turnPort: '5349',
          ),
        ),
      );

      await controller.startResolutionFromDraft();
      expect(api.startResolutionCalls, hasLength(1));
      expect(controller.resolutions, hasLength(1));

      final resolutionID = controller.resolutions.single.id;
      await controller.copyResolutionExport(resolutionID);
      await controller.materializeResolution(resolutionID);

      expect(handoff.copiedLinks, <String>[
        'generic-turn://turn-user:turn-pass@turn.example.test:3478',
      ]);
      expect(api.materializeResolutionCalls, <String>[resolutionID]);
      expect(api.materializeResolutionDefaults, hasLength(1));
      expect(
        api.materializeResolutionDefaults.single.turnServer,
        'override.example.test',
      );
      expect(api.materializeResolutionDefaults.single.turnPort, '5349');
      expect(controller.selectedResolutionId, resolutionID);
      expect(controller.selectedSessionId, 'materialized-session');
      expect(
        controller.notice,
        contains('Started session materialized-session from resolution'),
      );
    },
  );

  test(
    'controller restores resolution challenge details during refresh',
    () async {
      final api = _FakeControlPlaneApi(
        profiles: const <ProfileRecord>[],
        resolutions: <ResolutionRecord>[
          _resolutionRecord(activeChallengeId: 'challenge-resolution-1'),
        ],
        sessions: const <SessionRecord>[],
        challenges: <String, ChallengeRecord>{
          'challenge-resolution-1': ChallengeRecord(
            id: 'challenge-resolution-1',
            sessionId: '',
            resolutionId: 'resolution-1',
            provider: 'vk',
            stage: 'provider_resolve',
            kind: 'browser',
            prompt: 'continue in browser',
            openUrl: 'https://vk.com/call/join/test',
            status: ChallengeStatus.pending,
            createdAt: DateTime.utc(2026, 4, 5, 17, 0),
            updatedAt: DateTime.utc(2026, 4, 5, 17, 1),
          ),
        },
      );
      final controller = DesktopShellController(
        api: api,
        supervisor: _SequencedHostSupervisor(const <HostConnectionResult>[
          HostConnectionResult(
            state: HostLifecycleState.ready,
            message: 'ready',
            info: _readyHostInfo,
          ),
        ]),
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(api.challengeRequests, <String>['challenge-resolution-1']);
      final challenge = controller.activeChallengeForResolution(
        controller.resolutions.single,
      );
      expect(challenge?.id, 'challenge-resolution-1');
      expect(challenge?.openUrl, 'https://vk.com/call/join/test');
    },
  );

  test(
    'controller export diagnostics includes gui and host build identity',
    () async {
      final api = _FakeControlPlaneApi(
        profiles: const <ProfileRecord>[],
        sessions: <SessionRecord>[
          SessionRecord(
            id: 'session-1',
            profile: _profileSpec(),
            state: SessionState.ready,
            startedAt: DateTime.utc(2026, 4, 5, 17, 0),
            updatedAt: DateTime.utc(2026, 4, 5, 17, 1),
          ),
        ],
      );
      final directory = await Directory.systemTemp.createTemp(
        'gui-shell-diagnostics-',
      );
      addTearDown(() => directory.delete(recursive: true));

      final controller = DesktopShellController(
        api: api,
        supervisor: _SequencedHostSupervisor(const <HostConnectionResult>[
          HostConnectionResult(
            state: HostLifecycleState.ready,
            message: 'ready',
            info: _readyHostInfo,
          ),
        ]),
        diagnosticsDirectoryProvider: () async => directory,
        clock: () => DateTime.utc(2026, 4, 7, 10, 11, 12),
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.exportDiagnostics('session-1');

      final exportedFiles = directory.listSync().whereType<File>().toList(
        growable: false,
      );
      expect(exportedFiles, hasLength(1));

      final payload =
          jsonDecode(await exportedFiles.single.readAsString())
              as Map<String, dynamic>;
      expect(payload['contract_version'], '1');
      expect(
        (payload['host_build'] as Map<String, dynamic>)['version'],
        '0.1.0',
      );
      expect(
        (payload['gui_build'] as Map<String, dynamic>)['revision'],
        'gui123456789',
      );
    },
  );

  test(
    'controller consumes typed platform tunnel reports and startup-stage results',
    () async {
      final api = _FakeControlPlaneApi(
        profiles: const <ProfileRecord>[],
        sessions: const <SessionRecord>[],
      );
      final controller = DesktopShellController(
        api: api,
        supervisor: _SequencedHostSupervisor(const <HostConnectionResult>[
          HostConnectionResult(
            state: HostLifecycleState.ready,
            message: 'ready',
            info: _readyHostInfo,
          ),
        ]),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.startPlatformTunnel(PlatformTunnelMode.windowsWintun);

      expect(api.startPlatformTunnelCalls, <PlatformTunnelMode>[
        PlatformTunnelMode.windowsWintun,
      ]);
      expect(
        controller.platformTunnels.single.mode,
        PlatformTunnelMode.windowsWintun,
      );
      expect(
        controller
            .platformTunnelResultFor(PlatformTunnelMode.windowsWintun)
            ?.stage,
        PlatformTunnelStartupStage.capabilityCheck,
      );
      expect(controller.notice, contains('Capability check'));
    },
  );

  test(
    'controller clears platform tunnel startup results after reconnecting to the same mode',
    () async {
      final api = _FakeControlPlaneApi(
        profiles: const <ProfileRecord>[],
        sessions: const <SessionRecord>[],
      );
      final supervisor = _SequencedHostSupervisor(const <HostConnectionResult>[
        HostConnectionResult(
          state: HostLifecycleState.ready,
          message: 'ready',
          info: _readyHostInfo,
        ),
        HostConnectionResult(
          state: HostLifecycleState.ready,
          message: 'ready again',
          info: _readyHostInfo,
        ),
      ]);
      final controller = DesktopShellController(
        api: api,
        supervisor: supervisor,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.startPlatformTunnel(PlatformTunnelMode.windowsWintun);
      expect(
        controller.platformTunnelResultFor(PlatformTunnelMode.windowsWintun),
        isNotNull,
      );

      await controller.reconnect();

      expect(supervisor.calls, 2);
      expect(
        controller.platformTunnelResultFor(PlatformTunnelMode.windowsWintun),
        isNull,
      );
      expect(
        controller.platformTunnels.single.mode,
        PlatformTunnelMode.windowsWintun,
      );
      expect(controller.notice, 'ready again');
    },
  );
}

class _FakeControlPlaneApi implements ControlPlaneApi {
  _FakeControlPlaneApi({
    required List<ProfileRecord> profiles,
    List<ResolutionRecord>? resolutions,
    required List<SessionRecord> sessions,
    Map<String, ChallengeRecord>? challenges,
  }) : _profiles = List<ProfileRecord>.of(profiles),
       _resolutions = List<ResolutionRecord>.of(
         resolutions ?? const <ResolutionRecord>[],
       ),
       _sessions = List<SessionRecord>.of(sessions),
       _challenges = Map<String, ChallengeRecord>.of(
         challenges ?? <String, ChallengeRecord>{},
       );

  final List<ProfileRecord> _profiles;
  final List<ResolutionRecord> _resolutions;
  final List<SessionRecord> _sessions;
  final Map<String, ChallengeRecord> _challenges;
  final StreamController<EventRecord> _events =
      StreamController<EventRecord>.broadcast();
  final List<String> challengeRequests = <String>[];
  final List<_StartResolutionCall> startResolutionCalls =
      <_StartResolutionCall>[];
  final List<String> materializeResolutionCalls = <String>[];
  final List<RuntimeDefaults> materializeResolutionDefaults =
      <RuntimeDefaults>[];
  final List<PlatformTunnelMode> startPlatformTunnelCalls =
      <PlatformTunnelMode>[];
  final List<ProfileRecord> upsertedProfiles = <ProfileRecord>[];
  bool failReads = false;
  int startSessionCalls = 0;

  @override
  Future<ChallengeRecord> cancelChallenge(String challengeId) async {
    return _challenges[challengeId]!;
  }

  @override
  Future<ChallengeRecord> challenge(String challengeId) async {
    challengeRequests.add(challengeId);
    final challenge = _challenges[challengeId];
    if (challenge == null) {
      throw const ControlPlaneError(
        statusCode: 404,
        code: 'not_found',
        message: 'challenge not found',
      );
    }
    return challenge;
  }

  @override
  Future<ChallengeRecord> continueChallenge(String challengeId) async {
    return _challenges[challengeId]!;
  }

  @override
  Future<void> deleteProfile(String profileId) async {}

  @override
  Future<ResolutionRecord> cancelResolution(String resolutionId) async {
    final index = _resolutions.indexWhere(
      (ResolutionRecord resolution) => resolution.id == resolutionId,
    );
    if (index < 0) {
      throw const ControlPlaneError(
        statusCode: 404,
        code: 'not_found',
        message: 'resolution not found',
      );
    }
    final updated = _resolutionRecord(
      id: _resolutions[index].id,
      state: ResolutionState.cancelled,
    );
    _resolutions[index] = updated;
    return updated;
  }

  @override
  Future<DiagnosticsBundle> diagnostics(String sessionId) async {
    return DiagnosticsBundle(
      session: _sessions.first,
      events: const <EventRecord>[],
      challenges: _challenges.values.toList(growable: false),
      metrics: 'vk_turn_proxy_runtime_session_starts_total 1',
      hostBuild: _testHostBuild,
      contractVersion: '1',
    );
  }

  @override
  Stream<EventRecord> events() => _events.stream;

  void emitEvent(EventRecord event) {
    _events.add(event);
  }

  @override
  Future<HostInfo> hostInfo() async {
    return _readyHostInfo;
  }

  @override
  Future<SessionRecord> materializeResolution({
    required String resolutionId,
    required RuntimeDefaults runtimeDefaults,
  }) async {
    materializeResolutionCalls.add(resolutionId);
    materializeResolutionDefaults.add(runtimeDefaults);
    final session = SessionRecord(
      id: 'materialized-session',
      profileId: null,
      profileName: 'materialized',
      sourceResolutionId: resolutionId,
      profile: _profileSpec().copyWith(
        provider: 'generic-turn',
        listenAddress: runtimeDefaults.listenAddress,
        peerAddress: runtimeDefaults.peerAddress,
        turnServer: runtimeDefaults.turnServer,
        turnPort: runtimeDefaults.turnPort,
      ),
      state: SessionState.ready,
      startedAt: DateTime.utc(2026, 4, 7, 11, 0),
      updatedAt: DateTime.utc(2026, 4, 7, 11, 0),
    );
    _sessions
      ..clear()
      ..add(session);
    return session;
  }

  @override
  Future<HostInfo> negotiate({
    required List<String> supportedVersions,
    required List<Capability> requiredCapabilities,
  }) {
    return hostInfo();
  }

  @override
  Future<ResolutionExportResult> exportResolution(String resolutionId) async {
    return ResolutionExportResult(
      resolutionId: resolutionId,
      link: 'generic-turn://turn-user:turn-pass@turn.example.test:3478',
      expiresAt: DateTime.utc(2026, 4, 10, 20, 17, 6),
      expirySource: 'vk_turn_rest_username',
    );
  }

  @override
  Future<PlatformTunnelStartResult> startPlatformTunnel({
    required PlatformTunnelMode mode,
  }) async {
    startPlatformTunnelCalls.add(mode);
    return const PlatformTunnelStartResult(
      mode: PlatformTunnelMode.windowsWintun,
      ready: false,
      stage: PlatformTunnelStartupStage.capabilityCheck,
      missingPrerequisite: PlatformTunnelPrerequisite.hostImplementation,
      message: 'desktop sidecar does not implement system tunnel startup yet',
    );
  }

  @override
  Future<List<ProfileRecord>> profiles() async {
    if (failReads) {
      throw const ControlPlaneError(
        statusCode: 0,
        code: 'connection_failed',
        message: 'control plane connection lost',
      );
    }
    return _profiles;
  }

  @override
  Future<List<ResolutionRecord>> resolutions() async => _resolutions;

  @override
  Future<ResolutionRecord> startResolution({
    required String provider,
    required String link,
    required bool interactiveProvider,
  }) async {
    startResolutionCalls.add(
      _StartResolutionCall(
        provider: provider,
        link: link,
        interactiveProvider: interactiveProvider,
      ),
    );
    final resolution = _resolutionRecord(
      id: 'resolution-${startResolutionCalls.length}',
      provider: provider,
      linkRedacted: link,
    );
    _resolutions
      ..clear()
      ..add(resolution);
    return resolution;
  }

  @override
  Future<List<SessionRecord>> sessions() async {
    if (failReads) {
      throw const ControlPlaneError(
        statusCode: 0,
        code: 'connection_failed',
        message: 'control plane connection lost',
      );
    }
    return _sessions;
  }

  @override
  Future<SessionRecord> startSession({
    String? profileId,
    ProfileSpec? spec,
  }) async {
    startSessionCalls++;
    return _sessions.first;
  }

  @override
  Future<SessionRecord> stopSession(String sessionId) async {
    return _sessions.first;
  }

  @override
  Future<ProfileRecord> upsertProfile(ProfileRecord profile) async {
    upsertedProfiles.add(profile);
    final index = _profiles.indexWhere(
      (ProfileRecord existing) => existing.id == profile.id,
    );
    if (index >= 0) {
      _profiles[index] = profile;
    } else {
      _profiles.add(profile);
    }
    return profile;
  }
}

class _FakeShellStateStore implements DesktopShellStateStore {
  _FakeShellStateStore({this.loaded});

  final DesktopShellState? loaded;
  final List<DesktopShellState> savedStates = <DesktopShellState>[];

  @override
  Future<DesktopShellState?> load() async => loaded;

  @override
  Future<void> save(DesktopShellState state) async {
    savedStates.add(state);
  }
}

class _FakeDesktopHandoffAdapter implements DesktopHandoffAdapter {
  final List<String> copiedLinks = <String>[];

  @override
  Future<void> copyLink(String link) async {
    copiedLinks.add(link);
  }
}

class _SequencedHostSupervisor implements HostSupervisor {
  _SequencedHostSupervisor(this._results);

  final List<HostConnectionResult> _results;
  int calls = 0;

  @override
  Future<void> dispose() async {}

  @override
  Future<HostConnectionResult> ensureReady() async {
    final index = calls < _results.length ? calls : _results.length - 1;
    calls++;
    return _results[index];
  }
}

ProfileSpec _profileSpec() {
  return const ProfileSpec(
    provider: 'vk',
    link: 'https://vk.com/call/join/test',
    listenAddress: '127.0.0.1:9001',
    peerAddress: '127.0.0.1:56000',
    turnServer: 'turn.example.test',
    turnPort: '3478',
  );
}

ResolutionRecord _resolutionRecord({
  String id = 'resolution-1',
  String provider = 'vk',
  String linkRedacted = 'https://vk.com/call/join/<redacted:invite-token>',
  ResolutionState state = ResolutionState.resolved,
  String? activeChallengeId,
}) {
  return ResolutionRecord(
    id: id,
    provider: provider,
    input: ResolutionInput(
      provider: provider,
      linkRedacted: linkRedacted,
      interactiveProvider: true,
    ),
    state: state,
    credentials: const ResolutionCredentials(
      address: 'turn.example.test:3478',
      usernameRedacted: '<redacted:turn-username>',
      passwordRedacted: '<redacted:turn-password>',
    ),
    export: ResolutionExportStatus(
      supported: state == ResolutionState.resolved,
      expiresAt: state == ResolutionState.resolved
          ? DateTime.utc(2026, 4, 10, 20, 17, 6)
          : null,
      expirySource: state == ResolutionState.resolved
          ? 'vk_turn_rest_username'
          : null,
    ),
    activeChallengeId: activeChallengeId,
    startedAt: DateTime.utc(2026, 4, 10, 12, 0),
    updatedAt: DateTime.utc(2026, 4, 10, 12, 1),
    resolvedAt: state == ResolutionState.resolved
        ? DateTime.utc(2026, 4, 10, 12, 1)
        : null,
  );
}

class _StartResolutionCall {
  const _StartResolutionCall({
    required this.provider,
    required this.link,
    required this.interactiveProvider,
  });

  final String provider;
  final String link;
  final bool interactiveProvider;
}
