import 'dart:convert';
import 'dart:io';

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
    },
  );

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
      final bridge = await MobileHostBridgeFactory.fromEnvironment(
        configuredBaseUrl: 'http://127.0.0.1:7777',
        clientFactory: (_) => _ReadyControlPlaneApi(),
      );

      final result = await bridge.startPlatformTunnel(
        mode: PlatformTunnelMode.appleNetworkExtension,
      );

      expect(result.ready, isFalse);
      expect(result.stage, PlatformTunnelStartupStage.capabilityCheck);
      expect(
        result.missingPrerequisite,
        PlatformTunnelPrerequisite.hostImplementation,
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
              'product': 'vk-turn-proxy-go',
              'version': '0.1.0',
              'build_number': '1',
            },
            'capabilities': <String>[
              'mobile_host_bridge',
              'platform_tunnels',
              'profiles',
              'provider-runtime-artifacts',
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
              'product': 'vk-turn-proxy-go',
              'version': '0.1.0',
              'build_number': '1',
            },
            'capabilities': <String>[
              'mobile_host_bridge',
              'platform_tunnels',
              'profiles',
              'provider-runtime-artifacts',
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
      product: 'vk-turn-proxy-go',
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
  );

  final List<List<Capability>> negotiateCalls = <List<Capability>>[];

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
  Future<void> deleteProfile(String profileId) async {}

  @override
  Future<void> deleteProviderConfig(String configId) async {}

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
  Future<PlatformTunnelStartResult> startPlatformTunnel({
    required PlatformTunnelMode mode,
  }) async {
    return const PlatformTunnelStartResult(
      mode: PlatformTunnelMode.appleNetworkExtension,
      ready: false,
      stage: PlatformTunnelStartupStage.capabilityCheck,
      missingPrerequisite: PlatformTunnelPrerequisite.hostImplementation,
      message: 'native bridge does not implement tunnel startup yet',
    );
  }

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
}
