import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/profile_draft.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _prefsStateKey = 'mobile_gui_shell_state_v1';
const String _secureSecretsKey = 'mobile_gui_shell_secure_state_v1';

class MobileShellState {
  const MobileShellState({
    required this.profiles,
    required this.draft,
    this.selectedProfileId,
  });

  factory MobileShellState.empty() {
    return MobileShellState(
      profiles: const <ProfileRecord>[],
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
      selectedProfileId: json['selected_profile_id'] as String?,
      draft: json['draft'] is Map<String, dynamic>
          ? ProfileDraft.fromJson(json['draft'] as Map<String, dynamic>)
          : ProfileDraft.defaults(),
    );
  }

  final List<ProfileRecord> profiles;
  final String? selectedProfileId;
  final ProfileDraft draft;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'profiles': profiles
          .map((ProfileRecord profile) => profile.toJson())
          .toList(growable: false),
      'selected_profile_id': selectedProfileId,
      'draft': draft.toJson(),
    };
  }

  String signature() => jsonEncode(toJson());
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
      throw StateError(
        'Secure profile secrets are unavailable. Restore secure storage or clear the saved mobile shell state.',
      );
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
          'Secure profile secrets are missing for saved profile $profileId.',
        );
      }
    }
    if (secretManifest.hasDraft && !secretState.containsKey('draft')) {
      throw StateError(
        'Secure draft secrets are unavailable. Restore secure storage or reset the draft.',
      );
    }

    return MobileShellState(
      profiles: sanitized.profiles
          .map((ProfileRecord profile) {
            final secret = profileSecrets[profile.id];
            return _profileFromSanitized(profile.toJson(), secret);
          })
          .toList(growable: false),
      selectedProfileId: sanitized.selectedProfileId,
      draft: ProfileDraft.fromJson(
        _draftFromSanitized(sanitized.draft.toJson(), draftSecrets),
      ),
    );
  }

  @override
  Future<void> save(MobileShellState state) async {
    final secretManifest = _SecretManifest.fromState(state);
    final sanitized = MobileShellState(
      profiles: state.profiles
          .map(
            (ProfileRecord profile) =>
                ProfileRecord.fromJson(_sanitizeProfile(profile.toJson())),
          )
          .toList(growable: false),
      selectedProfileId: state.selectedProfileId,
      draft: ProfileDraft.fromJson(_sanitizeDraft(state.draft.toJson())),
    );
    final sanitizedJson = sanitized.toJson()
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

Map<String, dynamic> _sanitizeProfile(Map<String, dynamic> json) {
  final sanitized = Map<String, dynamic>.from(json);
  final spec = Map<String, dynamic>.from(
    sanitized['spec'] as Map<String, dynamic>? ?? const <String, dynamic>{},
  );
  spec['link'] = '';
  sanitized['spec'] = spec;
  return sanitized;
}

Map<String, dynamic> _sanitizeDraft(Map<String, dynamic> json) {
  final sanitized = Map<String, dynamic>.from(json);
  final spec = Map<String, dynamic>.from(
    sanitized['spec'] as Map<String, dynamic>? ?? const <String, dynamic>{},
  );
  spec['link'] = '';
  sanitized['spec'] = spec;
  return sanitized;
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
