import 'dart:convert';

import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';

import 'runtime_execution_planning.dart';

typedef LocalizedTextMap = Map<String, String>;

enum Capability {
  profiles('profiles'),
  providerConfigs('provider_configs'),
  sessions('sessions'),
  challenges('challenges'),
  diagnostics('diagnostics'),
  eventStream('event_stream'),
  desktopSidecar('desktop_sidecar'),
  mobileHostBridge('mobile_host_bridge'),
  platformTunnels('platform_tunnels'),
  providerRuntimeArtifacts('provider-runtime-artifacts'),
  runtimeExecutionPlanning('runtime-execution-planning'),
  vpnTransportProfileStore('vpn-transport-profile-store');

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
    ProviderAuthPosture.notApplicable =>
      t.sharedProviderAuthPostureNotApplicable,
    ProviderAuthPosture.guest => t.sharedProviderAuthPostureGuest,
    ProviderAuthPosture.account => t.sharedProviderAuthPostureAccount,
    ProviderAuthPosture.guestOrAccount =>
      t.sharedProviderAuthPostureGuestOrAccount,
    ProviderAuthPosture.staticSecret => t.sharedProviderAuthPostureStaticSecret,
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
    ProviderBrowserPolicy.notRequired =>
      t.sharedProviderBrowserPolicyNotRequired,
    ProviderBrowserPolicy.externalRequired =>
      t.sharedProviderBrowserPolicyExternalRequired,
    ProviderBrowserPolicy.embeddedAllowed =>
      t.sharedProviderBrowserPolicyEmbeddedAllowed,
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
    ArtifactFamily.genericTurn => t.sharedArtifactFamilyGenericTurn,
    ArtifactFamily.conferenceRoom => t.sharedArtifactFamilyConferenceRoom,
    ArtifactFamily.cameraStream => t.sharedArtifactFamilyCameraStream,
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
    ArtifactAction.startOnThisDevice => t.sharedArtifactActionStartOnThisDevice,
    ArtifactAction.exportHandoff => t.sharedArtifactActionExportHandoff,
    ArtifactAction.openRoom => t.sharedArtifactActionOpenRoom,
    ArtifactAction.openCamera => t.sharedArtifactActionOpenCamera,
    ArtifactAction.openArchive => t.sharedArtifactActionOpenArchive,
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

enum ProviderSettingType {
  string('string'),
  integer('integer'),
  number('number'),
  boolean('boolean');

  const ProviderSettingType(this.value);

  final String value;

  static ProviderSettingType? fromJson(String? raw) {
    for (final type in values) {
      if (type.value == raw) {
        return type;
      }
    }
    return null;
  }
}

enum ProviderSettingControl {
  text('text'),
  textarea('textarea'),
  select('select'),
  checkbox('checkbox'),
  password('password');

  const ProviderSettingControl(this.value);

  final String value;

  static ProviderSettingControl? fromJson(String? raw) {
    for (final control in values) {
      if (control.value == raw) {
        return control;
      }
    }
    return null;
  }
}

enum ProviderSettingPersistence {
  profile('profile'),
  ephemeral('ephemeral');

  const ProviderSettingPersistence(this.value);

  final String value;

  static ProviderSettingPersistence? fromJson(String? raw) {
    for (final persistence in values) {
      if (persistence.value == raw) {
        return persistence;
      }
    }
    return null;
  }
}

class ProviderSettingProperty {
  const ProviderSettingProperty({
    required this.type,
    String title = '',
    this.titleLocalized = const <String, String>{},
    String description = '',
    this.descriptionLocalized = const <String, String>{},
    this.enumValues = const <dynamic>[],
    this.defaultValue,
    this.examples = const <dynamic>[],
    this.writeOnly = false,
    this.minLength,
    this.maxLength,
    this.pattern,
    this.minimum,
    this.maximum,
    this.control,
    this.persistence,
  }) : _title = title,
       _description = description;

  factory ProviderSettingProperty.fromJson(Map<String, dynamic> json) {
    return ProviderSettingProperty(
      type: ProviderSettingType.fromJson(json['type'] as String?),
      title: json['title'] as String? ?? '',
      titleLocalized: _readLocalizedTextMap(json['title_localized']),
      description: json['description'] as String? ?? '',
      descriptionLocalized: _readLocalizedTextMap(
        json['description_localized'],
      ),
      enumValues: _readScalarList(json['enum']),
      defaultValue: _scalarJsonValueOrNull(json['default']),
      examples: _readScalarList(json['examples']),
      writeOnly: json['writeOnly'] as bool? ?? false,
      minLength: json['minLength'] as int?,
      maxLength: json['maxLength'] as int?,
      pattern: json['pattern'] as String?,
      minimum: (json['minimum'] as num?)?.toDouble(),
      maximum: (json['maximum'] as num?)?.toDouble(),
      control: ProviderSettingControl.fromJson(
        json['x-vkturn-control'] as String?,
      ),
      persistence: ProviderSettingPersistence.fromJson(
        json['x-vkturn-persistence'] as String?,
      ),
    );
  }

  final ProviderSettingType? type;
  final String _title;
  final LocalizedTextMap titleLocalized;
  final String _description;
  final LocalizedTextMap descriptionLocalized;
  final List<dynamic> enumValues;
  final dynamic defaultValue;
  final List<dynamic> examples;
  final bool writeOnly;
  final int? minLength;
  final int? maxLength;
  final String? pattern;
  final double? minimum;
  final double? maximum;
  final ProviderSettingControl? control;
  final ProviderSettingPersistence? persistence;

  String get baseTitle => _title;

  String get title => _resolveLocalizedText(_title, titleLocalized);

  String get baseDescription => _description;

  String get description =>
      _resolveLocalizedText(_description, descriptionLocalized);
}

class ProviderSettingsField {
  const ProviderSettingsField({required this.key, required this.property});

  final String key;
  final ProviderSettingProperty property;
}

class ProviderSettingsSchema {
  const ProviderSettingsSchema({
    required this.type,
    required this.additionalProperties,
    this.properties = const <String, ProviderSettingProperty>{},
    this.requiredKeys = const <String>[],
    this.order = const <String>[],
  });

  factory ProviderSettingsSchema.fromJson(Map<String, dynamic> json) {
    return ProviderSettingsSchema(
      type: json['type'] as String? ?? '',
      additionalProperties: json['additionalProperties'] as bool? ?? true,
      properties: _readProviderSettingProperties(json['properties']),
      requiredKeys: (json['required'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic raw) => (raw as String? ?? '').trim())
          .where((String key) => key.isNotEmpty)
          .toList(growable: false),
      order: (json['x-vkturn-order'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic raw) => (raw as String? ?? '').trim())
          .where((String key) => key.isNotEmpty)
          .toList(growable: false),
    );
  }

  final String type;
  final bool additionalProperties;
  final Map<String, ProviderSettingProperty> properties;
  final List<String> requiredKeys;
  final List<String> order;

  String? get unsupportedReason {
    if (type != 'object') {
      return 'schema root must be type=object';
    }
    if (additionalProperties) {
      return 'schema root must set additionalProperties=false';
    }
    for (final key in requiredKeys) {
      if (!properties.containsKey(key)) {
        return 'required field $key is not declared in properties';
      }
    }
    for (final key in order) {
      if (!properties.containsKey(key)) {
        return 'x-vkturn-order references unknown field $key';
      }
    }
    for (final entry in properties.entries) {
      final reason = _unsupportedPropertyReason(entry.key, entry.value);
      if (reason != null) {
        return reason;
      }
    }
    return null;
  }

  List<ProviderSettingsField> get orderedFields {
    if (unsupportedReason != null) {
      return const <ProviderSettingsField>[];
    }
    final keys = <String>[];
    final seen = <String>{};
    for (final key in order) {
      if (seen.add(key)) {
        keys.add(key);
      }
    }
    final remaining =
        properties.keys
            .where((String key) => !seen.contains(key))
            .toList(growable: false)
          ..sort();
    keys.addAll(remaining);
    return keys
        .map(
          (String key) =>
              ProviderSettingsField(key: key, property: properties[key]!),
        )
        .toList(growable: false);
  }

  Map<String, dynamic> normalizeValues(
    Map<String, dynamic> values, {
    bool applyDefaults = true,
  }) {
    if (unsupportedReason != null) {
      return const <String, dynamic>{};
    }
    final normalized = <String, dynamic>{};
    for (final field in orderedFields) {
      if (values.containsKey(field.key) &&
          _canShellRepresentProviderSettingValue(
            field.property,
            values[field.key],
          )) {
        normalized[field.key] = values[field.key];
        continue;
      }
      if (applyDefaults &&
          _canShellRepresentProviderSettingValue(
            field.property,
            field.property.defaultValue,
          )) {
        normalized[field.key] = field.property.defaultValue;
      }
    }
    return normalized;
  }

