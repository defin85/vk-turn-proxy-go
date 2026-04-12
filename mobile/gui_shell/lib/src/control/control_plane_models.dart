import 'dart:convert';

enum Capability {
  profiles('profiles'),
  sessions('sessions'),
  challenges('challenges'),
  diagnostics('diagnostics'),
  eventStream('event_stream'),
  desktopSidecar('desktop_sidecar'),
  mobileHostBridge('mobile_host_bridge'),
  platformTunnels('platform_tunnels'),
  providerRuntimeArtifacts('provider-runtime-artifacts');

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

enum ProviderInputKind {
  link('link');

  const ProviderInputKind(this.value);

  final String value;

  static ProviderInputKind fromJson(String? raw) {
    for (final kind in values) {
      if (kind.value == raw) {
        return kind;
      }
    }
    return ProviderInputKind.link;
  }
}

enum ProviderAuthPosture {
  notApplicable('not_applicable'),
  guest('guest'),
  account('account'),
  guestOrAccount('guest_or_account'),
  staticSecret('static_secret');

  const ProviderAuthPosture(this.value);

  final String value;

  static ProviderAuthPosture fromJson(String? raw) {
    for (final posture in values) {
      if (posture.value == raw) {
        return posture;
      }
    }
    return ProviderAuthPosture.notApplicable;
  }
}

extension ProviderAuthPostureDisplay on ProviderAuthPosture {
  String get label => switch (this) {
    ProviderAuthPosture.notApplicable => 'no auth requirement reported',
    ProviderAuthPosture.guest => 'guest auth',
    ProviderAuthPosture.account => 'account auth',
    ProviderAuthPosture.guestOrAccount => 'guest or account auth',
    ProviderAuthPosture.staticSecret => 'static secret input',
  };
}

enum ProviderBrowserPolicy {
  notRequired('not_required'),
  externalRequired('external_required'),
  embeddedAllowed('embedded_allowed');

  const ProviderBrowserPolicy(this.value);

  final String value;

  static ProviderBrowserPolicy fromJson(String? raw) {
    for (final policy in values) {
      if (policy.value == raw) {
        return policy;
      }
    }
    return ProviderBrowserPolicy.notRequired;
  }
}

extension ProviderBrowserPolicyDisplay on ProviderBrowserPolicy {
  String get label => switch (this) {
    ProviderBrowserPolicy.notRequired => 'no browser requirement reported',
    ProviderBrowserPolicy.externalRequired => 'external browser required',
    ProviderBrowserPolicy.embeddedAllowed => 'embedded browser allowed',
  };
}

enum ProviderChallengeMode {
  browser('browser');

  const ProviderChallengeMode(this.value);

  final String value;

  static ProviderChallengeMode? fromJson(String? raw) {
    for (final mode in values) {
      if (mode.value == raw) {
        return mode;
      }
    }
    return null;
  }
}

enum ArtifactFamily {
  genericTurn('generic_turn'),
  conferenceRoom('conference_room'),
  cameraStream('camera_stream');

  const ArtifactFamily(this.value);

  final String value;

  static ArtifactFamily? fromJson(String? raw) {
    for (final family in values) {
      if (family.value == raw) {
        return family;
      }
    }
    return null;
  }
}

extension ArtifactFamilyDisplay on ArtifactFamily {
  String get label => switch (this) {
    ArtifactFamily.genericTurn => 'Generic TURN',
    ArtifactFamily.conferenceRoom => 'Conference room',
    ArtifactFamily.cameraStream => 'Camera stream',
  };
}

enum ArtifactAction {
  startOnThisDevice('start_on_this_device'),
  exportHandoff('export_handoff'),
  openRoom('open_room'),
  openCamera('open_camera'),
  openArchive('open_archive');

  const ArtifactAction(this.value);

  final String value;

  static ArtifactAction? fromJson(String? raw) {
    for (final action in values) {
      if (action.value == raw) {
        return action;
      }
    }
    return null;
  }
}

extension ArtifactActionDisplay on ArtifactAction {
  String get label => switch (this) {
    ArtifactAction.startOnThisDevice => 'Start on this device',
    ArtifactAction.exportHandoff => 'Export handoff',
    ArtifactAction.openRoom => 'Open room',
    ArtifactAction.openCamera => 'Open camera',
    ArtifactAction.openArchive => 'Open archive',
  };
}

enum ActionExecutionOwner {
  host('host'),
  shellLocal('shell_local'),
  shellExternal('shell_external');

  const ActionExecutionOwner(this.value);

  final String value;

  static ActionExecutionOwner fromJson(String? raw) {
    for (final owner in values) {
      if (owner.value == raw) {
        return owner;
      }
    }
    return ActionExecutionOwner.host;
  }
}

class ArtifactRedactionPolicy {
  const ArtifactRedactionPolicy({
    this.ordinaryReads,
    this.events,
    this.diagnostics,
    this.persistedState,
  });

  factory ArtifactRedactionPolicy.fromJson(Map<String, dynamic> json) {
    return ArtifactRedactionPolicy(
      ordinaryReads: json['ordinary_reads'] as String?,
      events: json['events'] as String?,
      diagnostics: json['diagnostics'] as String?,
      persistedState: json['persisted_state'] as String?,
    );
  }

