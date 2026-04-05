import 'dart:convert';

enum Capability {
  profiles('profiles'),
  sessions('sessions'),
  challenges('challenges'),
  diagnostics('diagnostics'),
  eventStream('event_stream'),
  desktopSidecar('desktop_sidecar'),
  mobileHostBridge('mobile_host_bridge');

  const Capability(this.value);

  final String value;

  static Capability? fromJson(String raw) {
    for (final capability in values) {
      if (capability.value == raw) {
        return capability;
      }
    }
    return null;
  }
}

enum TransportMode {
  auto('auto'),
  udp('udp'),
  tcp('tcp');

  const TransportMode(this.value);

  final String value;

  static TransportMode fromJson(String? raw) {
    for (final mode in values) {
      if (mode.value == raw) {
        return mode;
      }
    }
    return TransportMode.auto;
  }
}

enum SessionState {
  starting('starting'),
  challengeRequired('challenge_required'),
  ready('ready'),
  retrying('retrying'),
  stopping('stopping'),
  stopped('stopped'),
  failed('failed');

  const SessionState(this.value);

  final String value;

  static SessionState? fromJson(String? raw) {
    for (final state in values) {
      if (state.value == raw) {
        return state;
      }
    }
    return null;
  }
}

enum ChallengeStatus {
  pending('pending'),
  continuing('continuing'),
  completed('completed'),
  cancelled('cancelled'),
  failed('failed');

  const ChallengeStatus(this.value);

  final String value;

  static ChallengeStatus? fromJson(String? raw) {
    for (final status in values) {
      if (status.value == raw) {
        return status;
      }
    }
    return null;
  }
}

enum EventType {
  sessionStarting('session_starting'),
  sessionReady('session_ready'),
  sessionRetrying('session_retrying'),
  sessionFailed('session_failed'),
  sessionStopped('session_stopped'),
  challengeRequired('challenge_required'),
  challengeUpdated('challenge_updated');

  const EventType(this.value);

  final String value;

  static EventType? fromJson(String? raw) {
    for (final type in values) {
      if (type.value == raw) {
        return type;
      }
    }
    return null;
  }
}

class HostInfo {
  const HostInfo({
    required this.version,
    required this.capabilities,
  });

  factory HostInfo.fromJson(Map<String, dynamic> json) {
    return HostInfo(
      version: json['version'] as String? ?? '',
      capabilities: (json['capabilities'] as List<dynamic>? ?? const [])
          .map((dynamic raw) => Capability.fromJson(raw as String? ?? ''))
          .whereType<Capability>()
          .toList(growable: false),
    );
  }

  final String version;
  final List<Capability> capabilities;
}

class FailureInfo {
  const FailureInfo({
    this.stage,
    this.message,
    this.notImplemented = false,
  });

  factory FailureInfo.fromJson(Map<String, dynamic> json) {
    return FailureInfo(
      stage: json['stage'] as String?,
      message: json['message'] as String?,
      notImplemented: json['not_implemented'] as bool? ?? false,
    );
  }

  final String? stage;
  final String? message;
  final bool notImplemented;

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'stage': stage,
      'message': message,
      'not_implemented': notImplemented ? true : null,
    });
  }
}

class ProfileSpec {
  const ProfileSpec({
    required this.provider,
    required this.link,
    required this.listenAddress,
    required this.peerAddress,
    this.connections = 1,
    this.turnServer,
    this.turnPort,
    this.bindInterface,
    this.mode = TransportMode.auto,
    this.useDtls = true,
    this.interactiveProvider = false,
    this.logLevel = 'info',
  });

  factory ProfileSpec.fromJson(Map<String, dynamic> json) {
    return ProfileSpec(
      provider: json['provider'] as String? ?? '',
      link: json['link'] as String? ?? '',
      listenAddress: json['listen_addr'] as String? ?? '',
      peerAddress: json['peer_addr'] as String? ?? '',
      connections: json['connections'] as int? ?? 1,
      turnServer: json['turn_server'] as String?,
      turnPort: json['turn_port'] as String?,
      bindInterface: json['bind_interface'] as String?,
      mode: TransportMode.fromJson(json['mode'] as String?),
      useDtls: json['use_dtls'] as bool? ?? true,
      interactiveProvider: json['interactive_provider'] as bool? ?? false,
      logLevel: json['log_level'] as String? ?? 'info',
    );
  }

  final String provider;
  final String link;
  final String listenAddress;
  final String peerAddress;
  final int connections;
  final String? turnServer;
  final String? turnPort;
  final String? bindInterface;
  final TransportMode mode;
  final bool useDtls;
  final bool interactiveProvider;
  final String logLevel;

