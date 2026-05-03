import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter_shell_core/portable_profile_transfer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gui_shell/src/control/control_plane_client.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/desktop_handoff_adapter.dart';
import 'package:gui_shell/src/control/desktop_host_supervisor.dart';
import 'package:gui_shell/src/control/desktop_portable_profile_transfer_adapter.dart';
import 'package:gui_shell/src/control/desktop_shell_controller.dart';
import 'package:gui_shell/src/control/profile_draft.dart';
import 'package:gui_shell/src/control/shell_state_store.dart';

const BuildIdentity _testGuiBuild = BuildIdentity(
  product: 'RelayDock',
  version: '0.1.0',
  buildNumber: '1',
  revision: 'gui123456789',
  role: 'gui_shell',
  target: 'windows/x64',
);

const BuildIdentity _testHostBuild = BuildIdentity(
  product: 'RelayDock',
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
      mode: PlatformTunnelMode.windowsWintun,
      available: false,
      missingPrerequisite: PlatformTunnelPrerequisite.hostImplementation,
      message: 'desktop sidecar does not implement system tunnel startup yet',
    ),
  ],
);

const RuntimeExecutionPlan _windowsWintunExecutionPlan = RuntimeExecutionPlan(
  accessMethod: RuntimeAccessMethod.turnCredentials,
  carrierFamily: RuntimeCarrierFamily.turnDatagram,
  engineFamily: RuntimeEngineFamily.wireguardNative,
  hostAdapter: RuntimeHostAdapter.windowsWintun,
);

const HostInfo _readyWindowsWintunHostInfo = HostInfo(
  contractVersion: '1',
  build: _testHostBuild,
  capabilities: <Capability>[
    Capability.desktopSidecar,
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
      mode: PlatformTunnelMode.windowsWintun,
      available: true,
      satisfiedPrerequisites: <PlatformTunnelPrerequisite>[
        PlatformTunnelPrerequisite.driver,
        PlatformTunnelPrerequisite.routeExclusion,
        PlatformTunnelPrerequisite.dnsBypass,
      ],
      supportedUnderlayRoutePolicies: <PlatformTunnelUnderlayRoutePolicy>[
        PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork,
      ],
      executionPlans: <RuntimeExecutionPlanDescriptor>[
        RuntimeExecutionPlanDescriptor(
          plan: _windowsWintunExecutionPlan,
          supportState: RuntimeExecutionPlanSupportState.supported,
          remoteEndpointFamily: RuntimeRemoteEndpointFamily.turnServer,
          isDefault: true,
        ),
      ],
    ),
  ],
);

const TransportProfileStoreCapability _transportProfileStoreCapability =
    TransportProfileStoreCapability(
      supportedKinds: <TransportProfileKind>[
        TransportProfileKind.wireGuardNativeV1,
      ],
      importAdapters: <TransportProfileImportAdapterDescriptor>[
        TransportProfileImportAdapterDescriptor(
          id: TransportProfileImportAdapter.wireGuardConf,
          profileKind: TransportProfileKind.wireGuardNativeV1,
          displayName: 'WireGuard .conf',
          extensions: <String>['conf'],
          materialAcquisitionMethod:
              TransportProfileMaterialAcquisitionMethod.plainText,
        ),
      ],
      lifecycleActions: <TransportProfileLifecycleAction>[
        TransportProfileLifecycleAction.list,
        TransportProfileLifecycleAction.import,
        TransportProfileLifecycleAction.replace,
        TransportProfileLifecycleAction.forget,
        TransportProfileLifecycleAction.validate,
        TransportProfileLifecycleAction.selectForStartup,
      ],
    );

HostInfo _desktopTransportProfileHostInfo({required bool configured}) {
  final reference = configured
      ? const TransportProfileReference(
          profileId: 'transport-profile-1',
          kind: TransportProfileKind.wireGuardNativeV1,
        )
      : null;
  final prerequisite = configured
      ? TransportProfilePrerequisiteStatus(
          requiredKinds: const <TransportProfileKind>[
            TransportProfileKind.wireGuardNativeV1,
          ],
          state: TransportProfileCompatibilityState.compatible,
          selectedProfile: reference,
          defaultProfile: reference,
          importAdapters: const <TransportProfileImportAdapter>[
            TransportProfileImportAdapter.wireGuardConf,
          ],
        )
      : const TransportProfilePrerequisiteStatus(
          requiredKinds: <TransportProfileKind>[
            TransportProfileKind.wireGuardNativeV1,
          ],
          state: TransportProfileCompatibilityState.incompatible,
          missingKind: TransportProfileKind.wireGuardNativeV1,
          importAdapters: <TransportProfileImportAdapter>[
            TransportProfileImportAdapter.wireGuardConf,
          ],
          message:
              'VPN transport profile wireguard_native_v1 is not configured.',
        );
  return HostInfo(
    contractVersion: '1',
    build: _testHostBuild,
    capabilities: const <Capability>[
      Capability.desktopSidecar,
      Capability.platformTunnels,
      Capability.profiles,
      Capability.providerConfigs,
      Capability.providerRuntimeArtifacts,
      Capability.runtimeExecutionPlanning,
      Capability.sessions,
      Capability.challenges,
      Capability.diagnostics,
      Capability.eventStream,
      Capability.vpnTransportProfileStore,
      Capability.providerTransportCompatibility,
    ],
    providerTransportCompatibility:
        const ProviderTransportCompatibilityCapability(
          version: '1',
          candidateEndpoint: '/v1/provider-transport-compatibility/candidates',
        ),
    transportProfileStore: _transportProfileStoreCapability,
    platformTunnels: <PlatformTunnelCapability>[
      PlatformTunnelCapability(
        mode: PlatformTunnelMode.windowsWintun,
        available: true,
        satisfiedPrerequisites: const <PlatformTunnelPrerequisite>[
          PlatformTunnelPrerequisite.driver,
          PlatformTunnelPrerequisite.routeExclusion,
          PlatformTunnelPrerequisite.dnsBypass,
        ],
        supportedUnderlayRoutePolicies:
            const <PlatformTunnelUnderlayRoutePolicy>[
              PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork,
            ],
        executionPlans: <RuntimeExecutionPlanDescriptor>[
          RuntimeExecutionPlanDescriptor(
            plan: _windowsWintunExecutionPlan,
            supportState: configured
                ? RuntimeExecutionPlanSupportState.supported
                : RuntimeExecutionPlanSupportState.unavailable,
            remoteEndpointFamily: RuntimeRemoteEndpointFamily.turnServer,
            isDefault: true,
            requiredTransportProfileKinds: const <TransportProfileKind>[
              TransportProfileKind.wireGuardNativeV1,
            ],
            transportProfile: prerequisite,
            message: configured
                ? null
                : 'VPN transport profile wireguard_native_v1 is not configured.',
          ),
        ],
      ),
    ],
  );
}

