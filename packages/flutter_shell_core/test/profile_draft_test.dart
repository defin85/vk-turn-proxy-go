import 'package:flutter_shell_core/control_plane_models.dart';
import 'package:flutter_shell_core/profile_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ProfileDraft.copyWith can clear an existing id', () {
    const original = ProfileDraft(
      id: 'profile-1',
      name: 'Alpha',
      spec: ProfileSpec(
        provider: 'vk',
        link: 'https://vk.com/call/join/alpha',
        listenAddress: '127.0.0.1:9001',
        peerAddress: '127.0.0.1:56000',
      ),
    );

    final duplicated = original.copyWith(
      id: null,
      replaceId: true,
      name: 'Alpha copy',
    );

    expect(duplicated.id, isNull);
    expect(duplicated.name, 'Alpha copy');
    expect(duplicated.spec.link, original.spec.link);
  });

  test('ManagedProviderDraft.copyWith can clear persisted identity fields', () {
    final original = ManagedProviderDraft(
      id: 'provider-config-1',
      provider: 'vk',
      name: 'VK Saved',
      providerSettings: const <String, dynamic>{'region': 'eu-west'},
      createdAt: DateTime.utc(2026, 4, 17, 12, 0),
      updatedAt: DateTime.utc(2026, 4, 17, 12, 1),
    );

    final duplicated = original.copyWith(
      id: null,
      replaceId: true,
      name: 'VK Saved copy',
      createdAt: null,
      replaceCreatedAt: true,
      updatedAt: null,
      replaceUpdatedAt: true,
    );

    expect(duplicated.id, isNull);
    expect(duplicated.name, 'VK Saved copy');
    expect(duplicated.createdAt, isNull);
    expect(duplicated.updatedAt, isNull);
    expect(duplicated.providerSettings, original.providerSettings);
  });

  test(
    'ProviderTemplateDraft.copyWith can clear persisted identity fields',
    () {
      final original = ProviderTemplateDraft(
        id: 'template-1',
        provider: 'vk',
        name: 'VK Template',
        providerSettings: const <String, dynamic>{'region': 'eu-west'},
        createdAt: DateTime.utc(2026, 4, 17, 12, 0),
        updatedAt: DateTime.utc(2026, 4, 17, 12, 1),
      );

      final duplicated = original.copyWith(
        id: null,
        replaceId: true,
        name: 'VK Template copy',
        createdAt: null,
        replaceCreatedAt: true,
        updatedAt: null,
        replaceUpdatedAt: true,
      );

      expect(duplicated.id, isNull);
      expect(duplicated.name, 'VK Template copy');
      expect(duplicated.createdAt, isNull);
      expect(duplicated.updatedAt, isNull);
      expect(duplicated.providerSettings, original.providerSettings);
    },
  );
}