  Map<String, dynamic> profileRetainedValues(Map<String, dynamic> values) {
    final normalized = normalizeValues(values, applyDefaults: false);
    final retained = <String, dynamic>{};
    for (final field in orderedFields) {
      if (!normalized.containsKey(field.key)) {
        continue;
      }
      if (field.property.writeOnly) {
        continue;
      }
      if (field.property.persistence != ProviderSettingPersistence.profile) {
        continue;
      }
      retained[field.key] = normalized[field.key];
    }
    return retained;
  }
}

class ProviderDescriptor {
  const ProviderDescriptor({
    required this.id,
    required String displayName,
    required this.inputKind,
    required this.authPosture,
    required this.browserPolicy,
    this.displayNameLocalized = const <String, String>{},
    String description = '',
    this.descriptionLocalized = const <String, String>{},
    this.settingsSchema,
    this.challengeModes = const <ProviderChallengeMode>[],
    this.artifactFamilies = const <ArtifactFamily>[],
    this.capabilityHints = const ProviderCapabilityHints(),
  }) : _displayName = displayName,
       _description = description;

  factory ProviderDescriptor.fromJson(Map<String, dynamic> json) {
    return ProviderDescriptor(
      id: json['id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      displayNameLocalized: _readLocalizedTextMap(
        json['display_name_localized'],
      ),
      description: json['description'] as String? ?? '',
      descriptionLocalized: _readLocalizedTextMap(
        json['description_localized'],
      ),
      inputKind: ProviderInputKind.fromJson(json['input_kind'] as String?),
      authPosture: ProviderAuthPosture.fromJson(
        json['auth_posture'] as String?,
      ),
      browserPolicy: ProviderBrowserPolicy.fromJson(
        json['browser_policy'] as String?,
      ),
      settingsSchema: json['provider_settings_schema'] is Map<String, dynamic>
          ? ProviderSettingsSchema.fromJson(
              json['provider_settings_schema'] as Map<String, dynamic>,
            )
          : null,
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
  final String _displayName;
  final LocalizedTextMap displayNameLocalized;
  final String _description;
  final LocalizedTextMap descriptionLocalized;
  final ProviderInputKind inputKind;
  final ProviderAuthPosture authPosture;
  final ProviderBrowserPolicy browserPolicy;
  final ProviderSettingsSchema? settingsSchema;
  final List<ProviderChallengeMode> challengeModes;
  final List<ArtifactFamily> artifactFamilies;
  final ProviderCapabilityHints capabilityHints;

  String get baseDisplayName => _displayName;

  String get displayName =>
      _resolveLocalizedText(_displayName, displayNameLocalized);

  String get baseDescription => _description;

  String get description =>
      _resolveLocalizedText(_description, descriptionLocalized);

  bool get mayRequireBrowserContinuation =>
      challengeModes.contains(ProviderChallengeMode.browser);

  bool get supportsProviderSettings =>
      settingsSchema?.unsupportedReason == null;

  String? get providerSettingsSupportError => settingsSchema?.unsupportedReason;

  List<ProviderSettingsField> get providerSettingsFields =>
      settingsSchema?.orderedFields ?? const <ProviderSettingsField>[];

  Map<String, dynamic> normalizeProviderSettings(
    Map<String, dynamic> values, {
    bool applyDefaults = true,
  }) {
    return settingsSchema?.normalizeValues(
          values,
          applyDefaults: applyDefaults,
        ) ??
        const <String, dynamic>{};
  }

  Map<String, dynamic> profileRetainedProviderSettings(
    Map<String, dynamic> values,
  ) {
    return settingsSchema?.profileRetainedValues(values) ??
        const <String, dynamic>{};
  }
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

enum ChallengeCompletionMode {
  manualConfirm('manual_confirm'),
  appReturnCallback('app_return_callback'),
  ownedBrowserObserved('owned_browser_observed');

  const ChallengeCompletionMode(this.value);

  final String value;

  static ChallengeCompletionMode? fromJson(String? raw) {
    for (final mode in values) {
      if (mode.value == raw) {
        return mode;
      }
    }
    return null;
  }
}

enum BrowserReturnSignalKind {
  appLink('app_link'),
  universalLink('universal_link'),
  foregroundResume('foreground_resume');

  const BrowserReturnSignalKind(this.value);

  final String value;

  static BrowserReturnSignalKind? fromJson(String? raw) {
    for (final kind in values) {
      if (kind.value == raw) {
        return kind;
      }
    }
    return null;
  }
}

class ChallengeBrowserReturnMetadata {
  const ChallengeBrowserReturnMetadata({
    required this.signalKinds,
    required this.allowAutoContinue,
    this.expectedReturnUri,
  });

  factory ChallengeBrowserReturnMetadata.fromJson(Map<String, dynamic> json) {
    final seen = <BrowserReturnSignalKind>{};
    final signalKinds = <BrowserReturnSignalKind>[];
    for (final raw
        in json['signal_kinds'] as List<dynamic>? ?? const <dynamic>[]) {
      final kind = BrowserReturnSignalKind.fromJson(raw as String?);
      if (kind == null || !seen.add(kind)) {
        continue;
      }
      signalKinds.add(kind);
    }
    final expectedReturnUri = (json['expected_return_uri'] as String?)?.trim();
    return ChallengeBrowserReturnMetadata(
      signalKinds: signalKinds,
      allowAutoContinue: json['allow_auto_continue'] as bool? ?? false,
      expectedReturnUri: expectedReturnUri == null || expectedReturnUri.isEmpty
          ? null
          : expectedReturnUri,
    );
  }

  final List<BrowserReturnSignalKind> signalKinds;
  final bool allowAutoContinue;
  final String? expectedReturnUri;

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'signal_kinds': signalKinds
          .map((BrowserReturnSignalKind kind) => kind.value)
          .toList(growable: false),
      'allow_auto_continue': allowAutoContinue,
      'expected_return_uri': expectedReturnUri,
    });
  }
}

class ChallengeOwnedBrowserMetadata {
  const ChallengeOwnedBrowserMetadata({
    this.cookieUrls = const <String>[],
    this.rememberSignIn = false,
    this.autoContinueOnTransportReady = false,
  });

  factory ChallengeOwnedBrowserMetadata.fromJson(Map<String, dynamic> json) {
    final seen = <String>{};
    final cookieUrls = <String>[];
    for (final raw
        in json['cookie_urls'] as List<dynamic>? ?? const <dynamic>[]) {
      final value = (raw as String?)?.trim() ?? '';
      if (value.isEmpty || !seen.add(value)) {
        continue;
      }
      cookieUrls.add(value);
    }
    return ChallengeOwnedBrowserMetadata(
      cookieUrls: List<String>.unmodifiable(cookieUrls),
      rememberSignIn: json['remember_sign_in'] as bool? ?? false,
      autoContinueOnTransportReady:
          json['auto_continue_on_transport_ready'] as bool? ?? false,
    );
  }

  final List<String> cookieUrls;
  final bool rememberSignIn;
  final bool autoContinueOnTransportReady;

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'cookie_urls': cookieUrls,
      'remember_sign_in': rememberSignIn,
      'auto_continue_on_transport_ready': autoContinueOnTransportReady,
    });
  }
}

class BrowserCookieRecord {
  const BrowserCookieRecord({
    required this.name,
    required this.value,
    this.domain,
    this.path,
    this.expires,
    this.secure = false,
    this.httpOnly = false,
  });

  factory BrowserCookieRecord.fromJson(Map<String, dynamic> json) {
    return BrowserCookieRecord(
      name: json['name'] as String? ?? '',
      value: json['value'] as String? ?? '',
      domain: json['domain'] as String?,
      path: json['path'] as String?,
      expires: json['expires'] == null ? null : _readTimestamp(json['expires']),
      secure: json['secure'] as bool? ?? false,
      httpOnly: json['http_only'] as bool? ?? false,
    );
  }

  final String name;
  final String value;
  final String? domain;
  final String? path;
  final DateTime? expires;
  final bool secure;
  final bool httpOnly;

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'name': name,
      'value': value,
      'domain': domain,
      'path': path,
      'expires': expires?.toUtc().toIso8601String(),
      'secure': secure ? true : null,
      'http_only': httpOnly ? true : null,
    });
  }
}

class BrowserObservedRequestRecord {
  const BrowserObservedRequestRecord({
    required this.method,
    required this.url,
    this.formValues = const <String, String>{},
    required this.statusCode,
    this.body = const <String, dynamic>{},
  });

  factory BrowserObservedRequestRecord.fromJson(Map<String, dynamic> json) {
    final rawFormValues =
        json['form_values'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final formValues = <String, String>{};
    rawFormValues.forEach((String key, dynamic value) {
      final trimmedKey = key.trim();
      if (trimmedKey.isEmpty || value is! String) {
        return;
      }
      formValues[trimmedKey] = value;
    });
    return BrowserObservedRequestRecord(
      method: json['method'] as String? ?? '',
      url: json['url'] as String? ?? '',
      formValues: Map<String, String>.unmodifiable(formValues),
      statusCode: json['status_code'] as int? ?? 0,
      body: Map<String, dynamic>.unmodifiable(
        (json['body'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
      ),
    );
  }

  final String method;
  final String url;
  final Map<String, String> formValues;
  final int statusCode;
  final Map<String, dynamic> body;

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'method': method,
      'url': url,
      'form_values': formValues.isEmpty ? null : formValues,
      'status_code': statusCode == 0 ? null : statusCode,
      'body': body.isEmpty ? null : body,
    });
  }
}