  final String? ordinaryReads;
  final String? events;
  final String? diagnostics;
  final String? persistedState;
}

class ProviderCapabilityHints {
  const ProviderCapabilityHints({
    this.potentialActions = const <ArtifactAction>[],
    this.redactionPolicy = const ArtifactRedactionPolicy(),
  });

  factory ProviderCapabilityHints.fromJson(Map<String, dynamic> json) {
    return ProviderCapabilityHints(
      potentialActions:
          (json['potential_actions'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic raw) => ArtifactAction.fromJson(raw as String?))
              .whereType<ArtifactAction>()
              .toList(growable: false),
      redactionPolicy: json['redaction_policy'] is Map<String, dynamic>
          ? ArtifactRedactionPolicy.fromJson(
              json['redaction_policy'] as Map<String, dynamic>,
            )
          : const ArtifactRedactionPolicy(),
    );
  }

  final List<ArtifactAction> potentialActions;
  final ArtifactRedactionPolicy redactionPolicy;
}

class ProviderDescriptor {
  const ProviderDescriptor({
    required this.id,
    required this.displayName,
    required this.inputKind,
    required this.authPosture,
    required this.browserPolicy,
    this.description = '',
    this.challengeModes = const <ProviderChallengeMode>[],
    this.artifactFamilies = const <ArtifactFamily>[],
    this.capabilityHints = const ProviderCapabilityHints(),
  });

  factory ProviderDescriptor.fromJson(Map<String, dynamic> json) {
    return ProviderDescriptor(
      id: json['id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      inputKind: ProviderInputKind.fromJson(json['input_kind'] as String?),
      authPosture: ProviderAuthPosture.fromJson(
        json['auth_posture'] as String?,
      ),
      browserPolicy: ProviderBrowserPolicy.fromJson(
        json['browser_policy'] as String?,
      ),
      challengeModes:
          (json['challenge_modes'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (dynamic raw) => ProviderChallengeMode.fromJson(raw as String?),
              )
              .whereType<ProviderChallengeMode>()
              .toList(growable: false),
      artifactFamilies:
          (json['artifact_families'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic raw) => ArtifactFamily.fromJson(raw as String?))
              .whereType<ArtifactFamily>()
              .toList(growable: false),
      capabilityHints: json['capability_hints'] is Map<String, dynamic>
          ? ProviderCapabilityHints.fromJson(
              json['capability_hints'] as Map<String, dynamic>,
            )
          : const ProviderCapabilityHints(),
    );
  }

  final String id;
  final String displayName;
  final String description;
  final ProviderInputKind inputKind;
  final ProviderAuthPosture authPosture;
  final ProviderBrowserPolicy browserPolicy;
  final List<ProviderChallengeMode> challengeModes;
  final List<ArtifactFamily> artifactFamilies;
  final ProviderCapabilityHints capabilityHints;

  bool get mayRequireBrowserContinuation =>
      challengeModes.contains(ProviderChallengeMode.browser);
}

class ProviderInputEnvelope {
  const ProviderInputEnvelope({required this.kind, this.link = ''});

  final ProviderInputKind kind;
  final String link;

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'kind': kind.value,
      'link': link.isEmpty ? null : link,
    });
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

enum ResolutionState {
  starting('starting'),
  challengeRequired('challenge_required'),
  resolved('resolved'),
  failed('failed'),
  cancelled('cancelled'),
  expired('expired');

  const ResolutionState(this.value);

  final String value;

