enum RuntimeAccessMethod {
  turnCredentials('turn_credentials'),
  webrtcCallAttach('webrtc_call_attach');

  const RuntimeAccessMethod(this.value);

  final String value;

  static RuntimeAccessMethod? fromJson(String? raw) {
    for (final method in values) {
      if (method.value == raw) {
        return method;
      }
    }
    return null;
  }
}

enum RuntimeCarrierFamily {
  turnDatagram('turn_datagram'),
  turnDtlsOverlay('turn_dtls_overlay'),
  webrtcDataChannel('webrtc_datachannel');

  const RuntimeCarrierFamily(this.value);

  final String value;

  static RuntimeCarrierFamily? fromJson(String? raw) {
    for (final family in values) {
      if (family.value == raw) {
        return family;
      }
    }
    return null;
  }
}

enum RuntimeEngineFamily {
  wireguardNative('wireguard_native'),
  customPacketOverlay('custom_packet_overlay'),
  proxyCoreAdapter('proxy_core_adapter'),
  trusttunnelNative('trusttunnel_native');

  const RuntimeEngineFamily(this.value);

  final String value;

  static RuntimeEngineFamily? fromJson(String? raw) {
    for (final family in values) {
      if (family.value == raw) {
        return family;
      }
    }
    return null;
  }
}

enum RuntimeHostAdapter {
  androidVpnService('android_vpn_service'),
  appleNetworkExtension('apple_network_extension'),
  windowsWintun('windows_wintun'),
  linuxTun('linux_tun');

  const RuntimeHostAdapter(this.value);

  final String value;

  static RuntimeHostAdapter? fromJson(String? raw) {
    for (final adapter in values) {
      if (adapter.value == raw) {
        return adapter;
      }
    }
    return null;
  }
}

enum RuntimeExecutionPlanSupportState {
  supported('supported'),
  unavailable('unavailable'),
  experimental('experimental');

  const RuntimeExecutionPlanSupportState(this.value);

  final String value;

  static RuntimeExecutionPlanSupportState? fromJson(String? raw) {
    for (final state in values) {
      if (state.value == raw) {
        return state;
      }
    }
    return null;
  }
}

enum RuntimeRemoteEndpointFamily {
  turnServer('turn_server'),
  webrtcCallEndpoint('webrtc_call_endpoint'),
  httpsTunnelServer('https_tunnel_server');

  const RuntimeRemoteEndpointFamily(this.value);

  final String value;

  static RuntimeRemoteEndpointFamily? fromJson(String? raw) {
    for (final family in values) {
      if (family.value == raw) {
        return family;
      }
    }
    return null;
  }
}

enum TransportProfileKind {
  wireGuardNativeV1('wireguard_native_v1');

  const TransportProfileKind(this.value);

  final String value;

  static TransportProfileKind? fromJson(String? raw) {
    for (final kind in values) {
      if (kind.value == raw) {
        return kind;
      }
    }
    return null;
  }
}

enum TransportProfileImportAdapter {
  wireGuardConf('wireguard_conf');

  const TransportProfileImportAdapter(this.value);

  final String value;

  static TransportProfileImportAdapter? fromJson(String? raw) {
    for (final adapter in values) {
      if (adapter.value == raw) {
        return adapter;
      }
    }
    return null;
  }
}

enum TransportProfileLifecycleAction {
  list('list'),
  import('import'),
  replace('replace'),
  forget('forget'),
  validate('validate'),
  selectForStartup('select_for_startup');

  const TransportProfileLifecycleAction(this.value);

  final String value;

  static TransportProfileLifecycleAction? fromJson(String? raw) {
    for (final action in values) {
      if (action.value == raw) {
        return action;
      }
    }
    return null;
  }
}

enum TransportProfileValidationState {
  valid('valid'),
  invalid('invalid');

  const TransportProfileValidationState(this.value);

  final String value;

  static TransportProfileValidationState fromJson(String? raw) {
    for (final state in values) {
      if (state.value == raw) {
        return state;
      }
    }
    return TransportProfileValidationState.invalid;
  }
}