  ProfileSpec copyWith({
    String? provider,
    String? link,
    String? listenAddress,
    String? peerAddress,
    int? connections,
    String? turnServer,
    String? turnPort,
    String? bindInterface,
    TransportMode? mode,
    bool? useDtls,
    bool? interactiveProvider,
    String? logLevel,
  }) {
    return ProfileSpec(
      provider: provider ?? this.provider,
      link: link ?? this.link,
      listenAddress: listenAddress ?? this.listenAddress,
      peerAddress: peerAddress ?? this.peerAddress,
      connections: connections ?? this.connections,
      turnServer: turnServer ?? this.turnServer,
      turnPort: turnPort ?? this.turnPort,
      bindInterface: bindInterface ?? this.bindInterface,
      mode: mode ?? this.mode,
      useDtls: useDtls ?? this.useDtls,
      interactiveProvider: interactiveProvider ?? this.interactiveProvider,
      logLevel: logLevel ?? this.logLevel,
    );
  }

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'provider': provider,
      'link': link,
      'listen_addr': listenAddress,
      'peer_addr': peerAddress,
      'connections': connections,
      'turn_server': turnServer,
      'turn_port': turnPort,
      'bind_interface': bindInterface,
      'mode': mode.value,
      'use_dtls': useDtls,
      'interactive_provider': interactiveProvider ? true : null,
      'log_level': logLevel,
    });
  }
}

class ProfileRecord {
  const ProfileRecord({
    required this.id,
    required this.name,
    required this.spec,
  });

  factory ProfileRecord.fromJson(Map<String, dynamic> json) {
    return ProfileRecord(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      spec: ProfileSpec.fromJson(json['spec'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
    );
  }

  final String id;
  final String name;
  final ProfileSpec spec;

  ProfileRecord copyWith({
    String? id,
    String? name,
    ProfileSpec? spec,
  }) {
    return ProfileRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      spec: spec ?? this.spec,
    );
  }

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'id': id.isEmpty ? null : id,
      'name': name,
      'spec': spec.toJson(),
    });
  }
}

class ChallengeRecord {
  const ChallengeRecord({
    required this.id,
    required this.sessionId,
    required this.provider,
    required this.stage,
    required this.kind,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.prompt,
    this.openUrl,
  });

  factory ChallengeRecord.fromJson(Map<String, dynamic> json) {
    return ChallengeRecord(
      id: json['id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      stage: json['stage'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      prompt: json['prompt'] as String?,
      openUrl: json['open_url'] as String?,
      status: ChallengeStatus.fromJson(json['status'] as String?) ?? ChallengeStatus.pending,
      createdAt: _readTimestamp(json['created_at']),
      updatedAt: _readTimestamp(json['updated_at']),
    );
  }

  final String id;
  final String sessionId;
  final String provider;
  final String stage;
  final String kind;
  final String? prompt;
  final String? openUrl;
  final ChallengeStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChallengeRecord copyWith({
    ChallengeStatus? status,
    DateTime? updatedAt,
  }) {
    return ChallengeRecord(
      id: id,
      sessionId: sessionId,
      provider: provider,
      stage: stage,
      kind: kind,
      prompt: prompt,
      openUrl: openUrl,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'id': id,
      'session_id': sessionId,
      'provider': provider,
      'stage': stage,
      'kind': kind,
      'prompt': prompt,
      'open_url': openUrl,
      'status': status.value,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    });
  }
}

class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.profile,
    required this.state,
    required this.startedAt,
    required this.updatedAt,
    this.profileId,
    this.profileName,
    this.failure,
    this.activeChallengeId,
    this.stoppedAt,
  });

  factory SessionRecord.fromJson(Map<String, dynamic> json) {
    return SessionRecord(
      id: json['id'] as String? ?? '',
      profileId: json['profile_id'] as String?,
      profileName: json['profile_name'] as String?,
      profile: ProfileSpec.fromJson(json['profile'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
      state: SessionState.fromJson(json['state'] as String?) ?? SessionState.starting,
      failure: json['failure'] is Map<String, dynamic>
          ? FailureInfo.fromJson(json['failure'] as Map<String, dynamic>)
          : null,
      activeChallengeId: json['active_challenge_id'] as String?,
      startedAt: _readTimestamp(json['started_at']),
      updatedAt: _readTimestamp(json['updated_at']),
      stoppedAt: json['stopped_at'] == null ? null : _readTimestamp(json['stopped_at']),
    );
  }

  final String id;
  final String? profileId;
  final String? profileName;
  final ProfileSpec profile;
  final SessionState state;
  final FailureInfo? failure;
  final String? activeChallengeId;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? stoppedAt;

  SessionRecord copyWith({
    SessionState? state,
    FailureInfo? failure,
    String? activeChallengeId,
    DateTime? updatedAt,
    DateTime? stoppedAt,
  }) {
    return SessionRecord(
      id: id,
      profileId: profileId,
      profileName: profileName,
      profile: profile,
      state: state ?? this.state,
      failure: failure ?? this.failure,
      activeChallengeId: activeChallengeId ?? this.activeChallengeId,
      startedAt: startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      stoppedAt: stoppedAt ?? this.stoppedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'id': id,
      'profile_id': profileId,
      'profile_name': profileName,
      'profile': profile.toJson(),
      'state': state.value,
      'failure': failure?.toJson(),
      'active_challenge_id': activeChallengeId,
      'started_at': startedAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'stopped_at': stoppedAt?.toUtc().toIso8601String(),
    });
  }
}