  static ResolutionState? fromJson(String? raw) {
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
  resolutionStarting('resolution_starting'),
  resolutionResolved('resolution_resolved'),
  resolutionFailed('resolution_failed'),
  resolutionCancelled('resolution_cancelled'),
  resolutionExpired('resolution_expired'),
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

enum PlatformTunnelMode {
  androidVpnService('android_vpn_service'),
  appleNetworkExtension('apple_network_extension'),
  windowsWintun('windows_wintun'),
  linuxTun('linux_tun');

  const PlatformTunnelMode(this.value);

  final String value;

  static PlatformTunnelMode? fromJson(String? raw) {
    for (final mode in values) {
      if (mode.value == raw) {
        return mode;
      }
    }
    return null;
  }
}

extension PlatformTunnelModeDisplay on PlatformTunnelMode {
  String get label => switch (this) {
    PlatformTunnelMode.androidVpnService => 'Android VPN Service',
    PlatformTunnelMode.appleNetworkExtension => 'Apple Network Extension',
    PlatformTunnelMode.windowsWintun => 'Windows Wintun',
    PlatformTunnelMode.linuxTun => 'Linux TUN',
  };
}

enum PlatformTunnelPrerequisite {
  permission('permission'),
  entitlement('entitlement'),
  privilegedExtension('privileged_extension'),
  driver('driver'),
  routeExclusion('route_exclusion'),
  dnsBypass('dns_bypass'),
  hostImplementation('host_implementation');

  const PlatformTunnelPrerequisite(this.value);

  final String value;

  static PlatformTunnelPrerequisite? fromJson(String? raw) {
    for (final prerequisite in values) {
      if (prerequisite.value == raw) {
        return prerequisite;
      }
    }
    return null;
  }
}

extension PlatformTunnelPrerequisiteDisplay on PlatformTunnelPrerequisite {
  String get label => switch (this) {
    PlatformTunnelPrerequisite.permission => 'permission',
    PlatformTunnelPrerequisite.entitlement => 'entitlement',
    PlatformTunnelPrerequisite.privilegedExtension => 'privileged extension',
    PlatformTunnelPrerequisite.driver => 'driver',
    PlatformTunnelPrerequisite.routeExclusion => 'route exclusion',
    PlatformTunnelPrerequisite.dnsBypass => 'DNS bypass',
    PlatformTunnelPrerequisite.hostImplementation => 'host implementation',
  };
}

enum PlatformTunnelStartupStage {
  capabilityCheck('capability_check'),
  permissionAcquire('permission_acquire'),
  entitlementAcquire('entitlement_acquire'),
  driverCheck('driver_check'),
  routeValidate('route_validate'),
  hostBringup('host_bringup'),
  runtimeAttach('runtime_attach');

  const PlatformTunnelStartupStage(this.value);

  final String value;

  static PlatformTunnelStartupStage? fromJson(String? raw) {
    for (final stage in values) {
      if (stage.value == raw) {
        return stage;
      }
    }
    return null;
  }
}

extension PlatformTunnelStartupStageDisplay on PlatformTunnelStartupStage {
  String get label => switch (this) {
    PlatformTunnelStartupStage.capabilityCheck => 'Capability check',
    PlatformTunnelStartupStage.permissionAcquire => 'Permission acquire',
    PlatformTunnelStartupStage.entitlementAcquire => 'Entitlement acquire',
    PlatformTunnelStartupStage.driverCheck => 'Driver check',
    PlatformTunnelStartupStage.routeValidate => 'Route validation',
    PlatformTunnelStartupStage.hostBringup => 'Host bring-up',
    PlatformTunnelStartupStage.runtimeAttach => 'Runtime attach',
  };
}

class BuildIdentity {
  const BuildIdentity({
    required this.product,
    required this.version,
    required this.buildNumber,
    this.revision = '',
    this.dirty = false,
    this.builtAt = '',
    this.role = '',
    this.target = '',
  });

  static const BuildIdentity unknown = BuildIdentity(
    product: 'vk-turn-proxy-go',
    version: 'unknown',
    buildNumber: '0',
  );

  factory BuildIdentity.fromJson(Map<String, dynamic> json) {
    return BuildIdentity(
      product: json['product'] as String? ?? 'vk-turn-proxy-go',
      version: json['version'] as String? ?? 'unknown',
      buildNumber: '${json['build_number'] ?? '0'}',
      revision: json['revision'] as String? ?? '',
      dirty: json['dirty'] as bool? ?? false,
      builtAt: json['built_at'] as String? ?? '',
      role: json['role'] as String? ?? '',
      target: json['target'] as String? ?? '',
    );
  }

  final String product;
  final String version;
  final String buildNumber;
  final String revision;
  final bool dirty;
  final String builtAt;
  final String role;
  final String target;

  bool get isKnown => version.isNotEmpty && version != 'unknown';

  String get versionLabel => '$version+$buildNumber';

  String get shortLabel {
    final buffer = StringBuffer(versionLabel);
    if (revision.isNotEmpty) {
      buffer.write(' @$revision');
      if (dirty) {
        buffer.write('*');
      }
    }
    return buffer.toString();
  }

  BuildIdentity copyWith({
    String? product,
    String? version,
    String? buildNumber,
    String? revision,
    bool? dirty,
    String? builtAt,
    String? role,
    String? target,
  }) {
    return BuildIdentity(
      product: product ?? this.product,
      version: version ?? this.version,
      buildNumber: buildNumber ?? this.buildNumber,
      revision: revision ?? this.revision,
      dirty: dirty ?? this.dirty,
      builtAt: builtAt ?? this.builtAt,
      role: role ?? this.role,
      target: target ?? this.target,
    );
  }

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'product': product,
      'version': version,
      'build_number': buildNumber,
      'revision': revision.isEmpty ? null : revision,
      'dirty': dirty ? true : null,
      'built_at': builtAt.isEmpty ? null : builtAt,
      'role': role.isEmpty ? null : role,
      'target': target.isEmpty ? null : target,
    });
  }
}

class HostInfo {
  const HostInfo({
    required this.contractVersion,
    required this.build,
    required this.capabilities,
    this.platformTunnels = const <PlatformTunnelCapability>[],
  });

  factory HostInfo.fromJson(Map<String, dynamic> json) {
    final capabilities = (json['capabilities'] as List<dynamic>? ?? const [])
        .map((dynamic raw) => Capability.fromJson(raw as String? ?? ''))
        .whereType<Capability>()
        .toList(growable: false);
    final platformTunnels = _readPlatformTunnels(
      json['platform_tunnels'],
      capabilities,
    );
    return HostInfo(
      contractVersion:
          json['contract_version'] as String? ??
          json['version'] as String? ??
          '',
      build: json['build'] is Map<String, dynamic>
          ? BuildIdentity.fromJson(json['build'] as Map<String, dynamic>)
          : BuildIdentity.unknown,
      capabilities: capabilities,
      platformTunnels: platformTunnels,
    );
  }

  final String contractVersion;
  final BuildIdentity build;
  final List<Capability> capabilities;
  final List<PlatformTunnelCapability> platformTunnels;