enum TransportProfileCompatibilityState {
  unknown('unknown'),
  compatible('compatible'),
  incompatible('incompatible');

  const TransportProfileCompatibilityState(this.value);

  final String value;

  static TransportProfileCompatibilityState fromJson(String? raw) {
    for (final state in values) {
      if (state.value == raw) {
        return state;
      }
    }
    return TransportProfileCompatibilityState.unknown;
  }
}

enum TransportProfileMaterialSource {
  importAdapter('import_adapter'),
  legacyPath('legacy_path');

  const TransportProfileMaterialSource(this.value);

  final String value;

  static TransportProfileMaterialSource fromJson(String? raw) {
    for (final source in values) {
      if (source.value == raw) {
        return source;
      }
    }
    return TransportProfileMaterialSource.importAdapter;
  }
}

class TransportProfileSecretMaterialRef {
  const TransportProfileSecretMaterialRef({
    required this.kind,
    required this.ref,
  });

  factory TransportProfileSecretMaterialRef.fromJson(
    Map<String, dynamic>? json,
  ) {
    return TransportProfileSecretMaterialRef(
      kind: TransportProfileMaterialSource.fromJson(json?['kind'] as String?),
      ref: json?['ref'] as String? ?? '',
    );
  }

  final TransportProfileMaterialSource kind;
  final String ref;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': kind.value,
      if (ref.isNotEmpty) 'ref': ref,
    };
  }
}

class TransportProfileValidationStatus {
  const TransportProfileValidationStatus({
    required this.state,
    this.message = '',
    this.fingerprint = '',
  });

  factory TransportProfileValidationStatus.fromJson(
    Map<String, dynamic>? json,
  ) {
    return TransportProfileValidationStatus(
      state: TransportProfileValidationState.fromJson(
        json?['state'] as String?,
      ),
      message: json?['message'] as String? ?? '',
      fingerprint: json?['fingerprint'] as String? ?? '',
    );
  }

  final TransportProfileValidationState state;
  final String message;
  final String fingerprint;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'state': state.value,
      if (message.isNotEmpty) 'message': message,
      if (fingerprint.isNotEmpty) 'fingerprint': fingerprint,
    };
  }
}

class TransportProfileCompatibilityStatus {
  const TransportProfileCompatibilityStatus({
    required this.state,
    this.message = '',
    this.compatibleExecutionPlans = const <RuntimeExecutionPlan>[],
  });

  factory TransportProfileCompatibilityStatus.fromJson(
    Map<String, dynamic>? json,
  ) {
    return TransportProfileCompatibilityStatus(
      state: TransportProfileCompatibilityState.fromJson(
        json?['state'] as String?,
      ),
      message: json?['message'] as String? ?? '',
      compatibleExecutionPlans:
          (json?['compatible_execution_plans'] as List<dynamic>? ??
                  const <dynamic>[])
              .map(
                (dynamic raw) =>
                    RuntimeExecutionPlan.fromJson(raw as Map<String, dynamic>),
              )
              .toList(growable: false),
    );
  }

  final TransportProfileCompatibilityState state;
  final String message;
  final List<RuntimeExecutionPlan> compatibleExecutionPlans;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'state': state.value,
      if (message.isNotEmpty) 'message': message,
      if (compatibleExecutionPlans.isNotEmpty)
        'compatible_execution_plans': compatibleExecutionPlans
            .map((RuntimeExecutionPlan plan) => plan.toJson())
            .toList(growable: false),
    };
  }
}

class TransportProfileReference {
  const TransportProfileReference({
    this.profileId = '',
    this.kind,
    this.useDefault = false,
    this.defaultScopeId = '',
  });

  factory TransportProfileReference.fromJson(Map<String, dynamic> json) {
    return TransportProfileReference(
      profileId: json['profile_id'] as String? ?? '',
      kind: TransportProfileKind.fromJson(json['kind'] as String?),
      useDefault: json['use_default'] as bool? ?? false,
      defaultScopeId: json['default_scope_id'] as String? ?? '',
    );
  }

