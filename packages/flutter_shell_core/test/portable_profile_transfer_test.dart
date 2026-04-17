import 'dart:convert';

import 'package:flutter_shell_core/flutter_shell_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('portable profile envelope round-trips custom profiles', () {
    final profile = _profileRecord(
      id: 'profile-custom-1',
      name: 'Portable custom profile',
      provider: 'vk',
      link: '',
      providerSettings: const <String, dynamic>{},
    );
    const binding = ProfileProviderBinding(mode: ProfileProviderMode.custom);

    final envelope = PortableProfileEnvelope.build(
      profile: profile,
      providerBinding: binding,
    );
    final restored = PortableProfileEnvelope.decode(envelope.encode());

    expect(restored.version, kPortableProfileEnvelopeVersion);
    expect(restored.profile.id, 'profile-custom-1');
    expect(restored.profile.name, 'Portable custom profile');
    expect(restored.providerBinding.mode, ProfileProviderMode.custom);
    expect(restored.managedProviderSnapshot, isNull);
    expect(restored.isSecretBearing, isFalse);
  });

  test('portable profile envelope round-trips managed profiles', () {
    final profile = _profileRecord(
      id: 'profile-managed-1',
      name: 'Portable managed profile',
      provider: 'vk',
      link: '',
      providerSettings: const <String, dynamic>{},
    );
    final managedProvider = _managedProviderRecord(
      id: 'managed-1',
      provider: 'vk',
      name: 'VK Calls EU',
      providerSettings: const <String, dynamic>{'region': 'eu-west'},
    );
    const binding = ProfileProviderBinding(
      mode: ProfileProviderMode.managed,
      managedProviderId: 'managed-1',
    );

    final envelope = PortableProfileEnvelope.build(
      profile: profile,
      providerBinding: binding,
      managedProviderSnapshot: managedProvider,
    );
    final restored = PortableProfileEnvelope.decode(envelope.encode());

    expect(restored.providerBinding.isManaged, isTrue);
    expect(restored.providerBinding.managedProviderId, 'managed-1');
    expect(restored.managedProviderSnapshot?.id, 'managed-1');
    expect(
      restored.managedProviderSnapshot?.providerSettings,
      const <String, dynamic>{'region': 'eu-west'},
    );
  });

  test('portable profile import remaps ids for managed profiles', () {
    final profile = _profileRecord(
      id: 'profile-old',
      name: 'Portable managed profile',
      provider: 'vk',
      link: '',
      providerSettings: const <String, dynamic>{},
    );
    final managedProvider = _managedProviderRecord(
      id: 'managed-old',
      provider: 'vk',
      name: 'VK Calls EU',
      providerSettings: const <String, dynamic>{'region': 'eu-west'},
    );
    const binding = ProfileProviderBinding(
      mode: ProfileProviderMode.managed,
      managedProviderId: 'managed-old',
    );
    final envelope = PortableProfileEnvelope.build(
      profile: profile,
      providerBinding: binding,
      managedProviderSnapshot: managedProvider,
    );
    final ids = <String>['profile-new', 'managed-new'].iterator;

    final imported = importPortableProfileEnvelope(
      envelope,
      idFactory: () {
        final moved = ids.moveNext();
        expect(moved, isTrue);
        return ids.current;
      },
    );

    expect(imported.profile.id, 'profile-new');
    expect(imported.profile.name, 'Portable managed profile');
    expect(imported.providerBinding.mode, ProfileProviderMode.managed);
    expect(imported.providerBinding.managedProviderId, 'managed-new');
    expect(imported.managedProvider?.id, 'managed-new');
    expect(imported.managedProvider?.provider, 'vk');
    expect(imported.managedProvider?.providerSettings, const <String, dynamic>{
      'region': 'eu-west',
    });
  });

  test('portable profile import keeps custom profiles append-only', () {
    final profile = _profileRecord(
      id: 'profile-old',
      name: 'Portable custom profile',
      provider: 'generic-turn',
      link: '',
      providerSettings: const <String, dynamic>{},
    );
    const binding = ProfileProviderBinding(mode: ProfileProviderMode.custom);
    final envelope = PortableProfileEnvelope.build(
      profile: profile,
      providerBinding: binding,
    );

    final imported = importPortableProfileEnvelope(
      envelope,
      idFactory: () => 'profile-new',
    );

    expect(imported.profile.id, 'profile-new');
    expect(imported.profile.spec.provider, 'generic-turn');
    expect(imported.providerBinding.mode, ProfileProviderMode.custom);
    expect(imported.providerBinding.managedProviderId, isNull);
    expect(imported.managedProvider, isNull);
  });

  test('portable profile envelope rejects unsupported versions', () {
    final raw = _portableJson(<String, dynamic>{'version': 99});

    expect(
      () => PortableProfileEnvelope.fromJson(raw),
      throwsA(
        isA<FormatException>().having(
          (FormatException error) => error.message,
          'message',
          contains('unsupported envelope version'),
        ),
      ),
    );
  });

  test(
    'portable profile envelope rejects managed bindings without snapshots',
    () {
      final raw = _portableJson(<String, dynamic>{
        'provider_binding': const ProfileProviderBinding(
          mode: ProfileProviderMode.managed,
          managedProviderId: 'managed-1',
        ).toJson(),
        'managed_provider_snapshot': null,
      });

      expect(
        () => PortableProfileEnvelope.fromJson(raw),
        throwsA(
          isA<FormatException>().having(
            (FormatException error) => error.message,
            'message',
            contains('without managed-provider snapshot'),
          ),
        ),
      );
    },
  );

  test(
    'portable profile envelope rejects inconsistent secret classification',
    () {
      final raw = _portableJson(<String, dynamic>{
        'profile': _profileRecord(
          id: 'profile-secret',
          name: 'Portable secret profile',
          provider: 'vk',
          link: 'https://vk.com/call/join/secret',
          providerSettings: const <String, dynamic>{},
        ).toJson(),
        'secret_classification': const PortableProfileSecretClassification(
          secretBearing: false,
        ).toJson(),
      });

      expect(
        () => PortableProfileEnvelope.fromJson(raw),
        throwsA(
          isA<FormatException>().having(
            (FormatException error) => error.message,
            'message',
            contains('inconsistent secret classification'),
          ),
        ),
      );
    },
  );

  test(
    'portable profile secret classification records link and settings reasons',
    () {
      final classification = PortableProfileSecretClassification.fromProfile(
        _profileRecord(
          id: 'profile-secret',
          name: 'Portable secret profile',
          provider: 'vk',
          link: 'https://vk.com/call/join/secret',
          providerSettings: const <String, dynamic>{'region': 'eu-west'},
        ),
      );

      expect(classification.secretBearing, isTrue);
      expect(
        classification.reasons,
        containsAll(<PortableProfileSecretReason>[
          PortableProfileSecretReason.providerLink,
          PortableProfileSecretReason.profileRetainedProviderSettings,
        ]),
      );
    },
  );

  test(
    'portable profile envelope fails closed when QR payload is oversized',
    () {
      final envelope = PortableProfileEnvelope.build(
        profile: _profileRecord(
          id: 'profile-oversized',
          name: 'Oversized QR profile',
          provider: 'vk',
          link: 'https://vk.com/call/join/${'a' * 2600}',
          providerSettings: const <String, dynamic>{},
        ),
        providerBinding: const ProfileProviderBinding(
          mode: ProfileProviderMode.custom,
        ),
      );

      expect(
        envelope.encodedUtf8Bytes,
        greaterThan(kPortableProfileQrMaxPayloadBytes),
      );
      expect(envelope.fitsQrBounds, isFalse);
      expect(
        envelope.requireSupportedQrBounds,
        throwsA(
          isA<FormatException>().having(
            (FormatException error) => error.message,
            'message',
            contains('exceeds supported QR bounds'),
          ),
        ),
      );
    },
  );
}

