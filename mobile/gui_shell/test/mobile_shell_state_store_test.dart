import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_state_store.dart';
import 'package:mobile_gui_shell/src/control/profile_draft.dart';

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
    'mobile state store keeps provider links out of persisted preferences and secure storage',
    () async {
      final preferences = _MemoryBlobStore();
      final secrets = _MemoryBlobStore();
      final store = SecureMobileShellStateStore(
        preferences: preferences,
        secrets: secrets,
      );

      final state = MobileShellState(
        profiles: <ProfileRecord>[
          ProfileRecord(
            id: 'profile-1',
            name: 'vk live',
            spec: const ProfileSpec(
              provider: 'wb-stream',
              link: 'https://vk.com/call/join/secret',
              providerSettings: <String, dynamic>{
                'region': 'eu-west',
                'device_alias': '123-invalid',
                'device_pin': '123456',
              },
              listenAddress: '127.0.0.1:9006',
              peerAddress: '176.109.104.105:38218',
              turnServer: '155.212.199.161',
              turnPort: '19302',
              interactiveProvider: true,
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
        selectedProfileId: 'profile-1',
        draft: const ProfileDraft(
          id: 'draft-1',
          name: 'draft',
          spec: ProfileSpec(
            provider: 'wb-stream',
            link: 'generic-turn://user:pass@turn.example.test:3478',
            providerSettings: <String, dynamic>{
              'region': 'ru-central',
              'device_alias': '456-invalid',
              'device_pin': '654321',
            },
            listenAddress: '127.0.0.1:9007',
            peerAddress: '176.109.104.105:38218',
            turnServer: 'turn.example.test',
            turnPort: '3478',
          ),
        ),
      );

      await store.save(state.sanitizedForPersistence(providerDescriptors));

      final preferencesPayload = preferences.values.values.single;

      expect(
        preferencesPayload,
        isNot(contains('https://vk.com/call/join/secret')),
      );
      expect(preferencesPayload, contains('turn.example.test'));
      expect(preferencesPayload, contains('176.109.104.105:38218'));

      expect(secrets.values, isEmpty);

      final restored = await store.load();
      expect(restored, isNotNull);
      expect(restored!.profiles.single.spec.link, '');
      expect(restored.profiles.single.spec.providerSettings, <String, dynamic>{
        'region': 'eu-west',
      });
      expect(restored.profiles.single.spec.turnServer, '155.212.199.161');
      expect(restored.profiles.single.spec.turnPort, '19302');
      expect(restored.providerConfigs, hasLength(1));
      expect(
        restored.providerConfigs.single.providerSettings,
        <String, dynamic>{
          'region': 'eu-west',
          'device_alias': 'trusted-device',
        },
      );
      expect(restored.draft.spec.link, '');
      expect(restored.draft.spec.providerSettings, <String, dynamic>{
        'region': 'ru-central',
      });
      expect(restored.draft.spec.turnServer, 'turn.example.test');
      expect(restored.draft.spec.turnPort, '3478');

      final sanitizedJson =
          jsonDecode(preferencesPayload) as Map<String, dynamic>;
      final profileJson =
          (sanitizedJson['profiles'] as List<dynamic>).single
              as Map<String, dynamic>;
      final providerConfigJson =
          (sanitizedJson['provider_configs'] as List<dynamic>).single
              as Map<String, dynamic>;
      final draftJson = sanitizedJson['draft'] as Map<String, dynamic>;
      expect((profileJson['spec'] as Map<String, dynamic>)['link'], '');
      expect(
        (profileJson['spec'] as Map<String, dynamic>)['provider_settings'],
        <String, dynamic>{'region': 'eu-west'},
      );
      expect((draftJson['spec'] as Map<String, dynamic>)['link'], '');
      expect(
        (draftJson['spec'] as Map<String, dynamic>)['provider_settings'],
        <String, dynamic>{'region': 'ru-central'},
      );
      expect(providerConfigJson['provider_settings'], <String, dynamic>{
        'region': 'eu-west',
        'device_alias': 'trusted-device',
      });
    },
  );

  test(
    'secure mobile state store fails closed when secrets are missing during restore',
    () async {
      final preferences = _MemoryBlobStore();
      final secrets = _MemoryBlobStore();
      final store = SecureMobileShellStateStore(
        preferences: preferences,
        secrets: secrets,
      );

      await preferences.write(
        'mobile_gui_shell_state_v1',
        const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
          'profiles': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'profile-1',
              'name': 'vk live',
              'spec': <String, dynamic>{
                'provider': 'vk',
                'link': '',
                'listen_addr': '127.0.0.1:9006',
                'peer_addr': '176.109.104.105:38218',
              },
            },
          ],
          'selected_profile_id': 'profile-1',
          'draft': <String, dynamic>{
            'name': '',
            'spec': <String, dynamic>{
              'provider': 'vk',
              'link': '',
              'listen_addr': '127.0.0.1:9006',
              'peer_addr': '176.109.104.105:38218',
            },
          },
          'secret_manifest': <String, dynamic>{
            'profile_ids': <String>['profile-1'],
            'has_draft': false,
          },
        }),
      );

      await expectLater(
        store.load(),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            contains('Secure profile secrets are unavailable'),
          ),
        ),
      );
    },
  );
}

class _MemoryBlobStore implements StringBlobStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
