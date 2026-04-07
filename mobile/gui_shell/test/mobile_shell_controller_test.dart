import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/mobile_host_bridge.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_controller.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_state_store.dart';
import 'package:mobile_gui_shell/src/control/profile_draft.dart';

const BuildIdentity _testGuiBuild = BuildIdentity(
  product: 'vk-turn-proxy-go',
  version: '0.1.0',
  buildNumber: '1',
  revision: 'mobilegui1234',
  role: 'mobile_gui_shell',
  target: 'android/debug',
);

const BuildIdentity _testHostBuild = BuildIdentity(
  product: 'vk-turn-proxy-go',
  version: '0.1.0',
  buildNumber: '1',
  revision: 'embeddedhost123',
  role: 'mobile_host',
  target: 'android/debug',
);

const HostInfo _readyHostInfo = HostInfo(
  contractVersion: '1',
  build: _testHostBuild,
  capabilities: <Capability>[
    Capability.mobileHostBridge,
    Capability.profiles,
    Capability.sessions,
    Capability.challenges,
    Capability.diagnostics,
    Capability.eventStream,
  ],
);

void main() {
  test(
    'controller rehydrates persisted profiles into a ready mobile bridge',
    () async {
      final profile = ProfileRecord(
        id: 'profile-1',
        name: 'vk live',
        spec: _profileSpec(),
      );
      final bridge = _FakeMobileHostBridge();
      final controller = MobileShellController(
        bridge: bridge,
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: <ProfileRecord>[profile],
            selectedProfileId: profile.id,
            draft: ProfileDraft.fromProfile(profile),
          ),
        ),
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(controller.status, ShellStatus.ready);
      expect(controller.hostConnection?.isReady, isTrue);
      expect(
        bridge.upsertedProfiles.map((ProfileRecord item) => item.id),
        <String>['profile-1'],
      );
      expect(controller.profiles.single.id, 'profile-1');
    },
  );

  test(
    'controller blocks incompatible bridge and does not start sessions',
    () async {
      final profile = ProfileRecord(
        id: 'profile-1',
        name: 'vk live',
        spec: _profileSpec(),
      );
      final bridge = _FakeMobileHostBridge(
        ensureReadyResult: const MobileHostConnectionResult(
          state: MobileHostLifecycleState.incompatible,
          message: 'contract mismatch',
          info: HostInfo(
            contractVersion: '2',
            build: _testHostBuild,
            capabilities: <Capability>[Capability.mobileHostBridge],
          ),
          description: 'native bridge',
        ),
      );
      final controller = MobileShellController(
        bridge: bridge,
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: <ProfileRecord>[profile],
            selectedProfileId: profile.id,
            draft: ProfileDraft.fromProfile(profile),
          ),
        ),
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.startSelectedProfile();

      expect(controller.status, ShellStatus.blocked);
      expect(
        controller.hostConnection?.state,
        MobileHostLifecycleState.incompatible,
      );
      expect(controller.notice, contains('contract mismatch'));
      expect(bridge.startSessionCalls, 0);
    },
  );

  test(
    'controller uses browser handoff and typed challenge continuation',
    () async {
      final challenge = ChallengeRecord(
        id: 'challenge-1',
        sessionId: 'session-1',
        provider: 'vk',
        stage: 'provider_resolve',
        kind: 'browser',
        prompt: 'Open the browser and complete Join.',
        openUrl: 'https://vk.com/call/join/test',
        status: ChallengeStatus.pending,
        createdAt: DateTime.utc(2026, 4, 7, 13, 0),
        updatedAt: DateTime.utc(2026, 4, 7, 13, 1),
      );
      final bridge = _FakeMobileHostBridge(
        sessionsList: <SessionRecord>[
          SessionRecord(
            id: 'session-1',
            profileId: 'profile-1',
            profileName: 'vk live',
            profile: _profileSpec(),
            state: SessionState.challengeRequired,
            activeChallengeId: challenge.id,
            startedAt: DateTime.utc(2026, 4, 7, 13, 0),
            updatedAt: DateTime.utc(2026, 4, 7, 13, 1),
          ),
        ],
        challengeMap: <String, ChallengeRecord>{challenge.id: challenge},
      );
      final browser = _FakeBrowserLauncher();
      final controller = MobileShellController(
        bridge: bridge,
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
        browserLauncher: browser,
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      final active = controller.activeChallengeFor(controller.sessions.single);
      expect(active?.id, challenge.id);

      await controller.openChallengeInBrowser(active!);
      expect(browser.openedUrls, <String>['https://vk.com/call/join/test']);
      expect(controller.notice, contains('Opened mobile browser handoff'));

      await controller.continueChallenge(challenge.id);
      expect(bridge.continueChallengeCalls, <String>[challenge.id]);
    },
  );

  test(
    'controller exports diagnostics with GUI and host build identities',
    () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'mobile-shell-test-',
      );
      addTearDown(() async {
        if (await tempRoot.exists()) {
          await tempRoot.delete(recursive: true);
        }
      });

      final bridge = _FakeMobileHostBridge(
        sessionsList: <SessionRecord>[
          SessionRecord(
            id: 'session-1',
            profileId: 'profile-1',
            profileName: 'vk live',
            profile: _profileSpec(),
            state: SessionState.ready,
            startedAt: DateTime.utc(2026, 4, 7, 14, 0),
            updatedAt: DateTime.utc(2026, 4, 7, 14, 1),
          ),
        ],
      );
      final controller = MobileShellController(
        bridge: bridge,
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
        diagnosticsDirectoryProvider: () async => tempRoot,
        clock: () => DateTime.utc(2026, 4, 7, 14, 2, 3),
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.exportDiagnostics('session-1');

      final exported = await tempRoot
          .list()
          .where((FileSystemEntity entry) => entry is File)
          .cast<File>()
          .single;
      final payload = await exported.readAsString();

      expect(payload, contains('"gui_build"'));
      expect(payload, contains('"host_build"'));
      expect(payload, contains('"contract_version": "1"'));
      expect(payload, contains('mobilegui1234'));
      expect(payload, contains('embeddedhost123'));
    },
  );
}

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
}

