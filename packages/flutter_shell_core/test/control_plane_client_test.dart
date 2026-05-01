import 'dart:convert';
import 'dart:io';

import 'package:flutter_shell_core/flutter_shell_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'control plane client sends Accept-Language on locale-aware metadata requests',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((HttpRequest request) async {
        expect(request.uri.path, '/v1/providers');
        expect(
          request.headers.value(HttpHeaders.acceptLanguageHeader),
          'ru-RU,ru;q=0.9,en;q=0.8',
        );
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(<Map<String, dynamic>>[]));
        await request.response.close();
      });

      final client = ControlPlaneClient(
        baseUri: Uri.parse('http://${server.address.address}:${server.port}'),
        localeTagProvider: () => 'ru-RU,ru;q=0.9,en;q=0.8',
      );

      final providers = await client.providers();
      expect(providers, isEmpty);
    },
  );

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
                  'vpn-transport-profile-store',
                ],
                'transport_profile_store': <String, dynamic>{
                  'supported_kinds': <String>[
                    'wireguard_native_v1',
                    'future_native_v1',
                  ],
                  'import_adapters': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'wireguard_conf',
                      'profile_kind': 'wireguard_native_v1',
                      'display_name': 'WireGuard .conf',
                      'extensions': <String>['conf'],
                      'material_acquisition_method': 'plain_text',
                    },
                    <String, dynamic>{
                      'id': 'future_enrollment',
                      'profile_kind': 'future_native_v1',
                      'display_name': 'Future enrollment',
                      'material_acquisition_method': 'provider_managed',
                    },
                  ],
                  'lifecycle_actions': <String>[
                    'list',
                    'import',
                    'replace',
                    'forget',
                    'validate',
                    'select_for_startup',
                    'create_structured',
                    'update_structured',
                    'validate_draft',
                    'generate_key',
                  ],
                  'editable_kinds': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'kind': 'wireguard_native_v1',
                      'schema_version':
                          'wireguard_native_v1.structured_editor.v1',
                      'lifecycle_actions': <String>[
                        'create_structured',
                        'update_structured',
                        'validate_draft',
                        'generate_key',
                      ],
                      'fields': <Map<String, dynamic>>[
                        <String, dynamic>{
                          'id': 'interface_private_key',
                          'value_kind': 'secret_string',
                          'required': true,
                          'secret': true,
                          'generated': true,
                          'update_preservable': true,
                          'supported': true,
                          'secret_update_actions': <String>[
                            'preserve_existing',
                            'replace_submitted',
                            'generate_host',
                          ],
                        },
                      ],
                    },
                  ],
                },
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
                        'default': true,
                        'required_transport_profile_kinds': <String>[
                          'wireguard_native_v1',
                        ],
                        'transport_profile': <String, dynamic>{
                          'required_kinds': <String>['wireguard_native_v1'],
                          'state': 'incompatible',
                          'missing_kind': 'wireguard_native_v1',
                          'import_adapters': <String>['wireguard_conf'],
                          'message':
                              'VPN transport profile wireguard_native_v1 is not configured.',
                        },
                        'message':
                            'packaged host missing tunnel implementation',
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
            expect(payload['resolution_id'], 'resolution-1');
            final runtimeDefaults =
                payload['runtime_defaults'] as Map<String, dynamic>;
            expect(runtimeDefaults['listen_addr'], '127.0.0.1:7777');
            expect(runtimeDefaults['peer_addr'], 'peer.example.test:443');
            expect(runtimeDefaults['turn_server'], 'turn.example.test');
            expect(runtimeDefaults['turn_port'], '3478');
            final executionPlan =
                payload['execution_plan'] as Map<String, dynamic>;
            expect(executionPlan['access_method'], 'turn_credentials');
            expect(executionPlan['carrier_family'], 'turn_datagram');
            expect(executionPlan['engine_family'], 'wireguard_native');
            expect(executionPlan['host_adapter'], 'windows_wintun');
            final transportProfile =
                payload['transport_profile'] as Map<String, dynamic>;
            expect(transportProfile['profile_id'], 'transport-profile-1');
            expect(transportProfile['kind'], 'wireguard_native_v1');
            expect(
              payload['underlay_route_policy'],
              'preserve_active_local_network',
            );
            expect(payload.containsKey('application_routing_policy'), isFalse);
            expect(payload.containsKey('allowed_packages'), isFalse);
            expect(payload.containsKey('disallowed_packages'), isFalse);
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
                'transport_profile': <String, dynamic>{
                  'profile_id': 'transport-profile-1',
                  'kind': 'wireguard_native_v1',
                },
                'ready': false,
                'stage': 'profile_validate',
                'missing_prerequisite': 'transport_profile',
                'message': 'packaged host missing tunnel implementation',
              }),
            );
            await request.response.close();
            return;
          case '/v1/transport-profiles':
            switch (request.method) {
              case 'GET':
                request.response.headers.contentType = ContentType.json;
                request.response.write(
                  jsonEncode(<Map<String, dynamic>>[
                    _transportProfileStatusPayload(),
                  ]),
                );
                await request.response.close();
                return;
              case 'POST':
                final payload =
                    jsonDecode(await utf8.decoder.bind(request).join())
                        as Map<String, dynamic>;
                expect(payload['adapter'], 'wireguard_conf');
                expect(payload['kind'], 'wireguard_native_v1');
                expect(payload['material'], contains('[Interface]'));
                request.response.headers.contentType = ContentType.json;
                request.response.write(
                  jsonEncode(_transportProfileStatusPayload()),
                );
                await request.response.close();
                return;
            }
            break;
          case '/v1/transport-profiles:structured':
            expect(request.method, 'POST');
            final payload =
                jsonDecode(await utf8.decoder.bind(request).join())
                    as Map<String, dynamic>;
            final draft = payload['draft'] as Map<String, dynamic>;
            expect(draft['kind'], 'wireguard_native_v1');
            expect(
              (draft['secret_actions']
                  as Map<String, dynamic>)['interface_private_key'],
              'generate_host',
            );
            expect(
              (draft['fields'] as Map<String, dynamic>)['interface_addresses'],
              <String>['10.10.0.2/32'],
            );
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode(<String, dynamic>{
                'profile': _transportProfileStatusPayload(),
                'generated_keys': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'kind': 'wireguard_native_v1',
                    'field': 'interface_private_key',
                    'public_key': 'saved-public-key',
                    'fingerprint': 'sha256:saved-public',
                  },
                ],
              }),
            );
            await request.response.close();
            return;
          case '/v1/transport-profiles:validate-draft':
            expect(request.method, 'POST');
            final payload =
                jsonDecode(await utf8.decoder.bind(request).join())
                    as Map<String, dynamic>;
            expect(payload['profile_id'], 'transport-profile-1');
            final draft = payload['draft'] as Map<String, dynamic>;
            expect(
              (draft['fields'] as Map<String, dynamic>)['allowed_ips'],
              <String>['0.0.0.0/0'],
            );
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode(<String, dynamic>{
                'valid': false,
                'errors': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'field': 'allowed_ips',
                    'violation': 'malformed',
                    'message': 'bad prefix',
                  },
                ],
              }),
            );
            await request.response.close();
            return;
          case '/v1/transport-profiles:generate-key':
            expect(request.method, 'POST');
            final payload =
                jsonDecode(await utf8.decoder.bind(request).join())
                    as Map<String, dynamic>;
            expect(payload['kind'], 'wireguard_native_v1');
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode(<String, dynamic>{
                'kind': 'wireguard_native_v1',
                'field': 'interface_private_key',
                'public_key': 'public-key',
                'fingerprint': 'sha256:public',
              }),
            );
            await request.response.close();
            return;
          case '/v1/transport-profiles/transport-profile-1':
            expect(request.method, 'DELETE');
            request.response.statusCode = HttpStatus.noContent;
            await request.response.close();
            return;
          case '/v1/transport-profiles/transport-profile-1/validate':
            expect(request.method, 'POST');
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode(_transportProfileStatusPayload()),
            );
            await request.response.close();
            return;
          case '/v1/transport-profiles/transport-profile-1/structured-update':
            expect(request.method, 'POST');
            final payload =
                jsonDecode(await utf8.decoder.bind(request).join())
                    as Map<String, dynamic>;
            final draft = payload['draft'] as Map<String, dynamic>;
            expect(
              (draft['secret_actions']
                  as Map<String, dynamic>)['interface_private_key'],
              'preserve_existing',
            );
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode(<String, dynamic>{
                'profile': _transportProfileStatusPayload(),
              }),
            );
            await request.response.close();
            return;
          case '/v1/transport-profiles/transport-profile-1/select-for-startup':
            expect(request.method, 'POST');
            final payload =
                jsonDecode(await utf8.decoder.bind(request).join())
                    as Map<String, dynamic>;
            final plan = payload['plan'] as Map<String, dynamic>;
            expect(plan['access_method'], 'turn_credentials');
            expect(plan['carrier_family'], 'turn_datagram');
            expect(plan['engine_family'], 'wireguard_native');
            expect(plan['host_adapter'], 'windows_wintun');
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode(_transportProfileStatusPayload(defaultFor: true)),
            );
            await request.response.close();
            return;
          case '/v1/platform-tunnels/stop':
            final payload =
                jsonDecode(await utf8.decoder.bind(request).join())
                    as Map<String, dynamic>;
            expect(payload['mode'], 'windows_wintun');
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode(<String, dynamic>{
                'mode': 'windows_wintun',
                'stopped': true,
                'message': 'Windows Wintun disconnected.',
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
      expect(info.capabilities, contains(Capability.runtimeExecutionPlanning));
      expect(info.capabilities, contains(Capability.vpnTransportProfileStore));
      expect(info.transportProfileStore?.supportedKinds, <TransportProfileKind>[
        TransportProfileKind.wireGuardNativeV1,
        const TransportProfileKind('future_native_v1'),
      ]);
      expect(
        info.transportProfileStore?.importAdapters.last.id,
        const TransportProfileImportAdapter('future_enrollment'),
      );
      expect(
        info.transportProfileStore?.importAdapters.last.profileKind,
        const TransportProfileKind('future_native_v1'),
      );
      expect(
        info.transportProfileStore?.editableKinds.single.schemaVersion,
        'wireguard_native_v1.structured_editor.v1',
      );
      expect(
        info.transportProfileStore?.editableKinds.single.fields.single.id,
        TransportProfileStructuredFieldId.interfacePrivateKey,
      );
      expect(info.platformTunnels, hasLength(1));
      expect(
        info.platformTunnels.single.mode,
        PlatformTunnelMode.windowsWintun,
      );
      expect(
        info.platformTunnels.single.missingPrerequisite,
        PlatformTunnelPrerequisite.hostImplementation,
      );
      expect(info.platformTunnels.single.executionPlans, hasLength(1));
      expect(
        info.platformTunnels.single.executionPlans.single.plan.engineFamily,
        RuntimeEngineFamily.wireguardNative,
      );
      expect(
        info.platformTunnels.single.executionPlans.single.supportState,
        RuntimeExecutionPlanSupportState.unavailable,
      );
      expect(
        info
            .platformTunnels
            .single
            .executionPlans
            .single
            .requiredTransportProfileKinds,
        <TransportProfileKind>[TransportProfileKind.wireGuardNativeV1],
      );
      expect(
        info
            .platformTunnels
            .single
            .executionPlans
            .single
            .transportProfile
            ?.missingKind,
        TransportProfileKind.wireGuardNativeV1,
      );

      final profiles = await client.transportProfiles();
      expect(profiles.single.id, 'transport-profile-1');
      expect(profiles.single.secretMaterialRef.ref, startsWith('host-owned:'));

      final imported = await client.importTransportProfile(
        const TransportProfileImportRequest(
          adapter: TransportProfileImportAdapter.wireGuardConf,
          kind: TransportProfileKind.wireGuardNativeV1,
          material: '[Interface]\nPrivateKey = redacted\n',
        ),
      );
      expect(imported.kind, TransportProfileKind.wireGuardNativeV1);

      final generatedKey = await client.generateTransportProfileKey(
        const TransportProfileGenerateKeyRequest(
          kind: TransportProfileKind.wireGuardNativeV1,
        ),
      );
      expect(generatedKey.publicKey, 'public-key');

      final structuredDraft = TransportProfileStructuredDraft(
        kind: TransportProfileKind.wireGuardNativeV1,
        schemaVersion: 'wireguard_native_v1.structured_editor.v1',
        fields: <TransportProfileStructuredFieldId, Object?>{
          TransportProfileStructuredFieldId.interfaceAddresses: <String>[
            '10.10.0.2/32',
          ],
          TransportProfileStructuredFieldId.peerPublicKey: 'peer-public-key',
          TransportProfileStructuredFieldId.allowedIps: <String>['0.0.0.0/0'],
          TransportProfileStructuredFieldId.endpoint:
              'relay.example.test:51820',
        },
        secretActions:
            <
              TransportProfileStructuredFieldId,
              TransportProfileSecretUpdateAction
            >{
              TransportProfileStructuredFieldId.interfacePrivateKey:
                  TransportProfileSecretUpdateAction.generateHost,
            },
      );
      final structured = await client.createStructuredTransportProfile(
        TransportProfileStructuredCreateRequest(draft: structuredDraft),
      );
      expect(structured.profile.id, 'transport-profile-1');
      expect(structured.generatedKeys.single.publicKey, 'saved-public-key');

      final draftValidation = await client
          .validateStructuredTransportProfileDraft(
            TransportProfileStructuredValidationRequest(
              profileId: 'transport-profile-1',
              draft: structuredDraft,
            ),
          );
      expect(draftValidation.valid, isFalse);
      expect(
        draftValidation.errors.single.field,
        TransportProfileStructuredFieldId.allowedIps,
      );

      final updated = await client.updateStructuredTransportProfile(
        'transport-profile-1',
        TransportProfileStructuredUpdateRequest(
          draft: TransportProfileStructuredDraft(
            kind: TransportProfileKind.wireGuardNativeV1,
            fields: <TransportProfileStructuredFieldId, Object?>{
              TransportProfileStructuredFieldId.interfaceAddresses: <String>[
                '10.10.0.2/32',
              ],
              TransportProfileStructuredFieldId.peerPublicKey:
                  'peer-public-key',
              TransportProfileStructuredFieldId.allowedIps: <String>[
                '0.0.0.0/0',
              ],
              TransportProfileStructuredFieldId.endpoint:
                  'relay.example.test:51820',
            },
            secretActions:
                <
                  TransportProfileStructuredFieldId,
                  TransportProfileSecretUpdateAction
                >{
                  TransportProfileStructuredFieldId.interfacePrivateKey:
                      TransportProfileSecretUpdateAction.preserveExisting,
                },
          ),
        ),
      );
      expect(updated.profile.id, 'transport-profile-1');

      final validated = await client.validateTransportProfile(
        'transport-profile-1',
      );
      expect(validated.validation.state, TransportProfileValidationState.valid);

      final selected = await client.selectTransportProfileForStartup(
        'transport-profile-1',
        const TransportProfileSelectForStartupRequest(
          plan: RuntimeExecutionPlan(
            accessMethod: RuntimeAccessMethod.turnCredentials,
            carrierFamily: RuntimeCarrierFamily.turnDatagram,
            engineFamily: RuntimeEngineFamily.wireguardNative,
            hostAdapter: RuntimeHostAdapter.windowsWintun,
          ),
        ),
      );
      expect(selected.defaultFor.single.profileId, 'transport-profile-1');

      await client.forgetTransportProfile('transport-profile-1');

      final startResult = await client.startPlatformTunnel(
        mode: PlatformTunnelMode.windowsWintun,
        resolutionId: 'resolution-1',
        runtimeDefaults: const RuntimeDefaults(
          listenAddress: '127.0.0.1:7777',
          peerAddress: 'peer.example.test:443',
          turnServer: 'turn.example.test',
          turnPort: '3478',
        ),
        executionPlan: const RuntimeExecutionPlan(
          accessMethod: RuntimeAccessMethod.turnCredentials,
          carrierFamily: RuntimeCarrierFamily.turnDatagram,
          engineFamily: RuntimeEngineFamily.wireguardNative,
          hostAdapter: RuntimeHostAdapter.windowsWintun,
        ),
        transportProfile: const TransportProfileReference(
          profileId: 'transport-profile-1',
          kind: TransportProfileKind.wireGuardNativeV1,
        ),
        underlayRoutePolicy:
            PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork,
      );
      expect(startResult.ready, isFalse);
      expect(startResult.stage, PlatformTunnelStartupStage.profileValidate);
      expect(
        startResult.missingPrerequisite,
        PlatformTunnelPrerequisite.transportProfile,
      );
      expect(startResult.transportProfile?.profileId, 'transport-profile-1');
      expect(
        startResult.executionPlan?.engineFamily,
        RuntimeEngineFamily.wireguardNative,
      );

      final stopResult = await client.stopPlatformTunnel(
        mode: PlatformTunnelMode.windowsWintun,
      );
      expect(stopResult.stopped, isTrue);

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
            'requested_execution_plan': <String, dynamic>{
              'access_method': 'turn_credentials',
              'carrier_family': 'turn_datagram',
              'engine_family': 'wireguard_native',
              'host_adapter': 'windows_wintun',
            },
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
                (ControlPlaneError error) =>
                    error.requestedExecutionPlan?.engineFamily,
                'requestedExecutionPlan.engineFamily',
                RuntimeEngineFamily.wireguardNative,
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
        final observedRequests =
            browserContinuation['observed_requests'] as List<dynamic>? ??
            <dynamic>[];
        expect(observedRequests, hasLength(1));
        expect(
          (observedRequests.single as Map<String, dynamic>)['method'],
          'POST',
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
              'remember_sign_in': true,
              'auto_continue_on_transport_ready': true,
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
          observedRequests: <BrowserObservedRequestRecord>[
            BrowserObservedRequestRecord(
              method: 'POST',
              url: 'https://api.vk.com/method/calls.getCallPreview?v=5.275',
              formValues: <String, String>{'method': 'calls.getCallPreview'},
              statusCode: 200,
              body: <String, dynamic>{
                'response': <String, dynamic>{'call': 'preview'},
              },
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
      expect(challenge.ownedBrowser?.rememberSignIn, isTrue);
      expect(challenge.ownedBrowser?.autoContinueOnTransportReady, isTrue);
    },
  );

  test(
    'control plane client sends Android app scope and resumes startup',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((HttpRequest request) async {
        request.response.headers.contentType = ContentType.json;
        switch (request.uri.path) {
          case '/v1/platform-tunnels/start':
            final payload =
                jsonDecode(await utf8.decoder.bind(request).join())
                    as Map<String, dynamic>;
            expect(payload['mode'], 'android_vpn_service');
            expect(payload['resolution_id'], 'resolution-android-1');
            final runtimeDefaults =
                payload['runtime_defaults'] as Map<String, dynamic>;
            expect(runtimeDefaults['listen_addr'], '127.0.0.1:7777');
            expect(runtimeDefaults['peer_addr'], 'relay.example.test:3478');
            expect(runtimeDefaults['turn_server'], 'turn.example.test');
            expect(runtimeDefaults['turn_port'], '3478');
            expect(payload['application_routing_policy'], 'allowed_packages');
            expect(
              payload['underlay_route_policy'],
              'preserve_active_local_network',
            );
            expect(payload['allowed_packages'], <dynamic>[
              'com.example.youtube',
            ]);
            request.response.write(
              jsonEncode(<String, dynamic>{
                'mode': 'android_vpn_service',
                'ready': false,
                'stage': 'permission_acquire',
                'missing_prerequisite': 'permission',
                'startup_attempt_id': 'attempt-android-1',
                'underlay_route_policy': 'preserve_active_local_network',
                'message': 'permission required',
              }),
            );
            await request.response.close();
            return;
          case '/v1/platform-tunnels/resume':
            final payload =
                jsonDecode(await utf8.decoder.bind(request).join())
                    as Map<String, dynamic>;
            expect(payload['startup_attempt_id'], 'attempt-android-1');
            request.response.write(
              jsonEncode(<String, dynamic>{
                'mode': 'android_vpn_service',
                'ready': true,
                'session_id': 'session-android-1',
              }),
            );
            await request.response.close();
            return;
          default:
            request.response.statusCode = HttpStatus.notFound;
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

      final startResult = await client.startPlatformTunnel(
        mode: PlatformTunnelMode.androidVpnService,
        resolutionId: 'resolution-android-1',
        runtimeDefaults: const RuntimeDefaults(
          listenAddress: '127.0.0.1:7777',
          peerAddress: 'relay.example.test:3478',
          turnServer: 'turn.example.test',
          turnPort: '3478',
        ),
        applicationRoutingPolicy:
            PlatformTunnelApplicationRoutingPolicy.allowedPackages,
        allowedPackages: const <String>['com.example.youtube'],
        underlayRoutePolicy:
            PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork,
      );
      expect(startResult.ready, isFalse);
      expect(startResult.stage, PlatformTunnelStartupStage.permissionAcquire);
      expect(
        startResult.missingPrerequisite,
        PlatformTunnelPrerequisite.permission,
      );
      expect(startResult.startupAttemptId, 'attempt-android-1');
      expect(
        startResult.underlayRoutePolicy,
        PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork,
      );

      final resumeResult = await client.resumePlatformTunnel(
        startupAttemptId: startResult.startupAttemptId,
      );
      expect(resumeResult.ready, isTrue);
      expect(resumeResult.sessionId, 'session-android-1');
      expect(resumeResult.startupAttemptId, isEmpty);
    },
  );

  test(
    'control plane client accepts ready platform tunnel results without session_id for mixed-version hosts',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((HttpRequest request) async {
        request.response.headers.contentType = ContentType.json;
        switch (request.uri.path) {
          case '/v1/platform-tunnels/start':
            request.response.write(
              jsonEncode(<String, dynamic>{
                'mode': 'android_vpn_service',
                'ready': true,
              }),
            );
            await request.response.close();
            return;
          default:
            request.response.statusCode = HttpStatus.notFound;
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

      final startResult = await client.startPlatformTunnel(
        mode: PlatformTunnelMode.androidVpnService,
        resolutionId: 'resolution-android-1',
        runtimeDefaults: const RuntimeDefaults(
          listenAddress: '127.0.0.1:7777',
          peerAddress: 'relay.example.test:3478',
          turnServer: 'turn.example.test',
          turnPort: '3478',
        ),
      );
      expect(startResult.ready, isTrue);
      expect(startResult.sessionId, isEmpty);
      expect(startResult.startupAttemptId, isEmpty);
    },
  );
}

Map<String, dynamic> _transportProfileStatusPayload({bool defaultFor = false}) {
  final payload = <String, dynamic>{
    'id': 'transport-profile-1',
    'kind': 'wireguard_native_v1',
    'version': '1',
    'display_name': 'WireGuard',
    'validation': <String, dynamic>{
      'state': 'valid',
      'fingerprint': 'sha256:testprofile',
    },
    'compatibility': <String, dynamic>{
      'state': 'compatible',
      'compatible_execution_plans': <Map<String, dynamic>>[
        <String, dynamic>{
          'access_method': 'turn_credentials',
          'carrier_family': 'turn_datagram',
          'engine_family': 'wireguard_native',
          'host_adapter': 'windows_wintun',
        },
      ],
    },
    'secret_material_ref': <String, dynamic>{
      'kind': 'import_adapter',
      'ref': 'host-owned:transport-profile-1',
    },
    'actions': <String>['replace', 'forget', 'validate', 'select_for_startup'],
    'imported_at': DateTime.utc(2026, 4, 28, 12).toIso8601String(),
    'updated_at': DateTime.utc(2026, 4, 28, 12).toIso8601String(),
  };
  if (defaultFor) {
    payload['default_for'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'profile_id': 'transport-profile-1',
        'kind': 'wireguard_native_v1',
        'host_adapter': 'windows_wintun',
        'plan': <String, dynamic>{
          'access_method': 'turn_credentials',
          'carrier_family': 'turn_datagram',
          'engine_family': 'wireguard_native',
          'host_adapter': 'windows_wintun',
        },
        'scope_id':
            'windows_wintun|turn_credentials|turn_datagram|wireguard_native',
      },
    ];
  }
  return payload;
}