Map<String, dynamic> _portableJson(Map<String, dynamic> overrides) {
  final raw = <String, dynamic>{
    'type': kPortableProfileEnvelopeType,
    'version': kPortableProfileEnvelopeVersion,
    'profile': _profileRecord(
      id: 'profile-1',
      name: 'Portable profile',
      provider: 'vk',
      link: '',
      providerSettings: const <String, dynamic>{},
    ).toJson(),
    'provider_binding': const ProfileProviderBinding(
      mode: ProfileProviderMode.custom,
    ).toJson(),
    'secret_classification': const PortableProfileSecretClassification(
      secretBearing: false,
    ).toJson(),
  };
  raw.addAll(overrides);
  return jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
}

ProfileRecord _profileRecord({
  required String id,
  required String name,
  required String provider,
  required String link,
  required Map<String, dynamic> providerSettings,
}) {
  return ProfileRecord(
    id: id,
    name: name,
    spec: ProfileSpec(
      provider: provider,
      link: link,
      providerSettings: providerSettings,
      listenAddress: '127.0.0.1:9001',
      peerAddress: '127.0.0.1:56000',
      mode: TransportMode.udp,
      useDtls: true,
      interactiveProvider: true,
    ),
  );
}

ManagedProviderRecord _managedProviderRecord({
  required String id,
  required String provider,
  required String name,
  required Map<String, dynamic> providerSettings,
}) {
  return ManagedProviderRecord(
    id: id,
    provider: provider,
    name: name,
    providerSettings: providerSettings,
    createdAt: DateTime.utc(2026, 4, 17, 10, 15),
    updatedAt: DateTime.utc(2026, 4, 17, 10, 16),
  );
}