  final String profileId;
  final TransportProfileKind? kind;
  final bool useDefault;
  final String defaultScopeId;

  bool get isEmpty => profileId.trim().isEmpty && !useDefault;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (profileId.trim().isNotEmpty) 'profile_id': profileId.trim(),
      if (kind != null) 'kind': kind!.value,
      if (useDefault) 'use_default': true,
      if (defaultScopeId.trim().isNotEmpty)
        'default_scope_id': defaultScopeId.trim(),
    };
  }
}

class TransportProfileDefaultBinding {
  const TransportProfileDefaultBinding({
    required this.profileId,
    required this.kind,
    required this.hostAdapter,
    required this.plan,
    required this.scopeId,
  });

  factory TransportProfileDefaultBinding.fromJson(Map<String, dynamic> json) {
    final kind = TransportProfileKind.fromJson(json['kind'] as String?);
    final hostAdapter = RuntimeHostAdapter.fromJson(
      json['host_adapter'] as String?,
    );
    if (kind == null || hostAdapter == null) {
      throw const FormatException('transport profile default binding invalid');
    }
    return TransportProfileDefaultBinding(
      profileId: json['profile_id'] as String? ?? '',
      kind: kind,
      hostAdapter: hostAdapter,
      plan: RuntimeExecutionPlan.fromJson(json['plan'] as Map<String, dynamic>),
      scopeId: json['scope_id'] as String? ?? '',
    );
  }

  final String profileId;
  final TransportProfileKind kind;
  final RuntimeHostAdapter hostAdapter;
  final RuntimeExecutionPlan plan;
  final String scopeId;
}

class TransportProfileStatus {
  const TransportProfileStatus({
    required this.id,
    required this.kind,
    required this.version,
    required this.validation,
    required this.compatibility,
    required this.secretMaterialRef,
    required this.importedAt,
    required this.updatedAt,
    this.displayName = '',
    this.actions = const <TransportProfileLifecycleAction>[],
    this.defaultFor = const <TransportProfileDefaultBinding>[],
  });

