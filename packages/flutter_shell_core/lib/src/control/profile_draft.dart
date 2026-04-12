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