class ChallengeContinuationSubmission {
  const ChallengeContinuationSubmission({
    this.cookies = const <BrowserCookieRecord>[],
    this.observedRequests = const <BrowserObservedRequestRecord>[],
  });

  factory ChallengeContinuationSubmission.fromJson(Map<String, dynamic> json) {
    return ChallengeContinuationSubmission(
      cookies: (json['cookies'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(BrowserCookieRecord.fromJson)
          .toList(growable: false),
      observedRequests:
          (json['observed_requests'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(BrowserObservedRequestRecord.fromJson)
              .toList(growable: false),
    );
  }

  final List<BrowserCookieRecord> cookies;
  final List<BrowserObservedRequestRecord> observedRequests;

  bool get isEmpty => cookies.isEmpty && observedRequests.isEmpty;

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'cookies': cookies
          .map((BrowserCookieRecord cookie) => cookie.toJson())
          .toList(growable: false),
      'observed_requests': observedRequests
          .map((BrowserObservedRequestRecord request) => request.toJson())
          .toList(growable: false),
    });
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
    PlatformTunnelMode.androidVpnService =>
      t.sharedPlatformTunnelModeAndroidVpnService,
    PlatformTunnelMode.appleNetworkExtension =>
      t.sharedPlatformTunnelModeAppleNetworkExtension,
    PlatformTunnelMode.windowsWintun => t.sharedPlatformTunnelModeWindowsWintun,
    PlatformTunnelMode.linuxTun => t.sharedPlatformTunnelModeLinuxTun,
  };
}

enum PlatformTunnelPrerequisite {
  permission('permission'),
  entitlement('entitlement'),
  privilegedExtension('privileged_extension'),
  driver('driver'),
  routeExclusion('route_exclusion'),
  dnsBypass('dns_bypass'),
  appRoutingPolicy('app_routing_policy'),
  hostImplementation('host_implementation'),
  transportProfile('transport_profile'),
  dataplaneEvidence('dataplane_evidence');

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
    PlatformTunnelPrerequisite.permission =>
      t.sharedPlatformTunnelPrerequisitePermission,
    PlatformTunnelPrerequisite.entitlement =>
      t.sharedPlatformTunnelPrerequisiteEntitlement,
    PlatformTunnelPrerequisite.privilegedExtension =>
      t.sharedPlatformTunnelPrerequisitePrivilegedExtension,
    PlatformTunnelPrerequisite.driver =>
      t.sharedPlatformTunnelPrerequisiteDriver,
    PlatformTunnelPrerequisite.routeExclusion =>
      t.sharedPlatformTunnelPrerequisiteRouteExclusion,
    PlatformTunnelPrerequisite.dnsBypass =>
      t.sharedPlatformTunnelPrerequisiteDnsBypass,
    PlatformTunnelPrerequisite.appRoutingPolicy =>
      t.sharedPlatformTunnelPrerequisiteAppRoutingPolicy,
    PlatformTunnelPrerequisite.hostImplementation =>
      t.sharedPlatformTunnelPrerequisiteHostImplementation,
    PlatformTunnelPrerequisite.transportProfile =>
      t.sharedPlatformTunnelPrerequisiteTransportProfile,
    PlatformTunnelPrerequisite.dataplaneEvidence =>
      t.sharedPlatformTunnelPrerequisiteDataplaneEvidence,
  };
}

enum PlatformTunnelApplicationRoutingPolicy {
  allApps('all_apps'),
  allowedPackages('allowed_packages'),
  disallowedPackages('disallowed_packages');

  const PlatformTunnelApplicationRoutingPolicy(this.value);

  final String value;

  static PlatformTunnelApplicationRoutingPolicy? fromJson(String? raw) {
    for (final policy in values) {
      if (policy.value == raw) {
        return policy;
      }
    }
    return null;
  }
}

enum PlatformTunnelUnderlayRoutePolicy {
  standard('standard'),
  preserveActiveLocalNetwork('preserve_active_local_network');

  const PlatformTunnelUnderlayRoutePolicy(this.value);

  final String value;

  static PlatformTunnelUnderlayRoutePolicy? fromJson(String? raw) {
    for (final policy in values) {
      if (policy.value == raw) {
        return policy;
      }
    }
    return null;
  }
}

enum PlatformTunnelStartupStage {
  capabilityCheck('capability_check'),
  permissionAcquire('permission_acquire'),
  entitlementAcquire('entitlement_acquire'),
  driverCheck('driver_check'),
  profileValidate('profile_validate'),
  routeValidate('route_validate'),
  hostBringup('host_bringup'),
  runtimeAttach('runtime_attach'),
  dataplaneVerify('dataplane_verify');

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
    PlatformTunnelStartupStage.capabilityCheck =>
      t.sharedPlatformTunnelStartupStageCapabilityCheck,
    PlatformTunnelStartupStage.permissionAcquire =>
      t.sharedPlatformTunnelStartupStagePermissionAcquire,
    PlatformTunnelStartupStage.entitlementAcquire =>
      t.sharedPlatformTunnelStartupStageEntitlementAcquire,
    PlatformTunnelStartupStage.driverCheck =>
      t.sharedPlatformTunnelStartupStageDriverCheck,
    PlatformTunnelStartupStage.profileValidate =>
      t.sharedPlatformTunnelStartupStageProfileValidate,
    PlatformTunnelStartupStage.routeValidate =>
      t.sharedPlatformTunnelStartupStageRouteValidate,
    PlatformTunnelStartupStage.hostBringup =>
      t.sharedPlatformTunnelStartupStageHostBringup,
    PlatformTunnelStartupStage.runtimeAttach =>
      t.sharedPlatformTunnelStartupStageRuntimeAttach,
    PlatformTunnelStartupStage.dataplaneVerify =>
      t.sharedPlatformTunnelStartupStageDataplaneVerify,
  };
}

enum PlatformTunnelLifecycleState {
  setupNeeded('setup_needed'),
  permission('permission'),
  starting('starting'),
  ready('ready'),
  stopping('stopping'),
  stopped('stopped'),
  failed('failed');

  const PlatformTunnelLifecycleState(this.value);

  final String value;

  static PlatformTunnelLifecycleState? fromJson(String? raw) {
    for (final state in values) {
      if (state.value == raw) {
        return state;
      }
    }
    return null;
  }
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
    this.transportProfileStore,
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
      transportProfileStore:
          json['transport_profile_store'] is Map<String, dynamic>
          ? TransportProfileStoreCapability.fromJson(
              json['transport_profile_store'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  final String contractVersion;
  final BuildIdentity build;
  final List<Capability> capabilities;
  final List<PlatformTunnelCapability> platformTunnels;
  final TransportProfileStoreCapability? transportProfileStore;

  String get version => contractVersion;
}

class PlatformTunnelCapability {
  const PlatformTunnelCapability({
    required this.mode,
    required this.available,
    this.satisfiedPrerequisites = const <PlatformTunnelPrerequisite>[],
    this.supportedUnderlayRoutePolicies =
        const <PlatformTunnelUnderlayRoutePolicy>[],
    this.executionPlans = const <RuntimeExecutionPlanDescriptor>[],
    this.missingPrerequisite,
    this.message = '',
  });

  factory PlatformTunnelCapability.fromJson(Map<String, dynamic> json) {
    final mode = _requirePlatformTunnelMode(json['mode']);
    final available = json['available'] as bool? ?? false;
    final satisfiedPrerequisites = _readSatisfiedPrerequisites(
      json['satisfied_prerequisites'],
    );
    final supportedUnderlayRoutePolicies = _readSupportedUnderlayRoutePolicies(
      json['supported_underlay_route_policies'],
      mode: mode,
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
      supportedUnderlayRoutePolicies: supportedUnderlayRoutePolicies,
      executionPlans:
          (json['execution_plans'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (dynamic entry) => RuntimeExecutionPlanDescriptor.fromJson(
                  entry as Map<String, dynamic>,
                ),
              )
              .toList(growable: false),
      missingPrerequisite: missingPrerequisite,
      message: json['message'] as String? ?? '',
    );
  }

  final PlatformTunnelMode mode;
  final bool available;
  final List<PlatformTunnelPrerequisite> satisfiedPrerequisites;
  final List<PlatformTunnelUnderlayRoutePolicy> supportedUnderlayRoutePolicies;
  final List<RuntimeExecutionPlanDescriptor> executionPlans;
  final PlatformTunnelPrerequisite? missingPrerequisite;
  final String message;

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'mode': mode.value,
      'available': available,
      'satisfied_prerequisites': satisfiedPrerequisites
          .map((PlatformTunnelPrerequisite prerequisite) => prerequisite.value)
          .toList(growable: false),
      'supported_underlay_route_policies': supportedUnderlayRoutePolicies
          .map((PlatformTunnelUnderlayRoutePolicy policy) => policy.value)
          .toList(growable: false),
      'execution_plans': executionPlans
          .map((RuntimeExecutionPlanDescriptor plan) => plan.toJson())
          .toList(growable: false),
      'missing_prerequisite': missingPrerequisite?.value,
      'message': message.isEmpty ? null : message,
    });
  }
}

