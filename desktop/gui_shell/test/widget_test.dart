import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gui_shell/src/control/control_plane_client.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/desktop_host_supervisor.dart';
import 'package:gui_shell/src/control/desktop_shell_controller.dart';
import 'package:gui_shell/src/control/shell_state_store.dart';
import 'package:gui_shell/src/ui/dashboard_page.dart';

void main() {
  testWidgets('desktop shell starts a saved profile from the GUI', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _FakeControlPlaneApi();
    final controller = DesktopShellController(
      api: api,
      supervisor: _FakeHostSupervisor(),
      stateStore: const _InMemoryShellStateStore(),
    );

    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(controller: controller),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Local host ready'), findsOneWidget);
    expect(find.text('alpha', skipOffstage: false), findsOneWidget);

    final startButton = find.widgetWithText(
      FilledButton,
      'Start saved profile',
      skipOffstage: false,
    );
    await tester.ensureVisible(startButton);
    await tester.pump();
    await tester.tap(startButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(api.startedProfileIDs, <String>['profile-1']);
    expect(find.textContaining('Started session'), findsOneWidget);
    expect(find.text('ready'), findsWidgets);

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
  final List<String> startedProfileIDs = <String>[];
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
  final StreamController<EventRecord> _events = StreamController<EventRecord>.broadcast();
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
  Future<DiagnosticsBundle> diagnostics(String sessionId) async {
    return DiagnosticsBundle(
      session: _sessions.first,
      events: const <EventRecord>[],
      challenges: const <ChallengeRecord>[],
      metrics: 'vk_turn_proxy_runtime_session_starts_total 1',
    );
  }

  @override
  Stream<EventRecord> events() => _events.stream;

  @override
  Future<HostInfo> hostInfo() async {
    return const HostInfo(
      version: '1',
      capabilities: <Capability>[
        Capability.desktopSidecar,
        Capability.profiles,
        Capability.sessions,
        Capability.challenges,
        Capability.diagnostics,
        Capability.eventStream,
      ],
    );
  }

  @override
  Future<HostInfo> negotiate({
    required List<String> supportedVersions,
    required List<Capability> requiredCapabilities,
  }) {
    return hostInfo();
  }

  @override
  Future<List<ProfileRecord>> profiles() async => _profiles;

  @override
  Future<SessionRecord> startSession({String? profileId, ProfileSpec? spec}) async {
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
      info: HostInfo(
        version: '1',
        capabilities: <Capability>[
          Capability.desktopSidecar,
          Capability.profiles,
          Capability.sessions,
          Capability.challenges,
          Capability.diagnostics,
          Capability.eventStream,
        ],
      ),
    );
  }
}
