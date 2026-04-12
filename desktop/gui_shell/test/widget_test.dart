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
    Capability.providerConfigs,
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

void main() {
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

      expect(find.text('Connecting to local host'), findsOneWidget);
      expect(
        find.text('Starting local host and negotiating capabilities.'),
        findsOneWidget,
      );
      expect(find.text('Local host blocked'), findsNothing);
      expect(find.text('Libraries'), findsOneWidget);
      expect(find.text('Profile workspace'), findsOneWidget);
      expect(find.text('Diagnostics'), findsOneWidget);

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

    final libraryScrollable = find
        .descendant(
          of: find.byKey(const ValueKey<String>('workflow-library-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('profile-library-item-profile-2')),
      180,
      scrollable: libraryScrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text('Libraries'), findsOneWidget);
    expect(find.text('Profile workspace'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('profile-library-item-profile-2')),
      findsOneWidget,
    );

    final libraryOffset = tester.getTopLeft(find.text('Libraries'));
    final workspaceOffset = tester.getTopLeft(find.text('Profile workspace'));
    expect(libraryOffset.dx, lessThan(workspaceOffset.dx));

    await tester.tap(
      find.byKey(const ValueKey<String>('profile-library-item-profile-2')),
    );
    await tester.pumpAndSettle();

    expect(controller.selectedProfileId, 'profile-2');
    expect(controller.draft.name, 'beta');

    controller.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
    expect(controller.selectedProfileId, 'profile-1');
    expect(find.text('GUI 0.1.0+1 @gui123456789'), findsOneWidget);
    expect(find.text('Host 0.1.0+1 @deadbeefcafe'), findsOneWidget);
    expect(find.text('Contract 1'), findsOneWidget);
    expect(find.text('Libraries'), findsOneWidget);
    expect(find.text('Profile workspace'), findsOneWidget);
    expect(find.text('Diagnostics'), findsOneWidget);
    expect(find.text('Live work'), findsNothing);
    expect(
      find.textContaining(
        'All reported tunnel modes are currently fail-closed',
      ),
      findsOneWidget,
    );
    final libraryOffset = tester.getTopLeft(find.text('Libraries'));
    final workspaceOffset = tester.getTopLeft(find.text('Profile workspace'));
    final diagnosticsOffset = tester.getTopLeft(find.text('Diagnostics'));

    expect(libraryOffset.dx, lessThan(workspaceOffset.dx));
    expect(workspaceOffset.dx, lessThan(diagnosticsOffset.dx));

    final workspaceScrollable = find
        .descendant(
          of: find.byKey(const ValueKey<String>('profile-workspace-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    final startButton = find.text('Start saved profile', skipOffstage: false);
    await tester.scrollUntilVisible(
      startButton,
      320,
      scrollable: workspaceScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(startButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(api.startedProfileIDs, <String>['profile-1']);
    expect(find.textContaining('Started session'), findsOneWidget);
    expect(find.text('Live work'), findsOneWidget);
    expect(find.text('Sessions (1)'), findsOneWidget);
    expect(find.text('ready'), findsWidgets);

    await tester.tap(find.text('Tunnel detail'));
    await tester.pumpAndSettle();

    expect(find.text('Platform tunnel modes'), findsOneWidget);
    expect(find.text('Windows Wintun'), findsOneWidget);
    expect(
      find.textContaining('host implementation is still missing'),
      findsOneWidget,
    );
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

    expect(find.text('Live work'), findsOneWidget);
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
      providers: <ProviderDescriptor>[
        ..._providerDescriptors,
        _providerWithSettingsDescriptor,
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

    final libraryScrollable = _libraryScrollable();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('preset-card-smarthome-default')),
      180,
      scrollable: libraryScrollable,
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'does not advertise the RTK Smarthome provider family yet',
      ),
      findsOneWidget,
    );

    controller.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(api.dispose());
  });

  testWidgets(
    'desktop shell bootstraps an available preset into a new draft',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api = _FakeControlPlaneApi(
        providers: <ProviderDescriptor>[
          ..._providerDescriptors,
          _providerWithSettingsDescriptor,
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

      final libraryScrollable = _libraryScrollable();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('preset-card-wb-stream-default')),
        180,
        scrollable: libraryScrollable,
      );
      await tester.pumpAndSettle();

      final wbPresetButton = find.byKey(
        const ValueKey<String>('preset-use-wb-stream-default'),
      );
      await tester.scrollUntilVisible(
        wbPresetButton,
        120,
        scrollable: libraryScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(wbPresetButton);
      await tester.pumpAndSettle();

      expect(controller.selectedProfileId, isNull);
      expect(controller.workspaceSurface, DesktopWorkspaceSurface.profile);
      expect(controller.draft.name, 'WB Stream');
      expect(controller.draft.spec.provider, 'wb-stream');

      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(api.dispose());
    },
  );

  testWidgets('desktop shell creates, edits, and deletes provider configs', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _FakeControlPlaneApi(
      providers: <ProviderDescriptor>[
        ..._providerDescriptors,
        _providerWithSettingsDescriptor,
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

    final libraryScrollable = _libraryScrollable();
    await tester.scrollUntilVisible(
      find.text('Provider configs'),
      180,
      scrollable: libraryScrollable,
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('provider-config-create-button')),
    );
    await tester.pumpAndSettle();

    expect(controller.workspaceSurface, DesktopWorkspaceSurface.providerConfig);
    expect(find.text('Provider config workspace'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'WB Central');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save config'));
    await tester.pumpAndSettle();

    expect(controller.providerConfigs, hasLength(1));
    expect(controller.providerConfigs.single.name, 'WB Central');

    await tester.enterText(find.byType(TextField).first, 'WB Central Updated');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save config'));
    await tester.pumpAndSettle();

    expect(controller.providerConfigs, hasLength(1));
    expect(controller.providerConfigs.single.name, 'WB Central Updated');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(controller.providerConfigs, isEmpty);
    expect(controller.workspaceSurface, DesktopWorkspaceSurface.profile);

    controller.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(api.dispose());
  });

  testWidgets('desktop shell blocks unavailable provider configs explicitly', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _FakeControlPlaneApi(
      providerConfigs: <ProviderConfigRecord>[
        _providerConfigRecord(
          id: 'provider-config-1',
          provider: 'wb-stream',
          name: 'WB Central',
          providerSettings: const <String, dynamic>{'region': 'eu-west'},
          availability: const ProviderConfigAvailability(
            state: ProviderConfigAvailabilityState.providerUnavailable,
            message:
                'The connected host no longer advertises WB Stream provider settings.',
          ),
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

    controller.selectProviderConfig('provider-config-1');
    await tester.pumpAndSettle();

    await tester.pumpAndSettle();

    expect(controller.workspaceSurface, DesktopWorkspaceSurface.providerConfig);
    expect(
      find.textContaining('no longer advertises WB Stream'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Apply to profile draft'),
          )
          .onPressed,
      isNull,
    );

    controller.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(api.dispose());
  });

  testWidgets(
    'desktop shell applies provider configs as saved-profile snapshots',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api = _FakeControlPlaneApi(
        providers: <ProviderDescriptor>[
          ..._providerDescriptors,
          _providerWithSettingsDescriptor,
        ],
        providerConfigs: <ProviderConfigRecord>[
          _providerConfigRecord(
            id: 'provider-config-1',
            provider: 'wb-stream',
            name: 'WB Central',
            providerSettings: const <String, dynamic>{'region': 'eu-west'},
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

      controller.selectProviderConfig('provider-config-1');
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(FilledButton, 'Apply to profile draft'),
      );
      await tester.pumpAndSettle();

      expect(controller.workspaceSurface, DesktopWorkspaceSurface.profile);
      expect(controller.draft.spec.provider, 'wb-stream');
      expect(controller.draft.spec.providerSettings['region'], 'eu-west');

      await controller.saveDraft();
      await tester.pumpAndSettle();

      final savedProfile = controller.profiles.firstWhere(
        (ProfileRecord profile) => profile.id == 'profile-1',
      );
      expect(savedProfile.spec.provider, 'wb-stream');
      expect(savedProfile.spec.providerSettings['region'], 'eu-west');

      await api.upsertProviderConfig(
        _providerConfigRecord(
          id: 'provider-config-1',
          provider: 'wb-stream',
          name: 'WB Central',
          providerSettings: const <String, dynamic>{'region': 'ru-central'},
        ),
      );
      await controller.refresh();
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
}

Finder _libraryScrollable() {
  return find
      .descendant(
        of: find.byKey(const ValueKey<String>('workflow-library-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;
}

ProviderConfigRecord _providerConfigRecord({
  required String id,
  required String provider,
  required String name,
  required Map<String, dynamic> providerSettings,
  ProviderConfigAvailability availability = const ProviderConfigAvailability(),
}) {
  return ProviderConfigRecord(
    id: id,
    provider: provider,
    name: name,
    providerSettings: providerSettings,
    createdAt: DateTime.utc(2026, 4, 12, 18, 0),
    updatedAt: DateTime.utc(2026, 4, 12, 18, 1),
    availability: availability,
  );
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
  _FakeControlPlaneApi({
    this.resolutionsList = const <ResolutionRecord>[],
    List<ProviderDescriptor>? providers,
    List<ProviderConfigRecord>? providerConfigs,
  }) : _providers = List<ProviderDescriptor>.of(
         providers ?? _providerDescriptors,
       ),
       _providerConfigs = List<ProviderConfigRecord>.of(
         providerConfigs ?? const <ProviderConfigRecord>[],
       );

  final List<ResolutionRecord> resolutionsList;
  final List<ProviderDescriptor> _providers;
  final List<ProviderConfigRecord> _providerConfigs;
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
    ProfileRecord(
      id: 'profile-2',
      name: 'beta',
      spec: const ProfileSpec(
        provider: 'generic-turn',
        link: 'generic-turn://turn-user:turn-pass@turn.example.test:3478',
        listenAddress: '127.0.0.1:9002',
        peerAddress: '10.0.0.2:6000',
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
  Future<List<ProviderDescriptor>> providers() async => _providers;

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

  @override
  Future<ProviderConfigRecord> upsertProviderConfig(
    ProviderConfigRecord config,
  ) async {
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
