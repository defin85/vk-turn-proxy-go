import 'dart:convert';

import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/profile_draft.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _prefsStateKey = 'mobile_gui_shell_state_v1';
const String _secureSecretsKey = 'mobile_gui_shell_secure_state_v1';

class MobilePlatformModePreferences {
  const MobilePlatformModePreferences({
    this.executionPlan,
    this.applicationRoutingPolicy =
        PlatformTunnelApplicationRoutingPolicy.allApps,
    this.allowedPackages = const <String>[],
    this.disallowedPackages = const <String>[],
  });

  factory MobilePlatformModePreferences.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const MobilePlatformModePreferences();
    }
    return MobilePlatformModePreferences(
      executionPlan: json['execution_plan'] is Map<String, dynamic>
          ? RuntimeExecutionPlan.fromJson(
              json['execution_plan'] as Map<String, dynamic>,
            )
          : null,
      applicationRoutingPolicy:
          PlatformTunnelApplicationRoutingPolicy.fromJson(
            json['application_routing_policy'] as String?,
          ) ??
          PlatformTunnelApplicationRoutingPolicy.allApps,
      allowedPackages: _readPackageList(json['allowed_packages']),
      disallowedPackages: _readPackageList(json['disallowed_packages']),
    );
  }

  final RuntimeExecutionPlan? executionPlan;
  final PlatformTunnelApplicationRoutingPolicy applicationRoutingPolicy;
  final List<String> allowedPackages;
  final List<String> disallowedPackages;

  MobilePlatformModePreferences copyWith({
    RuntimeExecutionPlan? executionPlan,
    bool replaceExecutionPlan = false,
    PlatformTunnelApplicationRoutingPolicy? applicationRoutingPolicy,
    List<String>? allowedPackages,
    List<String>? disallowedPackages,
  }) {
    return MobilePlatformModePreferences(
      executionPlan: replaceExecutionPlan
          ? executionPlan
          : (executionPlan ?? this.executionPlan),
      applicationRoutingPolicy:
          applicationRoutingPolicy ?? this.applicationRoutingPolicy,
      allowedPackages: allowedPackages ?? this.allowedPackages,
      disallowedPackages: disallowedPackages ?? this.disallowedPackages,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (executionPlan != null) 'execution_plan': executionPlan!.toJson(),
      'application_routing_policy': applicationRoutingPolicy.value,
      if (allowedPackages.isNotEmpty) 'allowed_packages': allowedPackages,
      if (disallowedPackages.isNotEmpty)
        'disallowed_packages': disallowedPackages,
    };
  }
}

class MobileShellState {
  MobileShellState({
    required this.profiles,
    List<ManagedProviderRecord>? managedProviders,
    List<ProviderTemplateRecord>? providerTemplates,
    List<ProviderConfigRecord>? providerConfigs,
    required this.draft,
    this.profileBindings = const <String, ProfileProviderBinding>{},
    this.selectedProfileId,
    this.selectedPlatformTunnelMode,
    this.platformModePreferences =
        const <String, MobilePlatformModePreferences>{},
    this.localeTag,
  }) : managedProviders =
           managedProviders ??
           (providerConfigs ?? const <ProviderConfigRecord>[])
               .map(ManagedProviderRecord.fromLegacyProviderConfig)
               .toList(growable: false),
       providerTemplates =
           providerTemplates ?? const <ProviderTemplateRecord>[];

  factory MobileShellState.empty() {
    return MobileShellState(
      profiles: const <ProfileRecord>[],
      managedProviders: const <ManagedProviderRecord>[],
      providerTemplates: const <ProviderTemplateRecord>[],
      draft: ProfileDraft.defaults(),
    );
  }

