import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/mobile_handoff_adapter.dart';
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
    Capability.platformTunnels,
    Capability.profiles,
    Capability.providerConfigs,
    Capability.providerRuntimeArtifacts,
    Capability.runtimeExecutionPlanning,
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
      message: 'mobile host does not implement tunnel startup yet',
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
    capabilityHints: ProviderCapabilityHints(
      potentialActions: <ArtifactAction>[
        ArtifactAction.startOnThisDevice,
        ArtifactAction.exportHandoff,
      ],
      redactionPolicy: ArtifactRedactionPolicy(
        ordinaryReads: 'summary_only',
        events: 'summary_only',
        diagnostics: 'summary_only',
        persistedState: 'summary_only',
      ),
    ),
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
    capabilityHints: ProviderCapabilityHints(
      potentialActions: <ArtifactAction>[
        ArtifactAction.startOnThisDevice,
        ArtifactAction.exportHandoff,
      ],
      redactionPolicy: ArtifactRedactionPolicy(
        ordinaryReads: 'summary_only',
        events: 'summary_only',
        diagnostics: 'summary_only',
        persistedState: 'summary_only',
      ),
    ),
  ),
];

const ProviderDescriptor _providerWithSettingsDescriptor = ProviderDescriptor(
  id: 'wb-stream',
  displayName: 'WB Stream',
  description: 'Descriptor-driven provider settings test fixture.',
  inputKind: ProviderInputKind.link,
  authPosture: ProviderAuthPosture.account,
  browserPolicy: ProviderBrowserPolicy.notRequired,
  artifactFamilies: <ArtifactFamily>[ArtifactFamily.genericTurn],
  settingsSchema: ProviderSettingsSchema(
    type: 'object',
    additionalProperties: false,
    requiredKeys: <String>['region', 'device_pin'],
    order: <String>['region', 'device_pin'],
    properties: <String, ProviderSettingProperty>{
      'region': ProviderSettingProperty(
        type: ProviderSettingType.string,
        title: 'Region',
        enumValues: <dynamic>['ru-central', 'eu-west'],
        defaultValue: 'ru-central',
        control: ProviderSettingControl.select,
        persistence: ProviderSettingPersistence.profile,
      ),
      'device_pin': ProviderSettingProperty(
        type: ProviderSettingType.string,
        title: 'Device PIN',
        writeOnly: true,
        control: ProviderSettingControl.password,
        persistence: ProviderSettingPersistence.ephemeral,
      ),
    },
  ),
);

