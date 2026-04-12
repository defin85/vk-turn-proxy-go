import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_gui_shell/src/app.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/mobile_handoff_adapter.dart';
import 'package:mobile_gui_shell/src/control/mobile_host_bridge.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_controller.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_state_store.dart';
import 'package:mobile_gui_shell/src/control/profile_draft.dart';

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

    expect(find.text('Workflow ready'), findsOneWidget);
    expect(find.text('Open activity'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'vk mobile draft');
    await tester.pump();

    await tester.tap(find.text('Diagnostics'));
    await tester.pumpAndSettle();

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

    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sessions (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Open browser', skipOffstage: false), findsOneWidget);
    expect(find.text("I've completed it", skipOffstage: false), findsOneWidget);
    expect(find.text('vk live'), findsWidgets);

    await tester.tap(find.text('Workflow'));
    await tester.pumpAndSettle();
    expect(find.text('vk mobile draft'), findsOneWidget);
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

    expect(find.text('Workflow blocked by host state'), findsOneWidget);
    expect(find.text('Reset local state'), findsOneWidget);
    expect(
      find.textContaining('Secure profile secrets are unavailable'),
      findsWidgets,
    );

    await tester.tap(find.text('Diagnostics'));
    await tester.pumpAndSettle();
    expect(find.text('Mobile host blocked'), findsOneWidget);
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

      expect(find.text('Workflow blocked by host mismatch'), findsOneWidget);
      expect(find.textContaining('contract mismatch'), findsWidgets);

      await tester.tap(find.text('Diagnostics'));
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
    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
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
    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();

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
    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();

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

    await tester.tap(find.text('Diagnostics'));
    await tester.pumpAndSettle();
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
        providersList: <ProviderDescriptor>[
          ..._providerDescriptors,
          _providerWithSettingsDescriptor,
        ],
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

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('preset-card-smarthome-default')),
      240,
      scrollable: _workflowScrollable(),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'does not advertise the RTK Smarthome provider family yet',
      ),
      findsOneWidget,
    );
  });

  testWidgets('mobile shell bootstraps an available preset into a new draft', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = MobileShellController(
      bridge: _FakeMobileHostBridge(
        providersList: <ProviderDescriptor>[
          ..._providerDescriptors,
          _providerWithSettingsDescriptor,
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

    final workflowScrollable = _workflowScrollable();
    final wbPresetButton = find.byKey(
      const ValueKey<String>('preset-use-wb-stream-default'),
    );
    await tester.scrollUntilVisible(
      wbPresetButton,
      240,
      scrollable: workflowScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(wbPresetButton);
    await tester.pumpAndSettle();

    expect(controller.selectedProfileId, isNull);
    expect(controller.workflowSurface, MobileWorkflowSurface.profile);
    expect(controller.draft.name, 'WB Stream');
    expect(controller.draft.spec.provider, 'wb-stream');
  });

  testWidgets('mobile shell creates edits and deletes provider configs', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = MobileShellController(
      bridge: _FakeMobileHostBridge(
        providersList: <ProviderDescriptor>[
          ..._providerDescriptors,
          _providerWithSettingsDescriptor,
        ],
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

    final workflowScrollable = _workflowScrollable();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('provider-config-create-button')),
      240,
      scrollable: workflowScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('provider-config-create-button')),
    );
    await tester.pumpAndSettle();

    expect(controller.workflowSurface, MobileWorkflowSurface.providerConfig);
    expect(find.text('Save config'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'WB Central');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save config'));
    await tester.pumpAndSettle();

    expect(controller.providerConfigs, hasLength(1));
    expect(controller.providerConfigs.single.name, 'WB Central');

    await tester.enterText(find.byType(TextField).first, 'WB Central Updated');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save config'));
    await tester.pumpAndSettle();

    expect(controller.providerConfigs.single.name, 'WB Central Updated');

    final deleteButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey<String>('provider-config-delete-button')),
    );
    expect(deleteButton.onPressed, isNotNull);
    deleteButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(controller.providerConfigs, isEmpty);
    expect(controller.workflowSurface, MobileWorkflowSurface.profile);
  });

  testWidgets('mobile shell blocks unavailable provider configs explicitly', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = MobileShellController(
      bridge: _FakeMobileHostBridge(
        providerConfigsList: <ProviderConfigRecord>[
          _providerConfigRecord(
            id: 'provider-config-1',
            provider: 'wb-stream',
            name: 'WB Central',
            providerSettings: const <String, dynamic>{'region': 'eu-west'},
            availability: const ProviderConfigAvailability(
              state: ProviderConfigAvailabilityState.providerUnavailable,
              message:
                  'The connected mobile host no longer advertises WB Stream provider settings.',
            ),
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
    );

    await controller.initialize();
    controller.selectProviderConfig('provider-config-1');
    await tester.pumpWidget(MobileShellApp(controller: controller));
    await tester.pumpAndSettle();

    expect(controller.workflowSurface, MobileWorkflowSurface.providerConfig);
    expect(find.textContaining('no longer advertises WB Stream'), findsWidgets);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Apply to profile draft'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'mobile shell applies provider configs as saved-profile snapshots',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final bridge = _FakeMobileHostBridge(
        providersList: <ProviderDescriptor>[
          ..._providerDescriptors,
          _providerWithSettingsDescriptor,
        ],
        providerConfigsList: <ProviderConfigRecord>[
          _providerConfigRecord(
            id: 'provider-config-1',
            provider: 'wb-stream',
            name: 'WB Central',
            providerSettings: const <String, dynamic>{'region': 'eu-west'},
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
      );

      await controller.initialize();
      controller.selectProviderConfig('provider-config-1');
      await tester.pumpWidget(MobileShellApp(controller: controller));
      await tester.pumpAndSettle();

      final applyButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey<String>('provider-config-apply-button')),
      );
      expect(applyButton.onPressed, isNotNull);
      applyButton.onPressed!.call();
      await tester.pumpAndSettle();

      expect(controller.workflowSurface, MobileWorkflowSurface.profile);
      expect(controller.draft.spec.provider, 'wb-stream');
      expect(controller.draft.spec.providerSettings['region'], 'eu-west');

      await controller.saveDraft();
      await tester.pumpAndSettle();

      final savedProfile = controller.profiles.firstWhere(
        (ProfileRecord profile) => profile.id == 'profile-1',
      );
      expect(savedProfile.spec.providerSettings['region'], 'eu-west');

      await bridge.upsertProviderConfig(
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
    },
  );
}

Finder _workflowScrollable() => find.byType(Scrollable).first;

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
    List<ProviderDescriptor>? providersList,
    List<ProviderConfigRecord>? providerConfigsList,
    List<ResolutionRecord>? resolutionsList,
    this.sessionsList = const <SessionRecord>[],
    this.challengeMap = const <String, ChallengeRecord>{},
    MobileHostConnectionResult? readyResult,
    Stream<EventRecord>? eventStream,
    HostInfo? hostInfo,
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
  }) async {
    return sessionsList.first;
  }

  @override
  Future<ProfileRecord> upsertProfile(ProfileRecord profile) async => profile;

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