  factory MobileShellState.fromJson(Map<String, dynamic> json) {
    return MobileShellState(
      profiles: (json['profiles'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (dynamic raw) =>
                ProfileRecord.fromJson(raw as Map<String, dynamic>),
          )
          .toList(growable: false),
      managedProviders: _readManagedProviders(json),
      providerTemplates: _readProviderTemplates(json),
      profileBindings: _readProfileBindings(json['profile_bindings']),
      selectedProfileId: json['selected_profile_id'] as String?,
      selectedPlatformTunnelMode: PlatformTunnelMode.fromJson(
        json['selected_platform_tunnel_mode'] as String?,
      ),
      localeTag: _readLocaleTag(json['locale_tag'] as String?),
      platformModePreferences: _readPlatformModePreferences(
        json['platform_mode_preferences'],
      ),
      draft: json['draft'] is Map<String, dynamic>
          ? ProfileDraft.fromJson(json['draft'] as Map<String, dynamic>)
          : ProfileDraft.defaults(),
    );
  }

  final List<ProfileRecord> profiles;
  final List<ManagedProviderRecord> managedProviders;
  final List<ProviderTemplateRecord> providerTemplates;
  final Map<String, ProfileProviderBinding> profileBindings;
  final String? selectedProfileId;
  final PlatformTunnelMode? selectedPlatformTunnelMode;
  final Map<String, MobilePlatformModePreferences> platformModePreferences;
  final String? localeTag;
  final ProfileDraft draft;

  List<ManagedProviderRecord> get providerConfigs => managedProviders;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'profiles': profiles
          .map((ProfileRecord profile) => profile.toJson())
          .toList(growable: false),
      'managed_providers': managedProviders
          .map((ManagedProviderRecord provider) => provider.toJson())
          .toList(growable: false),
      'provider_templates': providerTemplates
          .map((ProviderTemplateRecord template) => template.toJson())
          .toList(growable: false),
      'profile_bindings': <String, dynamic>{
        for (final entry in profileBindings.entries)
          entry.key: entry.value.toJson(),
      },
      'locale_tag': localeTag,
      'selected_profile_id': selectedProfileId,
      'selected_platform_tunnel_mode': selectedPlatformTunnelMode?.value,
      'platform_mode_preferences': <String, dynamic>{
        for (final entry in platformModePreferences.entries)
          entry.key: entry.value.toJson(),
      },
      'draft': draft.toJson(),
    };
  }

  String signature() => jsonEncode(toJson());

  MobileShellState sanitizedForPersistence(
    Iterable<ProviderDescriptor> providerDescriptors,
  ) {
    final descriptorById = <String, ProviderDescriptor>{
      for (final descriptor in providerDescriptors)
        descriptor.id.trim().toLowerCase(): descriptor,
    };
    return MobileShellState(
      profiles: profiles
          .map(
            (ProfileRecord profile) => _sanitizeProfile(
              profile,
              descriptorById[profile.spec.provider.trim().toLowerCase()],
            ),
          )
          .toList(growable: false),
      managedProviders: managedProviders
          .map(
            (ManagedProviderRecord provider) => provider.copyWith(
              providerSettings: Map<String, dynamic>.from(
                provider.providerSettings,
              ),
            ),
          )
          .toList(growable: false),
      providerTemplates: providerTemplates
          .map(
            (ProviderTemplateRecord template) => template.copyWith(
              providerSettings: Map<String, dynamic>.from(
                template.providerSettings,
              ),
            ),
          )
          .toList(growable: false),
      profileBindings: <String, ProfileProviderBinding>{
        for (final profile in profiles)
          if (profileBindings.containsKey(profile.id))
            profile.id: profileBindings[profile.id]!,
      },
      localeTag: localeTag,
      selectedProfileId: selectedProfileId,
      selectedPlatformTunnelMode: selectedPlatformTunnelMode,
      platformModePreferences: Map<String, MobilePlatformModePreferences>.from(
        platformModePreferences,
      ),
      draft: _sanitizeDraft(
        draft,
        descriptorById[draft.spec.provider.trim().toLowerCase()],
      ),
    );
  }
}