class EventRecord {
  const EventRecord({
    required this.id,
    required this.timestamp,
    required this.sessionId,
    required this.type,
    this.state,
    this.stage,
    this.message,
    this.connections,
    this.readyWorkers,
    this.restart,
    this.backoff,
    this.challenge,
  });

  factory EventRecord.fromJson(Map<String, dynamic> json) {
    return EventRecord(
      id: json['id'] as String? ?? '',
      timestamp: _readTimestamp(json['timestamp']),
      sessionId: json['session_id'] as String? ?? '',
      type: EventType.fromJson(json['type'] as String?) ?? EventType.sessionStarting,
      state: SessionState.fromJson(json['state'] as String?),
      stage: json['stage'] as String?,
      message: json['message'] as String?,
      connections: json['connections'] as int?,
      readyWorkers: json['ready_workers'] as int?,
      restart: json['restart'] as int?,
      backoff: json['backoff'] as String?,
      challenge: json['challenge'] is Map<String, dynamic>
          ? ChallengeRecord.fromJson(json['challenge'] as Map<String, dynamic>)
          : null,
    );
  }

  final String id;
  final DateTime timestamp;
  final String sessionId;
  final EventType type;
  final SessionState? state;
  final String? stage;
  final String? message;
  final int? connections;
  final int? readyWorkers;
  final int? restart;
  final String? backoff;
  final ChallengeRecord? challenge;

  String summary() {
    final buffer = StringBuffer(type.value);
    if (state != null) {
      buffer.write(' -> ${state!.value}');
    }
    if (stage != null && stage!.isNotEmpty) {
      buffer.write(' @ $stage');
    }
    if (message != null && message!.isNotEmpty) {
      buffer.write(' | $message');
    }
    if (challenge != null) {
      buffer.write(' | challenge=${challenge!.kind}/${challenge!.status.value}');
    }
    return buffer.toString();
  }

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'id': id,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'session_id': sessionId,
      'type': type.value,
      'state': state?.value,
      'stage': stage,
      'message': message,
      'connections': connections,
      'ready_workers': readyWorkers,
      'restart': restart,
      'backoff': backoff,
      'challenge': challenge?.toJson(),
    });
  }
}

class DiagnosticsBundle {
  const DiagnosticsBundle({
    required this.session,
    required this.events,
    required this.challenges,
    required this.metrics,
  });

  factory DiagnosticsBundle.fromJson(Map<String, dynamic> json) {
    return DiagnosticsBundle(
      session: SessionRecord.fromJson(json['session'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
      events: (json['events'] as List<dynamic>? ?? const [])
          .map((dynamic raw) => EventRecord.fromJson(raw as Map<String, dynamic>))
          .toList(growable: false),
      challenges: (json['challenges'] as List<dynamic>? ?? const [])
          .map((dynamic raw) => ChallengeRecord.fromJson(raw as Map<String, dynamic>))
          .toList(growable: false),
      metrics: json['metrics'] as String? ?? '',
    );
  }

  final SessionRecord session;
  final List<EventRecord> events;
  final List<ChallengeRecord> challenges;
  final String metrics;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'session': session.toJson(),
      'events': events.map((event) => event.toJson()).toList(growable: false),
      'challenges': challenges.map((challenge) => challenge.toJson()).toList(growable: false),
      'metrics': metrics,
    };
  }

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}

class ControlPlaneError implements Exception {
  const ControlPlaneError({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String code;
  final String message;

  bool get incompatibleHost => statusCode == 409 && code == 'incompatible_host';

  @override
  String toString() {
    return 'ControlPlaneError(status=$statusCode, code=$code, message=$message)';
  }
}

DateTime _readTimestamp(dynamic raw) {
  if (raw is String && raw.isNotEmpty) {
    return DateTime.parse(raw).toLocal();
  }
  return DateTime.fromMillisecondsSinceEpoch(0).toLocal();
}

Map<String, dynamic> _compact(Map<String, dynamic> values) {
  values.removeWhere((String _, dynamic value) => value == null);
  return values;
}
