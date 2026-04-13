import 'dart:convert';
import 'dart:io';

import 'package:flutter_shell_core/flutter_shell_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'control plane client parses shared negotiate and event payloads',
    () async {
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
            request.response.write('\n');
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
                'completion_mode': 'app_return_callback',
                'browser_return': <String, dynamic>{
                  'signal_kinds': <String>[
                    'foreground_resume',
                    'app_link',
                    'foreground_resume',
                  ],
                  'allow_auto_continue': true,
                  'expected_return_uri':
                      'https://app.example.test/mobile-return',
                },
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
                  'started_at': DateTime.utc(
                    2026,
                    4,
                    5,
                    14,
                    0,
                  ).toIso8601String(),
                  'updated_at': DateTime.utc(
                    2026,
                    4,
                    5,
                    14,
                    1,
                  ).toIso8601String(),
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
      expect(info.platformTunnels, hasLength(1));
      expect(
        info.platformTunnels.single.mode,
        PlatformTunnelMode.windowsWintun,
      );
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
      expect(
        challenge.completionMode,
        ChallengeCompletionMode.appReturnCallback,
      );
      expect(challenge.browserReturn, isNotNull);
      expect(challenge.browserReturn?.signalKinds, <BrowserReturnSignalKind>[
        BrowserReturnSignalKind.foregroundResume,
        BrowserReturnSignalKind.appLink,
      ]);
      expect(challenge.browserReturn?.allowAutoContinue, isTrue);
      expect(
        challenge.browserReturn?.expectedReturnUri,
        'https://app.example.test/mobile-return',
      );
      expect(challenge.openUrl, 'https://vk.com/call/join/test');

      final resolutions = await client.resolutions();
      expect(resolutions, hasLength(1));
      expect(
        resolutions.single.artifact?.family,
        ArtifactFamily.conferenceRoom,
      );
      expect(
        resolutions.single.artifact?.summary.conferenceRoom?.roomUrl,
        'https://room.example.test/rooms/team-sync',
      );
    },
  );

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

  test('control plane client manages provider config CRUD payloads', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    server.listen((HttpRequest request) async {
      switch (request.uri.path) {
        case '/v1/provider-configs':
          if (request.method == 'GET') {
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode(<Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'cfg-1',
                  'provider': 'wb-stream',
                  'name': 'WB EU guest',
                  'provider_settings': <String, dynamic>{'region': 'eu-west'},
                  'availability': <String, dynamic>{'state': 'available'},
                  'created_at': DateTime.utc(
                    2026,
                    4,
                    13,
                    10,
                    15,
                  ).toIso8601String(),
                  'updated_at': DateTime.utc(
                    2026,
                    4,
                    13,
                    10,
                    16,
                  ).toIso8601String(),
                },
              ]),
            );
            await request.response.close();
            return;
          }
          if (request.method == 'POST') {
            final payload =
                jsonDecode(await utf8.decoder.bind(request).join())
                    as Map<String, dynamic>;
            expect(payload['provider'], 'wb-stream');
            expect(payload['name'], 'WB EU guest');
            expect(payload['provider_settings'], <String, dynamic>{
              'region': 'eu-west',
            });
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode(<String, dynamic>{
                'id': 'cfg-1',
                'provider': 'wb-stream',
                'name': 'WB EU guest',
                'provider_settings': <String, dynamic>{'region': 'eu-west'},
                'availability': <String, dynamic>{'state': 'available'},
                'created_at': DateTime.utc(
                  2026,
                  4,
                  13,
                  10,
                  15,
                ).toIso8601String(),
                'updated_at': DateTime.utc(
                  2026,
                  4,
                  13,
                  10,
                  16,
                ).toIso8601String(),
              }),
            );
            await request.response.close();
            return;
          }
          break;
        case '/v1/provider-configs/cfg-1':
          expect(request.method, 'DELETE');
          request.response.statusCode = HttpStatus.noContent;
          await request.response.close();
          return;
        case '/v1/provider-configs:restore':
          expect(request.method, 'POST');
          final payload =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
          expect(payload['id'], 'cfg-restore');
          expect(payload['provider'], 'wb-stream');
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, dynamic>{
              'id': 'cfg-restore',
              'provider': 'wb-stream',
              'name': 'Legacy WB guest',
              'provider_settings': <String, dynamic>{'region': 'eu-west'},
              'availability': <String, dynamic>{
                'state': 'provider_unavailable',
                'message':
                    'provider "wb-stream" is not advertised by the current host',
              },
              'created_at': DateTime.utc(2026, 4, 13, 10, 15).toIso8601String(),
              'updated_at': DateTime.utc(2026, 4, 13, 10, 16).toIso8601String(),
            }),
          );
          await request.response.close();
          return;
      }

      request.response.statusCode = HttpStatus.notFound;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, dynamic>{
          'code': 'not_found',
          'message': 'missing fixture route',
        }),
      );
      await request.response.close();
    });

    final client = ControlPlaneClient(
      baseUri: Uri.parse('http://${server.address.address}:${server.port}'),
    );

    final listed = await client.providerConfigs();
    expect(listed, hasLength(1));
    expect(listed.single.id, 'cfg-1');
    expect(listed.single.isAvailable, isTrue);

    final saved = await client.upsertProviderConfig(
      ProviderConfigRecord(
        id: '',
        provider: 'wb-stream',
        name: 'WB EU guest',
        providerSettings: const <String, dynamic>{'region': 'eu-west'},
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    expect(saved.id, 'cfg-1');
    expect(saved.providerSettings, const <String, dynamic>{
      'region': 'eu-west',
    });

    await client.deleteProviderConfig('cfg-1');

    final restored = await client.restoreProviderConfig(
      ProviderConfigRecord(
        id: 'cfg-restore',
        provider: 'wb-stream',
        name: 'Legacy WB guest',
        providerSettings: const <String, dynamic>{'region': 'eu-west'},
        createdAt: DateTime.utc(2026, 4, 13, 10, 15),
        updatedAt: DateTime.utc(2026, 4, 13, 10, 16),
      ),
    );
    expect(restored.id, 'cfg-restore');
    expect(restored.availability.isAvailable, isFalse);
  });

  test(
    'challenge record fails closed when owned-browser metadata is incomplete',
    () {
      final challenge = ChallengeRecord.fromJson(<String, dynamic>{
        'id': 'challenge-1',
        'session_id': 'session-1',
        'provider': 'vk',
        'stage': 'provider_resolve',
        'kind': 'browser',
        'status': 'pending',
        'completion_mode': 'owned_browser_observed',
        'created_at': DateTime.utc(2026, 4, 5, 14, 0).toIso8601String(),
        'updated_at': DateTime.utc(2026, 4, 5, 14, 0).toIso8601String(),
      });

      expect(challenge.completionMode, ChallengeCompletionMode.manualConfirm);
      expect(challenge.ownedBrowser, isNull);
      expect(challenge.browserReturn, isNull);
    },
  );

  test(
    'control plane client sends owned-browser continuation payloads',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((HttpRequest request) async {
        expect(request.uri.path, '/v1/challenges/challenge-1/continue');
        expect(request.method, 'POST');

        final payload =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        final browserContinuation =
            payload['browser_continuation'] as Map<String, dynamic>?;
        expect(browserContinuation, isNotNull);
        final cookies =
            browserContinuation!['cookies'] as List<dynamic>? ?? <dynamic>[];
        expect(cookies, hasLength(1));
        expect((cookies.single as Map<String, dynamic>)['name'], 'session');
        expect(
          (cookies.single as Map<String, dynamic>)['value'],
          'owned-session',
        );

        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{
            'id': 'challenge-1',
            'session_id': 'session-1',
            'provider': 'vk',
            'stage': 'provider_resolve',
            'kind': 'browser',
            'status': 'continuing',
            'completion_mode': 'owned_browser_observed',
            'owned_browser': <String, dynamic>{
              'cookie_urls': <String>['https://login.vk.ru/'],
            },
            'created_at': DateTime.utc(2026, 4, 5, 14, 0).toIso8601String(),
            'updated_at': DateTime.utc(2026, 4, 5, 14, 1).toIso8601String(),
          }),
        );
        await request.response.close();
      });

      final client = ControlPlaneClient(
        baseUri: Uri.parse('http://${server.address.address}:${server.port}'),
      );
      final challenge = await client.continueChallenge(
        'challenge-1',
        browserContinuation: ChallengeContinuationSubmission(
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

      expect(challenge.status, ChallengeStatus.continuing);
      expect(
        challenge.completionMode,
        ChallengeCompletionMode.ownedBrowserObserved,
      );
      expect(challenge.ownedBrowser?.cookieUrls, <String>[
        'https://login.vk.ru/',
      ]);
    },
  );
}
