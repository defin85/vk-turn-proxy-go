import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_state_store.dart';
import 'package:mobile_gui_shell/src/control/profile_draft.dart';

void main() {
  test(
    'secure mobile state store keeps secrets out of shared preferences',
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
              provider: 'vk',
              link: 'https://vk.com/call/join/secret',
              listenAddress: '127.0.0.1:9006',
              peerAddress: '176.109.104.105:38218',
              turnServer: '155.212.199.161',
              turnPort: '19302',
              interactiveProvider: true,
            ),
          ),
        ],
        selectedProfileId: 'profile-1',
        draft: const ProfileDraft(
          id: 'draft-1',
          name: 'draft',
          spec: ProfileSpec(
            provider: 'generic-turn',
            link: 'generic-turn://user:pass@turn.example.test:3478',
            listenAddress: '127.0.0.1:9007',
            peerAddress: '176.109.104.105:38218',
            turnServer: 'turn.example.test',
            turnPort: '3478',
          ),
        ),
      );

      await store.save(state);

      final preferencesPayload = preferences.values.values.single;
      final secretsPayload = secrets.values.values.single;

      expect(
        preferencesPayload,
        isNot(contains('https://vk.com/call/join/secret')),
      );
      expect(preferencesPayload, isNot(contains('turn.example.test')));
      expect(preferencesPayload, contains('176.109.104.105:38218'));

      expect(secretsPayload, contains('https://vk.com/call/join/secret'));
      expect(secretsPayload, contains('turn.example.test'));
      expect(secretsPayload, isNot(contains('176.109.104.105:38218')));

      final restored = await store.load();
      expect(restored, isNotNull);
      expect(
        restored!.profiles.single.spec.link,
        'https://vk.com/call/join/secret',
      );
      expect(restored.profiles.single.spec.turnServer, '155.212.199.161');
      expect(restored.profiles.single.spec.turnPort, '19302');
      expect(
        restored.draft.spec.link,
        'generic-turn://user:pass@turn.example.test:3478',
      );
      expect(restored.draft.spec.turnServer, 'turn.example.test');
      expect(restored.draft.spec.turnPort, '3478');

      final sanitizedJson =
          jsonDecode(preferencesPayload) as Map<String, dynamic>;
      final profileJson =
          (sanitizedJson['profiles'] as List<dynamic>).single
              as Map<String, dynamic>;
      final draftJson = sanitizedJson['draft'] as Map<String, dynamic>;
      expect((profileJson['spec'] as Map<String, dynamic>)['link'], '');
      expect((draftJson['spec'] as Map<String, dynamic>)['link'], '');
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