const ProviderDescriptor _unsupportedProviderSettingsDescriptor =
    ProviderDescriptor(
      id: 'unsupported-provider',
      displayName: 'Unsupported provider',
      description: 'Schema with unsupported persistent secret settings.',
      inputKind: ProviderInputKind.link,
      authPosture: ProviderAuthPosture.account,
      browserPolicy: ProviderBrowserPolicy.notRequired,
      artifactFamilies: <ArtifactFamily>[ArtifactFamily.genericTurn],
      settingsSchema: ProviderSettingsSchema(
        type: 'object',
        additionalProperties: false,
        properties: <String, ProviderSettingProperty>{
          'device_pin': ProviderSettingProperty(
            type: ProviderSettingType.string,
            title: 'Device PIN',
            writeOnly: true,
            control: ProviderSettingControl.password,
            persistence: ProviderSettingPersistence.profile,
          ),
        },
      ),
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
            providerConfigs: const <ProviderConfigRecord>[],
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
    'controller restores persisted managed providers locally and preserves managed profile mode',
    () async {
      final restoredAt = DateTime.utc(2026, 4, 13, 10, 15);
      final bridge = _FakeMobileHostBridge(
        providersList: const <ProviderDescriptor>[
          ProviderDescriptor(
            id: 'vk',
            displayName: 'VK Calls',
            inputKind: ProviderInputKind.link,
            authPosture: ProviderAuthPosture.guestOrAccount,
            browserPolicy: ProviderBrowserPolicy.externalRequired,
            artifactFamilies: <ArtifactFamily>[ArtifactFamily.genericTurn],
          ),
        ],
      );
      final profile = ProfileRecord(
        id: 'profile-1',
        name: 'legacy managed profile',
        spec: const ProfileSpec(
          provider: 'generic-turn',
          link: '',
          listenAddress: '127.0.0.1:9001',
          peerAddress: '127.0.0.1:56000',
        ),
      );
      final controller = MobileShellController(
        bridge: bridge,
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: <ProfileRecord>[profile],
            providerConfigs: <ProviderConfigRecord>[
              ProviderConfigRecord(
                id: 'cfg-1',
                provider: 'generic-turn',
                name: 'Legacy managed provider',
                providerSettings: const <String, dynamic>{},
                createdAt: restoredAt,
                updatedAt: restoredAt,
              ),
            ],
            profileBindings: const <String, ProfileProviderBinding>{
              'profile-1': ProfileProviderBinding(
                mode: ProfileProviderMode.managed,
                managedProviderId: 'cfg-1',
              ),
            },
            selectedProfileId: profile.id,
            draft: ProfileDraft.fromProfile(
              profile,
              providerBinding: const ProfileProviderBinding(
                mode: ProfileProviderMode.managed,
                managedProviderId: 'cfg-1',
              ),
            ),
          ),
        ),
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(bridge.restoredProviderConfigs, isEmpty);
      expect(bridge.upsertedProviderConfigs, isEmpty);
      expect(controller.providerConfigs, hasLength(1));
      expect(
        controller.providerConfigs.single.availability.state,
        ProviderConfigAvailabilityState.providerUnavailable,
      );
      controller.selectProfile('profile-1');
      expect(controller.draft.providerBinding.isManaged, isTrue);
      expect(controller.draft.providerBinding.managedProviderId, 'cfg-1');
    },
  );

  test(
    'controller fails closed when secure local state restore is unavailable',
    () async {
      final bridge = _FakeMobileHostBridge();
      final controller = MobileShellController(
        bridge: bridge,
        stateStore: _ThrowingStateStore(
          StateError(
            'Secure profile secrets are unavailable. Restore secure storage or clear the saved mobile shell state.',
          ),
        ),
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(controller.status, ShellStatus.blocked);
      expect(controller.requiresLocalStateReset, isTrue);
      expect(controller.hostConnection?.state, MobileHostLifecycleState.failed);
      expect(
        controller.notice,
        contains('Secure profile secrets are unavailable'),
      );
      expect(bridge.ensureReadyCalls, 0);
    },
  );

  test(
    'controller can clear local state and reconnect after restore failure',
    () async {
      final bridge = _FakeMobileHostBridge();
      final stateStore = _RecoverableThrowingStateStore(
        StateError(
          'Secure profile secrets are unavailable. Restore secure storage or clear the saved mobile shell state.',
        ),
      );
      final controller = MobileShellController(
        bridge: bridge,
        stateStore: stateStore,
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.clearLocalState();

      expect(stateStore.clearCalls, 1);
      expect(controller.requiresLocalStateReset, isFalse);
      expect(controller.status, ShellStatus.ready);
      expect(controller.hostConnection?.isReady, isTrue);
      expect(bridge.ensureReadyCalls, 1);
      expect(controller.profiles, isEmpty);
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
            capabilities: <Capability>[
              Capability.mobileHostBridge,
              Capability.platformTunnels,
            ],
            platformTunnels: <PlatformTunnelCapability>[
              PlatformTunnelCapability(
                mode: PlatformTunnelMode.androidVpnService,
                available: false,
                missingPrerequisite:
                    PlatformTunnelPrerequisite.hostImplementation,
              ),
            ],
          ),
          description: 'native bridge',
        ),
      );
      final controller = MobileShellController(
        bridge: bridge,
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: <ProfileRecord>[profile],
            providerConfigs: const <ProviderConfigRecord>[],
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
    'controller preserves incompatible state when a ready bridge later fails closed',
    () async {
      final bridge = _FakeMobileHostBridge(
        sessionsList: <SessionRecord>[
          SessionRecord(
            id: 'session-1',
            profileId: 'profile-1',
            profileName: 'vk live',
            profile: _profileSpec(),
            state: SessionState.starting,
            startedAt: DateTime.utc(2026, 4, 7, 14, 0),
            updatedAt: DateTime.utc(2026, 4, 7, 14, 1),
          ),
        ],
        startSessionError: const ControlPlaneError(
          statusCode: 409,
          code: 'incompatible_host',
          message: 'native bridge contract drifted',
        ),
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
            providerConfigs: const <ProviderConfigRecord>[],
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
      expect(controller.notice, contains('contract drifted'));
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
            providerConfigs: const <ProviderConfigRecord>[],
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
    'controller auto-continues an eligible challenge once on app resume',
    () async {
      final challenge = ChallengeRecord(
        id: 'challenge-auto',
        sessionId: 'session-1',
        provider: 'vk',
        stage: 'provider_resolve',
        kind: 'browser',
        prompt: 'Return after browser.',
        openUrl: 'https://vk.com/call/join/test',
        status: ChallengeStatus.pending,
        completionMode: ChallengeCompletionMode.appReturnCallback,
        browserReturn: const ChallengeBrowserReturnMetadata(
          signalKinds: <BrowserReturnSignalKind>[
            BrowserReturnSignalKind.foregroundResume,
          ],
          allowAutoContinue: true,
        ),
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
            providerConfigs: const <ProviderConfigRecord>[],
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
      await controller.openChallengeInBrowser(challenge);

      controller.onAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bridge.continueChallengeCalls, <String>[challenge.id]);
      expect(controller.notice, contains('browser return on app resume'));

      controller.onAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(bridge.continueChallengeCalls, <String>[challenge.id]);
    },
  );

  test(
    'controller keeps manual fallback for manual-confirm challenges on app resume',
    () async {
      final challenge = ChallengeRecord(
        id: 'challenge-manual',
        sessionId: 'session-1',
        provider: 'vk',
        stage: 'provider_resolve',
        kind: 'browser',
        prompt: 'Return after browser.',
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
            providerConfigs: const <ProviderConfigRecord>[],
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
      await controller.openChallengeInBrowser(challenge);

      controller.onAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bridge.continueChallengeCalls, isEmpty);
    },
  );

  test(
    'controller auto-continues only on matching native browser-return callback',
    () async {
      final challenge = ChallengeRecord(
        id: 'challenge-link',
        sessionId: 'session-1',
        provider: 'vk',
        stage: 'provider_resolve',
        kind: 'browser',
        prompt: 'Return after browser.',
        openUrl: 'https://vk.com/call/join/test',
        status: ChallengeStatus.pending,
        completionMode: ChallengeCompletionMode.appReturnCallback,
        browserReturn: const ChallengeBrowserReturnMetadata(
          signalKinds: <BrowserReturnSignalKind>[
            BrowserReturnSignalKind.appLink,
          ],
          allowAutoContinue: true,
          expectedReturnUri: 'https://app.example.test/mobile-return',
        ),
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
            providerConfigs: const <ProviderConfigRecord>[],
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
      await controller.openChallengeInBrowser(challenge);

      bridge.emitBrowserReturnSignal(
        const MobileBrowserReturnSignal(
          kind: BrowserReturnSignalKind.appLink,
          uri: 'https://app.example.test/other-return',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(bridge.continueChallengeCalls, isEmpty);

      bridge.emitBrowserReturnSignal(
        const MobileBrowserReturnSignal(
          kind: BrowserReturnSignalKind.appLink,
          uri: 'https://app.example.test/mobile-return?code=1',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(bridge.continueChallengeCalls, <String>[challenge.id]);
    },
  );

  test('controller submits owned-browser continuation payloads', () async {
    final challenge = ChallengeRecord(
      id: 'challenge-owned',
      sessionId: 'session-1',
      provider: 'vk',
      stage: 'provider_resolve',
      kind: 'browser',
      prompt: 'Continue in the app-owned browser.',
      openUrl: 'https://vk.com/call/join/test',
      status: ChallengeStatus.pending,
      completionMode: ChallengeCompletionMode.ownedBrowserObserved,
      ownedBrowser: const ChallengeOwnedBrowserMetadata(
        cookieUrls: <String>['https://login.vk.ru/'],
      ),
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
          providerConfigs: const <ProviderConfigRecord>[],
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
      appBuild: _testGuiBuild,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.continueOwnedBrowserChallenge(
      challenge.id,
      ChallengeContinuationSubmission(
        cookies: const <BrowserCookieRecord>[
          BrowserCookieRecord(
            name: 'session',
            value: 'owned-session',
            domain: 'login.vk.ru',
            path: '/',
          ),
        ],
      ),
    );

    expect(bridge.continueChallengeCalls, <String>[challenge.id]);
    expect(bridge.continueChallengePayloads, hasLength(1));
    expect(
      bridge.continueChallengePayloads.single?.cookies.single.name,
      'session',
    );
    expect(
      bridge.continueChallengePayloads.single?.cookies.single.value,
      'owned-session',
    );
    expect(
      controller.notice,
      contains('Completed the in-app browser continuation'),
    );
  });

  test(
    'controller allows fail-closed cancel notices for owned-browser paths',
    () async {
      final challenge = ChallengeRecord(
        id: 'challenge-owned',
        sessionId: 'session-1',
        provider: 'vk',
        stage: 'provider_resolve',
        kind: 'browser',
        prompt: 'Continue in the app-owned browser.',
        openUrl: 'https://vk.com/call/join/test',
        status: ChallengeStatus.pending,
        completionMode: ChallengeCompletionMode.ownedBrowserObserved,
        ownedBrowser: const ChallengeOwnedBrowserMetadata(
          cookieUrls: <String>['https://login.vk.ru/'],
        ),
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
            providerConfigs: const <ProviderConfigRecord>[],
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
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.cancelChallenge(
        challenge.id,
        noticeOverride:
            'In-app browser continuation failed: embedded cookies missing. Marked challenge ${challenge.id} as cancelled.',
      );

      expect(bridge.cancelChallengeCalls, <String>[challenge.id]);
      expect(controller.notice, contains('In-app browser continuation failed'));
      expect(
        controller.notice,
        contains('Marked challenge ${challenge.id} as cancelled.'),
      );
    },
  );

  test(
    'controller sorts sessions newest first and auto-selects the latest active session',
    () async {
      final bridge = _FakeMobileHostBridge(
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
            startedAt: DateTime.utc(2026, 4, 7, 14, 0),
            updatedAt: DateTime.utc(2026, 4, 7, 14, 1),
            stoppedAt: DateTime.utc(2026, 4, 7, 14, 1),
          ),
          SessionRecord(
            id: 'session-ready',
            profileId: 'profile-1',
            profileName: 'newer ready',
            profile: _profileSpec(),
            state: SessionState.ready,
            startedAt: DateTime.utc(2026, 4, 7, 14, 2),
            updatedAt: DateTime.utc(2026, 4, 7, 14, 3),
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
            providerConfigs: const <ProviderConfigRecord>[],
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
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(
        controller.sessions.map((SessionRecord session) => session.id).toList(),
        <String>['session-ready', 'session-failed'],
      );
      expect(controller.selectedSessionId, 'session-ready');
    },
  );

  test(
    'controller opens shell-external conference-room actions from typed artifact summaries',
    () async {
      final bridge = _FakeMobileHostBridge(
        resolutionsList: <ResolutionRecord>[_conferenceRoomResolutionRecord()],
      );
      final browser = _FakeBrowserLauncher();
      final controller = MobileShellController(
        bridge: bridge,
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: const <ProfileRecord>[],
            providerConfigs: const <ProviderConfigRecord>[],
            draft: ProfileDraft.defaults(),
          ),
        ),
        browserLauncher: browser,
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.openResolutionExternalAction(
        controller.resolutions.single.id,
        ArtifactAction.openRoom,
      );

      expect(browser.openedUrls, <String>[
        'https://room.example.test/rooms/team-sync',
      ]);
      expect(controller.notice, contains('Opened room'));
    },
  );

  test(
    'controller materializes typed same-device actions with draft runtime defaults',
    () async {
      final bridge = _FakeMobileHostBridge(
        resolutionsList: <ResolutionRecord>[_resolutionRecord()],
        sessionsList: <SessionRecord>[
          SessionRecord(
            id: 'materialized-session',
            profileId: '',
            profileName: 'materialized',
            sourceResolutionId: 'resolution-1',
            profile: _profileSpec().copyWith(provider: 'generic-turn'),
            state: SessionState.ready,
            startedAt: DateTime.utc(2026, 4, 10, 12, 2),
            updatedAt: DateTime.utc(2026, 4, 10, 12, 3),
          ),
        ],
      );
      final controller = MobileShellController(
        bridge: bridge,
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: const <ProfileRecord>[],
            providerConfigs: const <ProviderConfigRecord>[],
            draft: ProfileDraft.defaults(),
          ),
        ),
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      controller.updateDraft(
        controller.draft.copyWith(
          spec: controller.draft.spec.copyWith(
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

      await controller.materializeResolution('resolution-1');

      expect(bridge.materializeResolutionCalls, <String>['resolution-1']);
      expect(bridge.materializeResolutionDefaults, hasLength(1));
      expect(
        bridge.materializeResolutionDefaults.single.listenAddress,
        '127.0.0.1:9101',
      );
      expect(
        bridge.materializeResolutionDefaults.single.peerAddress,
        '127.0.0.1:56100',
      );
      expect(
        bridge.materializeResolutionDefaults.single.turnServer,
        'override.example.test',
      );
      expect(bridge.materializeResolutionDefaults.single.turnPort, '5349');
      expect(
        bridge.materializeResolutionDefaults.single.bindInterface,
        '127.0.0.1',
      );
      expect(
        bridge.materializeResolutionDefaults.single.mode,
        TransportMode.udp,
      );
      expect(bridge.materializeResolutionDefaults.single.useDtls, isFalse);
      expect(bridge.materializeResolutionDefaults.single.logLevel, 'debug');
      expect(controller.selectedSessionId, 'materialized-session');
      expect(controller.notice, contains('Started mobile session'));
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
            providerConfigs: const <ProviderConfigRecord>[],
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

  test(
    'controller starts resolutions and exports copied and shared handoff links',
    () async {
      final bridge = _FakeMobileHostBridge(
        resolutionsList: const <ResolutionRecord>[],
      );
      final handoff = _FakeMobileHandoffAdapter();
      final controller = MobileShellController(
        bridge: bridge,
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: const <ProfileRecord>[],
            providerConfigs: const <ProviderConfigRecord>[],
            draft: ProfileDraft.defaults(),
          ),
        ),
        handoffAdapter: handoff,
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      controller.updateDraft(
        controller.draft.copyWith(
          spec: controller.draft.spec.copyWith(
            provider: 'vk',
            link: 'https://vk.com/call/join/fresh',
            interactiveProvider: true,
          ),
        ),
      );

      await controller.startResolutionFromDraft();
      expect(bridge.startResolutionCalls, hasLength(1));
      expect(bridge.startResolutionCalls.single.provider, 'vk');
      expect(
        bridge.startResolutionCalls.single.input.kind,
        ProviderInputKind.link,
      );
      expect(
        bridge.startResolutionCalls.single.input.link,
        'https://vk.com/call/join/fresh',
      );
      expect(controller.resolutions, hasLength(1));

      final resolutionID = controller.resolutions.single.id;
      await controller.copyResolutionExport(resolutionID);
      await controller.shareResolutionExport(resolutionID);

      expect(handoff.copiedLinks, <String>[
        'generic-turn://turn-user:turn-pass@turn.example.test:3478',
      ]);
      expect(handoff.sharedLinks, <String>[
        'generic-turn://turn-user:turn-pass@turn.example.test:3478',
      ]);
      expect(controller.selectedResolutionId, resolutionID);
      expect(controller.notice, contains('Shared handoff link'));
    },
  );

  test(
    'controller fails closed when the mobile host does not advertise the provider',
    () async {
      final bridge = _FakeMobileHostBridge(
        providersList: const <ProviderDescriptor>[],
        resolutionsList: const <ResolutionRecord>[],
      );
      final controller = MobileShellController(
        bridge: bridge,
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: const <ProfileRecord>[],
            providerConfigs: const <ProviderConfigRecord>[],
            draft: ProfileDraft.defaults(),
          ),
        ),
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.startResolutionFromDraft();

      expect(bridge.startResolutionCalls, isEmpty);
      expect(
        controller.notice,
        contains('not advertised by the connected mobile host'),
      );
    },
  );

  test(
    'controller sends provider settings for mobile resolution and stores only profile-retained values',
    () async {
      final bridge = _FakeMobileHostBridge(
        providersList: const <ProviderDescriptor>[
          _providerWithSettingsDescriptor,
        ],
        resolutionsList: const <ResolutionRecord>[],
      );
      final controller = MobileShellController(
        bridge: bridge,
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: const <ProfileRecord>[],
            providerConfigs: const <ProviderConfigRecord>[],
            draft: ProfileDraft.defaults(),
          ),
        ),
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      controller.updateDraft(
        controller.draft.copyWith(
          spec: controller.draft.spec.copyWith(
            provider: 'wb-stream',
            link: 'https://wb.example.test/invite/abc',
            providerSettings: <String, dynamic>{
              'region': 'eu-west',
              'device_pin': '123456',
            },
          ),
        ),
      );

      await controller.startResolutionFromDraft();
      expect(bridge.startResolutionCalls, hasLength(1));
      expect(
        bridge.startResolutionCalls.single.providerSettings,
        <String, dynamic>{'region': 'eu-west', 'device_pin': '123456'},
      );

      await controller.saveDraft();
      expect(bridge.upsertedProfiles, hasLength(1));
      expect(
        bridge.upsertedProfiles.single.spec.providerSettings,
        <String, dynamic>{'region': 'eu-west'},
      );
    },
  );

  test(
    'controller fails closed on unsupported mobile provider settings schema',
    () async {
      final bridge = _FakeMobileHostBridge(
        providersList: const <ProviderDescriptor>[
          _unsupportedProviderSettingsDescriptor,
        ],
        resolutionsList: const <ResolutionRecord>[],
      );
      final controller = MobileShellController(
        bridge: bridge,
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: const <ProfileRecord>[],
            providerConfigs: const <ProviderConfigRecord>[],
            draft: ProfileDraft.defaults(),
          ),
        ),
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      controller.updateDraft(
        controller.draft.copyWith(
          spec: controller.draft.spec.copyWith(
            provider: 'unsupported-provider',
            link: 'https://example.test/invite/abc',
          ),
        ),
      );

      await controller.startResolutionFromDraft();

      expect(bridge.startResolutionCalls, isEmpty);
      expect(controller.notice, contains('cannot render provider settings'));
    },
  );

  test(
    'controller defaults to the first advertised provider instead of a hard-coded VK flow',
    () async {
      final bridge = _FakeMobileHostBridge(
        providersList: <ProviderDescriptor>[
          _providerDescriptors[1],
          _providerDescriptors[0],
        ],
      );
      final controller = MobileShellController(
        bridge: bridge,
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: const <ProfileRecord>[],
            providerConfigs: const <ProviderConfigRecord>[],
            draft: ProfileDraft.defaults(),
          ),
        ),
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(controller.draft.spec.provider, 'generic-turn');
      expect(controller.draft.spec.interactiveProvider, isFalse);
    },
  );

  test(
    'controller restores mobile resolution challenge details during refresh',
    () async {
      final challenge = ChallengeRecord(
        id: 'challenge-resolution-1',
        sessionId: '',
        resolutionId: 'resolution-1',
        provider: 'vk',
        stage: 'provider_resolve',
        kind: 'browser',
        prompt: 'continue in browser',
        openUrl: 'https://vk.com/call/join/test',
        status: ChallengeStatus.pending,
        createdAt: DateTime.utc(2026, 4, 7, 13, 0),
        updatedAt: DateTime.utc(2026, 4, 7, 13, 1),
      );
      final bridge = _FakeMobileHostBridge(
        resolutionsList: <ResolutionRecord>[
          _resolutionRecord(activeChallengeId: challenge.id),
        ],
        challengeMap: <String, ChallengeRecord>{challenge.id: challenge},
      );
      final controller = MobileShellController(
        bridge: bridge,
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: const <ProfileRecord>[],
            providerConfigs: const <ProviderConfigRecord>[],
            draft: ProfileDraft.defaults(),
          ),
        ),
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(
        controller
            .activeChallengeForResolution(controller.resolutions.single)
            ?.id,
        challenge.id,
      );
    },
  );

  test(
    'controller consumes typed platform tunnel reports and startup-stage results',
    () async {
      final bridge = _FakeMobileHostBridge();
      final controller = MobileShellController(
        bridge: bridge,
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: const <ProfileRecord>[],
            providerConfigs: const <ProviderConfigRecord>[],
            draft: ProfileDraft.defaults(),
          ),
        ),
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.startPlatformTunnel(
        PlatformTunnelMode.androidVpnService,
      );

      expect(bridge.startedPlatformTunnels, <PlatformTunnelMode>[
        PlatformTunnelMode.androidVpnService,
      ]);
      expect(
        controller.platformTunnels.single.mode,
        PlatformTunnelMode.androidVpnService,
      );
      expect(
        controller
            .platformTunnelResultFor(PlatformTunnelMode.androidVpnService)
            ?.stage,
        PlatformTunnelStartupStage.capabilityCheck,
      );
      expect(controller.notice, contains('Capability check'));
    },
  );

  test(
    'controller clears platform tunnel startup results when the bridge later fails closed',
    () async {
      final bridge = _FakeMobileHostBridge(
        sessionsList: <SessionRecord>[
          SessionRecord(
            id: 'session-1',
            profileId: 'profile-1',
            profileName: 'vk live',
            profile: _profileSpec(),
            state: SessionState.starting,
            startedAt: DateTime.utc(2026, 4, 7, 14, 0),
            updatedAt: DateTime.utc(2026, 4, 7, 14, 1),
          ),
        ],
        startSessionError: const ControlPlaneError(
          statusCode: 409,
          code: 'incompatible_host',
          message: 'native bridge contract drifted',
        ),
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
            providerConfigs: const <ProviderConfigRecord>[],
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
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.startPlatformTunnel(
        PlatformTunnelMode.androidVpnService,
      );
      expect(
        controller.platformTunnelResultFor(
          PlatformTunnelMode.androidVpnService,
        ),
        isNotNull,
      );

      await controller.startSelectedProfile();

      expect(controller.status, ShellStatus.blocked);
      expect(
        controller.platformTunnelResultFor(
          PlatformTunnelMode.androidVpnService,
        ),
        isNull,
      );
      expect(
        controller.hostConnection?.state,
        MobileHostLifecycleState.incompatible,
      );
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

  @override
  Future<void> clear() async {}
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
    List<ProviderDescriptor>? providersList,
    List<ProviderConfigRecord>? providerConfigsList,
    List<ResolutionRecord>? resolutionsList,
    this.sessionsList = const <SessionRecord>[],
    this.challengeMap = const <String, ChallengeRecord>{},
    this.startSessionError,
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
           ),
       _providers = List<ProviderDescriptor>.of(
         providersList ?? _providerDescriptors,
       ),
       _providerConfigs = List<ProviderConfigRecord>.of(
         providerConfigsList ?? const <ProviderConfigRecord>[],
       ),
       _resolutions = List<ResolutionRecord>.of(
         resolutionsList ?? const <ResolutionRecord>[],
       );

  final MobileHostConnectionResult ensureReadyResult;
  final List<ProviderDescriptor> _providers;
  final List<ProviderConfigRecord> _providerConfigs;
  final List<SessionRecord> sessionsList;
  final Map<String, ChallengeRecord> challengeMap;
  final ControlPlaneError? startSessionError;
  final DiagnosticsBundle diagnosticsBundle;
  final List<ResolutionRecord> _resolutions;

  final List<ProfileRecord> upsertedProfiles = <ProfileRecord>[];
  final List<ProviderConfigRecord> upsertedProviderConfigs =
      <ProviderConfigRecord>[];
  final List<ProviderConfigRecord> restoredProviderConfigs =
      <ProviderConfigRecord>[];
  final List<String> continueChallengeCalls = <String>[];
  final List<String> cancelChallengeCalls = <String>[];
  final List<ChallengeContinuationSubmission?> continueChallengePayloads =
      <ChallengeContinuationSubmission?>[];
  final List<_StartResolutionCall> startResolutionCalls =
      <_StartResolutionCall>[];
  final List<String> materializeResolutionCalls = <String>[];
  final List<RuntimeDefaults> materializeResolutionDefaults =
      <RuntimeDefaults>[];
  final List<PlatformTunnelMode> startedPlatformTunnels =
      <PlatformTunnelMode>[];
  int ensureReadyCalls = 0;
  int startSessionCalls = 0;
  final StreamController<EventRecord> _events =
      StreamController<EventRecord>.broadcast();
  final StreamController<MobileBrowserReturnSignal> _browserReturnSignals =
      StreamController<MobileBrowserReturnSignal>.broadcast();

  @override
  Stream<MobileBrowserReturnSignal> get browserReturnSignals =>
      _browserReturnSignals.stream;

  @override
  Future<ChallengeRecord> cancelChallenge(String challengeId) async {
    cancelChallengeCalls.add(challengeId);
    final challenge = challengeMap[challengeId]!;
    return challenge.copyWith(
      status: ChallengeStatus.cancelled,
      updatedAt: challenge.updatedAt.add(const Duration(seconds: 1)),
    );
  }

  @override
  Future<ChallengeRecord> challenge(String challengeId) async {
    return challengeMap[challengeId]!;
  }

  @override
  Future<ChallengeRecord> continueChallenge(
    String challengeId, {
    ChallengeContinuationSubmission? browserContinuation,
  }) async {
    continueChallengeCalls.add(challengeId);
    continueChallengePayloads.add(browserContinuation);
    return challengeMap[challengeId]!;
  }

  @override
  Future<ResolutionRecord> cancelResolution(String resolutionId) async {
    return _resolutionRecord(
      id: resolutionId,
      state: ResolutionState.cancelled,
    );
  }

  @override
  Future<void> deleteProfile(String profileId) async {}

  @override
  Future<void> deleteProviderConfig(String configId) async {
    _providerConfigs.removeWhere(
      (ProviderConfigRecord config) => config.id == configId,
    );
  }

  @override
  Future<DiagnosticsBundle> diagnostics(String sessionId) async {
    return diagnosticsBundle;
  }

  @override
  Future<void> dispose() async {
    await _browserReturnSignals.close();
    await _events.close();
  }

  void emitBrowserReturnSignal(MobileBrowserReturnSignal signal) {
    _browserReturnSignals.add(signal);
  }

  @override
  Future<MobileHostConnectionResult> ensureReady() async {
    ensureReadyCalls += 1;
    return ensureReadyResult;
  }

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
    RuntimeExecutionPlan? executionPlan,
    PlatformTunnelApplicationRoutingPolicy applicationRoutingPolicy =
        PlatformTunnelApplicationRoutingPolicy.allApps,
    List<String> allowedPackages = const <String>[],
    List<String> disallowedPackages = const <String>[],
  }) async {
    startedPlatformTunnels.add(mode);
    return const PlatformTunnelStartResult(
      mode: PlatformTunnelMode.androidVpnService,
      ready: false,
      stage: PlatformTunnelStartupStage.capabilityCheck,
      missingPrerequisite: PlatformTunnelPrerequisite.hostImplementation,
      message: 'mobile host does not implement tunnel startup yet',
    );
  }

  @override
  Future<PlatformTunnelStartResult> resumePlatformTunnel({
    required String startupAttemptId,
  }) async {
    return PlatformTunnelStartResult(
      mode: PlatformTunnelMode.androidVpnService,
      ready: false,
      stage: PlatformTunnelStartupStage.permissionAcquire,
      missingPrerequisite: PlatformTunnelPrerequisite.permission,
      startupAttemptId: startupAttemptId,
      message: 'mobile host does not implement tunnel resume yet',
    );
  }

  @override
  Future<List<ProviderDescriptor>> providers() async => _providers;

  @override
  Future<List<ProviderConfigRecord>> providerConfigs() async =>
      _providerConfigs;

  @override
  Future<List<ProfileRecord>> profiles() async => const <ProfileRecord>[];

  @override
  Future<List<ResolutionRecord>> resolutions() async => _resolutions;

  @override
  Future<ResolutionRecord> startResolution({
    required String provider,
    required ProviderInputEnvelope input,
    Map<String, dynamic> providerSettings = const <String, dynamic>{},
  }) async {
    startResolutionCalls.add(
      _StartResolutionCall(
        provider: provider,
        input: input,
        providerSettings: providerSettings,
      ),
    );
    final resolution = _resolutionRecord(
      id: 'resolution-${startResolutionCalls.length}',
      provider: provider,
      linkRedacted: input.link,
    );
    _resolutions
      ..clear()
      ..add(resolution);
    return resolution;
  }

  @override
  Future<List<SessionRecord>> sessions() async => sessionsList;

  @override
  Future<SessionRecord> startSession({
    String? profileId,
    ProfileSpec? spec,
  }) async {
    startSessionCalls += 1;
    if (startSessionError != null) {
      throw startSessionError!;
    }
    return sessionsList.first;
  }

  @override
  Future<SessionRecord> stopSession(String sessionId) async =>
      sessionsList.first;

  @override
  Future<SessionRecord> materializeResolution({
    required String resolutionId,
    required RuntimeDefaults runtimeDefaults,
    RuntimeExecutionPlan? executionPlan,
  }) async {
    materializeResolutionCalls.add(resolutionId);
    materializeResolutionDefaults.add(runtimeDefaults);
    return sessionsList.first;
  }

  @override
  Future<ProfileRecord> upsertProfile(ProfileRecord profile) async {
    upsertedProfiles.add(profile);
    return profile;
  }

  @override
  Future<ProviderConfigRecord> upsertProviderConfig(
    ProviderConfigRecord config,
  ) async {
    if (!_providerAdvertised(config.provider)) {
      throw const ControlPlaneError(
        statusCode: 400,
        code: 'provider_config_invalid',
        message: 'provider is not advertised by the connected host',
      );
    }
    final next = config.copyWith(
      id: config.id.isEmpty
          ? 'provider-config-${_providerConfigs.length + 1}'
          : config.id,
      createdAt: config.createdAt.millisecondsSinceEpoch == 0
          ? DateTime.utc(2026, 4, 12, 18, 0)
          : config.createdAt,
      updatedAt: DateTime.utc(2026, 4, 12, 18, 1),
    );
    _providerConfigs
      ..removeWhere((ProviderConfigRecord current) => current.id == next.id)
      ..add(next);
    upsertedProviderConfigs.add(next);
    return next;
  }

  @override
  Future<ProviderConfigRecord> restoreProviderConfig(
    ProviderConfigRecord config,
  ) async {
    final next = config.copyWith(
      availability: _providerAdvertised(config.provider)
          ? const ProviderConfigAvailability()
          : ProviderConfigAvailability(
              state: ProviderConfigAvailabilityState.providerUnavailable,
              message:
                  'provider "${config.provider}" is not advertised by the current host',
            ),
    );
    _providerConfigs
      ..removeWhere((ProviderConfigRecord current) => current.id == next.id)
      ..add(next);
    restoredProviderConfigs.add(next);
    return next;
  }

  bool _providerAdvertised(String providerId) {
    final normalized = providerId.trim().toLowerCase();
    return _providers.any(
      (ProviderDescriptor descriptor) =>
          descriptor.id.trim().toLowerCase() == normalized,
    );
  }
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

class _FakeMobileHandoffAdapter implements MobileHandoffAdapter {
  final List<String> copiedLinks = <String>[];
  final List<String> sharedLinks = <String>[];

  @override
  Future<void> copyLink(String link) async {
    copiedLinks.add(link);
  }

  @override
  Future<void> shareLink(String link) async {
    sharedLinks.add(link);
  }
}

class _RecoverableThrowingStateStore implements MobileShellStateStore {
  _RecoverableThrowingStateStore(this.error);

  Object? error;
  int clearCalls = 0;

  @override
  Future<void> clear() async {
    clearCalls += 1;
    error = null;
  }

  @override
  Future<MobileShellState?> load() async {
    if (error != null) {
      throw error!;
    }
    return null;
  }

  @override
  Future<void> save(MobileShellState state) async {}
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
      kind: ProviderInputKind.link,
      linkRedacted: linkRedacted,
      interactiveProvider: provider == 'vk',
    ),
    state: state,
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
      summary: ResolutionArtifactSummary(
        genericTurn: ResolutionCredentials(
          address: 'turn.example.test:3478',
          usernameRedacted: '<redacted:turn-username>',
          passwordRedacted: '<redacted:turn-password>',
        ),
      ),
    ),
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

ResolutionRecord _conferenceRoomResolutionRecord({
  String id = 'resolution-room-1',
}) {
  return ResolutionRecord(
    id: id,
    provider: 'roomy',
    input: const ResolutionInput(
      provider: 'roomy',
      kind: ProviderInputKind.link,
      linkRedacted: 'https://room.example.test/join/<redacted:room-token>',
    ),
    state: ResolutionState.resolved,
    artifact: const ResolutionArtifactRecord(
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
  );
}

class _StartResolutionCall {
  const _StartResolutionCall({
    required this.provider,
    required this.input,
    required this.providerSettings,
  });

  final String provider;
  final ProviderInputEnvelope input;
  final Map<String, dynamic> providerSettings;
}
