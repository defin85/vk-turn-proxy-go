import 'dart:convert';

import 'package:flutter_shell_core/control_plane_models.dart';

const String kPortableProfileEnvelopeType = 'portable_profile';
const int kPortableProfileEnvelopeVersion = 1;
const int kPortableProfileQrMaxPayloadBytes = 2048;

enum PortableProfileSecretReason {
  providerLink('provider_link'),
  profileRetainedProviderSettings('profile_retained_provider_settings');

  const PortableProfileSecretReason(this.value);

  final String value;

  static PortableProfileSecretReason? fromJson(String? raw) {
    for (final reason in values) {
      if (reason.value == raw) {
        return reason;
      }
    }
    return null;
  }
}

class PortableProfileSecretClassification {
  const PortableProfileSecretClassification({
    required this.secretBearing,
    this.reasons = const <PortableProfileSecretReason>[],
  });

  factory PortableProfileSecretClassification.fromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return const PortableProfileSecretClassification(secretBearing: false);
    }
    final reasons = <PortableProfileSecretReason>[];
    final seen = <PortableProfileSecretReason>{};
    for (final raw in json['reasons'] as List<dynamic>? ?? const <dynamic>[]) {
      final reason = PortableProfileSecretReason.fromJson(raw as String?);
      if (reason == null || !seen.add(reason)) {
        continue;
      }
      reasons.add(reason);
    }
    final secretBearing = json['secret_bearing'] as bool? ?? reasons.isNotEmpty;
    return PortableProfileSecretClassification(
      secretBearing: secretBearing,
      reasons: List<PortableProfileSecretReason>.unmodifiable(reasons),
    );
  }

  factory PortableProfileSecretClassification.fromProfile(
    ProfileRecord profile,
  ) {
    final reasons = <PortableProfileSecretReason>[];
    if (profile.spec.link.trim().isNotEmpty) {
      reasons.add(PortableProfileSecretReason.providerLink);
    }
    if (profile.spec.providerSettings.isNotEmpty) {
      reasons.add(PortableProfileSecretReason.profileRetainedProviderSettings);
    }
    return PortableProfileSecretClassification(
      secretBearing: reasons.isNotEmpty,
      reasons: List<PortableProfileSecretReason>.unmodifiable(reasons),
    );
  }

  final bool secretBearing;
  final List<PortableProfileSecretReason> reasons;

  Map<String, dynamic> toJson() {
    return _compactPortableJson(<String, dynamic>{
      'secret_bearing': secretBearing ? true : null,
      'reasons': reasons.isEmpty
          ? null
          : reasons
                .map((PortableProfileSecretReason reason) => reason.value)
                .toList(growable: false),
    });
  }
}

class PortableProfileEnvelope {
  const PortableProfileEnvelope({
    required this.version,
    required this.profile,
    required this.providerBinding,
    required this.secretClassification,
    this.managedProviderSnapshot,
  });

  factory PortableProfileEnvelope.build({
    required ProfileRecord profile,
    required ProfileProviderBinding providerBinding,
    ManagedProviderRecord? managedProviderSnapshot,
  }) {
    _validatePortableProfileBinding(
      providerBinding: providerBinding,
      managedProviderSnapshot: managedProviderSnapshot,
    );
    return PortableProfileEnvelope(
      version: kPortableProfileEnvelopeVersion,
      profile: profile,
      providerBinding: providerBinding,
      managedProviderSnapshot: managedProviderSnapshot,
      secretClassification: PortableProfileSecretClassification.fromProfile(
        profile,
      ),
    );
  }

