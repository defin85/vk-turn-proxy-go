import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_shell_core/shell_visuals.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gui_shell/src/app.dart';
import 'package:gui_shell/src/control/control_plane_client.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/desktop_host_supervisor.dart';
import 'package:gui_shell/src/control/desktop_shell_controller.dart';
import 'package:gui_shell/src/control/profile_draft.dart';
import 'package:gui_shell/src/control/shell_state_store.dart';
import 'package:gui_shell/src/ui/dashboard_page.dart';

import 'test_i18n.dart';

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
    ],
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

const ProviderDescriptor _supportedProviderWithSettingsDescriptor =
    ProviderDescriptor(
      id: 'vk',
      displayName: 'VK Calls',
      description: 'Managed provider settings fixture for a shipped provider.',
      inputKind: ProviderInputKind.link,
      authPosture: ProviderAuthPosture.guestOrAccount,
      browserPolicy: ProviderBrowserPolicy.externalRequired,
      artifactFamilies: <ArtifactFamily>[ArtifactFamily.genericTurn],
      settingsSchema: ProviderSettingsSchema(
        type: 'object',
        additionalProperties: false,
        requiredKeys: <String>['region'],
        properties: <String, ProviderSettingProperty>{
          'region': ProviderSettingProperty(
            type: ProviderSettingType.string,
            title: 'Region',
            enumValues: <dynamic>['ru-central', 'eu-west'],
            defaultValue: 'ru-central',
            control: ProviderSettingControl.select,
            persistence: ProviderSettingPersistence.profile,
          ),
        },
      ),
    );

