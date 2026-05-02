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

enum RuntimeRemoteEndpointRole {
  turnDtlsCustomOverlay('turn_dtls_custom_overlay'),
  wireGuardRawDatagram('wireguard_raw_datagram'),
  udpProtocolMultiplexer('udp_protocol_multiplexer');

  const RuntimeRemoteEndpointRole(this.value);

  final String value;

  static RuntimeRemoteEndpointRole? fromJson(String? raw) {
    for (final role in values) {
      if (role.value == raw) {
        return role;
      }
    }
    return null;
  }
}

enum RuntimeRemoteIngressProtocol {
  dtlsCustomOverlay('dtls_custom_overlay'),
  rawWireGuardDatagram('raw_wireguard_datagram'),
  udpProtocolMultiplexer('udp_protocol_multiplexer');

  const RuntimeRemoteIngressProtocol(this.value);

  final String value;

  static RuntimeRemoteIngressProtocol? fromJson(String? raw) {
    for (final protocol in values) {
      if (protocol.value == raw) {
        return protocol;
      }
    }
    return null;
  }
}

enum RuntimeRemoteIngressIsolation {
  dedicated('dedicated'),
  muxBacked('mux_backed');

  const RuntimeRemoteIngressIsolation(this.value);

  final String value;

  static RuntimeRemoteIngressIsolation? fromJson(String? raw) {
    for (final isolation in values) {
      if (isolation.value == raw) {
        return isolation;
      }
    }
    return null;
  }
}

class RuntimeRemoteIngressDiagnostics {
  const RuntimeRemoteIngressDiagnostics({
    required this.endpointFamily,
    required this.endpointRole,
    required this.protocol,
    required this.isolation,
    this.address = '',
  });

  factory RuntimeRemoteIngressDiagnostics.fromJson(Map<String, dynamic> json) {
    final endpointFamily = RuntimeRemoteEndpointFamily.fromJson(
      json['endpoint_family'] as String?,
    );
    final endpointRole = RuntimeRemoteEndpointRole.fromJson(
      json['endpoint_role'] as String?,
    );
    final protocol = RuntimeRemoteIngressProtocol.fromJson(
      json['protocol'] as String?,
    );
    final isolation = RuntimeRemoteIngressIsolation.fromJson(
      json['isolation'] as String?,
    );
    if (endpointFamily == null ||
        endpointRole == null ||
        protocol == null ||
        isolation == null) {
      throw const FormatException('remote_ingress diagnostics are incomplete');
    }
    return RuntimeRemoteIngressDiagnostics(
      endpointFamily: endpointFamily,
      endpointRole: endpointRole,
      protocol: protocol,
      isolation: isolation,
      address: json['address'] as String? ?? '',
    );
  }

  final RuntimeRemoteEndpointFamily endpointFamily;
  final RuntimeRemoteEndpointRole endpointRole;
  final RuntimeRemoteIngressProtocol protocol;
  final RuntimeRemoteIngressIsolation isolation;
  final String address;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'endpoint_family': endpointFamily.value,
      'endpoint_role': endpointRole.value,
      'protocol': protocol.value,
      'isolation': isolation.value,
      if (address.isNotEmpty) 'address': address,
    };
  }
}

class TransportProfileKind {
  const TransportProfileKind(this.value);

  static const wireGuardNativeV1 = TransportProfileKind('wireguard_native_v1');

  final String value;

  static TransportProfileKind? fromJson(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    return TransportProfileKind(value);
  }

  bool get isWireGuardNativeV1 => this == wireGuardNativeV1;

  @override
  bool operator ==(Object other) =>
      other is TransportProfileKind && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

class TransportProfileImportAdapter {
  const TransportProfileImportAdapter(this.value);

  static const wireGuardConf = TransportProfileImportAdapter('wireguard_conf');

  final String value;

  static TransportProfileImportAdapter? fromJson(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    return TransportProfileImportAdapter(value);
  }

