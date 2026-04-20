import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/mobile_host_bridge.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_controller.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_state_store.dart';

import 'test_i18n.dart';

const BuildIdentity _testHostBuild = BuildIdentity(
  product: 'RelayDock',
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
      message: 'embedded mobile host does not implement tunnel startup yet',
    ),
  ],
);

class _ReadyMobileHostBridge extends UnavailableMobileHostBridge {
  _ReadyMobileHostBridge();

  @override
  Future<MobileHostConnectionResult> ensureReady() async {
    return const MobileHostConnectionResult(
      state: MobileHostLifecycleState.ready,
      message: 'Connected to embedded mobile host bridge',
      info: _readyHostInfo,
      description: 'locale-test-bridge',
    );
  }

  @override
  Stream<EventRecord> events() => const Stream<EventRecord>.empty();

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
      ];

  @override
  Future<List<ProfileRecord>> profiles() async => const <ProfileRecord>[];

  @override
  Future<List<ResolutionRecord>> resolutions() async =>
      const <ResolutionRecord>[];

  @override
  Future<List<SessionRecord>> sessions() async => const <SessionRecord>[];
}

class _LocalizedReadyMobileHostBridge extends UnavailableMobileHostBridge {
  final StreamController<EventRecord> _events =
      StreamController<EventRecord>.broadcast();

  int ensureReadyCalls = 0;

  @override
  Future<MobileHostConnectionResult> ensureReady() async {
    ensureReadyCalls += 1;
    return MobileHostConnectionResult(
      state: MobileHostLifecycleState.ready,
      message: currentShellText.connectedToMobileHostBridge(
        'http://127.0.0.1:7777',
      ),
      info: _readyHostInfo,
      description: 'locale-test-bridge',
    );
  }

  @override
  Stream<EventRecord> events() => _events.stream;

  @override
  Future<void> dispose() async {
    await _events.close();
  }

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
      ];

  @override
  Future<List<ProfileRecord>> profiles() async => const <ProfileRecord>[];

  @override
  Future<List<ResolutionRecord>> resolutions() async =>
      const <ResolutionRecord>[];

  @override
  Future<List<SessionRecord>> sessions() async => const <SessionRecord>[];
}

class _InMemoryMobileShellStateStore implements MobileShellStateStore {
  _InMemoryMobileShellStateStore([this._state]);

  MobileShellState? _state;

  @override
  Future<void> clear() async {
    _state = null;
  }

  @override
  Future<MobileShellState?> load() async => _state;

  @override
  Future<void> save(
    MobileShellState state, {
    Iterable<ProviderDescriptor> providerDescriptors =
        const <ProviderDescriptor>[],
  }) async {
    _state = state;
  }
}

void main() {
  test(
    'mobile controller reconnects on locale switch and relocalizes host status',
    () async {
      await AppLocale.en.build();
      await AppLocale.ru.build();
      LocaleSettings.setLocaleSync(AppLocale.ru);
      addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.en));

      final bridge = _LocalizedReadyMobileHostBridge();
      final controller = MobileShellController(
        bridge: bridge,
        stateStore: _InMemoryMobileShellStateStore(MobileShellState.empty()),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      expect(
        controller.hostStatusMessage,
        'Подключено к мосту мобильного хоста http://127.0.0.1:7777',
      );

      await controller.selectLocaleOverride('en');

      expect(bridge.ensureReadyCalls, 1);
      expect(
        controller.hostStatusMessage,
        'Connected to mobile host bridge http://127.0.0.1:7777',
      );
    },
  );

  testWidgets('mobile shell chrome switches to Russian locale labels', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = MobileShellController(
      bridge: _ReadyMobileHostBridge(),
      stateStore: _InMemoryMobileShellStateStore(MobileShellState.empty()),
    );

    await controller.initialize();
    await pumpMobileShellTestApp(
      tester,
      controller: controller,
      locale: AppLocale.ru,
    );

    expect(find.text('Главная'), findsWidgets);
    expect(find.text('Профили'), findsWidgets);
    expect(find.byTooltip('Сменить язык'), findsWidgets);
  });
}