class PlatformTunnelDataplaneEvidence {
  const PlatformTunnelDataplaneEvidence({
    required this.hostAttached,
    required this.wireGuardHandshakeFresh,
    required this.bidirectionalTrafficVerified,
    this.wireGuardRxBytesDelta = 0,
    this.wireGuardTxBytesDelta = 0,
    this.wintunReceivedBytesDelta = 0,
    this.remoteEgressIp = '',
    this.expectedRemoteEgressIp = '',
  });

  factory PlatformTunnelDataplaneEvidence.fromJson(Map<String, dynamic> json) {
    return PlatformTunnelDataplaneEvidence(
      hostAttached: json['host_attached'] as bool? ?? false,
      wireGuardHandshakeFresh:
          json['wireguard_handshake_fresh'] as bool? ?? false,
      wireGuardRxBytesDelta: _readInt(json['wireguard_rx_bytes_delta']),
      wireGuardTxBytesDelta: _readInt(json['wireguard_tx_bytes_delta']),
      wintunReceivedBytesDelta: _readInt(json['wintun_received_bytes_delta']),
      remoteEgressIp: json['remote_egress_ip'] as String? ?? '',
      expectedRemoteEgressIp:
          json['expected_remote_egress_ip'] as String? ?? '',
      bidirectionalTrafficVerified:
          json['bidirectional_traffic_verified'] as bool? ?? false,
    );
  }

  final bool hostAttached;
  final bool wireGuardHandshakeFresh;
  final int wireGuardRxBytesDelta;
  final int wireGuardTxBytesDelta;
  final int wintunReceivedBytesDelta;
  final String remoteEgressIp;
  final String expectedRemoteEgressIp;
  final bool bidirectionalTrafficVerified;

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'host_attached': hostAttached,
      'wireguard_handshake_fresh': wireGuardHandshakeFresh,
      'wireguard_rx_bytes_delta': wireGuardRxBytesDelta == 0
          ? null
          : wireGuardRxBytesDelta,
      'wireguard_tx_bytes_delta': wireGuardTxBytesDelta == 0
          ? null
          : wireGuardTxBytesDelta,
      'wintun_received_bytes_delta': wintunReceivedBytesDelta == 0
          ? null
          : wintunReceivedBytesDelta,
      'remote_egress_ip': remoteEgressIp.isEmpty ? null : remoteEgressIp,
      'expected_remote_egress_ip': expectedRemoteEgressIp.isEmpty
          ? null
          : expectedRemoteEgressIp,
      'bidirectional_traffic_verified': bidirectionalTrafficVerified,
    });
  }
}

class PlatformTunnelStartResult {
  const PlatformTunnelStartResult({
    required this.mode,
    required this.ready,
    this.executionPlan,
    this.transportProfile,
    this.remoteIngress,
    this.dataplane,
    this.sessionId = '',
    this.stage,
    this.missingPrerequisite,
    this.startupAttemptId = '',
    this.underlayRoutePolicy,
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
    final sessionId = (json['session_id'] as String? ?? '').trim();
    if (ready && missingPrerequisite != null) {
      throw const FormatException(
        'ready platform tunnel startup result unexpectedly reports missing_prerequisite',
      );
    }
    if (!ready && sessionId.isNotEmpty) {
      throw const FormatException(
        'non-ready platform tunnel startup result unexpectedly reports session_id',
      );
    }
    final startupAttemptId = (json['startup_attempt_id'] as String? ?? '')
        .trim();
    if (ready && startupAttemptId.isNotEmpty) {
      throw const FormatException(
        'ready platform tunnel startup result unexpectedly reports startup_attempt_id',
      );
    }
    if (startupAttemptId.isNotEmpty &&
        (stage != PlatformTunnelStartupStage.permissionAcquire ||
            missingPrerequisite != PlatformTunnelPrerequisite.permission)) {
      throw const FormatException(
        'platform tunnel startup result reports startup_attempt_id outside permission prerequisite',
      );
    }
    return PlatformTunnelStartResult(
      mode: mode,
      ready: ready,
      executionPlan: json['execution_plan'] is Map<String, dynamic>
          ? RuntimeExecutionPlan.fromJson(
              json['execution_plan'] as Map<String, dynamic>,
            )
          : null,
      transportProfile: json['transport_profile'] is Map<String, dynamic>
          ? TransportProfileReference.fromJson(
              json['transport_profile'] as Map<String, dynamic>,
            )
          : null,
      remoteIngress: json['remote_ingress'] is Map<String, dynamic>
          ? RuntimeRemoteIngressDiagnostics.fromJson(
              json['remote_ingress'] as Map<String, dynamic>,
            )
          : null,
      dataplane: json['dataplane'] is Map<String, dynamic>
          ? PlatformTunnelDataplaneEvidence.fromJson(
              json['dataplane'] as Map<String, dynamic>,
            )
          : null,
      sessionId: sessionId,
      stage: stage,
      missingPrerequisite: missingPrerequisite,
      startupAttemptId: startupAttemptId,
      underlayRoutePolicy: _readOptionalUnderlayRoutePolicy(
        json['underlay_route_policy'],
        fieldName: 'underlay_route_policy',
      ),
      message: json['message'] as String? ?? '',
    );
  }

  final PlatformTunnelMode mode;
  final bool ready;
  final RuntimeExecutionPlan? executionPlan;
  final TransportProfileReference? transportProfile;
  final RuntimeRemoteIngressDiagnostics? remoteIngress;
  final PlatformTunnelDataplaneEvidence? dataplane;
  final String sessionId;
  final PlatformTunnelStartupStage? stage;
  final PlatformTunnelPrerequisite? missingPrerequisite;
  final String startupAttemptId;
  final PlatformTunnelUnderlayRoutePolicy? underlayRoutePolicy;
  final String message;

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'mode': mode.value,
      'ready': ready,
      'execution_plan': executionPlan?.toJson(),
      'transport_profile': transportProfile?.toJson(),
      'remote_ingress': remoteIngress?.toJson(),
      'dataplane': dataplane?.toJson(),
      'session_id': sessionId.isEmpty ? null : sessionId,
      'stage': stage?.value,
      'missing_prerequisite': missingPrerequisite?.value,
      'startup_attempt_id': startupAttemptId.isEmpty ? null : startupAttemptId,
      'underlay_route_policy': underlayRoutePolicy?.value,
      'message': message.isEmpty ? null : message,
    });
  }
}

class PlatformTunnelStatus {
  const PlatformTunnelStatus({
    required this.mode,
    required this.state,
    required this.ready,
    required this.updatedAt,
    this.sessionId = '',
    this.sourceResolutionId = '',
    this.executionPlan,
    this.transportProfile,
    this.remoteIngress,
    this.dataplane,
    this.applicationRoutingPolicy,
    this.underlayRoutePolicy,
    this.allowedPackages = const <String>[],
    this.disallowedPackages = const <String>[],
    this.stage,
    this.missingPrerequisite,
    this.startupAttemptId = '',
    this.message = '',
  });

  factory PlatformTunnelStatus.fromJson(Map<String, dynamic> json) {
    final state = _requirePlatformTunnelLifecycleState(json['state']);
    return PlatformTunnelStatus(
      mode: _requirePlatformTunnelMode(json['mode']),
      state: state,
      ready:
          json['ready'] as bool? ?? state == PlatformTunnelLifecycleState.ready,
      sessionId: (json['session_id'] as String? ?? '').trim(),
      sourceResolutionId: (json['source_resolution_id'] as String? ?? '')
          .trim(),
      executionPlan: json['execution_plan'] is Map<String, dynamic>
          ? RuntimeExecutionPlan.fromJson(
              json['execution_plan'] as Map<String, dynamic>,
            )
          : null,
      transportProfile: json['transport_profile'] is Map<String, dynamic>
          ? TransportProfileReference.fromJson(
              json['transport_profile'] as Map<String, dynamic>,
            )
          : null,
      remoteIngress: json['remote_ingress'] is Map<String, dynamic>
          ? RuntimeRemoteIngressDiagnostics.fromJson(
              json['remote_ingress'] as Map<String, dynamic>,
            )
          : null,
      dataplane: json['dataplane'] is Map<String, dynamic>
          ? PlatformTunnelDataplaneEvidence.fromJson(
              json['dataplane'] as Map<String, dynamic>,
            )
          : null,
      applicationRoutingPolicy: _readOptionalApplicationRoutingPolicy(
        json['application_routing_policy'],
        fieldName: 'application_routing_policy',
      ),
      underlayRoutePolicy: _readOptionalUnderlayRoutePolicy(
        json['underlay_route_policy'],
        fieldName: 'underlay_route_policy',
      ),
      allowedPackages: _readStringList(json['allowed_packages']),
      disallowedPackages: _readStringList(json['disallowed_packages']),
      stage: _readOptionalPlatformTunnelStage(
        json['stage'],
        fieldName: 'stage',
      ),
      missingPrerequisite: _readOptionalPlatformTunnelPrerequisite(
        json['missing_prerequisite'],
        fieldName: 'missing_prerequisite',
      ),
      startupAttemptId: (json['startup_attempt_id'] as String? ?? '').trim(),
      message: json['message'] as String? ?? '',
      updatedAt: _readTimestamp(json['updated_at']),
    );
  }

