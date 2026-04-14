import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gui_shell/src/control/control_plane_client.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/desktop_host_supervisor.dart';

void main() {
  test(
    'supervisor reports incompatible host without launching sidecar',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((HttpRequest request) async {
        if (request.uri.path == '/v1/host') {
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, dynamic>{
              'contract_version': '0',
              'version': '0',
              'build': <String, dynamic>{
                'product': 'vk-turn-proxy-go',
                'version': '0.0.9',
                'build_number': '7',
                'revision': 'badcafe12345',
                'role': 'clientd',
                'target': 'linux/amd64',
              },
              'capabilities': <String>['profiles'],
            }),
          );
        } else if (request.uri.path == '/v1/negotiate') {
          final payload =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
          expect(
            payload['required_capabilities'],
            contains('platform_tunnels'),
          );
          request.response.statusCode = HttpStatus.conflict;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, dynamic>{
              'code': 'incompatible_host',
              'message':
                  'client control host missing capabilities: event_stream',
            }),
          );
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });

      final client = ControlPlaneClient(
        baseUri: Uri.parse('http://${server.address.address}:${server.port}'),
      );
      var launched = false;
      final supervisor = DesktopHostSupervisor(
        client: client,
        listenAddress: '${server.address.address}:${server.port}',
        locator: _StaticLocator(const <SidecarLaunchSpec>[
          SidecarLaunchSpec(
            executable: 'clientd',
            description: 'should-not-launch',
          ),
        ]),
        starter: (SidecarLaunchSpec spec) async {
          launched = true;
          return _FakeManagedProcess();
        },
      );

      final result = await supervisor.ensureReady();
      expect(result.state, HostLifecycleState.incompatible);
      expect(result.info?.build.version, '0.0.9');
      expect(launched, isFalse);
    },
  );

  test(
    'supervisor launches repo-local clientd and negotiates contract',
    () async {
      final repoRoot = _findRepoRoot(Directory.current);
      expect(repoRoot, isNotNull);

      final listenPort = await _reservePort();
      final listenAddress = '127.0.0.1:$listenPort';
      final client = ControlPlaneClient(
        baseUri: Uri.parse('http://$listenAddress'),
      );
      final supervisor = DesktopHostSupervisor(
        client: client,
        listenAddress: listenAddress,
        locator: _StaticLocator(<SidecarLaunchSpec>[
          SidecarLaunchSpec(
            executable: 'go',
            arguments: <String>[
              'run',
              './cmd/clientd',
              '-listen',
              listenAddress,
            ],
            workingDirectory: repoRoot!.path,
            description: 'repo-local go run fallback',
          ),
        ]),
        startupTimeout: const Duration(seconds: 60),
      );
      addTearDown(supervisor.dispose);

      final result = await supervisor.ensureReady();
      expect(result.isReady, isTrue);
      expect(result.launched, isTrue);
      expect(result.info?.contractVersion, '1');
      expect(result.info?.build.version, isNotEmpty);
      expect(result.info?.capabilities, contains(Capability.desktopSidecar));
      expect(result.info?.capabilities, contains(Capability.platformTunnels));
      expect(
        result.info?.platformTunnels.single.mode,
        PlatformTunnelMode.linuxTun,
      );
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    'supervisor falls through launched incompatible candidate to the next sidecar',
    () async {
      final listenPort = await _reservePort();
      final listenAddress = '127.0.0.1:$listenPort';
      final client = ControlPlaneClient(
        baseUri: Uri.parse('http://$listenAddress'),
      );
      final supervisor = DesktopHostSupervisor(
        client: client,
        listenAddress: listenAddress,
        locator: _StaticLocator(const <SidecarLaunchSpec>[
          SidecarLaunchSpec(
            executable: 'clientd-a',
            description: 'bad-sidecar',
          ),
          SidecarLaunchSpec(
            executable: 'clientd-b',
            description: 'good-sidecar',
          ),
        ]),
        starter: (SidecarLaunchSpec spec) async {
          final host = await HttpServer.bind(
            InternetAddress.loopbackIPv4,
            listenPort,
          );
          host.listen((HttpRequest request) async {
            if (request.uri.path == '/v1/host') {
              request.response.headers.contentType = ContentType.json;
              if (spec.description == 'bad-sidecar') {
                request.response.write(
                  jsonEncode(<String, dynamic>{
                    'contract_version': '0',
                    'version': '0',
                    'build': <String, dynamic>{
                      'product': 'vk-turn-proxy-go',
                      'version': '0.0.9',
                      'build_number': '7',
                      'revision': 'badcafe12345',
                      'role': 'clientd',
                      'target': 'linux/amd64',
                    },
                    'capabilities': <String>['profiles'],
                  }),
                );
              } else {
                request.response.write(
                  jsonEncode(<String, dynamic>{
                    'contract_version': '1',
                    'version': '1',
                    'build': <String, dynamic>{
                      'product': 'vk-turn-proxy-go',
                      'version': '0.1.0',
                      'build_number': '1',
                      'revision': 'deadbeefcafe',
                      'role': 'clientd',
                      'target': 'linux/amd64',
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
                        'mode': 'linux_tun',
                        'available': false,
                        'missing_prerequisite': 'host_implementation',
                      },
                    ],
                  }),
                );
              }
              await request.response.close();
              return;
            }

            if (request.uri.path != '/v1/negotiate') {
              request.response.statusCode = HttpStatus.notFound;
              await request.response.close();
              return;
            }

            if (spec.description == 'bad-sidecar') {
              request.response.statusCode = HttpStatus.conflict;
              request.response.headers.contentType = ContentType.json;
              request.response.write(
                jsonEncode(<String, dynamic>{
                  'code': 'incompatible_host',
                  'message':
                      'incompatible client control host version=0 supported=1',
                }),
              );
              await request.response.close();
              return;
            }

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
                  'role': 'clientd',
                  'target': 'linux/amd64',
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
                    'mode': 'linux_tun',
                    'available': false,
                    'missing_prerequisite': 'host_implementation',
                  },
                ],
              }),
            );
            await request.response.close();
          });
          return _ServerManagedProcess(host);
        },
      );
      addTearDown(supervisor.dispose);

      final result = await supervisor.ensureReady();
      expect(result.isReady, isTrue);
      expect(result.launched, isTrue);
      expect(result.launchSpec?.description, 'good-sidecar');
    },
  );

  test(
    'supervisor stops launching fallbacks after shutdown is requested',
    () async {
      final listenPort = await _reservePort();
      final listenAddress = '127.0.0.1:$listenPort';
      final client = ControlPlaneClient(
        baseUri: Uri.parse('http://$listenAddress'),
        timeout: const Duration(milliseconds: 50),
      );
      final launched = <String>[];
      final firstLaunch = Completer<void>();
      final processes = <String, _TrackingManagedProcess>{};
      final supervisor = DesktopHostSupervisor(
        client: client,
        listenAddress: listenAddress,
        locator: _StaticLocator(const <SidecarLaunchSpec>[
          SidecarLaunchSpec(
            executable: 'clientd-a',
            description: 'first-sidecar',
          ),
          SidecarLaunchSpec(
            executable: 'clientd-b',
            description: 'second-sidecar',
          ),
        ]),
        startupTimeout: const Duration(seconds: 5),
        probeInterval: const Duration(milliseconds: 10),
        starter: (SidecarLaunchSpec spec) async {
          launched.add(spec.description);
          final process = _TrackingManagedProcess();
          processes[spec.description] = process;
          if (!firstLaunch.isCompleted) {
            firstLaunch.complete();
          }
          return process;
        },
      );

      final ensureFuture = supervisor.ensureReady();
      await firstLaunch.future;
      await supervisor.dispose();

      final result = await ensureFuture;
      expect(result.state, HostLifecycleState.failed);
      expect(result.message, 'Local host shutdown requested.');
      expect(launched, <String>['first-sidecar']);
      expect(processes['first-sidecar']?.killCalls, 1);
    },
  );

  test('macOS bundled sidecar path resolves inside Contents/Frameworks', () {
    expect(
      macOSBundledSidecarPath(
        '/Applications/gui_shell.app/Contents/MacOS/gui_shell',
        'clientd',
      ),
      '/Applications/gui_shell.app/Contents/Frameworks/clientd',
    );
  });
}

