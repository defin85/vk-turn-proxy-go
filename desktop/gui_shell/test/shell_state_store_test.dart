import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/profile_draft.dart';
import 'package:gui_shell/src/control/shell_state_store.dart';

void main() {
  const providerDescriptors = <ProviderDescriptor>[
    ProviderDescriptor(
      id: 'wb-stream',
      displayName: 'WB Stream',
      inputKind: ProviderInputKind.link,
      authPosture: ProviderAuthPosture.account,
      browserPolicy: ProviderBrowserPolicy.notRequired,
      settingsSchema: ProviderSettingsSchema(
        type: 'object',
        additionalProperties: false,
        properties: <String, ProviderSettingProperty>{
          'region': ProviderSettingProperty(
            type: ProviderSettingType.string,
            control: ProviderSettingControl.select,
            persistence: ProviderSettingPersistence.profile,
            enumValues: <dynamic>['ru-central', 'eu-west'],
          ),
          'device_alias': ProviderSettingProperty(
            type: ProviderSettingType.string,
            control: ProviderSettingControl.text,
            persistence: ProviderSettingPersistence.profile,
            pattern: r'^[a-z]+$',
          ),
          'device_pin': ProviderSettingProperty(
            type: ProviderSettingType.string,
            writeOnly: true,
            control: ProviderSettingControl.password,
            persistence: ProviderSettingPersistence.ephemeral,
          ),
        },
      ),
    ),
  ];

  test(
    'desktop state store redacts provider links from persisted plaintext state',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'desktop-shell-state-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/gui-shell-state.json');
      final store = FileDesktopShellStateStore(fileProvider: () async => file);

      final state = DesktopShellState(
        profiles: <ProfileRecord>[
          ProfileRecord(
            id: 'profile-1',
            name: 'vk invite',
            spec: const ProfileSpec(
              provider: 'wb-stream',
              link: 'https://vk.com/call/join/test-token',
              providerSettings: <String, dynamic>{
                'region': 'eu-west',
                'device_alias': '123-invalid',
                'device_pin': '123456',
              },
              listenAddress: '127.0.0.1:9001',
              peerAddress: '127.0.0.1:56000',
            ),
          ),
          ProfileRecord(
            id: 'profile-2',
            name: 'handoff',
            spec: const ProfileSpec(
              provider: 'generic-turn',
              link: 'generic-turn://turn-user:turn-pass@turn.example.test:3478',
              listenAddress: '127.0.0.1:9001',
              peerAddress: '127.0.0.1:56000',
            ),
          ),
        ],
        providerConfigs: <ProviderConfigRecord>[
          ProviderConfigRecord(
            id: 'provider-config-1',
            provider: 'wb-stream',
            name: 'WB Central',
            providerSettings: const <String, dynamic>{
              'region': 'eu-west',
              'device_alias': 'trusted-device',
            },
            createdAt: DateTime.utc(2026, 4, 12, 10, 0),
            updatedAt: DateTime.utc(2026, 4, 12, 10, 5),
          ),
        ],
        selectedProfileId: 'profile-2',
        draft: const ProfileDraft(
          id: 'draft-1',
          name: 'draft',
          spec: ProfileSpec(
            provider: 'wb-stream',
            link: 'generic-turn://draft-user:draft-pass@turn.example.test:3478',
            providerSettings: <String, dynamic>{
              'region': 'ru-central',
              'device_alias': '456-invalid',
              'device_pin': '654321',
            },
            listenAddress: '127.0.0.1:9001',
            peerAddress: '127.0.0.1:56000',
          ),
        ),
        runtimeDefaults: const RuntimeDefaults(
          listenAddress: '127.0.0.1:9101',
          peerAddress: '127.0.0.1:56100',
          turnServer: 'override.example.test',
          turnPort: '5349',
          bindInterface: '127.0.0.1',
          mode: TransportMode.tcp,
          useDtls: false,
          logLevel: 'debug',
        ),
      );

      await store.save(state.sanitizedForPersistence(providerDescriptors));

      final payload = await file.readAsString();
      expect(payload, isNot(contains('https://vk.com/call/join/test-token')));
      expect(
        payload,
        isNot(
          contains('generic-turn://turn-user:turn-pass@turn.example.test:3478'),
        ),
      );
      expect(
        payload,
        isNot(
          contains(
            'generic-turn://draft-user:draft-pass@turn.example.test:3478',
          ),
        ),
      );

      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final profiles = decoded['profiles'] as List<dynamic>;
      final providerConfigs = decoded['provider_configs'] as List<dynamic>;
      final runtimeDefaults =
          decoded['runtime_defaults'] as Map<String, dynamic>;
      expect((profiles[0] as Map<String, dynamic>)['spec']['link'], '');
      expect(
        (profiles[0] as Map<String, dynamic>)['spec']['provider_settings'],
        <String, dynamic>{'region': 'eu-west'},
      );
      expect((profiles[1] as Map<String, dynamic>)['spec']['link'], '');
      expect((decoded['draft'] as Map<String, dynamic>)['spec']['link'], '');
      expect(
        (decoded['draft'] as Map<String, dynamic>)['spec']['provider_settings'],
        <String, dynamic>{'region': 'ru-central'},
      );
      expect(providerConfigs, hasLength(1));
      expect(
        (providerConfigs.single as Map<String, dynamic>)['provider_settings'],
        <String, dynamic>{
          'region': 'eu-west',
          'device_alias': 'trusted-device',
        },
      );
      expect(runtimeDefaults['listen_addr'], '127.0.0.1:9101');
      expect(runtimeDefaults['peer_addr'], '127.0.0.1:56100');
      expect(runtimeDefaults['turn_server'], 'override.example.test');
      expect(runtimeDefaults['turn_port'], '5349');
      expect(runtimeDefaults['bind_interface'], '127.0.0.1');
      expect(runtimeDefaults['mode'], 'tcp');
      expect(runtimeDefaults['use_dtls'], isFalse);
      expect(runtimeDefaults['log_level'], 'debug');
    },
  );
}