  bool get isWireGuardConf => this == wireGuardConf;

  @override
  bool operator ==(Object other) =>
      other is TransportProfileImportAdapter && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

class TransportProfileMaterialAcquisitionMethod {
  const TransportProfileMaterialAcquisitionMethod(this.value);

  static const plainText = TransportProfileMaterialAcquisitionMethod(
    'plain_text',
  );
  static const filePicker = TransportProfileMaterialAcquisitionMethod(
    'file_picker',
  );
  static const qrPayload = TransportProfileMaterialAcquisitionMethod(
    'qr_payload',
  );
  static const providerManaged = TransportProfileMaterialAcquisitionMethod(
    'provider_managed',
  );

  final String value;

  static TransportProfileMaterialAcquisitionMethod? fromJson(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    return TransportProfileMaterialAcquisitionMethod(value);
  }

  bool get canAcquireInShell => this == plainText || this == filePicker;

  @override
  bool operator ==(Object other) =>
      other is TransportProfileMaterialAcquisitionMethod &&
      other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

enum TransportProfileLifecycleAction {
  list('list'),
  import('import'),
  replace('replace'),
  forget('forget'),
  validate('validate'),
  selectForStartup('select_for_startup'),
  createStructured('create_structured'),
  updateStructured('update_structured'),
  validateDraft('validate_draft'),
  generateKey('generate_key');

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
  legacyPath('legacy_path'),
  structuredEditor('structured_editor');

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

class TransportProfileStructuredFieldId {
  const TransportProfileStructuredFieldId(this.value);

  static const schemaVersion = TransportProfileStructuredFieldId(
    'schema_version',
  );
  static const displayName = TransportProfileStructuredFieldId('display_name');
  static const interfacePrivateKey = TransportProfileStructuredFieldId(
    'interface_private_key',
  );
  static const interfaceAddresses = TransportProfileStructuredFieldId(
    'interface_addresses',
  );
  static const dnsServers = TransportProfileStructuredFieldId('dns_servers');
  static const mtu = TransportProfileStructuredFieldId('mtu');
  static const peerPublicKey = TransportProfileStructuredFieldId(
    'peer_public_key',
  );
  static const peerPresharedKey = TransportProfileStructuredFieldId(
    'peer_preshared_key',
  );
  static const allowedIps = TransportProfileStructuredFieldId('allowed_ips');
  static const endpoint = TransportProfileStructuredFieldId('endpoint');
  static const persistentKeepalive = TransportProfileStructuredFieldId(
    'persistent_keepalive',
  );

  final String value;

  static TransportProfileStructuredFieldId? fromJson(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    return TransportProfileStructuredFieldId(value);
  }

  @override
  bool operator ==(Object other) =>
      other is TransportProfileStructuredFieldId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

class TransportProfileStructuredFieldValueKind {
  const TransportProfileStructuredFieldValueKind(this.value);

  static const string = TransportProfileStructuredFieldValueKind('string');
  static const stringList = TransportProfileStructuredFieldValueKind(
    'string_list',
  );
  static const integer = TransportProfileStructuredFieldValueKind('integer');
  static const secretString = TransportProfileStructuredFieldValueKind(
    'secret_string',
  );

  final String value;

  static TransportProfileStructuredFieldValueKind? fromJson(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    return TransportProfileStructuredFieldValueKind(value);
  }

  bool get supportedByShell =>
      this == string ||
      this == stringList ||
      this == integer ||
      this == secretString;

  @override
  bool operator ==(Object other) =>
      other is TransportProfileStructuredFieldValueKind && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

class TransportProfileStructuredFieldCardinality {
  const TransportProfileStructuredFieldCardinality(this.value);

  static const one = TransportProfileStructuredFieldCardinality('one');
  static const many = TransportProfileStructuredFieldCardinality('many');

  final String value;

