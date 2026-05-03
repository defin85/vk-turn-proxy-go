import 'package:flutter/material.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gui_shell/src/control/control_plane_client.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/desktop_host_supervisor.dart';
import 'package:gui_shell/src/control/desktop_shell_controller.dart';
import 'package:gui_shell/src/control/shell_state_store.dart';

import 'test_i18n.dart';

const BuildIdentity _testGuiBuild = BuildIdentity(
  product: 'RelayDock',
  version: '0.1.0',
  buildNumber: '1',
  revision: 'gui123456789',
  role: 'gui_shell',
  target: 'linux/x64',
);

const BuildIdentity _testHostBuild = BuildIdentity(
  product: 'RelayDock',
  version: '0.1.0',
  buildNumber: '1',
  revision: 'deadbeefcafe',
  role: 'clientd',
  target: 'linux/amd64',
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
);

class _ReadyHostSupervisor implements HostSupervisor {
  const _ReadyHostSupervisor();

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

class _LocalizedReadyHostSupervisor implements HostSupervisor {
  int calls = 0;

  @override
  Future<void> dispose() async {}

  @override
  Future<HostConnectionResult> ensureReady() async {
    calls += 1;
    return HostConnectionResult(
      state: HostLifecycleState.ready,
      message: currentShellText.connectedToLocalHost('127.0.0.1:7777'),
      info: _readyHostInfo,
    );
  }
}

class _InMemoryDesktopShellStateStore implements DesktopShellStateStore {
  const _InMemoryDesktopShellStateStore();

  @override
  Future<DesktopShellState?> load() async => null;

  @override
  Future<void> save(DesktopShellState state) async {}
}

class _ReadyControlPlaneApi implements ControlPlaneApi {
  const _ReadyControlPlaneApi();

  @override
  Future<ChallengeRecord> cancelChallenge(String challengeId) =>
      Future<ChallengeRecord>.error(UnimplementedError());

  @override
  Future<ChallengeRecord> challenge(String challengeId) =>
      Future<ChallengeRecord>.error(UnimplementedError());

  @override
  Future<ChallengeRecord> continueChallenge(
    String challengeId, {
    ChallengeContinuationSubmission? browserContinuation,
  }) => Future<ChallengeRecord>.error(UnimplementedError());

  @override
  Future<void> deleteProfile(String profileId) async {}

  @override
  Future<void> deleteProviderConfig(String configId) async {}

  @override
  Future<ResolutionRecord> cancelResolution(String resolutionId) =>
      Future<ResolutionRecord>.error(UnimplementedError());

  @override
  Future<DiagnosticsBundle> diagnostics(String sessionId) =>
      Future<DiagnosticsBundle>.error(UnimplementedError());

  @override
  Stream<EventRecord> events() => const Stream<EventRecord>.empty();

  @override
  Future<ResolutionExportResult> exportResolution(String resolutionId) =>
      Future<ResolutionExportResult>.error(UnimplementedError());

  @override
  Future<HostInfo> hostInfo() async => _readyHostInfo;

  @override
  Future<List<TransportProfileStatus>> transportProfiles() async =>
      const <TransportProfileStatus>[];

  @override
  Future<List<PlatformTunnelStatus>> platformTunnelStatuses() async =>
      const <PlatformTunnelStatus>[];

  @override
  Future<TransportProfileStatus> importTransportProfile(
    TransportProfileImportRequest request,
  ) => Future<TransportProfileStatus>.error(UnimplementedError());

  @override
  Future<TransportProfileStructuredSaveResult> createStructuredTransportProfile(
    TransportProfileStructuredCreateRequest request,
  ) => Future<TransportProfileStructuredSaveResult>.error(UnimplementedError());

  @override
  Future<TransportProfileStructuredSaveResult> updateStructuredTransportProfile(
    String profileId,
    TransportProfileStructuredUpdateRequest request,
  ) => Future<TransportProfileStructuredSaveResult>.error(UnimplementedError());

  @override
  Future<TransportProfileStructuredValidationResult>
  validateStructuredTransportProfileDraft(
    TransportProfileStructuredValidationRequest request,
  ) => Future<TransportProfileStructuredValidationResult>.error(
    UnimplementedError(),
  );

  @override
  Future<TransportProfileGeneratedKey> generateTransportProfileKey(
    TransportProfileGenerateKeyRequest request,
  ) => Future<TransportProfileGeneratedKey>.error(UnimplementedError());

  @override
  Future<TransportProfileStatus> validateTransportProfile(String profileId) =>
      Future<TransportProfileStatus>.error(UnimplementedError());

  @override
  Future<TransportProfileStatus> selectTransportProfileForStartup(
    String profileId,
    TransportProfileSelectForStartupRequest request,
  ) => Future<TransportProfileStatus>.error(UnimplementedError());

  @override
  Future<void> forgetTransportProfile(String profileId) async {}

  @override
  Future<SessionRecord> materializeResolution({
    required String resolutionId,
    required RuntimeDefaults runtimeDefaults,
    RuntimeExecutionPlan? executionPlan,
  }) => Future<SessionRecord>.error(UnimplementedError());

  @override
  Future<HostInfo> negotiate({
    required List<String> supportedVersions,
    required List<Capability> requiredCapabilities,
  }) async => _readyHostInfo;