String? _readLocaleTag(String? raw) {
  final normalized = raw?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

abstract class StringBlobStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SharedPreferencesBlobStore implements StringBlobStore {
  SharedPreferencesBlobStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<SharedPreferencesBlobStore> create() async {
    return SharedPreferencesBlobStore(await SharedPreferences.getInstance());
  }

  @override
  Future<void> delete(String key) async {
    await _prefs.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    return _prefs.getString(key);
  }

  @override
  Future<void> write(String key, String value) async {
    await _prefs.setString(key, value);
  }
}

class FlutterSecureBlobStore implements StringBlobStore {
  FlutterSecureBlobStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

abstract class MobileShellStateStore {
  Future<MobileShellState?> load();
  Future<void> save(MobileShellState state);
  Future<void> clear();

  static Future<MobileShellStateStore> defaultStore() async {
    return SecureMobileShellStateStore(
      preferences: await SharedPreferencesBlobStore.create(),
      secrets: FlutterSecureBlobStore(),
    );
  }
}

class SecureMobileShellStateStore implements MobileShellStateStore {
  SecureMobileShellStateStore({
    required this.preferences,
    required this.secrets,
  });

  final StringBlobStore preferences;
  final StringBlobStore secrets;

  @override
  Future<MobileShellState?> load() async {
    final payload = await preferences.read(_prefsStateKey);
    if (payload == null || payload.trim().isEmpty) {
      return null;
    }

    final rawState = jsonDecode(payload) as Map<String, dynamic>;
    final sanitized = MobileShellState.fromJson(rawState);
    final secretManifest = _SecretManifest.fromJson(
      rawState['secret_manifest'] as Map<String, dynamic>?,
      fallbackProfiles: sanitized.profiles,
      fallbackDraft: sanitized.draft,
    );
    final secretPayload = await secrets.read(_secureSecretsKey);
    if (secretManifest.requiresSecrets &&
        (secretPayload == null || secretPayload.trim().isEmpty)) {
      throw StateError(currentShellText.secureProfileSecretsUnavailable);
    }
    final secretState = secretPayload == null || secretPayload.trim().isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(secretPayload) as Map<String, dynamic>;

    final profileSecrets =
        secretState['profiles'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final draftSecrets =
        secretState['draft'] as Map<String, dynamic>? ??
        const <String, dynamic>{};

    for (final profileId in secretManifest.profileIds) {
      if (!profileSecrets.containsKey(profileId)) {
        throw StateError(
          currentShellText.secureProfileSecretsMissing(profileId),
        );
      }
    }
    if (secretManifest.hasDraft && !secretState.containsKey('draft')) {
      throw StateError(currentShellText.secureDraftSecretsUnavailable);
    }

    return MobileShellState(
      profiles: sanitized.profiles
          .map((ProfileRecord profile) {
            final secret = profileSecrets[profile.id];
            return _profileFromSanitized(profile.toJson(), secret);
          })
          .toList(growable: false),
      managedProviders: sanitized.managedProviders,
      providerTemplates: sanitized.providerTemplates,
      profileBindings: sanitized.profileBindings,
      selectedProfileId: sanitized.selectedProfileId,
      selectedPlatformTunnelMode: sanitized.selectedPlatformTunnelMode,
      platformModePreferences: sanitized.platformModePreferences,
      draft: ProfileDraft.fromJson(
        _draftFromSanitized(sanitized.draft.toJson(), draftSecrets),
      ),
    );
  }

  @override
  Future<void> save(MobileShellState state) async {
    final secretManifest = _SecretManifest.fromState(state);
    final sanitizedJson = state.toJson()
      ..['secret_manifest'] = secretManifest.toJson();

    final encoder = const JsonEncoder.withIndent('  ');
    await preferences.write(_prefsStateKey, encoder.convert(sanitizedJson));
    await secrets.delete(_secureSecretsKey);
  }

  @override
  Future<void> clear() async {
    await preferences.delete(_prefsStateKey);
    await secrets.delete(_secureSecretsKey);
  }
}

class _SecretManifest {
  const _SecretManifest({required this.profileIds, required this.hasDraft});

  factory _SecretManifest.fromJson(
    Map<String, dynamic>? json, {
    required List<ProfileRecord> fallbackProfiles,
    required ProfileDraft fallbackDraft,
  }) {
    if (json == null) {
      return _SecretManifest(
        profileIds: fallbackProfiles
            .map((ProfileRecord profile) => profile.id.trim())
            .where((String id) => id.isNotEmpty)
            .toList(growable: false),
        hasDraft: _draftRequiresSecretState(fallbackDraft),
      );
    }
    final ids = (json['profile_ids'] as List<dynamic>? ?? const <dynamic>[])
        .map((dynamic raw) => (raw as String? ?? '').trim())
        .where((String id) => id.isNotEmpty)
        .toList(growable: false);
    return _SecretManifest(
      profileIds: ids,
      hasDraft: json['has_draft'] as bool? ?? false,
    );
  }

  factory _SecretManifest.fromState(MobileShellState state) {
    return const _SecretManifest(profileIds: <String>[], hasDraft: false);
  }

  final List<String> profileIds;
  final bool hasDraft;

  bool get requiresSecrets => profileIds.isNotEmpty || hasDraft;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'profile_ids': profileIds, 'has_draft': hasDraft};
  }
}

bool _draftRequiresSecretState(ProfileDraft draft) {
  return draft.spec.link.trim().isNotEmpty;
}

ProfileRecord _sanitizeProfile(
  ProfileRecord profile,
  ProviderDescriptor? descriptor,
) {
  return profile.copyWith(spec: _sanitizeProfileSpec(profile.spec, descriptor));
}

ProfileDraft _sanitizeDraft(
  ProfileDraft draft,
  ProviderDescriptor? descriptor,
) {
  return draft.copyWith(spec: _sanitizeProfileSpec(draft.spec, descriptor));
}

ProfileSpec _sanitizeProfileSpec(
  ProfileSpec spec,
  ProviderDescriptor? descriptor,
) {
  final sanitizedProviderSettings =
      descriptor?.profileRetainedProviderSettings(spec.providerSettings) ??
      const <String, dynamic>{};
  return spec.copyWith(link: '', providerSettings: sanitizedProviderSettings);
}

ProfileRecord _profileFromSanitized(
  Map<String, dynamic> json,
  dynamic secretState,
) {
  final withSecrets = Map<String, dynamic>.from(json);
  final spec = Map<String, dynamic>.from(
    withSecrets['spec'] as Map<String, dynamic>? ?? const <String, dynamic>{},
  );
  final secrets = secretState is Map<String, dynamic>
      ? secretState
      : const <String, dynamic>{};
  spec['link'] = secrets['link'] as String? ?? '';
  if ((secrets['turn_server'] as String?)?.isNotEmpty == true) {
    spec['turn_server'] = secrets['turn_server'];
  }
  if ((secrets['turn_port'] as String?)?.isNotEmpty == true) {
    spec['turn_port'] = secrets['turn_port'];
  }
  withSecrets['spec'] = spec;
  return ProfileRecord.fromJson(withSecrets);
}

Map<String, dynamic> _draftFromSanitized(
  Map<String, dynamic> json,
  Map<String, dynamic> secretState,
) {
  final withSecrets = Map<String, dynamic>.from(json);
  final spec = Map<String, dynamic>.from(
    withSecrets['spec'] as Map<String, dynamic>? ?? const <String, dynamic>{},
  );
  spec['link'] = secretState['link'] as String? ?? '';
  if ((secretState['turn_server'] as String?)?.isNotEmpty == true) {
    spec['turn_server'] = secretState['turn_server'];
  }
  if ((secretState['turn_port'] as String?)?.isNotEmpty == true) {
    spec['turn_port'] = secretState['turn_port'];
  }
  withSecrets['spec'] = spec;
  return withSecrets;
}

List<ManagedProviderRecord> _readManagedProviders(Map<String, dynamic> json) {
  final managed =
      (json['managed_providers'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ManagedProviderRecord.fromJson)
          .toList(growable: false);
  if (managed.isNotEmpty) {
    return managed;
  }
  return (json['provider_configs'] as List<dynamic>? ?? const <dynamic>[])
      .whereType<Map<String, dynamic>>()
      .map(ProviderConfigRecord.fromJson)
      .map(ManagedProviderRecord.fromLegacyProviderConfig)
      .toList(growable: false);
}

List<ProviderTemplateRecord> _readProviderTemplates(Map<String, dynamic> json) {
  return (json['provider_templates'] as List<dynamic>? ?? const <dynamic>[])
      .whereType<Map<String, dynamic>>()
      .map(ProviderTemplateRecord.fromJson)
      .toList(growable: false);
}

Map<String, ProfileProviderBinding> _readProfileBindings(dynamic raw) {
  if (raw is! Map<String, dynamic>) {
    return const <String, ProfileProviderBinding>{};
  }
  final bindings = <String, ProfileProviderBinding>{};
  raw.forEach((dynamic key, dynamic value) {
    final profileId = (key as String?)?.trim() ?? '';
    if (profileId.isEmpty) {
      return;
    }
    bindings[profileId] = ProfileProviderBinding.fromJson(
      value as Map<String, dynamic>?,
    );
  });
  return bindings;
}

Map<String, MobilePlatformModePreferences> _readPlatformModePreferences(
  dynamic raw,
) {
  if (raw is! Map<String, dynamic>) {
    return const <String, MobilePlatformModePreferences>{};
  }
  final preferences = <String, MobilePlatformModePreferences>{};
  raw.forEach((dynamic key, dynamic value) {
    final preferenceKey = (key as String?)?.trim() ?? '';
    if (preferenceKey.isEmpty) {
      return;
    }
    preferences[preferenceKey] = MobilePlatformModePreferences.fromJson(
      value as Map<String, dynamic>?,
    );
  });
  return preferences;
}

List<String> _readPackageList(dynamic raw) {
  final normalized = (raw as List<dynamic>? ?? const <dynamic>[])
      .whereType<String>()
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .toSet()
      .toList(growable: false);
  normalized.sort();
  return normalized;
}
