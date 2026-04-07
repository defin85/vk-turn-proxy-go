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
          return const _ReadyControlPlaneApi();
        },
      );

      expect(bridge, isA<HttpMobileHostBridge>());
      expect(createdUri.toString(), 'http://127.0.0.1:7777');

      final result = await bridge.ensureReady();
      expect(result.state, MobileHostLifecycleState.ready);
      expect(result.description, 'ios loopback default');
      expect(result.info?.capabilities, contains(Capability.mobileHostBridge));
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
}

class _FakeResolver implements MobileHostConfigResolver {
  const _FakeResolver(this.resolved);

  final ResolvedMobileHostConfig? resolved;

  @override
  Future<ResolvedMobileHostConfig?> resolve() async => resolved;
}

class _ReadyControlPlaneApi implements ControlPlaneApi {
  const _ReadyControlPlaneApi();

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
      Capability.profiles,
      Capability.sessions,
      Capability.challenges,
      Capability.diagnostics,
      Capability.eventStream,
    ],
  );

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
    return _hostInfo;
  }

  @override
  Future<List<ProfileRecord>> profiles() async => const <ProfileRecord>[];

  @override
  Future<List<SessionRecord>> sessions() async => const <SessionRecord>[];

  @override
  Future<SessionRecord> startSession({String? profileId, ProfileSpec? spec}) {
    throw UnimplementedError();
  }

  @override
  Future<SessionRecord> stopSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<ProfileRecord> upsertProfile(ProfileRecord profile) async => profile;
}
