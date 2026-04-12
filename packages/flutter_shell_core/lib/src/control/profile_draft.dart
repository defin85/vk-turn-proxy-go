import 'package:flutter_shell_core/control_plane_models.dart';

class ProfileDraft {
  const ProfileDraft({this.id, required this.name, required this.spec});

  factory ProfileDraft.defaults() {
    return const ProfileDraft(
      name: '',
      spec: ProfileSpec(
        provider: '',
        link: '',
        listenAddress: '127.0.0.1:9001',
        peerAddress: '127.0.0.1:56000',
      ),
    );
  }

  factory ProfileDraft.fromJson(Map<String, dynamic> json) {
    return ProfileDraft(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      spec: ProfileSpec.fromJson(
        json['spec'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
    );
  }

  factory ProfileDraft.fromProfile(ProfileRecord profile) {
    return ProfileDraft(id: profile.id, name: profile.name, spec: profile.spec);
  }

  final String? id;
  final String name;
  final ProfileSpec spec;

  ProfileDraft copyWith({String? id, String? name, ProfileSpec? spec}) {
    return ProfileDraft(
      id: id ?? this.id,
      name: name ?? this.name,
      spec: spec ?? this.spec,
    );
  }

  ProfileRecord toProfile() {
    return ProfileRecord(id: id ?? '', name: name.trim(), spec: spec);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'id': id, 'name': name, 'spec': spec.toJson()};
  }
}

class ProviderConfigDraft {
  const ProviderConfigDraft({
    this.id,
    required this.provider,
    required this.name,
    this.providerSettings = const <String, dynamic>{},
    this.createdAt,
    this.updatedAt,
    this.availability = const ProviderConfigAvailability(),
  });

  factory ProviderConfigDraft.defaults({String provider = ''}) {
    return ProviderConfigDraft(provider: provider, name: '');
  }

  factory ProviderConfigDraft.fromJson(Map<String, dynamic> json) {
    return ProviderConfigDraft(
      id: json['id'] as String?,
      provider: json['provider'] as String? ?? '',
      name: json['name'] as String? ?? '',
      providerSettings: json['provider_settings'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(
              json['provider_settings'] as Map<String, dynamic>,
            )
          : const <String, dynamic>{},
      createdAt:
          json['created_at'] is String &&
              (json['created_at'] as String).isNotEmpty
          ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
          : null,
      updatedAt:
          json['updated_at'] is String &&
              (json['updated_at'] as String).isNotEmpty
          ? DateTime.tryParse(json['updated_at'] as String)?.toLocal()
          : null,
      availability: json['availability'] is Map<String, dynamic>
          ? ProviderConfigAvailability.fromJson(
              json['availability'] as Map<String, dynamic>,
            )
          : const ProviderConfigAvailability(),
    );
  }

  factory ProviderConfigDraft.fromRecord(ProviderConfigRecord record) {
    return ProviderConfigDraft(
      id: record.id,
      provider: record.provider,
      name: record.name,
      providerSettings: record.providerSettings,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      availability: record.availability,
    );
  }

  final String? id;
  final String provider;
  final String name;
  final Map<String, dynamic> providerSettings;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final ProviderConfigAvailability availability;

  ProviderConfigDraft copyWith({
    String? id,
    String? provider,
    String? name,
    Map<String, dynamic>? providerSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
    ProviderConfigAvailability? availability,
  }) {
    return ProviderConfigDraft(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      name: name ?? this.name,
      providerSettings: providerSettings ?? this.providerSettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      availability: availability ?? this.availability,
    );
  }

  ProviderConfigRecord toRecord() {
    return ProviderConfigRecord(
      id: id ?? '',
      provider: provider,
      name: name.trim(),
      providerSettings: providerSettings,
      createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      availability: availability,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'provider': provider,
      'name': name,
      'provider_settings': providerSettings,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
      'availability': availability.toJson(),
    };
  }
}

extension ProfileDraftProviderBootstrap on ProfileDraft {
  ProfileDraft applyProviderConfig(ProviderConfigRecord config) {
    final sameProvider =
        spec.provider.trim().toLowerCase() ==
        config.provider.trim().toLowerCase();
    return copyWith(
      spec: spec.copyWith(
        provider: config.provider,
        link: sameProvider ? spec.link : '',
        providerSettings: config.providerSettings,
      ),
    );
  }

  ProfileDraft applyProviderPreset(
    ProviderPreset preset, {
    ProviderDescriptor? descriptor,
  }) {
    return copyWith(
      id: null,
      name: preset.suggestedProfileName,
      spec: spec.copyWith(
        provider: preset.provider,
        link: '',
        providerSettings: preset.normalizedSeedSettings(descriptor),
      ),
    );
  }
}