  String get version => contractVersion;
}

class PlatformTunnelCapability {
  const PlatformTunnelCapability({
    required this.mode,
    required this.available,
    this.satisfiedPrerequisites = const <PlatformTunnelPrerequisite>[],
    this.missingPrerequisite,
    this.message = '',
  });

  factory PlatformTunnelCapability.fromJson(Map<String, dynamic> json) {
    final mode = _requirePlatformTunnelMode(json['mode']);
    final available = json['available'] as bool? ?? false;
    final satisfiedPrerequisites = _readSatisfiedPrerequisites(
      json['satisfied_prerequisites'],
    );
    final missingPrerequisite = _readOptionalPlatformTunnelPrerequisite(
      json['missing_prerequisite'],
      fieldName: 'missing_prerequisite',
    );
    if (available && satisfiedPrerequisites.isEmpty) {
      throw FormatException(
        'platform tunnel mode ${mode.value} is available but missing satisfied_prerequisites',
      );
    }
    if (available && missingPrerequisite != null) {
      throw FormatException(
        'platform tunnel mode ${mode.value} is available but still reports missing_prerequisite',
      );
    }
    return PlatformTunnelCapability(
      mode: mode,
      available: available,
      satisfiedPrerequisites: satisfiedPrerequisites,
      missingPrerequisite: missingPrerequisite,
      message: json['message'] as String? ?? '',
    );
  }

  final PlatformTunnelMode mode;
  final bool available;
  final List<PlatformTunnelPrerequisite> satisfiedPrerequisites;
  final PlatformTunnelPrerequisite? missingPrerequisite;
  final String message;

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'mode': mode.value,
      'available': available,
      'satisfied_prerequisites': satisfiedPrerequisites
          .map((PlatformTunnelPrerequisite prerequisite) => prerequisite.value)
          .toList(growable: false),
      'missing_prerequisite': missingPrerequisite?.value,
      'message': message.isEmpty ? null : message,
    });
  }
}

class PlatformTunnelStartResult {
  const PlatformTunnelStartResult({
    required this.mode,
    required this.ready,
    this.stage,
    this.missingPrerequisite,
    this.message = '',
  });

  factory PlatformTunnelStartResult.fromJson(Map<String, dynamic> json) {
    final mode = _requirePlatformTunnelMode(json['mode']);
    final ready = json['ready'] as bool? ?? false;
    final stage = _readOptionalPlatformTunnelStage(
      json['stage'],
      fieldName: 'stage',
    );
    final missingPrerequisite = _readOptionalPlatformTunnelPrerequisite(
      json['missing_prerequisite'],
      fieldName: 'missing_prerequisite',
    );
    if (!ready && stage == null) {
      throw const FormatException(
        'platform tunnel startup result missing failure stage',
      );
    }
    if (!ready && missingPrerequisite == null) {
      throw const FormatException(
        'platform tunnel startup result missing failing prerequisite',
      );
    }
    if (ready && missingPrerequisite != null) {
      throw const FormatException(
        'ready platform tunnel startup result unexpectedly reports missing_prerequisite',
      );
    }
    return PlatformTunnelStartResult(
      mode: mode,
      ready: ready,
      stage: stage,
      missingPrerequisite: missingPrerequisite,
      message: json['message'] as String? ?? '',
    );
  }

  final PlatformTunnelMode mode;
  final bool ready;
  final PlatformTunnelStartupStage? stage;
  final PlatformTunnelPrerequisite? missingPrerequisite;
  final String message;

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'mode': mode.value,
      'ready': ready,
      'stage': stage?.value,
      'missing_prerequisite': missingPrerequisite?.value,
      'message': message.isEmpty ? null : message,
    });
  }
}

class FailureInfo {
  const FailureInfo({this.stage, this.message, this.notImplemented = false});

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
      spec: ProfileSpec.fromJson(
        json['spec'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
    );
  }

  final String id;
  final String name;
  final ProfileSpec spec;

  ProfileRecord copyWith({String? id, String? name, ProfileSpec? spec}) {
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

class RuntimeDefaults {
  const RuntimeDefaults({
    required this.listenAddress,
    required this.peerAddress,
    this.connections = 1,
    this.turnServer,
    this.turnPort,
    this.bindInterface,
    this.mode = TransportMode.auto,
    this.useDtls = true,
    this.logLevel = 'info',
  });

  factory RuntimeDefaults.fromProfileSpec(ProfileSpec spec) {
    return RuntimeDefaults(
      listenAddress: spec.listenAddress,
      peerAddress: spec.peerAddress,
      connections: spec.connections,
      turnServer: spec.turnServer,
      turnPort: spec.turnPort,
      bindInterface: spec.bindInterface,
      mode: spec.mode,
      useDtls: spec.useDtls,
      logLevel: spec.logLevel,
    );
  }

  final String listenAddress;
  final String peerAddress;
  final int connections;
  final String? turnServer;
  final String? turnPort;
  final String? bindInterface;
  final TransportMode mode;
  final bool useDtls;
  final String logLevel;

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'listen_addr': listenAddress,
      'peer_addr': peerAddress,
      'connections': connections,
      'turn_server': turnServer,
      'turn_port': turnPort,
      'bind_interface': bindInterface,
      'mode': mode.value,
      'use_dtls': useDtls,
      'log_level': logLevel,
    });
  }
}

class ResolutionInput {
  const ResolutionInput({
    required this.provider,
    this.kind = ProviderInputKind.link,
    this.linkRedacted = '',
    this.interactiveProvider = false,
  });

