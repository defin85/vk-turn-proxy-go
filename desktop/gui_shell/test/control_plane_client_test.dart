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
              ],
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
        Capability.sessions,
      ],
    );
    expect(info.contractVersion, '1');
    expect(info.build.version, '0.1.0');
    expect(info.capabilities, contains(Capability.desktopSidecar));

    final events = await client.events().toList();
    expect(events, hasLength(1));
    expect(events.single.type, EventType.sessionReady);
    expect(events.single.state, SessionState.ready);
    expect(events.single.message, 'runtime ready');

    final challenge = await client.challenge('challenge-1');
    expect(challenge.id, 'challenge-1');
    expect(challenge.openUrl, 'https://vk.com/call/join/test');
  });
}
