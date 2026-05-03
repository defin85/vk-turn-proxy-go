import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter_shell_core/portable_profile_transfer.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/mobile_handoff_adapter.dart';
import 'package:mobile_gui_shell/src/control/mobile_host_bridge.dart';
import 'package:mobile_gui_shell/src/control/mobile_portable_profile_transfer_adapter.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_controller.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_state_store.dart';
import 'package:mobile_gui_shell/src/control/profile_draft.dart';

const BuildIdentity _testGuiBuild = BuildIdentity(
  product: 'RelayDock',
  version: '0.1.0',
  buildNumber: '1',
  revision: 'mobilegui1234',
  role: 'mobile_gui_shell',
  target: 'android/debug',
);

const BuildIdentity _testHostBuild = BuildIdentity(
  product: 'RelayDock',
  version: '0.1.0',
  buildNumber: '1',
  revision: 'embeddedhost123',
  role: 'mobile_host',
  target: 'android/debug',
);

const TransportProfileReference _androidTransportProfileReference =
    TransportProfileReference(
      profileId: 'transport-profile-1',
      kind: TransportProfileKind.wireGuardNativeV1,
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

const TransportProfilePrerequisiteStatus
_configuredTransportProfilePrerequisite = TransportProfilePrerequisiteStatus(
  requiredKinds: <TransportProfileKind>[TransportProfileKind.wireGuardNativeV1],
  state: TransportProfileCompatibilityState.compatible,
  selectedProfile: _androidTransportProfileReference,
  importAdapters: <TransportProfileImportAdapter>[
    TransportProfileImportAdapter.wireGuardConf,
  ],
);

const TransportProfilePrerequisiteStatus _missingTransportProfilePrerequisite =
    TransportProfilePrerequisiteStatus(
      requiredKinds: <TransportProfileKind>[
        TransportProfileKind.wireGuardNativeV1,
      ],
      state: TransportProfileCompatibilityState.incompatible,
      missingKind: TransportProfileKind.wireGuardNativeV1,
      importAdapters: <TransportProfileImportAdapter>[
        TransportProfileImportAdapter.wireGuardConf,
      ],
      message: 'VPN transport profile wireguard_native_v1 is not configured.',
    );

const RuntimeExecutionPlanDescriptor _androidVpnExecutionPlanDescriptor =
    RuntimeExecutionPlanDescriptor(
      plan: RuntimeExecutionPlan(
        accessMethod: RuntimeAccessMethod.turnCredentials,
        carrierFamily: RuntimeCarrierFamily.turnDatagram,
        engineFamily: RuntimeEngineFamily.wireguardNative,
        hostAdapter: RuntimeHostAdapter.androidVpnService,
      ),
      supportState: RuntimeExecutionPlanSupportState.supported,
      remoteEndpointFamily: RuntimeRemoteEndpointFamily.turnServer,
      isDefault: true,
      requiredTransportProfileKinds: <TransportProfileKind>[
        TransportProfileKind.wireGuardNativeV1,
      ],
      transportProfile: _configuredTransportProfilePrerequisite,
    );

const RuntimeExecutionPlanDescriptor
_unavailableAndroidVpnExecutionPlanDescriptor = RuntimeExecutionPlanDescriptor(
  plan: RuntimeExecutionPlan(
    accessMethod: RuntimeAccessMethod.turnCredentials,
    carrierFamily: RuntimeCarrierFamily.turnDatagram,
    engineFamily: RuntimeEngineFamily.wireguardNative,
    hostAdapter: RuntimeHostAdapter.androidVpnService,
  ),
  supportState: RuntimeExecutionPlanSupportState.unavailable,
  remoteEndpointFamily: RuntimeRemoteEndpointFamily.turnServer,
  isDefault: true,
  message:
      'The android/arm64 host does not yet implement the strict TURN datagram WireGuard carrier/materializer required for mode android_vpn_service.',
);

const RuntimeExecutionPlanDescriptor
_missingProfileAndroidVpnExecutionPlanDescriptor =
    RuntimeExecutionPlanDescriptor(
      plan: RuntimeExecutionPlan(
        accessMethod: RuntimeAccessMethod.turnCredentials,
        carrierFamily: RuntimeCarrierFamily.turnDatagram,
        engineFamily: RuntimeEngineFamily.wireguardNative,
        hostAdapter: RuntimeHostAdapter.androidVpnService,
      ),
      supportState: RuntimeExecutionPlanSupportState.unavailable,
      remoteEndpointFamily: RuntimeRemoteEndpointFamily.turnServer,
      isDefault: true,
      requiredTransportProfileKinds: <TransportProfileKind>[
        TransportProfileKind.wireGuardNativeV1,
      ],
      transportProfile: _missingTransportProfilePrerequisite,
      message: 'VPN transport profile wireguard_native_v1 is not configured.',
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
    Capability.vpnTransportProfileStore,
    Capability.sessions,
    Capability.challenges,
    Capability.diagnostics,
    Capability.eventStream,
  ],
  platformTunnels: <PlatformTunnelCapability>[
    PlatformTunnelCapability(
      mode: PlatformTunnelMode.androidVpnService,
      available: false,
      supportedUnderlayRoutePolicies: <PlatformTunnelUnderlayRoutePolicy>[
        PlatformTunnelUnderlayRoutePolicy.standard,
        PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork,
      ],
      executionPlans: <RuntimeExecutionPlanDescriptor>[
        _androidVpnExecutionPlanDescriptor,
      ],
      missingPrerequisite: PlatformTunnelPrerequisite.hostImplementation,
      message: 'mobile host does not implement tunnel startup yet',
    ),
  ],
  transportProfileStore: _transportProfileStoreCapability,
);

const HostInfo _hostInfoWithoutSupportedAndroidExecutionPath = HostInfo(
  contractVersion: '1',
  build: _testHostBuild,
  capabilities: <Capability>[
    Capability.mobileHostBridge,
    Capability.platformTunnels,
    Capability.profiles,
    Capability.providerConfigs,
    Capability.providerRuntimeArtifacts,
    Capability.runtimeExecutionPlanning,
    Capability.vpnTransportProfileStore,
    Capability.sessions,
    Capability.challenges,
    Capability.diagnostics,
    Capability.eventStream,
  ],
  platformTunnels: <PlatformTunnelCapability>[
    PlatformTunnelCapability(
      mode: PlatformTunnelMode.androidVpnService,
      available: false,
      supportedUnderlayRoutePolicies: <PlatformTunnelUnderlayRoutePolicy>[
        PlatformTunnelUnderlayRoutePolicy.standard,
        PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork,
      ],
      executionPlans: <RuntimeExecutionPlanDescriptor>[
        _unavailableAndroidVpnExecutionPlanDescriptor,
      ],
      missingPrerequisite: PlatformTunnelPrerequisite.hostImplementation,
      message:
          'The android/arm64 host does not yet implement the strict TURN datagram WireGuard carrier/materializer required for mode android_vpn_service.',
    ),
  ],
  transportProfileStore: _transportProfileStoreCapability,
);

const HostInfo _hostInfoMissingTransportProfile = HostInfo(
  contractVersion: '1',
  build: _testHostBuild,
  capabilities: <Capability>[
    Capability.mobileHostBridge,
    Capability.platformTunnels,
    Capability.profiles,
    Capability.providerConfigs,
    Capability.providerRuntimeArtifacts,
    Capability.runtimeExecutionPlanning,
    Capability.vpnTransportProfileStore,
    Capability.sessions,
    Capability.challenges,
    Capability.diagnostics,
    Capability.eventStream,
  ],
  platformTunnels: <PlatformTunnelCapability>[
    PlatformTunnelCapability(
      mode: PlatformTunnelMode.androidVpnService,
      available: true,
      satisfiedPrerequisites: <PlatformTunnelPrerequisite>[
        PlatformTunnelPrerequisite.routeExclusion,
        PlatformTunnelPrerequisite.dnsBypass,
      ],
      supportedUnderlayRoutePolicies: <PlatformTunnelUnderlayRoutePolicy>[
        PlatformTunnelUnderlayRoutePolicy.standard,
        PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork,
      ],
      executionPlans: <RuntimeExecutionPlanDescriptor>[
        _missingProfileAndroidVpnExecutionPlanDescriptor,
      ],
      message: 'Android VPN Service is available after profile setup.',
    ),
  ],
  transportProfileStore: _transportProfileStoreCapability,
);

