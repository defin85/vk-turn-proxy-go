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
                'product': 'RelayDock',
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
                'runtime-execution-planning',
              ],
              'platform_tunnels': <Map<String, dynamic>>[
                <String, dynamic>{
                  'mode': 'windows_wintun',
                  'available': false,
                  'execution_plans': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'plan': <String, dynamic>{
                        'access_method': 'turn_credentials',
                        'carrier_family': 'turn_datagram',
                        'engine_family': 'wireguard_native',
                        'host_adapter': 'windows_wintun',
                      },
                      'support_state': 'unavailable',
                      'remote_endpoint_family': 'turn_server',
                      'remote_endpoint_role': 'wireguard_raw_datagram',
                      'default': true,
                      'message': 'packaged host missing tunnel implementation',
                    },
                  ],
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
              'execution_plan': <String, dynamic>{
                'access_method': 'turn_credentials',
                'carrier_family': 'turn_datagram',
                'engine_family': 'wireguard_native',
                'host_adapter': 'windows_wintun',
              },
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
        case '/v1/resolutions':
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'resolution-room-1',
                'provider': 'roomy',
                'input': <String, dynamic>{
                  'provider': 'roomy',
                  'kind': 'link',
                  'link_redacted':
                      'https://room.example.test/join/<redacted:room-token>',
                },
                'state': 'resolved',
                'artifact': <String, dynamic>{
                  'family': 'conference_room',
                  'actions': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'open_room',
                      'execution_owner': 'shell_external',
                    },
                  ],
                  'summary': <String, dynamic>{
                    'conference_room': <String, dynamic>{
                      'room_url': 'https://room.example.test/rooms/team-sync',
                    },
                  },
                },
                'export': <String, dynamic>{'supported': false},
                'started_at': DateTime.utc(2026, 4, 5, 14, 0).toIso8601String(),
                'updated_at': DateTime.utc(2026, 4, 5, 14, 1).toIso8601String(),
                'resolved_at': DateTime.utc(
                  2026,
                  4,
                  5,
                  14,
                  1,
                ).toIso8601String(),
              },
            ]),
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
    expect(info.capabilities, contains(Capability.runtimeExecutionPlanning));
    expect(info.platformTunnels, hasLength(1));
    expect(info.platformTunnels.single.mode, PlatformTunnelMode.windowsWintun);
    expect(
      info.platformTunnels.single.missingPrerequisite,
      PlatformTunnelPrerequisite.hostImplementation,
    );
    expect(info.platformTunnels.single.executionPlans, hasLength(1));
    expect(
      info.platformTunnels.single.executionPlans.single.plan.engineFamily,
      RuntimeEngineFamily.wireguardNative,
    );

    final startResult = await client.startPlatformTunnel(
      mode: PlatformTunnelMode.windowsWintun,
    );
    expect(startResult.ready, isFalse);
    expect(startResult.stage, PlatformTunnelStartupStage.capabilityCheck);
    expect(
      startResult.executionPlan?.engineFamily,
      RuntimeEngineFamily.wireguardNative,
    );

    final events = await client.events().toList();
    expect(events, hasLength(1));
    expect(events.single.type, EventType.sessionReady);
    expect(events.single.state, SessionState.ready);
    expect(events.single.message, 'runtime ready');

    final challenge = await client.challenge('challenge-1');
    expect(challenge.id, 'challenge-1');
    expect(challenge.openUrl, 'https://vk.com/call/join/test');

    final resolutions = await client.resolutions();
    expect(resolutions, hasLength(1));
    expect(resolutions.single.artifact?.family, ArtifactFamily.conferenceRoom);
    expect(
      resolutions.single.artifact?.summary.conferenceRoom?.roomUrl,
      'https://room.example.test/rooms/team-sync',
    );
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
              'product': 'RelayDock',
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
              'product': 'RelayDock',
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
              <String, dynamic>{'mode': 'windows_wintun', 'available': true},
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

  test(
    'control plane client preserves typed resolution action failure details',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((HttpRequest request) async {
        request.response.statusCode = HttpStatus.conflict;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{
            'code': 'resolution_materialize_unavailable',
            'message':
                'resolution action "start_on_this_device" is unavailable: resolution is not transport-ready',
            'action': 'start_on_this_device',
            'stage': 'runtime_attach',
            'not_implemented': true,
          }),
        );
        await request.response.close();
      });

      final client = ControlPlaneClient(
        baseUri: Uri.parse('http://${server.address.address}:${server.port}'),
      );

      await expectLater(
        client.materializeResolution(
          resolutionId: 'resolution-1',
          runtimeDefaults: const RuntimeDefaults(
            listenAddress: '127.0.0.1:9001',
            peerAddress: '127.0.0.1:56000',
          ),
        ),
        throwsA(
          isA<ControlPlaneError>()
              .having(
                (ControlPlaneError error) => error.code,
                'code',
                'resolution_materialize_unavailable',
              )
              .having(
                (ControlPlaneError error) => error.action,
                'action',
                'start_on_this_device',
              )
              .having(
                (ControlPlaneError error) => error.stage,
                'stage',
                'runtime_attach',
              )
              .having(
                (ControlPlaneError error) => error.notImplemented,
                'notImplemented',
                isTrue,
              ),
        ),
      );
    },
  );

  test(
    'control plane client sends provider settings and parses field-aware validation failures',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((HttpRequest request) async {
        expect(request.uri.path, '/v1/resolutions');
        final payload =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        expect(payload['provider'], 'wb-stream');
        expect(payload['provider_settings'], <String, dynamic>{
          'region': 'eu-west',
          'device_pin': '123456',
        });
        request.response.statusCode = HttpStatus.badRequest;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{
            'code': 'provider_settings_invalid',
            'message': 'provider_settings.region is required',
            'field': 'region',
            'violation': 'required',
          }),
        );
        await request.response.close();
      });

      final client = ControlPlaneClient(
        baseUri: Uri.parse('http://${server.address.address}:${server.port}'),
      );

      await expectLater(
        client.startResolution(
          provider: 'wb-stream',
          input: const ProviderInputEnvelope(
            kind: ProviderInputKind.link,
            link: 'https://wb.example.test/invite/abc',
          ),
          providerSettings: const <String, dynamic>{
            'region': 'eu-west',
            'device_pin': '123456',
          },
        ),
        throwsA(
          isA<ControlPlaneError>()
              .having(
                (ControlPlaneError error) => error.code,
                'code',
                'provider_settings_invalid',
              )
              .having(
                (ControlPlaneError error) => error.field,
                'field',
                'region',
              )
              .having(
                (ControlPlaneError error) => error.violation,
                'violation',
                'required',
              ),
        ),
      );
    },
  );
}