  static TransportProfileStructuredFieldCardinality? fromJson(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    return TransportProfileStructuredFieldCardinality(value);
  }

  @override
  bool operator ==(Object other) =>
      other is TransportProfileStructuredFieldCardinality &&
      other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

enum TransportProfileSecretUpdateAction {
  preserveExisting('preserve_existing'),
  replaceSubmitted('replace_submitted'),
  generateHost('generate_host');

  const TransportProfileSecretUpdateAction(this.value);

  final String value;

  static TransportProfileSecretUpdateAction? fromJson(String? raw) {
    for (final action in values) {
      if (action.value == raw) {
        return action;
      }
    }
    return null;
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
    this.materialAcquisitionMethod,
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
      materialAcquisitionMethod:
          TransportProfileMaterialAcquisitionMethod.fromJson(
            json['material_acquisition_method'] as String?,
          ),
    );
  }

  final TransportProfileImportAdapter id;
  final TransportProfileKind profileKind;
  final String displayName;
  final List<String> extensions;
  final TransportProfileMaterialAcquisitionMethod? materialAcquisitionMethod;
}

class TransportProfileStructuredFieldDescriptor {
  const TransportProfileStructuredFieldDescriptor({
    required this.id,
    required this.valueKind,
    this.displayName = '',
    this.helpText = '',
    this.placeholder = '',
    this.group = '',
    this.order = 0,
    this.cardinality,
    this.required = false,
    this.secret = false,
    this.generated = false,
    this.updatePreservable = false,
    this.manualReplacement = false,
    this.minItems = 0,
    this.maxItems = 0,
    this.defaultString = '',
    this.defaultStringList = const <String>[],
    this.defaultInteger = 0,
    this.supported = false,
    this.unsupportedReason = '',
    this.secretUpdateActions = const <TransportProfileSecretUpdateAction>[],
  });