  factory TransportProfileStatus.fromJson(Map<String, dynamic> json) {
    final kind = TransportProfileKind.fromJson(json['kind'] as String?);
    if (kind == null) {
      throw const FormatException('transport profile status missing kind');
    }
    return TransportProfileStatus(
      id: json['id'] as String? ?? '',
      kind: kind,
      version: json['version'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      validation: TransportProfileValidationStatus.fromJson(
        json['validation'] as Map<String, dynamic>?,
      ),
      compatibility: TransportProfileCompatibilityStatus.fromJson(
        json['compatibility'] as Map<String, dynamic>?,
      ),
      secretMaterialRef: TransportProfileSecretMaterialRef.fromJson(
        json['secret_material_ref'] as Map<String, dynamic>?,
      ),
      actions: _readTransportProfileLifecycleActions(json['actions']),
      defaultFor: (json['default_for'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (dynamic raw) => TransportProfileDefaultBinding.fromJson(
              raw as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      importedAt: _readDateTime(json['imported_at']),
      updatedAt: _readDateTime(json['updated_at']),
    );
  }

  final String id;
  final TransportProfileKind kind;
  final String version;
  final String displayName;
  final TransportProfileValidationStatus validation;
  final TransportProfileCompatibilityStatus compatibility;
  final TransportProfileSecretMaterialRef secretMaterialRef;
  final List<TransportProfileLifecycleAction> actions;
  final List<TransportProfileDefaultBinding> defaultFor;
  final DateTime importedAt;
  final DateTime updatedAt;

  bool get isUsable =>
      validation.state == TransportProfileValidationState.valid &&
      compatibility.state == TransportProfileCompatibilityState.compatible;
}

class TransportProfileImportAdapterDescriptor {
  const TransportProfileImportAdapterDescriptor({
    required this.id,
    required this.profileKind,
    this.displayName = '',
    this.extensions = const <String>[],
  });

  factory TransportProfileImportAdapterDescriptor.fromJson(
    Map<String, dynamic> json,
  ) {
    final id = TransportProfileImportAdapter.fromJson(json['id'] as String?);
    final profileKind = TransportProfileKind.fromJson(
      json['profile_kind'] as String?,
    );
    if (id == null || profileKind == null) {
      throw const FormatException('transport profile import adapter invalid');
    }
    return TransportProfileImportAdapterDescriptor(
      id: id,
      profileKind: profileKind,
      displayName: json['display_name'] as String? ?? '',
      extensions: (json['extensions'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
    );
  }

  final TransportProfileImportAdapter id;
  final TransportProfileKind profileKind;
  final String displayName;
  final List<String> extensions;
}

class TransportProfileStoreCapability {
  const TransportProfileStoreCapability({
    this.supportedKinds = const <TransportProfileKind>[],
    this.importAdapters = const <TransportProfileImportAdapterDescriptor>[],
    this.lifecycleActions = const <TransportProfileLifecycleAction>[],
    this.redactionGuarantees = const <String>[],
  });

  factory TransportProfileStoreCapability.fromJson(Map<String, dynamic> json) {
    return TransportProfileStoreCapability(
      supportedKinds: _readTransportProfileKinds(json['supported_kinds']),
      importAdapters:
          (json['import_adapters'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (dynamic raw) =>
                    TransportProfileImportAdapterDescriptor.fromJson(
                      raw as Map<String, dynamic>,
                    ),
              )
              .toList(growable: false),
      lifecycleActions: _readTransportProfileLifecycleActions(
        json['lifecycle_actions'],
      ),
      redactionGuarantees:
          (json['redaction_guarantees'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(growable: false),
    );
  }

  final List<TransportProfileKind> supportedKinds;
  final List<TransportProfileImportAdapterDescriptor> importAdapters;
  final List<TransportProfileLifecycleAction> lifecycleActions;
  final List<String> redactionGuarantees;
}

class TransportProfileImportRequest {
  const TransportProfileImportRequest({
    required this.adapter,
    required this.kind,
    required this.material,
    this.displayName = '',
    this.replaceProfileId = '',
    this.defaultFor,
  });

  final TransportProfileImportAdapter adapter;
  final TransportProfileKind kind;
  final String material;
  final String displayName;
  final String replaceProfileId;
  final RuntimeExecutionPlan? defaultFor;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'adapter': adapter.value,
      'kind': kind.value,
      if (displayName.trim().isNotEmpty) 'display_name': displayName.trim(),
      'material': material,
      if (replaceProfileId.trim().isNotEmpty)
        'replace_profile_id': replaceProfileId.trim(),
      if (defaultFor != null) 'default_for': defaultFor!.toJson(),
    };
  }
}

class TransportProfileSelectForStartupRequest {
  const TransportProfileSelectForStartupRequest({required this.plan});

  final RuntimeExecutionPlan plan;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'plan': plan.toJson()};
  }
}

class TransportProfilePrerequisiteStatus {
  const TransportProfilePrerequisiteStatus({
    this.requiredKinds = const <TransportProfileKind>[],
    this.state = TransportProfileCompatibilityState.unknown,
    this.selectedProfile,
    this.defaultProfile,
    this.missingKind,
    this.importAdapters = const <TransportProfileImportAdapter>[],
    this.message = '',
  });

  factory TransportProfilePrerequisiteStatus.fromJson(
    Map<String, dynamic> json,
  ) {
    return TransportProfilePrerequisiteStatus(
      requiredKinds: _readTransportProfileKinds(json['required_kinds']),
      state: TransportProfileCompatibilityState.fromJson(
        json['state'] as String?,
      ),
      selectedProfile: json['selected_profile'] is Map<String, dynamic>
          ? TransportProfileReference.fromJson(
              json['selected_profile'] as Map<String, dynamic>,
            )
          : null,
      defaultProfile: json['default_profile'] is Map<String, dynamic>
          ? TransportProfileReference.fromJson(
              json['default_profile'] as Map<String, dynamic>,
            )
          : null,
      missingKind: TransportProfileKind.fromJson(
        json['missing_kind'] as String?,
      ),
      importAdapters: _readTransportProfileImportAdapters(
        json['import_adapters'],
      ),
      message: json['message'] as String? ?? '',
    );
  }

  final List<TransportProfileKind> requiredKinds;
  final TransportProfileCompatibilityState state;
  final TransportProfileReference? selectedProfile;
  final TransportProfileReference? defaultProfile;
  final TransportProfileKind? missingKind;
  final List<TransportProfileImportAdapter> importAdapters;
  final String message;

  bool get isCompatible =>
      state == TransportProfileCompatibilityState.compatible;
}

class RuntimeExecutionPlan {
  const RuntimeExecutionPlan({
    required this.accessMethod,
    required this.carrierFamily,
    required this.engineFamily,
    this.hostAdapter,
  });

  factory RuntimeExecutionPlan.fromJson(Map<String, dynamic> json) {
    final accessMethod = RuntimeAccessMethod.fromJson(
      json['access_method'] as String?,
    );
    if (accessMethod == null) {
      throw FormatException(
        'runtime execution plan missing or invalid access_method',
      );
    }
    final carrierFamily = RuntimeCarrierFamily.fromJson(
      json['carrier_family'] as String?,
    );
    if (carrierFamily == null) {
      throw FormatException(
        'runtime execution plan missing or invalid carrier_family',
      );
    }
    final engineFamily = RuntimeEngineFamily.fromJson(
      json['engine_family'] as String?,
    );
    if (engineFamily == null) {
      throw FormatException(
        'runtime execution plan missing or invalid engine_family',
      );
    }
    final hostAdapter = json['host_adapter'] == null
        ? null
        : RuntimeHostAdapter.fromJson(json['host_adapter'] as String?);
    if (json['host_adapter'] != null && hostAdapter == null) {
      throw FormatException('runtime execution plan host_adapter is invalid');
    }
    return RuntimeExecutionPlan(
      accessMethod: accessMethod,
      carrierFamily: carrierFamily,
      engineFamily: engineFamily,
      hostAdapter: hostAdapter,
    );
  }

  final RuntimeAccessMethod accessMethod;
  final RuntimeCarrierFamily carrierFamily;
  final RuntimeEngineFamily engineFamily;
  final RuntimeHostAdapter? hostAdapter;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'access_method': accessMethod.value,
      'carrier_family': carrierFamily.value,
      'engine_family': engineFamily.value,
      if (hostAdapter != null) 'host_adapter': hostAdapter!.value,
    };
  }
}

class RuntimeExecutionPlanDescriptor {
  const RuntimeExecutionPlanDescriptor({
    required this.plan,
    required this.supportState,
    required this.remoteEndpointFamily,
    this.isDefault = false,
    this.requiresCapability,
    this.requiredTransportProfileKinds = const <TransportProfileKind>[],
    this.transportProfile,
    this.message,
  });

  factory RuntimeExecutionPlanDescriptor.fromJson(Map<String, dynamic> json) {
    final plan = json['plan'] is Map<String, dynamic>
        ? RuntimeExecutionPlan.fromJson(json['plan'] as Map<String, dynamic>)
        : throw const FormatException(
            'runtime execution plan descriptor missing plan',
          );
    final supportState = RuntimeExecutionPlanSupportState.fromJson(
      json['support_state'] as String?,
    );
    if (supportState == null) {
      throw const FormatException(
        'runtime execution plan descriptor missing support_state',
      );
    }
    final remoteEndpointFamily = RuntimeRemoteEndpointFamily.fromJson(
      json['remote_endpoint_family'] as String?,
    );
    if (remoteEndpointFamily == null) {
      throw const FormatException(
        'runtime execution plan descriptor missing remote_endpoint_family',
      );
    }
    return RuntimeExecutionPlanDescriptor(
      plan: plan,
      supportState: supportState,
      remoteEndpointFamily: remoteEndpointFamily,
      isDefault: json['default'] as bool? ?? false,
      requiresCapability: json['requires_capability'] as String?,
      requiredTransportProfileKinds: _readTransportProfileKinds(
        json['required_transport_profile_kinds'],
      ),
      transportProfile: json['transport_profile'] is Map<String, dynamic>
          ? TransportProfilePrerequisiteStatus.fromJson(
              json['transport_profile'] as Map<String, dynamic>,
            )
          : null,
      message: json['message'] as String?,
    );
  }

  final RuntimeExecutionPlan plan;
  final RuntimeExecutionPlanSupportState supportState;
  final RuntimeRemoteEndpointFamily remoteEndpointFamily;
  final bool isDefault;
  final String? requiresCapability;
  final List<TransportProfileKind> requiredTransportProfileKinds;
  final TransportProfilePrerequisiteStatus? transportProfile;
  final String? message;

  bool get isSelectable =>
      supportState == RuntimeExecutionPlanSupportState.supported;

  bool get isProfileSetupNeeded =>
      supportState == RuntimeExecutionPlanSupportState.unavailable &&
      transportProfile != null &&
      transportProfile!.state != TransportProfileCompatibilityState.compatible;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'plan': plan.toJson(),
      'support_state': supportState.value,
      'remote_endpoint_family': remoteEndpointFamily.value,
      if (isDefault) 'default': true,
      if (requiresCapability != null && requiresCapability!.isNotEmpty)
        'requires_capability': requiresCapability,
      if (requiredTransportProfileKinds.isNotEmpty)
        'required_transport_profile_kinds': requiredTransportProfileKinds
            .map((TransportProfileKind kind) => kind.value)
            .toList(growable: false),
      if (transportProfile != null)
        'transport_profile': _transportProfilePrerequisiteStatusToJson(
          transportProfile!,
        ),
      if (message != null && message!.isNotEmpty) 'message': message,
    };
  }
}

List<TransportProfileKind> _readTransportProfileKinds(dynamic raw) {
  return (raw as List<dynamic>? ?? const <dynamic>[])
      .map((dynamic item) => TransportProfileKind.fromJson(item as String?))
      .whereType<TransportProfileKind>()
      .toList(growable: false);
}

List<TransportProfileImportAdapter> _readTransportProfileImportAdapters(
  dynamic raw,
) {
  return (raw as List<dynamic>? ?? const <dynamic>[])
      .map(
        (dynamic item) =>
            TransportProfileImportAdapter.fromJson(item as String?),
      )
      .whereType<TransportProfileImportAdapter>()
      .toList(growable: false);
}

List<TransportProfileLifecycleAction> _readTransportProfileLifecycleActions(
  dynamic raw,
) {
  return (raw as List<dynamic>? ?? const <dynamic>[])
      .map(
        (dynamic item) =>
            TransportProfileLifecycleAction.fromJson(item as String?),
      )
      .whereType<TransportProfileLifecycleAction>()
      .toList(growable: false);
}

DateTime _readDateTime(dynamic raw) {
  final value = raw as String?;
  if (value == null || value.isEmpty) {
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  return DateTime.parse(value).toUtc();
}

Map<String, dynamic> _transportProfilePrerequisiteStatusToJson(
  TransportProfilePrerequisiteStatus status,
) {
  return <String, dynamic>{
    if (status.requiredKinds.isNotEmpty)
      'required_kinds': status.requiredKinds
          .map((TransportProfileKind kind) => kind.value)
          .toList(growable: false),
    'state': status.state.value,
    if (status.selectedProfile != null)
      'selected_profile': status.selectedProfile!.toJson(),
    if (status.defaultProfile != null)
      'default_profile': status.defaultProfile!.toJson(),
    if (status.missingKind != null) 'missing_kind': status.missingKind!.value,
    if (status.importAdapters.isNotEmpty)
      'import_adapters': status.importAdapters
          .map((TransportProfileImportAdapter adapter) => adapter.value)
          .toList(growable: false),
    if (status.message.isNotEmpty) 'message': status.message,
  };
}
