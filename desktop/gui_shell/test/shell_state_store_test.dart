import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/profile_draft.dart';
import 'package:gui_shell/src/control/shell_state_store.dart';

void main() {
  test(
    'desktop state store redacts generic-turn links from persisted plaintext state',
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
              provider: 'vk',
              link: 'https://vk.com/call/join/test-token',
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
        selectedProfileId: 'profile-2',
        draft: const ProfileDraft(
          id: 'draft-1',
          name: 'draft',
          spec: ProfileSpec(
            provider: 'generic-turn',
            link: 'generic-turn://draft-user:draft-pass@turn.example.test:3478',
            listenAddress: '127.0.0.1:9001',
            peerAddress: '127.0.0.1:56000',
          ),
        ),
      );

      await store.save(state);

      final payload = await file.readAsString();
      expect(payload, contains('https://vk.com/call/join/test-token'));
      expect(
        payload,
        isNot(contains('generic-turn://turn-user:turn-pass@turn.example.test:3478')),
      );
      expect(
        payload,
        isNot(contains('generic-turn://draft-user:draft-pass@turn.example.test:3478')),
      );

      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final profiles = decoded['profiles'] as List<dynamic>;
      expect(
        (profiles[0] as Map<String, dynamic>)['spec']['link'],
        'https://vk.com/call/join/test-token',
      );
      expect((profiles[1] as Map<String, dynamic>)['spec']['link'], '');
      expect((decoded['draft'] as Map<String, dynamic>)['spec']['link'], '');
    },
  );
}