  final PlatformTunnelMode mode;
  final PlatformTunnelLifecycleState state;
  final bool ready;
  final String sessionId;
  final String sourceResolutionId;
  final RuntimeExecutionPlan? executionPlan;
  final TransportProfileReference? transportProfile;
  final RuntimeRemoteIngressDiagnostics? remoteIngress;
  final PlatformTunnelDataplaneEvidence? dataplane;
  final PlatformTunnelApplicationRoutingPolicy? applicationRoutingPolicy;
  final PlatformTunnelUnderlayRoutePolicy? underlayRoutePolicy;
  final List<String> allowedPackages;
  final List<String> disallowedPackages;
  final PlatformTunnelStartupStage? stage;
  final PlatformTunnelPrerequisite? missingPrerequisite;
  final String startupAttemptId;
  final String message;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'mode': mode.value,
      'state': state.value,
      'ready': ready,
      'session_id': sessionId.isEmpty ? null : sessionId,
      'source_resolution_id': sourceResolutionId.isEmpty
          ? null
          : sourceResolutionId,
      'execution_plan': executionPlan?.toJson(),
      'transport_profile': transportProfile?.toJson(),
      'remote_ingress': remoteIngress?.toJson(),
      'dataplane': dataplane?.toJson(),
      'application_routing_policy': applicationRoutingPolicy?.value,
      'underlay_route_policy': underlayRoutePolicy?.value,
      'allowed_packages': allowedPackages.isEmpty ? null : allowedPackages,
      'disallowed_packages': disallowedPackages.isEmpty
          ? null
          : disallowedPackages,
      'stage': stage?.value,
      'missing_prerequisite': missingPrerequisite?.value,
      'startup_attempt_id': startupAttemptId.isEmpty ? null : startupAttemptId,
      'message': message.isEmpty ? null : message,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    });
  }
}

class PlatformTunnelStopResult {
  const PlatformTunnelStopResult({
    required this.mode,
    required this.stopped,
    this.message = '',
  });

  factory PlatformTunnelStopResult.fromJson(Map<String, dynamic> json) {
    final mode = _requirePlatformTunnelMode(json['mode']);
    final stopped = json['stopped'] as bool? ?? false;
    if (!stopped) {
      throw const FormatException(
        'platform tunnel stop result missing stopped=true',
      );
    }
    return PlatformTunnelStopResult(
      mode: mode,
      stopped: stopped,
      message: json['message'] as String? ?? '',
    );
  }

  final PlatformTunnelMode mode;
  final bool stopped;
  final String message;

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'mode': mode.value,
      'stopped': stopped,
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
    this.providerSettings = const <String, dynamic>{},
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
      providerSettings: _readJsonObject(json['provider_settings']),
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
  final Map<String, dynamic> providerSettings;
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
    Map<String, dynamic>? providerSettings,
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
      providerSettings: providerSettings ?? this.providerSettings,
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
      'provider_settings': providerSettings.isEmpty ? null : providerSettings,
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

extension ProfileSpecWorkflow on ProfileSpec {
  bool get isManagedVkInviteWorkflow => provider.trim().toLowerCase() == 'vk';
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

enum ProviderConfigAvailabilityState {
  available('available'),
  providerUnavailable('provider_unavailable'),
  schemaUnsupported('schema_unsupported'),
  settingsInvalid('settings_invalid');

  const ProviderConfigAvailabilityState(this.value);

  final String value;

  static ProviderConfigAvailabilityState fromJson(String? raw) {
    for (final state in values) {
      if (state.value == raw) {
        return state;
      }
    }
    return ProviderConfigAvailabilityState.available;
  }
}

extension ProviderConfigAvailabilityStateDisplay
    on ProviderConfigAvailabilityState {
  String get label => switch (this) {
    ProviderConfigAvailabilityState.available =>
      t.sharedProviderConfigAvailabilityStateAvailable,
    ProviderConfigAvailabilityState.providerUnavailable =>
      t.sharedProviderConfigAvailabilityStateProviderUnavailable,
    ProviderConfigAvailabilityState.schemaUnsupported =>
      t.sharedProviderConfigAvailabilityStateSchemaUnsupported,
    ProviderConfigAvailabilityState.settingsInvalid =>
      t.sharedProviderConfigAvailabilityStateSettingsInvalid,
  };
}

class ProviderConfigAvailability {
  const ProviderConfigAvailability({
    this.state = ProviderConfigAvailabilityState.available,
    String message = '',
    this.messageLocalized = const <String, String>{},
    this.field = '',
    this.violation = '',
  }) : _message = message;

  factory ProviderConfigAvailability.fromJson(Map<String, dynamic> json) {
    return ProviderConfigAvailability(
      state: ProviderConfigAvailabilityState.fromJson(json['state'] as String?),
      message: json['message'] as String? ?? '',
      messageLocalized: _readLocalizedTextMap(json['message_localized']),
      field: json['field'] as String? ?? '',
      violation: json['violation'] as String? ?? '',
    );
  }

  final ProviderConfigAvailabilityState state;
  final String _message;
  final LocalizedTextMap messageLocalized;
  final String field;
  final String violation;

  bool get isAvailable => state == ProviderConfigAvailabilityState.available;

  String get baseMessage => _message;

  String get message => _resolveLocalizedText(_message, messageLocalized);

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'state': state.value,
      'message': baseMessage.isEmpty ? null : baseMessage,
      'message_localized': messageLocalized.isEmpty ? null : messageLocalized,
      'field': field.isEmpty ? null : field,
      'violation': violation.isEmpty ? null : violation,
    });
  }
}

class ProviderConfigRecord {
  const ProviderConfigRecord({
    required this.id,
    required this.provider,
    required this.name,
    required this.providerSettings,
    required this.createdAt,
    required this.updatedAt,
    this.availability = const ProviderConfigAvailability(),
  });

  factory ProviderConfigRecord.fromJson(Map<String, dynamic> json) {
    return ProviderConfigRecord(
      id: json['id'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      name: json['name'] as String? ?? '',
      providerSettings: _readJsonObject(json['provider_settings']),
      createdAt: _readTimestamp(json['created_at']),
      updatedAt: _readTimestamp(json['updated_at']),
      availability: json['availability'] is Map<String, dynamic>
          ? ProviderConfigAvailability.fromJson(
              json['availability'] as Map<String, dynamic>,
            )
          : const ProviderConfigAvailability(),
    );
  }

  final String id;
  final String provider;
  final String name;
  final Map<String, dynamic> providerSettings;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProviderConfigAvailability availability;

  bool get isAvailable => availability.isAvailable;

  ProviderConfigRecord copyWith({
    String? id,
    String? provider,
    String? name,
    Map<String, dynamic>? providerSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
    ProviderConfigAvailability? availability,
  }) {
    return ProviderConfigRecord(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      name: name ?? this.name,
      providerSettings: providerSettings ?? this.providerSettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      availability: availability ?? this.availability,
    );
  }

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'id': id.isEmpty ? null : id,
      'provider': provider,
      'name': name,
      'provider_settings': providerSettings.isEmpty ? null : providerSettings,
      'availability': availability.toJson(),
      'created_at': createdAt.millisecondsSinceEpoch == 0
          ? null
          : createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.millisecondsSinceEpoch == 0
          ? null
          : updatedAt.toUtc().toIso8601String(),
    });
  }
}

enum ProfileProviderMode {
  managed('managed'),
  custom('custom');

  const ProfileProviderMode(this.value);

  final String value;

  static ProfileProviderMode fromJson(String? raw) {
    for (final mode in values) {
      if (mode.value == raw) {
        return mode;
      }
    }
    return ProfileProviderMode.custom;
  }
}

class ProfileProviderBinding {
  const ProfileProviderBinding({
    this.mode = ProfileProviderMode.custom,
    this.managedProviderId,
  });

  factory ProfileProviderBinding.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ProfileProviderBinding();
    }
    final managedProviderId = (json['managed_provider_id'] as String? ?? '')
        .trim();
    return ProfileProviderBinding(
      mode: ProfileProviderMode.fromJson(json['mode'] as String?),
      managedProviderId: managedProviderId.isEmpty ? null : managedProviderId,
    );
  }

  final ProfileProviderMode mode;
  final String? managedProviderId;

  bool get isManaged => mode == ProfileProviderMode.managed;

  ProfileProviderBinding copyWith({
    ProfileProviderMode? mode,
    String? managedProviderId,
    bool clearManagedProviderId = false,
  }) {
    return ProfileProviderBinding(
      mode: mode ?? this.mode,
      managedProviderId: clearManagedProviderId
          ? null
          : managedProviderId ?? this.managedProviderId,
    );
  }

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'mode': mode.value,
      'managed_provider_id': managedProviderId,
    });
  }
}

enum SupportedProviderAvailabilityState {
  available('available'),
  providerUnavailable('provider_unavailable');

  const SupportedProviderAvailabilityState(this.value);

  final String value;
}

