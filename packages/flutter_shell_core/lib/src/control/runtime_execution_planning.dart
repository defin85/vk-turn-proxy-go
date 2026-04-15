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
      message: json['message'] as String?,
    );
  }

  final RuntimeExecutionPlan plan;
  final RuntimeExecutionPlanSupportState supportState;
  final RuntimeRemoteEndpointFamily remoteEndpointFamily;
  final bool isDefault;
  final String? requiresCapability;
  final String? message;

  bool get isSelectable =>
      supportState == RuntimeExecutionPlanSupportState.supported;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'plan': plan.toJson(),
      'support_state': supportState.value,
      'remote_endpoint_family': remoteEndpointFamily.value,
      if (isDefault) 'default': true,
      if (requiresCapability != null && requiresCapability!.isNotEmpty)
        'requires_capability': requiresCapability,
      if (message != null && message!.isNotEmpty) 'message': message,
    };
  }
}
