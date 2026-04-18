import 'dart:convert';
import 'dart:io';

import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/profile_draft.dart';

typedef StateFileProvider = Future<File> Function();

class DesktopShellState {
  DesktopShellState({
    required this.profiles,
    List<ManagedProviderRecord>? managedProviders,
    List<ProviderConfigRecord>? providerConfigs,
    required this.draft,
    this.profileBindings = const <String, ProfileProviderBinding>{},
    this.selectedProfileId,
    this.runtimeDefaults = const RuntimeDefaults(
      listenAddress: '127.0.0.1:9001',
      peerAddress: '127.0.0.1:56000',
    ),
    this.localeTag,
  }) : managedProviders =
           managedProviders ??
           (providerConfigs ?? const <ProviderConfigRecord>[])
               .map(ManagedProviderRecord.fromLegacyProviderConfig)
               .toList(growable: false);

  factory DesktopShellState.empty() {
    return DesktopShellState(
      profiles: const <ProfileRecord>[],
      managedProviders: const <ManagedProviderRecord>[],
      draft: ProfileDraft.defaults(),
    );
  }

  factory DesktopShellState.fromJson(Map<String, dynamic> json) {
    final draft = json['draft'] is Map<String, dynamic>
        ? ProfileDraft.fromJson(json['draft'] as Map<String, dynamic>)
        : ProfileDraft.defaults();
    return DesktopShellState(
      profiles: (json['profiles'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (dynamic raw) =>
                ProfileRecord.fromJson(raw as Map<String, dynamic>),
          )
          .toList(growable: false),
      managedProviders: _readManagedProviders(json),
      profileBindings: _readProfileBindings(json['profile_bindings']),
      selectedProfileId: json['selected_profile_id'] as String?,
      localeTag: _readLocaleTag(json['locale_tag'] as String?),
      draft: draft,
      runtimeDefaults: json['runtime_defaults'] is Map<String, dynamic>
          ? RuntimeDefaults.fromJson(
              json['runtime_defaults'] as Map<String, dynamic>,
            )
          : RuntimeDefaults.fromProfileSpec(draft.spec),
    );
  }

  final List<ProfileRecord> profiles;
  final List<ManagedProviderRecord> managedProviders;
  final Map<String, ProfileProviderBinding> profileBindings;
  final String? selectedProfileId;
  final ProfileDraft draft;
  final RuntimeDefaults runtimeDefaults;
  final String? localeTag;

  List<ManagedProviderRecord> get providerConfigs => managedProviders;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'profiles': profiles
          .map((ProfileRecord profile) => profile.toJson())
          .toList(growable: false),
      'managed_providers': managedProviders
          .map((ManagedProviderRecord provider) => provider.toJson())
          .toList(growable: false),
      'profile_bindings': <String, dynamic>{
        for (final entry in profileBindings.entries)
          entry.key: entry.value.toJson(),
      },
      'locale_tag': localeTag,
      'selected_profile_id': selectedProfileId,
      'draft': draft.toJson(),
      'runtime_defaults': runtimeDefaults.toJson(),
    };
  }

  String signature() {
    return jsonEncode(toJson());
  }

  DesktopShellState sanitizedForPersistence(
    Iterable<ProviderDescriptor> providerDescriptors,
  ) {
    final descriptorById = <String, ProviderDescriptor>{
      for (final descriptor in providerDescriptors)
        descriptor.id.trim().toLowerCase(): descriptor,
    };
    return DesktopShellState(
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
      profileBindings: <String, ProfileProviderBinding>{
        for (final profile in profiles)
          if (profileBindings.containsKey(profile.id))
            profile.id: profileBindings[profile.id]!,
      },
      localeTag: localeTag,
      selectedProfileId: selectedProfileId,
      draft: _sanitizeDraft(
        draft,
        descriptorById[draft.spec.provider.trim().toLowerCase()],
      ),
      runtimeDefaults: runtimeDefaults,
    );
  }
}

String? _readLocaleTag(String? raw) {
  final normalized = raw?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

abstract class DesktopShellStateStore {
  Future<DesktopShellState?> load();
  Future<void> save(DesktopShellState state);
}

class FileDesktopShellStateStore implements DesktopShellStateStore {
  FileDesktopShellStateStore({StateFileProvider? fileProvider})
    : _fileProvider = fileProvider ?? defaultDesktopShellStateFile;

  final StateFileProvider _fileProvider;

  @override
  Future<DesktopShellState?> load() async {
    final file = await _fileProvider();
    if (!await file.exists()) {
      return null;
    }
    final payload = await file.readAsString();
    if (payload.trim().isEmpty) {
      return null;
    }
    return DesktopShellState.fromJson(
      jsonDecode(payload) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> save(DesktopShellState state) async {
    final file = await _fileProvider();
    await file.parent.create(recursive: true);
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(state.toJson())}\n');
  }
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

Future<File> defaultDesktopShellStateFile() async {
  final environment = Platform.environment;
  if (Platform.isWindows) {
    final appData = environment['APPDATA'] ?? environment['USERPROFILE'];
    if (appData != null && appData.isNotEmpty) {
      return File(
        _join(<String>[appData, 'vk-turn-proxy-go', 'gui-shell-state.json']),
      );
    }
  }

  final home = environment['HOME'];
  if (home != null && home.isNotEmpty) {
    return File(
      _join(<String>[home, '.vk-turn-proxy-go', 'gui-shell-state.json']),
    );
  }
  return File(
    _join(<String>[
      Directory.systemTemp.path,
      'vk-turn-proxy-go-gui-shell-state.json',
    ]),
  );
}

String _join(List<String> parts) {
  final filtered = parts
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
  if (filtered.isEmpty) {
    return '';
  }
  var value = filtered.first;
  for (final part in filtered.skip(1)) {
    if (value.endsWith(Platform.pathSeparator)) {
      value = '$value${part.replaceFirst(RegExp(r'^[\\/]+'), '')}';
      continue;
    }
    value =
        '$value${Platform.pathSeparator}${part.replaceFirst(RegExp(r'^[\\/]+'), '')}';
  }
  return value;
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