  factory ResolutionInput.fromJson(Map<String, dynamic> json) {
    return ResolutionInput(
      provider: json['provider'] as String? ?? '',
      kind: ProviderInputKind.fromJson(json['kind'] as String?),
      linkRedacted: json['link_redacted'] as String? ?? '',
      interactiveProvider: json['interactive_provider'] as bool? ?? false,
    );
  }

  final String provider;
  final ProviderInputKind kind;
  final String linkRedacted;
  final bool interactiveProvider;

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'provider': provider,
      'kind': kind.value,
      'link_redacted': linkRedacted.isEmpty ? null : linkRedacted,
      'interactive_provider': interactiveProvider ? true : null,
    });
  }
}

class ResolutionActionRecord {
  const ResolutionActionRecord({
    required this.id,
    required this.executionOwner,
  });

  factory ResolutionActionRecord.fromJson(Map<String, dynamic> json) {
    return ResolutionActionRecord(
      id:
          ArtifactAction.fromJson(json['id'] as String?) ??
          ArtifactAction.exportHandoff,
      executionOwner: ActionExecutionOwner.fromJson(
        json['execution_owner'] as String?,
      ),
    );
  }

  final ArtifactAction id;
  final ActionExecutionOwner executionOwner;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id.value,
      'execution_owner': executionOwner.value,
    };
  }
}

class ConferenceRoomArtifactSummary {
  const ConferenceRoomArtifactSummary({required this.roomUrl});

  factory ConferenceRoomArtifactSummary.fromJson(Map<String, dynamic> json) {
    return ConferenceRoomArtifactSummary(
      roomUrl: json['room_url'] as String? ?? '',
    );
  }

  final String roomUrl;

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{'room_url': roomUrl});
  }
}

class CameraStreamArtifactSummary {
  const CameraStreamArtifactSummary({
    this.cameraUrl = '',
    this.archiveUrl = '',
  });

  factory CameraStreamArtifactSummary.fromJson(Map<String, dynamic> json) {
    return CameraStreamArtifactSummary(
      cameraUrl: json['camera_url'] as String? ?? '',
      archiveUrl: json['archive_url'] as String? ?? '',
    );
  }

  final String cameraUrl;
  final String archiveUrl;

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'camera_url': cameraUrl.isEmpty ? null : cameraUrl,
      'archive_url': archiveUrl.isEmpty ? null : archiveUrl,
    });
  }
}

class ResolutionArtifactSummary {
  const ResolutionArtifactSummary({
    this.genericTurn,
    this.conferenceRoom,
    this.cameraStream,
  });

  factory ResolutionArtifactSummary.fromJson(Map<String, dynamic> json) {
    return ResolutionArtifactSummary(
      genericTurn: json['generic_turn'] is Map<String, dynamic>
          ? ResolutionCredentials.fromJson(
              json['generic_turn'] as Map<String, dynamic>,
            )
          : null,
      conferenceRoom: json['conference_room'] is Map<String, dynamic>
          ? ConferenceRoomArtifactSummary.fromJson(
              json['conference_room'] as Map<String, dynamic>,
            )
          : null,
      cameraStream: json['camera_stream'] is Map<String, dynamic>
          ? CameraStreamArtifactSummary.fromJson(
              json['camera_stream'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  final ResolutionCredentials? genericTurn;
  final ConferenceRoomArtifactSummary? conferenceRoom;
  final CameraStreamArtifactSummary? cameraStream;

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'generic_turn': genericTurn?.toJson(),
      'conference_room': conferenceRoom?.toJson(),
      'camera_stream': cameraStream?.toJson(),
    });
  }
}

class ResolutionArtifactRecord {
  const ResolutionArtifactRecord({
    required this.family,
    this.actions = const <ResolutionActionRecord>[],
    this.summary = const ResolutionArtifactSummary(),
  });

  factory ResolutionArtifactRecord.fromJson(Map<String, dynamic> json) {
    return ResolutionArtifactRecord(
      family:
          ArtifactFamily.fromJson(json['family'] as String?) ??
          ArtifactFamily.genericTurn,
      actions: (json['actions'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (dynamic entry) =>
                ResolutionActionRecord.fromJson(entry as Map<String, dynamic>),
          )
          .toList(growable: false),
      summary: json['summary'] is Map<String, dynamic>
          ? ResolutionArtifactSummary.fromJson(
              json['summary'] as Map<String, dynamic>,
            )
          : const ResolutionArtifactSummary(),
    );
  }

  final ArtifactFamily family;
  final List<ResolutionActionRecord> actions;
  final ResolutionArtifactSummary summary;

  bool supports(ArtifactAction action) =>
      actions.any((ResolutionActionRecord candidate) => candidate.id == action);

  ResolutionActionRecord? action(ArtifactAction action) {
    for (final candidate in actions) {
      if (candidate.id == action) {
        return candidate;
      }
    }
    return null;
  }

  String? externalTargetUrl(ArtifactAction action) {
    return switch (action) {
      ArtifactAction.openRoom => _nonEmpty(summary.conferenceRoom?.roomUrl),
      ArtifactAction.openCamera => _nonEmpty(summary.cameraStream?.cameraUrl),
      ArtifactAction.openArchive => _nonEmpty(summary.cameraStream?.archiveUrl),
      _ => null,
    };
  }

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'family': family.value,
      'actions': actions
          .map((ResolutionActionRecord item) => item.toJson())
          .toList(growable: false),
      'summary': summary.toJson(),
    });
  }
}

