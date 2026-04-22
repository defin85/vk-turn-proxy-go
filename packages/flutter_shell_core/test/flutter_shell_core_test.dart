import 'package:flutter/material.dart';
import 'package:flutter_shell_core/flutter_shell_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workspace scaffold package exports shared shell leaf modules', () {
    expect(kFlutterShellCorePackage, 'flutter_shell_core');
    expect(ControlPlaneClient.contractVersion, '1');
    expect(ProfileDraft.defaults().spec.listenAddress, '127.0.0.1:9001');
    expect(BuildIdentityEnvironment.revision, 'dev');
    expect(BuildIdentityEnvironment.dirty, isTrue);
  });

  test('shared shell visuals keep the approved mobile reference palette', () {
    final theme = buildRelayDockShellTheme();
    final visuals = theme.extension<ShellVisualTheme>();

    expect(theme.colorScheme.primary, const Color(0xFF214B66));
    expect(theme.colorScheme.secondary, const Color(0xFFB36A37));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFEEE7DA));
    expect(visuals, isNotNull);
    expect(
      visuals!.tone(ShellSemanticTone.ready).container,
      const Color(0xFFE2F4E8),
    );
    expect(
      visuals.tone(ShellSemanticTone.danger).accent,
      const Color(0xFFB3261E),
    );
  });

  test('profile draft round-trips through profile records', () {
    const profile = ProfileRecord(
      id: 'profile-1',
      name: '  VK Main  ',
      spec: ProfileSpec(
        provider: 'vk',
        link: 'https://vk.com/call/join/test',
        listenAddress: '127.0.0.1:9001',
        peerAddress: '127.0.0.1:56000',
        mode: TransportMode.udp,
        useDtls: true,
        interactiveProvider: true,
        providerSettings: <String, dynamic>{'region': 'eu-west'},
      ),
    );

    final draft = ProfileDraft.fromProfile(profile);
    final restored = ProfileDraft.fromJson(draft.toJson());
    final persistedProfile = restored.toProfile();

    expect(restored.id, 'profile-1');
    expect(restored.name, '  VK Main  ');
    expect(restored.spec.provider, 'vk');
    expect(restored.spec.providerSettings, <String, dynamic>{
      'region': 'eu-west',
    });
    expect(persistedProfile.id, 'profile-1');
    expect(persistedProfile.name, 'VK Main');
    expect(persistedProfile.spec.interactiveProvider, isTrue);
  });

  test(
    'provider descriptor normalizes defaults and keeps only profile-retained settings',
    () {
      const descriptor = ProviderDescriptor(
        id: 'wb-stream',
        displayName: 'Wideband stream',
        inputKind: ProviderInputKind.link,
        authPosture: ProviderAuthPosture.staticSecret,
        browserPolicy: ProviderBrowserPolicy.notRequired,
        settingsSchema: ProviderSettingsSchema(
          type: 'object',
          additionalProperties: false,
          properties: <String, ProviderSettingProperty>{
            'region': ProviderSettingProperty(
              type: ProviderSettingType.string,
              control: ProviderSettingControl.text,
              defaultValue: 'us-east',
              persistence: ProviderSettingPersistence.profile,
            ),
            'device_pin': ProviderSettingProperty(
              type: ProviderSettingType.string,
              control: ProviderSettingControl.password,
              writeOnly: true,
              persistence: ProviderSettingPersistence.ephemeral,
            ),
            'max_peers': ProviderSettingProperty(
              type: ProviderSettingType.integer,
              control: ProviderSettingControl.text,
              defaultValue: 2,
              persistence: ProviderSettingPersistence.ephemeral,
            ),
          },
          order: <String>['region', 'device_pin', 'max_peers'],
        ),
      );

      final normalized = descriptor.normalizeProviderSettings(
        const <String, dynamic>{'region': 'eu-west', 'device_pin': '123456'},
      );

      expect(normalized, <String, dynamic>{
        'region': 'eu-west',
        'device_pin': '123456',
        'max_peers': 2,
      });
      expect(
        descriptor.profileRetainedProviderSettings(normalized),
        <String, dynamic>{'region': 'eu-west'},
      );
    },
  );

  test('provider config records and drafts round-trip through json', () {
    final createdAt = DateTime.utc(2026, 4, 13, 10, 15);
    final updatedAt = DateTime.utc(2026, 4, 13, 10, 16);
    final record = ProviderConfigRecord(
      id: 'cfg-1',
      provider: 'wb-stream',
      name: 'WB EU guest',
      providerSettings: const <String, dynamic>{
        'region': 'eu-west',
        'device_index': 2,
      },
      createdAt: createdAt,
      updatedAt: updatedAt,
      availability: const ProviderConfigAvailability(),
    );

    final restored = ProviderConfigRecord.fromJson(record.toJson());
    final draft = ProviderConfigDraft.fromRecord(restored);
    final roundTrip = ProviderConfigDraft.fromJson(draft.toJson()).toRecord();

    expect(restored.id, 'cfg-1');
    expect(restored.provider, 'wb-stream');
    expect(restored.providerSettings['device_index'], 2);
    expect(draft.name, 'WB EU guest');
    expect(roundTrip.id, 'cfg-1');
    expect(roundTrip.createdAt.toUtc(), createdAt);
    expect(roundTrip.updatedAt.toUtc(), updatedAt);
  });

  test(
    'managed provider drafts and profile bindings round-trip through json',
    () {
      final createdAt = DateTime.utc(2026, 4, 13, 10, 15);
      final updatedAt = DateTime.utc(2026, 4, 13, 10, 16);
      const binding = ProfileProviderBinding(
        mode: ProfileProviderMode.managed,
        managedProviderId: 'managed-1',
      );
      final record = ManagedProviderRecord(
        id: 'managed-1',
        provider: 'vk',
        name: 'VK Calls',
        providerSettings: const <String, dynamic>{'region': 'eu-west'},
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final restoredRecord = ManagedProviderRecord.fromJson(record.toJson());
      final restoredDraft = ManagedProviderDraft.fromJson(
        ManagedProviderDraft.fromRecord(restoredRecord).toJson(),
      );
      final restoredBinding = ProfileProviderBinding.fromJson(binding.toJson());

      expect(restoredRecord.id, 'managed-1');
      expect(restoredRecord.provider, 'vk');
      expect(restoredRecord.providerSettings['region'], 'eu-west');
      expect(restoredDraft.id, 'managed-1');
      expect(restoredDraft.provider, 'vk');
      expect(restoredDraft.updatedAt?.toUtc(), updatedAt);
      expect(restoredBinding.isManaged, isTrue);
      expect(restoredBinding.managedProviderId, 'managed-1');
    },
  );

  test('provider templates round-trip through json and seed drafts', () {
    final createdAt = DateTime.utc(2026, 4, 13, 10, 20);
    final updatedAt = DateTime.utc(2026, 4, 13, 10, 21);
    final record = ProviderTemplateRecord(
      id: 'template-1',
      provider: 'vk',
      name: 'VK Guest Bootstrap',
      providerSettings: const <String, dynamic>{'region': 'eu-west'},
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final restoredRecord = ProviderTemplateRecord.fromJson(record.toJson());
    final restoredDraft = ProviderTemplateDraft.fromJson(
      ProviderTemplateDraft.fromRecord(restoredRecord).toJson(),
    );
    final seededProviderDraft = ManagedProviderDraft.fromTemplateRecord(
      restoredRecord,
    );

    expect(restoredRecord.id, 'template-1');
    expect(restoredRecord.providerSettings['region'], 'eu-west');
    expect(restoredDraft.id, 'template-1');
    expect(restoredDraft.updatedAt?.toUtc(), updatedAt);
    expect(seededProviderDraft.provider, 'vk');
    expect(seededProviderDraft.name, 'VK Guest Bootstrap');
    expect(seededProviderDraft.providerSettings['region'], 'eu-west');
  });

  test('profile draft bootstrap applies provider configs snapshot-style', () {
    final draft = ProfileDraft.defaults().copyWith(
      name: 'Current profile',
      spec: ProfileDraft.defaults().spec.copyWith(
        provider: 'vk',
        link: 'https://vk.com/call/join/test',
      ),
    );
    final config = ProviderConfigRecord(
      id: 'cfg-1',
      provider: 'wb-stream',
      name: 'WB EU guest',
      providerSettings: const <String, dynamic>{'region': 'eu-west'},
      createdAt: DateTime.utc(2026, 4, 13, 10, 15),
      updatedAt: DateTime.utc(2026, 4, 13, 10, 16),
    );

    final applied = draft.applyProviderConfig(config);

    expect(applied.name, 'Current profile');
    expect(applied.spec.provider, 'wb-stream');
    expect(applied.spec.link, isEmpty);
    expect(applied.spec.providerSettings, const <String, dynamic>{
      'region': 'eu-west',
    });
  });

  test('preset catalog gates availability on provider descriptors', () {
    const descriptors = <ProviderDescriptor>[
      ProviderDescriptor(
        id: 'vk',
        displayName: 'VK Calls',
        inputKind: ProviderInputKind.link,
        authPosture: ProviderAuthPosture.guestOrAccount,
        browserPolicy: ProviderBrowserPolicy.externalRequired,
      ),
    ];

    final vkPreset = kProviderPresetCatalog.firstWhere(
      (ProviderPreset preset) => preset.id == 'vk-default',
    );
    final genericTurnPreset = kProviderPresetCatalog.firstWhere(
      (ProviderPreset preset) => preset.id == 'generic-turn-default',
    );

    final available = vkPreset.availabilityFor(descriptors);
    final unavailable = genericTurnPreset.availabilityFor(descriptors);
    final seeded = ManagedProviderDraft.fromPreset(
      vkPreset,
      descriptor: descriptors.single,
    );

    expect(available.isAvailable, isTrue);
    expect(available.descriptor?.id, 'vk');
    expect(unavailable.isAvailable, isFalse);
    expect(unavailable.message, contains('Generic TURN'));
    expect(seeded.name, 'VK Calls');
    expect(seeded.provider, 'vk');
  });

  test('build identity keeps shared labels and round-trips through json', () {
    const build = BuildIdentity(
      product: 'RelayDock',
      version: '0.1.0',
      buildNumber: '7',
      revision: 'deadbeef',
      dirty: true,
      builtAt: '2026-04-12T09:30:00Z',
      role: 'clientd',
      target: 'linux/amd64',
    );

    final restored = BuildIdentity.fromJson(build.toJson());

    expect(build.versionLabel, '0.1.0+7');
    expect(build.shortLabel, '0.1.0+7 @deadbeef*');
    expect(restored.product, 'RelayDock');
    expect(restored.role, 'clientd');
    expect(restored.target, 'linux/amd64');
    expect(restored.builtAt, '2026-04-12T09:30:00Z');
  });

  test('runtime execution plans round-trip through json', () {
    const plan = RuntimeExecutionPlan(
      accessMethod: RuntimeAccessMethod.turnCredentials,
      carrierFamily: RuntimeCarrierFamily.turnDtlsOverlay,
      engineFamily: RuntimeEngineFamily.wireguardNative,
      hostAdapter: RuntimeHostAdapter.windowsWintun,
    );

    final restored = RuntimeExecutionPlan.fromJson(plan.toJson());

    expect(restored.accessMethod, RuntimeAccessMethod.turnCredentials);
    expect(restored.carrierFamily, RuntimeCarrierFamily.turnDtlsOverlay);
    expect(restored.engineFamily, RuntimeEngineFamily.wireguardNative);
    expect(restored.hostAdapter, RuntimeHostAdapter.windowsWintun);
  });

  test('runtime execution plans omit host adapter when absent', () {
    const plan = RuntimeExecutionPlan(
      accessMethod: RuntimeAccessMethod.webrtcCallAttach,
      carrierFamily: RuntimeCarrierFamily.webrtcDataChannel,
      engineFamily: RuntimeEngineFamily.proxyCoreAdapter,
    );

    expect(plan.toJson().containsKey('host_adapter'), isFalse);
  });

  test(
    'runtime execution plan descriptors and artifact access methods parse',
    () {
      final artifact = ResolutionArtifactRecord.fromJson(<String, dynamic>{
        'family': 'generic_turn',
        'access_methods': <String>['turn_credentials'],
        'actions': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'start_on_this_device',
            'execution_owner': 'host',
            'execution_plans': <Map<String, dynamic>>[
              <String, dynamic>{
                'plan': <String, dynamic>{
                  'access_method': 'turn_credentials',
                  'carrier_family': 'turn_dtls_overlay',
                  'engine_family': 'custom_packet_overlay',
                },
                'support_state': 'supported',
                'remote_endpoint_family': 'turn_server',
                'default': true,
              },
              <String, dynamic>{
                'plan': <String, dynamic>{
                  'access_method': 'turn_credentials',
                  'carrier_family': 'turn_datagram',
                  'engine_family': 'wireguard_native',
                  'host_adapter': 'windows_wintun',
                },
                'support_state': 'unavailable',
                'remote_endpoint_family': 'turn_server',
                'message': 'packaged host missing tunnel implementation',
              },
            ],
          },
        ],
      });

      expect(artifact.accessMethods, const <RuntimeAccessMethod>[
        RuntimeAccessMethod.turnCredentials,
      ]);
      expect(
        artifact.executionPlansForAction(ArtifactAction.startOnThisDevice),
        hasLength(2),
      );
      expect(
        artifact
            .executionPlansForAction(ArtifactAction.startOnThisDevice)
            .first
            .isSelectable,
        isTrue,
      );
      expect(
        artifact
            .executionPlansForAction(ArtifactAction.startOnThisDevice)
            .last
            .plan
            .engineFamily,
        RuntimeEngineFamily.wireguardNative,
      );
    },
  );
}
