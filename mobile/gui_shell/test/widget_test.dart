import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_gui_shell/src/app.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/mobile_handoff_adapter.dart';
import 'package:mobile_gui_shell/src/control/mobile_host_bridge.dart';
import 'package:mobile_gui_shell/src/control/mobile_platform_app_inventory.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_controller.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_state_store.dart';
import 'package:mobile_gui_shell/src/control/profile_draft.dart';
import 'package:mobile_gui_shell/src/ui/owned_browser_challenge.dart';

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
    );

const RuntimeExecutionPlanDescriptor
_appleNetworkExtensionExecutionPlanDescriptor = RuntimeExecutionPlanDescriptor(
  plan: RuntimeExecutionPlan(
    accessMethod: RuntimeAccessMethod.turnCredentials,
    carrierFamily: RuntimeCarrierFamily.turnDatagram,
    engineFamily: RuntimeEngineFamily.wireguardNative,
    hostAdapter: RuntimeHostAdapter.appleNetworkExtension,
  ),
  supportState: RuntimeExecutionPlanSupportState.supported,
  remoteEndpointFamily: RuntimeRemoteEndpointFamily.turnServer,
  isDefault: true,
);

void main() {
  testWidgets('mobile shell uses workflow-first navigation', (
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
    );
    await controller.initialize();
    await tester.pumpWidget(MobileShellApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Finish provider validation'), findsOneWidget);
    expect(find.text('Open browser'), findsOneWidget);
    expect(find.text("I've completed it"), findsOneWidget);
    expect(find.text('Providers'), findsWidgets);
    expect(find.text('Open activity'), findsOneWidget);
    expect(find.text('Edit profiles'), findsNothing);
    expect(find.text('Open routing'), findsNothing);

    await _openSupportDiagnostics(tester);

    expect(
      find.text('Android VPN Service', skipOffstage: false),
      findsOneWidget,
    );
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
    await _openProfilesTab(tester);
    await _openProfileEditorFromProfiles(tester);
    await tester.enterText(find.byType(TextField).first, 'vk mobile draft');
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home').first);
    await tester.pumpAndSettle();
    await _openProfilesTab(tester);
    expect(controller.draft.name, 'vk mobile draft');
  });

  testWidgets(
    'shell host indicator keeps host connection details out of the main workflow until requested',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = MobileShellController(
        bridge: _FakeMobileHostBridge(),
        stateStore: _InMemoryStateStore(MobileShellState.empty()),
      );
      await controller.initialize();
      await tester.pumpWidget(MobileShellApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Host ready'), findsOneWidget);
      expect(
        find.textContaining('Connected to embedded mobile host bridge'),
        findsNothing,
      );

      await tester.tap(find.byTooltip('Host ready'));
      await tester.pumpAndSettle();

      expect(find.text('Mobile host ready'), findsOneWidget);
      expect(
        find.textContaining('Connected to embedded mobile host bridge'),
        findsOneWidget,
      );
      expect(find.text('Open diagnostics'), findsOneWidget);
    },
  );

  testWidgets(
    'home primary action resolves the selected profile and then disconnects from the same surface',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

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
      );

      await controller.initialize();
      await tester.pumpWidget(MobileShellApp(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Turn on VPN'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(bridge.startResolutionCalls, hasLength(1));
      expect(bridge.startResolutionCalls.single.provider, 'vk');
      expect(
        bridge.startResolutionCalls.single.input.link,
        'https://vk.com/call/join/test',
      );
      expect(bridge.startedPlatformTunnelResolutionIDs, <String?>[
        'resolution-1',
      ]);
      expect(find.text('Turn off VPN'), findsOneWidget);

      await tester.tap(find.text('Turn off VPN'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(bridge.stoppedPlatformTunnels, <PlatformTunnelMode>[
        PlatformTunnelMode.androidVpnService,
      ]);
    },
  );

  testWidgets(
    'home keeps vpn-first runtime context when add profile clears the current selection',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final profile = ProfileRecord(
        id: 'profile-1',
        name: 'vk live',
        spec: _profileSpec(),
      );
      final controller = MobileShellController(
        bridge: _FakeMobileHostBridge(),
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: <ProfileRecord>[profile],
            providerConfigs: const <ProviderConfigRecord>[],
            selectedProfileId: profile.id,
            draft: ProfileDraft.fromProfile(profile),
          ),
        ),
      );

      await controller.initialize();
      await tester.pumpWidget(MobileShellApp(controller: controller));
      await tester.pumpAndSettle();

      await _openProfilesTab(tester);
      await tester.tap(find.text('Add profile'));
      await tester.pumpAndSettle();

      expect(controller.selectedProfileId, isNull);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home').first);
      await tester.pumpAndSettle();

      expect(find.text('Choose a profile'), findsOneWidget);
      expect(find.text('Mode and scope'), findsOneWidget);
      expect(find.text('Continue in Profiles'), findsOneWidget);
      expect(find.text('Open activity'), findsOneWidget);
      expect(find.text('Open routing'), findsNothing);
    },
  );

  testWidgets(
    'providers move to top-level navigation while profiles overflow stays profile-only',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = MobileShellController(
        bridge: _FakeMobileHostBridge(),
        stateStore: _InMemoryStateStore(MobileShellState.empty()),
      );

      await controller.initialize();
      await tester.pumpWidget(MobileShellApp(controller: controller));
      await tester.pumpAndSettle();

      await _openProfilesTab(tester);

      expect(find.text('No saved profiles yet'), findsOneWidget);
      expect(find.text('Add profile'), findsOneWidget);
      expect(find.text('Import invite'), findsNothing);
      expect(find.text('Manage providers'), findsNothing);
      expect(find.byTooltip('Profiles actions'), findsOneWidget);

      await _openProfilesMenu(tester);

      expect(find.text('Import invite'), findsOneWidget);
      expect(find.text('Manage providers'), findsNothing);
      await tester.tapAt(const Offset(200, 200));
      await tester.pumpAndSettle();

      await _openProvidersTab(tester);

      expect(find.text('App-owned provider catalog'), findsOneWidget);
      expect(find.text('Supported provider families'), findsOneWidget);
    },
  );

  testWidgets(
    'mobile shell exposes dedicated routing surface for android vpn mode',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final profile = ProfileRecord(
        id: 'profile-1',
        name: 'vk live',
        spec: _profileSpec(),
      );
      final controller = MobileShellController(
        bridge: _FakeMobileHostBridge(),
        appInventory: _FakeMobilePlatformAppInventory(
          apps: const <MobilePlatformApp>[
            MobilePlatformApp(packageName: 'org.signal', label: 'Signal'),
            MobilePlatformApp(
              packageName: 'org.telegram.messenger',
              label: 'Telegram',
            ),
          ],
        ),
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: <ProfileRecord>[profile],
            providerConfigs: const <ProviderConfigRecord>[],
            selectedProfileId: profile.id,
            draft: ProfileDraft.fromProfile(profile),
          ),
        ),
      );

      await controller.initialize();
      await tester.pumpWidget(MobileShellApp(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Routing').first);
      await tester.pumpAndSettle();

      expect(find.text('Routing'), findsWidgets);
      expect(find.text('Search apps'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Included apps').first);
      await tester.pumpAndSettle();

      expect(find.text('Search apps'), findsOneWidget);
      await tester.tap(find.text('Signal').first);
      await tester.pumpAndSettle();

      expect(
        controller.activePlatformModePreferences.allowedPackages,
        contains('org.signal'),
      );
    },
  );

  testWidgets(
    'mobile shell hides routing as a primary path for modes without app routing support',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final profile = ProfileRecord(
        id: 'profile-1',
        name: 'vk live',
        spec: _profileSpec(),
      );
      final controller = MobileShellController(
        bridge: _FakeMobileHostBridge(
          readyResult: const MobileHostConnectionResult(
            state: MobileHostLifecycleState.ready,
            message: 'Connected to non-routing mobile host bridge',
            info: _nonRoutingReadyHostInfo,
            description: 'fake-test-bridge',
          ),
        ),
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: <ProfileRecord>[profile],
            providerConfigs: const <ProviderConfigRecord>[],
            selectedProfileId: profile.id,
            draft: ProfileDraft.fromProfile(profile),
          ),
        ),
      );

      await controller.initialize();
      await tester.pumpWidget(MobileShellApp(controller: controller));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Per-app routing is unavailable for this mobile mode.',
        ),
        findsOneWidget,
      );
      expect(find.text('Routing'), findsNothing);
      expect(find.text('Open routing'), findsNothing);

      await _openProfilesTab(tester);
      expect(find.text('Routing'), findsNothing);
    },
  );

  testWidgets(
    'mobile shell preserves draft and routing state across width changes',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(700, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final profile = ProfileRecord(
        id: 'profile-1',
        name: 'vk live',
        spec: _profileSpec(),
      );
      final controller = MobileShellController(
        bridge: _FakeMobileHostBridge(),
        appInventory: _FakeMobilePlatformAppInventory(
          apps: const <MobilePlatformApp>[
            MobilePlatformApp(packageName: 'org.signal', label: 'Signal'),
          ],
        ),
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: <ProfileRecord>[profile],
            providerConfigs: const <ProviderConfigRecord>[],
            selectedProfileId: profile.id,
            draft: ProfileDraft.fromProfile(profile),
          ),
        ),
      );

      await controller.initialize();
      await tester.pumpWidget(MobileShellApp(controller: controller));
      await tester.pumpAndSettle();

      await _openProfilesTab(tester);
      await _openProfileEditorFromProfiles(tester);
      await tester.enterText(find.byType(TextField).first, 'resize draft');
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      await _openProfilesMenu(tester);
      await tester.tap(find.text('Routing').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Included apps').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Signal').first);
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(1200, 1600);
      await tester.pumpAndSettle();

      expect(
        controller.activePlatformModePreferences.allowedPackages,
        contains('org.signal'),
      );
      expect(find.text('Routing'), findsWidgets);

      await _openProfilesTab(tester);
      expect(controller.draft.name, 'resize draft');
    },
  );

  testWidgets(
    'mobile shell renders owned-browser challenges in-app without manual fallback',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final runner = _FakeOwnedBrowserChallengeRunner(
        result: ChallengeContinuationSubmission(
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
      final bridge = _FakeMobileHostBridge(
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
            prompt: 'Continue inside the in-app browser.',
            openUrl: 'https://vk.com/call/join/test',
            status: ChallengeStatus.pending,
            completionMode: ChallengeCompletionMode.ownedBrowserObserved,
            ownedBrowser: const ChallengeOwnedBrowserMetadata(
              cookieUrls: <String>['https://login.vk.ru/'],
            ),
            createdAt: DateTime.utc(2026, 4, 7, 12, 0),
            updatedAt: DateTime.utc(2026, 4, 7, 12, 1),
          ),
        },
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
      );
      await controller.initialize();
      await tester.pumpWidget(
        MobileShellApp(
          controller: controller,
          ownedBrowserChallengeRunner: runner,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Finish provider validation'), findsOneWidget);
      expect(find.text('Continue in app'), findsOneWidget);
      expect(find.text("I've completed it"), findsNothing);

      await tester.tap(find.text('Continue in app'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(runner.challengeIds, <String>['challenge-1']);
      expect(bridge.continueChallengeCalls, <String>['challenge-1']);
      expect(bridge.continueChallengePayloads, hasLength(1));
      expect(
        bridge.continueChallengePayloads.single?.cookies.single.value,
        'owned-session',
      );
      expect(find.text('Turn on VPN'), findsOneWidget);
      expect(
        find.text(
          'Inspect provider resolutions and session state without crowding the main workflow.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'mobile shell reuses the continued resolution when Home starts VPN after an in-app browser flow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final resolution = ResolutionRecord(
        id: 'resolution-continued',
        provider: 'vk',
        input: const ResolutionInput(
          provider: 'vk',
          kind: ProviderInputKind.link,
          linkRedacted: 'https://vk.com/call/join/<redacted:invite-token>',
          interactiveProvider: true,
        ),
        state: ResolutionState.resolved,
        artifact: const ResolutionArtifactRecord(
          family: ArtifactFamily.genericTurn,
          actions: <ResolutionActionRecord>[
            ResolutionActionRecord(
              id: ArtifactAction.startOnThisDevice,
              executionOwner: ActionExecutionOwner.host,
            ),
          ],
        ),
        export: const ResolutionExportStatus(supported: true),
        startedAt: DateTime.utc(2026, 4, 7, 12, 0),
        updatedAt: DateTime.utc(2026, 4, 7, 12, 1),
      );
      final challenge = ChallengeRecord(
        id: 'challenge-1',
        sessionId: 'session-1',
        resolutionId: resolution.id,
        provider: 'vk',
        stage: 'provider_resolve',
        kind: 'browser',
        prompt: 'Continue inside the in-app browser.',
        openUrl: 'https://vk.com/call/join/test',
        status: ChallengeStatus.pending,
        completionMode: ChallengeCompletionMode.ownedBrowserObserved,
        ownedBrowser: const ChallengeOwnedBrowserMetadata(
          cookieUrls: <String>['https://login.vk.ru/'],
        ),
        createdAt: DateTime.utc(2026, 4, 7, 12, 0),
        updatedAt: DateTime.utc(2026, 4, 7, 12, 1),
      );
      final runner = _FakeOwnedBrowserChallengeRunner(
        result: const ChallengeContinuationSubmission(
          cookies: <BrowserCookieRecord>[
            BrowserCookieRecord(
              name: 'session',
              value: 'owned-session',
              domain: 'login.vk.ru',
              path: '/',
            ),
          ],
        ),
      );
      final bridge = _FakeMobileHostBridge(
        resolutionsList: <ResolutionRecord>[resolution],
        sessionsList: <SessionRecord>[
          SessionRecord(
            id: 'session-1',
            profileId: 'profile-1',
            profileName: 'vk live',
            profile: _profileSpec(),
            state: SessionState.challengeRequired,
            activeChallengeId: challenge.id,
            startedAt: DateTime.utc(2026, 4, 7, 12, 0),
            updatedAt: DateTime.utc(2026, 4, 7, 12, 1),
          ),
        ],
        challengeMap: <String, ChallengeRecord>{challenge.id: challenge},
        startPlatformTunnelResult: const PlatformTunnelStartResult(
          mode: PlatformTunnelMode.androidVpnService,
          ready: true,
          stage: PlatformTunnelStartupStage.runtimeAttach,
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
      );
      await controller.initialize();
      await tester.pumpWidget(
        MobileShellApp(
          controller: controller,
          ownedBrowserChallengeRunner: runner,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue in app'), findsOneWidget);
      await tester.tap(find.text('Continue in app'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(controller.selectedResolutionId, resolution.id);
      expect(find.text('Turn on VPN'), findsOneWidget);

      await tester.tap(find.text('Turn on VPN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(bridge.startResolutionCalls, isEmpty);
      expect(bridge.startedPlatformTunnelResolutionIDs, <String?>[
        resolution.id,
      ]);
    },
  );

  testWidgets(
    'mobile shell falls back to the cached challenge resolution when continueChallenge omits resolution_id',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final resolution = ResolutionRecord(
        id: 'resolution-cached',
        provider: 'vk',
        input: const ResolutionInput(
          provider: 'vk',
          kind: ProviderInputKind.link,
          linkRedacted: 'https://vk.com/call/join/<redacted:invite-token>',
          interactiveProvider: true,
        ),
        state: ResolutionState.resolved,
        artifact: const ResolutionArtifactRecord(
          family: ArtifactFamily.genericTurn,
          actions: <ResolutionActionRecord>[
            ResolutionActionRecord(
              id: ArtifactAction.startOnThisDevice,
              executionOwner: ActionExecutionOwner.host,
            ),
          ],
        ),
        export: const ResolutionExportStatus(supported: true),
        startedAt: DateTime.utc(2026, 4, 7, 12, 0),
        updatedAt: DateTime.utc(2026, 4, 7, 12, 1),
      );
      final cachedChallenge = ChallengeRecord(
        id: 'challenge-1',
        sessionId: 'session-1',
        resolutionId: resolution.id,
        provider: 'vk',
        stage: 'provider_resolve',
        kind: 'browser',
        prompt: 'Continue inside the in-app browser.',
        openUrl: 'https://vk.com/call/join/test',
        status: ChallengeStatus.pending,
        completionMode: ChallengeCompletionMode.ownedBrowserObserved,
        ownedBrowser: const ChallengeOwnedBrowserMetadata(
          cookieUrls: <String>['https://login.vk.ru/'],
        ),
        createdAt: DateTime.utc(2026, 4, 7, 12, 0),
        updatedAt: DateTime.utc(2026, 4, 7, 12, 1),
      );
      final continuedChallenge = ChallengeRecord(
        id: cachedChallenge.id,
        sessionId: cachedChallenge.sessionId,
        provider: cachedChallenge.provider,
        stage: cachedChallenge.stage,
        kind: cachedChallenge.kind,
        prompt: cachedChallenge.prompt,
        openUrl: cachedChallenge.openUrl,
        status: ChallengeStatus.completed,
        completionMode: cachedChallenge.completionMode,
        browserReturn: cachedChallenge.browserReturn,
        ownedBrowser: cachedChallenge.ownedBrowser,
        createdAt: cachedChallenge.createdAt,
        updatedAt: cachedChallenge.updatedAt.add(const Duration(seconds: 1)),
      );
      final runner = _FakeOwnedBrowserChallengeRunner(
        result: const ChallengeContinuationSubmission(
          cookies: <BrowserCookieRecord>[
            BrowserCookieRecord(
              name: 'session',
              value: 'owned-session',
              domain: 'login.vk.ru',
              path: '/',
            ),
          ],
        ),
      );
      final bridge = _FakeMobileHostBridge(
        resolutionsList: <ResolutionRecord>[resolution],
        sessionsList: <SessionRecord>[
          SessionRecord(
            id: 'session-1',
            profileId: 'profile-1',
            profileName: 'vk live',
            profile: _profileSpec(),
            state: SessionState.challengeRequired,
            activeChallengeId: cachedChallenge.id,
            startedAt: DateTime.utc(2026, 4, 7, 12, 0),
            updatedAt: DateTime.utc(2026, 4, 7, 12, 1),
          ),
        ],
        challengeMap: <String, ChallengeRecord>{
          cachedChallenge.id: continuedChallenge,
        },
        startPlatformTunnelResult: const PlatformTunnelStartResult(
          mode: PlatformTunnelMode.androidVpnService,
          ready: true,
          stage: PlatformTunnelStartupStage.runtimeAttach,
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
      );
      await controller.initialize();
      await tester.pumpWidget(
        MobileShellApp(
          controller: controller,
          ownedBrowserChallengeRunner: runner,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue in app'), findsOneWidget);
      await tester.tap(find.text('Continue in app'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(controller.selectedResolutionId, resolution.id);
      await tester.tap(find.text('Turn on VPN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(bridge.startResolutionCalls, isEmpty);
      expect(bridge.startedPlatformTunnelResolutionIDs, <String?>[
        resolution.id,
      ]);
    },
  );

  testWidgets(
    'mobile shell keeps resolution ordering stable and preserves the selected resolution across refresh',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final resolutionFailed = ResolutionRecord(
        id: 'resolution-failed',
        provider: 'vk',
        input: const ResolutionInput(
          provider: 'vk',
          kind: ProviderInputKind.link,
          linkRedacted: 'https://vk.com/call/join/failed',
          interactiveProvider: true,
        ),
        state: ResolutionState.failed,
        export: const ResolutionExportStatus(supported: false),
        startedAt: DateTime.utc(2026, 4, 7, 12, 0, 0),
        updatedAt: DateTime.utc(2026, 4, 7, 12, 1, 0),
      );
      final resolutionResolved = ResolutionRecord(
        id: 'resolution-resolved',
        provider: 'vk',
        input: const ResolutionInput(
          provider: 'vk',
          kind: ProviderInputKind.link,
          linkRedacted: 'https://vk.com/call/join/resolved',
          interactiveProvider: true,
        ),
        state: ResolutionState.resolved,
        export: const ResolutionExportStatus(supported: false),
        startedAt: DateTime.utc(2026, 4, 7, 12, 0, 30),
        updatedAt: DateTime.utc(2026, 4, 7, 12, 2, 0),
      );
      final resolutionChallenge = ResolutionRecord(
        id: 'resolution-challenge',
        provider: 'vk',
        input: const ResolutionInput(
          provider: 'vk',
          kind: ProviderInputKind.link,
          linkRedacted: 'https://vk.com/call/join/challenge',
          interactiveProvider: true,
        ),
        state: ResolutionState.challengeRequired,
        export: const ResolutionExportStatus(supported: false),
        startedAt: DateTime.utc(2026, 4, 7, 12, 1, 0),
        updatedAt: DateTime.utc(2026, 4, 7, 12, 3, 0),
      );

      final bridge = _FakeMobileHostBridge(
        resolutionsList: <ResolutionRecord>[
          resolutionFailed,
          resolutionResolved,
          resolutionChallenge,
        ],
      );
      final controller = MobileShellController(
        bridge: bridge,
        stateStore: _InMemoryStateStore(MobileShellState.empty()),
      );

      await controller.initialize();

      expect(
        controller.resolutions.map((ResolutionRecord record) => record.id),
        <String>[
          'resolution-challenge',
          'resolution-resolved',
          'resolution-failed',
        ],
      );
      expect(controller.selectedResolutionId, 'resolution-challenge');

      controller.selectResolution('resolution-resolved');
      bridge._resolutions
        ..clear()
        ..addAll(<ResolutionRecord>[
          resolutionResolved,
          resolutionFailed,
          resolutionChallenge,
        ]);

      await controller.refresh();

      expect(
        controller.resolutions.map((ResolutionRecord record) => record.id),
        <String>[
          'resolution-challenge',
          'resolution-resolved',
          'resolution-failed',
        ],
      );
      expect(controller.selectedResolutionId, 'resolution-resolved');
    },
  );

  testWidgets(
    'mobile shell cancels owned-browser challenges when the in-app flow is dismissed',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final runner = _FakeOwnedBrowserChallengeRunner();
      final bridge = _FakeMobileHostBridge(
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
            prompt: 'Continue inside the in-app browser.',
            openUrl: 'https://vk.com/call/join/test',
            status: ChallengeStatus.pending,
            completionMode: ChallengeCompletionMode.ownedBrowserObserved,
            ownedBrowser: const ChallengeOwnedBrowserMetadata(
              cookieUrls: <String>['https://login.vk.ru/'],
            ),
            createdAt: DateTime.utc(2026, 4, 7, 12, 0),
            updatedAt: DateTime.utc(2026, 4, 7, 12, 1),
          ),
        },
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
      );
      await controller.initialize();
      await tester.pumpWidget(
        MobileShellApp(
          controller: controller,
          ownedBrowserChallengeRunner: runner,
        ),
      );
      await tester.pumpAndSettle();

      await _openSupportTab(tester);
      await tester.tap(find.text('Sessions (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue in app', skipOffstage: false));
      await tester.pumpAndSettle();

      expect(runner.challengeIds, <String>['challenge-1']);
      expect(bridge.continueChallengeCalls, isEmpty);
      expect(bridge.cancelChallengeCalls, <String>['challenge-1']);
      expect(
        controller.notice,
        contains('Cancelled the in-app browser continuation'),
      );
    },
  );

  testWidgets(
    'mobile shell fail-closes owned-browser challenges when the in-app flow throws',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final runner = _FakeOwnedBrowserChallengeRunner(
        error: StateError('embedded cookies missing'),
      );
      final bridge = _FakeMobileHostBridge(
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
            prompt: 'Continue inside the in-app browser.',
            openUrl: 'https://vk.com/call/join/test',
            status: ChallengeStatus.pending,
            completionMode: ChallengeCompletionMode.ownedBrowserObserved,
            ownedBrowser: const ChallengeOwnedBrowserMetadata(
              cookieUrls: <String>['https://login.vk.ru/'],
            ),
            createdAt: DateTime.utc(2026, 4, 7, 12, 0),
            updatedAt: DateTime.utc(2026, 4, 7, 12, 1),
          ),
        },
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
      );
      await controller.initialize();
      await tester.pumpWidget(
        MobileShellApp(
          controller: controller,
          ownedBrowserChallengeRunner: runner,
        ),
      );
      await tester.pumpAndSettle();

      await _openSupportTab(tester);
      await tester.tap(find.text('Sessions (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue in app', skipOffstage: false));
      await tester.pumpAndSettle();

      expect(runner.challengeIds, <String>['challenge-1']);
      expect(bridge.continueChallengeCalls, isEmpty);
      expect(bridge.cancelChallengeCalls, <String>['challenge-1']);
      expect(controller.notice, contains('In-app browser continuation failed'));
      expect(controller.notice, contains('challenge-1'));
    },
  );

  testWidgets(
    'owned-browser page yields shell chrome to web content while keyboard is visible even after a web resource error',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2560, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final runner = WebViewOwnedBrowserChallengeRunner(
        sessionFactory:
            (
              ValueChanged<String> onWebResourceError,
              ValueChanged<Uri> onPageNavigation,
            ) {
              return OwnedBrowserWebSession(
                viewBuilder: (BuildContext context) => const SizedBox.expand(
                  key: Key('owned-browser-webview'),
                  child: ColoredBox(color: Colors.black),
                ),
                load: (Uri uri) async {
                  onWebResourceError('net::ERR_FAILED');
                },
                clearCookies: () async {},
                collectCookies: (List<String> urls) async =>
                    const <BrowserCookieRecord>[],
              );
            },
      );
      final challenge = ChallengeRecord(
        id: 'challenge-1',
        sessionId: 'session-1',
        provider: 'vk',
        stage: 'provider_resolve',
        kind: 'captcha',
        prompt: 'Continue inside the in-app browser.',
        openUrl: 'https://vk.com/call/join/test',
        status: ChallengeStatus.pending,
        completionMode: ChallengeCompletionMode.ownedBrowserObserved,
        ownedBrowser: const ChallengeOwnedBrowserMetadata(
          cookieUrls: <String>['https://login.vk.ru/'],
        ),
        createdAt: DateTime.utc(2026, 4, 7, 12, 0),
        updatedAt: DateTime.utc(2026, 4, 7, 12, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          builder: (BuildContext context, Widget? child) {
            return MediaQuery(
              // Keep MediaQuery stale to prove the page reacts to real window
              // metrics instead of relying only on inherited viewInsets.
              data: const MediaQueryData(size: Size(2560, 1600)),
              child: child!,
            );
          },
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      unawaited(runner.run(context, challenge));
                    },
                    child: const Text('Open challenge'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open challenge'));
      await tester.pumpAndSettle();

      final webViewFinder = find.byKey(const Key('owned-browser-webview'));

      expect(find.text('Continue inside the in-app browser.'), findsOneWidget);
      expect(find.text('net::ERR_FAILED'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('vk challenge'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);

      tester.view.viewInsets = const FakeViewPadding(bottom: 700);
      await tester.pumpAndSettle();

      expect(find.text('Continue inside the in-app browser.'), findsNothing);
      expect(find.text('net::ERR_FAILED'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('vk challenge'), findsOneWidget);
      expect(webViewFinder, findsOneWidget);
      expect(find.text('Hide keyboard'), findsOneWidget);
    },
  );

  testWidgets(
    'owned-browser page keeps the embedded viewport size stable across IME transitions',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2560, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final runner = WebViewOwnedBrowserChallengeRunner(
        sessionFactory:
            (
              ValueChanged<String> onWebResourceError,
              ValueChanged<Uri> onPageNavigation,
            ) {
              return OwnedBrowserWebSession(
                viewBuilder: (BuildContext context) => const SizedBox.expand(
                  key: Key('owned-browser-webview'),
                  child: ColoredBox(color: Colors.black),
                ),
                load: (Uri uri) async {},
                clearCookies: () async {},
                collectCookies: (List<String> urls) async =>
                    const <BrowserCookieRecord>[],
              );
            },
      );
      final challenge = ChallengeRecord(
        id: 'challenge-1',
        sessionId: 'session-1',
        provider: 'vk',
        stage: 'provider_resolve',
        kind: 'captcha',
        prompt: 'Continue inside the in-app browser.',
        openUrl: 'https://vk.com/call/join/test',
        status: ChallengeStatus.pending,
        completionMode: ChallengeCompletionMode.ownedBrowserObserved,
        ownedBrowser: const ChallengeOwnedBrowserMetadata(
          cookieUrls: <String>['https://login.vk.ru/'],
        ),
        createdAt: DateTime.utc(2026, 4, 7, 12, 0),
        updatedAt: DateTime.utc(2026, 4, 7, 12, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      unawaited(runner.run(context, challenge));
                    },
                    child: const Text('Open challenge'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open challenge'));
      await tester.pumpAndSettle();

      final webViewFinder = find.byKey(const Key('owned-browser-webview'));
      final viewportSizeBeforeIme = tester.getSize(webViewFinder);

      tester.view.viewInsets = const FakeViewPadding(bottom: 700);
      await tester.pumpAndSettle();

      expect(tester.getSize(webViewFinder), viewportSizeBeforeIme);
      expect(find.text('Hide keyboard'), findsOneWidget);
    },
  );

  testWidgets('owned-browser page exposes a hide-keyboard action', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var hideCalls = 0;
    final runner = WebViewOwnedBrowserChallengeRunner(
      sessionFactory:
          (
            ValueChanged<String> onWebResourceError,
            ValueChanged<Uri> onPageNavigation,
          ) {
            return OwnedBrowserWebSession(
              viewBuilder: (BuildContext context) => const SizedBox.expand(
                key: Key('owned-browser-webview'),
                child: ColoredBox(color: Colors.black),
              ),
              load: (Uri uri) async {},
              clearCookies: () async {},
              collectCookies: (List<String> urls) async =>
                  const <BrowserCookieRecord>[],
            );
          },
      keyboardHider: _FakeMobileSoftKeyboardHider(
        onHide: () {
          hideCalls += 1;
        },
      ),
    );
    final challenge = ChallengeRecord(
      id: 'challenge-1',
      sessionId: 'session-1',
      provider: 'vk',
      stage: 'provider_resolve',
      kind: 'captcha',
      prompt: 'Continue inside the in-app browser.',
      openUrl: 'https://vk.com/call/join/test',
      status: ChallengeStatus.pending,
      completionMode: ChallengeCompletionMode.ownedBrowserObserved,
      ownedBrowser: const ChallengeOwnedBrowserMetadata(
        cookieUrls: <String>['https://login.vk.ru/'],
      ),
      createdAt: DateTime.utc(2026, 4, 7, 12, 0),
      updatedAt: DateTime.utc(2026, 4, 7, 12, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    unawaited(runner.run(context, challenge));
                  },
                  child: const Text('Open challenge'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open challenge'));
    await tester.pumpAndSettle();

    tester.view.viewInsets = const FakeViewPadding(bottom: 700);
    await tester.pumpAndSettle();

    expect(find.text('Hide keyboard'), findsOneWidget);

    await tester.tap(find.text('Hide keyboard'));
    await tester.pump();

    expect(hideCalls, 1);
  });

  testWidgets(
    'owned-browser page reloads the original VK invite once after login lands on feed',
    (WidgetTester tester) async {
      final inviteUri = Uri.parse('https://vk.com/call/join/test');
      final loadedUris = <Uri>[];
      final runner = WebViewOwnedBrowserChallengeRunner(
        sessionFactory:
            (
              ValueChanged<String> onWebResourceError,
              ValueChanged<Uri> onPageNavigation,
            ) {
              return OwnedBrowserWebSession(
                viewBuilder: (BuildContext context) => const SizedBox.expand(
                  child: ColoredBox(color: Colors.black),
                ),
                load: (Uri uri) async {
                  loadedUris.add(uri);
                  if (uri == inviteUri) {
                    onPageNavigation(Uri.parse('https://m.vk.com/feed'));
                  }
                },
                clearCookies: () async {},
                collectCookies: (List<String> urls) async =>
                    const <BrowserCookieRecord>[],
              );
            },
      );
      final challenge = ChallengeRecord(
        id: 'challenge-1',
        sessionId: 'session-1',
        provider: 'vk',
        stage: 'provider_resolve',
        kind: 'captcha',
        prompt: 'Continue inside the in-app browser.',
        openUrl: inviteUri.toString(),
        status: ChallengeStatus.pending,
        completionMode: ChallengeCompletionMode.ownedBrowserObserved,
        ownedBrowser: const ChallengeOwnedBrowserMetadata(
          cookieUrls: <String>['https://login.vk.ru/'],
        ),
        createdAt: DateTime.utc(2026, 4, 7, 12, 0),
        updatedAt: DateTime.utc(2026, 4, 7, 12, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      unawaited(runner.run(context, challenge));
                    },
                    child: const Text('Open challenge'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open challenge'));
      await tester.pumpAndSettle();

      expect(loadedUris, <Uri>[inviteUri, inviteUri]);
    },
  );

  testWidgets('owned-browser page applies the VK desktop-like user agent', (
    WidgetTester tester,
  ) async {
    final requestedUserAgents = <String>[];
    final runner = WebViewOwnedBrowserChallengeRunner(
      sessionFactory:
          (
            ValueChanged<String> onWebResourceError,
            ValueChanged<Uri> onPageNavigation,
          ) {
            return OwnedBrowserWebSession(
              viewBuilder: (BuildContext context) =>
                  const SizedBox.expand(child: ColoredBox(color: Colors.black)),
              load: (Uri uri) async {},
              clearCookies: () async {},
              setUserAgent: (String userAgent) async {
                requestedUserAgents.add(userAgent);
              },
              collectCookies: (List<String> urls) async =>
                  const <BrowserCookieRecord>[],
            );
          },
    );
    final challenge = ChallengeRecord(
      id: 'challenge-1',
      sessionId: 'session-1',
      provider: 'vk',
      stage: 'provider_resolve',
      kind: 'captcha',
      prompt: 'Continue inside the in-app browser.',
      openUrl: 'https://vk.com/call/join/test',
      status: ChallengeStatus.pending,
      completionMode: ChallengeCompletionMode.ownedBrowserObserved,
      ownedBrowser: const ChallengeOwnedBrowserMetadata(
        cookieUrls: <String>['https://login.vk.ru/'],
      ),
      createdAt: DateTime.utc(2026, 4, 7, 12, 0),
      updatedAt: DateTime.utc(2026, 4, 7, 12, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    unawaited(runner.run(context, challenge));
                  },
                  child: const Text('Open challenge'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open challenge'));
    await tester.pumpAndSettle();

    expect(requestedUserAgents, <String>[
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:144.0) Gecko/20100101 Firefox/144.0',
    ]);
  });

  testWidgets('owned-browser page preserves VK cookies across sessions', (
    WidgetTester tester,
  ) async {
    var clearCookiesCalls = 0;
    final runner = WebViewOwnedBrowserChallengeRunner(
      sessionFactory:
          (
            ValueChanged<String> onWebResourceError,
            ValueChanged<Uri> onPageNavigation,
          ) {
            return OwnedBrowserWebSession(
              viewBuilder: (BuildContext context) =>
                  const SizedBox.expand(child: ColoredBox(color: Colors.black)),
              load: (Uri uri) async {},
              clearCookies: () async {
                clearCookiesCalls += 1;
              },
              collectCookies: (List<String> urls) async =>
                  const <BrowserCookieRecord>[],
            );
          },
    );
    final challenge = ChallengeRecord(
      id: 'challenge-1',
      sessionId: 'session-1',
      provider: 'vk',
      stage: 'provider_resolve',
      kind: 'captcha',
      prompt: 'Continue inside the in-app browser.',
      openUrl: 'https://vk.com/call/join/test',
      status: ChallengeStatus.pending,
      completionMode: ChallengeCompletionMode.ownedBrowserObserved,
      ownedBrowser: const ChallengeOwnedBrowserMetadata(
        cookieUrls: <String>['https://login.vk.ru/'],
      ),
      createdAt: DateTime.utc(2026, 4, 7, 12, 0),
      updatedAt: DateTime.utc(2026, 4, 7, 12, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    unawaited(runner.run(context, challenge));
                  },
                  child: const Text('Open challenge'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open challenge'));
    await tester.pumpAndSettle();

    expect(clearCookiesCalls, 0);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(clearCookiesCalls, 0);
  });

  testWidgets('owned-browser page resets non-VK cookies per session', (
    WidgetTester tester,
  ) async {
    var clearCookiesCalls = 0;
    final runner = WebViewOwnedBrowserChallengeRunner(
      sessionFactory:
          (
            ValueChanged<String> onWebResourceError,
            ValueChanged<Uri> onPageNavigation,
          ) {
            return OwnedBrowserWebSession(
              viewBuilder: (BuildContext context) =>
                  const SizedBox.expand(child: ColoredBox(color: Colors.black)),
              load: (Uri uri) async {},
              clearCookies: () async {
                clearCookiesCalls += 1;
              },
              collectCookies: (List<String> urls) async =>
                  const <BrowserCookieRecord>[],
            );
          },
    );
    final challenge = ChallengeRecord(
      id: 'challenge-1',
      sessionId: 'session-1',
      provider: 'example-provider',
      stage: 'provider_resolve',
      kind: 'captcha',
      prompt: 'Continue inside the in-app browser.',
      openUrl: 'https://example.com/challenge',
      status: ChallengeStatus.pending,
      completionMode: ChallengeCompletionMode.ownedBrowserObserved,
      ownedBrowser: const ChallengeOwnedBrowserMetadata(
        cookieUrls: <String>['https://example.com/'],
      ),
      createdAt: DateTime.utc(2026, 4, 7, 12, 0),
      updatedAt: DateTime.utc(2026, 4, 7, 12, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    unawaited(runner.run(context, challenge));
                  },
                  child: const Text('Open challenge'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open challenge'));
    await tester.pumpAndSettle();

    expect(clearCookiesCalls, 1);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(clearCookiesCalls, 2);
  });

  testWidgets(
    'owned-browser page refreshes the embedded viewport while IME is visible',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2560, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var refreshCalls = 0;
      final runner = WebViewOwnedBrowserChallengeRunner(
        sessionFactory:
            (
              ValueChanged<String> onWebResourceError,
              ValueChanged<Uri> onPageNavigation,
            ) {
              return OwnedBrowserWebSession(
                viewBuilder: (BuildContext context) => const SizedBox.expand(
                  child: ColoredBox(color: Colors.black),
                ),
                load: (Uri uri) async {},
                clearCookies: () async {},
                collectCookies: (List<String> urls) async =>
                    const <BrowserCookieRecord>[],
                refreshViewport: () async {
                  refreshCalls += 1;
                },
              );
            },
      );
      final challenge = ChallengeRecord(
        id: 'challenge-1',
        sessionId: 'session-1',
        provider: 'vk',
        stage: 'provider_resolve',
        kind: 'captcha',
        prompt: 'Continue inside the in-app browser.',
        openUrl: 'https://vk.com/call/join/test',
        status: ChallengeStatus.pending,
        completionMode: ChallengeCompletionMode.ownedBrowserObserved,
        ownedBrowser: const ChallengeOwnedBrowserMetadata(
          cookieUrls: <String>['https://login.vk.ru/'],
        ),
        createdAt: DateTime.utc(2026, 4, 7, 12, 0),
        updatedAt: DateTime.utc(2026, 4, 7, 12, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      unawaited(runner.run(context, challenge));
                    },
                    child: const Text('Open challenge'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open challenge'));
      await tester.pumpAndSettle();

      expect(refreshCalls, 0);

      tester.view.viewInsets = const FakeViewPadding(bottom: 700);
      await tester.pump(const Duration(milliseconds: 350));

      expect(refreshCalls, greaterThanOrEqualTo(3));
      final callsWhileOpening = refreshCalls;

      await tester.pump(const Duration(milliseconds: 800));

      expect(refreshCalls, greaterThan(callsWhileOpening));

      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump(const Duration(milliseconds: 350));

      expect(refreshCalls, greaterThanOrEqualTo(6));
      final callsAfterClosing = refreshCalls;

      await tester.pump(const Duration(milliseconds: 800));

      expect(refreshCalls, callsAfterClosing);
    },
  );

  testWidgets(
    'owned-browser page toggles Android soft input mode for the route lifetime',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2560, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final softInputModeCalls = <String>[];
      final runner = WebViewOwnedBrowserChallengeRunner(
        sessionFactory:
            (
              ValueChanged<String> onWebResourceError,
              ValueChanged<Uri> onPageNavigation,
            ) {
              return OwnedBrowserWebSession(
                viewBuilder: (BuildContext context) => const SizedBox.expand(
                  child: ColoredBox(color: Colors.black),
                ),
                load: (Uri uri) async {},
                clearCookies: () async {},
                collectCookies: (List<String> urls) async =>
                    const <BrowserCookieRecord>[],
              );
            },
        softInputModeController: _FakeMobileWindowSoftInputModeController(
          onEnableOwnedBrowserMode: () {
            softInputModeCalls.add('adjustNothing');
          },
          onRestoreDefaultMode: () {
            softInputModeCalls.add('adjustResize');
          },
        ),
      );
      final challenge = ChallengeRecord(
        id: 'challenge-1',
        sessionId: 'session-1',
        provider: 'vk',
        stage: 'provider_resolve',
        kind: 'captcha',
        prompt: 'Continue inside the in-app browser.',
        openUrl: 'https://vk.com/call/join/test',
        status: ChallengeStatus.pending,
        completionMode: ChallengeCompletionMode.ownedBrowserObserved,
        ownedBrowser: const ChallengeOwnedBrowserMetadata(
          cookieUrls: <String>['https://login.vk.ru/'],
        ),
        createdAt: DateTime.utc(2026, 4, 7, 12, 0),
        updatedAt: DateTime.utc(2026, 4, 7, 12, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      unawaited(runner.run(context, challenge));
                    },
                    child: const Text('Open challenge'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open challenge'));
      await tester.pumpAndSettle();

      expect(softInputModeCalls, contains('adjustNothing'));

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(softInputModeCalls, contains('adjustResize'));
    },
  );

  testWidgets('mobile shell exposes reset action for blocked local state', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Routing'), findsWidgets);
    expect(find.text('Reset local state'), findsOneWidget);
    expect(
      find.textContaining('Secure profile secrets are unavailable'),
      findsWidgets,
    );

    await _openSupportDiagnostics(tester);
    expect(find.text('Mobile host ready'), findsOneWidget);
  });

  testWidgets(
    'mobile shell renders incompatible host state in workflow and diagnostics',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final profile = ProfileRecord(
        id: 'profile-1',
        name: 'vk live',
        spec: _profileSpec(),
      );
      final controller = MobileShellController(
        bridge: _FakeMobileHostBridge(
          readyResult: MobileHostConnectionResult(
            state: MobileHostLifecycleState.incompatible,
            message: 'contract mismatch',
            info: const HostInfo(
              contractVersion: '2',
              build: BuildIdentity(
                product: 'vk-turn-proxy-go',
                version: '0.1.0',
                buildNumber: '1',
                revision: 'mobilehost9999',
                role: 'mobile_host',
                target: 'android/debug',
              ),
              capabilities: <Capability>[
                Capability.mobileHostBridge,
                Capability.platformTunnels,
                Capability.runtimeExecutionPlanning,
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
        ),
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: <ProfileRecord>[profile],
            providerConfigs: const <ProviderConfigRecord>[],
            selectedProfileId: profile.id,
            draft: ProfileDraft.fromProfile(profile),
          ),
        ),
      );

      await controller.initialize();
      await tester.pumpWidget(MobileShellApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsWidgets);
      expect(find.byTooltip('Host incompatible'), findsOneWidget);
      expect(find.textContaining('contract mismatch'), findsNothing);

      await tester.tap(find.byTooltip('Host incompatible'));
      await tester.pumpAndSettle();
      expect(find.textContaining('contract mismatch'), findsOneWidget);
      await tester.tap(find.text('Open diagnostics').last);
      await tester.pumpAndSettle();

      expect(find.text('Mobile host incompatible'), findsOneWidget);
      expect(find.text('Contract 2'), findsOneWidget);
    },
  );

  testWidgets('mobile shell shows freshest sessions first with session metadata', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
    );
    await controller.initialize();
    await tester.pumpWidget(MobileShellApp(controller: controller));
    await tester.pumpAndSettle();
    await _openSupportTab(tester);
    await tester.tap(find.text('Sessions (2)'));
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

  testWidgets('mobile shell exposes same-device and handoff actions', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = MobileShellController(
      bridge: _FakeMobileHostBridge(
        resolutionsList: <ResolutionRecord>[
          ResolutionRecord(
            id: 'resolution-1',
            provider: 'vk',
            input: const ResolutionInput(
              provider: 'vk',
              kind: ProviderInputKind.link,
              linkRedacted: 'https://vk.com/call/join/<redacted:invite-token>',
              interactiveProvider: true,
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
          ),
        ],
      ),
      stateStore: _InMemoryStateStore(
        MobileShellState(
          profiles: const <ProfileRecord>[],
          providerConfigs: const <ProviderConfigRecord>[],
          draft: ProfileDraft.defaults(),
        ),
      ),
      handoffAdapter: _FakeMobileHandoffAdapter(),
    );
    await controller.initialize();
    await tester.pumpWidget(MobileShellApp(controller: controller));
    await tester.pumpAndSettle();
    await _openSupportTab(tester);

    expect(
      find.text('Start on this device', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Copy handoff', skipOffstage: false), findsNothing);
    expect(find.text('Share handoff', skipOffstage: false), findsNothing);

    await tester.tap(find.byTooltip('More resolution actions'));
    await tester.pumpAndSettle();

    expect(find.text('Copy handoff', skipOffstage: false), findsOneWidget);
    expect(find.text('Share handoff', skipOffstage: false), findsOneWidget);
  });

  testWidgets('mobile shell renders and executes open room actions', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final browser = _FakeBrowserLauncher();
    final controller = MobileShellController(
      bridge: _FakeMobileHostBridge(
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
      ),
      stateStore: _InMemoryStateStore(
        MobileShellState(
          profiles: const <ProfileRecord>[],
          providerConfigs: const <ProviderConfigRecord>[],
          draft: ProfileDraft.defaults(),
        ),
      ),
      browserLauncher: browser,
    );
    await controller.initialize();
    await tester.pumpWidget(MobileShellApp(controller: controller));
    await tester.pumpAndSettle();
    await _openSupportTab(tester);

    final openRoomButton = find.text('Open room', skipOffstage: false);
    await tester.tap(openRoomButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(browser.openedUrls, <String>[
      'https://room.example.test/rooms/team-sync',
    ]);
  });

  testWidgets('mobile shell renders event stream in diagnostics events', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final eventStream = StreamController<EventRecord>.broadcast();
    final controller = MobileShellController(
      bridge: _FakeMobileHostBridge(eventStream: eventStream.stream),
      stateStore: _InMemoryStateStore(
        MobileShellState(
          profiles: const <ProfileRecord>[],
          providerConfigs: const <ProviderConfigRecord>[],
          draft: ProfileDraft.defaults(),
        ),
      ),
    );

    await controller.initialize();
    await tester.pumpWidget(MobileShellApp(controller: controller));
    await tester.pumpAndSettle();

    eventStream.add(
      EventRecord(
        id: 'event-1',
        timestamp: DateTime.utc(2026, 4, 12, 18, 31),
        sessionId: 'session-1',
        type: EventType.challengeUpdated,
        stage: 'provider_resolve',
        message: 'Browser handoff opened',
        challenge: ChallengeRecord(
          id: 'challenge-1',
          sessionId: 'session-1',
          provider: 'vk',
          stage: 'provider_resolve',
          kind: 'browser',
          prompt: 'Return after the provider browser step.',
          status: ChallengeStatus.pending,
          createdAt: DateTime.utc(2026, 4, 12, 18, 30),
          updatedAt: DateTime.utc(2026, 4, 12, 18, 31),
        ),
      ),
    );
    await tester.pump();

    await _openSupportDiagnostics(tester);
    await tester.tap(find.text('Events (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Event stream', skipOffstage: false), findsOneWidget);
    expect(
      find.textContaining('challenge_updated', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('session-1', skipOffstage: false), findsOneWidget);
  });

  testWidgets('mobile shell keeps unavailable presets explicit', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = MobileShellController(
      bridge: _FakeMobileHostBridge(
        providersList: <ProviderDescriptor>[_providerDescriptors.first],
      ),
      stateStore: _InMemoryStateStore(
        MobileShellState(
          profiles: const <ProfileRecord>[],
          providerConfigs: const <ProviderConfigRecord>[],
          draft: ProfileDraft.defaults(),
        ),
      ),
    );

    await controller.initialize();
    await tester.pumpWidget(MobileShellApp(controller: controller));
    await tester.pumpAndSettle();
    await _openProvidersTab(tester);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('preset-card-generic-turn-default')),
      240,
      scrollable: _workflowScrollable(),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'does not advertise the Generic TURN provider family yet',
      ),
      findsWidgets,
    );
  });

  testWidgets('mobile shell bootstraps an available preset into a new draft', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = MobileShellController(
      bridge: _FakeMobileHostBridge(providersList: _providerDescriptors),
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
    );

    await controller.initialize();
    await tester.pumpWidget(MobileShellApp(controller: controller));
    await tester.pumpAndSettle();
    await _openProvidersTab(tester);

    final workflowScrollable = _workflowScrollable();
    final wbPresetButton = find.byKey(
      const ValueKey<String>('preset-use-generic-turn-default'),
    );
    await tester.scrollUntilVisible(
      wbPresetButton,
      240,
      scrollable: workflowScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(wbPresetButton);
    await tester.pumpAndSettle();

    expect(controller.workflowSurface, MobileWorkflowSurface.providerConfig);
    expect(controller.managedProviderDraft.name, 'Generic TURN');
    expect(controller.managedProviderDraft.provider, 'generic-turn');
    expect(controller.selectedManagedProviderId, isNull);
  });

  testWidgets(
    'mobile shell creates edits and deletes managed provider records',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = MobileShellController(
        bridge: _FakeMobileHostBridge(providersList: _providerDescriptors),
        stateStore: _InMemoryStateStore(
          MobileShellState(
            profiles: const <ProfileRecord>[],
            providerConfigs: const <ProviderConfigRecord>[],
            draft: ProfileDraft.defaults(),
          ),
        ),
      );

      await controller.initialize();
      await tester.pumpWidget(MobileShellApp(controller: controller));
      await tester.pumpAndSettle();
      await _openProvidersTab(tester);

      final workflowScrollable = _workflowScrollable();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('managed-provider-create-button')),
        240,
        scrollable: workflowScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('managed-provider-create-button')),
      );
      await tester.pumpAndSettle();

      expect(controller.workflowSurface, MobileWorkflowSurface.providerConfig);
      expect(find.text('App-owned provider catalog'), findsOneWidget);
      expect(find.text('Supported provider families'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('supported-provider-card-vk')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('supported-provider-card-generic-turn'),
        ),
        findsOneWidget,
      );

      final providerWorkspaceScrollable = _managedProviderWorkspaceScrollable();
      await tester.scrollUntilVisible(
        find.text('Managed record name'),
        240,
        scrollable: providerWorkspaceScrollable,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'WB Central');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Save managed record'),
        240,
        scrollable: providerWorkspaceScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save managed record'));
      await tester.pumpAndSettle();

      expect(controller.providerConfigs, hasLength(1));
      expect(controller.providerConfigs.single.name, 'WB Central');

      await tester.scrollUntilVisible(
        find.text('Managed record name'),
        240,
        scrollable: providerWorkspaceScrollable,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'WB Central Updated',
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Save managed record'),
        240,
        scrollable: providerWorkspaceScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save managed record'));
      await tester.pumpAndSettle();

      expect(controller.providerConfigs.single.name, 'WB Central Updated');

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('managed-provider-delete-button')),
        240,
        scrollable: providerWorkspaceScrollable,
      );
      await tester.pumpAndSettle();
      final deleteButton = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey<String>('managed-provider-delete-button')),
      );
      expect(deleteButton.onPressed, isNotNull);
      deleteButton.onPressed!.call();
      await tester.pumpAndSettle();

      expect(controller.providerConfigs, isEmpty);
      expect(controller.workflowSurface, MobileWorkflowSurface.profile);
    },
  );

  testWidgets('mobile shell keeps unavailable managed providers explicit', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = MobileShellController(
      bridge: _FakeMobileHostBridge(
        providersList: <ProviderDescriptor>[_providerDescriptors.first],
      ),
      stateStore: _InMemoryStateStore(
        MobileShellState(
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
    );

    await controller.initialize();
    controller.selectProviderConfig('provider-config-1');
    await tester.pumpWidget(MobileShellApp(controller: controller));
    await tester.pumpAndSettle();
    await _openProvidersTab(tester);

    expect(controller.workflowSurface, MobileWorkflowSurface.providerConfig);
    expect(
      find.textContaining(
        'does not advertise the Generic TURN provider family',
      ),
      findsWidgets,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Apply record to profile draft'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'mobile shell disables provider saves when reusable settings are unsupported',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = MobileShellController(
        bridge: _FakeMobileHostBridge(
          providersList: const <ProviderDescriptor>[
            _supportedProviderWithUnsupportedSettingsDescriptor,
          ],
        ),
        stateStore: _InMemoryStateStore(
          MobileShellState(
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
      );

      await controller.initialize();
      controller.selectProviderConfig('provider-config-1');
      await tester.pumpWidget(MobileShellApp(controller: controller));
      await tester.pumpAndSettle();
      await _openProvidersTab(tester);

      final providerWorkspaceScrollable = _managedProviderWorkspaceScrollable();
      await tester.scrollUntilVisible(
        find.textContaining('cannot render the provider settings schema'),
        240,
        scrollable: providerWorkspaceScrollable,
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('cannot render the provider settings schema'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(
                const ValueKey<String>('managed-provider-save-button'),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(
                const ValueKey<String>('managed-provider-apply-button'),
              ),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'mobile shell applies managed providers as saved-profile snapshots',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final bridge = _FakeMobileHostBridge(
        providersList: const <ProviderDescriptor>[
          _supportedProviderWithSettingsDescriptor,
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
                name: 'vk live',
                spec: _profileSpec(),
              ),
            ),
          ),
        ),
      );

      await controller.initialize();
      controller.selectProviderConfig('provider-config-1');
      await tester.pumpWidget(MobileShellApp(controller: controller));
      await tester.pumpAndSettle();
      await _openProvidersTab(tester);

      final applyButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey<String>('managed-provider-apply-button')),
      );
      expect(applyButton.onPressed, isNotNull);
      applyButton.onPressed!.call();
      await tester.pumpAndSettle();

      expect(controller.workflowSurface, MobileWorkflowSurface.profile);
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
    },
  );

  testWidgets(
    'mobile profile editor toggles between managed and custom provider modes',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = MobileShellController(
        bridge: _FakeMobileHostBridge(
          providersList: const <ProviderDescriptor>[
            _supportedProviderWithSettingsDescriptor,
          ],
        ),
        stateStore: _InMemoryStateStore(
          MobileShellState(
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
      );

      await controller.initialize();
      await tester.pumpWidget(MobileShellApp(controller: controller));
      await tester.pumpAndSettle();
      await _openProfilesTab(tester);
      await _openProfileEditorFromProfiles(tester);

      final profileWorkspaceScrollable = _profileWorkspaceScrollable();
      await tester.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, 'Managed provider'),
        240,
        scrollable: profileWorkspaceScrollable,
      );
      await tester.pumpAndSettle();

      expect(find.text('Provider mode'), findsOneWidget);
      expect(
        find.widgetWithText(ChoiceChip, 'Managed provider'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ChoiceChip, 'Custom provider'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Managed provider'));
      await tester.pumpAndSettle();

      expect(controller.draft.providerBinding.isManaged, isTrue);
      expect(
        controller.draft.providerBinding.managedProviderId,
        'provider-config-1',
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Custom provider'));
      await tester.pumpAndSettle();

      expect(controller.draft.providerBinding.isManaged, isFalse);
    },
  );
}

Future<void> _openProfilesTab(WidgetTester tester) async {
  await tester.tap(find.text('Profiles').first);
  await tester.pumpAndSettle();
}

Future<void> _openProvidersTab(WidgetTester tester) async {
  final inactiveIcon = find.byIcon(Icons.cloud_outlined);
  final activeIcon = find.byIcon(Icons.cloud);
  if (inactiveIcon.evaluate().isNotEmpty) {
    await tester.tap(inactiveIcon.first);
  } else {
    await tester.tap(activeIcon.first);
  }
  await tester.pumpAndSettle();
}

Future<void> _openProfileEditorFromProfiles(
  WidgetTester tester, {
  String label = 'Add profile',
}) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _openProfilesMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Profiles actions'));
  await tester.pumpAndSettle();
}

Future<void> _openSupportTab(WidgetTester tester) async {
  await tester.tap(find.text('Support').first);
  await tester.pumpAndSettle();
  final activityChip = find.widgetWithText(ChoiceChip, 'Activity');
  if (activityChip.evaluate().isNotEmpty) {
    await tester.tap(activityChip.first);
    await tester.pumpAndSettle();
  }
}

Future<void> _openSupportDiagnostics(WidgetTester tester) async {
  await _openSupportTab(tester);
  final diagnosticsChip = find.widgetWithText(ChoiceChip, 'Diagnostics');
  if (diagnosticsChip.evaluate().isNotEmpty) {
    await tester.tap(diagnosticsChip.first);
    await tester.pumpAndSettle();
  }
}

Finder _workflowScrollable() => find.byType(Scrollable).first;

Finder _managedProviderWorkspaceScrollable() {
  return find
      .descendant(
        of: find.byKey(
          const ValueKey<String>('managed-provider-workspace-scroll'),
        ),
        matching: find.byType(Scrollable),
      )
      .first;
}

Finder _profileWorkspaceScrollable() {
  return _workflowScrollable();
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
      executionPlans: <RuntimeExecutionPlanDescriptor>[
        _androidVpnExecutionPlanDescriptor,
      ],
      missingPrerequisite: PlatformTunnelPrerequisite.hostImplementation,
      message: 'embedded mobile host does not implement tunnel startup yet',
    ),
  ],
);

const HostInfo _nonRoutingReadyHostInfo = HostInfo(
  contractVersion: '1',
  build: BuildIdentity(
    product: 'vk-turn-proxy-go',
    version: '0.1.0',
    buildNumber: '1',
    revision: 'mobilehost1234',
    role: 'mobile_host',
    target: 'ios/debug',
  ),
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
      mode: PlatformTunnelMode.appleNetworkExtension,
      available: true,
      satisfiedPrerequisites: <PlatformTunnelPrerequisite>[
        PlatformTunnelPrerequisite.entitlement,
      ],
      executionPlans: <RuntimeExecutionPlanDescriptor>[
        _appleNetworkExtensionExecutionPlanDescriptor,
      ],
      message: 'apple network extension mode is available on this host',
    ),
    PlatformTunnelCapability(
      mode: PlatformTunnelMode.androidVpnService,
      available: false,
      executionPlans: <RuntimeExecutionPlanDescriptor>[
        _androidVpnExecutionPlanDescriptor,
      ],
      missingPrerequisite: PlatformTunnelPrerequisite.hostImplementation,
      message: 'android vpn service is unavailable on this host target',
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

class _FakeOwnedBrowserChallengeRunner implements OwnedBrowserChallengeRunner {
  _FakeOwnedBrowserChallengeRunner({this.result, this.error});

  final ChallengeContinuationSubmission? result;
  final Object? error;
  final List<String> challengeIds = <String>[];

  @override
  Future<ChallengeContinuationSubmission?> run(
    BuildContext context,
    ChallengeRecord challenge,
  ) async {
    challengeIds.add(challenge.id);
    if (error != null) {
      throw error!;
    }
    return result;
  }
}

class _FakeMobileSoftKeyboardHider implements MobileSoftKeyboardHider {
  _FakeMobileSoftKeyboardHider({required this.onHide});

  final VoidCallback onHide;

  @override
  Future<bool> hide() async {
    onHide();
    return true;
  }
}

class _FakeMobileWindowSoftInputModeController
    implements MobileWindowSoftInputModeController {
  _FakeMobileWindowSoftInputModeController({
    required this.onEnableOwnedBrowserMode,
    required this.onRestoreDefaultMode,
  });

  final VoidCallback onEnableOwnedBrowserMode;
  final VoidCallback onRestoreDefaultMode;

  @override
  Future<bool> enableOwnedBrowserMode() async {
    onEnableOwnedBrowserMode();
    return true;
  }

  @override
  Future<bool> restoreDefaultMode() async {
    onRestoreDefaultMode();
    return true;
  }
}

class _FakeMobileHostBridge implements MobileHostBridge {
  _FakeMobileHostBridge({
    List<ProviderDescriptor>? providersList,
    List<ProviderConfigRecord>? providerConfigsList,
    List<ResolutionRecord>? resolutionsList,
    this.sessionsList = const <SessionRecord>[],
    this.challengeMap = const <String, ChallengeRecord>{},
    MobileHostConnectionResult? readyResult,
    Stream<EventRecord>? eventStream,
    HostInfo? hostInfo,
    this.startPlatformTunnelResult = const PlatformTunnelStartResult(
      mode: PlatformTunnelMode.androidVpnService,
      ready: false,
      stage: PlatformTunnelStartupStage.capabilityCheck,
      missingPrerequisite: PlatformTunnelPrerequisite.hostImplementation,
      message: 'embedded mobile host does not implement tunnel startup yet',
    ),
  }) : _providers = List<ProviderDescriptor>.of(
         providersList ?? _providerDescriptors,
       ),
       ensureReadyResult =
           readyResult ??
           const MobileHostConnectionResult(
             state: MobileHostLifecycleState.ready,
             message: 'Connected to embedded mobile host bridge',
             info: _readyHostInfo,
             description: 'fake-test-bridge',
           ),
       _eventStream = eventStream ?? const Stream<EventRecord>.empty(),
       _hostInfo = hostInfo ?? readyResult?.info ?? _readyHostInfo,
       _providerConfigs = List<ProviderConfigRecord>.of(
         providerConfigsList ?? const <ProviderConfigRecord>[],
       ),
       _resolutions = List<ResolutionRecord>.of(
         resolutionsList ?? const <ResolutionRecord>[],
       );

  final List<ProviderDescriptor> _providers;
  final List<ProviderConfigRecord> _providerConfigs;
  final MobileHostConnectionResult ensureReadyResult;
  final List<SessionRecord> sessionsList;
  final Map<String, ChallengeRecord> challengeMap;
  final Stream<EventRecord> _eventStream;
  final HostInfo _hostInfo;
  final List<ResolutionRecord> _resolutions;
  final PlatformTunnelStartResult startPlatformTunnelResult;
  final List<PlatformTunnelMode> startedPlatformTunnels =
      <PlatformTunnelMode>[];
  final List<String?> startedPlatformTunnelResolutionIDs = <String?>[];
  final List<PlatformTunnelMode> stoppedPlatformTunnels =
      <PlatformTunnelMode>[];
  final List<String> cancelChallengeCalls = <String>[];
  final List<String> continueChallengeCalls = <String>[];
  final List<ChallengeContinuationSubmission?> continueChallengePayloads =
      <ChallengeContinuationSubmission?>[];
  final List<_StartResolutionCall> startResolutionCalls =
      <_StartResolutionCall>[];

  @override
  Stream<MobileBrowserReturnSignal> get browserReturnSignals =>
      const Stream<MobileBrowserReturnSignal>.empty();

  @override
  Future<ChallengeRecord> cancelChallenge(String challengeId) async {
    cancelChallengeCalls.add(challengeId);
    final challenge = challengeMap[challengeId]!;
    final cancelled = challenge.copyWith(
      status: ChallengeStatus.cancelled,
      updatedAt: challenge.updatedAt.add(const Duration(seconds: 1)),
    );
    challengeMap[challengeId] = cancelled;
    _resolveChallengeOutcome(cancelled);
    return cancelled;
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
    final challenge = challengeMap[challengeId]!;
    final continued = challenge.status == ChallengeStatus.pending
        ? challenge.copyWith(
            status: ChallengeStatus.completed,
            updatedAt: challenge.updatedAt.add(const Duration(seconds: 1)),
          )
        : challenge;
    challengeMap[challengeId] = continued;
    _resolveChallengeOutcome(continued);
    return continued;
  }

  @override
  Future<ResolutionRecord> cancelResolution(String resolutionId) async {
    throw UnimplementedError();
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
    return DiagnosticsBundle(
      session: sessionsList.first,
      events: const <EventRecord>[],
      challenges: challengeMap.values.toList(growable: false),
      metrics: '',
      hostBuild: _hostInfo.build,
      contractVersion: _hostInfo.contractVersion,
    );
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<MobileHostConnectionResult> ensureReady() async => ensureReadyResult;

  @override
  Stream<EventRecord> events() => _eventStream;

  @override
  Future<HostInfo> hostInfo() async => _hostInfo;

  @override
  Future<HostInfo> negotiate({
    required List<String> supportedVersions,
    required List<Capability> requiredCapabilities,
  }) async => _hostInfo;

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
    PlatformTunnelApplicationRoutingPolicy applicationRoutingPolicy =
        PlatformTunnelApplicationRoutingPolicy.allApps,
    List<String> allowedPackages = const <String>[],
    List<String> disallowedPackages = const <String>[],
  }) async {
    startedPlatformTunnels.add(mode);
    startedPlatformTunnelResolutionIDs.add(resolutionId);
    return startPlatformTunnelResult;
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
      message: 'embedded mobile host does not implement tunnel resume yet',
    );
  }

  @override
  Future<PlatformTunnelStopResult> stopPlatformTunnel({
    required PlatformTunnelMode mode,
  }) async {
    stoppedPlatformTunnels.add(mode);
    return const PlatformTunnelStopResult(
      mode: PlatformTunnelMode.androidVpnService,
      stopped: true,
      message: 'Android VPN Service disconnected.',
    );
  }

  @override
  Future<bool> requestPlatformTunnelPermission({
    required PlatformTunnelMode mode,
  }) async {
    return true;
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
  Future<SessionRecord> materializeResolution({
    required String resolutionId,
    required RuntimeDefaults runtimeDefaults,
    RuntimeExecutionPlan? executionPlan,
  }) async {
    return sessionsList.first;
  }

  @override
  Future<ProfileRecord> upsertProfile(ProfileRecord profile) async => profile;

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

  bool _providerAdvertised(String providerId) {
    final normalized = providerId.trim().toLowerCase();
    return _providers.any(
      (ProviderDescriptor descriptor) =>
          descriptor.id.trim().toLowerCase() == normalized,
    );
  }

  void _resolveChallengeOutcome(ChallengeRecord challenge) {
    for (var index = 0; index < sessionsList.length; index += 1) {
      final session = sessionsList[index];
      if (session.activeChallengeId != challenge.id) {
        continue;
      }
      sessionsList[index] = SessionRecord(
        id: session.id,
        profileId: session.profileId,
        profileName: session.profileName,
        sourceResolutionId:
            session.sourceResolutionId ?? challenge.resolutionId,
        profile: session.profile,
        state: switch (challenge.status) {
          ChallengeStatus.completed => SessionState.ready,
          ChallengeStatus.cancelled => SessionState.stopped,
          ChallengeStatus.failed => SessionState.failed,
          ChallengeStatus.pending ||
          ChallengeStatus.continuing => session.state,
        },
        failure: session.failure,
        startedAt: session.startedAt,
        updatedAt: challenge.updatedAt,
        stoppedAt: challenge.status == ChallengeStatus.cancelled
            ? challenge.updatedAt
            : session.stoppedAt,
      );
    }

    final resolutionId = challenge.resolutionId?.trim() ?? '';
    if (resolutionId.isEmpty) {
      return;
    }
    for (var index = 0; index < _resolutions.length; index += 1) {
      final resolution = _resolutions[index];
      if (resolution.id != resolutionId &&
          resolution.activeChallengeId != challenge.id) {
        continue;
      }
      _resolutions[index] = ResolutionRecord(
        id: resolution.id,
        provider: resolution.provider,
        resolutionMethod: resolution.resolutionMethod,
        input: resolution.input,
        state: switch (challenge.status) {
          ChallengeStatus.completed => ResolutionState.resolved,
          ChallengeStatus.cancelled => ResolutionState.cancelled,
          ChallengeStatus.failed => ResolutionState.failed,
          ChallengeStatus.pending ||
          ChallengeStatus.continuing => resolution.state,
        },
        artifact: resolution.artifact,
        credentials: resolution.credentials,
        export: resolution.export,
        failure: resolution.failure,
        startedAt: resolution.startedAt,
        updatedAt: challenge.updatedAt,
        resolvedAt: challenge.status == ChallengeStatus.completed
            ? (resolution.resolvedAt ?? challenge.updatedAt)
            : resolution.resolvedAt,
        expiredAt: resolution.expiredAt,
      );
    }
  }
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

class _FakeMobilePlatformAppInventory implements MobilePlatformAppInventory {
  const _FakeMobilePlatformAppInventory({required this.apps});

  final List<MobilePlatformApp> apps;

  @override
  Future<List<MobilePlatformApp>> listInstalledApps() async {
    return apps;
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
  @override
  Future<void> copyLink(String link) async {}

  @override
  Future<void> shareLink(String link) async {}
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