  factory PortableProfileEnvelope.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] as String? ?? '').trim();
    if (type != kPortableProfileEnvelopeType) {
      throw const FormatException(
        'portable profile payload missing supported envelope type',
      );
    }
    final version = json['version'] as int? ?? 0;
    if (version != kPortableProfileEnvelopeVersion) {
      throw FormatException(
        'portable profile payload uses unsupported envelope version $version',
      );
    }
    final profile = ProfileRecord.fromJson(
      _readPortableJsonObject(json['profile'], fieldName: 'profile'),
    );
    final providerBinding = ProfileProviderBinding.fromJson(
      _readPortableJsonObject(
        json['provider_binding'],
        fieldName: 'provider_binding',
      ),
    );
    final managedProviderSnapshot =
        json['managed_provider_snapshot'] is Map<String, dynamic>
        ? ManagedProviderRecord.fromJson(
            json['managed_provider_snapshot'] as Map<String, dynamic>,
          )
        : null;
    _validatePortableProfileBinding(
      providerBinding: providerBinding,
      managedProviderSnapshot: managedProviderSnapshot,
    );
    final secretClassification = PortableProfileSecretClassification.fromJson(
      json['secret_classification'] as Map<String, dynamic>?,
    );
    final recomputed = PortableProfileSecretClassification.fromProfile(profile);
    if (secretClassification.secretBearing != recomputed.secretBearing ||
        secretClassification.reasons.length != recomputed.reasons.length ||
        !secretClassification.reasons.every(recomputed.reasons.contains)) {
      throw const FormatException(
        'portable profile payload has inconsistent secret classification',
      );
    }
    return PortableProfileEnvelope(
      version: version,
      profile: profile,
      providerBinding: providerBinding,
      managedProviderSnapshot: managedProviderSnapshot,
      secretClassification: secretClassification,
    );
  }

  static PortableProfileEnvelope decode(String payload) {
    final trimmed = payload.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('portable profile payload is empty');
    }
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'portable profile payload must be a JSON map',
      );
    }
    return PortableProfileEnvelope.fromJson(decoded);
  }

  final int version;
  final ProfileRecord profile;
  final ProfileProviderBinding providerBinding;
  final ManagedProviderRecord? managedProviderSnapshot;
  final PortableProfileSecretClassification secretClassification;

  bool get isSecretBearing => secretClassification.secretBearing;

  String get displayName => profile.name.isEmpty ? profile.id : profile.name;

  Map<String, dynamic> toJson() {
    return _compactPortableJson(<String, dynamic>{
      'type': kPortableProfileEnvelopeType,
      'version': version,
      'profile': profile.toJson(),
      'provider_binding': providerBinding.toJson(),
      'managed_provider_snapshot': managedProviderSnapshot?.toJson(),
      'secret_classification': secretClassification.toJson(),
    });
  }

  String encode() => jsonEncode(toJson());

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  int get encodedUtf8Bytes => utf8.encode(encode()).length;

  bool get fitsQrBounds =>
      encodedUtf8Bytes <= kPortableProfileQrMaxPayloadBytes;

  void requireSupportedQrBounds() {
    if (fitsQrBounds) {
      return;
    }
    throw FormatException(
      'portable profile payload exceeds supported QR bounds '
      '($encodedUtf8Bytes > $kPortableProfileQrMaxPayloadBytes bytes)',
    );
  }
}

class PortableProfileImportResult {
  const PortableProfileImportResult({
    required this.profile,
    required this.providerBinding,
    this.managedProvider,
  });

  final ProfileRecord profile;
  final ProfileProviderBinding providerBinding;
  final ManagedProviderRecord? managedProvider;
}

PortableProfileImportResult importPortableProfileEnvelope(
  PortableProfileEnvelope envelope, {
  required String Function() idFactory,
}) {
  final importedProfileId = idFactory().trim();
  if (importedProfileId.isEmpty) {
    throw const FormatException(
      'portable profile import generated an empty id',
    );
  }
  ManagedProviderRecord? importedProvider;
  ProfileProviderBinding importedBinding = envelope.providerBinding;
  if (envelope.providerBinding.isManaged) {
    final snapshot = envelope.managedProviderSnapshot;
    if (snapshot == null) {
      throw const FormatException(
        'portable profile import requires a managed-provider snapshot',
      );
    }
    final importedProviderId = idFactory().trim();
    if (importedProviderId.isEmpty) {
      throw const FormatException(
        'portable profile import generated an empty managed-provider id',
      );
    }
    importedProvider = snapshot.copyWith(id: importedProviderId);
    importedBinding = ProfileProviderBinding(
      mode: ProfileProviderMode.managed,
      managedProviderId: importedProviderId,
    );
  } else {
    importedBinding = const ProfileProviderBinding(
      mode: ProfileProviderMode.custom,
    );
  }
  return PortableProfileImportResult(
    profile: envelope.profile.copyWith(id: importedProfileId),
    providerBinding: importedBinding,
    managedProvider: importedProvider,
  );
}

void _validatePortableProfileBinding({
  required ProfileProviderBinding providerBinding,
  required ManagedProviderRecord? managedProviderSnapshot,
}) {
  if (providerBinding.isManaged) {
    final managedProviderId = providerBinding.managedProviderId?.trim() ?? '';
    if (managedProviderId.isEmpty) {
      throw const FormatException(
        'portable profile payload marks managed mode without managed_provider_id',
      );
    }
    if (managedProviderSnapshot == null) {
      throw const FormatException(
        'portable profile payload marks managed mode without managed-provider snapshot',
      );
    }
    if (managedProviderSnapshot.id.trim() != managedProviderId) {
      throw const FormatException(
        'portable profile payload managed-provider snapshot does not match provider_binding.managed_provider_id',
      );
    }
    return;
  }
  if (managedProviderSnapshot != null) {
    throw const FormatException(
      'portable profile payload includes managed-provider snapshot for custom mode',
    );
  }
}

Map<String, dynamic> _readPortableJsonObject(
  dynamic raw, {
  required String fieldName,
}) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  throw FormatException('portable profile payload missing $fieldName object');
}

Map<String, dynamic> _compactPortableJson(Map<String, dynamic> raw) {
  final compact = <String, dynamic>{};
  raw.forEach((String key, dynamic value) {
    if (value == null) {
      return;
    }
    if (value is String && value.isEmpty) {
      return;
    }
    if (value is Iterable && value.isEmpty) {
      return;
    }
    if (value is Map && value.isEmpty) {
      return;
    }
    compact[key] = value;
  });
  return compact;
}
