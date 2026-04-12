import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gui_shell/src/control/control_plane_client.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/desktop_host_supervisor.dart';
import 'package:gui_shell/src/control/desktop_shell_controller.dart';
import 'package:gui_shell/src/control/shell_state_store.dart';
import 'package:gui_shell/src/ui/dashboard_page.dart';

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
    Capability.providerRuntimeArtifacts,
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

const List<ProviderDescriptor> _providerDescriptors = <ProviderDescriptor>[
  ProviderDescriptor(
    id: 'vk',
    displayName: 'VK Calls',
    description:
        'Invite-first provider with browser-mediated continuation that resolves into transport-ready TURN credentials.',
    inputKind: ProviderInputKind.link,
    authPosture: ProviderAuthPosture.guestOrAccount,
    browserPolicy: ProviderBrowserPolicy.externalRequired,
    challengeModes: <ProviderChallengeMode>[ProviderChallengeMode.browser],
    artifactFamilies: <ArtifactFamily>[ArtifactFamily.genericTurn],
  ),
  ProviderDescriptor(
    id: 'generic-turn',
    displayName: 'Generic TURN',
    description:
        'Static TURN handoff for deterministic transport testing and operator-driven runtime startup.',
    inputKind: ProviderInputKind.link,
    authPosture: ProviderAuthPosture.staticSecret,
    browserPolicy: ProviderBrowserPolicy.notRequired,
    artifactFamilies: <ArtifactFamily>[ArtifactFamily.genericTurn],
  ),
];

