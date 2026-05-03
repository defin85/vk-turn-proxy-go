import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_gui_shell/src/control/control_plane_client.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/mobile_host_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(
    'com.defin85.vk_turn_proxy_go/mobile_host_bridge',
  );

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('http mobile host bridge forwards browser-return signals', () async {
    final signalController =
        StreamController<MobileBrowserReturnSignal>.broadcast();
    addTearDown(signalController.close);

    final bridge = HttpMobileHostBridge(
      baseUri: Uri.parse('http://127.0.0.1:7777'),
      client: _ReadyControlPlaneApi(),
      browserReturnSignalSource: _FakeBrowserReturnSignalSource(
        signalController.stream,
      ),
    );

    final observed = <MobileBrowserReturnSignal>[];
    final subscription = bridge.browserReturnSignals.listen(observed.add);
    addTearDown(subscription.cancel);

    signalController.add(
      const MobileBrowserReturnSignal(
        kind: BrowserReturnSignalKind.appLink,
        uri: 'https://app.example.test/mobile-return?code=1',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(observed, hasLength(1));
    expect(observed.single.kind, BrowserReturnSignalKind.appLink);
    expect(
      observed.single.uri,
      'https://app.example.test/mobile-return?code=1',
    );
  });

  test('platform host resolver reads native host configuration', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          expect(call.method, 'resolveHost');
          return <String, dynamic>{
            'base_url': 'http://127.0.0.1:9777',
            'description': 'android manifest mobile host url',
          };
        });

    final resolver = PlatformMobileHostConfigResolver(methodChannel: channel);
    final resolved = await resolver.resolve();

    expect(resolved, isNotNull);
    expect(resolved!.baseUri.toString(), 'http://127.0.0.1:9777');
    expect(resolved.description, 'android manifest mobile host url');
  });

  test(
    'mobile host bridge factory uses the native-resolved host path',
    () async {
      Uri? createdUri;
      final api = _ReadyControlPlaneApi();
      final bridge = await MobileHostBridgeFactory.fromEnvironment(
        configuredBaseUrl: '',
        resolver: _FakeResolver(
          ResolvedMobileHostConfig(
            baseUri: Uri.parse('http://127.0.0.1:7777'),
            description: 'ios loopback default',
          ),
        ),
        clientFactory: (Uri uri) {
          createdUri = uri;
          return api;
        },
      );

      expect(bridge, isA<HttpMobileHostBridge>());
      expect(createdUri.toString(), 'http://127.0.0.1:7777');

      final result = await bridge.ensureReady();
      expect(result.state, MobileHostLifecycleState.ready);
      expect(result.description, 'ios loopback default');
      expect(result.info?.capabilities, contains(Capability.mobileHostBridge));
      expect(result.info?.capabilities, contains(Capability.platformTunnels));
      expect(
        result.info?.platformTunnels.single.mode,
        PlatformTunnelMode.appleNetworkExtension,
      );
      expect(api.negotiateCalls, hasLength(1));
      expect(api.negotiateCalls.single, contains(Capability.platformTunnels));
      expect(
        api.negotiateCalls.single,
        contains(Capability.providerRuntimeArtifacts),
      );
      expect(
        api.negotiateCalls.single,
        contains(Capability.providerTransportCompatibility),
      );
      expect(
        api.negotiateCalls.single,
        contains(Capability.runtimeExecutionPlanning),
      );
      expect(
        api.negotiateCalls.single,
        contains(Capability.vpnTransportProfileStore),
      );
    },
  );

  test('http mobile host bridge localizes ready message in Russian', () async {
    await AppLocale.ru.build();
    LocaleSettings.setLocaleSync(AppLocale.ru);
    addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.en));

    final bridge = HttpMobileHostBridge(
      baseUri: Uri.parse('http://127.0.0.1:7777'),
      client: _ReadyControlPlaneApi(),
    );

    final result = await bridge.ensureReady();

    expect(
      result.message,
      'Подключено к мосту мобильного хоста http://127.0.0.1:7777',
    );
  });

  test(
    'mobile host bridge factory fails closed when the native bridge returns no configuration',
    () async {
      final bridge = await MobileHostBridgeFactory.fromEnvironment(
        configuredBaseUrl: '',
        resolver: const _FakeResolver(null),
      );

      expect(bridge, isA<UnavailableMobileHostBridge>());

      final result = await bridge.ensureReady();
      expect(result.state, MobileHostLifecycleState.unavailable);
      expect(
        result.message,
        'Native mobile host bridge did not provide a control-plane endpoint.',
      );
      expect(result.description, 'native mobile host bridge');
    },
  );

  test(
    'mobile host bridge factory surfaces native resolver failures as unavailable',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            throw PlatformException(
              code: 'native_bridge_failure',
              message: 'resolver unavailable',
            );
          });

      final bridge = await MobileHostBridgeFactory.fromEnvironment(
        configuredBaseUrl: '',
        resolver: PlatformMobileHostConfigResolver(methodChannel: channel),
      );

      expect(bridge, isA<UnavailableMobileHostBridge>());

      final result = await bridge.ensureReady();
      expect(result.state, MobileHostLifecycleState.unavailable);
      expect(result.message, contains('resolver unavailable'));
      expect(result.description, 'native mobile host bridge');
    },
  );

  test(
    'mobile host bridge factory fails closed when the native bridge plugin is missing',
    () async {
      final bridge = await MobileHostBridgeFactory.fromEnvironment(
        configuredBaseUrl: '',
        resolver: PlatformMobileHostConfigResolver(methodChannel: channel),
      );

      expect(bridge, isA<UnavailableMobileHostBridge>());

      final result = await bridge.ensureReady();
      expect(result.state, MobileHostLifecycleState.unavailable);
      expect(result.message, contains('plugin is unavailable'));
      expect(result.description, 'native mobile host bridge');
    },
  );

  test('platform soft keyboard hider invokes the native bridge', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          expect(call.method, 'hideSoftKeyboard');
          return null;
        });

    final hider = PlatformMobileSoftKeyboardHider(methodChannel: channel);

    expect(await hider.hide(), isTrue);
  });

  test(
    'platform owned-browser soft input mode controller invokes the native bridge',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            calls.add(call);
            return null;
          });

      final controller = PlatformMobileWindowSoftInputModeController(
        methodChannel: channel,
      );

      expect(await controller.enableOwnedBrowserMode(), isTrue);
      expect(await controller.restoreDefaultMode(), isTrue);
      expect(calls, hasLength(2));
      expect(calls.first.method, 'setSoftInputMode');
      expect(calls.first.arguments, <String, dynamic>{'mode': 'adjustNothing'});
      expect(calls.last.method, 'setSoftInputMode');
      expect(calls.last.arguments, <String, dynamic>{'mode': 'adjustResize'});
    },
  );

  test('platform webview debug inspector invokes the native bridge', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          expect(call.method, 'debugInspectWebView');
          expect(call.arguments, <String, dynamic>{'webViewIdentifier': 42});
          return <String, Object?>{
            'web_view_identifier': 42,
            'ime_visible': true,
            'last_no_extract_ui_flag': true,
          };
        });

    final inspector = PlatformMobileWebViewDebugInspector(
      methodChannel: channel,
    );

    expect(await inspector.snapshot(webViewIdentifier: 42), <String, Object?>{
      'web_view_identifier': 42,
      'ime_visible': true,
      'last_no_extract_ui_flag': true,
    });
  });

  test(
    'platform webview document-start script installer invokes the native bridge',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            expect(call.method, 'installDocumentStartJavaScript');
            expect(call.arguments, <String, Object?>{
              'webViewIdentifier': 42,
              'javaScript': 'window.test = true;',
              'allowedOriginRules': <String>[
                'https://vk.com',
                'https://*.vk.com',
              ],
            });
            return null;
          });

      final installer = PlatformMobileWebViewDocumentStartScriptInstaller(
        methodChannel: channel,
      );

      expect(
        await installer.install(
          webViewIdentifier: 42,
          javaScript: 'window.test = true;',
          allowedOriginRules: const <String>[
            'https://vk.com',
            'https://*.vk.com',
          ],
        ),
        isTrue,
      );
    },
  );

  test(
    'platform webview user-agent metadata controller invokes the native bridge',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            expect(call.method, 'setWebViewUserAgentMetadata');
            expect(call.arguments, <String, Object?>{
              'webViewIdentifier': 42,
              'userAgent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.7680.178 Safari/537.36',
            });
            return null;
          });

      final controller = PlatformMobileWebViewUserAgentMetadataController(
        methodChannel: channel,
      );

      expect(
        await controller.sync(
          webViewIdentifier: 42,
          userAgent:
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.7680.178 Safari/537.36',
        ),
        isTrue,
      );
    },
  );

  test(
    'platform owned-browser session resetter invokes the native bridge',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            expect(call.method, 'clearOwnedBrowserSessionState');
            return null;
          });

      final resetter = PlatformMobileOwnedBrowserSessionStateResetter(
        methodChannel: channel,
      );

      await resetter.clearSessionState();
    },
  );

  test('platform host resolver rejects invalid native host URLs', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          return <String, dynamic>{
            'base_url': 'not a url',
            'description': 'broken native host',
          };
        });

    final resolver = PlatformMobileHostConfigResolver(methodChannel: channel);

    await expectLater(
      resolver.resolve(),
      throwsA(
        isA<MobileHostConfigResolutionError>().having(
          (MobileHostConfigResolutionError error) => error.message,
          'message',
          contains('invalid host URL'),
        ),
      ),
    );
  });

  test(
    'mobile host bridge forwards typed platform tunnel startup results',
    () async {
      final api = _ReadyControlPlaneApi();
      final bridge = await MobileHostBridgeFactory.fromEnvironment(
        configuredBaseUrl: 'http://127.0.0.1:7777',
        clientFactory: (_) => api,
      );

      final result = await bridge.startPlatformTunnel(
        mode: PlatformTunnelMode.appleNetworkExtension,
        resolutionId: 'resolution-bridge-1',
        runtimeDefaults: const RuntimeDefaults(
          listenAddress: '127.0.0.1:7777',
          peerAddress: 'peer.example.test:443',
          turnServer: 'turn.example.test',
          turnPort: '3478',
        ),
        underlayRoutePolicy:
            PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork,
      );

      expect(result.ready, isFalse);
      expect(result.stage, PlatformTunnelStartupStage.capabilityCheck);
      expect(
        result.missingPrerequisite,
        PlatformTunnelPrerequisite.hostImplementation,
      );
      expect(api.startPlatformTunnelResolutionIDs, <String?>[
        'resolution-bridge-1',
      ]);
      expect(api.startPlatformTunnelRuntimeDefaults, hasLength(1));
      expect(
        api.startPlatformTunnelRuntimeDefaults.single?.turnServer,
        'turn.example.test',
      );
      expect(
        api.startPlatformTunnelUnderlayRoutePolicies,
        <PlatformTunnelUnderlayRoutePolicy>[
          PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork,
        ],
      );
    },
  );

  test(
    'mobile host bridge forwards typed platform tunnel stop results',
    () async {
      final api = _ReadyControlPlaneApi();
      final bridge = await MobileHostBridgeFactory.fromEnvironment(
        configuredBaseUrl: 'http://127.0.0.1:7777',
        clientFactory: (_) => api,
      );

      final result = await bridge.stopPlatformTunnel(
        mode: PlatformTunnelMode.appleNetworkExtension,
      );

      expect(result.stopped, isTrue);
      expect(api.stopPlatformTunnelModes, <PlatformTunnelMode>[
        PlatformTunnelMode.appleNetworkExtension,
      ]);
    },
  );

  test(
    'mobile host bridge requests native platform tunnel permission',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            expect(call.method, 'requestPlatformTunnelPermission');
            expect(call.arguments, <String, dynamic>{
              'mode': 'android_vpn_service',
            });
            return true;
          });

      final bridge = HttpMobileHostBridge(
        baseUri: Uri.parse('http://127.0.0.1:7777'),
        client: _ReadyControlPlaneApi(),
      );

      final granted = await bridge.requestPlatformTunnelPermission(
        mode: PlatformTunnelMode.androidVpnService,
      );

      expect(granted, isTrue);
    },
  );

  test(
    'mobile host bridge returns false when native platform tunnel permission is denied',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            expect(call.method, 'requestPlatformTunnelPermission');
            return false;
          });

      final bridge = HttpMobileHostBridge(
        baseUri: Uri.parse('http://127.0.0.1:7777'),
        client: _ReadyControlPlaneApi(),
      );

      final granted = await bridge.requestPlatformTunnelPermission(
        mode: PlatformTunnelMode.androidVpnService,
      );

      expect(granted, isFalse);
    },
  );

  test(
    'mobile host bridge surfaces native platform tunnel permission cancellation',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            expect(call.method, 'requestPlatformTunnelPermission');
            throw PlatformException(
              code: 'platform_tunnel_permission_cancelled',
              message:
                  'The Android VPN permission request was cancelled before completion.',
            );
          });

      final bridge = HttpMobileHostBridge(
        baseUri: Uri.parse('http://127.0.0.1:7777'),
        client: _ReadyControlPlaneApi(),
      );

      await expectLater(
        bridge.requestPlatformTunnelPermission(
          mode: PlatformTunnelMode.androidVpnService,
        ),
        throwsA(
          isA<MobileHostPlatformActionError>().having(
            (MobileHostPlatformActionError error) => error.message,
            'message',
            contains('cancelled'),
          ),
        ),
      );
    },
  );

  test(
    'mobile control plane client fails closed on invalid platform modes',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((HttpRequest request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{
            'contract_version': '1',
            'build': <String, dynamic>{
              'product': 'RelayDock',
              'version': '0.1.0',
              'build_number': '1',
            },
            'capabilities': <String>[
              'mobile_host_bridge',
              'platform_tunnels',
              'profiles',
              'provider-runtime-artifacts',
              'runtime-execution-planning',
              'sessions',
              'challenges',
              'diagnostics',
              'event_stream',
            ],
            'platform_tunnels': <Map<String, dynamic>>[
              <String, dynamic>{
                'mode': 'future_platform_mode',
                'available': false,
                'missing_prerequisite': 'host_implementation',
              },
            ],
          }),
        );
        await request.response.close();
      });

      final realHttpOverrides = _RealHttpOverrides();
      final client = ControlPlaneClient(
        baseUri: Uri.parse('http://${server.address.address}:${server.port}'),
        httpClientFactory: () => realHttpOverrides.createHttpClient(null),
      );

      await expectLater(
        client.negotiate(
          supportedVersions: const <String>['1'],
          requiredCapabilities: const <Capability>[
            Capability.mobileHostBridge,
            Capability.platformTunnels,
          ],
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test(
    'mobile control plane client fails closed on invalid startup result payloads',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((HttpRequest request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{
            'mode': 'apple_network_extension',
            'ready': false,
            'message': 'missing startup stage',
          }),
        );
        await request.response.close();
      });

      final realHttpOverrides = _RealHttpOverrides();
      final client = ControlPlaneClient(
        baseUri: Uri.parse('http://${server.address.address}:${server.port}'),
        httpClientFactory: () => realHttpOverrides.createHttpClient(null),
      );

      await expectLater(
        client.startPlatformTunnel(
          mode: PlatformTunnelMode.appleNetworkExtension,
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test(
    'mobile control plane client fails closed when available platform tunnel omits satisfied prerequisites',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((HttpRequest request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{
            'contract_version': '1',
            'build': <String, dynamic>{
              'product': 'RelayDock',
              'version': '0.1.0',
              'build_number': '1',
            },
            'capabilities': <String>[
              'mobile_host_bridge',
              'platform_tunnels',
              'profiles',
              'provider-runtime-artifacts',
              'runtime-execution-planning',
              'sessions',
              'challenges',
              'diagnostics',
              'event_stream',
            ],
            'platform_tunnels': <Map<String, dynamic>>[
              <String, dynamic>{
                'mode': 'apple_network_extension',
                'available': true,
              },
            ],
          }),
        );
        await request.response.close();
      });

      final realHttpOverrides = _RealHttpOverrides();
      final client = ControlPlaneClient(
        baseUri: Uri.parse('http://${server.address.address}:${server.port}'),
        httpClientFactory: () => realHttpOverrides.createHttpClient(null),
      );

      await expectLater(
        client.negotiate(
          supportedVersions: const <String>['1'],
          requiredCapabilities: const <Capability>[
            Capability.mobileHostBridge,
            Capability.platformTunnels,
          ],
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test(
    'mobile control plane client fails closed on startup results missing failing prerequisite',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((HttpRequest request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{
            'mode': 'apple_network_extension',
            'ready': false,
            'stage': 'runtime_attach',
            'message': 'runtime attach failed without a typed prerequisite',
          }),
        );
        await request.response.close();
      });

      final realHttpOverrides = _RealHttpOverrides();
      final client = ControlPlaneClient(
        baseUri: Uri.parse('http://${server.address.address}:${server.port}'),
        httpClientFactory: () => realHttpOverrides.createHttpClient(null),
      );

      await expectLater(
        client.startPlatformTunnel(
          mode: PlatformTunnelMode.appleNetworkExtension,
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test(
    'mobile control plane client preserves typed resolution action failure details',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((HttpRequest request) async {
        request.response.statusCode = HttpStatus.conflict;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{
            'code': 'resolution_export_unavailable',
            'message':
                'resolution action "export_handoff" is unavailable: resolution export is not available',
            'action': 'export_handoff',
          }),
        );
        await request.response.close();
      });

      final realHttpOverrides = _RealHttpOverrides();
      final client = ControlPlaneClient(
        baseUri: Uri.parse('http://${server.address.address}:${server.port}'),
        httpClientFactory: () => realHttpOverrides.createHttpClient(null),
      );

      await expectLater(
        client.exportResolution('resolution-1'),
        throwsA(
          isA<ControlPlaneError>()
              .having(
                (ControlPlaneError error) => error.code,
                'code',
                'resolution_export_unavailable',
              )
              .having(
                (ControlPlaneError error) => error.action,
                'action',
                'export_handoff',
              ),
        ),
      );
    },
  );
}

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.connectionTimeout = const Duration(seconds: 5);
    return client;
  }
}