class _StaticLocator implements SidecarLocator {
  const _StaticLocator(this._candidates);

  final List<SidecarLaunchSpec> _candidates;

  @override
  Future<List<SidecarLaunchSpec>> candidates(String listenAddress) async {
    return _candidates;
  }
}

class _FakeManagedProcess implements ManagedSidecarProcess {
  @override
  Future<int> get exitCode => Future<int>.value(0);

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
}

class _ServerManagedProcess implements ManagedSidecarProcess {
  _ServerManagedProcess(this._server);

  final HttpServer _server;
  final Completer<int> _exitCode = Completer<int>();

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    unawaited(
      _server.close(force: true).whenComplete(() {
        if (!_exitCode.isCompleted) {
          _exitCode.complete(0);
        }
      }),
    );
    return true;
  }
}

class _TrackingManagedProcess implements ManagedSidecarProcess {
  final Completer<int> _exitCode = Completer<int>();
  int killCalls = 0;

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killCalls++;
    if (!_exitCode.isCompleted) {
      _exitCode.complete(0);
    }
    return true;
  }
}

Future<int> _reservePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

Directory? _findRepoRoot(Directory start) {
  Directory current = start.absolute;
  while (true) {
    if (File('${current.path}/go.mod').existsSync() &&
        Directory('${current.path}/cmd/clientd').existsSync()) {
      return current;
    }
    if (current.parent.path == current.path) {
      return null;
    }
    current = current.parent;
  }
}
