import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gui_shell/src/control/control_plane_client.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';

void main() {
  test('control plane client parses negotiate and event payloads', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    server.listen((HttpRequest request) async {
      switch (request.uri.path) {
        case '/v1/negotiate':
          final payload =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
          expect(
            payload['required_capabilities'],
            contains('platform_tunnels'),
          );
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, dynamic>{
              'contract_version': '1',
              'version': '1',
              'build': <String, dynamic>{
                'product': 'vk-turn-proxy-go',
                'version': '0.1.0',
                'build_number': '1',
                'revision': 'deadbeefcafe',
                'dirty': true,
                'role': 'clientd',
                'target': 'windows/amd64',
              },
              'capabilities': <String>[
                'profiles',
                'sessions',
                'challenges',
                'diagnostics',
                'event_stream',
                'desktop_sidecar',
                'platform_tunnels',
              ],
              'platform_tunnels': <Map<String, dynamic>>[
                <String, dynamic>{
                  'mode': 'windows_wintun',
                  'available': false,
                  'missing_prerequisite': 'host_implementation',
                  'message': 'packaged host missing tunnel implementation',
                },
              ],
            }),
          );
          await request.response.close();
          return;
        case '/v1/platform-tunnels/start':
          final payload =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
          expect(payload['mode'], 'windows_wintun');
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, dynamic>{
              'mode': 'windows_wintun',
              'ready': false,
              'stage': 'capability_check',
              'missing_prerequisite': 'host_implementation',
              'message': 'packaged host missing tunnel implementation',
            }),
          );
          await request.response.close();
          return;
        case '/v1/events':
          request.response.headers.contentType = ContentType(
            'application',
            'x-ndjson',
          );
          request.response.write(
            jsonEncode(<String, dynamic>{
              'id': 'event-1',
              'timestamp': DateTime.utc(2026, 4, 5, 14, 0).toIso8601String(),
              'session_id': 'session-1',
              'type': 'session_ready',
              'state': 'ready',
              'message': 'runtime ready',
            }),
          );
          request.response.write('\n');
          await request.response.close();
          return;
        case '/v1/challenges/challenge-1':
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, dynamic>{
              'id': 'challenge-1',
              'session_id': 'session-1',
              'provider': 'vk',
              'stage': 'provider_resolve',
              'kind': 'browser',
              'prompt': 'continue in browser',
              'open_url': 'https://vk.com/call/join/test',
              'status': 'pending',
              'created_at': DateTime.utc(2026, 4, 5, 14, 0).toIso8601String(),
              'updated_at': DateTime.utc(2026, 4, 5, 14, 0).toIso8601String(),
            }),
          );
          await request.response.close();
          return;
        default:
          request.response.statusCode = HttpStatus.notFound;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, dynamic>{
              'code': 'not_found',
              'message': 'missing fixture route',
            }),
          );
          await request.response.close();
          return;
      }
    });

    final client = ControlPlaneClient(
      baseUri: Uri.parse('http://${server.address.address}:${server.port}'),
    );

    final info = await client.negotiate(
      supportedVersions: const <String>['1'],
      requiredCapabilities: const <Capability>[
        Capability.desktopSidecar,
        Capability.platformTunnels,
        Capability.sessions,
      ],
    );
    expect(info.contractVersion, '1');
    expect(info.build.version, '0.1.0');
    expect(info.capabilities, contains(Capability.desktopSidecar));
    expect(info.platformTunnels, hasLength(1));
    expect(info.platformTunnels.single.mode, PlatformTunnelMode.windowsWintun);
    expect(
      info.platformTunnels.single.missingPrerequisite,
      PlatformTunnelPrerequisite.hostImplementation,
    );

    final startResult = await client.startPlatformTunnel(
      mode: PlatformTunnelMode.windowsWintun,
    );
    expect(startResult.ready, isFalse);
    expect(startResult.stage, PlatformTunnelStartupStage.capabilityCheck);

    final events = await client.events().toList();
    expect(events, hasLength(1));
    expect(events.single.type, EventType.sessionReady);
    expect(events.single.state, SessionState.ready);
    expect(events.single.message, 'runtime ready');

    final challenge = await client.challenge('challenge-1');
    expect(challenge.id, 'challenge-1');
    expect(challenge.openUrl, 'https://vk.com/call/join/test');
  });

  test(
    'control plane client fails closed on invalid platform tunnel payloads',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((HttpRequest request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{
            'contract_version': '1',
            'version': '1',
            'build': <String, dynamic>{
              'product': 'vk-turn-proxy-go',
              'version': '0.1.0',
              'build_number': '1',
            },
            'capabilities': <String>[
              'desktop_sidecar',
              'platform_tunnels',
              'profiles',
              'sessions',
              'challenges',
              'diagnostics',
              'event_stream',
            ],
            'platform_tunnels': <Map<String, dynamic>>[
              <String, dynamic>{
                'mode': 'future_desktop_mode',
                'available': false,
                'missing_prerequisite': 'host_implementation',
              },
            ],
          }),
        );
        await request.response.close();
      });

      final client = ControlPlaneClient(
        baseUri: Uri.parse('http://${server.address.address}:${server.port}'),
      );

      await expectLater(
        client.negotiate(
          supportedVersions: const <String>['1'],
          requiredCapabilities: const <Capability>[
            Capability.desktopSidecar,
            Capability.platformTunnels,
          ],
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test(
    'control plane client fails closed on invalid platform tunnel startup results',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((HttpRequest request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{
            'mode': 'windows_wintun',
            'ready': false,
            'message': 'missing startup stage',
          }),
        );
        await request.response.close();
      });

      final client = ControlPlaneClient(
        baseUri: Uri.parse('http://${server.address.address}:${server.port}'),
      );

      await expectLater(
        client.startPlatformTunnel(mode: PlatformTunnelMode.windowsWintun),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test(
    'control plane client fails closed when available platform tunnel omits satisfied prerequisites',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((HttpRequest request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{
            'contract_version': '1',
            'version': '1',
            'build': <String, dynamic>{
              'product': 'vk-turn-proxy-go',
              'version': '0.1.0',
              'build_number': '1',
            },
            'capabilities': <String>[
              'desktop_sidecar',
              'platform_tunnels',
              'profiles',
              'sessions',
              'challenges',
              'diagnostics',
              'event_stream',
            ],
            'platform_tunnels': <Map<String, dynamic>>[
              <String, dynamic>{
                'mode': 'windows_wintun',
                'available': true,
              },
            ],
          }),
        );
        await request.response.close();
      });

      final client = ControlPlaneClient(
        baseUri: Uri.parse('http://${server.address.address}:${server.port}'),
      );

      await expectLater(
        client.negotiate(
          supportedVersions: const <String>['1'],
          requiredCapabilities: const <Capability>[
            Capability.desktopSidecar,
            Capability.platformTunnels,
          ],
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test(
    'control plane client fails closed on startup results missing failing prerequisite',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((HttpRequest request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{
            'mode': 'windows_wintun',
            'ready': false,
            'stage': 'runtime_attach',
            'message': 'runtime attach failed without a typed prerequisite',
          }),
        );
        await request.response.close();
      });

      final client = ControlPlaneClient(
        baseUri: Uri.parse('http://${server.address.address}:${server.port}'),
      );

      await expectLater(
        client.startPlatformTunnel(mode: PlatformTunnelMode.windowsWintun),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