TransportProfileStatus _desktopTransportProfileStatus() {
  return TransportProfileStatus(
    id: 'transport-profile-1',
    kind: TransportProfileKind.wireGuardNativeV1,
    version: '1',
    displayName: 'WireGuard',
    validation: const TransportProfileValidationStatus(
      state: TransportProfileValidationState.valid,
      fingerprint: 'wg:test',
    ),
    compatibility: const TransportProfileCompatibilityStatus(
      state: TransportProfileCompatibilityState.compatible,
      compatibleExecutionPlans: <RuntimeExecutionPlan>[
        _windowsWintunExecutionPlan,
      ],
    ),
    secretMaterialRef: const TransportProfileSecretMaterialRef(
      kind: TransportProfileMaterialSource.importAdapter,
      ref: 'host-owned:transport-profile-1',
    ),
    actions: const <TransportProfileLifecycleAction>[
      TransportProfileLifecycleAction.list,
      TransportProfileLifecycleAction.import,
      TransportProfileLifecycleAction.replace,
      TransportProfileLifecycleAction.forget,
      TransportProfileLifecycleAction.validate,
      TransportProfileLifecycleAction.selectForStartup,
    ],
    importedAt: DateTime.utc(2026, 4, 28, 12),
    updatedAt: DateTime.utc(2026, 4, 28, 12),
  );
}

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
        stateStore: _FakeShellStateStore(),
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
    'controller defaults to the first advertised provider instead of a hard-coded VK flow',
    () async {
      final api = _FakeControlPlaneApi(
        profiles: const <ProfileRecord>[],
        providers: <ProviderDescriptor>[
          _providerDescriptors[1],
          _providerDescriptors[0],
        ],
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
        stateStore: _FakeShellStateStore(),
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(controller.draft.spec.provider, 'generic-turn');
      expect(controller.draft.spec.interactiveProvider, isFalse);
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
          providerConfigs: const <ProviderConfigRecord>[],
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
    'controller restores persisted managed providers locally and preserves managed profile mode',
    () async {
      final restoredAt = DateTime.utc(2026, 4, 13, 10, 15);
      final api = _FakeControlPlaneApi(
        profiles: const <ProfileRecord>[],
        providers: const <ProviderDescriptor>[
          ProviderDescriptor(
            id: 'vk',
            displayName: 'VK Calls',
            inputKind: ProviderInputKind.link,
            authPosture: ProviderAuthPosture.guestOrAccount,
            browserPolicy: ProviderBrowserPolicy.externalRequired,
            artifactFamilies: <ArtifactFamily>[ArtifactFamily.genericTurn],
          ),
        ],
        sessions: const <SessionRecord>[],
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
      final store = _FakeShellStateStore(
        loaded: DesktopShellState(
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

      expect(api.restoredProviderConfigs, isEmpty);
      expect(api.upsertedProviderConfigs, isEmpty);
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
      expect(saved.draft.spec.link, '');
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
    'controller starts descriptor-driven VK resolution with browser guidance',
    () async {
      final api = _FakeControlPlaneApi(
        profiles: const <ProfileRecord>[],
        resolutions: const <ResolutionRecord>[],
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
        stateStore: _FakeShellStateStore(),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      controller.updateDraft(
        controller.draft.copyWith(
          spec: controller.draft.spec.copyWith(
            link: 'https://vk.com/call/join/fresh',
            interactiveProvider: true,
          ),
        ),
      );

      await controller.startResolutionFromDraft();

      expect(api.startResolutionCalls, hasLength(1));
      expect(api.startResolutionCalls.single.provider, 'vk');
      expect(
        api.startResolutionCalls.single.input.kind,
        ProviderInputKind.link,
      );
      expect(
        api.startResolutionCalls.single.input.link,
        'https://vk.com/call/join/fresh',
      );
      expect(controller.notice, contains('external browser steps'));
    },
  );

  test(
    'controller sends provider settings for resolution and stores only profile-retained values',
    () async {
      final api = _FakeControlPlaneApi(
        profiles: const <ProfileRecord>[],
        providers: const <ProviderDescriptor>[_providerWithSettingsDescriptor],
        resolutions: const <ResolutionRecord>[],
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
        stateStore: _FakeShellStateStore(),
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
      expect(api.startResolutionCalls, hasLength(1));
      expect(
        api.startResolutionCalls.single.providerSettings,
        <String, dynamic>{'region': 'eu-west', 'device_pin': '123456'},
      );

      await controller.saveDraft();
      expect(api.upsertedProfiles, hasLength(1));
      expect(
        api.upsertedProfiles.single.spec.providerSettings,
        <String, dynamic>{'region': 'eu-west'},
      );
    },
  );

  test(
    'controller fails closed on unsupported provider settings schema',
    () async {
      final api = _FakeControlPlaneApi(
        profiles: const <ProfileRecord>[],
        providers: const <ProviderDescriptor>[
          _unsupportedProviderSettingsDescriptor,
        ],
        resolutions: const <ResolutionRecord>[],
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
        stateStore: _FakeShellStateStore(),
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

      expect(api.startResolutionCalls, isEmpty);
      expect(controller.notice, contains('cannot render provider settings'));
    },
  );

  test(
    'controller fails closed when the host does not advertise the provider',
    () async {
      final api = _FakeControlPlaneApi(
        profiles: const <ProfileRecord>[],
        providers: const <ProviderDescriptor>[],
        resolutions: const <ResolutionRecord>[],
        sessions: const <SessionRecord>[],
      );
      final controller = DesktopShellController(
        api: api,
        supervisor: _SequencedHostSupervisor(const <HostConnectionResult>[
          HostConnectionResult(
            state: HostLifecycleState.ready,
            message: 'ready',
            info: _readyWindowsWintunHostInfo,
          ),
        ]),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.startResolutionFromDraft();

      expect(api.startResolutionCalls, isEmpty);
      expect(
        controller.notice,
        contains('not advertised by the connected host'),
      );
    },
  );

  test('controller localizes shell-owned desktop notices in Russian', () async {
    await AppLocale.ru.build();
    LocaleSettings.setLocaleSync(AppLocale.ru);
    addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.en));

    final api = _FakeControlPlaneApi(
      profiles: const <ProfileRecord>[],
      providers: const <ProviderDescriptor>[],
      resolutions: const <ResolutionRecord>[],
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
    controller.managedProviders = const <ManagedProviderRecord>[];
    controller.selectedManagedProviderId = null;
    controller.draft = ProfileDraft.defaults();
    controller.activateManagedProviderMode();
    expect(controller.notice, 'Управляемые провайдеры пока недоступны.');

    await controller.startResolutionFromDraft();
    expect(
      controller.notice,
      'Выбранный провайдер не объявлен подключенным хостом.',
    );
  });

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
    'controller opens shell-external conference-room actions from typed artifact summaries',
    () async {
      final api = _FakeControlPlaneApi(
        profiles: const <ProfileRecord>[],
        resolutions: <ResolutionRecord>[_conferenceRoomResolutionRecord()],
        sessions: const <SessionRecord>[],
      );
      final browser = _FakeDesktopBrowserLauncher();
      final controller = DesktopShellController(
        api: api,
        supervisor: _SequencedHostSupervisor(const <HostConnectionResult>[
          HostConnectionResult(
            state: HostLifecycleState.ready,
            message: 'ready',
            info: _readyHostInfo,
          ),
        ]),
        browserLauncher: browser,
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
      expect(controller.notice, contains('Opened action "Open room"'));
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
            info: _readyWindowsWintunHostInfo,
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
    'controller exports selected profiles through portable transfer adapter',
    () async {
      final portableAdapter = _FakeDesktopPortableProfileTransferAdapter();
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
            state: HostLifecycleState.ready,
            message: 'ready',
            info: _readyHostInfo,
          ),
        ]),
        portableProfileTransferAdapter: portableAdapter,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      controller.selectProfile('profile-1');

      final envelope = controller.selectedPortableProfileEnvelope();
      expect(envelope, isNotNull);

      await controller.copyPortableProfileEnvelopeText(envelope!);
      await controller.savePortableProfileEnvelopeToFile(envelope);

      expect(portableAdapter.copiedPayloads, hasLength(1));
      expect(
        portableAdapter.copiedPayloads.single,
        contains('"type": "portable_profile"'),
      );
      expect(portableAdapter.savedPayloads, hasLength(1));
      expect(
        portableAdapter.savedSuggestedNames.single,
        'alpha.portable-profile.json',
      );
      expect(controller.notice, contains('secret-bearing portable profile'));
    },
  );

  test(
    'controller imports managed portable profiles append-only with fresh ids',
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
        stateStore: _FakeShellStateStore(),
        clock: () => DateTime.utc(2026, 4, 17, 12, 0),
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      final envelope = PortableProfileEnvelope.build(
        profile: ProfileRecord(
          id: 'remote-profile',
          name: 'Imported alpha',
          spec: _profileSpec().copyWith(link: ''),
        ),
        providerBinding: const ProfileProviderBinding(
          mode: ProfileProviderMode.managed,
          managedProviderId: 'remote-managed',
        ),
        managedProviderSnapshot: _managedProviderRecord(
          id: 'remote-managed',
          name: 'Imported VK provider',
        ),
      );

      await controller.confirmPortableProfileImport(envelope);

      expect(api.upsertedProfiles, hasLength(1));
      final savedProfile = api.upsertedProfiles.single;
      expect(savedProfile.id, isNot('remote-profile'));
      expect(savedProfile.id, startsWith('portable-'));
      expect(controller.selectedProfileId, savedProfile.id);
      expect(
        controller.profileBindings[savedProfile.id]?.mode,
        ProfileProviderMode.managed,
      );
      expect(
        controller.profileBindings[savedProfile.id]?.managedProviderId,
        isNot('remote-managed'),
      );
      final importedManagedProviderId =
          controller.profileBindings[savedProfile.id]?.managedProviderId;
      expect(
        controller.managedProviders.any(
          (ManagedProviderRecord provider) =>
              provider.id == importedManagedProviderId,
        ),
        isTrue,
      );
      expect(controller.notice, contains('Imported profile'));
      expect(api.startSessionCalls, 0);
      expect(api.startResolutionCalls, isEmpty);
    },
  );

  test(
    'controller fails closed for unsupported portable import payloads',
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
            info: _readyWindowsWintunHostInfo,
          ),
        ]),
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      final envelope = controller.previewPortableProfileEnvelope(
        jsonEncode(<String, dynamic>{
          'type': kPortableProfileEnvelopeType,
          'version': 99,
          'profile': ProfileRecord(
            id: 'profile-1',
            name: 'alpha',
            spec: _profileSpec(),
          ).toJson(),
          'provider_binding': const ProfileProviderBinding().toJson(),
          'secret_classification': const PortableProfileSecretClassification(
            secretBearing: true,
          ).toJson(),
        }),
      );

      expect(envelope, isNull);
      expect(controller.notice, contains('unsupported envelope version'));
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
            info: _readyWindowsWintunHostInfo,
          ),
        ]),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.startPlatformTunnel(PlatformTunnelMode.windowsWintun);

      expect(api.startPlatformTunnelCalls, hasLength(1));
      expect(
        api.startPlatformTunnelCalls.single.mode,
        PlatformTunnelMode.windowsWintun,
      );
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
    'controller forwards selected resolution and default windows execution plan for platform tunnel start',
    () async {
      final api = _FakeControlPlaneApi(
        profiles: const <ProfileRecord>[],
        resolutions: <ResolutionRecord>[_resolutionRecord(id: 'resolution-7')],
        sessions: const <SessionRecord>[],
      );
      final controller = DesktopShellController(
        api: api,
        supervisor: _SequencedHostSupervisor(const <HostConnectionResult>[
          HostConnectionResult(
            state: HostLifecycleState.ready,
            message: 'ready',
            info: _readyWindowsWintunHostInfo,
          ),
        ]),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      controller.materializeDefaults = const RuntimeDefaults(
        listenAddress: '127.0.0.1:9101',
        peerAddress: 'relay.example.test:3478',
        turnServer: 'turn.example.test',
        turnPort: '3478',
      );
      await controller.startPlatformTunnel(PlatformTunnelMode.windowsWintun);

      expect(api.startPlatformTunnelCalls, hasLength(1));
      final call = api.startPlatformTunnelCalls.single;
      expect(call.mode, PlatformTunnelMode.windowsWintun);
      expect(call.resolutionId, 'resolution-7');
      expect(call.runtimeDefaults, isNotNull);
      expect(call.runtimeDefaults?.listenAddress, '127.0.0.1:9101');
      expect(call.runtimeDefaults?.peerAddress, 'relay.example.test:3478');
      expect(call.runtimeDefaults?.turnServer, 'turn.example.test');
      expect(call.runtimeDefaults?.turnPort, '3478');
      expect(call.executionPlan, isNotNull);
      expect(
        call.executionPlan?.accessMethod,
        RuntimeAccessMethod.turnCredentials,
      );
      expect(
        call.executionPlan?.carrierFamily,
        RuntimeCarrierFamily.turnDatagram,
      );
      expect(
        call.executionPlan?.engineFamily,
        RuntimeEngineFamily.wireguardNative,
      );
      expect(call.executionPlan?.hostAdapter, RuntimeHostAdapter.windowsWintun);
      expect(
        call.underlayRoutePolicy,
        PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork,
      );
    },
  );

  test('controller loads provider source catalog during refresh', () async {
    final api = _FakeControlPlaneApi(
      profiles: const <ProfileRecord>[],
      sessions: const <SessionRecord>[],
      providerSources: const <RemoteProviderSourceDescriptor>[
        RemoteProviderSourceDescriptor(
          endpointId: 'vps-1',
          providerId: 'generic-turn',
          sourceId: 'vk-turn-vps',
          displayName: 'VK TURN VPS',
          sourceFamily: 'turn',
          healthStatus: 'ready',
          evidenceStatus: 'fresh',
          validationStatus: 'valid',
          artifactOffers: <RemoteProviderArtifactOffer>[
            RemoteProviderArtifactOffer(
              offerId: 'turn-wg',
              family: 'generic_turn',
              accessMethods: <String>['turn_credentials'],
              compatibleProfileKinds: <TransportProfileKind>[
                TransportProfileKind.wireGuardNativeV1,
              ],
              validationStatus: 'valid',
            ),
          ],
        ),
      ],
    );
    final controller = DesktopShellController(
      api: api,
      supervisor: _SequencedHostSupervisor(<HostConnectionResult>[
        const HostConnectionResult(
          state: HostLifecycleState.ready,
          message: 'ready',
          info: _readyHostInfo,
        ),
      ]),
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.providerSources, hasLength(1));
    expect(controller.providerSources.single.sourceId, 'vk-turn-vps');
    expect(
      controller
          .providerSources
          .single
          .artifactOffers
          .single
          .compatibleProfileKinds,
      <TransportProfileKind>[TransportProfileKind.wireGuardNativeV1],
    );
  });

  test(
    'controller uses VPN transport profile store before desktop platform tunnel startup',
    () async {
      final api = _FakeControlPlaneApi(
        profiles: const <ProfileRecord>[],
        sessions: const <SessionRecord>[],
        hostInfo: _desktopTransportProfileHostInfo(configured: false),
      );
      final controller = DesktopShellController(
        api: api,
        supervisor: _SequencedHostSupervisor(<HostConnectionResult>[
          HostConnectionResult(
            state: HostLifecycleState.ready,
            message: 'ready',
            info: _desktopTransportProfileHostInfo(configured: false),
          ),
        ]),
        transportProfileContentPicker: () async => 'wg-profile',
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(
        controller.canConfigureVPNTransportProfileForMode(
          PlatformTunnelMode.windowsWintun,
        ),
        isTrue,
      );
      expect(
        controller.vpnTransportProfileStatusSummaryForMode(
          PlatformTunnelMode.windowsWintun,
        ),
        contains('not configured'),
      );
      expect(
        controller.platformTunnelStartPreparationBlockReason(
          PlatformTunnelMode.windowsWintun,
        ),
        contains('VPN transport profile'),
      );

      await controller.startPlatformTunnel(PlatformTunnelMode.windowsWintun);

      expect(api.startResolutionCalls, isEmpty);
      expect(api.startPlatformTunnelCalls, isEmpty);

      await controller.importVPNTransportProfileForMode(
        PlatformTunnelMode.windowsWintun,
      );

      expect(api.importTransportProfileCalls, hasLength(1));
      expect(api.importTransportProfileCalls.single.material, 'wg-profile');
      expect(
        api.importTransportProfileCalls.single.defaultFor,
        _windowsWintunExecutionPlan,
      );
      expect(
        controller.vpnTransportProfileStatusSummaryForMode(
          PlatformTunnelMode.windowsWintun,
        ),
        contains('WireGuard profile: configured'),
      );
      expect(
        controller.platformTunnelStartPreparationBlockReason(
          PlatformTunnelMode.windowsWintun,
        ),
        isNull,
      );

      await controller.startPlatformTunnel(PlatformTunnelMode.windowsWintun);

      expect(api.startResolutionCalls, hasLength(1));
      expect(api.startPlatformTunnelCalls, hasLength(1));
      expect(api.providerTransportCompatibilityRequests, hasLength(2));
      expect(
        api
            .providerTransportCompatibilityRequests
            .last
            .transportProfile
            ?.profileId,
        'transport-profile-1',
      );
      expect(
        api.startPlatformTunnelCalls.single.transportProfile?.profileId,
        'transport-profile-1',
      );
      expect(
        api
            .startPlatformTunnelCalls
            .single
            .providerTransportCompatibility
            ?.source
            ?.resolutionId,
        'resolution-1',
      );
      expect(
        api
            .startPlatformTunnelCalls
            .single
            .providerTransportCompatibility
            ?.transportProfile
            ?.profileId,
        'transport-profile-1',
      );

      await controller.forgetVPNTransportProfileForMode(
        PlatformTunnelMode.windowsWintun,
      );

      expect(
        controller.activeVPNTransportProfileConfiguredForMode(
          PlatformTunnelMode.windowsWintun,
        ),
        isFalse,
      );
      expect(
        controller.vpnTransportProfileStatusSummaryForMode(
          PlatformTunnelMode.windowsWintun,
        ),
        contains('not configured'),
      );
      expect(
        controller.platformTunnelStartPreparationBlockReason(
          PlatformTunnelMode.windowsWintun,
        ),
        contains('VPN transport profile'),
      );
    },
  );

  test(
    'controller blocks desktop platform tunnel before host startup when provider transport compatibility is not startable',
    () async {
      final api = _FakeControlPlaneApi(
        profiles: const <ProfileRecord>[],
        sessions: const <SessionRecord>[],
        resolutions: <ResolutionRecord>[
          _resolutionRecord(provider: 'generic-turn'),
        ],
        hostInfo: _desktopTransportProfileHostInfo(configured: true),
        transportProfiles: <TransportProfileStatus>[
          _desktopTransportProfileStatus(),
        ],
        providerTransportCompatibilityResponseBuilder:
            (ProviderTransportCompatibilityRequest request) {
              final executionPlan = request.executionPlan!;
              return ProviderTransportCompatibilityResponse(
                version: '1',
                generatedAt: DateTime.utc(2026, 5, 3, 12),
                candidates: <ProviderTransportCompatibilityCandidate>[
                  ProviderTransportCompatibilityCandidate(
                    id: 'candidate-blocked',
                    source: ProviderTransportSourceReference(
                      providerId: 'generic-turn',
                      resolutionId: request.resolutionId,
                    ),
                    artifact: ProviderTransportArtifactReference(
                      providerId: 'generic-turn',
                      resolutionId: request.resolutionId,
                      family: ArtifactFamily.genericTurn,
                      accessMethods: <RuntimeAccessMethod>[
                        executionPlan.accessMethod,
                      ],
                    ),
                    executionPlan: RuntimeExecutionPlanDescriptor(
                      plan: executionPlan,
                      supportState: RuntimeExecutionPlanSupportState.supported,
                      remoteEndpointFamily:
                          RuntimeRemoteEndpointFamily.turnServer,
                      remoteEndpointRole:
                          RuntimeRemoteEndpointRole.wireGuardRawDatagram,
                    ),
                    selectedTransportProfile: request.transportProfile,
                    status: ProviderTransportCompatibilityStatus.unsupported,
                    startable: false,
                    failingAxis: ProviderTransportCompatibilityFailingAxis
                        .transportProfile,
                    reasonCode: ProviderTransportCompatibilityReasonCode
                        .transportProfileIncompatibleKind,
                    message:
                        'selected VPN transport profile kind is not supported by this provider source',
                  ),
                ],
              );
            },
      );
      final controller = DesktopShellController(
        api: api,
        supervisor: _SequencedHostSupervisor(<HostConnectionResult>[
          HostConnectionResult(
            state: HostLifecycleState.ready,
            message: 'ready',
            info: _desktopTransportProfileHostInfo(configured: true),
          ),
        ]),
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(api.providerTransportCompatibilityRequests, hasLength(1));
      expect(
        controller.platformTunnelStartPreparationBlockReason(
          PlatformTunnelMode.windowsWintun,
        ),
        contains('provider/transport compatibility'),
      );

      await controller.startPlatformTunnel(PlatformTunnelMode.windowsWintun);

      expect(api.startPlatformTunnelCalls, isEmpty);
    },
  );

  test(
    'controller starts provider resolution before windows platform tunnel start',
    () async {
      final api = _FakeControlPlaneApi(
        profiles: const <ProfileRecord>[],
        resolutions: const <ResolutionRecord>[],
        sessions: const <SessionRecord>[],
      );
      final controller = DesktopShellController(
        api: api,
        supervisor: _SequencedHostSupervisor(const <HostConnectionResult>[
          HostConnectionResult(
            state: HostLifecycleState.ready,
            message: 'ready',
            info: _readyWindowsWintunHostInfo,
          ),
        ]),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      controller.updateDraft(
        controller.draft.copyWith(
          spec: controller.draft.spec.copyWith(
            provider: 'vk',
            link: 'https://vk.com/call/join/fresh',
          ),
        ),
      );
      await controller.startPlatformTunnel(PlatformTunnelMode.windowsWintun);

      expect(api.startResolutionCalls, hasLength(1));
      expect(api.startResolutionCalls.single.provider, 'vk');
      expect(
        api.startResolutionCalls.single.input.link,
        'https://vk.com/call/join/fresh',
      );
      expect(api.startSessionCalls, 0);
      expect(api.startPlatformTunnelCalls, hasLength(1));
      expect(api.startPlatformTunnelCalls.single.resolutionId, 'resolution-1');
      expect(controller.selectedResolutionId, 'resolution-1');
    },
  );

  test(
    'controller waits for provider challenge started for windows platform tunnel',
    () async {
      final api = _FakeControlPlaneApi(
        profiles: const <ProfileRecord>[],
        resolutions: const <ResolutionRecord>[],
        sessions: const <SessionRecord>[],
        startResolutionState: ResolutionState.challengeRequired,
      );
      final controller = DesktopShellController(
        api: api,
        supervisor: _SequencedHostSupervisor(const <HostConnectionResult>[
          HostConnectionResult(
            state: HostLifecycleState.ready,
            message: 'ready',
            info: _readyWindowsWintunHostInfo,
          ),
        ]),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      controller.updateDraft(
        controller.draft.copyWith(
          spec: controller.draft.spec.copyWith(
            provider: 'vk',
            link: 'https://vk.com/call/join/fresh',
          ),
        ),
      );
      await controller.startPlatformTunnel(PlatformTunnelMode.windowsWintun);

      expect(api.startResolutionCalls, hasLength(1));
      expect(api.startPlatformTunnelCalls, isEmpty);
      expect(
        controller.notice,
        const ShellText().resolutionStartedThenCompleteChallengeBeforeStarting(
          const ShellText().startedResolutionForProviderWithExternalBrowser(
            'resolution-1',
            'VK Calls',
          ),
          PlatformTunnelMode.windowsWintun.label,
        ),
      );
    },
  );

  test(
    'controller continues pending windows platform tunnel after browser challenge',
    () async {
      final api = _FakeControlPlaneApi(
        profiles: const <ProfileRecord>[],
        resolutions: const <ResolutionRecord>[],
        sessions: const <SessionRecord>[],
        startResolutionState: ResolutionState.challengeRequired,
        continueChallengeResolutionState: ResolutionState.resolved,
      );
      final controller = DesktopShellController(
        api: api,
        supervisor: _SequencedHostSupervisor(const <HostConnectionResult>[
          HostConnectionResult(
            state: HostLifecycleState.ready,
            message: 'ready',
            info: _readyWindowsWintunHostInfo,
          ),
        ]),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      controller.updateDraft(
        controller.draft.copyWith(
          spec: controller.draft.spec.copyWith(
            provider: 'vk',
            link: 'https://vk.com/call/join/fresh',
          ),
        ),
      );

      await controller.startPlatformTunnel(PlatformTunnelMode.windowsWintun);
      expect(api.startResolutionCalls, hasLength(1));
      expect(api.startPlatformTunnelCalls, isEmpty);

      await controller.continueChallenge('challenge-1');

      expect(api.startPlatformTunnelCalls, hasLength(1));
      expect(api.startPlatformTunnelCalls.single.resolutionId, 'resolution-1');
    },
  );

  test(
    'controller refuses startup for unavailable desktop platform tunnel modes',
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

      expect(api.startPlatformTunnelCalls, isEmpty);
      expect(
        controller.platformTunnelResultFor(PlatformTunnelMode.windowsWintun),
        isNull,
      );
      expect(
        controller.notice,
        'desktop sidecar does not implement system tunnel startup yet',
      );
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
          info: _readyWindowsWintunHostInfo,
        ),
        HostConnectionResult(
          state: HostLifecycleState.ready,
          message: 'ready again',
          info: _readyWindowsWintunHostInfo,
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
    List<ProviderDescriptor>? providers,
    List<ProviderConfigRecord>? providerConfigs,
    List<RemoteProviderSourceDescriptor>? providerSources,
    List<ResolutionRecord>? resolutions,
    required List<SessionRecord> sessions,
    Map<String, ChallengeRecord>? challenges,
    HostInfo? hostInfo,
    List<TransportProfileStatus>? transportProfiles,
    ResolutionState startResolutionState = ResolutionState.resolved,
    ResolutionState? continueChallengeResolutionState,
    ProviderTransportCompatibilityResponse Function(
      ProviderTransportCompatibilityRequest request,
    )?
    providerTransportCompatibilityResponseBuilder,
  }) : _profiles = List<ProfileRecord>.of(profiles),
       _providers = List<ProviderDescriptor>.of(
         providers ?? _providerDescriptors,
       ),
       _providerConfigs = List<ProviderConfigRecord>.of(
         providerConfigs ?? const <ProviderConfigRecord>[],
       ),
       _providerSources = List<RemoteProviderSourceDescriptor>.of(
         providerSources ?? const <RemoteProviderSourceDescriptor>[],
       ),
       _resolutions = List<ResolutionRecord>.of(
         resolutions ?? const <ResolutionRecord>[],
       ),
       _sessions = List<SessionRecord>.of(sessions),
       _challenges = Map<String, ChallengeRecord>.of(
         challenges ?? <String, ChallengeRecord>{},
       ),
       _hostInfo = hostInfo ?? _readyHostInfo,
       _transportProfiles = List<TransportProfileStatus>.of(
         transportProfiles ?? const <TransportProfileStatus>[],
       ),
       _startResolutionState = startResolutionState,
       _continueChallengeResolutionState = continueChallengeResolutionState,
       _providerTransportCompatibilityResponseBuilder =
           providerTransportCompatibilityResponseBuilder;

  final List<ProviderDescriptor> _providers;
  final List<ProviderConfigRecord> _providerConfigs;
  final List<RemoteProviderSourceDescriptor> _providerSources;
  final List<ProfileRecord> _profiles;
  final List<ResolutionRecord> _resolutions;
  final List<SessionRecord> _sessions;
  final Map<String, ChallengeRecord> _challenges;
  HostInfo _hostInfo;
  final List<TransportProfileStatus> _transportProfiles;
  final ResolutionState _startResolutionState;
  final ResolutionState? _continueChallengeResolutionState;
  final ProviderTransportCompatibilityResponse Function(
    ProviderTransportCompatibilityRequest request,
  )?
  _providerTransportCompatibilityResponseBuilder;
  final StreamController<EventRecord> _events =
      StreamController<EventRecord>.broadcast();
  final List<String> challengeRequests = <String>[];
  final List<_StartResolutionCall> startResolutionCalls =
      <_StartResolutionCall>[];
  final List<String> materializeResolutionCalls = <String>[];
  final List<RuntimeDefaults> materializeResolutionDefaults =
      <RuntimeDefaults>[];
  final List<_StartPlatformTunnelCall> startPlatformTunnelCalls =
      <_StartPlatformTunnelCall>[];
  final List<ProviderTransportCompatibilityRequest>
  providerTransportCompatibilityRequests =
      <ProviderTransportCompatibilityRequest>[];
  final List<TransportProfileImportRequest> importTransportProfileCalls =
      <TransportProfileImportRequest>[];
  final List<ProfileRecord> upsertedProfiles = <ProfileRecord>[];
  final List<ProviderConfigRecord> upsertedProviderConfigs =
      <ProviderConfigRecord>[];
  final List<ProviderConfigRecord> restoredProviderConfigs =
      <ProviderConfigRecord>[];
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
  Future<ChallengeRecord> continueChallenge(
    String challengeId, {
    ChallengeContinuationSubmission? browserContinuation,
  }) async {
    final challenge = _challenges[challengeId]!.copyWith(
      status: ChallengeStatus.completed,
      updatedAt: DateTime.utc(2026, 4, 10, 12, 2),
    );
    _challenges[challengeId] = challenge;
    final nextResolutionState = _continueChallengeResolutionState;
    if (nextResolutionState != null) {
      final resolutionId = challenge.resolutionId?.trim() ?? '';
      final index = _resolutions.indexWhere(
        (ResolutionRecord resolution) => resolution.id == resolutionId,
      );
      if (index >= 0) {
        _resolutions[index] = _resolutionRecord(
          id: _resolutions[index].id,
          provider: _resolutions[index].provider,
          linkRedacted: _resolutions[index].input.linkRedacted,
          state: nextResolutionState,
        );
      }
    }
    return challenge;
  }

  @override
  Future<void> deleteProviderConfig(String configId) async {
    _providerConfigs.removeWhere(
      (ProviderConfigRecord config) => config.id == configId,
    );
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
    return _hostInfo;
  }

  @override
  Future<List<TransportProfileStatus>> transportProfiles() async {
    return _transportProfiles;
  }

  @override
  Future<List<PlatformTunnelStatus>> platformTunnelStatuses() async {
    return const <PlatformTunnelStatus>[];
  }

  @override
  Future<TransportProfileStatus> importTransportProfile(
    TransportProfileImportRequest request,
  ) async {
    importTransportProfileCalls.add(request);
    final status = _desktopTransportProfileStatus();
    _transportProfiles
      ..clear()
      ..add(status);
    _hostInfo = _desktopTransportProfileHostInfo(configured: true);
    return status;
  }

  @override
  Future<TransportProfileStructuredSaveResult> createStructuredTransportProfile(
    TransportProfileStructuredCreateRequest request,
  ) async {
    final status = _desktopTransportProfileStatus();
    _transportProfiles
      ..clear()
      ..add(status);
    _hostInfo = _desktopTransportProfileHostInfo(configured: true);
    return TransportProfileStructuredSaveResult(profile: status);
  }

  @override
  Future<TransportProfileStructuredSaveResult> updateStructuredTransportProfile(
    String profileId,
    TransportProfileStructuredUpdateRequest request,
  ) async {
    return TransportProfileStructuredSaveResult(
      profile: await validateTransportProfile(profileId),
    );
  }

  @override
  Future<TransportProfileStructuredValidationResult>
  validateStructuredTransportProfileDraft(
    TransportProfileStructuredValidationRequest request,
  ) async {
    return const TransportProfileStructuredValidationResult(valid: true);
  }

  @override
  Future<TransportProfileGeneratedKey> generateTransportProfileKey(
    TransportProfileGenerateKeyRequest request,
  ) async {
    return TransportProfileGeneratedKey(
      kind: request.kind,
      field:
          request.field ??
          TransportProfileStructuredFieldId.interfacePrivateKey,
      publicKey: 'public-key',
      fingerprint: 'sha256:test',
    );
  }

  @override
  Future<TransportProfileStatus> validateTransportProfile(
    String profileId,
  ) async {
    return _transportProfiles.firstWhere(
      (TransportProfileStatus profile) => profile.id == profileId,
    );
  }

  @override
  Future<TransportProfileStatus> selectTransportProfileForStartup(
    String profileId,
    TransportProfileSelectForStartupRequest request,
  ) async {
    return validateTransportProfile(profileId);
  }

  @override
  Future<void> forgetTransportProfile(String profileId) async {
    _transportProfiles.removeWhere(
      (TransportProfileStatus profile) => profile.id == profileId,
    );
    _hostInfo = _desktopTransportProfileHostInfo(configured: false);
  }

  @override
  Future<List<ProviderConfigRecord>> providerConfigs() async =>
      _providerConfigs;

  @override
  Future<SessionRecord> materializeResolution({
    required String resolutionId,
    required RuntimeDefaults runtimeDefaults,
    RuntimeExecutionPlan? executionPlan,
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
    String? resolutionId,
    RuntimeDefaults? runtimeDefaults,
    RuntimeExecutionPlan? executionPlan,
    TransportProfileReference? transportProfile,
    ProviderTransportCompatibilityStartupReference?
    providerTransportCompatibility,
    PlatformTunnelApplicationRoutingPolicy applicationRoutingPolicy =
        PlatformTunnelApplicationRoutingPolicy.allApps,
    PlatformTunnelUnderlayRoutePolicy underlayRoutePolicy =
        PlatformTunnelUnderlayRoutePolicy.standard,
    List<String> allowedPackages = const <String>[],
    List<String> disallowedPackages = const <String>[],
  }) async {
    startPlatformTunnelCalls.add(
      _StartPlatformTunnelCall(
        mode: mode,
        resolutionId: resolutionId,
        runtimeDefaults: runtimeDefaults,
        executionPlan: executionPlan,
        transportProfile: transportProfile,
        providerTransportCompatibility: providerTransportCompatibility,
        applicationRoutingPolicy: applicationRoutingPolicy,
        underlayRoutePolicy: underlayRoutePolicy,
        allowedPackages: allowedPackages,
        disallowedPackages: disallowedPackages,
      ),
    );
    return const PlatformTunnelStartResult(
      mode: PlatformTunnelMode.windowsWintun,
      ready: false,
      stage: PlatformTunnelStartupStage.capabilityCheck,
      missingPrerequisite: PlatformTunnelPrerequisite.hostImplementation,
      message: 'desktop sidecar does not implement system tunnel startup yet',
    );
  }

  @override
  Future<PlatformTunnelStartResult> resumePlatformTunnel({
    required String startupAttemptId,
  }) async {
    return PlatformTunnelStartResult(
      mode: PlatformTunnelMode.windowsWintun,
      ready: false,
      stage: PlatformTunnelStartupStage.permissionAcquire,
      missingPrerequisite: PlatformTunnelPrerequisite.permission,
      startupAttemptId: startupAttemptId,
      message: 'desktop sidecar does not implement tunnel resume yet',
    );
  }

  @override
  Future<PlatformTunnelStopResult> stopPlatformTunnel({
    required PlatformTunnelMode mode,
  }) async {
    return PlatformTunnelStopResult(
      mode: mode,
      stopped: true,
      message: 'stopped',
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
  Future<List<ProviderDescriptor>> providers() async => _providers;

  @override
  Future<List<RemoteProviderSourceDescriptor>> providerSources() async =>
      _providerSources;

  @override
  Future<ProviderTransportCompatibilityResponse>
  providerTransportCompatibilityCandidates(
    ProviderTransportCompatibilityRequest request,
  ) async {
    providerTransportCompatibilityRequests.add(request);
    final override = _providerTransportCompatibilityResponseBuilder;
    if (override != null) {
      return override(request);
    }
    final executionPlan = request.executionPlan;
    return ProviderTransportCompatibilityResponse(
      version: '1',
      generatedAt: DateTime.utc(2026, 5, 3, 12),
      candidates: executionPlan == null
          ? const <ProviderTransportCompatibilityCandidate>[]
          : <ProviderTransportCompatibilityCandidate>[
              ProviderTransportCompatibilityCandidate(
                id: 'candidate-1',
                source: ProviderTransportSourceReference(
                  providerId: 'generic-turn',
                  resolutionId: request.resolutionId,
                ),
                artifact: ProviderTransportArtifactReference(
                  providerId: 'generic-turn',
                  resolutionId: request.resolutionId,
                  family: ArtifactFamily.genericTurn,
                  accessMethods: <RuntimeAccessMethod>[
                    executionPlan.accessMethod,
                  ],
                ),
                executionPlan: RuntimeExecutionPlanDescriptor(
                  plan: executionPlan,
                  supportState: RuntimeExecutionPlanSupportState.supported,
                  remoteEndpointFamily: RuntimeRemoteEndpointFamily.turnServer,
                  remoteEndpointRole:
                      RuntimeRemoteEndpointRole.wireGuardRawDatagram,
                ),
                selectedTransportProfile: request.transportProfile,
                status: ProviderTransportCompatibilityStatus.startable,
                startable: true,
                reasonCode: ProviderTransportCompatibilityReasonCode.ready,
              ),
            ],
    );
  }

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
      state: _startResolutionState,
      activeChallengeId:
          _startResolutionState == ResolutionState.challengeRequired
          ? 'challenge-${startResolutionCalls.length}'
          : null,
    );
    if (_startResolutionState == ResolutionState.challengeRequired) {
      final challengeId = 'challenge-${startResolutionCalls.length}';
      _challenges[challengeId] = ChallengeRecord(
        id: challengeId,
        sessionId: '',
        resolutionId: resolution.id,
        provider: provider,
        stage: 'provider_resolve',
        kind: 'browser',
        prompt: 'continue in browser',
        openUrl: input.link,
        status: ChallengeStatus.pending,
        createdAt: DateTime.utc(2026, 4, 10, 12, 1),
        updatedAt: DateTime.utc(2026, 4, 10, 12, 1),
      );
    }
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
    final index = _providerConfigs.indexWhere(
      (ProviderConfigRecord existing) => existing.id == next.id,
    );
    if (index >= 0) {
      _providerConfigs[index] = next;
    } else {
      _providerConfigs.add(next);
    }
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
          : const ProviderConfigAvailability(
              state: ProviderConfigAvailabilityState.providerUnavailable,
              message:
                  'provider "wb-stream" is not advertised by the current host',
            ),
    );
    final index = _providerConfigs.indexWhere(
      (ProviderConfigRecord existing) => existing.id == next.id,
    );
    if (index >= 0) {
      _providerConfigs[index] = next;
    } else {
      _providerConfigs.add(next);
    }
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

class _FakeDesktopPortableProfileTransferAdapter
    implements DesktopPortableProfileTransferAdapter {
  final List<String> copiedPayloads = <String>[];
  final List<String> savedPayloads = <String>[];
  final List<String> savedSuggestedNames = <String>[];
  String? nextSavedPath = '/tmp/exported-profile.json';
  String? nextOpenedPayload;

  @override
  Future<void> copyEnvelopeText(String payload) async {
    copiedPayloads.add(payload);
  }

  @override
  Future<String?> openEnvelopeText() async => nextOpenedPayload;

  @override
  Future<String?> saveEnvelopeText({
    required String suggestedName,
    required String payload,
  }) async {
    savedSuggestedNames.add(suggestedName);
    savedPayloads.add(payload);
    return nextSavedPath;
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

ManagedProviderRecord _managedProviderRecord({
  required String id,
  required String name,
}) {
  return ManagedProviderRecord(
    id: id,
    provider: 'vk',
    name: name,
    providerSettings: const <String, dynamic>{'region': 'eu-west'},
    createdAt: DateTime.utc(2026, 4, 17, 12, 0),
    updatedAt: DateTime.utc(2026, 4, 17, 12, 1),
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

class _StartPlatformTunnelCall {
  const _StartPlatformTunnelCall({
    required this.mode,
    required this.applicationRoutingPolicy,
    required this.underlayRoutePolicy,
    this.resolutionId,
    this.runtimeDefaults,
    this.executionPlan,
    this.transportProfile,
    this.providerTransportCompatibility,
    this.allowedPackages = const <String>[],
    this.disallowedPackages = const <String>[],
  });

  final PlatformTunnelMode mode;
  final String? resolutionId;
  final RuntimeDefaults? runtimeDefaults;
  final RuntimeExecutionPlan? executionPlan;
  final TransportProfileReference? transportProfile;
  final ProviderTransportCompatibilityStartupReference?
  providerTransportCompatibility;
  final PlatformTunnelApplicationRoutingPolicy applicationRoutingPolicy;
  final PlatformTunnelUnderlayRoutePolicy underlayRoutePolicy;
  final List<String> allowedPackages;
  final List<String> disallowedPackages;
}
