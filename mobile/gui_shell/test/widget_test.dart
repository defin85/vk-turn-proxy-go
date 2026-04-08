import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_gui_shell/src/app.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/mobile_host_bridge.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_controller.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_state_store.dart';
import 'package:mobile_gui_shell/src/control/profile_draft.dart';

void main() {
  testWidgets('mobile shell renders challenge handoff and tunnel disclaimer', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = MobileShellController(
      bridge: _FakeMobileHostBridge(
        sessionsList: <SessionRecord>[
          SessionRecord(
            id: 'session-1',
            profileId: 'profile-1',
            profileName: 'vk live',
            profile: _profileSpec(),
            state: SessionState.challengeRequired,
            activeChallengeId: 'challenge-1',
            startedAt: DateTime.utc(2026, 4, 7, 12, 0),
            updatedAt: DateTime.utc(2026, 4, 7, 12, 1),
          ),
        ],
        challengeMap: <String, ChallengeRecord>{
          'challenge-1': ChallengeRecord(
            id: 'challenge-1',
            sessionId: 'session-1',
            provider: 'vk',
            stage: 'provider_resolve',
            kind: 'browser',
            prompt: 'Complete the browser step, then return here.',
            openUrl: 'https://vk.com/call/join/test',
            status: ChallengeStatus.pending,
            createdAt: DateTime.utc(2026, 4, 7, 12, 0),
            updatedAt: DateTime.utc(2026, 4, 7, 12, 1),
          ),
        },
      ),
      stateStore: _InMemoryStateStore(
        MobileShellState(
          profiles: <ProfileRecord>[
            ProfileRecord(
              id: 'profile-1',
              name: 'vk live',
              spec: _profileSpec(),
            ),
          ],
          selectedProfileId: 'profile-1',
          draft: ProfileDraft.fromProfile(
            ProfileRecord(
              id: 'profile-1',
              name: 'vk live',
              spec: _profileSpec(),
            ),
          ),
        ),
      ),
    );
    await controller.initialize();
    await tester.pumpWidget(MobileShellApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Mobile host ready'), findsOneWidget);
    expect(
      find.textContaining('does not yet claim device-wide tunnel capture'),
      findsOneWidget,
    );
    expect(find.text('Android VPN Service'), findsOneWidget);
    final tunnelButton = find.text('Request startup', skipOffstage: false);
    expect(tunnelButton, findsOneWidget);
    await tester.tap(tunnelButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      controller
          .platformTunnelResultFor(PlatformTunnelMode.androidVpnService)
          ?.stage,
      PlatformTunnelStartupStage.capabilityCheck,
    );
    expect(find.textContaining('Capability check'), findsWidgets);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('Open browser', skipOffstage: false), findsOneWidget);
    expect(find.text("I've completed it", skipOffstage: false), findsOneWidget);
    expect(find.text('vk live'), findsWidgets);
  });

  testWidgets('mobile shell exposes reset action for blocked local state', (
    WidgetTester tester,
  ) async {
    final controller = MobileShellController(
      bridge: _FakeMobileHostBridge(),
      stateStore: _ThrowingStateStore(
        StateError(
          'Secure profile secrets are unavailable. Restore secure storage or clear the saved mobile shell state.',
        ),
      ),
    );
    await controller.initialize();
    await tester.pumpWidget(MobileShellApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Mobile host blocked'), findsOneWidget);
    expect(find.text('Reset local state'), findsOneWidget);
    expect(
      find.textContaining('Secure profile secrets are unavailable'),
      findsWidgets,
    );
  });

  testWidgets('mobile shell shows freshest sessions first with session metadata', (
    WidgetTester tester,
  ) async {
    final controller = MobileShellController(
      bridge: _FakeMobileHostBridge(
        sessionsList: <SessionRecord>[
          SessionRecord(
            id: 'session-failed',
            profileId: 'profile-1',
            profileName: 'older failed',
            profile: _profileSpec(),
            state: SessionState.failed,
            failure: const FailureInfo(
              stage: 'turn_allocate',
              message: 'timed out',
            ),
            startedAt: DateTime.utc(2026, 4, 7, 12, 0),
            updatedAt: DateTime.utc(2026, 4, 7, 12, 1),
            stoppedAt: DateTime.utc(2026, 4, 7, 12, 1),
          ),
          SessionRecord(
            id: 'session-new',
            profileId: 'profile-1',
            profileName: 'newer stopped',
            profile: _profileSpec(),
            state: SessionState.stopped,
            startedAt: DateTime.utc(2026, 4, 7, 12, 2),
            updatedAt: DateTime.utc(2026, 4, 7, 12, 3),
            stoppedAt: DateTime.utc(2026, 4, 7, 12, 3),
          ),
        ],
      ),
      stateStore: _InMemoryStateStore(
        MobileShellState(
          profiles: <ProfileRecord>[
            ProfileRecord(
              id: 'profile-1',
              name: 'vk live',
              spec: _profileSpec(),
            ),
          ],
          selectedProfileId: 'profile-1',
          draft: ProfileDraft.fromProfile(
            ProfileRecord(
              id: 'profile-1',
              name: 'vk live',
              spec: _profileSpec(),
            ),
          ),
        ),
      ),
    );
    await controller.initialize();
    await tester.pumpWidget(MobileShellApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    final updatedAt = DateTime.utc(2026, 4, 7, 12, 3).toLocal();
    final updatedLabel =
        'Updated ${updatedAt.year}-${_twoDigits(updatedAt.month)}-${_twoDigits(updatedAt.day)} '
        '${_twoDigits(updatedAt.hour)}:${_twoDigits(updatedAt.minute)}:${_twoDigits(updatedAt.second)}';

    expect(
      tester.getTopLeft(find.text('newer stopped', skipOffstage: false)).dy,
      lessThan(
        tester.getTopLeft(find.text('older failed', skipOffstage: false)).dy,
      ),
    );
    expect(
      find.textContaining(updatedLabel, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.textContaining('session session-new', skipOffstage: false),
      findsOneWidget,
    );
  });
}

const HostInfo _readyHostInfo = HostInfo(
  contractVersion: '1',
  build: BuildIdentity(
    product: 'vk-turn-proxy-go',
    version: '0.1.0',
    buildNumber: '1',
    revision: 'mobilehost1234',
    role: 'mobile_host',
    target: 'android/debug',
  ),
  capabilities: <Capability>[
    Capability.mobileHostBridge,
    Capability.platformTunnels,
    Capability.profiles,
    Capability.sessions,
    Capability.challenges,
    Capability.diagnostics,
    Capability.eventStream,
  ],
  platformTunnels: <PlatformTunnelCapability>[
    PlatformTunnelCapability(
      mode: PlatformTunnelMode.androidVpnService,
      available: false,
      missingPrerequisite: PlatformTunnelPrerequisite.hostImplementation,
      message: 'embedded mobile host does not implement tunnel startup yet',
    ),
  ],
);

ProfileSpec _profileSpec() {
  return const ProfileSpec(
    provider: 'vk',
    link: 'https://vk.com/call/join/test',
    listenAddress: '127.0.0.1:9006',
    peerAddress: '176.109.104.105:38218',
    interactiveProvider: true,
  );
}

class _InMemoryStateStore implements MobileShellStateStore {
  const _InMemoryStateStore(this.state);

  final MobileShellState state;

  @override
  Future<MobileShellState?> load() async => state;

  @override
  Future<void> save(MobileShellState state) async {}

  @override
  Future<void> clear() async {}
}

class _FakeMobileHostBridge implements MobileHostBridge {
  _FakeMobileHostBridge({
    this.sessionsList = const <SessionRecord>[],
    this.challengeMap = const <String, ChallengeRecord>{},
  });

  final List<SessionRecord> sessionsList;
  final Map<String, ChallengeRecord> challengeMap;
  final List<PlatformTunnelMode> startedPlatformTunnels =
      <PlatformTunnelMode>[];

  @override
  Future<ChallengeRecord> cancelChallenge(String challengeId) async {
    return challengeMap[challengeId]!;
  }

  @override
  Future<ChallengeRecord> challenge(String challengeId) async {
    return challengeMap[challengeId]!;
  }

  @override
  Future<ChallengeRecord> continueChallenge(String challengeId) async {
    return challengeMap[challengeId]!;
  }

  @override
  Future<void> deleteProfile(String profileId) async {}

  @override
  Future<DiagnosticsBundle> diagnostics(String sessionId) async {
    return DiagnosticsBundle(
      session: sessionsList.first,
      events: const <EventRecord>[],
      challenges: challengeMap.values.toList(growable: false),
      metrics: '',
      hostBuild: _readyHostInfo.build,
      contractVersion: _readyHostInfo.contractVersion,
    );
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<MobileHostConnectionResult> ensureReady() async {
    return const MobileHostConnectionResult(
      state: MobileHostLifecycleState.ready,
      message: 'Connected to embedded mobile host bridge',
      info: _readyHostInfo,
      description: 'fake-test-bridge',
    );
  }

  @override
  Stream<EventRecord> events() => const Stream<EventRecord>.empty();

  @override
  Future<HostInfo> hostInfo() async => _readyHostInfo;

  @override
  Future<HostInfo> negotiate({
    required List<String> supportedVersions,
    required List<Capability> requiredCapabilities,
  }) async {
    return _readyHostInfo;
  }

  @override
  Future<PlatformTunnelStartResult> startPlatformTunnel({
    required PlatformTunnelMode mode,
  }) async {
    startedPlatformTunnels.add(mode);
    return const PlatformTunnelStartResult(
      mode: PlatformTunnelMode.androidVpnService,
      ready: false,
      stage: PlatformTunnelStartupStage.capabilityCheck,
      missingPrerequisite: PlatformTunnelPrerequisite.hostImplementation,
      message: 'embedded mobile host does not implement tunnel startup yet',
    );
  }

  @override
  Future<List<ProfileRecord>> profiles() async => const <ProfileRecord>[];

  @override
  Future<List<SessionRecord>> sessions() async => sessionsList;

  @override
  Future<SessionRecord> startSession({
    String? profileId,
    ProfileSpec? spec,
  }) async {
    return sessionsList.first;
  }

  @override
  Future<SessionRecord> stopSession(String sessionId) async =>
      sessionsList.first;

  @override
  Future<ProfileRecord> upsertProfile(ProfileRecord profile) async => profile;
}

class _ThrowingStateStore implements MobileShellStateStore {
  const _ThrowingStateStore(this.error);

  final Object error;

  @override
  Future<void> clear() async {}

  @override
  Future<MobileShellState?> load() async {
    throw error;
  }

  @override
  Future<void> save(MobileShellState state) async {}
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
