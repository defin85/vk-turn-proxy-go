import 'package:flutter_shell_core/control_plane_models.dart';

class ProfileDraft {
  const ProfileDraft({
    this.id,
    required this.name,
    required this.spec,
    this.providerBinding = const ProfileProviderBinding(),
  });

  factory ProfileDraft.defaults() {
    return const ProfileDraft(
      name: '',
      spec: ProfileSpec(
        provider: '',
        link: '',
        listenAddress: '127.0.0.1:9001',
        peerAddress: '127.0.0.1:56000',
      ),
      providerBinding: ProfileProviderBinding(),
    );
  }

  factory ProfileDraft.fromJson(Map<String, dynamic> json) {
    return ProfileDraft(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      spec: ProfileSpec.fromJson(
        json['spec'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      providerBinding: ProfileProviderBinding.fromJson(
        json['provider_binding'] as Map<String, dynamic>?,
      ),
    );
  }

  factory ProfileDraft.fromProfile(
    ProfileRecord profile, {
    ProfileProviderBinding providerBinding = const ProfileProviderBinding(),
  }) {
    return ProfileDraft(
      id: profile.id,
      name: profile.name,
      spec: profile.spec,
      providerBinding: providerBinding,
    );
  }

  final String? id;
  final String name;
  final ProfileSpec spec;
  final ProfileProviderBinding providerBinding;

  ProfileDraft copyWith({
    String? id,
    bool replaceId = false,
    String? name,
    ProfileSpec? spec,
    ProfileProviderBinding? providerBinding,
  }) {
    return ProfileDraft(
      id: replaceId ? id : (id ?? this.id),
      name: name ?? this.name,
      spec: spec ?? this.spec,
      providerBinding: providerBinding ?? this.providerBinding,
    );
  }

  ProfileRecord toProfile() {
    return ProfileRecord(id: id ?? '', name: name.trim(), spec: spec);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'spec': spec.toJson(),
      'provider_binding': providerBinding.toJson(),
    };
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
    bool replaceId = false,
    String? provider,
    String? name,
    Map<String, dynamic>? providerSettings,
    DateTime? createdAt,
    bool replaceCreatedAt = false,
    DateTime? updatedAt,
    bool replaceUpdatedAt = false,
    ProviderConfigAvailability? availability,
  }) {
    return ProviderConfigDraft(
      id: replaceId ? id : (id ?? this.id),
      provider: provider ?? this.provider,
      name: name ?? this.name,
      providerSettings: providerSettings ?? this.providerSettings,
      createdAt: replaceCreatedAt ? createdAt : (createdAt ?? this.createdAt),
      updatedAt: replaceUpdatedAt ? updatedAt : (updatedAt ?? this.updatedAt),
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

class ManagedProviderDraft {
  const ManagedProviderDraft({
    this.id,
    required this.provider,
    required this.name,
    this.providerSettings = const <String, dynamic>{},
    this.createdAt,
    this.updatedAt,
    this.availability = const ProviderConfigAvailability(),
  });

  factory ManagedProviderDraft.defaults({String provider = ''}) {
    return ManagedProviderDraft(provider: provider, name: '');
  }

  factory ManagedProviderDraft.fromJson(Map<String, dynamic> json) {
    return ManagedProviderDraft(
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

  factory ManagedProviderDraft.fromRecord(ManagedProviderRecord record) {
    return ManagedProviderDraft(
      id: record.id,
      provider: record.provider,
      name: record.name,
      providerSettings: record.providerSettings,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      availability: record.availability,
    );
  }

  factory ManagedProviderDraft.fromPreset(
    ProviderPreset preset, {
    ProviderDescriptor? descriptor,
  }) {
    return ManagedProviderDraft(
      provider: preset.provider,
      name: preset.title,
      providerSettings: preset.normalizedSeedSettings(descriptor),
    );
  }

  factory ManagedProviderDraft.fromTemplateRecord(
    ProviderTemplateRecord record,
  ) {
    return ManagedProviderDraft(
      provider: record.provider,
      name: record.name,
      providerSettings: record.providerSettings,
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

  ManagedProviderDraft copyWith({
    String? id,
    bool replaceId = false,
    String? provider,
    String? name,
    Map<String, dynamic>? providerSettings,
    DateTime? createdAt,
    bool replaceCreatedAt = false,
    DateTime? updatedAt,
    bool replaceUpdatedAt = false,
    ProviderConfigAvailability? availability,
  }) {
    return ManagedProviderDraft(
      id: replaceId ? id : (id ?? this.id),
      provider: provider ?? this.provider,
      name: name ?? this.name,
      providerSettings: providerSettings ?? this.providerSettings,
      createdAt: replaceCreatedAt ? createdAt : (createdAt ?? this.createdAt),
      updatedAt: replaceUpdatedAt ? updatedAt : (updatedAt ?? this.updatedAt),
      availability: availability ?? this.availability,
    );
  }

  ManagedProviderRecord toRecord() {
    return ManagedProviderRecord(
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

class ProviderTemplateDraft {
  const ProviderTemplateDraft({
    this.id,
    required this.provider,
    required this.name,
    this.providerSettings = const <String, dynamic>{},
    this.createdAt,
    this.updatedAt,
    this.availability = const ProviderConfigAvailability(),
  });

  factory ProviderTemplateDraft.defaults({String provider = ''}) {
    return ProviderTemplateDraft(provider: provider, name: '');
  }

  factory ProviderTemplateDraft.fromJson(Map<String, dynamic> json) {
    return ProviderTemplateDraft(
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

  factory ProviderTemplateDraft.fromRecord(ProviderTemplateRecord record) {
    return ProviderTemplateDraft(
      id: record.id,
      provider: record.provider,
      name: record.name,
      providerSettings: record.providerSettings,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      availability: record.availability,
    );
  }

  factory ProviderTemplateDraft.fromManagedProviderDraft(
    ManagedProviderDraft draft,
  ) {
    return ProviderTemplateDraft(
      provider: draft.provider,
      name: draft.name,
      providerSettings: draft.providerSettings,
    );
  }

  factory ProviderTemplateDraft.fromManagedProviderRecord(
    ManagedProviderRecord record,
  ) {
    return ProviderTemplateDraft(
      provider: record.provider,
      name: record.name,
      providerSettings: record.providerSettings,
    );
  }

  final String? id;
  final String provider;
  final String name;
  final Map<String, dynamic> providerSettings;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final ProviderConfigAvailability availability;

  ProviderTemplateDraft copyWith({
    String? id,
    bool replaceId = false,
    String? provider,
    String? name,
    Map<String, dynamic>? providerSettings,
    DateTime? createdAt,
    bool replaceCreatedAt = false,
    DateTime? updatedAt,
    bool replaceUpdatedAt = false,
    ProviderConfigAvailability? availability,
  }) {
    return ProviderTemplateDraft(
      id: replaceId ? id : (id ?? this.id),
      provider: provider ?? this.provider,
      name: name ?? this.name,
      providerSettings: providerSettings ?? this.providerSettings,
      createdAt: replaceCreatedAt ? createdAt : (createdAt ?? this.createdAt),
      updatedAt: replaceUpdatedAt ? updatedAt : (updatedAt ?? this.updatedAt),
      availability: availability ?? this.availability,
    );
  }

  ProviderTemplateRecord toRecord() {
    return ProviderTemplateRecord(
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

  ProfileDraft applyManagedProvider(ManagedProviderRecord provider) {
    final sameProvider =
        spec.provider.trim().toLowerCase() ==
        provider.provider.trim().toLowerCase();
    return copyWith(
      spec: spec.copyWith(
        provider: provider.provider,
        link: sameProvider ? spec.link : '',
        providerSettings: provider.providerSettings,
      ),
      providerBinding: ProfileProviderBinding(
        mode: ProfileProviderMode.managed,
        managedProviderId: provider.id,
      ),
    );
  }

  ProfileDraft applyManagedProviderDraft(ManagedProviderDraft provider) {
    final sameProvider =
        spec.provider.trim().toLowerCase() ==
        provider.provider.trim().toLowerCase();
    return copyWith(
      spec: spec.copyWith(
        provider: provider.provider,
        link: sameProvider ? spec.link : '',
        providerSettings: provider.providerSettings,
      ),
      providerBinding: ProfileProviderBinding(
        mode: ProfileProviderMode.managed,
        managedProviderId: provider.id,
      ),
    );
  }

  ProfileDraft asCustomProvider() {
    return copyWith(
      providerBinding: const ProfileProviderBinding(
        mode: ProfileProviderMode.custom,
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
      providerBinding: const ProfileProviderBinding(
        mode: ProfileProviderMode.custom,
      ),
    );
  }
}