  factory TransportProfileStructuredFieldDescriptor.fromJson(
    Map<String, dynamic> json,
  ) {
    final id = TransportProfileStructuredFieldId.fromJson(
      json['id'] as String?,
    );
    final valueKind = TransportProfileStructuredFieldValueKind.fromJson(
      json['value_kind'] as String?,
    );
    if (id == null || valueKind == null) {
      throw const FormatException(
        'transport profile structured field descriptor invalid',
      );
    }
    return TransportProfileStructuredFieldDescriptor(
      id: id,
      displayName: json['display_name'] as String? ?? '',
      helpText: json['help_text'] as String? ?? '',
      placeholder: json['placeholder'] as String? ?? '',
      group: json['group'] as String? ?? '',
      order: json['order'] as int? ?? 0,
      valueKind: valueKind,
      cardinality: TransportProfileStructuredFieldCardinality.fromJson(
        json['cardinality'] as String?,
      ),
      required: json['required'] as bool? ?? false,
      secret: json['secret'] as bool? ?? false,
      generated: json['generated'] as bool? ?? false,
      updatePreservable: json['update_preservable'] as bool? ?? false,
      manualReplacement: json['manual_replacement'] as bool? ?? false,
      minItems: json['min_items'] as int? ?? 0,
      maxItems: json['max_items'] as int? ?? 0,
      defaultString: json['default_string'] as String? ?? '',
      defaultStringList:
          (json['default_string_list'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(growable: false),
      defaultInteger: json['default_integer'] as int? ?? 0,
      supported: json['supported'] as bool? ?? false,
      unsupportedReason: json['unsupported_reason'] as String? ?? '',
      secretUpdateActions: _readTransportProfileSecretUpdateActions(
        json['secret_update_actions'],
      ),
    );
  }

  final TransportProfileStructuredFieldId id;
  final String displayName;
  final String helpText;
  final String placeholder;
  final String group;
  final int order;
  final TransportProfileStructuredFieldValueKind valueKind;
  final TransportProfileStructuredFieldCardinality? cardinality;
  final bool required;
  final bool secret;
  final bool generated;
  final bool updatePreservable;
  final bool manualReplacement;
  final int minItems;
  final int maxItems;
  final String defaultString;
  final List<String> defaultStringList;
  final int defaultInteger;
  final bool supported;
  final String unsupportedReason;
  final List<TransportProfileSecretUpdateAction> secretUpdateActions;

  bool get supportedByShell => supported && valueKind.supportedByShell;
}

class TransportProfileEditableKindSchema {
  const TransportProfileEditableKindSchema({
    required this.kind,
    required this.schemaVersion,
    this.fields = const <TransportProfileStructuredFieldDescriptor>[],
    this.lifecycleActions = const <TransportProfileLifecycleAction>[],
  });

  factory TransportProfileEditableKindSchema.fromJson(
    Map<String, dynamic> json,
  ) {
    final kind = TransportProfileKind.fromJson(json['kind'] as String?);
    if (kind == null) {
      throw const FormatException('transport profile editable schema invalid');
    }
    return TransportProfileEditableKindSchema(
      kind: kind,
      schemaVersion: json['schema_version'] as String? ?? '',
      fields: (json['fields'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (dynamic raw) => TransportProfileStructuredFieldDescriptor.fromJson(
              raw as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      lifecycleActions: _readTransportProfileLifecycleActions(
        json['lifecycle_actions'],
      ),
    );
  }

  final TransportProfileKind kind;
  final String schemaVersion;
  final List<TransportProfileStructuredFieldDescriptor> fields;
  final List<TransportProfileLifecycleAction> lifecycleActions;

  bool get supportsStructuredCreate => lifecycleActions.contains(
    TransportProfileLifecycleAction.createStructured,
  );

  bool get supportsStructuredUpdate => lifecycleActions.contains(
    TransportProfileLifecycleAction.updateStructured,
  );

  bool get supportsDraftValidation =>
      lifecycleActions.contains(TransportProfileLifecycleAction.validateDraft);
}

class TransportProfileStoreCapability {
  const TransportProfileStoreCapability({
    this.supportedKinds = const <TransportProfileKind>[],
    this.importAdapters = const <TransportProfileImportAdapterDescriptor>[],
    this.lifecycleActions = const <TransportProfileLifecycleAction>[],
    this.redactionGuarantees = const <String>[],
    this.editableKinds = const <TransportProfileEditableKindSchema>[],
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
      editableKinds:
          (json['editable_kinds'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (dynamic raw) => TransportProfileEditableKindSchema.fromJson(
                  raw as Map<String, dynamic>,
                ),
              )
              .toList(growable: false),
    );
  }

  final List<TransportProfileKind> supportedKinds;
  final List<TransportProfileImportAdapterDescriptor> importAdapters;
  final List<TransportProfileLifecycleAction> lifecycleActions;
  final List<String> redactionGuarantees;
  final List<TransportProfileEditableKindSchema> editableKinds;
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

class TransportProfileStructuredDraft {
  const TransportProfileStructuredDraft({
    required this.kind,
    this.schemaVersion = '',
    this.displayName = '',
    this.fields = const <TransportProfileStructuredFieldId, Object?>{},
    this.secretActions =
        const <
          TransportProfileStructuredFieldId,
          TransportProfileSecretUpdateAction
        >{},
    this.interfacePrivateKey = '',
    this.interfacePrivateKeyAction,
    this.interfaceAddresses = const <String>[],
    this.dnsServers = const <String>[],
    this.mtu = 0,
    this.peerPublicKey = '',
    this.peerPresharedKey = '',
    this.peerPresharedKeyAction,
    this.allowedIps = const <String>[],
    this.endpoint = '',
    this.persistentKeepaliveSeconds = 0,
    this.defaultFor,
  });

  final TransportProfileKind kind;
  final String schemaVersion;
  final String displayName;
  final Map<TransportProfileStructuredFieldId, Object?> fields;
  final Map<
    TransportProfileStructuredFieldId,
    TransportProfileSecretUpdateAction
  >
  secretActions;
  final String interfacePrivateKey;
  final TransportProfileSecretUpdateAction? interfacePrivateKeyAction;
  final List<String> interfaceAddresses;
  final List<String> dnsServers;
  final int mtu;
  final String peerPublicKey;
  final String peerPresharedKey;
  final TransportProfileSecretUpdateAction? peerPresharedKeyAction;
  final List<String> allowedIps;
  final String endpoint;
  final int persistentKeepaliveSeconds;
  final RuntimeExecutionPlan? defaultFor;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': kind.value,
      if (schemaVersion.trim().isNotEmpty)
        'schema_version': schemaVersion.trim(),
      if (displayName.trim().isNotEmpty) 'display_name': displayName.trim(),
      if (fields.isNotEmpty)
        'fields': fields.map(
          (TransportProfileStructuredFieldId field, Object? value) =>
              MapEntry<String, Object?>(field.value, _jsonFieldValue(value)),
        ),
      if (secretActions.isNotEmpty)
        'secret_actions': secretActions.map(
          (
            TransportProfileStructuredFieldId field,
            TransportProfileSecretUpdateAction action,
          ) => MapEntry<String, String>(field.value, action.value),
        ),
      if (interfacePrivateKey.trim().isNotEmpty)
        'interface_private_key': interfacePrivateKey.trim(),
      if (interfacePrivateKeyAction != null)
        'interface_private_key_action': interfacePrivateKeyAction!.value,
      if (interfaceAddresses.isNotEmpty)
        'interface_addresses': _trimmedStringList(interfaceAddresses),
      if (dnsServers.isNotEmpty) 'dns_servers': _trimmedStringList(dnsServers),
      if (mtu > 0) 'mtu': mtu,
      if (peerPublicKey.trim().isNotEmpty)
        'peer_public_key': peerPublicKey.trim(),
      if (peerPresharedKey.trim().isNotEmpty)
        'peer_preshared_key': peerPresharedKey.trim(),
      if (peerPresharedKeyAction != null)
        'peer_preshared_key_action': peerPresharedKeyAction!.value,
      if (allowedIps.isNotEmpty) 'allowed_ips': _trimmedStringList(allowedIps),
      if (endpoint.trim().isNotEmpty) 'endpoint': endpoint.trim(),
      if (persistentKeepaliveSeconds > 0)
        'persistent_keepalive_seconds': persistentKeepaliveSeconds,
      if (defaultFor != null) 'default_for': defaultFor!.toJson(),
    };
  }
}

class TransportProfileStructuredCreateRequest {
  const TransportProfileStructuredCreateRequest({required this.draft});

  final TransportProfileStructuredDraft draft;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'draft': draft.toJson()};
  }
}

class TransportProfileStructuredUpdateRequest {
  const TransportProfileStructuredUpdateRequest({required this.draft});

  final TransportProfileStructuredDraft draft;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'draft': draft.toJson()};
  }
}

class TransportProfileStructuredSaveResult {
  const TransportProfileStructuredSaveResult({
    required this.profile,
    this.generatedKeys = const <TransportProfileGeneratedKey>[],
  });

  factory TransportProfileStructuredSaveResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return TransportProfileStructuredSaveResult(
      profile: TransportProfileStatus.fromJson(
        json['profile'] as Map<String, dynamic>,
      ),
      generatedKeys:
          (json['generated_keys'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (dynamic raw) => TransportProfileGeneratedKey.fromJson(
                  raw as Map<String, dynamic>,
                ),
              )
              .toList(growable: false),
    );
  }

  final TransportProfileStatus profile;
  final List<TransportProfileGeneratedKey> generatedKeys;
}

class TransportProfileStructuredValidationRequest {
  const TransportProfileStructuredValidationRequest({
    required this.draft,
    this.profileId = '',
  });

  final String profileId;
  final TransportProfileStructuredDraft draft;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (profileId.trim().isNotEmpty) 'profile_id': profileId.trim(),
      'draft': draft.toJson(),
    };
  }
}

class TransportProfileFieldValidationError {
  const TransportProfileFieldValidationError({
    required this.field,
    required this.violation,
    this.message = '',
  });

  factory TransportProfileFieldValidationError.fromJson(
    Map<String, dynamic> json,
  ) {
    return TransportProfileFieldValidationError(
      field:
          TransportProfileStructuredFieldId.fromJson(
            json['field'] as String?,
          ) ??
          TransportProfileStructuredFieldId.schemaVersion,
      violation: json['violation'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }

  final TransportProfileStructuredFieldId field;
  final String violation;
  final String message;
}

class TransportProfileStructuredValidationResult {
  const TransportProfileStructuredValidationResult({
    required this.valid,
    this.errors = const <TransportProfileFieldValidationError>[],
    this.status,
  });

  factory TransportProfileStructuredValidationResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return TransportProfileStructuredValidationResult(
      valid: json['valid'] as bool? ?? false,
      errors: (json['errors'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (dynamic raw) => TransportProfileFieldValidationError.fromJson(
              raw as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      status: json['status'] is Map<String, dynamic>
          ? TransportProfileValidationStatus.fromJson(
              json['status'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  final bool valid;
  final List<TransportProfileFieldValidationError> errors;
  final TransportProfileValidationStatus? status;
}

class TransportProfileGenerateKeyRequest {
  const TransportProfileGenerateKeyRequest({required this.kind, this.field});

  final TransportProfileKind kind;
  final TransportProfileStructuredFieldId? field;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': kind.value,
      if (field != null) 'field': field!.value,
    };
  }
}

class TransportProfileGeneratedKey {
  const TransportProfileGeneratedKey({
    required this.kind,
    required this.field,
    required this.publicKey,
    required this.fingerprint,
  });

  factory TransportProfileGeneratedKey.fromJson(Map<String, dynamic> json) {
    final kind = TransportProfileKind.fromJson(json['kind'] as String?);
    final field = TransportProfileStructuredFieldId.fromJson(
      json['field'] as String?,
    );
    if (kind == null || field == null) {
      throw const FormatException('transport profile generated key invalid');
    }
    return TransportProfileGeneratedKey(
      kind: kind,
      field: field,
      publicKey: json['public_key'] as String? ?? '',
      fingerprint: json['fingerprint'] as String? ?? '',
    );
  }

  final TransportProfileKind kind;
  final TransportProfileStructuredFieldId field;
  final String publicKey;
  final String fingerprint;
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
    this.remoteEndpointRole,
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
    final remoteEndpointRole = RuntimeRemoteEndpointRole.fromJson(
      json['remote_endpoint_role'] as String?,
    );
    return RuntimeExecutionPlanDescriptor(
      plan: plan,
      supportState: supportState,
      remoteEndpointFamily: remoteEndpointFamily,
      remoteEndpointRole: remoteEndpointRole,
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
  final RuntimeRemoteEndpointRole? remoteEndpointRole;
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
      if (remoteEndpointRole != null)
        'remote_endpoint_role': remoteEndpointRole!.value,
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

List<TransportProfileSecretUpdateAction>
_readTransportProfileSecretUpdateActions(dynamic raw) {
  return (raw as List<dynamic>? ?? const <dynamic>[])
      .map(
        (dynamic item) =>
            TransportProfileSecretUpdateAction.fromJson(item as String?),
      )
      .whereType<TransportProfileSecretUpdateAction>()
      .toList(growable: false);
}

List<String> _trimmedStringList(List<String> values) {
  return values
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .toList(growable: false);
}

Object? _jsonFieldValue(Object? value) {
  if (value is String) {
    return value.trim();
  }
  if (value is Iterable<String>) {
    return value
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return value;
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