const HostInfo _readyHostInfoWithoutDevelopmentRouting = HostInfo(
  contractVersion: '1',
  build: _testHostBuild,
  capabilities: <Capability>[
    Capability.mobileHostBridge,
    Capability.platformTunnels,
    Capability.profiles,
    Capability.providerConfigs,
    Capability.providerRuntimeArtifacts,
    Capability.runtimeExecutionPlanning,
    Capability.vpnTransportProfileStore,
    Capability.sessions,
    Capability.challenges,
    Capability.diagnostics,
    Capability.eventStream,
  ],
  platformTunnels: <PlatformTunnelCapability>[
    PlatformTunnelCapability(
      mode: PlatformTunnelMode.androidVpnService,
      available: false,
      supportedUnderlayRoutePolicies: <PlatformTunnelUnderlayRoutePolicy>[
        PlatformTunnelUnderlayRoutePolicy.standard,
      ],
      executionPlans: <RuntimeExecutionPlanDescriptor>[
        _androidVpnExecutionPlanDescriptor,
      ],
      missingPrerequisite: PlatformTunnelPrerequisite.hostImplementation,
      message: 'mobile host does not implement tunnel startup yet',
    ),
  ],
  transportProfileStore: _transportProfileStoreCapability,
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

List<TransportProfileStatus> _transportProfileStatuses() {
  return <TransportProfileStatus>[
    TransportProfileStatus(
      id: _androidTransportProfileReference.profileId,
      kind: TransportProfileKind.wireGuardNativeV1,
      version: '1',
      displayName: 'WireGuard',
      validation: const TransportProfileValidationStatus(
        state: TransportProfileValidationState.valid,
        fingerprint: 'sha256:testprofile',
      ),
      compatibility: const TransportProfileCompatibilityStatus(
        state: TransportProfileCompatibilityState.compatible,
        compatibleExecutionPlans: <RuntimeExecutionPlan>[
          RuntimeExecutionPlan(
            accessMethod: RuntimeAccessMethod.turnCredentials,
            carrierFamily: RuntimeCarrierFamily.turnDatagram,
            engineFamily: RuntimeEngineFamily.wireguardNative,
            hostAdapter: RuntimeHostAdapter.androidVpnService,
          ),
        ],
      ),
      secretMaterialRef: const TransportProfileSecretMaterialRef(
        kind: TransportProfileMaterialSource.importAdapter,
        ref: 'host-owned:transport-profile-1',
      ),
      actions: const <TransportProfileLifecycleAction>[
        TransportProfileLifecycleAction.replace,
        TransportProfileLifecycleAction.forget,
        TransportProfileLifecycleAction.validate,
        TransportProfileLifecycleAction.selectForStartup,
      ],
      importedAt: DateTime.utc(2026, 4, 28, 12),
      updatedAt: DateTime.utc(2026, 4, 28, 12),
    ),
  ];
}

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
  TestWidgetsFlutterBinding.ensureInitialized();

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
    'controller restores current profile separately from focused detail state',
    () async {
      final alpha = ProfileRecord(
        id: 'profile-1',
        name: 'alpha',
        spec: _profileSpec(),
      );
      final beta = ProfileRecord(
        id: 'profile-2',
        name: 'beta',
        spec: _profileSpec().copyWith(link: 'https://vk.com/call/join/beta'),
      );
      final controller = MobileShellController(
        bridge: _FakeMobileHostBridge(),
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: <ProfileRecord>[alpha, beta],
            providerConfigs: const <ProviderConfigRecord>[],
            initialCurrentProfileId: alpha.id,
            initialFocusedProfileId: beta.id,
            draft: ProfileDraft.fromProfile(beta),
          ),
        ),
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(controller.selectedProfileId, alpha.id);
      expect(controller.focusedProfileId, beta.id);
      expect(controller.selectedSavedProfile?.id, alpha.id);
      expect(controller.focusedSavedProfile?.id, beta.id);
      expect(controller.draft.id, beta.id);
      expect(controller.draft.name, beta.name);
    },
  );

  test(
    'controller duplicateSelectedProfile seeds a new draft without mutating the source or current target',
    () async {
      final alpha = ProfileRecord(
        id: 'profile-1',
        name: 'alpha',
        spec: _profileSpec(),
      );
      final beta = ProfileRecord(
        id: 'profile-2',
        name: 'beta',
        spec: _profileSpec().copyWith(link: 'https://vk.com/call/join/beta'),
      );
      final controller = MobileShellController(
        bridge: _FakeMobileHostBridge(),
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: <ProfileRecord>[alpha, beta],
            providerConfigs: const <ProviderConfigRecord>[],
            initialCurrentProfileId: alpha.id,
            initialFocusedProfileId: beta.id,
            draft: ProfileDraft.fromProfile(beta),
          ),
        ),
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      expect(controller.focusedProfileId, beta.id);
      expect(controller.focusedSavedProfile?.id, beta.id);
      controller.duplicateSelectedProfile();

      expect(controller.profiles, hasLength(2));
      expect(controller.selectedProfileId, alpha.id);
      expect(controller.focusedProfileId, isNull);
      expect(controller.draft.id, isNull);
      expect(controller.draft.name, 'beta copy');
      expect(controller.draft.spec.link, beta.spec.link);
      expect(controller.notice, contains('beta'));
    },
  );

  test(
    'controller duplicateSelectedManagedProvider and duplicateSelectedProviderTemplate preserve source records',
    () async {
      final managedProvider = _managedProviderRecord(
        id: 'provider-config-1',
        name: 'VK Saved',
      );
      final template = ProviderTemplateRecord(
        id: 'template-1',
        provider: 'vk',
        name: 'VK Template',
        providerSettings: const <String, dynamic>{'region': 'eu-west'},
        createdAt: DateTime.utc(2026, 4, 17, 12, 0),
        updatedAt: DateTime.utc(2026, 4, 17, 12, 1),
      );
      final controller = MobileShellController(
        bridge: _FakeMobileHostBridge(
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
        ),
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: const <ProfileRecord>[],
            managedProviders: <ManagedProviderRecord>[managedProvider],
            providerTemplates: <ProviderTemplateRecord>[template],
            draft: ProfileDraft.defaults(),
          ),
        ),
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      controller.focusManagedProvider(managedProvider.id);
      expect(controller.selectedManagedProviderId, managedProvider.id);
      controller.duplicateSelectedManagedProvider();

      expect(controller.managedProviders.single.name, 'VK Saved');
      expect(controller.selectedManagedProviderId, isNull);
      expect(controller.managedProviderDraft.id, isNull);
      expect(controller.managedProviderDraft.name, 'VK Saved copy');

      controller.focusProviderTemplate(template.id);
      expect(controller.selectedProviderTemplateId, template.id);
      controller.duplicateSelectedProviderTemplate();

      expect(controller.providerTemplates.single.name, 'VK Template');
      expect(controller.selectedProviderTemplateId, isNull);
      expect(controller.providerTemplateDraft.id, isNull);
      expect(controller.providerTemplateDraft.name, 'VK Template copy');
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
      expect(controller.hostConnection?.state, MobileHostLifecycleState.ready);
      expect(controller.activeModeSupportsAppRouting, isTrue);
      expect(
        controller.notice,
        contains('Secure profile secrets are unavailable'),
      );
      expect(bridge.ensureReadyCalls, 1);
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
      expect(bridge.ensureReadyCalls, 2);
      expect(controller.profiles, isEmpty);
    },
  );

  test(
    'controller clears remembered embedded sign-in through the dedicated resetter',
    () async {
      final resetter = _FakeOwnedBrowserSessionStateResetter();
      final controller = MobileShellController(
        bridge: _FakeMobileHostBridge(),
        stateStore: _InMemoryStateStore(MobileShellState.empty()),
        ownedBrowserSessionStateResetter: resetter,
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.clearRememberedEmbeddedSignIn();

      expect(resetter.clearCalls, 1);
      expect(controller.busy, isFalse);
      expect(controller.notice, 'Cleared remembered embedded sign-in.');
    },
  );

  test(
    'controller clears the selected reusable resolution when forgetting embedded sign-in',
    () async {
      final resetter = _FakeOwnedBrowserSessionStateResetter();
      final profile = ProfileRecord(
        id: 'profile-1',
        name: 'vk live',
        spec: _profileSpec(),
      );
      final bridge = _FakeMobileHostBridge(
        resolutionsList: <ResolutionRecord>[_resolutionRecord()],
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
        ownedBrowserSessionStateResetter: resetter,
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      controller.selectResolution('resolution-1');

      await controller.clearRememberedEmbeddedSignIn();

      expect(resetter.clearCalls, 1);
      expect(controller.selectedResolutionId, isNull);
      expect(controller.notice, 'Cleared remembered embedded sign-in.');
    },
  );

  test(
    'controller starts a fresh resolution after forgetting embedded sign-in instead of reusing a resolved artifact',
    () async {
      final resetter = _FakeOwnedBrowserSessionStateResetter();
      final profile = ProfileRecord(
        id: 'profile-1',
        name: 'vk live',
        spec: _profileSpec(),
      );
      final bridge = _FakeMobileHostBridge(
        resolutionsList: <ResolutionRecord>[
          _resolutionRecord(id: 'resolution-resolved-1'),
        ],
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
        ownedBrowserSessionStateResetter: resetter,
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      expect(controller.selectedResolutionId, 'resolution-resolved-1');

      await controller.clearRememberedEmbeddedSignIn();
      await controller.startPlatformTunnel(
        PlatformTunnelMode.androidVpnService,
      );

      expect(resetter.clearCalls, 1);
      expect(bridge.startResolutionCalls, hasLength(1));
      expect(bridge.startedPlatformTunnelResolutionIDs, <String?>[
        'resolution-1',
      ]);
      expect(controller.selectedResolutionId, 'resolution-1');
    },
  );

  test(
    'controller surfaces platform reset errors for remembered embedded sign-in without double wrapping',
    () async {
      final resetter = _FakeOwnedBrowserSessionStateResetter(
        error: const MobileHostPlatformActionError('native reset failed'),
      );
      final controller = MobileShellController(
        bridge: _FakeMobileHostBridge(),
        stateStore: _InMemoryStateStore(MobileShellState.empty()),
        ownedBrowserSessionStateResetter: resetter,
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.clearRememberedEmbeddedSignIn();

      expect(resetter.clearCalls, 1);
      expect(controller.busy, isFalse);
      expect(controller.notice, 'native reset failed');
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
      expect(controller.notice, contains('Opened action "Open room"'));
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
    'controller exports selected profiles through the mobile portable transfer adapter',
    () async {
      final adapter = _FakeMobilePortableProfileTransferAdapter();
      final controller = MobileShellController(
        bridge: _FakeMobileHostBridge(
          profilesList: <ProfileRecord>[
            ProfileRecord(id: 'profile-1', name: 'alpha', spec: _profileSpec()),
          ],
        ),
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: <ProfileRecord>[
              ProfileRecord(
                id: 'profile-1',
                name: 'alpha',
                spec: _profileSpec(),
              ),
            ],
            providerConfigs: const <ProviderConfigRecord>[],
            selectedProfileId: 'profile-1',
            initialFocusedProfileId: 'profile-1',
            draft: ProfileDraft.fromProfile(
              ProfileRecord(
                id: 'profile-1',
                name: 'alpha',
                spec: _profileSpec(),
              ),
            ),
          ),
        ),
        portableProfileTransferAdapter: adapter,
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      final envelope = controller.selectedPortableProfileEnvelope();
      expect(envelope, isNotNull);

      await controller.copyPortableProfileEnvelopeText(envelope!);
      await controller.sharePortableProfileEnvelopeText(envelope);
      await controller.sharePortableProfileEnvelopeFile(envelope);

      expect(adapter.copiedPayloads, hasLength(1));
      expect(adapter.sharedTextPayloads, hasLength(1));
      expect(adapter.sharedFilePayloads, hasLength(1));
      expect(
        adapter.sharedSuggestedNames.single,
        'alpha.portable-profile.json',
      );
      expect(controller.notice, contains('portable profile'));
    },
  );

  test(
    'controller imports managed portable profiles append-only with fresh ids',
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
        clock: () => DateTime.utc(2026, 4, 17, 12, 0),
        appBuild: _testGuiBuild,
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

      expect(bridge.upsertedProfiles, hasLength(1));
      final savedProfile = bridge.upsertedProfiles.single;
      expect(savedProfile.id, isNot('remote-profile'));
      expect(savedProfile.id, startsWith('portable-'));
      expect(controller.selectedProfileId, savedProfile.id);
      expect(
        controller.profileBindings[savedProfile.id]?.mode,
        ProfileProviderMode.managed,
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
      expect(bridge.startedPlatformTunnels, isEmpty);
      expect(bridge.startResolutionCalls, isEmpty);
    },
  );

  test(
    'controller fails closed for unsupported portable import payloads',
    () async {
      final controller = MobileShellController(
        bridge: _FakeMobileHostBridge(),
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
    'controller stages inbound portable profile ingress for preview before import',
    () async {
      final adapter = _FakeMobilePortableProfileTransferAdapter();
      final controller = MobileShellController(
        bridge: _FakeMobileHostBridge(),
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: const <ProfileRecord>[],
            providerConfigs: const <ProviderConfigRecord>[],
            draft: ProfileDraft.defaults(),
          ),
        ),
        portableProfileTransferAdapter: adapter,
        appBuild: _testGuiBuild,
      );
      addTearDown(() async {
        await adapter.dispose();
        controller.dispose();
      });

      await controller.initialize();

      adapter.emitIngressPayload(
        PortableProfileEnvelope.build(
          profile: ProfileRecord(
            id: 'remote-profile',
            name: 'Inbound alpha',
            spec: _profileSpec().copyWith(link: ''),
          ),
          providerBinding: const ProfileProviderBinding(
            mode: ProfileProviderMode.custom,
          ),
        ).encode(),
      );
      await Future<void>.delayed(Duration.zero);

      final pending = controller.pendingPortableProfileImportEnvelope;
      expect(pending, isNotNull);
      expect(pending?.displayName, 'Inbound alpha');
      expect(controller.workflowSurface, MobileWorkflowSurface.profile);
      expect(controller.profiles, isEmpty);

      controller.clearPendingPortableProfileImportPreview();
      expect(controller.pendingPortableProfileImportEnvelope, isNull);
    },
  );

  test(
    'controller clears stale notices when the profile draft changes',
    () async {
      final controller = MobileShellController(
        bridge: _FakeMobileHostBridge(),
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
      controller.notice = 'input.link is required';

      controller.updateDraft(
        controller.draft.copyWith(
          spec: controller.draft.spec.copyWith(
            link: 'https://vk.com/call/join/fresh',
          ),
        ),
      );

      expect(controller.notice, isNull);
      expect(controller.draft.spec.link, 'https://vk.com/call/join/fresh');
    },
  );

  test('controller auto-dismisses saved profile notices', () async {
    final controller = MobileShellController(
      bridge: _FakeMobileHostBridge(),
      stateStore: _InMemoryStateStore(MobileShellState.empty()),
      appBuild: _testGuiBuild,
      transientNoticeDuration: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.saveDraft();

    expect(controller.notice, contains('Saved mobile profile'));

    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(controller.notice, isNull);
  });

  test('controller keeps non-transient notices sticky', () async {
    final controller = MobileShellController(
      bridge: _FakeMobileHostBridge(),
      stateStore: _InMemoryStateStore(MobileShellState.empty()),
      appBuild: _testGuiBuild,
      transientNoticeDuration: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    controller.notice = 'input.link is required';

    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(controller.notice, 'input.link is required');
  });

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

  test('controller localizes shell-owned mobile notices in Russian', () async {
    await AppLocale.ru.build();
    LocaleSettings.setLocaleSync(AppLocale.ru);
    addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.en));

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
    controller.managedProviders = const <ManagedProviderRecord>[];
    controller.selectedManagedProviderId = null;
    controller.draft = ProfileDraft.defaults();
    controller.activateManagedProviderMode();
    expect(controller.notice, 'Управляемые провайдеры пока недоступны.');

    await controller.startResolutionFromDraft();
    expect(
      controller.notice,
      'Выбранный провайдер не объявлен подключенным мобильным хостом.',
    );
  });

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
    'controller blocks strict Android VPN startup when runtime defaults still point to loopback',
    () async {
      final bridge = _FakeMobileHostBridge(
        resolutionsList: <ResolutionRecord>[
          _resolutionRecord(id: 'resolution-android-loopback-1'),
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
      await controller.startPlatformTunnel(
        PlatformTunnelMode.androidVpnService,
      );

      expect(bridge.startResolutionCalls, isEmpty);
      expect(bridge.startedPlatformTunnels, isEmpty);
      expect(
        controller.platformTunnelResultFor(
          PlatformTunnelMode.androidVpnService,
        ),
        isNull,
      );
      expect(controller.notice, contains('loopback peer 127.0.0.1:56000'));
      expect(
        controller.notice,
        contains('Configure an operator-managed remote peer endpoint'),
      );
    },
  );

  test(
    'controller consumes typed platform tunnel reports and startup-stage results',
    () async {
      final profile = ProfileRecord(
        id: 'profile-1',
        name: 'vk live',
        spec: _profileSpec(),
      );
      final bridge = _FakeMobileHostBridge(
        resolutionsList: <ResolutionRecord>[
          _resolutionRecord(id: 'resolution-android-1'),
        ],
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
      await controller.startPlatformTunnel(
        PlatformTunnelMode.androidVpnService,
      );

      expect(bridge.startedPlatformTunnels, <PlatformTunnelMode>[
        PlatformTunnelMode.androidVpnService,
      ]);
      expect(bridge.startedPlatformTunnelResolutionIDs, <String?>[
        'resolution-android-1',
      ]);
      expect(bridge.startedPlatformTunnelRuntimeDefaults, hasLength(1));
      final runtimeDefaults =
          bridge.startedPlatformTunnelRuntimeDefaults.single;
      final expectedDefaults = RuntimeDefaults.fromProfileSpec(profile.spec);
      expect(runtimeDefaults, isNotNull);
      expect(runtimeDefaults?.listenAddress, expectedDefaults.listenAddress);
      expect(runtimeDefaults?.peerAddress, expectedDefaults.peerAddress);
      expect(runtimeDefaults?.turnServer, expectedDefaults.turnServer);
      expect(runtimeDefaults?.turnPort, expectedDefaults.turnPort);
      expect(bridge.startedPlatformTunnelExecutionPlans, hasLength(1));
      expect(
        bridge.startedPlatformTunnelExecutionPlans.single?.engineFamily,
        _androidVpnExecutionPlanDescriptor.plan.engineFamily,
      );
      expect(
        bridge.startedPlatformTunnelRoutingPolicies,
        <PlatformTunnelApplicationRoutingPolicy>[
          PlatformTunnelApplicationRoutingPolicy.allApps,
        ],
      );
      expect(
        bridge.startedPlatformTunnelUnderlayRoutePolicies,
        <PlatformTunnelUnderlayRoutePolicy>[
          PlatformTunnelUnderlayRoutePolicy.standard,
        ],
      );
      expect(bridge.startedPlatformTunnelAllowedPackages.single, isEmpty);
      expect(bridge.startedPlatformTunnelDisallowedPackages.single, isEmpty);
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
    'controller blocks platform tunnel startup when no supported execution path is advertised',
    () async {
      final profile = ProfileRecord(
        id: 'profile-1',
        name: 'vk live',
        spec: _profileSpec(),
      );
      final bridge = _FakeMobileHostBridge(
        ensureReadyResult: const MobileHostConnectionResult(
          state: MobileHostLifecycleState.ready,
          message: 'Connected to embedded mobile host bridge',
          info: _hostInfoWithoutSupportedAndroidExecutionPath,
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

      expect(controller.activeExecutionPlan, isNull);
      expect(
        controller.platformTunnelStartPreparationBlockReason(
          PlatformTunnelMode.androidVpnService,
        ),
        contains('strict TURN datagram WireGuard carrier/materializer'),
      );

      await controller.startPlatformTunnel(
        PlatformTunnelMode.androidVpnService,
      );

      expect(bridge.startResolutionCalls, isEmpty);
      expect(bridge.startedPlatformTunnels, isEmpty);
      expect(
        controller.notice,
        contains('strict TURN datagram WireGuard carrier/materializer'),
      );
      expect(controller.notice, isNot(contains('Select an execution path')));
    },
  );

  test(
    'controller uses VPN transport profile store before platform tunnel startup',
    () async {
      final profile = ProfileRecord(
        id: 'profile-1',
        name: 'vk live',
        spec: _profileSpec(),
      );
      final bridge = _FakeMobileHostBridge(
        ensureReadyResult: const MobileHostConnectionResult(
          state: MobileHostLifecycleState.ready,
          message: 'Connected to embedded mobile host bridge',
          info: _hostInfoMissingTransportProfile,
          description: 'native bridge',
        ),
        transportProfilesList: const <TransportProfileStatus>[],
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
        transportProfileContentPicker: () async => 'wg-profile',
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(controller.canConfigureVPNTransportProfile, isTrue);
      expect(
        controller.activeVPNTransportProfileStatusSummary,
        contains('not configured'),
      );
      expect(
        controller.platformTunnelStartPreparationBlockReason(
          PlatformTunnelMode.androidVpnService,
        ),
        contains('VPN transport profile'),
      );

      await controller.startPlatformTunnel(
        PlatformTunnelMode.androidVpnService,
      );

      expect(bridge.startResolutionCalls, isEmpty);
      expect(bridge.startedPlatformTunnels, isEmpty);

      await controller.importVPNTransportProfile();

      expect(controller.activeVPNTransportProfileConfigured, isTrue);
      expect(
        controller.activeVPNTransportProfileStatusSummary,
        contains('WireGuard profile: configured'),
      );
      expect(
        controller.platformTunnelStartPreparationBlockReason(
          PlatformTunnelMode.androidVpnService,
        ),
        isNull,
      );

      await controller.startPlatformTunnel(
        PlatformTunnelMode.androidVpnService,
      );

      expect(bridge.startResolutionCalls, hasLength(1));
      expect(bridge.startedPlatformTunnels, <PlatformTunnelMode>[
        PlatformTunnelMode.androidVpnService,
      ]);
      expect(
        bridge.startedPlatformTunnelProfiles.single?.profileId,
        'transport-profile-1',
      );

      await controller.forgetVPNTransportProfile();

      expect(controller.activeVPNTransportProfileConfigured, isFalse);
      expect(
        controller.activeVPNTransportProfileStatusSummary,
        contains('not configured'),
      );
      expect(
        controller.platformTunnelStartPreparationBlockReason(
          PlatformTunnelMode.androidVpnService,
        ),
        contains('VPN transport profile'),
      );
    },
  );

  test(
    'controller refreshes host info before re-evaluating VPN transport profile prerequisite',
    () async {
      final profile = ProfileRecord(
        id: 'profile-1',
        name: 'vk live',
        spec: _profileSpec(),
      );
      final bridge = _FakeMobileHostBridge(
        ensureReadyResult: const MobileHostConnectionResult(
          state: MobileHostLifecycleState.ready,
          message: 'Connected to embedded mobile host bridge',
          info: _hostInfoMissingTransportProfile,
          description: 'native bridge',
        ),
        transportProfilesList: const <TransportProfileStatus>[],
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
      expect(
        controller.platformTunnelStartPreparationBlockReason(
          PlatformTunnelMode.androidVpnService,
        ),
        contains('VPN transport profile'),
      );

      bridge._hostInfo = _readyHostInfo;
      bridge._transportProfiles.addAll(_transportProfileStatuses());
      await controller.refresh();

      expect(bridge.hostInfoCalls, greaterThanOrEqualTo(1));
      expect(
        controller.activeVPNTransportProfileStatusSummary,
        contains('WireGuard profile: configured'),
      );
      expect(
        controller.platformTunnelStartPreparationBlockReason(
          PlatformTunnelMode.androidVpnService,
        ),
        isNull,
      );
    },
  );

  test(
    'controller resolves the active draft before platform tunnel startup when no resolution is selected',
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
      expect(controller.selectedResolutionId, isNull);

      await controller.startPlatformTunnel(
        PlatformTunnelMode.androidVpnService,
      );

      expect(bridge.startResolutionCalls, hasLength(1));
      expect(bridge.startResolutionCalls.single.provider, 'vk');
      expect(
        bridge.startResolutionCalls.single.input.link,
        'https://vk.com/call/join/test',
      );
      expect(bridge.startedPlatformTunnels, <PlatformTunnelMode>[
        PlatformTunnelMode.androidVpnService,
      ]);
      expect(bridge.startedPlatformTunnelResolutionIDs, <String?>[
        'resolution-1',
      ]);
      expect(controller.selectedResolutionId, 'resolution-1');
    },
  );

  test(
    'controller keeps challenge-required resolutions explicit instead of starting a duplicate platform tunnel path',
    () async {
      final profile = ProfileRecord(
        id: 'profile-1',
        name: 'vk live',
        spec: _profileSpec(),
      );
      final challenge = ChallengeRecord(
        id: 'challenge-1',
        sessionId: '',
        resolutionId: 'resolution-challenge-1',
        provider: 'vk',
        stage: 'provider_resolve',
        kind: 'browser',
        prompt: 'Complete the browser step, then return here.',
        openUrl: 'https://vk.com/call/join/test',
        status: ChallengeStatus.pending,
        createdAt: DateTime.utc(2026, 4, 10, 12, 0),
        updatedAt: DateTime.utc(2026, 4, 10, 12, 1),
      );
      final bridge = _FakeMobileHostBridge(
        resolutionsList: <ResolutionRecord>[
          _resolutionRecord(
            id: 'resolution-challenge-1',
            state: ResolutionState.challengeRequired,
            activeChallengeId: challenge.id,
          ),
        ],
        challengeMap: <String, ChallengeRecord>{challenge.id: challenge},
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
      expect(controller.selectedResolutionId, 'resolution-challenge-1');

      await controller.startPlatformTunnel(
        PlatformTunnelMode.androidVpnService,
      );

      expect(bridge.startResolutionCalls, isEmpty);
      expect(bridge.startedPlatformTunnels, isEmpty);
      expect(
        controller.notice,
        contains('Complete the current provider challenge'),
      );
    },
  );

  test(
    'controller forwards selected app-routing policy to platform tunnel startup',
    () async {
      final bridge = _FakeMobileHostBridge(
        resolutionsList: <ResolutionRecord>[
          _resolutionRecord(id: 'resolution-android-routing-1'),
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
      controller.updateApplicationRoutingPolicy(
        PlatformTunnelApplicationRoutingPolicy.allowedPackages,
      );
      controller.updateRoutingPackageSelection(
        packageName: 'org.signal',
        selected: true,
      );

      await controller.startPlatformTunnel(
        PlatformTunnelMode.androidVpnService,
      );

      expect(
        bridge.startedPlatformTunnelRoutingPolicies,
        <PlatformTunnelApplicationRoutingPolicy>[
          PlatformTunnelApplicationRoutingPolicy.allowedPackages,
        ],
      );
      expect(bridge.startedPlatformTunnelAllowedPackages.single, <String>[
        'org.signal',
      ]);
      expect(bridge.startedPlatformTunnelDisallowedPackages.single, isEmpty);
    },
  );

  test(
    'controller updates app-routing package selection in bulk for the active policy',
    () async {
      final controller = MobileShellController(
        bridge: _FakeMobileHostBridge(),
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
      controller.updateApplicationRoutingPolicy(
        PlatformTunnelApplicationRoutingPolicy.allowedPackages,
      );

      controller.updateRoutingPackageSelectionBatch(
        packageNames: <String>[
          'org.telegram.messenger',
          'org.signal',
          'org.signal',
        ],
        selected: true,
      );

      expect(controller.activePlatformModePreferences.allowedPackages, <String>[
        'org.signal',
        'org.telegram.messenger',
      ]);

      controller.updateRoutingPackageSelectionBatch(
        packageNames: const <String>['org.signal'],
        selected: false,
      );

      expect(controller.activePlatformModePreferences.allowedPackages, <String>[
        'org.telegram.messenger',
      ]);
    },
  );

  test(
    'controller forwards development underlay route policy to platform tunnel startup',
    () async {
      final bridge = _FakeMobileHostBridge(
        resolutionsList: <ResolutionRecord>[
          _resolutionRecord(id: 'resolution-android-underlay-1'),
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
      controller.updateUnderlayRoutePolicy(
        PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork,
      );

      await controller.startPlatformTunnel(
        PlatformTunnelMode.androidVpnService,
      );

      expect(
        bridge.startedPlatformTunnelUnderlayRoutePolicies,
        <PlatformTunnelUnderlayRoutePolicy>[
          PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork,
        ],
      );
    },
  );

  test(
    'controller fails closed when the saved development underlay profile is unsupported by the host',
    () async {
      final bridge = _FakeMobileHostBridge(
        ensureReadyResult: const MobileHostConnectionResult(
          state: MobileHostLifecycleState.ready,
          message: 'Connected to embedded mobile host bridge',
          info: _readyHostInfoWithoutDevelopmentRouting,
          description: 'native bridge',
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
            platformModePreferences:
                const <String, MobilePlatformModePreferences>{
                  'profile-1::android_vpn_service':
                      MobilePlatformModePreferences(
                        underlayRoutePolicy: PlatformTunnelUnderlayRoutePolicy
                            .preserveActiveLocalNetwork,
                      ),
                },
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

      expect(bridge.startResolutionCalls, isEmpty);
      expect(bridge.startedPlatformTunnels, isEmpty);
      expect(bridge.startedPlatformTunnelUnderlayRoutePolicies, isEmpty);
      expect(controller.notice, contains('Development Wi-Fi'));
      expect(controller.notice, contains('does not advertise'));
    },
  );

  test(
    'controller requests Android VPN permission and resumes the same startup attempt',
    () async {
      final profile = ProfileRecord(
        id: 'profile-1',
        name: 'vk live',
        spec: _profileSpec(),
      );
      final bridge = _FakeMobileHostBridge(
        resolutionsList: <ResolutionRecord>[
          _resolutionRecord(id: 'resolution-android-1'),
        ],
        startPlatformTunnelResult: const PlatformTunnelStartResult(
          mode: PlatformTunnelMode.androidVpnService,
          ready: false,
          stage: PlatformTunnelStartupStage.permissionAcquire,
          missingPrerequisite: PlatformTunnelPrerequisite.permission,
          startupAttemptId: 'attempt-android-1',
          message: 'Android VPN permission is required.',
        ),
        resumePlatformTunnelResult: const PlatformTunnelStartResult(
          mode: PlatformTunnelMode.androidVpnService,
          ready: false,
          stage: PlatformTunnelStartupStage.runtimeAttach,
          missingPrerequisite: PlatformTunnelPrerequisite.hostImplementation,
          message: 'Runtime attach is still unavailable in this fixture.',
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
      await controller.startPlatformTunnel(
        PlatformTunnelMode.androidVpnService,
      );

      expect(bridge.requestedPlatformTunnelPermissions, <PlatformTunnelMode>[
        PlatformTunnelMode.androidVpnService,
      ]);
      expect(bridge.resumedPlatformTunnelAttemptIDs, <String>[
        'attempt-android-1',
      ]);
      expect(
        controller
            .platformTunnelResultFor(PlatformTunnelMode.androidVpnService)
            ?.stage,
        PlatformTunnelStartupStage.runtimeAttach,
      );
      expect(controller.notice, contains('Runtime attach'));
    },
  );

  test(
    'controller focuses the returned session_id after a ready platform tunnel startup',
    () async {
      final profile = ProfileRecord(
        id: 'profile-1',
        name: 'vk live',
        spec: _profileSpec(),
      );
      final bridge = _FakeMobileHostBridge(
        resolutionsList: <ResolutionRecord>[
          _resolutionRecord(id: 'resolution-android-1'),
        ],
        sessionsList: <SessionRecord>[
          SessionRecord(
            id: 'session-other',
            profileId: 'profile-1',
            profileName: 'vk live',
            profile: _profileSpec(),
            state: SessionState.ready,
            startedAt: DateTime.utc(2026, 4, 7, 14, 5),
            updatedAt: DateTime.utc(2026, 4, 7, 14, 6),
          ),
          SessionRecord(
            id: 'session-android-1',
            profileId: 'profile-1',
            profileName: 'vk live',
            profile: _profileSpec(),
            state: SessionState.ready,
            startedAt: DateTime.utc(2026, 4, 7, 14, 0),
            updatedAt: DateTime.utc(2026, 4, 7, 14, 1),
            sourceResolutionId: 'resolution-android-1',
          ),
        ],
        startPlatformTunnelResult: const PlatformTunnelStartResult(
          mode: PlatformTunnelMode.androidVpnService,
          ready: true,
          sessionId: 'session-android-1',
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
      expect(controller.selectedSessionId, 'session-other');

      await controller.startPlatformTunnel(
        PlatformTunnelMode.androidVpnService,
      );

      expect(controller.selectedSessionId, 'session-android-1');
    },
  );

  test(
    'controller falls back to source_resolution_id when a ready platform tunnel omits session_id',
    () async {
      final profile = ProfileRecord(
        id: 'profile-1',
        name: 'vk live',
        spec: _profileSpec(),
      );
      final bridge = _FakeMobileHostBridge(
        resolutionsList: <ResolutionRecord>[
          _resolutionRecord(id: 'resolution-android-1'),
        ],
        sessionsList: <SessionRecord>[
          SessionRecord(
            id: 'session-other',
            profileId: 'profile-1',
            profileName: 'vk live',
            profile: _profileSpec(),
            state: SessionState.ready,
            startedAt: DateTime.utc(2026, 4, 7, 14, 5),
            updatedAt: DateTime.utc(2026, 4, 7, 14, 6),
          ),
          SessionRecord(
            id: 'session-android-1',
            profileId: 'profile-1',
            profileName: 'vk live',
            profile: _profileSpec(),
            state: SessionState.ready,
            startedAt: DateTime.utc(2026, 4, 7, 14, 0),
            updatedAt: DateTime.utc(2026, 4, 7, 14, 1),
            sourceResolutionId: 'resolution-android-1',
          ),
        ],
        startPlatformTunnelResult: const PlatformTunnelStartResult(
          mode: PlatformTunnelMode.androidVpnService,
          ready: true,
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
      expect(controller.selectedSessionId, 'session-other');

      await controller.startPlatformTunnel(
        PlatformTunnelMode.androidVpnService,
      );

      expect(controller.selectedSessionId, 'session-android-1');
    },
  );

  test(
    'controller rehydrates ready platform tunnel state from host status on initialize',
    () async {
      final profile = ProfileRecord(
        id: 'profile-1',
        name: 'vk live',
        spec: _profileSpec(),
      );
      final bridge = _FakeMobileHostBridge(
        sessionsList: <SessionRecord>[
          SessionRecord(
            id: 'session-android-1',
            profileId: 'profile-1',
            profileName: 'vk live',
            profile: _profileSpec(),
            state: SessionState.ready,
            startedAt: DateTime.utc(2026, 4, 7, 14, 0),
            updatedAt: DateTime.utc(2026, 4, 7, 14, 1),
            sourceResolutionId: 'resolution-android-1',
          ),
        ],
        platformTunnelStatusesList: <PlatformTunnelStatus>[
          PlatformTunnelStatus(
            mode: PlatformTunnelMode.androidVpnService,
            state: PlatformTunnelLifecycleState.ready,
            ready: true,
            sessionId: 'session-android-1',
            sourceResolutionId: 'resolution-android-1',
            underlayRoutePolicy: PlatformTunnelUnderlayRoutePolicy.standard,
            updatedAt: DateTime.utc(2026, 4, 7, 14, 1),
          ),
        ],
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

      expect(bridge.startedPlatformTunnels, isEmpty);
      expect(
        controller
            .platformTunnelResultFor(PlatformTunnelMode.androidVpnService)
            ?.ready,
        isTrue,
      );
      expect(
        controller
            .platformTunnelStatusFor(PlatformTunnelMode.androidVpnService)
            ?.state,
        PlatformTunnelLifecycleState.ready,
      );
      expect(controller.selectedSessionId, 'session-android-1');
    },
  );

  test(
    'controller removes stale ready state when host status reports stopped',
    () async {
      final profile = ProfileRecord(
        id: 'profile-1',
        name: 'vk live',
        spec: _profileSpec(),
      );
      final bridge = _FakeMobileHostBridge(
        platformTunnelStatusesList: <PlatformTunnelStatus>[
          PlatformTunnelStatus(
            mode: PlatformTunnelMode.androidVpnService,
            state: PlatformTunnelLifecycleState.ready,
            ready: true,
            sessionId: 'session-android-1',
            updatedAt: DateTime.utc(2026, 4, 7, 14, 1),
          ),
        ],
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
      expect(
        controller
            .platformTunnelResultFor(PlatformTunnelMode.androidVpnService)
            ?.ready,
        isTrue,
      );

      bridge._replacePlatformTunnelStatus(
        PlatformTunnelStatus(
          mode: PlatformTunnelMode.androidVpnService,
          state: PlatformTunnelLifecycleState.stopped,
          ready: false,
          sessionId: 'session-android-1',
          message: 'Android VPN Service disconnected.',
          updatedAt: DateTime.utc(2026, 4, 7, 14, 2),
        ),
      );
      await controller.refresh();

      expect(
        controller.platformTunnelResultFor(
          PlatformTunnelMode.androidVpnService,
        ),
        isNull,
      );
      expect(
        controller
            .platformTunnelStatusFor(PlatformTunnelMode.androidVpnService)
            ?.state,
        PlatformTunnelLifecycleState.stopped,
      );
    },
  );

  test('controller clears ready platform tunnel state after stop', () async {
    final profile = ProfileRecord(
      id: 'profile-1',
      name: 'vk live',
      spec: _profileSpec(),
    );
    final bridge = _FakeMobileHostBridge(
      startPlatformTunnelResult: const PlatformTunnelStartResult(
        mode: PlatformTunnelMode.androidVpnService,
        ready: true,
      ),
      stopPlatformTunnelResult: const PlatformTunnelStopResult(
        mode: PlatformTunnelMode.androidVpnService,
        stopped: true,
        message: 'Android VPN Service disconnected.',
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
    await controller.startPlatformTunnel(PlatformTunnelMode.androidVpnService);
    expect(
      controller
          .platformTunnelResultFor(PlatformTunnelMode.androidVpnService)
          ?.ready,
      isTrue,
    );

    await controller.stopPlatformTunnel(PlatformTunnelMode.androidVpnService);

    expect(bridge.stoppedPlatformTunnels, <PlatformTunnelMode>[
      PlatformTunnelMode.androidVpnService,
    ]);
    expect(
      controller.platformTunnelResultFor(PlatformTunnelMode.androidVpnService),
      isNull,
    );
    expect(controller.notice, 'Android VPN Service disconnected.');
  });

  test(
    'controller requires a restart after changing the underlay route profile while the tunnel is ready',
    () async {
      final profile = ProfileRecord(
        id: 'profile-1',
        name: 'vk live',
        spec: _profileSpec(),
      );
      final bridge = _FakeMobileHostBridge(
        resolutionsList: <ResolutionRecord>[
          _resolutionRecord(id: 'resolution-android-ready-1'),
        ],
        startPlatformTunnelResult: const PlatformTunnelStartResult(
          mode: PlatformTunnelMode.androidVpnService,
          ready: true,
          underlayRoutePolicy: PlatformTunnelUnderlayRoutePolicy.standard,
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
      await controller.startPlatformTunnel(
        PlatformTunnelMode.androidVpnService,
      );

      controller.updateUnderlayRoutePolicy(
        PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork,
      );

      expect(controller.activeUnderlayRoutePolicyRequiresRestart, isTrue);
      expect(controller.notice, contains('Restart'));
      expect(controller.notice, contains('routing profile'));
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

class _InMemoryStateStore implements MobileShellStateStore {
  const _InMemoryStateStore(this.state);

  final MobileShellState state;

  @override
  Future<MobileShellState?> load() async => state;

  @override
  Future<void> save(
    MobileShellState state, {
    Iterable<ProviderDescriptor> providerDescriptors =
        const <ProviderDescriptor>[],
  }) async {}

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

class _FakeOwnedBrowserSessionStateResetter
    implements MobileOwnedBrowserSessionStateResetter {
  _FakeOwnedBrowserSessionStateResetter({this.error});

  final Object? error;
  int clearCalls = 0;

  @override
  Future<void> clearSessionState() async {
    clearCalls += 1;
    if (error != null) {
      throw error!;
    }
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
    List<ProfileRecord>? profilesList,
    List<ResolutionRecord>? resolutionsList,
    List<TransportProfileStatus>? transportProfilesList,
    List<PlatformTunnelStatus>? platformTunnelStatusesList,
    this.sessionsList = const <SessionRecord>[],
    this.challengeMap = const <String, ChallengeRecord>{},
    this.startSessionError,
    this.startPlatformTunnelResult = const PlatformTunnelStartResult(
      mode: PlatformTunnelMode.androidVpnService,
      ready: false,
      stage: PlatformTunnelStartupStage.capabilityCheck,
      missingPrerequisite: PlatformTunnelPrerequisite.hostImplementation,
      message: 'mobile host does not implement tunnel startup yet',
    ),
    this.resumePlatformTunnelResult = const PlatformTunnelStartResult(
      mode: PlatformTunnelMode.androidVpnService,
      ready: false,
      stage: PlatformTunnelStartupStage.permissionAcquire,
      missingPrerequisite: PlatformTunnelPrerequisite.permission,
      startupAttemptId: 'attempt-android-1',
      message: 'mobile host does not implement tunnel resume yet',
    ),
    this.stopPlatformTunnelResult = const PlatformTunnelStopResult(
      mode: PlatformTunnelMode.androidVpnService,
      stopped: true,
      message: 'Android VPN Service disconnected.',
    ),
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
       _profiles = List<ProfileRecord>.of(
         profilesList ?? const <ProfileRecord>[],
       ),
       _resolutions = List<ResolutionRecord>.of(
         resolutionsList ?? const <ResolutionRecord>[],
       ),
       _hostInfo = ensureReadyResult.info ?? _readyHostInfo,
       _transportProfiles = List<TransportProfileStatus>.of(
         transportProfilesList ?? _transportProfileStatuses(),
       ),
       _platformTunnelStatuses = List<PlatformTunnelStatus>.of(
         platformTunnelStatusesList ?? const <PlatformTunnelStatus>[],
       );

  final MobileHostConnectionResult ensureReadyResult;
  HostInfo _hostInfo;
  final List<ProviderDescriptor> _providers;
  final List<ProviderConfigRecord> _providerConfigs;
  final List<ProfileRecord> _profiles;
  final List<SessionRecord> sessionsList;
  final List<TransportProfileStatus> _transportProfiles;
  final List<PlatformTunnelStatus> _platformTunnelStatuses;
  final Map<String, ChallengeRecord> challengeMap;
  final ControlPlaneError? startSessionError;
  final PlatformTunnelStartResult startPlatformTunnelResult;
  final PlatformTunnelStartResult resumePlatformTunnelResult;
  final PlatformTunnelStopResult stopPlatformTunnelResult;
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
  final List<String?> startedPlatformTunnelResolutionIDs = <String?>[];
  final List<RuntimeDefaults?> startedPlatformTunnelRuntimeDefaults =
      <RuntimeDefaults?>[];
  final List<RuntimeExecutionPlan?> startedPlatformTunnelExecutionPlans =
      <RuntimeExecutionPlan?>[];
  final List<TransportProfileReference?> startedPlatformTunnelProfiles =
      <TransportProfileReference?>[];
  final List<PlatformTunnelApplicationRoutingPolicy>
  startedPlatformTunnelRoutingPolicies =
      <PlatformTunnelApplicationRoutingPolicy>[];
  final List<PlatformTunnelUnderlayRoutePolicy>
  startedPlatformTunnelUnderlayRoutePolicies =
      <PlatformTunnelUnderlayRoutePolicy>[];
  final List<List<String>> startedPlatformTunnelAllowedPackages =
      <List<String>>[];
  final List<List<String>> startedPlatformTunnelDisallowedPackages =
      <List<String>>[];
  final List<PlatformTunnelMode> requestedPlatformTunnelPermissions =
      <PlatformTunnelMode>[];
  final List<String> resumedPlatformTunnelAttemptIDs = <String>[];
  final List<PlatformTunnelMode> stoppedPlatformTunnels =
      <PlatformTunnelMode>[];
  int ensureReadyCalls = 0;
  int hostInfoCalls = 0;
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
  Future<List<TransportProfileStatus>> transportProfiles() async =>
      _transportProfiles;

  @override
  Future<List<PlatformTunnelStatus>> platformTunnelStatuses() async =>
      _platformTunnelStatuses;

  @override
  Future<TransportProfileStatus> importTransportProfile(
    TransportProfileImportRequest request,
  ) async {
    final replacementID = request.replaceProfileId.trim();
    final profileID = replacementID.isEmpty
        ? 'transport-profile-${_transportProfiles.length + 1}'
        : replacementID;
    final profile = _transportProfileStatuses().first;
    final next = TransportProfileStatus(
      id: profileID,
      kind: request.kind,
      version: profile.version,
      displayName: request.displayName,
      validation: profile.validation,
      compatibility: profile.compatibility,
      secretMaterialRef: TransportProfileSecretMaterialRef(
        kind: TransportProfileMaterialSource.importAdapter,
        ref: 'host-owned:$profileID',
      ),
      actions: profile.actions,
      importedAt: profile.importedAt,
      updatedAt: DateTime.utc(2026, 4, 28, 12, _transportProfiles.length),
    );
    _transportProfiles
      ..removeWhere((TransportProfileStatus current) => current.id == profileID)
      ..add(next);
    _hostInfo = _readyHostInfo;
    return next;
  }

  @override
  Future<TransportProfileStructuredSaveResult> createStructuredTransportProfile(
    TransportProfileStructuredCreateRequest request,
  ) async {
    final profile = _transportProfileStatuses().first;
    final profileID = 'transport-profile-${_transportProfiles.length + 1}';
    final next = TransportProfileStatus(
      id: profileID,
      kind: request.draft.kind,
      version: profile.version,
      displayName: request.draft.displayName,
      validation: profile.validation,
      compatibility: profile.compatibility,
      secretMaterialRef: TransportProfileSecretMaterialRef(
        kind: TransportProfileMaterialSource.structuredEditor,
        ref: 'host-owned:$profileID',
      ),
      actions: profile.actions,
      importedAt: profile.importedAt,
      updatedAt: DateTime.utc(2026, 4, 28, 12, _transportProfiles.length),
    );
    _transportProfiles.add(next);
    _hostInfo = _readyHostInfo;
    return TransportProfileStructuredSaveResult(profile: next);
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
      (TransportProfileStatus current) => current.id == profileId,
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
      (TransportProfileStatus current) => current.id == profileId,
    );
    _hostInfo = _hostInfoMissingTransportProfile;
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
    return MobileHostConnectionResult(
      state: ensureReadyResult.state,
      message: ensureReadyResult.message,
      info: _hostInfo,
      description: ensureReadyResult.description,
    );
  }

  @override
  Stream<EventRecord> events() => _events.stream;

  @override
  Future<HostInfo> hostInfo() async {
    hostInfoCalls += 1;
    return _hostInfo;
  }

  @override
  Future<HostInfo> negotiate({
    required List<String> supportedVersions,
    required List<Capability> requiredCapabilities,
  }) async {
    final info = _hostInfo;
    if (ensureReadyResult.state == MobileHostLifecycleState.incompatible) {
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
    String? resolutionId,
    RuntimeDefaults? runtimeDefaults,
    RuntimeExecutionPlan? executionPlan,
    TransportProfileReference? transportProfile,
    PlatformTunnelApplicationRoutingPolicy applicationRoutingPolicy =
        PlatformTunnelApplicationRoutingPolicy.allApps,
    List<String> allowedPackages = const <String>[],
    List<String> disallowedPackages = const <String>[],
    PlatformTunnelUnderlayRoutePolicy underlayRoutePolicy =
        PlatformTunnelUnderlayRoutePolicy.standard,
  }) async {
    startedPlatformTunnels.add(mode);
    startedPlatformTunnelResolutionIDs.add(resolutionId);
    startedPlatformTunnelRuntimeDefaults.add(runtimeDefaults);
    startedPlatformTunnelExecutionPlans.add(executionPlan);
    startedPlatformTunnelProfiles.add(transportProfile);
    startedPlatformTunnelRoutingPolicies.add(applicationRoutingPolicy);
    startedPlatformTunnelUnderlayRoutePolicies.add(underlayRoutePolicy);
    startedPlatformTunnelAllowedPackages.add(List<String>.of(allowedPackages));
    startedPlatformTunnelDisallowedPackages.add(
      List<String>.of(disallowedPackages),
    );
    _replacePlatformTunnelStatus(
      _statusFromPlatformTunnelStartResult(startPlatformTunnelResult),
    );
    return startPlatformTunnelResult;
  }

  @override
  Future<PlatformTunnelStartResult> resumePlatformTunnel({
    required String startupAttemptId,
  }) async {
    resumedPlatformTunnelAttemptIDs.add(startupAttemptId);
    _replacePlatformTunnelStatus(
      _statusFromPlatformTunnelStartResult(resumePlatformTunnelResult),
    );
    return resumePlatformTunnelResult;
  }

  @override
  Future<PlatformTunnelStopResult> stopPlatformTunnel({
    required PlatformTunnelMode mode,
  }) async {
    stoppedPlatformTunnels.add(mode);
    _replacePlatformTunnelStatus(
      PlatformTunnelStatus(
        mode: mode,
        state: PlatformTunnelLifecycleState.stopped,
        ready: false,
        message: stopPlatformTunnelResult.message,
        updatedAt: DateTime.utc(2026, 4, 7, 14, 10),
      ),
    );
    return stopPlatformTunnelResult;
  }

  @override
  Future<bool> requestPlatformTunnelPermission({
    required PlatformTunnelMode mode,
  }) async {
    requestedPlatformTunnelPermissions.add(mode);
    return true;
  }

  @override
  Future<List<ProviderDescriptor>> providers() async => _providers;

  @override
  Future<List<ProviderConfigRecord>> providerConfigs() async =>
      _providerConfigs;

  @override
  Future<List<ProfileRecord>> profiles() async => _profiles;

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
    _profiles.removeWhere(
      (ProfileRecord existing) => existing.id == profile.id,
    );
    _profiles.add(profile);
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

  void _replacePlatformTunnelStatus(PlatformTunnelStatus status) {
    _platformTunnelStatuses
      ..removeWhere(
        (PlatformTunnelStatus current) => current.mode == status.mode,
      )
      ..add(status);
  }

  PlatformTunnelStatus _statusFromPlatformTunnelStartResult(
    PlatformTunnelStartResult result,
  ) {
    final state = result.ready
        ? PlatformTunnelLifecycleState.ready
        : result.stage == PlatformTunnelStartupStage.permissionAcquire &&
              result.missingPrerequisite ==
                  PlatformTunnelPrerequisite.permission &&
              result.startupAttemptId.isNotEmpty
        ? PlatformTunnelLifecycleState.permission
        : result.stage == PlatformTunnelStartupStage.profileValidate ||
              result.missingPrerequisite ==
                  PlatformTunnelPrerequisite.transportProfile
        ? PlatformTunnelLifecycleState.setupNeeded
        : PlatformTunnelLifecycleState.failed;
    return PlatformTunnelStatus(
      mode: result.mode,
      state: state,
      ready: result.ready,
      sessionId: result.sessionId,
      executionPlan: result.executionPlan,
      transportProfile: result.transportProfile,
      remoteIngress: result.remoteIngress,
      underlayRoutePolicy: result.underlayRoutePolicy,
      stage: result.stage,
      missingPrerequisite: result.missingPrerequisite,
      startupAttemptId: result.startupAttemptId,
      message: result.message,
      updatedAt: DateTime.utc(2026, 4, 7, 14, 9),
    );
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
  Future<void> save(
    MobileShellState state, {
    Iterable<ProviderDescriptor> providerDescriptors =
        const <ProviderDescriptor>[],
  }) async {}
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

class _FakeMobilePortableProfileTransferAdapter
    implements MobilePortableProfileTransferAdapter {
  final List<String> copiedPayloads = <String>[];
  final List<String> sharedTextPayloads = <String>[];
  final List<String> sharedFilePayloads = <String>[];
  final List<String> sharedSuggestedNames = <String>[];
  final StreamController<String> _ingressPayloads =
      StreamController<String>.broadcast();
  String? nextOpenedPayload;

  void emitIngressPayload(String payload) {
    _ingressPayloads.add(payload);
  }

  Future<void> dispose() => _ingressPayloads.close();

  @override
  Future<void> copyEnvelopeText(String payload) async {
    copiedPayloads.add(payload);
  }

  @override
  Stream<String> get ingressPayloads => _ingressPayloads.stream;

  @override
  Future<String?> openEnvelopeText() async => nextOpenedPayload;

  @override
  Future<void> shareEnvelopeFile({
    required String suggestedName,
    required String payload,
  }) async {
    sharedSuggestedNames.add(suggestedName);
    sharedFilePayloads.add(payload);
  }

  @override
  Future<void> shareEnvelopeText(String payload) async {
    sharedTextPayloads.add(payload);
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
  Future<void> save(
    MobileShellState state, {
    Iterable<ProviderDescriptor> providerDescriptors =
        const <ProviderDescriptor>[],
  }) async {}
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