void main() {
  testWidgets('desktop shell starts a saved profile from the GUI', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _FakeControlPlaneApi();
    final controller = DesktopShellController(
      api: api,
      supervisor: _FakeHostSupervisor(),
      stateStore: const _InMemoryShellStateStore(),
      appBuild: _testGuiBuild,
    );

    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(home: DashboardPage(controller: controller)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Local host ready'), findsOneWidget);
    expect(find.text('alpha', skipOffstage: false), findsOneWidget);
    expect(find.text('GUI 0.1.0+1 @gui123456789'), findsOneWidget);
    expect(find.text('Host 0.1.0+1 @deadbeefcafe'), findsOneWidget);
    expect(find.text('Contract 1'), findsOneWidget);
    expect(find.text('Platform tunnel modes'), findsOneWidget);
    expect(find.text('Resolutions'), findsOneWidget);
    expect(find.textContaining('Windows Wintun'), findsOneWidget);
    expect(
      find.textContaining('Fail-closed platform tunnel checks stay collapsed'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Windows Wintun: host implementation missing'),
      findsOneWidget,
    );
    final hostTitleOffset = tester.getTopLeft(find.text('Local host ready'));
    final tunnelTitleOffset = tester.getTopLeft(
      find.text('Platform tunnel modes'),
    );
    final resolutionsTitleOffset = tester.getTopLeft(find.text('Resolutions'));

    expect((hostTitleOffset.dy - tunnelTitleOffset.dy).abs(), lessThan(24));
    expect(resolutionsTitleOffset.dy, lessThan(430));

    final startButton = find.text('Start saved profile', skipOffstage: false);
    await tester.scrollUntilVisible(
      startButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(startButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(api.startedProfileIDs, <String>['profile-1']);
    expect(find.textContaining('Started session'), findsOneWidget);
    expect(find.text('ready'), findsWidgets);

    final tunnelButton = find.text('Request startup', skipOffstage: false);
    await tester.ensureVisible(tunnelButton);
    await tester.pump();
    await tester.tap(tunnelButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(api.startedPlatformTunnels, <PlatformTunnelMode>[
      PlatformTunnelMode.windowsWintun,
    ]);
    expect(find.textContaining('Capability check'), findsWidgets);

    controller.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(api.dispose());
  });

  testWidgets('desktop shell renders and executes open room actions', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _FakeControlPlaneApi(
      resolutionsList: <ResolutionRecord>[
        ResolutionRecord(
          id: 'resolution-room-1',
          provider: 'roomy',
          input: ResolutionInput(
            provider: 'roomy',
            kind: ProviderInputKind.link,
            linkRedacted:
                'https://room.example.test/join/<redacted:room-token>',
          ),
          state: ResolutionState.resolved,
          artifact: ResolutionArtifactRecord(
            family: ArtifactFamily.conferenceRoom,
            actions: <ResolutionActionRecord>[
              ResolutionActionRecord(
                id: ArtifactAction.openRoom,
                executionOwner: ActionExecutionOwner.shellExternal,
              ),
            ],
            summary: ResolutionArtifactSummary(
              conferenceRoom: ConferenceRoomArtifactSummary(
                roomUrl: 'https://room.example.test/rooms/team-sync',
              ),
            ),
          ),
          export: ResolutionExportStatus(supported: false),
          startedAt: DateTime.utc(2026, 4, 10, 12, 0),
          updatedAt: DateTime.utc(2026, 4, 10, 12, 1),
          resolvedAt: DateTime.utc(2026, 4, 10, 12, 1),
        ),
      ],
    );
    final browser = _FakeDesktopBrowserLauncher();
    final controller = DesktopShellController(
      api: api,
      supervisor: _FakeHostSupervisor(),
      stateStore: const _InMemoryShellStateStore(),
      browserLauncher: browser,
      appBuild: _testGuiBuild,
    );

    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(home: DashboardPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    final openRoomButton = find.text('Open room', skipOffstage: false);
    await tester.scrollUntilVisible(
      openRoomButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(openRoomButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(browser.openedUrls, <String>[
      'https://room.example.test/rooms/team-sync',
    ]);

    controller.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(api.dispose());
  });
}

class _InMemoryShellStateStore implements DesktopShellStateStore {
  const _InMemoryShellStateStore();

  @override
  Future<DesktopShellState?> load() async {
    return null;
  }

  @override
  Future<void> save(DesktopShellState state) async {}
}

class _FakeControlPlaneApi implements ControlPlaneApi {
  _FakeControlPlaneApi({this.resolutionsList = const <ResolutionRecord>[]});

  final List<ResolutionRecord> resolutionsList;
  final List<String> startedProfileIDs = <String>[];
  final List<PlatformTunnelMode> startedPlatformTunnels =
      <PlatformTunnelMode>[];
  final List<ProfileRecord> _profiles = <ProfileRecord>[
    ProfileRecord(
      id: 'profile-1',
      name: 'alpha',
      spec: const ProfileSpec(
        provider: 'vk',
        link: 'https://vk.com/call/join/test',
        listenAddress: '127.0.0.1:9001',
        peerAddress: '127.0.0.1:56000',
      ),
    ),
  ];
  final StreamController<EventRecord> _events =
      StreamController<EventRecord>.broadcast();
  List<SessionRecord> _sessions = const <SessionRecord>[];

  @override
  Future<ChallengeRecord> cancelChallenge(String challengeId) {
    throw UnimplementedError();
  }

  @override
  Future<ChallengeRecord> challenge(String challengeId) {
    throw UnimplementedError();
  }

  @override
  Future<ChallengeRecord> continueChallenge(String challengeId) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    _profiles.removeWhere((ProfileRecord profile) => profile.id == profileId);
  }

  @override
  Future<ResolutionRecord> cancelResolution(String resolutionId) async {
    throw UnimplementedError();
  }

  @override
  Future<DiagnosticsBundle> diagnostics(String sessionId) async {
    return DiagnosticsBundle(
      session: _sessions.first,
      events: const <EventRecord>[],
      challenges: const <ChallengeRecord>[],
      metrics: 'vk_turn_proxy_runtime_session_starts_total 1',
      hostBuild: _testHostBuild,
      contractVersion: '1',
    );
  }

  @override
  Stream<EventRecord> events() => _events.stream;

  @override
  Future<HostInfo> hostInfo() async {
    return _readyHostInfo;
  }

  @override
  Future<SessionRecord> materializeResolution({
    required String resolutionId,
    required RuntimeDefaults runtimeDefaults,
  }) async {
    return _sessions.first;
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
    startedPlatformTunnels.add(mode);
    return const PlatformTunnelStartResult(
      mode: PlatformTunnelMode.windowsWintun,
      ready: false,
      stage: PlatformTunnelStartupStage.capabilityCheck,
      missingPrerequisite: PlatformTunnelPrerequisite.hostImplementation,
      message: 'desktop sidecar does not implement system tunnel startup yet',
    );
  }

  @override
  Future<List<ProviderDescriptor>> providers() async => _providerDescriptors;

  @override
  Future<List<ProfileRecord>> profiles() async => _profiles;

  @override
  Future<List<ResolutionRecord>> resolutions() async => resolutionsList;

  @override
  Future<ResolutionRecord> startResolution({
    required String provider,
    required ProviderInputEnvelope input,
    Map<String, dynamic> providerSettings = const <String, dynamic>{},
  }) async {
    return ResolutionRecord(
      id: 'resolution-1',
      provider: provider,
      input: ResolutionInput(
        provider: provider,
        kind: input.kind,
        linkRedacted: input.link,
        interactiveProvider: provider == 'vk',
      ),
      state: ResolutionState.resolved,
      artifact: const ResolutionArtifactRecord(
        family: ArtifactFamily.genericTurn,
        actions: <ResolutionActionRecord>[
          ResolutionActionRecord(
            id: ArtifactAction.startOnThisDevice,
            executionOwner: ActionExecutionOwner.host,
          ),
          ResolutionActionRecord(
            id: ArtifactAction.exportHandoff,
            executionOwner: ActionExecutionOwner.host,
          ),
        ],
      ),
      export: ResolutionExportStatus(
        supported: true,
        expiresAt: DateTime.utc(2026, 4, 10, 20, 17, 6),
        expirySource: 'vk_turn_rest_username',
      ),
      startedAt: DateTime.utc(2026, 4, 10, 12, 0),
      updatedAt: DateTime.utc(2026, 4, 10, 12, 1),
    );
  }

  @override
  Future<SessionRecord> startSession({
    String? profileId,
    ProfileSpec? spec,
  }) async {
    startedProfileIDs.add(profileId ?? '');
    final now = DateTime(2026, 4, 5, 17, 0);
    final session = SessionRecord(
      id: 'session-1',
      profileId: profileId,
      profileName: 'alpha',
      profile: _profiles.first.spec,
      state: SessionState.ready,
      startedAt: now,
      updatedAt: now,
    );
    _sessions = <SessionRecord>[session];
    _events.add(
      EventRecord(
        id: 'event-1',
        timestamp: now,
        sessionId: session.id,
        type: EventType.sessionReady,
        state: SessionState.ready,
        message: 'runtime ready',
      ),
    );
    return session;
  }

  @override
  Future<SessionRecord> stopSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<List<SessionRecord>> sessions() async => _sessions;

  @override
  Future<ProfileRecord> upsertProfile(ProfileRecord profile) async {
    _profiles
      ..removeWhere((ProfileRecord current) => current.id == profile.id)
      ..add(profile);
    return profile;
  }

  Future<void> dispose() async {
    await _events.close();
  }
}

class _FakeHostSupervisor implements HostSupervisor {
  @override
  Future<void> dispose() async {}

  @override
  Future<HostConnectionResult> ensureReady() async {
    return const HostConnectionResult(
      state: HostLifecycleState.ready,
      message: 'Connected to local host 127.0.0.1:7777',
      info: _readyHostInfo,
    );
  }
}

class _FakeDesktopBrowserLauncher implements BrowserLauncher {
  final List<String> openedUrls = <String>[];

  @override
  Future<bool> open(String url) async {
    openedUrls.add(url);
    return true;
  }
}