class _FakeBrowserLauncher implements BrowserLauncher {
  final List<String> openedUrls = <String>[];

  @override
  Future<bool> open(String url) async {
    openedUrls.add(url);
    return true;
  }
}

class _FakeMobileHostBridge implements MobileHostBridge {
  _FakeMobileHostBridge({
    this.ensureReadyResult = const MobileHostConnectionResult(
      state: MobileHostLifecycleState.ready,
      message: 'Connected to embedded mobile host bridge',
      info: _readyHostInfo,
      description: 'native bridge',
    ),
    this.sessionsList = const <SessionRecord>[],
    this.challengeMap = const <String, ChallengeRecord>{},
    DiagnosticsBundle? diagnosticsBundle,
  }) : diagnosticsBundle =
           diagnosticsBundle ??
           DiagnosticsBundle(
             session: sessionsList.isEmpty
                 ? SessionRecord(
                     id: 'session-1',
                     profileId: 'profile-1',
                     profileName: 'vk live',
                     profile: _profileSpec(),
                     state: SessionState.ready,
                     startedAt: DateTime.utc(2026, 4, 7, 14, 0),
                     updatedAt: DateTime.utc(2026, 4, 7, 14, 1),
                   )
                 : sessionsList.first,
             events: const <EventRecord>[],
             challenges: challengeMap.values.toList(growable: false),
             metrics: 'vk_turn_proxy_runtime_session_starts_total 1',
             hostBuild: _testHostBuild,
             contractVersion: '1',
           );

  final MobileHostConnectionResult ensureReadyResult;
  final List<SessionRecord> sessionsList;
  final Map<String, ChallengeRecord> challengeMap;
  final DiagnosticsBundle diagnosticsBundle;

  final List<ProfileRecord> upsertedProfiles = <ProfileRecord>[];
  final List<String> continueChallengeCalls = <String>[];
  int startSessionCalls = 0;
  final StreamController<EventRecord> _events =
      StreamController<EventRecord>.broadcast();

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
    continueChallengeCalls.add(challengeId);
    return challengeMap[challengeId]!;
  }

  @override
  Future<void> deleteProfile(String profileId) async {}

  @override
  Future<DiagnosticsBundle> diagnostics(String sessionId) async {
    return diagnosticsBundle;
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }

  @override
  Future<MobileHostConnectionResult> ensureReady() async => ensureReadyResult;

  @override
  Stream<EventRecord> events() => _events.stream;

  @override
  Future<HostInfo> hostInfo() async => ensureReadyResult.info ?? _readyHostInfo;

  @override
  Future<HostInfo> negotiate({
    required List<String> supportedVersions,
    required List<Capability> requiredCapabilities,
  }) async {
    final info = ensureReadyResult.info;
    if (ensureReadyResult.state == MobileHostLifecycleState.incompatible ||
        info == null) {
      throw const ControlPlaneError(
        statusCode: 409,
        code: 'incompatible_host',
        message: 'contract mismatch',
      );
    }
    return info;
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
    startSessionCalls += 1;
    return sessionsList.first;
  }

  @override
  Future<SessionRecord> stopSession(String sessionId) async =>
      sessionsList.first;

  @override
  Future<ProfileRecord> upsertProfile(ProfileRecord profile) async {
    upsertedProfiles.add(profile);
    return profile;
  }
}