class ResolutionCredentials {
  const ResolutionCredentials({
    required this.address,
    this.usernameRedacted = '',
    this.passwordRedacted = '',
  });

  factory ResolutionCredentials.fromJson(Map<String, dynamic> json) {
    return ResolutionCredentials(
      address: json['address'] as String? ?? '',
      usernameRedacted: json['username_redacted'] as String? ?? '',
      passwordRedacted: json['password_redacted'] as String? ?? '',
    );
  }

  final String address;
  final String usernameRedacted;
  final String passwordRedacted;

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'address': address,
      'username_redacted': usernameRedacted.isEmpty ? null : usernameRedacted,
      'password_redacted': passwordRedacted.isEmpty ? null : passwordRedacted,
    });
  }
}

class ResolutionExportStatus {
  const ResolutionExportStatus({
    required this.supported,
    this.expiresAt,
    this.expirySource,
  });

  factory ResolutionExportStatus.fromJson(Map<String, dynamic> json) {
    return ResolutionExportStatus(
      supported: json['supported'] as bool? ?? false,
      expiresAt: json['expires_at'] == null
          ? null
          : _readTimestamp(json['expires_at']),
      expirySource: json['expiry_source'] as String?,
    );
  }

  final bool supported;
  final DateTime? expiresAt;
  final String? expirySource;

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'supported': supported,
      'expires_at': expiresAt?.toUtc().toIso8601String(),
      'expiry_source': expirySource,
    });
  }
}

class ResolutionRecord {
  const ResolutionRecord({
    required this.id,
    required this.provider,
    required this.input,
    required this.state,
    required this.export,
    required this.startedAt,
    required this.updatedAt,
    this.resolutionMethod,
    this.artifact,
    this.credentials,
    this.failure,
    this.activeChallengeId,
    this.resolvedAt,
    this.expiredAt,
  });