class SupportedProviderAvailability {
  const SupportedProviderAvailability({
    required this.state,
    required this.message,
    this.descriptor,
  });

  final SupportedProviderAvailabilityState state;
  final String message;
  final ProviderDescriptor? descriptor;

  bool get isAvailable => state == SupportedProviderAvailabilityState.available;
}

class SupportedProviderDefinition {
  const SupportedProviderDefinition({required this.id});

  final String id;

  String get title => switch (id.trim().toLowerCase()) {
    'vk' => t.sharedCatalogSupportedProviderVkTitle,
    'generic-turn' => t.sharedCatalogSupportedProviderGenericTurnTitle,
    _ => id,
  };

  String get description => switch (id.trim().toLowerCase()) {
    'vk' => t.sharedCatalogSupportedProviderVkDescription,
    'generic-turn' => t.sharedCatalogSupportedProviderGenericTurnDescription,
    _ => '',
  };

  String get suggestedManagedProviderName => switch (id.trim().toLowerCase()) {
    'vk' => t.sharedCatalogSupportedProviderVkSuggestedManagedProviderName,
    'generic-turn' =>
      t.sharedCatalogSupportedProviderGenericTurnSuggestedManagedProviderName,
    _ => id,
  };

  SupportedProviderAvailability availabilityFor(
    Iterable<ProviderDescriptor> descriptors,
  ) {
    final providerId = id.trim().toLowerCase();
    for (final descriptor in descriptors) {
      if (descriptor.id.trim().toLowerCase() != providerId) {
        continue;
      }
      return SupportedProviderAvailability(
        state: SupportedProviderAvailabilityState.available,
        message: '',
        descriptor: descriptor,
      );
    }
    return SupportedProviderAvailability(
      state: SupportedProviderAvailabilityState.providerUnavailable,
      message:
          'The connected host does not advertise the $title provider family yet.',
    );
  }
}

SupportedProviderDefinition? supportedProviderDefinitionFor(String providerId) {
  final normalized = providerId.trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }
  for (final provider in kSupportedProviderCatalog) {
    if (provider.id.trim().toLowerCase() == normalized) {
      return provider;
    }
  }
  return null;
}

class ManagedProviderRecord {
  const ManagedProviderRecord({
    required this.id,
    required this.provider,
    required this.name,
    required this.providerSettings,
    required this.createdAt,
    required this.updatedAt,
    this.availability = const ProviderConfigAvailability(),
  });

  factory ManagedProviderRecord.fromJson(Map<String, dynamic> json) {
    return ManagedProviderRecord(
      id: json['id'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      name: json['name'] as String? ?? '',
      providerSettings: _readJsonObject(json['provider_settings']),
      createdAt: _readTimestamp(json['created_at']),
      updatedAt: _readTimestamp(json['updated_at']),
      availability: json['availability'] is Map<String, dynamic>
          ? ProviderConfigAvailability.fromJson(
              json['availability'] as Map<String, dynamic>,
            )
          : const ProviderConfigAvailability(),
    );
  }

  factory ManagedProviderRecord.fromLegacyProviderConfig(
    ProviderConfigRecord record,
  ) {
    return ManagedProviderRecord(
      id: record.id,
      provider: record.provider,
      name: record.name,
      providerSettings: record.providerSettings,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      availability: record.availability,
    );
  }

  final String id;
  final String provider;
  final String name;
  final Map<String, dynamic> providerSettings;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProviderConfigAvailability availability;

  bool get isAvailable => availability.isAvailable;

  ManagedProviderRecord copyWith({
    String? id,
    String? provider,
    String? name,
    Map<String, dynamic>? providerSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
    ProviderConfigAvailability? availability,
  }) {
    return ManagedProviderRecord(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      name: name ?? this.name,
      providerSettings: providerSettings ?? this.providerSettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      availability: availability ?? this.availability,
    );
  }

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'id': id.isEmpty ? null : id,
      'provider': provider,
      'name': name,
      'provider_settings': providerSettings.isEmpty ? null : providerSettings,
      'availability': availability.toJson(),
      'created_at': createdAt.millisecondsSinceEpoch == 0
          ? null
          : createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.millisecondsSinceEpoch == 0
          ? null
          : updatedAt.toUtc().toIso8601String(),
    });
  }
}

class ProviderTemplateRecord {
  const ProviderTemplateRecord({
    required this.id,
    required this.provider,
    required this.name,
    required this.providerSettings,
    required this.createdAt,
    required this.updatedAt,
    this.availability = const ProviderConfigAvailability(),
  });

  factory ProviderTemplateRecord.fromJson(Map<String, dynamic> json) {
    return ProviderTemplateRecord(
      id: json['id'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      name: json['name'] as String? ?? '',
      providerSettings: _readJsonObject(json['provider_settings']),
      createdAt: _readTimestamp(json['created_at']),
      updatedAt: _readTimestamp(json['updated_at']),
      availability: json['availability'] is Map<String, dynamic>
          ? ProviderConfigAvailability.fromJson(
              json['availability'] as Map<String, dynamic>,
            )
          : const ProviderConfigAvailability(),
    );
  }

  final String id;
  final String provider;
  final String name;
  final Map<String, dynamic> providerSettings;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProviderConfigAvailability availability;

  bool get isAvailable => availability.isAvailable;

  ProviderTemplateRecord copyWith({
    String? id,
    String? provider,
    String? name,
    Map<String, dynamic>? providerSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
    ProviderConfigAvailability? availability,
  }) {
    return ProviderTemplateRecord(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      name: name ?? this.name,
      providerSettings: providerSettings ?? this.providerSettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      availability: availability ?? this.availability,
    );
  }

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'id': id.isEmpty ? null : id,
      'provider': provider,
      'name': name,
      'provider_settings': providerSettings.isEmpty ? null : providerSettings,
      'availability': availability.toJson(),
      'created_at': createdAt.millisecondsSinceEpoch == 0
          ? null
          : createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.millisecondsSinceEpoch == 0
          ? null
          : updatedAt.toUtc().toIso8601String(),
    });
  }
}

enum ProviderPresetAvailabilityState {
  available('available'),
  providerUnavailable('provider_unavailable');

  const ProviderPresetAvailabilityState(this.value);

  final String value;
}

class ProviderPresetAvailability {
  const ProviderPresetAvailability({
    required this.state,
    required this.message,
    this.descriptor,
  });

  final ProviderPresetAvailabilityState state;
  final String message;
  final ProviderDescriptor? descriptor;

  bool get isAvailable => state == ProviderPresetAvailabilityState.available;
}

class ProviderPreset {
  const ProviderPreset({
    required this.id,
    required this.provider,
    this.seedProviderSettings = const <String, dynamic>{},
  });

  final String id;
  final String provider;
  final Map<String, dynamic> seedProviderSettings;

  String get title => switch (id.trim().toLowerCase()) {
    'vk-default' => t.sharedCatalogPresetVkDefaultTitle,
    'generic-turn-default' => t.sharedCatalogPresetGenericTurnDefaultTitle,
    _ => provider,
  };

  String get description => switch (id.trim().toLowerCase()) {
    'vk-default' => t.sharedCatalogPresetVkDefaultDescription,
    'generic-turn-default' =>
      t.sharedCatalogPresetGenericTurnDefaultDescription,
    _ => '',
  };

  String get suggestedProfileName => switch (id.trim().toLowerCase()) {
    'vk-default' => t.sharedCatalogPresetVkDefaultSuggestedProfileName,
    'generic-turn-default' =>
      t.sharedCatalogPresetGenericTurnDefaultSuggestedProfileName,
    _ => provider,
  };

  ProviderPresetAvailability availabilityFor(
    Iterable<ProviderDescriptor> descriptors,
  ) {
    final providerId = provider.trim().toLowerCase();
    for (final descriptor in descriptors) {
      if (descriptor.id.trim().toLowerCase() != providerId) {
        continue;
      }
      return ProviderPresetAvailability(
        state: ProviderPresetAvailabilityState.available,
        message: '',
        descriptor: descriptor,
      );
    }
    return ProviderPresetAvailability(
      state: ProviderPresetAvailabilityState.providerUnavailable,
      message:
          'The connected host does not advertise the $title provider family yet.',
    );
  }

  Map<String, dynamic> normalizedSeedSettings(ProviderDescriptor? descriptor) {
    if (descriptor == null) {
      return const <String, dynamic>{};
    }
    return descriptor.normalizeProviderSettings(seedProviderSettings);
  }
}

const List<ProviderPreset> kProviderPresetCatalog = <ProviderPreset>[
  ProviderPreset(id: 'vk-default', provider: 'vk'),
  ProviderPreset(id: 'generic-turn-default', provider: 'generic-turn'),
];