class _FakeResolver implements MobileHostConfigResolver {
  const _FakeResolver(this.resolved);

  final ResolvedMobileHostConfig? resolved;

  @override
  Future<ResolvedMobileHostConfig?> resolve() async => resolved;
}

class _FakeBrowserReturnSignalSource
    implements MobileBrowserReturnSignalSource {
  const _FakeBrowserReturnSignalSource(this.signals);

  @override
  final Stream<MobileBrowserReturnSignal> signals;

  @override
  Future<void> dispose() async {}
}

class _ReadyControlPlaneApi implements ControlPlaneApi {
  _ReadyControlPlaneApi();

  static const List<ProviderDescriptor> _providers = <ProviderDescriptor>[
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

  static const HostInfo _hostInfo = HostInfo(
    contractVersion: '1',
    build: BuildIdentity(
      product: 'RelayDock',
      version: '0.1.0',
      buildNumber: '1',
      revision: 'nativebridge123',
      role: 'mobile_host',
      target: 'mobile/test',
    ),
    capabilities: <Capability>[
      Capability.mobileHostBridge,
      Capability.platformTunnels,
      Capability.profiles,
      Capability.providerConfigs,
      Capability.providerRuntimeArtifacts,
      Capability.providerTransportCompatibility,
      Capability.runtimeExecutionPlanning,
      Capability.vpnTransportProfileStore,
      Capability.sessions,
      Capability.challenges,
      Capability.diagnostics,
      Capability.eventStream,
    ],
    platformTunnels: <PlatformTunnelCapability>[
      PlatformTunnelCapability(
        mode: PlatformTunnelMode.appleNetworkExtension,
        available: false,
        missingPrerequisite: PlatformTunnelPrerequisite.hostImplementation,
        message: 'native bridge does not implement tunnel startup yet',
      ),
    ],
    transportProfileStore: TransportProfileStoreCapability(
      supportedKinds: <TransportProfileKind>[
        TransportProfileKind.wireGuardNativeV1,
      ],
      importAdapters: <TransportProfileImportAdapterDescriptor>[
        TransportProfileImportAdapterDescriptor(
          id: TransportProfileImportAdapter.wireGuardConf,
          profileKind: TransportProfileKind.wireGuardNativeV1,
          materialAcquisitionMethod:
              TransportProfileMaterialAcquisitionMethod.plainText,
        ),
      ],
    ),
  );

  final List<List<Capability>> negotiateCalls = <List<Capability>>[];
  final List<String?> startPlatformTunnelResolutionIDs = <String?>[];
  final List<RuntimeDefaults?> startPlatformTunnelRuntimeDefaults =
      <RuntimeDefaults?>[];
  final List<PlatformTunnelUnderlayRoutePolicy>
  startPlatformTunnelUnderlayRoutePolicies =
      <PlatformTunnelUnderlayRoutePolicy>[];
  final List<PlatformTunnelMode> stopPlatformTunnelModes =
      <PlatformTunnelMode>[];

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
  Future<void> deleteProfile(String profileId) async {}

  @override
  Future<void> deleteProviderConfig(String configId) async {}

  @override
  Future<List<TransportProfileStatus>> transportProfiles() async =>
      const <TransportProfileStatus>[];

  @override
  Future<TransportProfileStatus> importTransportProfile(
    TransportProfileImportRequest request,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<TransportProfileStructuredSaveResult> createStructuredTransportProfile(
    TransportProfileStructuredCreateRequest request,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<TransportProfileStructuredSaveResult> updateStructuredTransportProfile(
    String profileId,
    TransportProfileStructuredUpdateRequest request,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<TransportProfileStructuredValidationResult>
  validateStructuredTransportProfileDraft(
    TransportProfileStructuredValidationRequest request,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<TransportProfileGeneratedKey> generateTransportProfileKey(
    TransportProfileGenerateKeyRequest request,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<TransportProfileStatus> validateTransportProfile(String profileId) {
    throw UnimplementedError();
  }

  @override
  Future<TransportProfileStatus> selectTransportProfileForStartup(
    String profileId,
    TransportProfileSelectForStartupRequest request,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> forgetTransportProfile(String profileId) async {}

  @override
  Future<ResolutionRecord> cancelResolution(String resolutionId) {
    throw UnimplementedError();
  }

  @override
  Future<DiagnosticsBundle> diagnostics(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Stream<EventRecord> events() => const Stream<EventRecord>.empty();

  @override
  Future<HostInfo> hostInfo() async => _hostInfo;

  @override
  Future<HostInfo> negotiate({
    required List<String> supportedVersions,
    required List<Capability> requiredCapabilities,
  }) async {
    negotiateCalls.add(List<Capability>.of(requiredCapabilities));
    return _hostInfo;
  }

  @override
  Future<ResolutionExportResult> exportResolution(String resolutionId) {
    throw UnimplementedError();
  }

  @override
  Future<List<ProviderDescriptor>> providers() async => _providers;

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
    List<String> allowedPackages = const <String>[],
    List<String> disallowedPackages = const <String>[],
    PlatformTunnelUnderlayRoutePolicy underlayRoutePolicy =
        PlatformTunnelUnderlayRoutePolicy.standard,
  }) async {
    startPlatformTunnelResolutionIDs.add(resolutionId);
    startPlatformTunnelRuntimeDefaults.add(runtimeDefaults);
    startPlatformTunnelUnderlayRoutePolicies.add(underlayRoutePolicy);
    return const PlatformTunnelStartResult(
      mode: PlatformTunnelMode.appleNetworkExtension,
      ready: false,
      stage: PlatformTunnelStartupStage.capabilityCheck,
      missingPrerequisite: PlatformTunnelPrerequisite.hostImplementation,
      message: 'native bridge does not implement tunnel startup yet',
    );
  }

  @override
  Future<PlatformTunnelStartResult> resumePlatformTunnel({
    required String startupAttemptId,
  }) async {
    return PlatformTunnelStartResult(
      mode: PlatformTunnelMode.appleNetworkExtension,
      ready: false,
      stage: PlatformTunnelStartupStage.permissionAcquire,
      missingPrerequisite: PlatformTunnelPrerequisite.permission,
      startupAttemptId: startupAttemptId,
      message: 'native bridge does not implement tunnel resume yet',
    );
  }

  @override
  Future<PlatformTunnelStopResult> stopPlatformTunnel({
    required PlatformTunnelMode mode,
  }) async {
    stopPlatformTunnelModes.add(mode);
    return PlatformTunnelStopResult(
      mode: mode,
      stopped: true,
      message: '${mode.label} disconnected.',
    );
  }

  @override
  Future<List<PlatformTunnelStatus>> platformTunnelStatuses() async =>
      const <PlatformTunnelStatus>[];

  @override
  Future<List<ProfileRecord>> profiles() async => const <ProfileRecord>[];

  @override
  Future<List<ProviderConfigRecord>> providerConfigs() async =>
      const <ProviderConfigRecord>[];

  @override
  Future<List<ResolutionRecord>> resolutions() async =>
      const <ResolutionRecord>[];

  @override
  Future<ResolutionRecord> startResolution({
    required String provider,
    required ProviderInputEnvelope input,
    Map<String, dynamic> providerSettings = const <String, dynamic>{},
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<SessionRecord>> sessions() async => const <SessionRecord>[];

  @override
  Future<SessionRecord> startSession({String? profileId, ProfileSpec? spec}) {
    throw UnimplementedError();
  }

  @override
  Future<SessionRecord> materializeResolution({
    required String resolutionId,
    required RuntimeDefaults runtimeDefaults,
    RuntimeExecutionPlan? executionPlan,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SessionRecord> stopSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<ProfileRecord> upsertProfile(ProfileRecord profile) async => profile;

  @override
  Future<ProviderConfigRecord> upsertProviderConfig(
    ProviderConfigRecord config,
  ) async => config;

  @override
  Future<ProviderConfigRecord> restoreProviderConfig(
    ProviderConfigRecord config,
  ) async => config;
}