  factory ResolutionRecord.fromJson(Map<String, dynamic> json) {
    return ResolutionRecord(
      id: json['id'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      resolutionMethod: json['resolution_method'] as String?,
      input: ResolutionInput.fromJson(
        json['input'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      state:
          ResolutionState.fromJson(json['state'] as String?) ??
          ResolutionState.starting,
      artifact: json['artifact'] is Map<String, dynamic>
          ? ResolutionArtifactRecord.fromJson(
              json['artifact'] as Map<String, dynamic>,
            )
          : null,
      credentials: json['credentials'] is Map<String, dynamic>
          ? ResolutionCredentials.fromJson(
              json['credentials'] as Map<String, dynamic>,
            )
          : null,
      export: ResolutionExportStatus.fromJson(
        json['export'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      failure: json['failure'] is Map<String, dynamic>
          ? FailureInfo.fromJson(json['failure'] as Map<String, dynamic>)
          : null,
      activeChallengeId: json['active_challenge_id'] as String?,
      startedAt: _readTimestamp(json['started_at']),
      updatedAt: _readTimestamp(json['updated_at']),
      resolvedAt: json['resolved_at'] == null
          ? null
          : _readTimestamp(json['resolved_at']),
      expiredAt: json['expired_at'] == null
          ? null
          : _readTimestamp(json['expired_at']),
    );
  }

  final String id;
  final String provider;
  final String? resolutionMethod;
  final ResolutionInput input;
  final ResolutionState state;
  final ResolutionArtifactRecord? artifact;
  final ResolutionCredentials? credentials;
  final ResolutionExportStatus export;
  final FailureInfo? failure;
  final String? activeChallengeId;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final DateTime? expiredAt;

  bool get isTerminal => switch (state) {
    ResolutionState.failed ||
    ResolutionState.cancelled ||
    ResolutionState.expired => true,
    _ => false,
  };

  bool supportsAction(ArtifactAction action) =>
      artifact?.supports(action) ?? false;

  String? externalTargetUrl(ArtifactAction action) =>
      artifact?.externalTargetUrl(action);

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'id': id,
      'provider': provider,
      'resolution_method': resolutionMethod,
      'input': input.toJson(),
      'state': state.value,
      'artifact': artifact?.toJson(),
      'credentials': credentials?.toJson(),
      'export': export.toJson(),
      'failure': failure?.toJson(),
      'active_challenge_id': activeChallengeId,
      'started_at': startedAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'resolved_at': resolvedAt?.toUtc().toIso8601String(),
      'expired_at': expiredAt?.toUtc().toIso8601String(),
    });
  }
}

class ResolutionExportResult {
  const ResolutionExportResult({
    required this.resolutionId,
    required this.link,
    required this.expiresAt,
    this.expirySource,
  });

  factory ResolutionExportResult.fromJson(Map<String, dynamic> json) {
    return ResolutionExportResult(
      resolutionId: json['resolution_id'] as String? ?? '',
      link: json['link'] as String? ?? '',
      expiresAt: _readTimestamp(json['expires_at']),
      expirySource: json['expiry_source'] as String?,
    );
  }

  final String resolutionId;
  final String link;
  final DateTime expiresAt;
  final String? expirySource;
}

class ChallengeRecord {
  const ChallengeRecord({
    required this.id,
    required this.sessionId,
    this.resolutionId,
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
      resolutionId: json['resolution_id'] as String?,
      provider: json['provider'] as String? ?? '',
      stage: json['stage'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      prompt: json['prompt'] as String?,
      openUrl: json['open_url'] as String?,
      status:
          ChallengeStatus.fromJson(json['status'] as String?) ??
          ChallengeStatus.pending,
      createdAt: _readTimestamp(json['created_at']),
      updatedAt: _readTimestamp(json['updated_at']),
    );
  }

  final String id;
  final String sessionId;
  final String? resolutionId;
  final String provider;
  final String stage;
  final String kind;
  final String? prompt;
  final String? openUrl;
  final ChallengeStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChallengeRecord copyWith({ChallengeStatus? status, DateTime? updatedAt}) {
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
      'resolution_id': resolutionId,
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
    this.sourceResolutionId,
    this.failure,
    this.activeChallengeId,
    this.stoppedAt,
  });

  factory SessionRecord.fromJson(Map<String, dynamic> json) {
    return SessionRecord(
      id: json['id'] as String? ?? '',
      profileId: json['profile_id'] as String?,
      profileName: json['profile_name'] as String?,
      sourceResolutionId: json['source_resolution_id'] as String?,
      profile: ProfileSpec.fromJson(
        json['profile'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      state:
          SessionState.fromJson(json['state'] as String?) ??
          SessionState.starting,
      failure: json['failure'] is Map<String, dynamic>
          ? FailureInfo.fromJson(json['failure'] as Map<String, dynamic>)
          : null,
      activeChallengeId: json['active_challenge_id'] as String?,
      startedAt: _readTimestamp(json['started_at']),
      updatedAt: _readTimestamp(json['updated_at']),
      stoppedAt: json['stopped_at'] == null
          ? null
          : _readTimestamp(json['stopped_at']),
    );
  }

  final String id;
  final String? profileId;
  final String? profileName;
  final String? sourceResolutionId;
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
      'source_resolution_id': sourceResolutionId,
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
    this.resolutionId,
    this.state,
    this.resolutionState,
    this.stage,
    this.message,
    this.connections,
    this.readyWorkers,
    this.restart,
    this.backoff,
    this.challenge,
    this.artifact,
  });

  factory EventRecord.fromJson(Map<String, dynamic> json) {
    return EventRecord(
      id: json['id'] as String? ?? '',
      timestamp: _readTimestamp(json['timestamp']),
      sessionId: json['session_id'] as String? ?? '',
      resolutionId: json['resolution_id'] as String?,
      type:
          EventType.fromJson(json['type'] as String?) ??
          EventType.sessionStarting,
      state: SessionState.fromJson(json['state'] as String?),
      resolutionState: ResolutionState.fromJson(
        json['resolution_state'] as String?,
      ),
      stage: json['stage'] as String?,
      message: json['message'] as String?,
      connections: json['connections'] as int?,
      readyWorkers: json['ready_workers'] as int?,
      restart: json['restart'] as int?,
      backoff: json['backoff'] as String?,
      challenge: json['challenge'] is Map<String, dynamic>
          ? ChallengeRecord.fromJson(json['challenge'] as Map<String, dynamic>)
          : null,
      artifact: json['artifact'] is Map<String, dynamic>
          ? ResolutionArtifactRecord.fromJson(
              json['artifact'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  final String id;
  final DateTime timestamp;
  final String sessionId;
  final String? resolutionId;
  final EventType type;
  final SessionState? state;
  final ResolutionState? resolutionState;
  final String? stage;
  final String? message;
  final int? connections;
  final int? readyWorkers;
  final int? restart;
  final String? backoff;
  final ChallengeRecord? challenge;
  final ResolutionArtifactRecord? artifact;

  String summary() {
    final buffer = StringBuffer(type.value);
    if (state != null) {
      buffer.write(' -> ${state!.value}');
    }
    if (resolutionState != null) {
      buffer.write(' -> ${resolutionState!.value}');
    }
    if (stage != null && stage!.isNotEmpty) {
      buffer.write(' @ $stage');
    }
    if (message != null && message!.isNotEmpty) {
      buffer.write(' | $message');
    }
    if (challenge != null) {
      buffer.write(
        ' | challenge=${challenge!.kind}/${challenge!.status.value}',
      );
    }
    return buffer.toString();
  }

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'id': id,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'session_id': sessionId,
      'resolution_id': resolutionId,
      'type': type.value,
      'state': state?.value,
      'resolution_state': resolutionState?.value,
      'stage': stage,
      'message': message,
      'connections': connections,
      'ready_workers': readyWorkers,
      'restart': restart,
      'backoff': backoff,
      'challenge': challenge?.toJson(),
      'artifact': artifact?.toJson(),
    });
  }
}

class DiagnosticsBundle {
  const DiagnosticsBundle({
    required this.session,
    required this.events,
    required this.challenges,
    required this.metrics,
    this.guiBuild,
    this.hostBuild = BuildIdentity.unknown,
    this.contractVersion = '',
  });

  factory DiagnosticsBundle.fromJson(Map<String, dynamic> json) {
    return DiagnosticsBundle(
      session: SessionRecord.fromJson(
        json['session'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      events: (json['events'] as List<dynamic>? ?? const [])
          .map(
            (dynamic raw) => EventRecord.fromJson(raw as Map<String, dynamic>),
          )
          .toList(growable: false),
      challenges: (json['challenges'] as List<dynamic>? ?? const [])
          .map(
            (dynamic raw) =>
                ChallengeRecord.fromJson(raw as Map<String, dynamic>),
          )
          .toList(growable: false),
      metrics: json['metrics'] as String? ?? '',
      guiBuild: json['gui_build'] is Map<String, dynamic>
          ? BuildIdentity.fromJson(json['gui_build'] as Map<String, dynamic>)
          : null,
      hostBuild: json['host_build'] is Map<String, dynamic>
          ? BuildIdentity.fromJson(json['host_build'] as Map<String, dynamic>)
          : BuildIdentity.unknown,
      contractVersion: json['contract_version'] as String? ?? '',
    );
  }

  final SessionRecord session;
  final List<EventRecord> events;
  final List<ChallengeRecord> challenges;
  final String metrics;
  final BuildIdentity? guiBuild;
  final BuildIdentity hostBuild;
  final String contractVersion;

  DiagnosticsBundle copyWith({
    SessionRecord? session,
    List<EventRecord>? events,
    List<ChallengeRecord>? challenges,
    String? metrics,
    BuildIdentity? guiBuild,
    bool clearGuiBuild = false,
    BuildIdentity? hostBuild,
    String? contractVersion,
  }) {
    return DiagnosticsBundle(
      session: session ?? this.session,
      events: events ?? this.events,
      challenges: challenges ?? this.challenges,
      metrics: metrics ?? this.metrics,
      guiBuild: clearGuiBuild ? null : (guiBuild ?? this.guiBuild),
      hostBuild: hostBuild ?? this.hostBuild,
      contractVersion: contractVersion ?? this.contractVersion,
    );
  }

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'session': session.toJson(),
      'events': events.map((event) => event.toJson()).toList(growable: false),
      'challenges': challenges
          .map((challenge) => challenge.toJson())
          .toList(growable: false),
      'metrics': metrics,
      'gui_build': guiBuild?.toJson(),
      'host_build': hostBuild.toJson(),
      'contract_version': contractVersion.isEmpty ? null : contractVersion,
    });
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
    this.action,
    this.stage,
    this.notImplemented = false,
  });

  final int statusCode;
  final String code;
  final String message;
  final String? action;
  final String? stage;
  final bool notImplemented;

  bool get incompatibleHost => statusCode == 409 && code == 'incompatible_host';

  @override
  String toString() {
    return 'ControlPlaneError(status=$statusCode, code=$code, message=$message, action=$action, stage=$stage, notImplemented=$notImplemented)';
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

List<PlatformTunnelCapability> _readPlatformTunnels(
  dynamic raw,
  List<Capability> capabilities,
) {
  final values = raw as List<dynamic>? ?? const <dynamic>[];
  final platformTunnels = values
      .map((dynamic entry) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException(
            'platform_tunnels entries must be JSON objects',
          );
        }
        return PlatformTunnelCapability.fromJson(entry);
      })
      .toList(growable: false);
  if (capabilities.contains(Capability.platformTunnels) &&
      platformTunnels.isEmpty) {
    throw const FormatException(
      'host advertises platform_tunnels but omitted the mode report',
    );
  }
  for (final capability in platformTunnels) {
    if (!capability.available && capability.missingPrerequisite == null) {
      throw FormatException(
        'platform tunnel mode ${capability.mode.value} is unavailable but missing missing_prerequisite',
      );
    }
  }
  return platformTunnels;
}

PlatformTunnelMode _requirePlatformTunnelMode(dynamic raw) {
  final value = raw as String?;
  final mode = PlatformTunnelMode.fromJson(value);
  if (mode != null) {
    return mode;
  }
  throw FormatException(
    'invalid platform tunnel mode: ${value ?? '<missing>'}',
  );
}

List<PlatformTunnelPrerequisite> _readSatisfiedPrerequisites(dynamic raw) {
  final values = raw as List<dynamic>? ?? const <dynamic>[];
  return values
      .map((dynamic item) {
        if (item is! String) {
          throw const FormatException(
            'platform tunnel prerequisites must be string values',
          );
        }
        final prerequisite = PlatformTunnelPrerequisite.fromJson(item);
        if (prerequisite != null) {
          return prerequisite;
        }
        throw FormatException('invalid platform tunnel prerequisite: $item');
      })
      .toList(growable: false);
}

PlatformTunnelPrerequisite? _readOptionalPlatformTunnelPrerequisite(
  dynamic raw, {
  required String fieldName,
}) {
  final value = raw as String?;
  if (value == null || value.isEmpty) {
    return null;
  }
  final prerequisite = PlatformTunnelPrerequisite.fromJson(value);
  if (prerequisite != null) {
    return prerequisite;
  }
  throw FormatException('invalid $fieldName: $value');
}

PlatformTunnelStartupStage? _readOptionalPlatformTunnelStage(
  dynamic raw, {
  required String fieldName,
}) {
  final value = raw as String?;
  if (value == null || value.isEmpty) {
    return null;
  }
  final stage = PlatformTunnelStartupStage.fromJson(value);
  if (stage != null) {
    return stage;
  }
  throw FormatException('invalid $fieldName: $value');
}

String? _nonEmpty(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}