  @override
  Future<List<ProfileRecord>> profiles() async => const <ProfileRecord>[];

  @override
  Future<List<ProviderConfigRecord>> providerConfigs() async =>
      const <ProviderConfigRecord>[];

  @override
  Future<List<ProviderDescriptor>> providers() async =>
      const <ProviderDescriptor>[
        ProviderDescriptor(
          id: 'vk',
          displayName: 'VK Calls',
          inputKind: ProviderInputKind.link,
          authPosture: ProviderAuthPosture.guestOrAccount,
          browserPolicy: ProviderBrowserPolicy.externalRequired,
          artifactFamilies: <ArtifactFamily>[ArtifactFamily.genericTurn],
        ),
        ProviderDescriptor(
          id: 'generic-turn',
          displayName: 'Generic TURN',
          inputKind: ProviderInputKind.link,
          authPosture: ProviderAuthPosture.staticSecret,
          browserPolicy: ProviderBrowserPolicy.notRequired,
          artifactFamilies: <ArtifactFamily>[ArtifactFamily.genericTurn],
        ),
      ];

  @override
  Future<List<RemoteProviderSourceDescriptor>> providerSources() async =>
      const <RemoteProviderSourceDescriptor>[];

  @override
  Future<ProviderTransportCompatibilityResponse>
  providerTransportCompatibilityCandidates(
    ProviderTransportCompatibilityRequest request,
  ) => Future<ProviderTransportCompatibilityResponse>.error(
    UnimplementedError(),
  );

  @override
  Future<List<ResolutionRecord>> resolutions() async =>
      const <ResolutionRecord>[];

  @override
  Future<ProviderConfigRecord> restoreProviderConfig(
    ProviderConfigRecord config,
  ) => Future<ProviderConfigRecord>.error(UnimplementedError());

  @override
  Future<List<SessionRecord>> sessions() async => const <SessionRecord>[];

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
  }) => Future<PlatformTunnelStartResult>.error(UnimplementedError());

  @override
  Future<ResolutionRecord> startResolution({
    required String provider,
    required ProviderInputEnvelope input,
    Map<String, dynamic> providerSettings = const <String, dynamic>{},
  }) => Future<ResolutionRecord>.error(UnimplementedError());

  @override
  Future<SessionRecord> startSession({String? profileId, ProfileSpec? spec}) =>
      Future<SessionRecord>.error(UnimplementedError());

  @override
  Future<PlatformTunnelStartResult> resumePlatformTunnel({
    required String startupAttemptId,
  }) => Future<PlatformTunnelStartResult>.error(UnimplementedError());

  @override
  Future<PlatformTunnelStopResult> stopPlatformTunnel({
    required PlatformTunnelMode mode,
  }) => Future<PlatformTunnelStopResult>.error(UnimplementedError());

  @override
  Future<SessionRecord> stopSession(String sessionId) =>
      Future<SessionRecord>.error(UnimplementedError());

  @override
  Future<ProfileRecord> upsertProfile(ProfileRecord profile) =>
      Future<ProfileRecord>.error(UnimplementedError());

  @override
  Future<ProviderConfigRecord> upsertProviderConfig(
    ProviderConfigRecord config,
  ) => Future<ProviderConfigRecord>.error(UnimplementedError());
}

void main() {
  test(
    'desktop controller reconnects on locale switch and relocalizes host status',
    () async {
      await AppLocale.en.build();
      await AppLocale.ru.build();
      LocaleSettings.setLocaleSync(AppLocale.ru);
      addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.en));

      final supervisor = _LocalizedReadyHostSupervisor();
      final controller = DesktopShellController(
        api: const _ReadyControlPlaneApi(),
        supervisor: supervisor,
        stateStore: const _InMemoryDesktopShellStateStore(),
        appBuild: _testGuiBuild,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      expect(
        controller.hostStatusMessage,
        'Подключено к локальному хосту 127.0.0.1:7777',
      );

      await controller.selectLocaleOverride('en');

      expect(supervisor.calls, greaterThanOrEqualTo(2));
      expect(
        controller.hostStatusMessage,
        'Connected to local host 127.0.0.1:7777',
      );
    },
  );

  testWidgets('desktop shell chrome switches to Russian locale labels', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = DesktopShellController(
      api: const _ReadyControlPlaneApi(),
      supervisor: const _ReadyHostSupervisor(),
      stateStore: const _InMemoryDesktopShellStateStore(),
      appBuild: _testGuiBuild,
    );

    await controller.initialize();
    await pumpDesktopShellTestApp(
      tester,
      controller: controller,
      locale: AppLocale.ru,
    );

    final diagnosticsButton = find.byKey(
      const ValueKey<String>('desktop-open-diagnostics-button'),
    );
    final profilesSection = find.byKey(
      const ValueKey<String>('desktop-section-profiles'),
    );

    expect(diagnosticsButton, findsOneWidget);
    expect(
      find.descendant(
        of: diagnosticsButton,
        matching: find.text('Диагностика'),
      ),
      findsOneWidget,
    );
    expect(profilesSection, findsOneWidget);
    expect(
      find.descendant(of: profilesSection, matching: find.text('Профили')),
      findsOneWidget,
    );
    expect(find.byTooltip('Сменить язык'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('desktop-section-settings')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Сменить язык'), findsWidgets);
  });
}