const ProviderDescriptor _supportedProviderWithUnsupportedSettingsDescriptor =
    ProviderDescriptor(
      id: 'vk',
      displayName: 'VK Calls',
      description:
          'Unsupported reusable settings fixture for a shipped provider.',
      inputKind: ProviderInputKind.link,
      authPosture: ProviderAuthPosture.guestOrAccount,
      browserPolicy: ProviderBrowserPolicy.externalRequired,
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

Future<void> _openProfileMoreActions(WidgetTester tester) async {
  final finder = find.byKey(
    const ValueKey<String>('profile-editor-more-actions-button'),
  );
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _selectProfileMoreAction(
  WidgetTester tester,
  String actionKey,
) async {
  await _openProfileMoreActions(tester);
  await tester.tap(find.byKey(ValueKey<String>(actionKey)).last);
  await tester.pumpAndSettle();
}

Future<void> _openProviderMoreActions(WidgetTester tester) async {
  final finder = find.byKey(
    const ValueKey<String>('managed-provider-more-actions-button'),
  );
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _selectProviderMoreAction(
  WidgetTester tester,
  String actionKey,
) async {
  await _openProviderMoreActions(tester);
  await tester.tap(find.byKey(ValueKey<String>(actionKey)).last);
  await tester.pumpAndSettle();
}

Future<void> _openProfileFromLibrary(
  WidgetTester tester,
  String profileId,
) async {
  final finder = find.byKey(
    ValueKey<String>('profile-library-item-$profileId'),
  );
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _createDraftFromProfileLibrary(WidgetTester tester) async {
  final finder = find.byKey(
    const ValueKey<String>('profile-create-draft-button'),
  );
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _createManagedProviderFromLibrary(
  WidgetTester tester, {
  String providerId = 'vk',
}) async {
  final createFinder = find.byKey(
    const ValueKey<String>('managed-provider-create-button'),
  );
  await tester.ensureVisible(createFinder);
  await tester.tap(createFinder);
  await tester.pumpAndSettle();

  final providerFinder = find.byKey(
    ValueKey<String>('supported-provider-card-$providerId'),
  );
  await tester.ensureVisible(providerFinder);
  await tester.tap(providerFinder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('desktop shell test helper pins translated chrome labels', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = DesktopShellController(
      api: _FakeControlPlaneApi(),
      supervisor: const _FakeHostSupervisor(),
      stateStore: const _InMemoryShellStateStore(),
      appBuild: _testGuiBuild,
    );
    await controller.initialize();
    await pumpDesktopShellTestApp(
      tester,
      controller: controller,
      locale: AppLocale.ru,
    );

    expect(
      find.byKey(const ValueKey<String>('desktop-open-diagnostics-button')),
      findsOneWidget,
    );
    expect(find.text('Профили'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('desktop-section-rail')),
      findsOneWidget,
    );
    expect(find.text('Workflow'), findsNothing);
    expect(find.byTooltip('Сменить язык'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('desktop-section-settings')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Сменить язык'), findsWidgets);
  });

  testWidgets('desktop home starts windows vpn from the primary action', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _FakeControlPlaneApi(
      startPlatformTunnelResult: const PlatformTunnelStartResult(
        mode: PlatformTunnelMode.windowsWintun,
        ready: true,
        sessionId: 'platform-session-1',
      ),
    );
    final controller = DesktopShellController(
      api: api,
      supervisor: const _FakeHostSupervisor(
        result: HostConnectionResult(
          state: HostLifecycleState.ready,
          message: 'Connected to local host 127.0.0.1:7777',
          info: _readyWindowsWintunHostInfo,
        ),
      ),
      stateStore: const _InMemoryShellStateStore(),
      appBuild: _testGuiBuild,
    );

    await controller.initialize();
    await pumpDesktopShellTestApp(tester, controller: controller);

    expect(find.text('Turn on VPN'), findsOneWidget);
    await tester.tap(find.text('Turn on VPN'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(api.startedPlatformTunnels, <PlatformTunnelMode>[
      PlatformTunnelMode.windowsWintun,
    ]);
    expect(api.startedProfileIDs, isEmpty);
    expect(controller.selectedSessionId, 'platform-session-1');
    expect(find.text('Turn off VPN'), findsOneWidget);
  });

  testWidgets(
    'desktop shell exposes VPN transport profile setup before start',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final hostInfo = _desktopTransportProfileHostInfo(configured: false);
      final api = _FakeControlPlaneApi(hostInfo: hostInfo);
      final controller = DesktopShellController(
        api: api,
        supervisor: _FakeHostSupervisor(
          result: HostConnectionResult(
            state: HostLifecycleState.ready,
            message: 'Connected to local host 127.0.0.1:7777',
            info: hostInfo,
          ),
        ),
        stateStore: const _InMemoryShellStateStore(),
        transportProfileContentPicker: () async => 'wg-profile',
        appBuild: _testGuiBuild,
      );

      await controller.initialize();
      await pumpDesktopShellTestApp(tester, controller: controller);

      expect(find.text('Setup needed'), findsOneWidget);
      expect(find.text('Import VPN profile'), findsOneWidget);
      expect(
        find.text('VPN transport profile: not configured.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Import VPN profile'));
      await tester.pumpAndSettle();

      expect(
        controller.activeWorkbenchRoute,
        DesktopWorkbenchRoute.vpnTransportProfiles,
      );
      expect(
        find.byKey(
          const ValueKey<String>('desktop-vpn-transport-profiles-workbench'),
        ),
        findsOneWidget,
      );
      expect(find.byType(Dialog), findsNothing);
      expect(api.importTransportProfileCalls, isEmpty);

      await tester.tap(
        find.byKey(const ValueKey<String>('desktop-canvas-route-back-button')),
      );
      await tester.pumpAndSettle();
      expect(controller.activeWorkbenchRoute, DesktopWorkbenchRoute.home);

      await tester.tap(
        find.byKey(const ValueKey<String>('desktop-section-routing')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>(
            'desktop-routing-import-vpn-transport-profile-windows_wintun',
          ),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('WireGuard .conf'), findsWidgets);

      await tester.tap(find.text('Import VPN profile').first);
      await tester.pumpAndSettle();

      expect(api.importTransportProfileCalls, hasLength(1));
      expect(find.text('Request startup'), findsNothing);
      expect(find.text('WireGuard profile: configured.'), findsWidgets);
      expect(find.text('Replace VPN profile'), findsWidgets);
      expect(find.text('Forget VPN profile'), findsWidgets);

      await tester.tap(
        find.byKey(const ValueKey<String>('desktop-section-home')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turn on VPN'));
      await tester.pumpAndSettle();

      expect(api.startedPlatformTunnels, <PlatformTunnelMode>[
        PlatformTunnelMode.windowsWintun,
      ]);
      expect(
        api.startedPlatformTunnelProfiles.single?.profileId,
        'transport-profile-1',
      );
    },
  );

  testWidgets('desktop shell consumes the shared RelayDock visual contract', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = DesktopShellController(
      api: _FakeControlPlaneApi(),
      supervisor: const _FakeHostSupervisor(),
      stateStore: const _InMemoryShellStateStore(),
      appBuild: _testGuiBuild,
    );
    await controller.initialize();
    await pumpDesktopShellTestApp(
      tester,
      controller: controller,
      locale: AppLocale.en,
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final theme = app.theme!;
    final visuals = theme.extension<ShellVisualTheme>();
    final copy = tester.element(find.byType(MaterialApp)).shellText;

    expect(theme.colorScheme.primary, const Color(0xFF214B66));
    expect(visuals, isNotNull);
    expect(find.byType(ShellToneBadge), findsNothing);
    expect(find.text('Current profile'), findsOneWidget);
    expect(find.text('Current mode'), findsOneWidget);
    expect(find.text('Need deeper detail?'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('desktop-open-profile-library-button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('desktop-open-diagnostics-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tunnel detail'));
    await tester.pumpAndSettle();

    final labels = tester
        .widgetList<ShellToneBadge>(find.byType(ShellToneBadge))
        .map((ShellToneBadge badge) => badge.label)
        .toList(growable: false);
    expect(labels, contains(copy.unavailableLowercase));
  });

  testWidgets(
    'desktop shell localizes deep workflow and inspector surfaces in Russian',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api = _FakeControlPlaneApi();
      final controller = DesktopShellController(
        api: api,
        supervisor: const _FakeHostSupervisor(),
        stateStore: const _InMemoryShellStateStore(),
        appBuild: _testGuiBuild,
      );
      await controller.initialize();
      await pumpDesktopShellTestApp(
        tester,
        controller: controller,
        locale: AppLocale.ru,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('desktop-open-profile-library-button'),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.activeWorkbenchRoute, DesktopWorkbenchRoute.profiles);
      expect(
        find.byKey(
          const ValueKey<String>('saved-profiles-library-surface-desktop'),
        ),
        findsOneWidget,
      );
      await _openProfileFromLibrary(tester, 'profile-1');
      expect(find.text('Настройки профиля'), findsWidgets);
      expect(find.text('VK Calls'), findsWidgets);
      expect(find.text('Прямой ввод'), findsWidgets);

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('profile-start-action')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('profile-start-action')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Текущая работа'), findsWidgets);

      await tester.tap(
        find.byKey(const ValueKey<String>('desktop-open-activity-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('support-sessions-surface-desktop')),
        findsOneWidget,
      );
      expect(find.text('Сессии (1)'), findsOneWidget);
      expect(find.text('Остановить сессию'), findsOneWidget);

      controller.showDiagnosticsRoute();
      await tester.pumpAndSettle();

      expect(find.text('Диагностика'), findsWidgets);

      await tester.tap(find.text('Детали туннеля'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>(
            'support-diagnostics-overview-surface-desktop',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Платформенные туннельные режимы'), findsOneWidget);
      expect(find.text('Запросить запуск'), findsNothing);
      expect(find.textContaining('Локальный хост'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await api.dispose();
    },
  );

  testWidgets(
    'desktop shell waits for owned host shutdown before app exit completes',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final supervisor = _TrackingHostSupervisor();
      final controller = DesktopShellController(
        api: _FakeControlPlaneApi(),
        supervisor: supervisor,
        stateStore: const _InMemoryShellStateStore(),
        appBuild: _testGuiBuild,
      );

      await tester.pumpWidget(DesktopShellApp(controller: controller));
      await tester.pump();

      var exitResolved = false;
      final exitFuture = WidgetsBinding.instance.handleRequestAppExit().then((
        ui.AppExitResponse response,
      ) {
        exitResolved = true;
        return response;
      });

      await tester.pump();

      expect(supervisor.disposeCalls, 1);
      expect(exitResolved, isFalse);

      supervisor.completeDispose();

      expect(await exitFuture, ui.AppExitResponse.exit);
      expect(exitResolved, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(supervisor.disposeCalls, 1);
    },
  );

  testWidgets('desktop shell exit does not hang on event stream cancellation', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _HangingEventCancelControlPlaneApi();
    final supervisor = _TrackingHostSupervisor();
    final controller = DesktopShellController(
      api: api,
      supervisor: supervisor,
      stateStore: const _InMemoryShellStateStore(),
      appBuild: _testGuiBuild,
    );

    await controller.initialize();
    await tester.pumpWidget(DesktopShellApp(controller: controller));
    await tester.pumpAndSettle();

    final exitFuture = WidgetsBinding.instance.handleRequestAppExit();
    await tester.pump();

    expect(supervisor.disposeCalls, 1);
    supervisor.completeDispose();

    await tester.pump(const Duration(milliseconds: 300));

    expect(await exitFuture, ui.AppExitResponse.exit);
    expect(api.cancelAttempts, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'desktop shell shows connecting state before host negotiation completes',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = DesktopShellController(
        api: _FakeControlPlaneApi(),
        supervisor: _FakeHostSupervisor(),
        stateStore: const _InMemoryShellStateStore(),
        appBuild: _testGuiBuild,
      );

      await tester.pumpWidget(
        MaterialApp(home: DashboardPage(controller: controller)),
      );
      await tester.pump();

      expect(find.text('Connecting to local host'), findsWidgets);
      expect(
        find.text('Starting local host and negotiating capabilities.'),
        findsOneWidget,
      );
      expect(find.text('Local host blocked'), findsNothing);
      expect(find.text('Overview'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('desktop-section-home')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('desktop-open-diagnostics-button')),
        findsOneWidget,
      );

      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'desktop shell surfaces incompatible host state from the shell bar',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const incompatibleMessage =
          'Host contract 2 is incompatible with GUI contract 1. Update the desktop bundle.';
      final controller = DesktopShellController(
        api: _FakeControlPlaneApi(),
        supervisor: const _FakeHostSupervisor(
          result: HostConnectionResult(
            state: HostLifecycleState.incompatible,
            message: incompatibleMessage,
          ),
        ),
        stateStore: const _InMemoryShellStateStore(),
        appBuild: _testGuiBuild,
      );

      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(home: DashboardPage(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(controller.status, ShellStatus.blocked);
      expect(controller.hostConnection?.state, HostLifecycleState.incompatible);
      expect(find.text('Local host blocked'), findsWidgets);
      expect(find.textContaining('Update the desktop bundle'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('desktop-open-diagnostics-button')),
        findsOneWidget,
      );
      expect(find.text('Overview'), findsWidgets);

      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('desktop shell keeps saved-profile navigation separate', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = DesktopShellController(
      api: _FakeControlPlaneApi(),
      supervisor: _FakeHostSupervisor(),
      stateStore: const _InMemoryShellStateStore(),
      appBuild: _testGuiBuild,
    );

    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(home: DashboardPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('profile-library-item-profile-2')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('desktop-open-profile-library-button')),
    );
    await tester.pumpAndSettle();

    expect(controller.activeWorkbenchRoute, DesktopWorkbenchRoute.profiles);
    expect(controller.activeCanvasRoute, DesktopCanvasRoute.savedProfilePicker);
    expect(
      find.byKey(
        const ValueKey<String>('saved-profiles-library-surface-desktop'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('desktop-canvas-route-back-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('profile-library-item-profile-2')),
      findsOneWidget,
    );
    await _openProfileFromLibrary(tester, 'profile-2');

    expect(controller.selectedProfileId, 'profile-2');
    expect(controller.draft.name, 'beta');
    expect(controller.activeCanvasRoute, DesktopCanvasRoute.profileEditor);
    expect(
      find.byKey(
        const ValueKey<String>('saved-profiles-library-surface-desktop'),
      ),
      findsNothing,
    );

    await _selectProfileMoreAction(
      tester,
      'desktop-open-saved-profile-picker-button',
    );

    expect(controller.activeCanvasRoute, DesktopCanvasRoute.savedProfilePicker);
    expect(
      find.byKey(
        const ValueKey<String>('saved-profiles-library-surface-desktop'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('desktop-canvas-route-back-button')),
      findsOneWidget,
    );

    controller.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'desktop shell closes secondary surfaces without changing workflow context',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = DesktopShellController(
        api: _FakeControlPlaneApi(),
        supervisor: _FakeHostSupervisor(),
        stateStore: const _InMemoryShellStateStore(),
        appBuild: _testGuiBuild,
      );

      await controller.initialize();
      controller.updateDraft(controller.draft.copyWith(name: 'Keep context'));
      await tester.pumpWidget(
        MaterialApp(home: DashboardPage(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(controller.activeWorkbenchRoute, DesktopWorkbenchRoute.profiles);
      expect(controller.draft.name, 'Keep context');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(controller.isInspectorOpen, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(controller.isInspectorOpen, isFalse);
      expect(controller.activeWorkbenchRoute, DesktopWorkbenchRoute.profiles);
      expect(controller.draft.name, 'Keep context');

      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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

    expect(find.text('Local host ready'), findsWidgets);
    expect(controller.selectedProfileId, 'profile-1');
    expect(find.text('GUI 0.1.0+1 @gui123456789'), findsNothing);
    expect(find.text('Host 0.1.0+1 @deadbeefcafe'), findsNothing);
    expect(find.text('Contract 1'), findsNothing);
    expect(find.text('Overview'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('desktop-open-diagnostics-button')),
      findsOneWidget,
    );
    expect(find.text('Live work'), findsWidgets);
    expect(find.text('127.0.0.1:7777'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('profile-library-item-profile-1')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('desktop-section-settings')),
    );
    await tester.pumpAndSettle();

    expect(find.text('GUI 0.1.0+1 @gui123456789'), findsOneWidget);
    expect(find.text('Host 0.1.0+1 @deadbeefcafe'), findsOneWidget);
    expect(find.text('Contract 1'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('desktop-section-home')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('desktop-section-profiles')),
    );
    await tester.pumpAndSettle();
    await _openProfileFromLibrary(tester, 'profile-1');
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('profile-start-action')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('profile-start-action')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(api.startedProfileIDs, <String>['profile-1']);
    expect(find.textContaining('Started session'), findsOneWidget);
    expect(find.text('Live work'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey<String>('desktop-open-activity-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('support-sessions-surface-desktop')),
      findsOneWidget,
    );
    expect(find.text('Sessions (1)'), findsOneWidget);
    expect(find.text('ready'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey<String>('desktop-open-diagnostics-button')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tunnel detail'));
    await tester.pumpAndSettle();

    expect(find.text('Platform tunnel modes'), findsOneWidget);
    expect(
      find.text(
        'The desktop shell reads typed host tunnel capabilities and startup stages instead of guessing system routing support from the OS or app bundle.',
      ),
      findsWidgets,
    );
    expect(find.text('Windows Wintun'), findsOneWidget);
    expect(find.text('Linux TUN'), findsNothing);
    expect(find.text('Apple Network Extension'), findsNothing);
    expect(
      find.textContaining('host implementation is still missing'),
      findsOneWidget,
    );
    expect(find.text('Request startup', skipOffstage: false), findsNothing);
    expect(api.startedPlatformTunnels, isEmpty);

    controller.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(api.dispose());
  });

  testWidgets(
    'desktop profile editor shows disabled start session action for unsaved draft',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = DesktopShellController(
        api: _FakeControlPlaneApi(),
        supervisor: _FakeHostSupervisor(),
        stateStore: const _InMemoryShellStateStore(),
        appBuild: _testGuiBuild,
      );

      await controller.initialize();
      controller.resetDraft();
      await tester.pumpWidget(
        MaterialApp(home: DashboardPage(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('profile-start-action')),
        findsNothing,
      );
      final resolveButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey<String>('profile-resolve-action')),
      );
      expect(resolveButton.onPressed, isNotNull);
      expect(
        find.byKey(const ValueKey<String>('profile-save-action')),
        findsOneWidget,
      );

      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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

    expect(find.text('Live work'), findsWidgets);
    await tester.tap(
      find.byKey(const ValueKey<String>('desktop-open-activity-button')),
    );
    await tester.pumpAndSettle();

    final resolutionsScrollable = find
        .descendant(
          of: find.byKey(const ValueKey<String>('resolutions-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    final openRoomButton = find.text('Open room', skipOffstage: false);
    await tester.scrollUntilVisible(
      openRoomButton,
      320,
      scrollable: resolutionsScrollable,
    );
    await tester.pumpAndSettle();
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

  testWidgets('desktop shell keeps unavailable presets explicit', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _FakeControlPlaneApi(
      providers: <ProviderDescriptor>[_providerDescriptors.first],
    );
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
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('desktop-section-profiles')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey<String>('managed-provider-more-actions-button'),
      ),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('desktop-section-provider')),
    );
    await tester.pumpAndSettle();
    expect(controller.activeWorkbenchRoute, DesktopWorkbenchRoute.providers);
    await _selectProviderMoreAction(
      tester,
      'desktop-open-preset-bootstrap-button',
    );

    expect(
      find.textContaining(
        'does not advertise the Generic TURN provider family yet',
      ),
      findsWidgets,
    );

    controller.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(api.dispose());
  });

  testWidgets('desktop providers route renders provider source catalog', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _FakeControlPlaneApi(
      providerSources: const <RemoteProviderSourceDescriptor>[
        RemoteProviderSourceDescriptor(
          endpointId: 'vps-176',
          providerId: 'vk',
          sourceId: 'vk-turn-vps',
          displayName: 'VK TURN VPS',
          sourceFamily: 'vps',
          healthStatus: 'healthy',
          evidenceStatus: 'fresh',
          validationStatus: 'valid',
          artifactOffers: <RemoteProviderArtifactOffer>[
            RemoteProviderArtifactOffer(
              offerId: 'wg-turn',
              family: 'turn',
              validationStatus: 'valid',
              accessMethods: <String>['turn_credentials'],
              compatibleProfileKinds: <TransportProfileKind>[
                TransportProfileKind.wireGuardNativeV1,
              ],
            ),
          ],
        ),
      ],
    );
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
    await tester.pumpAndSettle();

    controller.showProviders();
    await tester.pumpAndSettle();

    expect(controller.activeWorkbenchRoute, DesktopWorkbenchRoute.providers);
    expect(
      find.byKey(const ValueKey<String>('provider-source-catalog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('provider-source-card-vk-turn-vps')),
      findsOneWidget,
    );
    expect(find.text('VK TURN VPS'), findsOneWidget);

    controller.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(api.dispose());
  });

  testWidgets('desktop shell bootstraps an available preset into a new draft', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _FakeControlPlaneApi(providers: _providerDescriptors);
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
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('desktop-section-profiles')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('desktop-section-provider')),
    );
    await tester.pumpAndSettle();

    expect(controller.activeWorkbenchRoute, DesktopWorkbenchRoute.providers);
    await _selectProviderMoreAction(
      tester,
      'desktop-open-preset-bootstrap-button',
    );

    final wbPresetButton = find.byKey(
      const ValueKey<String>('preset-use-generic-turn-default'),
    );
    await tester.tap(wbPresetButton);
    await tester.pumpAndSettle();

    expect(controller.activeSection, DesktopShellSection.providerWorkflow);
    expect(controller.managedProviderDraft.name, 'Generic TURN');
    expect(controller.managedProviderDraft.provider, 'generic-turn');
    expect(controller.selectedManagedProviderId, isNull);

    controller.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(api.dispose());
  });

  testWidgets(
    'desktop shell creates, edits, and deletes managed provider records',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api = _FakeControlPlaneApi(providers: _providerDescriptors);
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
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('desktop-section-profiles')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('desktop-section-provider')),
      );
      await tester.pumpAndSettle();

      expect(controller.activeWorkbenchRoute, DesktopWorkbenchRoute.providers);
      expect(
        controller.activeCanvasRoute,
        DesktopCanvasRoute.managedProviderPicker,
      );
      expect(
        find.byKey(const ValueKey<String>('desktop-canvas-route-back-button')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('managed-provider-create-button')),
        findsOneWidget,
      );
      await _createManagedProviderFromLibrary(tester);

      expect(
        controller.activeCanvasRoute,
        DesktopCanvasRoute.managedProviderEditor,
      );
      expect(
        find.byKey(const ValueKey<String>('managed-provider-workflow-body')),
        findsOneWidget,
      );

      await tester.ensureVisible(find.byType(TextField).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'WB Central');
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('managed-provider-save-action')),
      );
      await tester.pumpAndSettle();

      expect(controller.providerConfigs, hasLength(1));
      expect(controller.providerConfigs.single.name, 'WB Central');

      await tester.ensureVisible(find.byType(TextField).first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'WB Central Updated',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('managed-provider-save-action')),
      );
      await tester.pumpAndSettle();

      expect(controller.providerConfigs, hasLength(1));
      expect(controller.providerConfigs.single.name, 'WB Central Updated');

      await _selectProviderMoreAction(tester, 'managed-provider-delete-action');

      expect(controller.providerConfigs, isEmpty);
      expect(controller.activeSection, DesktopShellSection.providerWorkflow);
      expect(controller.activeWorkbenchRoute, DesktopWorkbenchRoute.providers);

      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(api.dispose());
    },
  );

  testWidgets('desktop shell keeps unavailable managed providers explicit', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _FakeControlPlaneApi(
      providers: <ProviderDescriptor>[_providerDescriptors.first],
    );
    final controller = DesktopShellController(
      api: api,
      supervisor: _FakeHostSupervisor(),
      stateStore: _InMemoryShellStateStore(
        DesktopShellState(
          profiles: const <ProfileRecord>[],
          managedProviders: <ManagedProviderRecord>[
            ManagedProviderRecord(
              id: 'provider-config-1',
              provider: 'generic-turn',
              name: 'Generic TURN Provider',
              providerSettings: const <String, dynamic>{},
              createdAt: DateTime.utc(2026, 4, 12, 18, 0),
              updatedAt: DateTime.utc(2026, 4, 12, 18, 1),
            ),
          ],
          draft: ProfileDraft.defaults(),
        ),
      ),
      appBuild: _testGuiBuild,
    );

    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(home: DashboardPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    controller.selectProviderConfig('provider-config-1');
    await tester.pumpAndSettle();

    expect(controller.workspaceSurface, DesktopWorkspaceSurface.providerConfig);
    expect(
      controller.managedProviders.single.availability.state,
      ProviderConfigAvailabilityState.providerUnavailable,
    );
    expect(
      controller.managedProviders.single.availability.message,
      contains('does not advertise'),
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Use in profile draft'),
          )
          .onPressed,
      isNotNull,
    );

    controller.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(api.dispose());
  });

  testWidgets(
    'desktop shell disables provider saves when reusable settings are unsupported',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api = _FakeControlPlaneApi(
        providers: const <ProviderDescriptor>[
          _supportedProviderWithUnsupportedSettingsDescriptor,
        ],
      );
      final controller = DesktopShellController(
        api: api,
        supervisor: _FakeHostSupervisor(),
        stateStore: _InMemoryShellStateStore(
          DesktopShellState(
            profiles: const <ProfileRecord>[],
            managedProviders: <ManagedProviderRecord>[
              ManagedProviderRecord(
                id: 'provider-config-1',
                provider: 'vk',
                name: 'Legacy managed provider',
                providerSettings: const <String, dynamic>{
                  'device_pin': '123456',
                },
                createdAt: DateTime.utc(2026, 4, 12, 18, 0),
                updatedAt: DateTime.utc(2026, 4, 12, 18, 1),
              ),
            ],
            draft: ProfileDraft.defaults(),
          ),
        ),
        appBuild: _testGuiBuild,
      );

      await controller.initialize();
      controller.selectProviderConfig('provider-config-1');
      await tester.pumpWidget(
        MaterialApp(home: DashboardPage(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(
        controller.managedProviders.single.availability.state,
        ProviderConfigAvailabilityState.schemaUnsupported,
      );
      expect(
        controller.managedProviders.single.availability.message,
        contains('cannot render reusable settings'),
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(
                const ValueKey<String>('managed-provider-save-action'),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(
                const ValueKey<String>('managed-provider-apply-action'),
              ),
            )
            .onPressed,
        isNotNull,
      );

      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(api.dispose());
    },
  );

  testWidgets(
    'desktop shell applies managed providers as saved-profile snapshots',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api = _FakeControlPlaneApi(
        providers: const <ProviderDescriptor>[
          _supportedProviderWithSettingsDescriptor,
        ],
      );
      final controller = DesktopShellController(
        api: api,
        supervisor: _FakeHostSupervisor(),
        stateStore: _InMemoryShellStateStore(
          DesktopShellState(
            profiles: <ProfileRecord>[
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
            ],
            managedProviders: <ManagedProviderRecord>[
              ManagedProviderRecord(
                id: 'provider-config-1',
                provider: 'vk',
                name: 'VK Europe',
                providerSettings: const <String, dynamic>{'region': 'eu-west'},
                createdAt: DateTime.utc(2026, 4, 12, 18, 0),
                updatedAt: DateTime.utc(2026, 4, 12, 18, 1),
              ),
            ],
            selectedProfileId: 'profile-1',
            draft: ProfileDraft.fromProfile(
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
            ),
          ),
        ),
        appBuild: _testGuiBuild,
      );

      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(home: DashboardPage(controller: controller)),
      );
      await tester.pumpAndSettle();

      controller.selectProviderConfig('provider-config-1');
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('managed-provider-apply-action')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('managed-provider-apply-action')),
      );
      await tester.pumpAndSettle();

      expect(controller.workspaceSurface, DesktopWorkspaceSurface.profile);
      expect(controller.draft.spec.provider, 'vk');
      expect(controller.draft.spec.providerSettings['region'], 'eu-west');
      expect(controller.draft.providerBinding.isManaged, isTrue);
      expect(
        controller.draft.providerBinding.managedProviderId,
        'provider-config-1',
      );

      await controller.saveDraft();
      await tester.pumpAndSettle();

      final savedProfile = controller.profiles.firstWhere(
        (ProfileRecord profile) => profile.id == 'profile-1',
      );
      expect(savedProfile.spec.provider, 'vk');
      expect(savedProfile.spec.providerSettings['region'], 'eu-west');

      controller.selectManagedProvider('provider-config-1');
      controller.updateManagedProviderDraft(
        controller.managedProviderDraft.copyWith(
          providerSettings: const <String, dynamic>{'region': 'ru-central'},
        ),
      );
      await controller.saveManagedProviderDraft();
      await tester.pumpAndSettle();

      final refreshedProfile = controller.profiles.firstWhere(
        (ProfileRecord profile) => profile.id == 'profile-1',
      );
      expect(refreshedProfile.spec.providerSettings['region'], 'eu-west');

      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(api.dispose());
    },
  );

  testWidgets(
    'desktop shell routes workflow and inspector shortcuts deterministically',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = DesktopShellController(
        api: _FakeControlPlaneApi(providers: _providerDescriptors),
        supervisor: _FakeHostSupervisor(),
        stateStore: const _InMemoryShellStateStore(),
        appBuild: _testGuiBuild,
      );

      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(home: DashboardPage(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(controller.activeWorkbenchRoute, DesktopWorkbenchRoute.home);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(controller.activeWorkbenchRoute, DesktopWorkbenchRoute.profiles);
      expect(
        find.byKey(
          const ValueKey<String>('saved-profiles-library-surface-desktop'),
        ),
        findsOneWidget,
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(controller.activeWorkbenchRoute, DesktopWorkbenchRoute.providers);
      expect(
        find.byKey(
          const ValueKey<String>('managed-provider-more-actions-button'),
        ),
        findsOneWidget,
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(controller.activeWorkbenchRoute, DesktopWorkbenchRoute.routing);
      expect(
        find.byKey(const ValueKey<String>('routing-content-surface-desktop')),
        findsOneWidget,
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(controller.isInspectorOpen, isTrue);
      expect(controller.activeInspectorPane, DesktopInspectorPane.diagnostics);
      expect(
        find.byKey(const ValueKey<String>('desktop-inspector-surface')),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(controller.isInspectorOpen, isFalse);
      expect(
        find.byKey(const ValueKey<String>('desktop-inspector-surface')),
        findsNothing,
      );

      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'desktop shell preserves open inspector context across resize transitions',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = DesktopShellController(
        api: _FakeControlPlaneApi(providers: _providerDescriptors),
        supervisor: _FakeHostSupervisor(),
        stateStore: const _InMemoryShellStateStore(),
        appBuild: _testGuiBuild,
      );

      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(home: DashboardPage(controller: controller)),
      );
      await tester.pumpAndSettle();

      tester
          .widget<Focus>(
            find.byKey(const ValueKey<String>('desktop-active-workflow-focus')),
          )
          .focusNode
          ?.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(controller.isInspectorOpen, isTrue);
      expect(controller.activeInspectorPane, DesktopInspectorPane.diagnostics);
      expect(
        find.byKey(const ValueKey<String>('desktop-inspector-surface')),
        findsOneWidget,
      );

      tester.view.physicalSize = const Size(1280, 1200);
      await tester.pumpAndSettle();

      expect(controller.isInspectorOpen, isTrue);
      expect(controller.activeInspectorPane, DesktopInspectorPane.diagnostics);
      expect(
        find.byKey(const ValueKey<String>('desktop-section-rail')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('desktop-inspector-surface')),
        findsOneWidget,
      );

      tester.view.physicalSize = const Size(1600, 1200);
      await tester.pumpAndSettle();

      expect(controller.isInspectorOpen, isTrue);
      expect(
        find.byKey(const ValueKey<String>('desktop-inspector-surface')),
        findsOneWidget,
      );

      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'desktop shell returns focus to the active workflow after overlay support closes',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = DesktopShellController(
        api: _FakeControlPlaneApi(providers: _providerDescriptors),
        supervisor: _FakeHostSupervisor(),
        stateStore: const _InMemoryShellStateStore(),
        appBuild: _testGuiBuild,
      );

      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(home: DashboardPage(controller: controller)),
      );
      await tester.pumpAndSettle();

      final workflowFocusFinder = find.byKey(
        const ValueKey<String>('desktop-active-workflow-focus'),
      );

      expect(
        tester.widget<Focus>(workflowFocusFinder).focusNode?.hasPrimaryFocus,
        isTrue,
      );

      controller.openInspector(pane: DesktopInspectorPane.diagnostics);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('desktop-inspector-surface')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('desktop-inspector-close-button')),
      );
      await tester.pumpAndSettle();

      expect(controller.isInspectorOpen, isFalse);
      expect(
        find.byKey(const ValueKey<String>('desktop-inspector-surface')),
        findsNothing,
      );
      expect(
        tester.widget<Focus>(workflowFocusFinder).focusNode?.hasPrimaryFocus,
        isTrue,
      );

      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'desktop shell uses compact drawer navigation and support routes',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = DesktopShellController(
        api: _FakeControlPlaneApi(providers: _providerDescriptors),
        supervisor: _FakeHostSupervisor(),
        stateStore: const _InMemoryShellStateStore(),
        appBuild: _testGuiBuild,
      );

      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(home: DashboardPage(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('desktop-navigation-drawer-button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('desktop-navigation-drawer-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('desktop-section-drawer')),
        findsOneWidget,
      );

      await tester.tap(find.text('Profiles').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('desktop-navigation-drawer-button')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('desktop-section-provider')),
      );
      await tester.pumpAndSettle();

      expect(controller.activeSection, DesktopShellSection.providerWorkflow);
      expect(controller.activeWorkbenchRoute, DesktopWorkbenchRoute.providers);
      expect(
        find.byKey(const ValueKey<String>('desktop-section-drawer')),
        findsNothing,
      );

      await _selectProviderMoreAction(
        tester,
        'desktop-open-preset-bootstrap-button',
      );

      expect(controller.activeCanvasRoute, DesktopCanvasRoute.presetPicker);
      expect(
        find.byKey(const ValueKey<String>('desktop-canvas-route-frame')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('desktop-canvas-route-back-button')),
      );
      await tester.pumpAndSettle();

      controller.showDiagnosticsRoute();
      await tester.pumpAndSettle();

      expect(
        controller.activeWorkbenchRoute,
        DesktopWorkbenchRoute.diagnostics,
      );
      expect(
        find.byKey(
          const ValueKey<String>('support-event-stream-surface-desktop'),
        ),
        findsOneWidget,
      );

      controller.showProviders();
      await tester.pumpAndSettle();

      expect(controller.activeSection, DesktopShellSection.providerWorkflow);

      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'desktop shell preserves provider workflow context across resize',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = DesktopShellController(
        api: _FakeControlPlaneApi(providers: _providerDescriptors),
        supervisor: _FakeHostSupervisor(),
        stateStore: const _InMemoryShellStateStore(),
        appBuild: _testGuiBuild,
      );

      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(home: DashboardPage(controller: controller)),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('desktop-section-profiles')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('desktop-section-provider')),
      );
      await tester.pumpAndSettle();
      expect(controller.activeWorkbenchRoute, DesktopWorkbenchRoute.providers);
      await _createManagedProviderFromLibrary(tester);
      await tester.enterText(find.byType(TextField).first, 'Resize Record');
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(1280, 1200);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('desktop-section-rail')),
        findsOneWidget,
      );
      expect(controller.activeSection, DesktopShellSection.providerWorkflow);
      expect(controller.activeWorkbenchRoute, DesktopWorkbenchRoute.providers);
      expect(controller.managedProviderDraft.name, 'Resize Record');

      tester.view.physicalSize = const Size(1040, 1200);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('desktop-navigation-drawer-button')),
        findsOneWidget,
      );
      expect(controller.activeSection, DesktopShellSection.providerWorkflow);
      expect(controller.activeWorkbenchRoute, DesktopWorkbenchRoute.providers);
      expect(controller.managedProviderDraft.name, 'Resize Record');

      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'desktop profile name input keeps caret position across draft sync',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = DesktopShellController(
        api: _FakeControlPlaneApi(),
        supervisor: const _FakeHostSupervisor(),
        stateStore: const _InMemoryShellStateStore(),
        appBuild: _testGuiBuild,
      );

      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(home: DashboardPage(controller: controller)),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('desktop-section-profiles')),
      );
      await tester.pumpAndSettle();
      await _openProfileFromLibrary(tester, 'profile-1');

      final profileNameField = find.byType(TextField).first;

      await tester.tap(profileNameField);
      await tester.pumpAndSettle();

      final focusedWidgetAfterTap =
          FocusManager.instance.primaryFocus?.context?.widget;
      expect(
        focusedWidgetAfterTap is EditableText ||
            FocusManager.instance.primaryFocus?.context
                    ?.findAncestorWidgetOfExactType<EditableText>() !=
                null,
        isTrue,
      );

      await tester.enterText(profileNameField, 'A');
      await tester.pumpAndSettle();

      var editable = tester.widget<EditableText>(
        find.descendant(
          of: profileNameField,
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.controller.text, 'A');
      expect(editable.controller.selection.isCollapsed, isTrue);
      expect(editable.controller.selection.baseOffset, 1);

      await tester.enterText(profileNameField, 'AB');
      await tester.pumpAndSettle();

      editable = tester.widget<EditableText>(
        find.descendant(
          of: profileNameField,
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.controller.text, 'AB');
      expect(editable.controller.selection.isCollapsed, isTrue);
      expect(editable.controller.selection.baseOffset, 2);

      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'desktop profile editor toggles between managed and custom provider modes',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api = _FakeControlPlaneApi(
        providers: const <ProviderDescriptor>[
          _supportedProviderWithSettingsDescriptor,
        ],
      );
      final controller = DesktopShellController(
        api: api,
        supervisor: _FakeHostSupervisor(),
        stateStore: _InMemoryShellStateStore(
          DesktopShellState(
            profiles: const <ProfileRecord>[],
            managedProviders: <ManagedProviderRecord>[
              ManagedProviderRecord(
                id: 'provider-config-1',
                provider: 'vk',
                name: 'VK Europe',
                providerSettings: const <String, dynamic>{'region': 'eu-west'},
                createdAt: DateTime.utc(2026, 4, 12, 18, 0),
                updatedAt: DateTime.utc(2026, 4, 12, 18, 1),
              ),
            ],
            draft: ProfileDraft.defaults(),
          ),
        ),
        appBuild: _testGuiBuild,
      );

      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(home: DashboardPage(controller: controller)),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('desktop-section-profiles')),
      );
      await tester.pumpAndSettle();
      await _createDraftFromProfileLibrary(tester);

      await tester.ensureVisible(
        find.widgetWithText(ChoiceChip, 'Saved record'),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, 'Saved record'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Direct input'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Saved record'));
      await tester.pumpAndSettle();

      expect(controller.draft.providerBinding.isManaged, isTrue);
      expect(
        controller.draft.providerBinding.managedProviderId,
        'provider-config-1',
      );
      expect(
        find.byKey(const ValueKey<String>('profile-provider-record-field')),
        findsOneWidget,
      );
      expect(find.text('VK Europe'), findsWidgets);

      await tester.ensureVisible(
        find.widgetWithText(ChoiceChip, 'Direct input'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Direct input'));
      await tester.pumpAndSettle();

      expect(controller.draft.providerBinding.isManaged, isFalse);
      expect(
        find.byKey(const ValueKey<String>('profile-provider-record-field')),
        findsNothing,
      );

      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(api.dispose());
    },
  );
}

class _InMemoryShellStateStore implements DesktopShellStateStore {
  const _InMemoryShellStateStore([this.state]);

  final DesktopShellState? state;

  @override
  Future<DesktopShellState?> load() async {
    return state;
  }

  @override
  Future<void> save(DesktopShellState state) async {}
}

class _FakeControlPlaneApi implements ControlPlaneApi {
  _FakeControlPlaneApi({
    List<ResolutionRecord> resolutionsList = const <ResolutionRecord>[],
    List<ProviderDescriptor>? providers,
    List<RemoteProviderSourceDescriptor>? providerSources,
    List<ProviderConfigRecord>? providerConfigs,
    List<ProfileRecord>? profiles,
    HostInfo? hostInfo,
    List<TransportProfileStatus>? transportProfiles,
    this.startPlatformTunnelResult = const PlatformTunnelStartResult(
      mode: PlatformTunnelMode.windowsWintun,
      ready: false,
      stage: PlatformTunnelStartupStage.capabilityCheck,
      missingPrerequisite: PlatformTunnelPrerequisite.hostImplementation,
      message: 'desktop sidecar does not implement system tunnel startup yet',
    ),
  }) : _providers = List<ProviderDescriptor>.of(
         providers ?? _providerDescriptors,
       ),
       _providerConfigs = List<ProviderConfigRecord>.of(
         providerConfigs ?? const <ProviderConfigRecord>[],
       ),
       _providerSources = List<RemoteProviderSourceDescriptor>.of(
         providerSources ?? const <RemoteProviderSourceDescriptor>[],
       ),
       _hostInfo = hostInfo ?? _readyHostInfo,
       _transportProfiles = List<TransportProfileStatus>.of(
         transportProfiles ?? const <TransportProfileStatus>[],
       ),
       _resolutions = List<ResolutionRecord>.of(resolutionsList),
       _profiles = List<ProfileRecord>.of(
         profiles ??
             <ProfileRecord>[
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
               ProfileRecord(
                 id: 'profile-2',
                 name: 'beta',
                 spec: const ProfileSpec(
                   provider: 'generic-turn',
                   link:
                       'generic-turn://turn-user:turn-pass@turn.example.test:3478',
                   listenAddress: '127.0.0.1:9002',
                   peerAddress: '10.0.0.2:6000',
                 ),
               ),
             ],
       );

  final List<ProviderDescriptor> _providers;
  final List<RemoteProviderSourceDescriptor> _providerSources;
  final List<ProviderConfigRecord> _providerConfigs;
  HostInfo _hostInfo;
  final List<TransportProfileStatus> _transportProfiles;
  final List<String> startedProfileIDs = <String>[];
  final List<PlatformTunnelMode> startedPlatformTunnels =
      <PlatformTunnelMode>[];
  final List<TransportProfileReference?> startedPlatformTunnelProfiles =
      <TransportProfileReference?>[];
  final List<TransportProfileImportRequest> importTransportProfileCalls =
      <TransportProfileImportRequest>[];
  final PlatformTunnelStartResult startPlatformTunnelResult;
  final List<ResolutionRecord> _resolutions;
  final List<ProfileRecord> _profiles;
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
  Future<ChallengeRecord> continueChallenge(
    String challengeId, {
    ChallengeContinuationSubmission? browserContinuation,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteProviderConfig(String configId) async {
    _providerConfigs.removeWhere(
      (ProviderConfigRecord config) => config.id == configId,
    );
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
  Future<List<ProviderConfigRecord>> providerConfigs() async =>
      _providerConfigs;

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
  ) {
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
  Future<SessionRecord> materializeResolution({
    required String resolutionId,
    required RuntimeDefaults runtimeDefaults,
    RuntimeExecutionPlan? executionPlan,
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
    startedPlatformTunnels.add(mode);
    startedPlatformTunnelProfiles.add(transportProfile);
    if (startPlatformTunnelResult.ready) {
      final now = DateTime(2026, 4, 5, 17, 1);
      final session = SessionRecord(
        id: startPlatformTunnelResult.sessionId.isEmpty
            ? 'platform-session-1'
            : startPlatformTunnelResult.sessionId,
        sourceResolutionId: resolutionId,
        profileName: 'windows wintun',
        profile: _profiles.first.spec,
        state: SessionState.ready,
        startedAt: now,
        updatedAt: now,
      );
      _sessions = <SessionRecord>[session];
    }
    return startPlatformTunnelResult;
  }

  @override
  Future<PlatformTunnelStartResult> resumePlatformTunnel({
    required String startupAttemptId,
  }) async {
    return const PlatformTunnelStartResult(
      mode: PlatformTunnelMode.windowsWintun,
      ready: false,
      stage: PlatformTunnelStartupStage.permissionAcquire,
      missingPrerequisite: PlatformTunnelPrerequisite.permission,
      startupAttemptId: 'attempt-1',
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
  Future<List<ProviderDescriptor>> providers() async => _providers;

  @override
  Future<List<RemoteProviderSourceDescriptor>> providerSources() async =>
      _providerSources;

  @override
  Future<ProviderTransportCompatibilityResponse>
  providerTransportCompatibilityCandidates(
    ProviderTransportCompatibilityRequest request,
  ) => Future<ProviderTransportCompatibilityResponse>.error(
    UnimplementedError(),
  );

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
    final resolution = ResolutionRecord(
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
    _resolutions
      ..clear()
      ..add(resolution);
    return resolution;
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
    return next;
  }

  Future<void> dispose() async {
    await _events.close();
  }

  bool _providerAdvertised(String providerId) {
    final normalized = providerId.trim().toLowerCase();
    return _providers.any(
      (ProviderDescriptor descriptor) =>
          descriptor.id.trim().toLowerCase() == normalized,
    );
  }
}

class _FakeHostSupervisor implements HostSupervisor {
  const _FakeHostSupervisor({
    this.result = const HostConnectionResult(
      state: HostLifecycleState.ready,
      message: 'Connected to local host 127.0.0.1:7777',
      info: _readyHostInfo,
    ),
  });

  final HostConnectionResult result;

  @override
  Future<void> dispose() async {}

  @override
  Future<HostConnectionResult> ensureReady() async {
    return result;
  }
}

class _TrackingHostSupervisor implements HostSupervisor {
  int disposeCalls = 0;
  Completer<void>? _disposeCompleter;
  Future<void>? _disposeFuture;

  void completeDispose() {
    _disposeCompleter?.complete();
  }

  @override
  Future<void> dispose() {
    disposeCalls++;
    _disposeCompleter ??= Completer<void>();
    _disposeFuture ??= _disposeCompleter!.future;
    return _disposeFuture!;
  }

  @override
  Future<HostConnectionResult> ensureReady() async {
    return const HostConnectionResult(
      state: HostLifecycleState.ready,
      message: 'Connected to local host 127.0.0.1:7777',
      info: _readyHostInfo,
    );
  }
}

class _HangingEventCancelControlPlaneApi extends _FakeControlPlaneApi {
  final Completer<void> _cancelCompleter = Completer<void>();
  int cancelAttempts = 0;

  @override
  Stream<EventRecord> events() {
    return Stream<EventRecord>.multi((
      StreamController<EventRecord> controller,
    ) {
      controller.onCancel = () {
        cancelAttempts++;
        return _cancelCompleter.future;
      };
    });
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
