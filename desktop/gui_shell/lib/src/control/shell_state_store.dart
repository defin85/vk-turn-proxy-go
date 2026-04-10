import 'dart:convert';
import 'dart:io';

import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/profile_draft.dart';

typedef StateFileProvider = Future<File> Function();

class DesktopShellState {
  const DesktopShellState({
    required this.profiles,
    required this.draft,
    this.selectedProfileId,
  });

  factory DesktopShellState.empty() {
    return DesktopShellState(
      profiles: const <ProfileRecord>[],
      draft: ProfileDraft.defaults(),
    );
  }

  factory DesktopShellState.fromJson(Map<String, dynamic> json) {
    return DesktopShellState(
      profiles: (json['profiles'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic raw) => ProfileRecord.fromJson(raw as Map<String, dynamic>))
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
      'profiles': profiles.map((ProfileRecord profile) => profile.toJson()).toList(growable: false),
      'selected_profile_id': selectedProfileId,
      'draft': draft.toJson(),
    };
  }

  String signature() {
    return jsonEncode(toJson());
  }

  DesktopShellState sanitizedForPersistence() {
    return DesktopShellState(
      profiles: profiles
          .map((ProfileRecord profile) => _sanitizeProfile(profile))
          .toList(growable: false),
      selectedProfileId: selectedProfileId,
      draft: _sanitizeDraft(draft),
    );
  }
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
    return DesktopShellState.fromJson(jsonDecode(payload) as Map<String, dynamic>);
  }

  @override
  Future<void> save(DesktopShellState state) async {
    final file = await _fileProvider();
    await file.parent.create(recursive: true);
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(
      '${encoder.convert(state.sanitizedForPersistence().toJson())}\n',
    );
  }
}

ProfileRecord _sanitizeProfile(ProfileRecord profile) {
  return profile.copyWith(spec: _sanitizeProfileSpec(profile.spec));
}

ProfileDraft _sanitizeDraft(ProfileDraft draft) {
  return draft.copyWith(spec: _sanitizeProfileSpec(draft.spec));
}

ProfileSpec _sanitizeProfileSpec(ProfileSpec spec) {
  final link = spec.link.trim();
  if (!link.startsWith('generic-turn://')) {
    return spec;
  }
  return spec.copyWith(link: '');
}

Future<File> defaultDesktopShellStateFile() async {
  final environment = Platform.environment;
  if (Platform.isWindows) {
    final appData = environment['APPDATA'] ?? environment['USERPROFILE'];
    if (appData != null && appData.isNotEmpty) {
      return File(_join(<String>[appData, 'vk-turn-proxy-go', 'gui-shell-state.json']));
    }
  }

  final home = environment['HOME'];
  if (home != null && home.isNotEmpty) {
    return File(_join(<String>[home, '.vk-turn-proxy-go', 'gui-shell-state.json']));
  }
  return File(_join(<String>[Directory.systemTemp.path, 'vk-turn-proxy-go-gui-shell-state.json']));
}

String _join(List<String> parts) {
  final filtered = parts.where((String part) => part.isNotEmpty).toList(growable: false);
  if (filtered.isEmpty) {
    return '';
  }
  var value = filtered.first;
  for (final part in filtered.skip(1)) {
    if (value.endsWith(Platform.pathSeparator)) {
      value = '$value${part.replaceFirst(RegExp(r'^[\\/]+'), '')}';
      continue;
    }
    value = '$value${Platform.pathSeparator}${part.replaceFirst(RegExp(r'^[\\/]+'), '')}';
  }
  return value;
}