const List<SupportedProviderDefinition> kSupportedProviderCatalog =
    <SupportedProviderDefinition>[
      SupportedProviderDefinition(id: 'vk'),
      SupportedProviderDefinition(id: 'generic-turn'),
    ];

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

  factory RuntimeDefaults.fromJson(Map<String, dynamic> json) {
    return RuntimeDefaults(
      listenAddress: json['listen_addr'] as String? ?? '',
      peerAddress: json['peer_addr'] as String? ?? '',
      connections: json['connections'] as int? ?? 1,
      turnServer: json['turn_server'] as String?,
      turnPort: json['turn_port'] as String?,
      bindInterface: json['bind_interface'] as String?,
      mode: TransportMode.fromJson(json['mode'] as String?),
      useDtls: json['use_dtls'] as bool? ?? true,
      logLevel: json['log_level'] as String? ?? 'info',
    );
  }

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
    this.executionPlans = const <RuntimeExecutionPlanDescriptor>[],
  });

  factory ResolutionActionRecord.fromJson(Map<String, dynamic> json) {
    return ResolutionActionRecord(
      id:
          ArtifactAction.fromJson(json['id'] as String?) ??
          ArtifactAction.exportHandoff,
      executionOwner: ActionExecutionOwner.fromJson(
        json['execution_owner'] as String?,
      ),
      executionPlans:
          (json['execution_plans'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (dynamic entry) => RuntimeExecutionPlanDescriptor.fromJson(
                  entry as Map<String, dynamic>,
                ),
              )
              .toList(growable: false),
    );
  }

  final ArtifactAction id;
  final ActionExecutionOwner executionOwner;
  final List<RuntimeExecutionPlanDescriptor> executionPlans;

  Map<String, dynamic> toJson() {
    return _compact(<String, dynamic>{
      'id': id.value,
      'execution_owner': executionOwner.value,
      'execution_plans': executionPlans
          .map((RuntimeExecutionPlanDescriptor plan) => plan.toJson())
          .toList(growable: false),
    });
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
    this.accessMethods = const <RuntimeAccessMethod>[],
    this.actions = const <ResolutionActionRecord>[],
    this.summary = const ResolutionArtifactSummary(),
  });

  factory ResolutionArtifactRecord.fromJson(Map<String, dynamic> json) {
    return ResolutionArtifactRecord(
      family:
          ArtifactFamily.fromJson(json['family'] as String?) ??
          ArtifactFamily.genericTurn,
      accessMethods:
          (json['access_methods'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (dynamic raw) => RuntimeAccessMethod.fromJson(raw as String?),
              )
              .whereType<RuntimeAccessMethod>()
              .toList(growable: false),
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
  final List<RuntimeAccessMethod> accessMethods;
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

  List<RuntimeExecutionPlanDescriptor> executionPlansForAction(
    ArtifactAction action,
  ) {
    return this.action(action)?.executionPlans ??
        const <RuntimeExecutionPlanDescriptor>[];
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
      'access_methods': accessMethods
          .map((RuntimeAccessMethod method) => method.value)
          .toList(growable: false),
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
    this.completionMode = ChallengeCompletionMode.manualConfirm,
    this.browserReturn,
    this.ownedBrowser,
  });

  factory ChallengeRecord.fromJson(Map<String, dynamic> json) {
    final browserReturn = json['browser_return'] is Map<String, dynamic>
        ? ChallengeBrowserReturnMetadata.fromJson(
            json['browser_return'] as Map<String, dynamic>,
          )
        : null;
    final ownedBrowser = json['owned_browser'] is Map<String, dynamic>
        ? ChallengeOwnedBrowserMetadata.fromJson(
            json['owned_browser'] as Map<String, dynamic>,
          )
        : null;
    final completionMode =
        ChallengeCompletionMode.fromJson(json['completion_mode'] as String?) ??
        ChallengeCompletionMode.manualConfirm;
    final normalized = _normalizeChallengeCompletion(
      completionMode: completionMode,
      browserReturn: browserReturn,
      ownedBrowser: ownedBrowser,
    );
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
      completionMode: normalized.completionMode,
      browserReturn: normalized.browserReturn,
      ownedBrowser: normalized.ownedBrowser,
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
  final ChallengeCompletionMode completionMode;
  final ChallengeBrowserReturnMetadata? browserReturn;
  final ChallengeOwnedBrowserMetadata? ownedBrowser;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChallengeRecord copyWith({
    ChallengeStatus? status,
    ChallengeCompletionMode? completionMode,
    ChallengeBrowserReturnMetadata? browserReturn,
    ChallengeOwnedBrowserMetadata? ownedBrowser,
    DateTime? updatedAt,
  }) {
    return ChallengeRecord(
      id: id,
      sessionId: sessionId,
      resolutionId: resolutionId,
      provider: provider,
      stage: stage,
      kind: kind,
      prompt: prompt,
      openUrl: openUrl,
      status: status ?? this.status,
      completionMode: completionMode ?? this.completionMode,
      browserReturn: browserReturn ?? this.browserReturn,
      ownedBrowser: ownedBrowser ?? this.ownedBrowser,
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
      'completion_mode': completionMode.value,
      'browser_return': browserReturn?.toJson(),
      'owned_browser': ownedBrowser?.toJson(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    });
  }
}

class _NormalizedChallengeCompletion {
  const _NormalizedChallengeCompletion({
    required this.completionMode,
    required this.browserReturn,
    required this.ownedBrowser,
  });

  final ChallengeCompletionMode completionMode;
  final ChallengeBrowserReturnMetadata? browserReturn;
  final ChallengeOwnedBrowserMetadata? ownedBrowser;
}

_NormalizedChallengeCompletion _normalizeChallengeCompletion({
  required ChallengeCompletionMode completionMode,
  required ChallengeBrowserReturnMetadata? browserReturn,
  required ChallengeOwnedBrowserMetadata? ownedBrowser,
}) {
  switch (completionMode) {
    case ChallengeCompletionMode.manualConfirm:
      return const _NormalizedChallengeCompletion(
        completionMode: ChallengeCompletionMode.manualConfirm,
        browserReturn: null,
        ownedBrowser: null,
      );
    case ChallengeCompletionMode.ownedBrowserObserved:
      if (ownedBrowser == null || ownedBrowser.cookieUrls.isEmpty) {
        return const _NormalizedChallengeCompletion(
          completionMode: ChallengeCompletionMode.manualConfirm,
          browserReturn: null,
          ownedBrowser: null,
        );
      }
      return _NormalizedChallengeCompletion(
        completionMode: ChallengeCompletionMode.ownedBrowserObserved,
        browserReturn: null,
        ownedBrowser: ownedBrowser,
      );
    case ChallengeCompletionMode.appReturnCallback:
      if (browserReturn == null ||
          !browserReturn.allowAutoContinue ||
          browserReturn.signalKinds.isEmpty) {
        return const _NormalizedChallengeCompletion(
          completionMode: ChallengeCompletionMode.manualConfirm,
          browserReturn: null,
          ownedBrowser: null,
        );
      }
      return _NormalizedChallengeCompletion(
        completionMode: ChallengeCompletionMode.appReturnCallback,
        browserReturn: browserReturn,
        ownedBrowser: null,
      );
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
    this.requestedExecutionPlan,
    this.field,
    this.violation,
    this.stage,
    this.notImplemented = false,
  });

  final int statusCode;
  final String code;
  final String message;
  final String? action;
  final RuntimeExecutionPlan? requestedExecutionPlan;
  final String? field;
  final String? violation;
  final String? stage;
  final bool notImplemented;

  bool get incompatibleHost => statusCode == 409 && code == 'incompatible_host';

  @override
  String toString() {
    return 'ControlPlaneError(status=$statusCode, code=$code, message=$message, action=$action, requestedExecutionPlan=$requestedExecutionPlan, field=$field, violation=$violation, stage=$stage, notImplemented=$notImplemented)';
  }
}

DateTime _readTimestamp(dynamic raw) {
  if (raw is String && raw.isNotEmpty) {
    return DateTime.parse(raw).toLocal();
  }
  return DateTime.fromMillisecondsSinceEpoch(0).toLocal();
}

int _readInt(dynamic raw) {
  if (raw == null) {
    return 0;
  }
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  throw FormatException('expected integer value, got $raw');
}

Map<String, dynamic> _compact(Map<String, dynamic> values) {
  values.removeWhere((String _, dynamic value) => value == null);
  return values;
}

Map<String, ProviderSettingProperty> _readProviderSettingProperties(
  dynamic raw,
) {
  if (raw is! Map) {
    return const <String, ProviderSettingProperty>{};
  }
  final values = <String, ProviderSettingProperty>{};
  raw.forEach((dynamic key, dynamic value) {
    if (value is! Map<String, dynamic>) {
      return;
    }
    final normalizedKey = (key as String? ?? '').trim();
    if (normalizedKey.isEmpty) {
      return;
    }
    values[normalizedKey] = ProviderSettingProperty.fromJson(value);
  });
  return values;
}

Map<String, dynamic> _readJsonObject(dynamic raw) {
  if (raw is! Map) {
    return const <String, dynamic>{};
  }
  final values = <String, dynamic>{};
  raw.forEach((dynamic key, dynamic value) {
    final normalizedKey = (key as String? ?? '').trim();
    if (normalizedKey.isEmpty) {
      return;
    }
    values[normalizedKey] = value;
  });
  return values;
}

List<dynamic> _readScalarList(dynamic raw) {
  return (raw as List<dynamic>? ?? const <dynamic>[])
      .where(_isScalarJsonValue)
      .toList(growable: false);
}

dynamic _scalarJsonValueOrNull(dynamic raw) {
  return _isScalarJsonValue(raw) ? raw : null;
}

bool _isScalarJsonValue(dynamic value) {
  return value is String || value is num || value is bool;
}

String? _unsupportedPropertyReason(
  String key,
  ProviderSettingProperty property,
) {
  if (property.type == null) {
    return 'provider setting $key is missing a supported scalar type';
  }
  if (property.control == null) {
    return 'provider setting $key is missing x-vkturn-control';
  }
  if (property.persistence == null) {
    return 'provider setting $key is missing x-vkturn-persistence';
  }
  if (property.writeOnly &&
      property.persistence != ProviderSettingPersistence.ephemeral) {
    return 'provider setting $key declares writeOnly ${property.persistence!.value} persistence which is unsupported';
  }
  if (property.control == ProviderSettingControl.select &&
      property.enumValues.isEmpty) {
    return 'provider setting $key uses select without enum values';
  }
  if (property.control == ProviderSettingControl.checkbox &&
      property.type != ProviderSettingType.boolean) {
    return 'provider setting $key uses checkbox but is not boolean';
  }
  if ((property.minLength != null ||
          property.maxLength != null ||
          (property.pattern ?? '').isNotEmpty) &&
      property.type != ProviderSettingType.string) {
    return 'provider setting $key uses string validation keywords but is not string';
  }
  if (property.minLength != null &&
      property.maxLength != null &&
      property.minLength! > property.maxLength!) {
    return 'provider setting $key declares minLength greater than maxLength';
  }
  if ((property.minimum != null || property.maximum != null) &&
      property.type != ProviderSettingType.integer &&
      property.type != ProviderSettingType.number) {
    return 'provider setting $key uses numeric range keywords but is not numeric';
  }
  if (property.minimum != null &&
      property.maximum != null &&
      property.minimum! > property.maximum!) {
    return 'provider setting $key declares minimum greater than maximum';
  }
  if ((property.pattern ?? '').isNotEmpty) {
    try {
      RegExp(property.pattern!);
    } on FormatException {
      return 'provider setting $key declares an invalid pattern';
    }
  }
  if (property.defaultValue != null &&
      !_matchesProviderSettingType(property.defaultValue, property.type!)) {
    return 'provider setting $key has a default that does not match ${property.type!.value}';
  }
  if (property.control == ProviderSettingControl.select &&
      property.defaultValue != null &&
      !property.enumValues.contains(property.defaultValue)) {
    return 'provider setting $key declares a default that is not one of the enum values';
  }
  for (final candidate in property.enumValues) {
    if (!_matchesProviderSettingType(candidate, property.type!)) {
      return 'provider setting $key has an enum value that does not match ${property.type!.value}';
    }
  }
  for (final candidate in property.examples) {
    if (!_matchesProviderSettingType(candidate, property.type!)) {
      return 'provider setting $key has an example that does not match ${property.type!.value}';
    }
  }
  return null;
}

bool _matchesProviderSettingType(dynamic value, ProviderSettingType type) {
  return switch (type) {
    ProviderSettingType.string => value is String,
    ProviderSettingType.integer => value is int,
    ProviderSettingType.number => value is num,
    ProviderSettingType.boolean => value is bool,
  };
}

bool _canShellRepresentProviderSettingValue(
  ProviderSettingProperty property,
  dynamic value,
) {
  if (value == null || property.type == null) {
    return false;
  }
  switch (property.control) {
    case ProviderSettingControl.select:
      return property.enumValues.contains(value) &&
          _matchesProviderSettingConstraints(property, value);
    case ProviderSettingControl.checkbox:
      return value is bool &&
          _matchesProviderSettingConstraints(property, value);
    case ProviderSettingControl.text:
    case ProviderSettingControl.textarea:
    case ProviderSettingControl.password:
      return _isScalarJsonValue(value) &&
          _matchesProviderSettingConstraints(property, value);
    case null:
      return false;
  }
}

bool _matchesProviderSettingConstraints(
  ProviderSettingProperty property,
  dynamic value,
) {
  if (property.type == null ||
      !_matchesProviderSettingType(value, property.type!)) {
    return false;
  }
  switch (property.type!) {
    case ProviderSettingType.string:
      final text = value as String;
      if (property.minLength != null &&
          text.runes.length < property.minLength!) {
        return false;
      }
      if (property.maxLength != null &&
          text.runes.length > property.maxLength!) {
        return false;
      }
      final pattern = property.pattern;
      if (pattern != null &&
          pattern.isNotEmpty &&
          !RegExp(pattern).hasMatch(text)) {
        return false;
      }
      return true;
    case ProviderSettingType.integer:
      final number = (value as int).toDouble();
      if (property.minimum != null && number < property.minimum!) {
        return false;
      }
      if (property.maximum != null && number > property.maximum!) {
        return false;
      }
      return true;
    case ProviderSettingType.number:
      final number = (value as num).toDouble();
      if (property.minimum != null && number < property.minimum!) {
        return false;
      }
      if (property.maximum != null && number > property.maximum!) {
        return false;
      }
      return true;
    case ProviderSettingType.boolean:
      return true;
  }
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

PlatformTunnelLifecycleState _requirePlatformTunnelLifecycleState(dynamic raw) {
  final value = raw as String?;
  final state = PlatformTunnelLifecycleState.fromJson(value);
  if (state != null) {
    return state;
  }
  throw FormatException(
    'invalid platform tunnel lifecycle state: ${value ?? '<missing>'}',
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

List<String> _readStringList(dynamic raw) {
  final values = raw as List<dynamic>? ?? const <dynamic>[];
  return values
      .map((dynamic item) {
        if (item is String) {
          return item.trim();
        }
        throw const FormatException('expected string list values');
      })
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);
}

List<PlatformTunnelUnderlayRoutePolicy> _readSupportedUnderlayRoutePolicies(
  dynamic raw, {
  required PlatformTunnelMode mode,
}) {
  final values = raw as List<dynamic>? ?? const <dynamic>[];
  if (values.isEmpty) {
    if (mode == PlatformTunnelMode.androidVpnService) {
      return const <PlatformTunnelUnderlayRoutePolicy>[
        PlatformTunnelUnderlayRoutePolicy.standard,
      ];
    }
    return const <PlatformTunnelUnderlayRoutePolicy>[];
  }
  return values
      .map((dynamic item) {
        if (item is! String) {
          throw const FormatException(
            'platform tunnel underlay route policies must be string values',
          );
        }
        final policy = PlatformTunnelUnderlayRoutePolicy.fromJson(item);
        if (policy != null) {
          return policy;
        }
        throw FormatException(
          'invalid platform tunnel underlay route policy: $item',
        );
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

PlatformTunnelApplicationRoutingPolicy? _readOptionalApplicationRoutingPolicy(
  dynamic raw, {
  required String fieldName,
}) {
  final value = raw as String?;
  if (value == null || value.isEmpty) {
    return null;
  }
  final policy = PlatformTunnelApplicationRoutingPolicy.fromJson(value);
  if (policy != null) {
    return policy;
  }
  throw FormatException('invalid $fieldName: $value');
}

PlatformTunnelUnderlayRoutePolicy? _readOptionalUnderlayRoutePolicy(
  dynamic raw, {
  required String fieldName,
}) {
  final value = raw as String?;
  if (value == null || value.isEmpty) {
    return null;
  }
  final policy = PlatformTunnelUnderlayRoutePolicy.fromJson(value);
  if (policy != null) {
    return policy;
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

LocalizedTextMap _readLocalizedTextMap(dynamic raw) {
  final values = raw as Map<String, dynamic>? ?? const <String, dynamic>{};
  final localized = <String, String>{};
  values.forEach((String key, dynamic value) {
    final normalizedKey = _normalizeLocaleTag(key);
    final normalizedValue = value is String ? _nonEmpty(value) : null;
    if (normalizedKey == null || normalizedValue == null) {
      return;
    }
    localized[normalizedKey] = normalizedValue;
  });
  return Map<String, String>.unmodifiable(localized);
}

String _resolveLocalizedText(String base, LocalizedTextMap localized) {
  if (localized.isNotEmpty) {
    final exactLocale = _normalizeLocaleTag(currentShellLocaleTag());
    if (exactLocale != null) {
      final exactValue = _nonEmpty(localized[exactLocale]);
      if (exactValue != null) {
        return exactValue;
      }
      final baseLanguage = _localeBaseLanguage(exactLocale);
      if (baseLanguage != null) {
        final baseValue = _nonEmpty(localized[baseLanguage]);
        if (baseValue != null) {
          return baseValue;
        }
      }
    }
  }
  return base;
}

String? _normalizeLocaleTag(String? value) {
  final normalized = value?.trim().replaceAll('_', '-') ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  return normalized.toLowerCase();
}

String? _localeBaseLanguage(String? value) {
  final normalized = _normalizeLocaleTag(value);
  if (normalized == null) {
    return null;
  }
  final separator = normalized.indexOf('-');
  if (separator <= 0) {
    return normalized;
  }
  return normalized.substring(0, separator);
}

String? _nonEmpty(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}
