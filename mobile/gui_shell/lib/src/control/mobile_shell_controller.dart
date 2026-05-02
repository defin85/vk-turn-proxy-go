import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter_shell_core/portable_profile_transfer.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_gui_shell/src/build/app_build_identity.dart';
import 'package:mobile_gui_shell/src/control/control_plane_client.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/mobile_handoff_adapter.dart';
import 'package:mobile_gui_shell/src/control/mobile_host_bridge.dart';
import 'package:mobile_gui_shell/src/control/mobile_platform_app_inventory.dart';
import 'package:mobile_gui_shell/src/control/mobile_portable_profile_transfer_adapter.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_state_store.dart';
import 'package:mobile_gui_shell/src/control/profile_draft.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

typedef DirectoryProvider = Future<Directory> Function();
typedef IDFactory = String Function();
typedef VPNTransportProfileContentPicker = Future<String?> Function();

enum ShellStatus { booting, ready, blocked }

enum MobileWorkflowSurface {
  profile,
  providerConfig,
  providerTemplate,
  provider,
}

abstract class BrowserLauncher {
  Future<bool> open(String url);
}

class ExternalBrowserLauncher implements BrowserLauncher {
  @override
  Future<bool> open(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return false;
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<String?> _pickVPNTransportProfileContents() async {
  final file = await openFile(
    acceptedTypeGroups: const <XTypeGroup>[
      XTypeGroup(
        label: 'WireGuard VPN transport profile',
        extensions: <String>['conf'],
      ),
    ],
  );
  if (file == null) {
    return null;
  }
  return file.readAsString();
}

class MobileShellController extends ChangeNotifier {
  MobileShellController({
    required this.bridge,
    required this.stateStore,
    BrowserLauncher? browserLauncher,
    MobileHandoffAdapter? handoffAdapter,
    MobilePortableProfileTransferAdapter? portableProfileTransferAdapter,
    MobilePlatformAppInventory? appInventory,
    MobileOwnedBrowserSessionStateResetter? ownedBrowserSessionStateResetter,
    VPNTransportProfileContentPicker? transportProfileContentPicker,
    DirectoryProvider? diagnosticsDirectoryProvider,
    DateTime Function()? clock,
    IDFactory? idFactory,
    BuildIdentity? appBuild,
    Duration transientNoticeDuration = const Duration(seconds: 4),
  }) : _browserLauncher = browserLauncher ?? ExternalBrowserLauncher(),
       _handoffAdapter = handoffAdapter ?? const SystemMobileHandoffAdapter(),
       _portableProfileTransferAdapter =
           portableProfileTransferAdapter ??
           SystemMobilePortableProfileTransferAdapter(),
       _appInventory = appInventory ?? PlatformMobilePlatformAppInventory(),
       _ownedBrowserSessionStateResetter =
           ownedBrowserSessionStateResetter ??
           const PlatformMobileOwnedBrowserSessionStateResetter(),
       _transportProfileContentPicker =
           transportProfileContentPicker ?? _pickVPNTransportProfileContents,
       _diagnosticsDirectoryProvider =
           diagnosticsDirectoryProvider ?? defaultDiagnosticsDirectory,
       _clock = clock ?? DateTime.now,
       _idFactory =
           idFactory ??
           (() => DateTime.now().microsecondsSinceEpoch.toRadixString(16)),
       _transientNoticeDuration = transientNoticeDuration,
       appBuild = appBuild ?? AppBuildIdentity.current;

  final MobileHostBridge bridge;
  final MobileShellStateStore stateStore;
  final BrowserLauncher _browserLauncher;
  final MobileHandoffAdapter _handoffAdapter;
  final MobilePortableProfileTransferAdapter _portableProfileTransferAdapter;
  final MobilePlatformAppInventory _appInventory;
  final MobileOwnedBrowserSessionStateResetter
  _ownedBrowserSessionStateResetter;
  final VPNTransportProfileContentPicker _transportProfileContentPicker;
  final DirectoryProvider _diagnosticsDirectoryProvider;
  final DateTime Function() _clock;
  final IDFactory _idFactory;
  final Duration _transientNoticeDuration;
  final BuildIdentity appBuild;

  static const String _draftModePreferenceScope = '__draft__';

  ShellStatus status = ShellStatus.booting;
  MobileHostConnectionResult? hostConnection;
  List<ProviderDescriptor> providerDescriptors = const <ProviderDescriptor>[];
  List<ManagedProviderRecord> managedProviders =
      const <ManagedProviderRecord>[];
  List<ProviderTemplateRecord> providerTemplates =
      const <ProviderTemplateRecord>[];
  List<ProfileRecord> profiles = const <ProfileRecord>[];
  List<ResolutionRecord> resolutions = const <ResolutionRecord>[];
  List<SessionRecord> sessions = const <SessionRecord>[];
  List<EventRecord> events = const <EventRecord>[];
  List<TransportProfileStatus> transportProfiles =
      const <TransportProfileStatus>[];
  List<PlatformTunnelStatus> platformTunnelStatuses =
      const <PlatformTunnelStatus>[];
  ProfileDraft draft = ProfileDraft.defaults();
  ManagedProviderDraft managedProviderDraft = ManagedProviderDraft.defaults();
  ProviderTemplateDraft providerTemplateDraft =
      ProviderTemplateDraft.defaults();
  MobileWorkflowSurface workflowSurface = MobileWorkflowSurface.profile;
  String? currentProfileId;
  String? focusedProfileId;
  PlatformTunnelMode? selectedPlatformTunnelMode;
  String? selectedManagedProviderId;
  String? selectedProviderTemplateId;
  String? selectedResolutionId;
  String? selectedSessionId;
  Map<String, ProfileProviderBinding> profileBindings =
      <String, ProfileProviderBinding>{};
  Map<String, MobilePlatformModePreferences> platformModePreferences =
      <String, MobilePlatformModePreferences>{};
  List<MobilePlatformApp> installedApps = const <MobilePlatformApp>[];
  bool loadingInstalledApps = false;
  String? installedAppsError;
  final Map<PlatformTunnelMode, PlatformTunnelStartResult>
  _platformTunnelResults = <PlatformTunnelMode, PlatformTunnelStartResult>{};
  String? _notice;
  bool busy = false;
  bool _requiresLocalStateReset = false;
  String? _blockedLocalStateMessage;
  bool _forceFreshResolutionAfterEmbeddedSignOut = false;

  final Map<String, ChallengeRecord> _challengeCache =
      <String, ChallengeRecord>{};
  StreamSubscription<EventRecord>? _eventSubscription;
  StreamSubscription<MobileBrowserReturnSignal>? _browserReturnSubscription;
  StreamSubscription<String>? _portableProfileIngressSubscription;
  Timer? _pollTimer;
  Timer? _debounceTimer;
  Timer? _persistTimer;
  Timer? _noticeTimer;
  bool _disposed = false;
  int _portableImportNonce = 0;
  String? _persistedStateSignature;
  String? _browserHandoffChallengeId;
  final Set<String> _autoContinuedChallengeIds = <String>{};
  String? localeOverrideTag;
  PortableProfileEnvelope? _pendingPortableProfileImportEnvelope;
  String? _pendingPortableProfileImportPayload;
  Object? _restoreStateError;

  static const List<Capability> requiredCapabilities = <Capability>[
    Capability.mobileHostBridge,
    Capability.platformTunnels,
    Capability.profiles,
    Capability.providerRuntimeArtifacts,
    Capability.runtimeExecutionPlanning,
    Capability.vpnTransportProfileStore,
    Capability.sessions,
    Capability.challenges,
    Capability.diagnostics,
    Capability.eventStream,
  ];

  bool get requiresLocalStateReset => _requiresLocalStateReset;

  String? get notice => _notice;

  set notice(String? value) {
    _noticeTimer?.cancel();
    _noticeTimer = null;
    _notice = value;
  }

  String? get hostStatusMessage {
    final message = hostConnection?.message.trim() ?? '';
    return message.isEmpty ? null : message;
  }

  String? get surfaceNotice {
    final message = notice?.trim() ?? '';
    if (message.isEmpty) {
      return null;
    }
    final hostMessage = hostStatusMessage;
    if (hostMessage != null && message == hostMessage) {
      return null;
    }
    return message;
  }

  AppLocale get activeLocale => LocaleSettings.currentLocale;
  ShellText get _copy => currentShellText;

  bool get usesSystemLocale => localeOverrideTag == null;

  Future<void> selectLocaleOverride(String? rawLocale) async {
    final previousHostMessage = hostStatusMessage;
    final locale = parseShellLocale(rawLocale);
    localeOverrideTag = locale == null ? null : shellLocaleTag(locale);
    await restoreShellLocale(localeOverrideTag);
    if (_restoreStateError != null) {
      _blockedLocalStateMessage = _copy.failedToRestoreMobileShellState(
        _restoreStateError!,
      );
    }
    _scheduleStatePersist();
    _relocalizeReadyHostConnection();
    final nextHostMessage = hostStatusMessage;
    if (previousHostMessage != null &&
        notice?.trim() == previousHostMessage &&
        nextHostMessage != null) {
      notice = nextHostMessage;
    }
    if (status == ShellStatus.ready && hostConnection?.isReady == true) {
      await refresh();
      return;
    }
    if (_requiresLocalStateReset) {
      await _stopRuntimeMonitoring();
      await _connectBridge(localStateBlocked: true);
      return;
    }
    if (hostConnection != null || status != ShellStatus.booting) {
      await reconnect();
      return;
    }
    _notify();
  }

  List<PlatformTunnelCapability> get platformTunnels =>
      hostConnection?.info?.platformTunnels ??
      const <PlatformTunnelCapability>[];

  PlatformTunnelMode? get activePlatformTunnelMode {
    final current = selectedPlatformTunnelMode;
    if (current != null && capabilityForMode(current) != null) {
      return current;
    }
    for (final capability in platformTunnels) {
      if (capability.available) {
        return capability.mode;
      }
    }
    return platformTunnels.isEmpty ? null : platformTunnels.first.mode;
  }

  PlatformTunnelCapability? get activePlatformTunnelCapability =>
      capabilityForMode(activePlatformTunnelMode);

  MobilePlatformModePreferences get activePlatformModePreferences {
    final mode = activePlatformTunnelMode;
    if (mode == null) {
      return const MobilePlatformModePreferences();
    }
    return modePreferencesFor(mode);
  }

  RuntimeExecutionPlan? get activeExecutionPlan =>
      activePlatformModePreferences.executionPlan;

  bool get activeModeRequiresVPNTransportProfile {
    final mode = activePlatformTunnelMode;
    if (mode == null) {
      return false;
    }
    return _transportProfilePrerequisiteForMode(mode) != null;
  }

  bool get canConfigureVPNTransportProfile {
    return _hostSupportsTransportProfileStore &&
        activeModeRequiresVPNTransportProfile &&
        _activeTransportProfileImportAdapter() != null;
  }

  bool canConfigureVPNTransportProfileForMode(PlatformTunnelMode mode) {
    return _hostSupportsTransportProfileStore &&
        _transportProfilePrerequisiteForMode(mode) != null &&
        _transportProfileImportAdapterForMode(mode) != null;
  }

  bool get canEditVPNTransportProfile {
    final schema = activeVPNTransportProfileEditorSchema;
    if (schema == null) {
      return false;
    }
    return activeVPNTransportProfileConfigured
        ? schema.supportsStructuredUpdate
        : schema.supportsStructuredCreate;
  }

  bool canEditVPNTransportProfileForMode(PlatformTunnelMode mode) {
    final schema = vpnTransportProfileEditorSchemaForMode(mode);
    if (schema == null) {
      return false;
    }
    final configured = vpnTransportProfileStatusForMode(mode) != null;
    return configured
        ? schema.supportsStructuredUpdate
        : schema.supportsStructuredCreate;
  }

  TransportProfileEditableKindSchema?
  get activeVPNTransportProfileEditorSchema {
    final mode = activePlatformTunnelMode;
    if (mode == null) {
      return null;
    }
    return vpnTransportProfileEditorSchemaForMode(mode);
  }

  TransportProfileEditableKindSchema? vpnTransportProfileEditorSchemaForMode(
    PlatformTunnelMode mode,
  ) {
    final prerequisite = _transportProfilePrerequisiteForMode(mode);
    final kind =
        prerequisite?.missingKind ??
        _firstTransportProfileKind(prerequisite?.requiredKinds);
    if (kind == null) {
      return null;
    }
    final capability = hostConnection?.info?.transportProfileStore;
    if (capability == null) {
      return null;
    }
    for (final schema in capability.editableKinds) {
      if (schema.kind == kind) {
        return schema;
      }
    }
    return null;
  }

  RuntimeExecutionPlan? get activeVPNTransportProfileExecutionPlan {
    final mode = activePlatformTunnelMode;
    if (mode == null) {
      return null;
    }
    return vpnTransportProfileExecutionPlanForMode(mode);
  }

  RuntimeExecutionPlan? vpnTransportProfileExecutionPlanForMode(
    PlatformTunnelMode mode,
  ) {
    return _transportProfileExecutionPlanDescriptorForMode(mode)?.plan;
  }

  bool get activeVPNTransportProfileConfigured {
    return activeVPNTransportProfileStatus != null;
  }

  bool activeVPNTransportProfileConfiguredForMode(PlatformTunnelMode mode) {
    return vpnTransportProfileStatusForMode(mode) != null;
  }

  String? get activeVPNTransportProfileStatusSummary {
    final mode = activePlatformTunnelMode;
    if (mode == null) {
      return null;
    }
    return vpnTransportProfileStatusSummaryForMode(mode);
  }

  String? vpnTransportProfileStatusSummaryForMode(PlatformTunnelMode mode) {
    final prerequisite = _transportProfilePrerequisiteForMode(mode);
    if (prerequisite == null) {
      return null;
    }
    final profile = vpnTransportProfileStatusForMode(mode);
    if (profile == null) {
      return _copy.vpnTransportProfileStatusNotConfigured;
    }
    final kindLabel = _transportProfileKindLabel(profile.kind);
    if (profile.validation.state == TransportProfileValidationState.invalid) {
      return _copy.vpnTransportProfileStatusInvalid(kindLabel);
    }
    if (profile.compatibility.state ==
            TransportProfileCompatibilityState.incompatible ||
        prerequisite.state == TransportProfileCompatibilityState.incompatible) {
      return _copy.vpnTransportProfileStatusIncompatible(kindLabel);
    }
    return _copy.vpnTransportProfileStatusConfigured(kindLabel);
  }

  String? vpnTransportProfileImportAdapterLabelForMode(
    PlatformTunnelMode mode,
  ) {
    final adapter = _transportProfileImportAdapterForMode(mode);
    if (adapter == null) {
      return null;
    }
    final capability = hostConnection?.info?.transportProfileStore;
    if (capability != null) {
      for (final descriptor in capability.importAdapters) {
        if (descriptor.id == adapter) {
          final label = descriptor.displayName.trim();
          if (label.isNotEmpty) {
            return label;
          }
        }
      }
    }
    return adapter.value;
  }

  TransportProfileStatus? get activeVPNTransportProfileStatus {
    final mode = activePlatformTunnelMode;
    if (mode == null) {
      return null;
    }
    return vpnTransportProfileStatusForMode(mode);
  }

  TransportProfileStatus? vpnTransportProfileStatusForMode(
    PlatformTunnelMode mode,
  ) {
    final prerequisite = _transportProfilePrerequisiteForMode(mode);
    final profileId =
        prerequisite?.selectedProfile?.profileId.trim().isNotEmpty == true
        ? prerequisite!.selectedProfile!.profileId.trim()
        : prerequisite?.defaultProfile?.profileId.trim();
    if (profileId != null && profileId.isNotEmpty) {
      return _transportProfileById(profileId);
    }
    final requiredKinds = prerequisite?.requiredKinds;
    if (requiredKinds == null || requiredKinds.isEmpty) {
      return null;
    }
    for (final profile in transportProfiles) {
      if (requiredKinds.contains(profile.kind)) {
        return profile;
      }
    }
    return null;
  }

  List<TransportProfileKind> vpnTransportProfileRequiredKindsForMode(
    PlatformTunnelMode mode,
  ) {
    final descriptor = _transportProfileExecutionPlanDescriptorForMode(mode);
    final prerequisite = descriptor?.transportProfile;
    if (prerequisite != null && prerequisite.requiredKinds.isNotEmpty) {
      return prerequisite.requiredKinds;
    }
    return descriptor?.requiredTransportProfileKinds ??
        const <TransportProfileKind>[];
  }

  List<TransportProfileStatus> vpnTransportProfilesForMode(
    PlatformTunnelMode mode,
  ) {
    final requiredKinds = vpnTransportProfileRequiredKindsForMode(mode);
    if (requiredKinds.isEmpty) {
      return transportProfiles;
    }
    return transportProfiles
        .where((TransportProfileStatus profile) {
          return requiredKinds.contains(profile.kind);
        })
        .toList(growable: false);
  }

  TransportProfilePrerequisiteStatus? get activeTransportProfilePrerequisite {
    final mode = activePlatformTunnelMode;
    if (mode == null) {
      return null;
    }
    return _transportProfilePrerequisiteForMode(mode);
  }

  String? platformTunnelStartPreparationBlockReason(PlatformTunnelMode mode) {
    final executionPlan = _resolvedExecutionPlanForMode(mode);
    if (executionPlan == null) {
      final transportProfileBlockReason = _transportProfileBlockReasonForMode(
        mode,
      );
      if (transportProfileBlockReason != null) {
        return transportProfileBlockReason;
      }
      return _executionPlanSelectionRequiredMessage(mode);
    }
    final transportProfileBlockReason = _transportProfileBlockReasonForMode(
      mode,
      plan: executionPlan,
    );
    if (transportProfileBlockReason != null) {
      return transportProfileBlockReason;
    }
    return null;
  }

  bool get activeModeSupportsAppRouting =>
      _modeSupportsAppRouting(activePlatformTunnelMode);

  bool get activeModeSupportsDevelopmentUnderlayRouting =>
      _modeSupportsUnderlayRoutePolicy(
        activePlatformTunnelMode,
        PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork,
      );

  bool get activeUnderlayRoutePolicyRequiresRestart {
    final mode = activePlatformTunnelMode;
    if (mode == null) {
      return false;
    }
    final result = platformTunnelResultFor(mode);
    if (result?.ready != true) {
      return false;
    }
    return _startedUnderlayRoutePolicyForMode(mode, result) !=
        activePlatformModePreferences.underlayRoutePolicy;
  }

  bool get systemTunnelSupported =>
      platformTunnels.any((PlatformTunnelCapability capability) {
        return capability.available;
      });

  PlatformTunnelStartResult? platformTunnelResultFor(PlatformTunnelMode mode) {
    return _platformTunnelResults[mode];
  }

  PlatformTunnelStatus? platformTunnelStatusFor(PlatformTunnelMode mode) {
    for (final status in platformTunnelStatuses) {
      if (status.mode == mode) {
        return status;
      }
    }
    return null;
  }

  ResolutionRecord? get selectedResolutionRecord => _selectedResolutionRecord();

  SessionRecord? get selectedSessionRecord {
    final sessionId = selectedSessionId?.trim() ?? '';
    if (sessionId.isEmpty) {
      return null;
    }
    for (final session in sessions) {
      if (session.id == sessionId) {
        return session;
      }
    }
    return null;
  }

  String? get selectedProfileId => currentProfileId;

  ProfileRecord? get selectedSavedProfile {
    return _profileById(currentProfileId);
  }

  ProfileRecord? get focusedSavedProfile {
    return _profileById(focusedProfileId);
  }

  ProfileDraft get currentProfileDraft {
    final profile = selectedSavedProfile;
    if (profile == null) {
      return draft;
    }
    return _normalizeDraft(
      ProfileDraft.fromProfile(
        profile,
        providerBinding:
            profileBindings[profile.id] ?? const ProfileProviderBinding(),
      ),
    );
  }

  PortableProfileEnvelope? get pendingPortableProfileImportEnvelope =>
      _pendingPortableProfileImportEnvelope;

  ChallengeRecord? get activeHomeChallenge {
    final selectedResolutionChallenge = switch (selectedResolutionRecord) {
      final ResolutionRecord resolution => activeChallengeForResolution(
        resolution,
      ),
      null => null,
    };
    if (selectedResolutionChallenge != null) {
      return selectedResolutionChallenge;
    }

    final selectedSessionChallenge = switch (selectedSessionRecord) {
      final SessionRecord session => activeChallengeFor(session),
      null => null,
    };
    if (selectedSessionChallenge != null) {
      return selectedSessionChallenge;
    }

    for (final resolution in resolutions) {
      final challenge = activeChallengeForResolution(resolution);
      if (challenge != null &&
          resolution.state == ResolutionState.challengeRequired) {
        return challenge;
      }
    }
    for (final session in sessions) {
      final challenge = activeChallengeFor(session);
      if (challenge != null &&
          session.state == SessionState.challengeRequired) {
        return challenge;
      }
    }
    return null;
  }

  ProfileRecord? _profileById(String? rawProfileId) {
    final profileId = rawProfileId?.trim() ?? '';
    if (profileId.isEmpty) {
      return null;
    }
    for (final profile in profiles) {
      if (profile.id == profileId) {
        return profile;
      }
    }
    return null;
  }

  PlatformTunnelCapability? capabilityForMode(PlatformTunnelMode? mode) {
    if (mode == null) {
      return null;
    }
    for (final capability in platformTunnels) {
      if (capability.mode == mode) {
        return capability;
      }
    }
    return null;
  }

  List<RuntimeExecutionPlanDescriptor> executionPlanOptionsForMode(
    PlatformTunnelMode mode,
  ) {
    final capability = capabilityForMode(mode);
    if (capability == null) {
      return const <RuntimeExecutionPlanDescriptor>[];
    }
    return capability.executionPlans
        .where((RuntimeExecutionPlanDescriptor descriptor) {
          return descriptor.isSelectable || descriptor.isProfileSetupNeeded;
        })
        .toList(growable: false);
  }

  MobilePlatformModePreferences modePreferencesFor(PlatformTunnelMode mode) {
    return _normalizePlatformModePreferences(
      mode,
      platformModePreferences[_platformModePreferenceKey(mode)],
    );
  }

  void publishNotice(String message) {
    notice = message;
    _notify();
  }

  void showTransientNotice(String message) {
    notice = message;
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _noticeTimer = Timer(_transientNoticeDuration, () {
      if (_notice?.trim() != trimmed) {
        return;
      }
      _notice = null;
      _notify();
    });
  }

  Future<void> importVPNTransportProfile() async {
    final mode = activePlatformTunnelMode;
    if (mode == null) {
      notice = _copy.noMobileTunnelModeSelected;
      _notify();
      return;
    }
    await importVPNTransportProfileForMode(mode);
  }

  Future<void> importVPNTransportProfileForMode(PlatformTunnelMode mode) async {
    await _runBridgeMutation(() async {
      final descriptor = _transportProfileExecutionPlanDescriptorForMode(mode);
      final prerequisite = descriptor?.transportProfile;
      final adapter = _transportProfileImportAdapterForMode(mode);
      if (adapter == null) {
        notice = _copy.vpnTransportProfileRequiredBeforeStarting;
        return;
      }
      final contents = await _transportProfileContentPicker();
      if (contents == null) {
        return;
      }
      final kind =
          prerequisite?.missingKind ??
          _firstTransportProfileKind(prerequisite?.requiredKinds) ??
          _profileKindForImportAdapter(adapter);
      if (kind == null) {
        notice = _copy.vpnTransportProfileRequiredBeforeStarting;
        return;
      }
      final existing = vpnTransportProfileStatusForMode(mode);
      await bridge.importTransportProfile(
        TransportProfileImportRequest(
          adapter: adapter,
          kind: kind,
          displayName: _transportProfileKindLabel(kind),
          material: contents,
          replaceProfileId: existing?.id ?? '',
          defaultFor: descriptor?.plan,
        ),
      );
      await _refreshHostInfo();
      await refresh();
      notice = _copy.vpnTransportProfileConfigured;
    });
  }

  Future<TransportProfileStructuredValidationResult>
  validateStructuredVPNTransportProfile(
    TransportProfileStructuredValidationRequest request,
  ) {
    final mode = activePlatformTunnelMode;
    if (mode == null) {
      throw StateError('No mobile tunnel mode selected.');
    }
    return validateStructuredVPNTransportProfileForMode(mode, request);
  }

  Future<TransportProfileStructuredValidationResult>
  validateStructuredVPNTransportProfileForMode(
    PlatformTunnelMode mode,
    TransportProfileStructuredValidationRequest request,
  ) {
    final schema = vpnTransportProfileEditorSchemaForMode(mode);
    if (schema == null || !schema.supportsDraftValidation) {
      throw StateError('Structured VPN profile editing is unavailable.');
    }
    return bridge.validateStructuredTransportProfileDraft(request);
  }

  Future<TransportProfileStructuredSaveResult>
  saveStructuredVPNTransportProfile(
    TransportProfileStructuredDraft draft,
  ) async {
    final mode = activePlatformTunnelMode;
    if (mode == null) {
      throw StateError('No mobile tunnel mode selected.');
    }
    return saveStructuredVPNTransportProfileForMode(mode, draft);
  }

  Future<TransportProfileStructuredSaveResult>
  saveStructuredVPNTransportProfileForMode(
    PlatformTunnelMode mode,
    TransportProfileStructuredDraft draft, {
    TransportProfileStatus? existingProfile,
    bool createNew = false,
  }) async {
    final schema = vpnTransportProfileEditorSchemaForMode(mode);
    if (schema == null) {
      throw StateError('Structured VPN profile editing is unavailable.');
    }
    final existing = createNew
        ? null
        : existingProfile ?? vpnTransportProfileStatusForMode(mode);
    if (existing == null && !schema.supportsStructuredCreate) {
      throw StateError('Structured VPN profile creation is unavailable.');
    }
    if (existing != null && !schema.supportsStructuredUpdate) {
      throw StateError('Structured VPN profile update is unavailable.');
    }
    final result = existing == null
        ? await bridge.createStructuredTransportProfile(
            TransportProfileStructuredCreateRequest(draft: draft),
          )
        : await bridge.updateStructuredTransportProfile(
            existing.id,
            TransportProfileStructuredUpdateRequest(draft: draft),
          );
    await _refreshHostInfo();
    await refresh();
    notice = _copy.vpnTransportProfileConfigured;
    _notify();
    return result;
  }

  Future<void> forgetVPNTransportProfile() async {
    final mode = activePlatformTunnelMode;
    if (mode == null) {
      notice = _copy.noMobileTunnelModeSelected;
      _notify();
      return;
    }
    await forgetVPNTransportProfileForMode(mode);
  }

  Future<void> forgetVPNTransportProfileForMode(PlatformTunnelMode mode) async {
    await _runBridgeMutation(() async {
      final profile = vpnTransportProfileStatusForMode(mode);
      if (profile == null) {
        notice = _copy.vpnTransportProfileRequiredBeforeStarting;
        return;
      }
      await bridge.forgetTransportProfile(profile.id);
      await _refreshHostInfo();
      await refresh();
      notice = _copy.vpnTransportProfileCleared;
    });
  }

  Future<void> forgetVPNTransportProfileRecord(
    TransportProfileStatus profile,
  ) async {
    await _runBridgeMutation(() async {
      await bridge.forgetTransportProfile(profile.id);
      await _refreshHostInfo();
      await refresh();
      notice = _copy.vpnTransportProfileCleared;
    });
  }

  Future<void> validateVPNTransportProfileRecord(
    TransportProfileStatus profile,
  ) async {
    await _runBridgeMutation(() async {
      await bridge.validateTransportProfile(profile.id);
      await _refreshHostInfo();
      await refresh();
      notice = _copy.vpnTransportProfileConfigured;
      _notify();
    });
  }

  Future<void> selectVPNTransportProfileForMode(
    PlatformTunnelMode mode,
    TransportProfileStatus profile,
  ) async {
    await _runBridgeMutation(() async {
      final plan = vpnTransportProfileExecutionPlanForMode(mode);
      if (plan == null) {
        notice = _copy.vpnTransportProfileRequiredBeforeStarting;
        return;
      }
      await bridge.selectTransportProfileForStartup(
        profile.id,
        TransportProfileSelectForStartupRequest(plan: plan),
      );
      await _refreshHostInfo();
      await refresh();
      notice = _copy.vpnTransportProfileConfigured;
    });
  }

  List<ProviderPreset> get presetCatalog => kProviderPresetCatalog;

  List<SupportedProviderDefinition> get supportedProviderCatalog =>
      kSupportedProviderCatalog;

  ProviderDescriptor? get activeManagedProviderDescriptor =>
      descriptorForProvider(managedProviderDraft.provider);

  List<ManagedProviderRecord> get availableManagedProvidersForDraft {
    final providerId = draft.spec.provider.trim().toLowerCase();
    if (providerId.isEmpty) {
      return managedProviders
          .where((ManagedProviderRecord provider) => provider.isAvailable)
          .toList(growable: false);
    }
    return managedProviders
        .where(
          (ManagedProviderRecord provider) =>
              provider.isAvailable &&
              provider.provider.trim().toLowerCase() == providerId,
        )
        .toList(growable: false);
  }

  List<ManagedProviderRecord> get providerConfigs => managedProviders;

  List<ManagedProviderRecord> get availableProviderConfigsForDraft =>
      availableManagedProvidersForDraft;

  ProviderConfigDraft get providerConfigDraft =>
      ProviderConfigDraft.fromJson(managedProviderDraft.toJson());

  String? get selectedProviderConfigId => selectedManagedProviderId;

  ProviderDescriptor? get activeProviderConfigDescriptor =>
      activeManagedProviderDescriptor;

  Future<void> initialize() async {
    _startBrowserReturnSignals();
    _startPortableProfileIngress();
    await _restorePersistedState();
    if (_requiresLocalStateReset) {
      await _connectBridge(localStateBlocked: true);
      return;
    }
    await _connectBridge();
  }

  Future<void> reconnect() async {
    if (_requiresLocalStateReset) {
      notice =
          _blockedLocalStateMessage ??
          _copy.resetLocalMobileShellStateBeforeReconnecting;
      _notify();
      return;
    }
    await _stopRuntimeMonitoring();
    await _connectBridge();
  }

  void onAppLifecycleStateChanged(AppLifecycleState state) {
    if (_disposed) {
      return;
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_handleAppResumed());
    }
  }

  Future<void> refresh() async {
    if (hostConnection?.isReady != true) {
      _notify();
      return;
    }
    try {
      final nextProviders = await bridge.providers();
      final nextTransportProfiles = _hostSupportsTransportProfileStore
          ? await bridge.transportProfiles()
          : const <TransportProfileStatus>[];
      final nextPlatformTunnelStatuses = platformTunnels.isNotEmpty
          ? await bridge.platformTunnelStatuses()
          : const <PlatformTunnelStatus>[];
      final nextResolutions = _orderedResolutions(await bridge.resolutions());
      final nextSessions = _orderedSessions(await bridge.sessions());
      final nextChallenges = await _loadActiveChallenges(
        nextSessions,
        nextResolutions,
      );
      providerDescriptors = nextProviders;
      managedProviders = _overlayManagedProviders(managedProviders);
      providerTemplates = _overlayProviderTemplates(providerTemplates);
      transportProfiles = nextTransportProfiles;
      _replacePlatformTunnelStatuses(nextPlatformTunnelStatuses);
      resolutions = nextResolutions;
      draft = _normalizeDraft(draft);
      managedProviderDraft = _normalizeManagedProviderDraft(
        managedProviderDraft,
      );
      providerTemplateDraft = _normalizeProviderTemplateDraft(
        providerTemplateDraft,
      );
      _normalizeProfileSelectionState();
      selectedResolutionId = _resolveSelectedResolutionId(nextResolutions);
      _replaceSessions(nextSessions);
      _mergeChallenges(nextChallenges);
      if (selectedManagedProviderId != null &&
          !managedProviders.any(
            (ManagedProviderRecord provider) =>
                provider.id == selectedManagedProviderId,
          )) {
        selectedManagedProviderId = null;
        managedProviderDraft = _defaultManagedProviderDraft();
        if (workflowSurface != MobileWorkflowSurface.profile) {
          workflowSurface = MobileWorkflowSurface.provider;
        }
      }
      if (selectedProviderTemplateId != null &&
          !providerTemplates.any(
            (ProviderTemplateRecord template) =>
                template.id == selectedProviderTemplateId,
          )) {
        selectedProviderTemplateId = null;
        providerTemplateDraft = _defaultProviderTemplateDraft();
        if (workflowSurface == MobileWorkflowSurface.providerTemplate) {
          workflowSurface = MobileWorkflowSurface.provider;
        }
      }
      _normalizeSelectedPlatformTunnelMode();
      _notify();
    } catch (error) {
      await _handleBridgeFailure(error);
    }
  }

  void selectProfile(String profileId) {
    focusProfile(profileId);
  }

  void focusProfile(String profileId) {
    final normalizedProfileId = profileId.trim();
    if (normalizedProfileId.isEmpty) {
      return;
    }
    workflowSurface = MobileWorkflowSurface.profile;
    focusedProfileId = normalizedProfileId;
    final selected = _profileById(normalizedProfileId);
    if (selected != null) {
      draft = _normalizeDraft(
        ProfileDraft.fromProfile(
          selected,
          providerBinding:
              profileBindings[normalizedProfileId] ??
              const ProfileProviderBinding(),
        ),
      );
    }
    _clearSelectedResolutionSelection();
    _scheduleStatePersist();
    notifyListeners();
  }

  void makeProfileCurrent(String profileId) {
    final normalizedProfileId = profileId.trim();
    if (normalizedProfileId.isEmpty ||
        _profileById(normalizedProfileId) == null) {
      return;
    }
    currentProfileId = normalizedProfileId;
    _normalizeSelectedPlatformTunnelMode();
    _scheduleStatePersist();
    notifyListeners();
  }

  void selectSession(String sessionId) {
    selectedSessionId = sessionId;
    notifyListeners();
  }

  void selectResolution(String resolutionId) {
    _forceFreshResolutionAfterEmbeddedSignOut = false;
    selectedResolutionId = resolutionId;
    notifyListeners();
  }

  void selectPlatformTunnelMode(PlatformTunnelMode mode) {
    if (capabilityForMode(mode) == null) {
      return;
    }
    selectedPlatformTunnelMode = mode;
    _storeModePreferences(mode, modePreferencesFor(mode));
    _scheduleStatePersist();
    notifyListeners();
  }

  void selectExecutionPlan(RuntimeExecutionPlan? plan) {
    final mode = activePlatformTunnelMode;
    if (mode == null) {
      return;
    }
    final current = modePreferencesFor(mode);
    _storeModePreferences(
      mode,
      current.copyWith(executionPlan: plan, replaceExecutionPlan: true),
      notify: true,
    );
  }

  void updateApplicationRoutingPolicy(
    PlatformTunnelApplicationRoutingPolicy policy,
  ) {
    final mode = activePlatformTunnelMode;
    if (mode == null) {
      return;
    }
    final current = modePreferencesFor(mode);
    _storeModePreferences(
      mode,
      current.copyWith(applicationRoutingPolicy: policy),
      notify: true,
    );
  }

  void updateUnderlayRoutePolicy(PlatformTunnelUnderlayRoutePolicy policy) {
    final mode = activePlatformTunnelMode;
    if (mode == null) {
      return;
    }
    final current = modePreferencesFor(mode);
    if (current.underlayRoutePolicy == policy) {
      return;
    }
    _storeModePreferences(
      mode,
      current.copyWith(underlayRoutePolicy: policy),
      notify: true,
    );
    if (platformTunnelResultFor(mode)?.ready == true) {
      notice = _copy.restartVpnToApplyRoutingProfile(mode.label);
      _notify();
    }
  }

  void updateRoutingPackageSelection({
    required String packageName,
    required bool selected,
  }) {
    final mode = activePlatformTunnelMode;
    if (mode == null) {
      return;
    }
    final normalizedPackage = packageName.trim();
    if (normalizedPackage.isEmpty) {
      return;
    }
    final current = modePreferencesFor(mode);
    switch (current.applicationRoutingPolicy) {
      case PlatformTunnelApplicationRoutingPolicy.allApps:
        return;
      case PlatformTunnelApplicationRoutingPolicy.allowedPackages:
        _storeModePreferences(
          mode,
          current.copyWith(
            allowedPackages: _togglePackage(
              current.allowedPackages,
              normalizedPackage,
              selected,
            ),
          ),
          notify: true,
        );
        return;
      case PlatformTunnelApplicationRoutingPolicy.disallowedPackages:
        _storeModePreferences(
          mode,
          current.copyWith(
            disallowedPackages: _togglePackage(
              current.disallowedPackages,
              normalizedPackage,
              selected,
            ),
          ),
          notify: true,
        );
        return;
    }
  }

  void updateRoutingPackageSelectionBatch({
    required Iterable<String> packageNames,
    required bool selected,
  }) {
    final mode = activePlatformTunnelMode;
    if (mode == null) {
      return;
    }
    final normalizedPackages = _normalizePackageNames(packageNames);
    if (normalizedPackages.isEmpty) {
      return;
    }
    final current = modePreferencesFor(mode);
    switch (current.applicationRoutingPolicy) {
      case PlatformTunnelApplicationRoutingPolicy.allApps:
        return;
      case PlatformTunnelApplicationRoutingPolicy.allowedPackages:
        _storeModePreferences(
          mode,
          current.copyWith(
            allowedPackages: _togglePackages(
              current.allowedPackages,
              normalizedPackages,
              selected,
            ),
          ),
          notify: true,
        );
        return;
      case PlatformTunnelApplicationRoutingPolicy.disallowedPackages:
        _storeModePreferences(
          mode,
          current.copyWith(
            disallowedPackages: _togglePackages(
              current.disallowedPackages,
              normalizedPackages,
              selected,
            ),
          ),
          notify: true,
        );
        return;
    }
  }

  Future<void> ensureInstalledAppsLoaded({bool force = false}) async {
    if (loadingInstalledApps) {
      return;
    }
    if (!force && installedApps.isNotEmpty) {
      return;
    }
    loadingInstalledApps = true;
    installedAppsError = null;
    _notify();
    try {
      installedApps = await _appInventory.listInstalledApps();
    } catch (error) {
      installedApps = const <MobilePlatformApp>[];
      installedAppsError = '$error';
    } finally {
      loadingInstalledApps = false;
      _notify();
    }
  }

  void updateDraft(ProfileDraft nextDraft) {
    workflowSurface = MobileWorkflowSurface.profile;
    draft = _normalizeDraft(nextDraft);
    notice = null;
    _clearSelectedResolutionSelection();
    _scheduleStatePersist();
    notifyListeners();
  }

  void useCustomProviderForDraft() {
    workflowSurface = MobileWorkflowSurface.profile;
    draft = _normalizeDraft(draft.asCustomProvider());
    selectedManagedProviderId = null;
    _clearSelectedResolutionSelection();
    _scheduleStatePersist();
    notifyListeners();
  }

  void activateManagedProviderMode({String? managedProviderId}) {
    final preferred =
        managedProviderId ??
        draft.providerBinding.managedProviderId ??
        selectedManagedProviderId ??
        (availableManagedProvidersForDraft.isEmpty
            ? (managedProviders.isEmpty ? null : managedProviders.first.id)
            : availableManagedProvidersForDraft.first.id);
    if (preferred == null || preferred.trim().isEmpty) {
      notice = _copy.noManagedProvidersAvailableYet;
      _notify();
      return;
    }
    useManagedProviderForDraft(preferred);
  }

  void resetDraft() {
    workflowSurface = MobileWorkflowSurface.profile;
    focusedProfileId = null;
    draft = _defaultDraft();
    _clearSelectedResolutionSelection();
    _scheduleStatePersist();
    notifyListeners();
  }

  void showProfileWorkspace() {
    workflowSurface = MobileWorkflowSurface.profile;
    notifyListeners();
  }

  void clearPendingPortableProfileImportPreview() {
    if (_pendingPortableProfileImportEnvelope == null &&
        _pendingPortableProfileImportPayload == null) {
      return;
    }
    _pendingPortableProfileImportEnvelope = null;
    _pendingPortableProfileImportPayload = null;
    _notify();
  }

  void showProviderWorkspace({String? preferredProvider}) {
    workflowSurface = MobileWorkflowSurface.provider;
    if (selectedManagedProviderId == null) {
      managedProviderDraft = _defaultManagedProviderDraft(
        preferredProvider: preferredProvider,
      );
    }
    notifyListeners();
  }

  void showProviderConfigWorkspace({String? preferredProvider}) {
    showProviderWorkspace(preferredProvider: preferredProvider);
  }

  void focusManagedProvider(String providerId) {
    final normalizedProviderId = providerId.trim();
    if (normalizedProviderId.isEmpty) {
      return;
    }
    workflowSurface = MobileWorkflowSurface.provider;
    selectedManagedProviderId = normalizedProviderId;
    final selected =
        managedProviderById(normalizedProviderId) ??
        _defaultManagedProviderDraft().toRecord();
    managedProviderDraft = _normalizeManagedProviderDraft(
      ManagedProviderDraft.fromRecord(selected),
    );
    notifyListeners();
  }

  void selectManagedProvider(String providerId) {
    workflowSurface = MobileWorkflowSurface.providerConfig;
    selectedManagedProviderId = providerId;
    final selected =
        managedProviderById(providerId) ??
        _defaultManagedProviderDraft().toRecord();
    managedProviderDraft = _normalizeManagedProviderDraft(
      ManagedProviderDraft.fromRecord(selected),
    );
    notifyListeners();
  }

  void selectProviderConfig(String configId) {
    selectManagedProvider(configId);
  }

  void updateManagedProviderDraft(ManagedProviderDraft nextDraft) {
    workflowSurface = MobileWorkflowSurface.providerConfig;
    managedProviderDraft = _normalizeManagedProviderDraft(nextDraft);
    notifyListeners();
  }

  void updateProviderConfigDraft(ProviderConfigDraft nextDraft) {
    updateManagedProviderDraft(
      ManagedProviderDraft.fromJson(nextDraft.toJson()),
    );
  }

  void resetManagedProviderDraft({
    String? preferredProvider,
    ProviderPreset? preset,
  }) {
    workflowSurface = MobileWorkflowSurface.providerConfig;
    selectedManagedProviderId = null;
    managedProviderDraft = preset == null
        ? _defaultManagedProviderDraft(preferredProvider: preferredProvider)
        : _normalizeManagedProviderDraft(
            ManagedProviderDraft.fromPreset(
              preset,
              descriptor: descriptorForProvider(preset.provider),
            ),
          );
    notifyListeners();
  }

  void resetProviderConfigDraft({String? preferredProvider}) {
    resetManagedProviderDraft(preferredProvider: preferredProvider);
  }

  void duplicateSelectedProfile() {
    final source = focusedSavedProfile;
    if (source == null) {
      notice = _copy.saveOrSelectProfileBeforeExport;
      _notify();
      return;
    }
    final sourceLabel = source.name.trim().isEmpty ? source.id : source.name;
    workflowSurface = MobileWorkflowSurface.profile;
    focusedProfileId = null;
    draft = _normalizeDraft(
      ProfileDraft.fromProfile(
        source,
        providerBinding:
            profileBindings[source.id] ?? const ProfileProviderBinding(),
      ).copyWith(
        id: null,
        replaceId: true,
        name: _duplicatedLabel(sourceLabel),
      ),
    );
    _clearSelectedResolutionSelection();
    showTransientNotice(_copy.seededProfileCopyDraft(sourceLabel));
    _scheduleStatePersist();
    notifyListeners();
  }

  void startProviderTemplateDraftFromManagedProvider() {
    workflowSurface = MobileWorkflowSurface.providerTemplate;
    selectedProviderTemplateId = null;
    providerTemplateDraft = _normalizeProviderTemplateDraft(
      ProviderTemplateDraft.fromManagedProviderDraft(managedProviderDraft),
    );
    notifyListeners();
  }

  void selectProviderTemplate(String templateId) {
    workflowSurface = MobileWorkflowSurface.providerTemplate;
    selectedProviderTemplateId = templateId;
    final selected =
        providerTemplateById(templateId) ??
        _defaultProviderTemplateDraft().toRecord();
    providerTemplateDraft = _normalizeProviderTemplateDraft(
      ProviderTemplateDraft.fromRecord(selected),
    );
    notifyListeners();
  }

  void updateProviderTemplateDraft(ProviderTemplateDraft nextDraft) {
    workflowSurface = MobileWorkflowSurface.providerTemplate;
    providerTemplateDraft = _normalizeProviderTemplateDraft(nextDraft);
    notifyListeners();
  }

  void focusProviderTemplate(String templateId) {
    final normalizedTemplateId = templateId.trim();
    if (normalizedTemplateId.isEmpty) {
      return;
    }
    workflowSurface = MobileWorkflowSurface.provider;
    selectedProviderTemplateId = normalizedTemplateId;
    final selected =
        providerTemplateById(normalizedTemplateId) ??
        _defaultProviderTemplateDraft().toRecord();
    providerTemplateDraft = _normalizeProviderTemplateDraft(
      ProviderTemplateDraft.fromRecord(selected),
    );
    notifyListeners();
  }

  void duplicateSelectedManagedProvider() {
    final source = managedProviderById(selectedManagedProviderId ?? '');
    if (source == null) {
      notice = _copy.noManagedProvidersAvailableYet;
      _notify();
      return;
    }
    final sourceLabel = source.name.trim().isEmpty ? source.id : source.name;
    workflowSurface = MobileWorkflowSurface.providerConfig;
    selectedManagedProviderId = null;
    managedProviderDraft = _normalizeManagedProviderDraft(
      ManagedProviderDraft.fromRecord(source).copyWith(
        id: null,
        replaceId: true,
        name: _duplicatedLabel(sourceLabel),
        createdAt: null,
        replaceCreatedAt: true,
        updatedAt: null,
        replaceUpdatedAt: true,
      ),
    );
    showTransientNotice(_copy.seededManagedProviderCopyDraft(sourceLabel));
    notifyListeners();
  }

  void duplicateSelectedProviderTemplate() {
    final source = providerTemplateById(selectedProviderTemplateId ?? '');
    if (source == null) {
      notice = _copy.noSavedTemplatesYet;
      _notify();
      return;
    }
    final sourceLabel = source.name.trim().isEmpty ? source.id : source.name;
    workflowSurface = MobileWorkflowSurface.providerTemplate;
    selectedProviderTemplateId = null;
    providerTemplateDraft = _normalizeProviderTemplateDraft(
      ProviderTemplateDraft.fromRecord(source).copyWith(
        id: null,
        replaceId: true,
        name: _duplicatedLabel(sourceLabel),
        createdAt: null,
        replaceCreatedAt: true,
        updatedAt: null,
        replaceUpdatedAt: true,
      ),
    );
    showTransientNotice(_copy.seededTemplateCopyDraft(sourceLabel));
    notifyListeners();
  }

  Future<void> saveProviderTemplateDraft() async {
    await _runBridgeMutation(() async {
      final supported = supportedProviderDefinitionFor(
        providerTemplateDraft.provider,
      );
      if (supported == null) {
        notice = _copy.selectedTemplateFamilyNotInSupportedCatalog;
        return;
      }
      final draftToSave = _normalizeProviderTemplateDraft(
        providerTemplateDraft,
      );
      final blockReason = _providerTemplateDraftBlockReason(draftToSave);
      if (blockReason != null) {
        notice = blockReason;
        return;
      }
      final now = _clock();
      final id = (draftToSave.id ?? '').trim().isEmpty
          ? _idFactory()
          : draftToSave.id!.trim();
      final existing = providerTemplateById(id);
      final saved = draftToSave
          .copyWith(
            id: id,
            createdAt: existing?.createdAt ?? draftToSave.createdAt ?? now,
            updatedAt: now,
          )
          .toRecord();
      final next = <ProviderTemplateRecord>[
        for (final template in providerTemplates)
          if (template.id != id) template,
        saved,
      ]..sort(_providerTemplateNameSort);
      providerTemplates = _overlayProviderTemplates(next);
      showTransientNotice(
        _copy.savedTemplate(saved.name.isEmpty ? saved.id : saved.name),
      );
      selectedProviderTemplateId = saved.id;
      providerTemplateDraft = ProviderTemplateDraft.fromRecord(saved);
      _scheduleStatePersist();
    });
  }

  Future<void> deleteSelectedProviderTemplate() async {
    final templateId = selectedProviderTemplateId;
    if (templateId == null) {
      return;
    }
    await _runBridgeMutation(() async {
      providerTemplates = providerTemplates
          .where((ProviderTemplateRecord template) => template.id != templateId)
          .toList(growable: false);
      notice = _copy.deletedTemplate(templateId);
      selectedProviderTemplateId = null;
      providerTemplateDraft = _defaultProviderTemplateDraft();
      workflowSurface = MobileWorkflowSurface.provider;
      _scheduleStatePersist();
    });
  }

  void useProviderTemplate(String templateId) {
    final template = providerTemplateById(templateId);
    if (template == null) {
      notice = _copy.templateNoLongerAvailable(templateId);
      _notify();
      return;
    }
    workflowSurface = MobileWorkflowSurface.providerConfig;
    selectedManagedProviderId = null;
    managedProviderDraft = _normalizeManagedProviderDraft(
      ManagedProviderDraft.fromTemplateRecord(template),
    );
    notice = _copy.seededManagedProviderDraftFromTemplate(
      template.name.isEmpty ? template.id : template.name,
    );
    _notify();
  }

  Future<void> saveManagedProviderDraft() async {
    await _runBridgeMutation(() async {
      final supported = supportedProviderDefinitionFor(
        managedProviderDraft.provider,
      );
      if (supported == null) {
        notice = _copy.selectedManagedProviderFamilyNotInSupportedCatalog;
        return;
      }
      final draftToSave = _normalizeManagedProviderDraft(managedProviderDraft);
      final blockReason = _managedProviderDraftBlockReason(draftToSave);
      if (blockReason != null) {
        notice = blockReason;
        return;
      }
      final now = _clock();
      final id = (draftToSave.id ?? '').trim().isEmpty
          ? _idFactory()
          : draftToSave.id!.trim();
      final existing = managedProviderById(id);
      final saved = draftToSave
          .copyWith(
            id: id,
            createdAt: existing?.createdAt ?? draftToSave.createdAt ?? now,
            updatedAt: now,
          )
          .toRecord();
      final next = <ManagedProviderRecord>[
        for (final provider in managedProviders)
          if (provider.id != id) provider,
        saved,
      ]..sort(_managedProviderNameSort);
      managedProviders = _overlayManagedProviders(next);
      showTransientNotice(
        _copy.savedManagedProvider(saved.name.isEmpty ? saved.id : saved.name),
      );
      selectedManagedProviderId = saved.id;
      managedProviderDraft = ManagedProviderDraft.fromRecord(saved);
      _scheduleStatePersist();
    });
  }

  Future<void> saveProviderConfigDraft() async {
    await saveManagedProviderDraft();
  }

  Future<void> deleteSelectedManagedProvider() async {
    final providerId = selectedManagedProviderId;
    if (providerId == null) {
      return;
    }
    await _runBridgeMutation(() async {
      managedProviders = managedProviders
          .where((ManagedProviderRecord provider) => provider.id != providerId)
          .toList(growable: false);
      profileBindings = _dropManagedProviderBindings(
        providerId,
        profileBindings,
      );
      if (draft.providerBinding.managedProviderId == providerId) {
        draft = draft.asCustomProvider();
      }
      notice = _copy.deletedManagedProvider(providerId);
      selectedManagedProviderId = null;
      managedProviderDraft = _defaultManagedProviderDraft();
      workflowSurface = MobileWorkflowSurface.provider;
      _scheduleStatePersist();
    });
  }

  Future<void> deleteSelectedProviderConfig() async {
    await deleteSelectedManagedProvider();
  }

  void useManagedProviderForDraft(String managedProviderId) {
    final provider = managedProviderById(managedProviderId);
    if (provider == null) {
      notice = _copy.managedProviderNoLongerAvailable(managedProviderId);
      _notify();
      return;
    }
    workflowSurface = MobileWorkflowSurface.profile;
    draft = _normalizeDraft(draft.applyManagedProvider(provider));
    selectedManagedProviderId = managedProviderId;
    _clearSelectedResolutionSelection();
    notice = _copy.appliedManagedProviderToActiveMobileProfileDraft(
      provider.name.isEmpty ? provider.id : provider.name,
    );
    _scheduleStatePersist();
    _notify();
  }

  void applyProviderConfigToDraft(String configId) {
    useManagedProviderForDraft(configId);
  }

  void applyPreset(ProviderPreset preset) {
    resetManagedProviderDraft(preset: preset);
    notice = _copy.seededManagedProviderDraftFromPreset(preset.title);
    _notify();
  }

  Future<void> clearLocalState() async {
    busy = true;
    _notify();
    try {
      await _stopRuntimeMonitoring();
      await stateStore.clear();
      _challengeCache.clear();
      managedProviders = const <ManagedProviderRecord>[];
      providerTemplates = const <ProviderTemplateRecord>[];
      providerDescriptors = const <ProviderDescriptor>[];
      profiles = const <ProfileRecord>[];
      resolutions = const <ResolutionRecord>[];
      sessions = const <SessionRecord>[];
      events = const <EventRecord>[];
      draft = ProfileDraft.defaults();
      managedProviderDraft = ManagedProviderDraft.defaults();
      providerTemplateDraft = ProviderTemplateDraft.defaults();
      workflowSurface = MobileWorkflowSurface.profile;
      currentProfileId = null;
      focusedProfileId = null;
      selectedPlatformTunnelMode = null;
      selectedManagedProviderId = null;
      selectedProviderTemplateId = null;
      profileBindings = <String, ProfileProviderBinding>{};
      platformModePreferences = <String, MobilePlatformModePreferences>{};
      selectedResolutionId = null;
      selectedSessionId = null;
      installedApps = const <MobilePlatformApp>[];
      installedAppsError = null;
      _persistedStateSignature = MobileShellState.empty().signature();
      _requiresLocalStateReset = false;
      _blockedLocalStateMessage = null;
      _restoreStateError = null;
      notice = _copy.clearedLocalMobileShellState;
      hostConnection = null;
      status = ShellStatus.booting;
    } catch (error) {
      notice = _copy.failedToClearLocalMobileShellState(error);
      status = ShellStatus.blocked;
      busy = false;
      _notify();
      return;
    }
    busy = false;
    _notify();
    await _connectBridge();
  }

  Future<void> clearRememberedEmbeddedSignIn() async {
    if (busy) {
      return;
    }
    busy = true;
    _notify();
    try {
      await _ownedBrowserSessionStateResetter.clearSessionState();
      _forceFreshResolutionAfterEmbeddedSignOut = true;
      _clearSelectedReusableResolutionSelection();
      notice = _copy.clearedRememberedEmbeddedSignIn;
    } catch (error) {
      notice = switch (error) {
        MobileHostPlatformActionError(:final message) => message,
        _ => _copy.failedToClearRememberedEmbeddedSignIn(error),
      };
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> saveDraft() async {
    if (_requiresLocalStateReset) {
      notice = _localStateResetBlockMessage();
      _notify();
      return;
    }
    busy = true;
    _notify();
    try {
      final persistedDraftProfileId = focusedProfileId?.trim() ?? '';
      final previousCurrentProfileId = currentProfileId?.trim() ?? '';
      final descriptor = activeProviderDescriptor;
      if (descriptor == null) {
        notice = _copy.selectedProviderNotAdvertisedByConnectedMobileHost;
        return;
      }
      final blockReason = _providerSettingsBlockReason(descriptor);
      if (blockReason != null) {
        notice = blockReason;
        return;
      }
      var profile = draft.toProfile().copyWith(
        spec: draft.spec.copyWith(
          providerSettings: descriptor.profileRetainedProviderSettings(
            draft.spec.providerSettings,
          ),
        ),
      );
      if (profile.id.isEmpty) {
        profile = profile.copyWith(id: _idFactory());
      }
      if (hostConnection?.isReady == true) {
        profile = await bridge.upsertProfile(profile);
      }
      if (persistedDraftProfileId.isEmpty) {
        _moveModePreferences(
          fromScope: _draftModePreferenceScope,
          toScope: profile.id,
        );
      }
      profileBindings = <String, ProfileProviderBinding>{
        ...profileBindings,
        profile.id: draft.providerBinding,
      };
      final nextProfiles = profiles.toList(growable: true);
      final index = nextProfiles.indexWhere(
        (ProfileRecord existing) => existing.id == profile.id,
      );
      if (index >= 0) {
        nextProfiles[index] = profile;
      } else {
        nextProfiles.add(profile);
      }
      nextProfiles.sort(
        (ProfileRecord left, ProfileRecord right) =>
            left.id.compareTo(right.id),
      );
      profiles = nextProfiles;
      if (previousCurrentProfileId.isEmpty ||
          previousCurrentProfileId == persistedDraftProfileId) {
        currentProfileId = profile.id;
      }
      focusedProfileId = profile.id;
      draft = _normalizeDraft(
        ProfileDraft.fromProfile(
          profile,
          providerBinding:
              profileBindings[profile.id] ?? const ProfileProviderBinding(),
        ),
      );
      _normalizeSelectedPlatformTunnelMode();
      _scheduleStatePersist();
      showTransientNotice(
        _copy.savedMobileProfile(
          profile.name.isEmpty ? profile.id : profile.name,
        ),
      );
      if (hostConnection?.isReady == true) {
        await refresh();
      }
    } on ControlPlaneError catch (error) {
      if (_bridgeShouldFailClosed(error)) {
        await _handleBridgeFailure(error);
      } else {
        notice = error.message;
      }
    } catch (error) {
      notice = '$error';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> deleteSelectedProfile() async {
    final profileId = focusedProfileId;
    if (profileId == null) {
      return;
    }
    if (_requiresLocalStateReset) {
      notice = _localStateResetBlockMessage();
      _notify();
      return;
    }
    busy = true;
    _notify();
    try {
      profiles = profiles
          .where((ProfileRecord profile) => profile.id != profileId)
          .toList(growable: false);
      profileBindings = <String, ProfileProviderBinding>{
        for (final entry in profileBindings.entries)
          if (entry.key != profileId) entry.key: entry.value,
      };
      _dropModePreferencesForScope(profileId);
      if (hostConnection?.isReady == true) {
        try {
          await bridge.deleteProfile(profileId);
        } on ControlPlaneError catch (error) {
          if (error.statusCode != 404) {
            rethrow;
          }
        }
      }
      if (currentProfileId == profileId) {
        currentProfileId = null;
      }
      resetDraft();
      notice = _copy.deletedMobileProfile(profileId);
      if (hostConnection?.isReady == true) {
        await refresh();
      }
    } on ControlPlaneError catch (error) {
      if (_bridgeShouldFailClosed(error)) {
        await _handleBridgeFailure(error);
      } else {
        notice = error.message;
      }
    } catch (error) {
      notice = '$error';
    } finally {
      busy = false;
      _notify();
    }
  }

  PortableProfileEnvelope? selectedPortableProfileEnvelope() {
    final selected = focusedSavedProfile;
    if (selected == null) {
      notice = _copy.saveOrSelectProfileBeforeExport;
      _notify();
      return null;
    }
    final binding =
        profileBindings[selected.id] ?? const ProfileProviderBinding();
    final managedProviderId = binding.managedProviderId?.trim() ?? '';
    final managedProviderSnapshot = managedProviderId.isEmpty
        ? null
        : managedProviderById(managedProviderId);
    if (binding.isManaged && managedProviderSnapshot == null) {
      notice = _copy.selectedProfileDependsOnMissingManagedProviderSnapshot;
      _notify();
      return null;
    }
    try {
      return PortableProfileEnvelope.build(
        profile: selected,
        providerBinding: binding,
        managedProviderSnapshot: managedProviderSnapshot,
      );
    } on FormatException catch (error) {
      notice = error.message;
      _notify();
      return null;
    }
  }

  Future<void> copyPortableProfileEnvelopeText(
    PortableProfileEnvelope envelope,
  ) async {
    if (_requiresLocalStateReset) {
      notice = _localStateResetBlockMessage();
      _notify();
      return;
    }
    busy = true;
    _notify();
    try {
      await _portableProfileTransferAdapter.copyEnvelopeText(
        envelope.toPrettyJson(),
      );
      final profileLabel = envelope.displayName;
      notice = envelope.isSecretBearing
          ? _copy.copiedSecretBearingPortableProfile(profileLabel)
          : _copy.copiedPortableProfile(profileLabel);
    } catch (error) {
      notice = '$error';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> sharePortableProfileEnvelopeText(
    PortableProfileEnvelope envelope,
  ) async {
    if (_requiresLocalStateReset) {
      notice = _localStateResetBlockMessage();
      _notify();
      return;
    }
    busy = true;
    _notify();
    try {
      await _portableProfileTransferAdapter.shareEnvelopeText(
        envelope.toPrettyJson(),
      );
      final profileLabel = envelope.displayName;
      notice = envelope.isSecretBearing
          ? _copy.sharedSecretBearingPortableProfileAsText(profileLabel)
          : _copy.sharedPortableProfileAsText(profileLabel);
    } catch (error) {
      notice = '$error';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> sharePortableProfileEnvelopeFile(
    PortableProfileEnvelope envelope,
  ) async {
    if (_requiresLocalStateReset) {
      notice = _localStateResetBlockMessage();
      _notify();
      return;
    }
    busy = true;
    _notify();
    try {
      await _portableProfileTransferAdapter.shareEnvelopeFile(
        suggestedName: _portableProfileSuggestedFilename(envelope),
        payload: envelope.toPrettyJson(),
      );
      final profileLabel = envelope.displayName;
      notice = envelope.isSecretBearing
          ? _copy.sharedSecretBearingPortableProfileAsFile(profileLabel)
          : _copy.sharedPortableProfileAsFile(profileLabel);
    } catch (error) {
      notice = '$error';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<PortableProfileEnvelope?>
  importPortableProfileEnvelopeFromFile() async {
    if (_requiresLocalStateReset) {
      notice = _localStateResetBlockMessage();
      _notify();
      return null;
    }
    try {
      final payload = await _portableProfileTransferAdapter.openEnvelopeText();
      if (payload == null) {
        return null;
      }
      return previewPortableProfileEnvelope(payload);
    } catch (error) {
      notice = '$error';
      _notify();
      return null;
    }
  }

  PortableProfileEnvelope? previewPortableProfileEnvelope(String payload) {
    try {
      return PortableProfileEnvelope.decode(payload);
    } on FormatException catch (error) {
      notice = error.message;
      _notify();
      return null;
    }
  }

  Future<void> confirmPortableProfileImport(
    PortableProfileEnvelope envelope,
  ) async {
    if (_requiresLocalStateReset) {
      notice = _localStateResetBlockMessage();
      _notify();
      return;
    }
    busy = true;
    _notify();
    try {
      final imported = importPortableProfileEnvelope(
        envelope,
        idFactory: _nextPortableImportId,
      );
      var profile = imported.profile;
      if (hostConnection?.isReady == true) {
        profile = await bridge.upsertProfile(profile);
      }
      if (imported.managedProvider != null) {
        final nextManagedProviders = <ManagedProviderRecord>[
          for (final provider in managedProviders)
            if (provider.id != imported.managedProvider!.id) provider,
          imported.managedProvider!,
        ]..sort(_managedProviderNameSort);
        managedProviders = _overlayManagedProviders(nextManagedProviders);
      }
      profileBindings = <String, ProfileProviderBinding>{
        ...profileBindings,
        profile.id: imported.providerBinding,
      };
      final nextProfiles = profiles.toList(growable: true);
      nextProfiles.removeWhere(
        (ProfileRecord existing) => existing.id == profile.id,
      );
      nextProfiles.add(profile);
      nextProfiles.sort(
        (ProfileRecord left, ProfileRecord right) =>
            left.id.compareTo(right.id),
      );
      profiles = nextProfiles;
      if ((currentProfileId?.trim() ?? '').isEmpty) {
        currentProfileId = profile.id;
      }
      focusedProfileId = profile.id;
      draft = _normalizeDraft(
        ProfileDraft.fromProfile(
          profile,
          providerBinding: imported.providerBinding,
        ),
      );
      workflowSurface = MobileWorkflowSurface.profile;
      notice = envelope.isSecretBearing
          ? _copy.importedSecretBearingProfile(
              profile.name.isEmpty ? profile.id : profile.name,
            )
          : _copy.importedProfile(
              profile.name.isEmpty ? profile.id : profile.name,
            );
      _scheduleStatePersist();
      if (hostConnection?.isReady == true) {
        await refresh();
      }
    } on ControlPlaneError catch (error) {
      if (_bridgeShouldFailClosed(error)) {
        await _handleBridgeFailure(error);
      } else {
        notice = error.message;
      }
    } catch (error) {
      notice = '$error';
    } finally {
      busy = false;
      _notify();
    }
  }

  String _nextPortableImportId() {
    _portableImportNonce += 1;
    final seed = _clock().microsecondsSinceEpoch.toRadixString(16);
    return 'portable-$seed-${_portableImportNonce.toRadixString(16)}';
  }

  Future<void> startSelectedProfile() async {
    final profileId = focusedProfileId ?? currentProfileId;
    if (profileId == null) {
      return;
    }
    await _runBridgeMutation(() async {
      final session = await bridge.startSession(profileId: profileId);
      selectedSessionId = session.id;
      notice = _copy.startedMobileSession(session.id);
      await refresh();
    });
  }

  Future<void> startResolutionFromDraft() async {
    await _runBridgeMutation(() async {
      final descriptor = activeProviderDescriptor;
      if (descriptor == null) {
        notice = _copy.selectedProviderNotAdvertisedByConnectedMobileHost;
        return;
      }
      final resolution = await _startResolutionForDraft(draft, descriptor);
      if (resolution == null) {
        return;
      }
      selectedResolutionId = resolution.id;
      notice = _resolutionStartedNotice(descriptor, resolution.id);
      await refresh();
    });
  }

  Future<void> cancelResolution(String resolutionId) async {
    await _runBridgeMutation(() async {
      final resolution = await bridge.cancelResolution(resolutionId);
      selectedResolutionId = resolution.id;
      notice = _copy.cancelledMobileResolution(resolution.id);
      await refresh();
    });
  }

  Future<void> materializeResolution(String resolutionId) async {
    await _runBridgeMutation(() async {
      final resolution = _resolutionById(resolutionId);
      if (resolution == null) {
        notice = _copy.resolutionNoLongerAvailable(resolutionId);
        return;
      }
      final advertised = resolution.artifact?.action(
        ArtifactAction.startOnThisDevice,
      );
      if (advertised == null ||
          advertised.executionOwner != ActionExecutionOwner.host) {
        notice = _copy.resolutionDoesNotAdvertiseAction(
          resolutionId,
          ArtifactAction.startOnThisDevice.label,
        );
        return;
      }
      final session = await bridge.materializeResolution(
        resolutionId: resolutionId,
        runtimeDefaults: RuntimeDefaults.fromProfileSpec(
          currentProfileDraft.spec,
        ),
      );
      selectedResolutionId = resolutionId;
      selectedSessionId = session.id;
      notice = _copy.startedMobileSessionFromResolution(
        session.id,
        resolutionId,
      );
      await refresh();
    });
  }

  Future<void> copyResolutionExport(String resolutionId) async {
    await _runBridgeMutation(() async {
      final exported = await bridge.exportResolution(resolutionId);
      await _handoffAdapter.copyLink(exported.link);
      selectedResolutionId = resolutionId;
      notice = _copy.copiedHandoffLink(
        resolutionId,
        _formatNoticeTimestamp(exported.expiresAt),
      );
    });
  }

  Future<void> shareResolutionExport(String resolutionId) async {
    await _runBridgeMutation(() async {
      final exported = await bridge.exportResolution(resolutionId);
      await _handoffAdapter.shareLink(exported.link);
      selectedResolutionId = resolutionId;
      notice = _copy.sharedHandoffLink(
        resolutionId,
        _formatNoticeTimestamp(exported.expiresAt),
      );
    });
  }

  Future<void> openResolutionExternalAction(
    String resolutionId,
    ArtifactAction action,
  ) async {
    await _runBridgeMutation(() async {
      final resolution = _resolutionById(resolutionId);
      if (resolution == null) {
        notice = _copy.resolutionNoLongerAvailable(resolutionId);
        return;
      }
      final advertised = resolution.artifact?.action(action);
      if (advertised == null ||
          advertised.executionOwner != ActionExecutionOwner.shellExternal) {
        notice = _copy.resolutionDoesNotAdvertiseAction(
          resolutionId,
          action.label,
        );
        return;
      }
      final targetUrl = resolution.externalTargetUrl(action);
      if (targetUrl == null) {
        notice = _copy.resolutionHasNoBrowserTarget(resolutionId, action.label);
        return;
      }
      final opened = await _browserLauncher.open(targetUrl);
      selectedResolutionId = resolutionId;
      notice = opened
          ? _copy.openedResolutionAction(resolutionId, action.label)
          : _copy.failedToOpenResolutionAction(resolutionId, action.label);
    });
  }

  Future<void> stopSession(String sessionId) async {
    await _runBridgeMutation(() async {
      await bridge.stopSession(sessionId);
      notice = _copy.stoppedSession(sessionId);
      await refresh();
    });
  }

  Future<void> openChallengeInBrowser(ChallengeRecord challenge) async {
    final url = challenge.openUrl?.trim() ?? '';
    if (url.isEmpty) {
      notice = _copy.challengeHasNoBrowserHandoffUrl;
      _notify();
      return;
    }
    final opened = await _browserLauncher.open(url);
    if (opened) {
      _browserHandoffChallengeId = challenge.id;
    }
    notice = opened
        ? _copy.openedMobileBrowserHandoff(challenge.kind)
        : _copy.failedToOpenMobileBrowserHandoffUrl;
    _notify();
  }

  Future<void> continueChallenge(String challengeId) async {
    await _runBridgeMutation(() async {
      await _continueChallengeThroughBridge(challengeId);
    });
  }

  Future<void> continueOwnedBrowserChallenge(
    String challengeId,
    ChallengeContinuationSubmission browserContinuation,
  ) async {
    await _runBridgeMutation(() async {
      await _continueChallengeThroughBridge(
        challengeId,
        browserContinuation: browserContinuation,
      );
    });
  }

  Future<void> cancelChallenge(
    String challengeId, {
    String? noticeOverride,
  }) async {
    await _runBridgeMutation(() async {
      _browserHandoffChallengeId = null;
      final challenge = await bridge.cancelChallenge(challengeId);
      _challengeCache[challenge.id] = challenge;
      notice = noticeOverride ?? _copy.cancelledChallenge(challengeId);
      await refresh();
    });
  }

  Future<void> exportDiagnostics(String sessionId) async {
    await _runBridgeMutation(() async {
      final diagnostics = await bridge.diagnostics(sessionId);
      final hostInfo = hostConnection?.info;
      final enriched = diagnostics.copyWith(
        guiBuild: appBuild,
        hostBuild: diagnostics.hostBuild.isKnown
            ? diagnostics.hostBuild
            : (hostInfo?.build ?? BuildIdentity.unknown),
        contractVersion: diagnostics.contractVersion.isNotEmpty
            ? diagnostics.contractVersion
            : (hostInfo?.contractVersion ?? ControlPlaneClient.contractVersion),
      );
      final directory = await _diagnosticsDirectoryProvider();
      await directory.create(recursive: true);
      final timestamp = _clock().toUtc().toIso8601String().replaceAll(':', '-');
      final file = File(
        _join(<String>[directory.path, '$sessionId-$timestamp.json']),
      );
      await file.writeAsString(enriched.toPrettyJson());

      notice = _copy.exportedDiagnostics(file.path);
      selectedSessionId = sessionId;
    });
  }

  Future<void> startPlatformTunnel(PlatformTunnelMode mode) async {
    await _runBridgeMutation(() async {
      final preparationBlockReason = platformTunnelStartPreparationBlockReason(
        mode,
      );
      if (preparationBlockReason != null) {
        notice = preparationBlockReason;
        return;
      }
      final executionPlan = _resolvedExecutionPlanForMode(mode)!;
      final runtimeDefaults = RuntimeDefaults.fromProfileSpec(
        currentProfileDraft.spec,
      );
      final runtimeDefaultsError = _platformTunnelRuntimeDefaultsBlockReason(
        mode: mode,
        executionPlan: executionPlan,
        runtimeDefaults: runtimeDefaults,
      );
      if (runtimeDefaultsError != null) {
        notice = runtimeDefaultsError;
        return;
      }
      final modePreferences = modePreferencesFor(mode);
      final routingError = _routingSelectionBlockReason(mode, modePreferences);
      if (routingError != null) {
        notice = routingError;
        return;
      }
      final underlayRoutePolicyError = _underlayRoutePolicySelectionBlockReason(
        mode,
        modePreferences,
      );
      if (underlayRoutePolicyError != null) {
        notice = underlayRoutePolicyError;
        return;
      }
      final underlayRoutePolicy = _requestedUnderlayRoutePolicyForMode(
        mode,
        modePreferences,
      );
      final resolutionId = await _ensureResolutionForPlatformTunnel(mode);
      if (resolutionId == null) {
        return;
      }
      var result = await bridge.startPlatformTunnel(
        mode: mode,
        resolutionId: resolutionId,
        runtimeDefaults: runtimeDefaults,
        executionPlan: executionPlan,
        transportProfile: _transportProfileReferenceForPlan(
          mode,
          executionPlan,
        ),
        applicationRoutingPolicy: _effectiveRoutingPolicyForMode(
          mode,
          modePreferences,
        ),
        allowedPackages: _effectiveAllowedPackagesForMode(
          mode,
          modePreferences,
        ),
        disallowedPackages: _effectiveDisallowedPackagesForMode(
          mode,
          modePreferences,
        ),
        underlayRoutePolicy: underlayRoutePolicy,
      );
      if (_requiresPlatformTunnelPermissionResume(mode, result)) {
        await bridge.requestPlatformTunnelPermission(mode: mode);
        result = await bridge.resumePlatformTunnel(
          startupAttemptId: result.startupAttemptId,
        );
      }
      _platformTunnelResults[mode] = result;
      if (result.ready) {
        await refresh();
        final sessionId = _resolvePlatformTunnelReadySessionId(
          sessionId: result.sessionId,
          resolutionId: resolutionId,
        );
        if (sessionId != null) {
          selectedSessionId = sessionId;
        }
      }
      notice = _platformTunnelNotice(result);
    });
  }

  Future<void> stopPlatformTunnel(PlatformTunnelMode mode) async {
    await _runBridgeMutation(() async {
      final result = await bridge.stopPlatformTunnel(mode: mode);
      _platformTunnelResults.remove(mode);
      await refresh();
      final message = result.message.trim();
      notice = message.isEmpty
          ? _copy.platformTunnelDisconnected(mode.label)
          : message;
    });
  }

  ChallengeRecord? activeChallengeFor(SessionRecord session) {
    final challengeID = session.activeChallengeId;
    return _activeChallengeById(challengeID);
  }

  ChallengeRecord? activeChallengeForResolution(ResolutionRecord resolution) {
    final challengeID = resolution.activeChallengeId;
    return _activeChallengeById(challengeID);
  }

  ChallengeRecord? _activeChallengeById(String? challengeID) {
    if (challengeID == null || challengeID.isEmpty) {
      return null;
    }
    final cached = _challengeCache[challengeID];
    if (cached != null) {
      return cached;
    }
    for (final event in events.reversed) {
      final challenge = event.challenge;
      if (challenge != null && challenge.id == challengeID) {
        return challenge;
      }
    }
    return null;
  }

  ResolutionRecord? _resolutionById(String resolutionId) {
    final normalized = resolutionId.trim();
    if (normalized.isEmpty) {
      return null;
    }
    for (final resolution in resolutions) {
      if (resolution.id == normalized) {
        return resolution;
      }
    }
    return null;
  }

  ResolutionRecord? _selectedResolutionRecord() {
    final resolutionId = selectedResolutionId?.trim() ?? '';
    if (resolutionId.isEmpty) {
      return null;
    }
    return _resolutionById(resolutionId);
  }

  Future<ResolutionRecord?> _startResolutionForDraft(
    ProfileDraft sourceDraft,
    ProviderDescriptor descriptor,
  ) async {
    if (descriptor.inputKind != ProviderInputKind.link) {
      notice = _copy.providerExpectsLinkEntryOnlyMobile(
        providerName: descriptor.displayName,
        inputKind: descriptor.inputKind.value,
      );
      return null;
    }
    final blockReason = _providerSettingsBlockReason(descriptor);
    if (blockReason != null) {
      notice = blockReason;
      return null;
    }
    return bridge.startResolution(
      provider: descriptor.id,
      input: ProviderInputEnvelope(
        kind: descriptor.inputKind,
        link: sourceDraft.spec.link,
      ),
      providerSettings: descriptor.normalizeProviderSettings(
        sourceDraft.spec.providerSettings,
        applyDefaults: false,
      ),
    );
  }

  Future<String?> _ensureResolutionForPlatformTunnel(
    PlatformTunnelMode mode,
  ) async {
    final selectedResolution = _selectedResolutionRecord();
    if (selectedResolution != null) {
      switch (selectedResolution.state) {
        case ResolutionState.resolved:
          if (_forceFreshResolutionAfterEmbeddedSignOut) {
            _clearSelectedResolutionSelection();
            break;
          }
          return selectedResolution.id;
        case ResolutionState.challengeRequired:
          notice = _copy.challengeMustCompleteBeforeStarting(mode.label);
          return null;
        case ResolutionState.starting:
          notice = _copy.waitForProviderResolutionBeforeStarting(mode.label);
          return null;
        case ResolutionState.failed ||
            ResolutionState.cancelled ||
            ResolutionState.expired:
          _clearSelectedResolutionSelection();
          break;
      }
    }
    final descriptor = descriptorForProvider(currentProfileDraft.spec.provider);
    if (descriptor == null) {
      notice = _copy.selectedProviderNotAdvertisedByConnectedMobileHost;
      return null;
    }
    final resolution = await _startResolutionForDraft(
      currentProfileDraft,
      descriptor,
    );
    if (resolution == null) {
      return null;
    }
    _forceFreshResolutionAfterEmbeddedSignOut = false;
    selectedResolutionId = resolution.id;
    await refresh();
    final refreshedResolution = _resolutionById(resolution.id) ?? resolution;
    switch (refreshedResolution.state) {
      case ResolutionState.resolved:
        return refreshedResolution.id;
      case ResolutionState.challengeRequired:
        notice = _copy.resolutionStartedThenCompleteChallengeBeforeStarting(
          _resolutionStartedNotice(descriptor, refreshedResolution.id),
          mode.label,
        );
        return null;
      case ResolutionState.starting:
        notice = _copy.resolutionStartedThenWaitForFinishBeforeStarting(
          _resolutionStartedNotice(descriptor, refreshedResolution.id),
          mode.label,
        );
        return null;
      case ResolutionState.failed ||
          ResolutionState.cancelled ||
          ResolutionState.expired:
        notice = _resolutionUnavailableForPlatformTunnelNotice(
          mode,
          refreshedResolution,
        );
        return null;
    }
  }

  ProviderDescriptor? descriptorForProvider(String providerId) {
    final normalized = providerId.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    for (final descriptor in providerDescriptors) {
      if (descriptor.id.trim().toLowerCase() == normalized) {
        return descriptor;
      }
    }
    return null;
  }

  ProviderDescriptor? get activeProviderDescriptor =>
      descriptorForProvider(draft.spec.provider);

  ManagedProviderRecord? managedProviderById(String managedProviderId) {
    final normalized = managedProviderId.trim();
    if (normalized.isEmpty) {
      return null;
    }
    for (final provider in managedProviders) {
      if (provider.id == normalized) {
        return provider;
      }
    }
    return null;
  }

  ProviderTemplateRecord? providerTemplateById(String templateId) {
    final normalized = templateId.trim();
    if (normalized.isEmpty) {
      return null;
    }
    for (final template in providerTemplates) {
      if (template.id == normalized) {
        return template;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _persistTimer?.cancel();
    _pollTimer?.cancel();
    _noticeTimer?.cancel();
    _eventSubscription?.cancel();
    _browserReturnSubscription?.cancel();
    _portableProfileIngressSubscription?.cancel();
    unawaited(bridge.dispose());
    super.dispose();
  }

  Future<void> _handleAppResumed() async {
    final autoContinued = await _handleBrowserReturnSignal(
      const MobileBrowserReturnSignal(
        kind: BrowserReturnSignalKind.foregroundResume,
      ),
    );
    if (_disposed) {
      return;
    }
    if (hostConnection?.isReady == true) {
      if (!autoContinued) {
        await refresh();
      }
    } else if (!busy) {
      await reconnect();
    }
  }

  void _startBrowserReturnSignals() {
    if (_browserReturnSubscription != null) {
      return;
    }
    _browserReturnSubscription = bridge.browserReturnSignals.listen((
      MobileBrowserReturnSignal signal,
    ) {
      unawaited(_handleBrowserReturnSignal(signal));
    }, onError: (Object error, StackTrace stackTrace) {});
  }

  void _startPortableProfileIngress() {
    if (_portableProfileIngressSubscription != null) {
      return;
    }
    _portableProfileIngressSubscription = _portableProfileTransferAdapter
        .ingressPayloads
        .listen((String payload) {
          unawaited(_handlePortableProfileIngressPayload(payload));
        }, onError: (Object error, StackTrace stackTrace) {});
  }

  Future<void> _handlePortableProfileIngressPayload(String payload) async {
    if (_disposed) {
      return;
    }
    final trimmed = payload.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (_requiresLocalStateReset) {
      notice = _localStateResetBlockMessage();
      _notify();
      return;
    }
    if (_pendingPortableProfileImportPayload == trimmed) {
      return;
    }
    try {
      final envelope = PortableProfileEnvelope.decode(trimmed);
      _pendingPortableProfileImportPayload = trimmed;
      _pendingPortableProfileImportEnvelope = envelope;
      workflowSurface = MobileWorkflowSurface.profile;
      notice = envelope.isSecretBearing
          ? _copy.receivedSecretBearingPortableProfileForReview(
              envelope.displayName,
            )
          : _copy.receivedPortableProfileForReview(envelope.displayName);
      _notify();
    } on FormatException catch (error) {
      notice = error.message;
      _notify();
    }
  }

  Future<void> _connectBridge({bool localStateBlocked = false}) async {
    busy = true;
    status = ShellStatus.booting;
    _notify();

    try {
      hostConnection = await bridge.ensureReady();
    } catch (error) {
      hostConnection = MobileHostConnectionResult(
        state: MobileHostLifecycleState.failed,
        message: '$error',
      );
    }

    _clearPlatformTunnelResults();

    if (localStateBlocked) {
      if (hostConnection?.isReady == true) {
        try {
          await refresh();
        } catch (error) {
          await _handleBridgeFailure(error);
          return;
        }
      } else {
        await _stopRuntimeMonitoring();
        _challengeCache.clear();
        transportProfiles = const <TransportProfileStatus>[];
        resolutions = const <ResolutionRecord>[];
        sessions = const <SessionRecord>[];
        selectedResolutionId = null;
        selectedSessionId = null;
        installedAppsError = null;
      }
      busy = false;
      status = ShellStatus.blocked;
      notice = _blockedLocalStateMessage ?? _localStateResetBlockMessage();
      _notify();
      return;
    }

    _normalizeSelectedPlatformTunnelMode();

    if (hostConnection?.isReady != true) {
      await _stopRuntimeMonitoring();
      _challengeCache.clear();
      transportProfiles = const <TransportProfileStatus>[];
      resolutions = const <ResolutionRecord>[];
      sessions = const <SessionRecord>[];
      selectedResolutionId = null;
      selectedSessionId = null;
      installedAppsError = null;
      busy = false;
      status = ShellStatus.blocked;
      notice = hostConnection?.message;
      _notify();
      return;
    }

    status = ShellStatus.ready;
    notice = hostConnection?.message;
    try {
      await _rehydrateProfiles();
      await refresh();
    } catch (error) {
      await _handleBridgeFailure(error);
      return;
    }
    if (status != ShellStatus.ready) {
      return;
    }
    _startEventStream();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (Timer _) {
      unawaited(refresh());
    });
    busy = false;
    _notify();
  }

  void _startEventStream() {
    _eventSubscription?.cancel();
    _eventSubscription = bridge.events().listen(
      (EventRecord event) {
        if (events.length >= 150) {
          events = <EventRecord>[...events.skip(events.length - 149), event];
        } else {
          events = <EventRecord>[...events, event];
        }
        if (event.challenge != null) {
          _challengeCache[event.challenge!.id] = event.challenge!;
        }
        _applyEvent(event);
        _scheduleRefresh();
        _notify();
      },
      onError: (Object error) {
        if (_disposed) {
          return;
        }
        unawaited(_handleBridgeFailure(error));
      },
      onDone: () {
        if (_disposed || status != ShellStatus.ready) {
          return;
        }
        unawaited(
          _handleBridgeFailure(
            ControlPlaneError(
              statusCode: 0,
              code: 'connection_closed',
              message: currentShellText.eventStreamClosed,
            ),
          ),
        );
      },
    );
  }

  void _applyEvent(EventRecord event) {
    final index = sessions.indexWhere(
      (SessionRecord session) => session.id == event.sessionId,
    );
    if (index < 0) {
      return;
    }
    final current = sessions[index];
    final nextActiveChallengeId = switch (event.challenge?.status) {
      ChallengeStatus.pending ||
      ChallengeStatus.continuing => event.challenge!.id,
      ChallengeStatus.completed ||
      ChallengeStatus.cancelled ||
      ChallengeStatus.failed => '',
      null => current.activeChallengeId,
    };
    final next = current.copyWith(
      state: event.state ?? current.state,
      activeChallengeId: nextActiveChallengeId,
      updatedAt: event.timestamp,
      failure: event.type == EventType.sessionFailed
          ? FailureInfo(stage: event.stage, message: event.message)
          : current.failure,
      stoppedAt: event.type == EventType.sessionStopped
          ? event.timestamp
          : current.stoppedAt,
    );
    final updated = sessions.toList(growable: true);
    updated[index] = next;
    _replaceSessions(updated);
  }

  void _replaceSessions(List<SessionRecord> nextSessions) {
    sessions = _orderedSessions(nextSessions);
    selectedSessionId = _resolveSelectedSessionId(sessions);
  }

  List<SessionRecord> _orderedSessions(List<SessionRecord> nextSessions) {
    final ordered = nextSessions.toList(growable: true);
    ordered.sort((SessionRecord left, SessionRecord right) {
      final updatedAt = right.updatedAt.compareTo(left.updatedAt);
      if (updatedAt != 0) {
        return updatedAt;
      }
      final startedAt = right.startedAt.compareTo(left.startedAt);
      if (startedAt != 0) {
        return startedAt;
      }
      return left.id.compareTo(right.id);
    });
    return ordered;
  }

  String? _resolveSelectedSessionId(List<SessionRecord> nextSessions) {
    if (nextSessions.isEmpty) {
      return null;
    }

    final preferredActive = _firstActiveSession(nextSessions);
    final preferred = preferredActive?.id ?? nextSessions.first.id;
    final currentID = selectedSessionId?.trim() ?? '';
    if (currentID.isEmpty) {
      return preferred;
    }

    SessionRecord? current;
    for (final session in nextSessions) {
      if (session.id == currentID) {
        current = session;
        break;
      }
    }
    if (current == null) {
      return preferred;
    }
    if (_isTerminalSession(current) && preferredActive != null) {
      return preferredActive.id;
    }
    return current.id;
  }

  String? _resolveSelectedResolutionId(List<ResolutionRecord> nextResolutions) {
    if (nextResolutions.isEmpty) {
      return null;
    }
    final preferredLive = _firstPreferredResolution(nextResolutions);
    final preferred = preferredLive?.id ?? nextResolutions.first.id;
    final currentID = selectedResolutionId?.trim() ?? '';
    if (currentID.isEmpty) {
      return preferred;
    }
    ResolutionRecord? current;
    for (final resolution in nextResolutions) {
      if (resolution.id == currentID) {
        current = resolution;
        break;
      }
    }
    if (current == null) {
      return preferred;
    }
    if (current.isTerminal && preferredLive != null) {
      return preferredLive.id;
    }
    return current.id;
  }

  SessionRecord? _firstActiveSession(List<SessionRecord> nextSessions) {
    for (final session in nextSessions) {
      if (!_isTerminalSession(session)) {
        return session;
      }
    }
    return null;
  }

  String? _resolvePlatformTunnelReadySessionId({
    required String sessionId,
    required String resolutionId,
  }) {
    final explicitSessionId = sessionId.trim();
    if (explicitSessionId.isNotEmpty &&
        sessions.any(
          (SessionRecord session) => session.id == explicitSessionId,
        )) {
      return explicitSessionId;
    }

    final normalizedResolutionId = resolutionId.trim();
    if (normalizedResolutionId.isEmpty) {
      return null;
    }

    SessionRecord? fallbackMatch;
    for (final session in sessions) {
      if ((session.sourceResolutionId ?? '').trim() != normalizedResolutionId) {
        continue;
      }
      fallbackMatch ??= session;
      if (!_isTerminalSession(session)) {
        return session.id;
      }
    }
    return fallbackMatch?.id;
  }

  bool _isTerminalSession(SessionRecord session) {
    return session.state == SessionState.stopped ||
        session.state == SessionState.failed;
  }

  List<ResolutionRecord> _orderedResolutions(
    List<ResolutionRecord> nextResolutions,
  ) {
    final ordered = nextResolutions.toList(growable: true);
    ordered.sort((ResolutionRecord left, ResolutionRecord right) {
      final updatedAt = right.updatedAt.compareTo(left.updatedAt);
      if (updatedAt != 0) {
        return updatedAt;
      }
      final startedAt = right.startedAt.compareTo(left.startedAt);
      if (startedAt != 0) {
        return startedAt;
      }
      return left.id.compareTo(right.id);
    });
    return ordered;
  }

  ResolutionRecord? _firstPreferredResolution(
    List<ResolutionRecord> nextResolutions,
  ) {
    for (final resolution in nextResolutions) {
      if (!resolution.isTerminal) {
        return resolution;
      }
    }
    return null;
  }

  Future<void> _rehydrateProfiles() async {
    if (profiles.isEmpty || hostConnection?.isReady != true) {
      return;
    }
    final restored = <ProfileRecord>[];
    for (final profile in profiles) {
      restored.add(await bridge.upsertProfile(profile));
    }
    profiles = restored;
    _scheduleStatePersist();
  }

  Future<List<ChallengeRecord>> _loadActiveChallenges(
    List<SessionRecord> nextSessions,
    List<ResolutionRecord> nextResolutions,
  ) async {
    final ids =
        <String?>[
              ...nextSessions.map(
                (SessionRecord session) => session.activeChallengeId,
              ),
              ...nextResolutions.map(
                (ResolutionRecord resolution) => resolution.activeChallengeId,
              ),
            ]
            .whereType<String>()
            .map((String id) => id.trim())
            .where((String id) => id.isNotEmpty)
            .toSet();
    if (ids.isEmpty) {
      return const <ChallengeRecord>[];
    }

    final loaded = <ChallengeRecord>[];
    for (final id in ids) {
      final cached = _challengeCache[id];
      if (cached != null) {
        loaded.add(cached);
        continue;
      }
      try {
        loaded.add(await bridge.challenge(id));
      } on ControlPlaneError catch (error) {
        if (error.statusCode == 404) {
          continue;
        }
        rethrow;
      }
    }
    return loaded;
  }

  void _mergeChallenges(List<ChallengeRecord> challenges) {
    final activeIDs =
        <String?>[
              ...sessions.map(
                (SessionRecord session) => session.activeChallengeId,
              ),
              ...resolutions.map(
                (ResolutionRecord resolution) => resolution.activeChallengeId,
              ),
            ]
            .whereType<String>()
            .map((String id) => id.trim())
            .where((String id) => id.isNotEmpty)
            .toSet();

    _challengeCache.removeWhere(
      (String id, ChallengeRecord _) => !activeIDs.contains(id),
    );
    if (_browserHandoffChallengeId != null &&
        !activeIDs.contains(_browserHandoffChallengeId)) {
      _browserHandoffChallengeId = null;
    }
    _autoContinuedChallengeIds.removeWhere(
      (String id) => !activeIDs.contains(id),
    );
    for (final challenge in challenges) {
      _challengeCache[challenge.id] = challenge;
    }
  }

  Future<bool> _handleBrowserReturnSignal(
    MobileBrowserReturnSignal signal,
  ) async {
    if (_disposed || busy) {
      return false;
    }
    final challenge = _autoContinuableChallengeForSignal(signal);
    if (challenge == null ||
        _autoContinuedChallengeIds.contains(challenge.id)) {
      return false;
    }
    _autoContinuedChallengeIds.add(challenge.id);
    await _runBridgeMutation(() async {
      await _continueChallengeThroughBridge(
        challenge.id,
        automatic: true,
        signalKind: signal.kind,
      );
    });
    return true;
  }

  ChallengeRecord? _autoContinuableChallengeForSignal(
    MobileBrowserReturnSignal signal,
  ) {
    if (hostConnection?.isReady != true) {
      return null;
    }
    final challengeId = _browserHandoffChallengeId?.trim() ?? '';
    if (challengeId.isEmpty) {
      return null;
    }
    final challenge = _activeChallengeById(challengeId);
    if (challenge == null ||
        challenge.completionMode != ChallengeCompletionMode.appReturnCallback) {
      return null;
    }
    final browserReturn = challenge.browserReturn;
    if (browserReturn == null ||
        !browserReturn.allowAutoContinue ||
        !browserReturn.signalKinds.contains(signal.kind)) {
      return null;
    }
    final expectedReturnUri = browserReturn.expectedReturnUri?.trim() ?? '';
    if ((signal.kind == BrowserReturnSignalKind.appLink ||
            signal.kind == BrowserReturnSignalKind.universalLink) &&
        expectedReturnUri.isNotEmpty &&
        !_matchesExpectedReturnUri(signal.uri, expectedReturnUri)) {
      return null;
    }
    return challenge;
  }

  bool _matchesExpectedReturnUri(String? actual, String expected) {
    final candidate = actual?.trim() ?? '';
    if (candidate.isEmpty) {
      return false;
    }
    return candidate == expected ||
        candidate.startsWith('$expected?') ||
        candidate.startsWith('$expected#');
  }

  Future<void> _continueChallengeThroughBridge(
    String challengeId, {
    bool automatic = false,
    BrowserReturnSignalKind? signalKind,
    ChallengeContinuationSubmission? browserContinuation,
  }) async {
    final cachedChallenge = _challengeCache[challengeId];
    final fallbackResolutionId = cachedChallenge?.resolutionId?.trim() ?? '';
    _browserHandoffChallengeId = null;
    final challenge = await bridge.continueChallenge(
      challengeId,
      browserContinuation: browserContinuation,
    );
    final resolutionId = challenge.resolutionId?.trim().isNotEmpty == true
        ? challenge.resolutionId!.trim()
        : fallbackResolutionId;
    if (resolutionId.isNotEmpty) {
      selectedResolutionId = resolutionId;
    }
    _challengeCache[challenge.id] = challenge;
    notice = automatic
        ? _copy.detectedBrowserReturnAndContinuedChallenge(
            _browserReturnSignalLabel(signalKind),
            challengeId,
          )
        : (browserContinuation != null
              ? _copy.completedInAppBrowserContinuation(challengeId)
              : _copy.continuedChallenge(challengeId));
    await refresh();
  }

  bool challengeRequiresOwnedBrowser(ChallengeRecord challenge) =>
      challenge.completionMode ==
          ChallengeCompletionMode.ownedBrowserObserved &&
      challenge.ownedBrowser != null &&
      challenge.ownedBrowser!.cookieUrls.isNotEmpty;

  String _localStateResetBlockMessage() {
    return _blockedLocalStateMessage ??
        _copy.resetLocalMobileShellStateBeforeRuntimeControlContinue;
  }

  String _browserReturnSignalLabel(BrowserReturnSignalKind? signalKind) {
    return switch (signalKind) {
      BrowserReturnSignalKind.appLink => _copy.appLinkBrowserReturn,
      BrowserReturnSignalKind.universalLink => _copy.universalLinkBrowserReturn,
      BrowserReturnSignalKind.foregroundResume =>
        _copy.browserReturnOnAppResume,
      null => _copy.browserReturn,
    };
  }

  void _scheduleRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(refresh());
    });
  }

  Future<void> _runBridgeMutation(Future<void> Function() action) async {
    if (_requiresLocalStateReset) {
      notice = _localStateResetBlockMessage();
      _notify();
      return;
    }
    if (hostConnection?.isReady != true) {
      notice = hostConnection?.message ?? _copy.mobileHostBridgeNotReady;
      _notify();
      return;
    }
    busy = true;
    _notify();
    try {
      await action();
    } on ControlPlaneError catch (error) {
      if (_bridgeShouldFailClosed(error)) {
        await _handleBridgeFailure(error);
        return;
      }
      notice = error.message;
    } catch (error) {
      notice = '$error';
    } finally {
      busy = false;
      _notify();
    }
  }

  bool _bridgeShouldFailClosed(ControlPlaneError error) {
    return error.statusCode == 0 ||
        error.incompatibleHost ||
        error.statusCode >= 500;
  }

  void _relocalizeReadyHostConnection() {
    final current = hostConnection;
    if (current == null || !current.isReady) {
      return;
    }
    final endpoint = _mobileHostEndpointFromMessage(current.message);
    if (endpoint == null) {
      return;
    }
    hostConnection = MobileHostConnectionResult(
      state: current.state,
      message: _copy.connectedToMobileHostBridge(endpoint),
      info: current.info,
      description: current.description,
    );
  }

  Future<void> _refreshHostInfo() async {
    final current = hostConnection;
    if (current == null || !current.isReady) {
      return;
    }
    final info = await bridge.hostInfo();
    hostConnection = MobileHostConnectionResult(
      state: current.state,
      message: current.message,
      info: info,
      description: current.description,
    );
    _normalizeSelectedPlatformTunnelMode();
  }

  String? _mobileHostEndpointFromMessage(String? message) {
    if (message == null || message.isEmpty) {
      return null;
    }
    final match = RegExp(r'https?://\S+').firstMatch(message);
    final endpoint = match?.group(0)?.trim();
    return endpoint == null || endpoint.isEmpty ? null : endpoint;
  }

  Future<void> _handleBridgeFailure(Object error) async {
    await _stopRuntimeMonitoring();
    final message = error is ControlPlaneError ? error.message : '$error';
    final state = error is ControlPlaneError && error.incompatibleHost
        ? MobileHostLifecycleState.incompatible
        : MobileHostLifecycleState.unavailable;
    hostConnection = MobileHostConnectionResult(
      state: state,
      message: message,
      info: hostConnection?.info,
      description: hostConnection?.description ?? '',
    );
    _clearPlatformTunnelResults();
    transportProfiles = const <TransportProfileStatus>[];
    resolutions = const <ResolutionRecord>[];
    sessions = const <SessionRecord>[];
    selectedResolutionId = null;
    selectedSessionId = null;
    installedAppsError = null;
    status = ShellStatus.blocked;
    notice = message;
    busy = false;
    _notify();
  }

  Future<void> _stopRuntimeMonitoring() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _persistTimer?.cancel();
    _persistTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    await _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  Future<void> _restorePersistedState() async {
    try {
      final state = await stateStore.load();
      _restoreStateError = null;
      if (state == null) {
        return;
      }
      profiles = state.profiles;
      managedProviders = state.managedProviders;
      providerTemplates = state.providerTemplates;
      profileBindings = state.profileBindings;
      currentProfileId = state.currentProfileId;
      focusedProfileId = state.focusedProfileId;
      selectedPlatformTunnelMode = state.selectedPlatformTunnelMode;
      platformModePreferences = state.platformModePreferences;
      localeOverrideTag = state.localeTag;
      draft = state.draft;
      _normalizeProfileSelectionState();
      managedProviderDraft = _defaultManagedProviderDraft();
      providerTemplateDraft = _defaultProviderTemplateDraft();
      _persistedStateSignature = state.signature();
    } catch (error) {
      _restoreStateError = error;
      _requiresLocalStateReset = true;
      _blockedLocalStateMessage = _copy.failedToRestoreMobileShellState(error);
      notice = _blockedLocalStateMessage;
    }
  }

  void _scheduleStatePersist() {
    if (_requiresLocalStateReset) {
      return;
    }
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 150), () {
      unawaited(_persistState());
    });
  }

  Future<void> _persistState() async {
    if (_requiresLocalStateReset) {
      return;
    }
    final next = MobileShellState(
      profiles: profiles,
      managedProviders: managedProviders,
      providerTemplates: providerTemplates,
      profileBindings: profileBindings,
      initialCurrentProfileId: currentProfileId,
      initialFocusedProfileId: focusedProfileId,
      selectedPlatformTunnelMode: selectedPlatformTunnelMode,
      platformModePreferences: platformModePreferences,
      localeTag: localeOverrideTag,
      draft: draft,
    );
    final signature = next.signature();
    if (signature == _persistedStateSignature) {
      return;
    }
    try {
      await stateStore.save(next, providerDescriptors: providerDescriptors);
      _persistedStateSignature = signature;
    } catch (error) {
      notice = _copy.failedToPersistMobileShellState(error);
      _notify();
    }
  }

  void _clearPlatformTunnelResults() {
    _platformTunnelResults.clear();
    platformTunnelStatuses = const <PlatformTunnelStatus>[];
  }

  void _replacePlatformTunnelStatuses(List<PlatformTunnelStatus> nextStatuses) {
    platformTunnelStatuses = nextStatuses;
    final seenModes = <PlatformTunnelMode>{};
    for (final status in nextStatuses) {
      seenModes.add(status.mode);
      final result = _platformTunnelResultFromStatus(status);
      if (result == null) {
        _platformTunnelResults.remove(status.mode);
      } else {
        _platformTunnelResults[status.mode] = result;
      }
    }
    _platformTunnelResults.removeWhere(
      (PlatformTunnelMode mode, PlatformTunnelStartResult _) =>
          !seenModes.contains(mode),
    );
  }

  PlatformTunnelStartResult? _platformTunnelResultFromStatus(
    PlatformTunnelStatus status,
  ) {
    if (status.state == PlatformTunnelLifecycleState.stopped) {
      return null;
    }
    if (status.state == PlatformTunnelLifecycleState.ready || status.ready) {
      return PlatformTunnelStartResult(
        mode: status.mode,
        ready: true,
        executionPlan: status.executionPlan,
        transportProfile: status.transportProfile,
        remoteIngress: status.remoteIngress,
        dataplane: status.dataplane,
        sessionId: status.sessionId,
        underlayRoutePolicy: status.underlayRoutePolicy,
        message: status.message,
      );
    }
    if (status.stage == null || status.missingPrerequisite == null) {
      return null;
    }
    return PlatformTunnelStartResult(
      mode: status.mode,
      ready: false,
      executionPlan: status.executionPlan,
      transportProfile: status.transportProfile,
      remoteIngress: status.remoteIngress,
      dataplane: status.dataplane,
      stage: status.stage,
      missingPrerequisite: status.missingPrerequisite,
      startupAttemptId: status.startupAttemptId,
      underlayRoutePolicy: status.underlayRoutePolicy,
      message: status.message,
    );
  }

  bool _requiresPlatformTunnelPermissionResume(
    PlatformTunnelMode mode,
    PlatformTunnelStartResult result,
  ) {
    return mode == PlatformTunnelMode.androidVpnService &&
        !result.ready &&
        result.stage == PlatformTunnelStartupStage.permissionAcquire &&
        result.missingPrerequisite == PlatformTunnelPrerequisite.permission &&
        result.startupAttemptId.isNotEmpty;
  }

  String _platformTunnelNotice(PlatformTunnelStartResult result) {
    if (result.ready) {
      if (result.underlayRoutePolicy ==
          PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork) {
        return _copy.platformTunnelReadyWithRoutingProfile(
          modeLabel: result.mode.label,
          profileLabel: _underlayRoutePolicyLabel(result.underlayRoutePolicy!),
        );
      }
      return _copy.platformTunnelReady(result.mode.label);
    }
    return _copy.platformTunnelBlocked(
      modeLabel: result.mode.label,
      stageLabel: result.stage?.label ?? _copy.unknownStage,
      prerequisiteLabel: result.missingPrerequisite?.label,
      message: result.message,
    );
  }

  String _resolutionUnavailableForPlatformTunnelNotice(
    PlatformTunnelMode mode,
    ResolutionRecord resolution,
  ) {
    final stage = resolution.failure?.stage ?? resolution.state.value;
    final message =
        resolution.failure?.message ??
        _copy.providerDidNotReturnStartableArtifact;
    return _copy.resolutionUnavailableForPlatformTunnel(
      modeLabel: mode.label,
      resolutionId: resolution.id,
      stage: stage,
      message: message,
    );
  }

  String _resolutionStartedNotice(
    ProviderDescriptor descriptor,
    String resolutionId,
  ) {
    if (descriptor.browserPolicy == ProviderBrowserPolicy.externalRequired) {
      return _copy.startedMobileResolutionForProviderWithExternalBrowser(
        resolutionId,
        descriptor.displayName,
      );
    }
    if (descriptor.mayRequireBrowserContinuation) {
      return _copy.startedMobileResolutionForProviderWithBrowserContinuation(
        resolutionId,
        descriptor.displayName,
      );
    }
    return _copy.startedMobileResolutionForProvider(
      resolutionId,
      descriptor.displayName,
    );
  }

  ProfileDraft _defaultDraft() {
    final base = ProfileDraft.defaults();
    if (providerDescriptors.isEmpty) {
      return base;
    }
    return _normalizeDraft(base.copyWith(spec: base.spec.copyWith(link: '')));
  }

  ManagedProviderDraft _defaultManagedProviderDraft({
    String? preferredProvider,
  }) {
    final boundManagedProviderId =
        draft.providerBinding.managedProviderId?.trim() ?? '';
    final boundProvider = boundManagedProviderId.isEmpty
        ? null
        : managedProviderById(boundManagedProviderId)?.provider;
    final providerId =
        preferredProvider ??
        boundProvider ??
        activeProviderDescriptor?.id ??
        (supportedProviderCatalog.isEmpty
            ? null
            : supportedProviderCatalog.first.id) ??
        '';
    return _normalizeManagedProviderDraft(
      ManagedProviderDraft.defaults(provider: providerId),
    );
  }

  ProviderTemplateDraft _defaultProviderTemplateDraft({
    String? preferredProvider,
  }) {
    final managedProvider = managedProviderDraft.provider.trim().isEmpty
        ? null
        : managedProviderDraft.provider.trim();
    final providerId =
        preferredProvider ??
        managedProvider ??
        (supportedProviderCatalog.isEmpty
            ? null
            : supportedProviderCatalog.first.id) ??
        '';
    return _normalizeProviderTemplateDraft(
      ProviderTemplateDraft.defaults(provider: providerId),
    );
  }

  ProfileDraft _normalizeDraft(ProfileDraft candidate) {
    final rawProvider = candidate.spec.provider.trim();
    if (providerDescriptors.isEmpty) {
      return candidate;
    }
    final descriptor = descriptorForProvider(rawProvider);
    if (descriptor == null) {
      if (rawProvider.isEmpty) {
        final fallback = providerDescriptors.first;
        return candidate.copyWith(
          spec: candidate.spec.copyWith(
            provider: fallback.id,
            interactiveProvider: fallback.mayRequireBrowserContinuation,
          ),
        );
      }
      return candidate;
    }
    final sameProvider =
        descriptor.id.trim().toLowerCase() == rawProvider.toLowerCase();
    final link = sameProvider ? candidate.spec.link : '';
    final providerSettings = switch (descriptor.settingsSchema) {
      null => const <String, dynamic>{},
      _ when descriptor.supportsProviderSettings =>
        descriptor.normalizeProviderSettings(
          sameProvider
              ? candidate.spec.providerSettings
              : const <String, dynamic>{},
        ),
      _ =>
        sameProvider
            ? candidate.spec.providerSettings
            : const <String, dynamic>{},
    };
    return candidate.copyWith(
      spec: candidate.spec.copyWith(
        provider: descriptor.id,
        link: link,
        providerSettings: providerSettings,
        interactiveProvider: descriptor.mayRequireBrowserContinuation,
      ),
    );
  }

  ManagedProviderDraft _normalizeManagedProviderDraft(
    ManagedProviderDraft candidate,
  ) {
    final supported =
        supportedProviderDefinitionFor(candidate.provider) ??
        (supportedProviderCatalog.isEmpty
            ? null
            : supportedProviderCatalog.first);
    if (supported == null) {
      return candidate;
    }
    final descriptor = descriptorForProvider(candidate.provider);
    final sameProvider =
        supported.id.trim().toLowerCase() ==
        candidate.provider.trim().toLowerCase();
    final seedValues = sameProvider
        ? candidate.providerSettings
        : const <String, dynamic>{};
    final providerSettings = switch (descriptor?.settingsSchema) {
      null => seedValues,
      _ when descriptor != null && descriptor.supportsProviderSettings =>
        descriptor.normalizeProviderSettings(seedValues),
      _ => seedValues,
    };
    return candidate.copyWith(
      provider: supported.id,
      providerSettings: providerSettings,
    );
  }

  ProviderTemplateDraft _normalizeProviderTemplateDraft(
    ProviderTemplateDraft candidate,
  ) {
    final supported =
        supportedProviderDefinitionFor(candidate.provider) ??
        (supportedProviderCatalog.isEmpty
            ? null
            : supportedProviderCatalog.first);
    if (supported == null) {
      return candidate;
    }
    final descriptor = descriptorForProvider(candidate.provider);
    final sameProvider =
        supported.id.trim().toLowerCase() ==
        candidate.provider.trim().toLowerCase();
    final seedValues = sameProvider
        ? candidate.providerSettings
        : const <String, dynamic>{};
    final providerSettings = switch (descriptor?.settingsSchema) {
      null => seedValues,
      _ when descriptor != null && descriptor.supportsProviderSettings =>
        descriptor.normalizeProviderSettings(seedValues),
      _ => seedValues,
    };
    return candidate.copyWith(
      provider: supported.id,
      providerSettings: providerSettings,
    );
  }

  String? _providerSettingsBlockReason(ProviderDescriptor descriptor) {
    final reason = descriptor.providerSettingsSupportError;
    if (reason == null) {
      return null;
    }
    return _copy.mobileProviderSettingsRuntimeUnsupported(
      providerName: descriptor.displayName,
      error: reason,
    );
  }

  String? _managedProviderDraftBlockReason(ManagedProviderDraft provider) {
    final supported = supportedProviderDefinitionFor(provider.provider);
    if (supported == null) {
      return _copy.selectedManagedProviderNotInSupportedCatalog;
    }
    final descriptor = descriptorForProvider(provider.provider);
    if (descriptor == null) {
      return null;
    }
    final schemaReason = descriptor.providerSettingsSupportError;
    if (schemaReason != null && provider.providerSettings.isNotEmpty) {
      return _copy.mobileReusableSettingsRuntimeUnsupported(
        providerName: descriptor.displayName,
        error: schemaReason,
      );
    }
    return null;
  }

  String? _providerTemplateDraftBlockReason(ProviderTemplateDraft template) {
    final supported = supportedProviderDefinitionFor(template.provider);
    if (supported == null) {
      return _copy.selectedTemplateFamilyNotInSupportedCatalog;
    }
    final descriptor = descriptorForProvider(template.provider);
    if (descriptor == null) {
      return null;
    }
    final schemaReason = descriptor.providerSettingsSupportError;
    if (schemaReason != null && template.providerSettings.isNotEmpty) {
      return _copy.mobileTemplateRuntimeUnsupported(
        providerName: descriptor.displayName,
        error: schemaReason,
      );
    }
    return null;
  }

  List<ManagedProviderRecord> _overlayManagedProviders(
    List<ManagedProviderRecord> providers,
  ) {
    return providers
        .map((ManagedProviderRecord provider) {
          final supported = supportedProviderDefinitionFor(provider.provider);
          if (supported == null) {
            return provider.copyWith(
              availability: ProviderConfigAvailability(
                state: ProviderConfigAvailabilityState.providerUnavailable,
                message: _copy.managedProviderNotInSupportedCatalog,
              ),
            );
          }
          final descriptor = descriptorForProvider(provider.provider);
          if (descriptor == null) {
            return provider.copyWith(
              availability: ProviderConfigAvailability(
                state: ProviderConfigAvailabilityState.providerUnavailable,
                message: _copy.connectedHostDoesNotAdvertiseProviderFamilyYet(
                  supported.title,
                ),
              ),
            );
          }
          final schemaReason = descriptor.providerSettingsSupportError;
          if (schemaReason != null && provider.providerSettings.isNotEmpty) {
            return provider.copyWith(
              availability: ProviderConfigAvailability(
                state: ProviderConfigAvailabilityState.schemaUnsupported,
                message: _copy.mobileReusableSettingsRuntimeUnsupported(
                  providerName: descriptor.displayName,
                  error: schemaReason,
                ),
              ),
            );
          }
          return provider.copyWith(
            availability: const ProviderConfigAvailability(),
          );
        })
        .toList(growable: false);
  }

  List<ProviderTemplateRecord> _overlayProviderTemplates(
    List<ProviderTemplateRecord> templates,
  ) {
    return templates
        .map((ProviderTemplateRecord template) {
          final supported = supportedProviderDefinitionFor(template.provider);
          if (supported == null) {
            return template.copyWith(
              availability: ProviderConfigAvailability(
                state: ProviderConfigAvailabilityState.providerUnavailable,
                message: _copy.templateNotInSupportedCatalog,
              ),
            );
          }
          final descriptor = descriptorForProvider(template.provider);
          if (descriptor == null) {
            return template.copyWith(
              availability: ProviderConfigAvailability(
                state: ProviderConfigAvailabilityState.providerUnavailable,
                message: _copy.connectedHostDoesNotAdvertiseProviderFamilyYet(
                  supported.title,
                ),
              ),
            );
          }
          final schemaReason = descriptor.providerSettingsSupportError;
          if (schemaReason != null && template.providerSettings.isNotEmpty) {
            return template.copyWith(
              availability: ProviderConfigAvailability(
                state: ProviderConfigAvailabilityState.schemaUnsupported,
                message: _copy.mobileTemplateRuntimeUnsupported(
                  providerName: descriptor.displayName,
                  error: schemaReason,
                ),
              ),
            );
          }
          return template.copyWith(
            availability: const ProviderConfigAvailability(),
          );
        })
        .toList(growable: false);
  }

  void _normalizeSelectedPlatformTunnelMode() {
    final resolvedMode = activePlatformTunnelMode;
    if (resolvedMode == null) {
      if (selectedPlatformTunnelMode != null) {
        selectedPlatformTunnelMode = null;
        _scheduleStatePersist();
      }
      return;
    }
    final changed = selectedPlatformTunnelMode != resolvedMode;
    selectedPlatformTunnelMode = resolvedMode;
    _storeModePreferences(resolvedMode, modePreferencesFor(resolvedMode));
    if (changed) {
      _scheduleStatePersist();
    }
  }

  String _platformModePreferenceScope() {
    final selected = currentProfileId?.trim() ?? '';
    return selected.isEmpty ? _draftModePreferenceScope : selected;
  }

  String _platformModePreferenceKey(PlatformTunnelMode mode, {String? scope}) {
    final candidate = (scope ?? _platformModePreferenceScope()).trim();
    final normalizedScope = candidate.isEmpty
        ? _draftModePreferenceScope
        : candidate;
    return '$normalizedScope::${mode.value}';
  }

  void _storeModePreferences(
    PlatformTunnelMode mode,
    MobilePlatformModePreferences next, {
    bool notify = false,
  }) {
    final key = _platformModePreferenceKey(mode);
    final normalized = _normalizePlatformModePreferences(mode, next);
    final current = platformModePreferences[key];
    if (current != null && _sameModePreferences(current, normalized)) {
      return;
    }
    platformModePreferences = <String, MobilePlatformModePreferences>{
      ...platformModePreferences,
      key: normalized,
    };
    _scheduleStatePersist();
    if (notify) {
      _notify();
    }
  }

  void _normalizeProfileSelectionState() {
    final normalizedCurrent = currentProfileId?.trim() ?? '';
    if (normalizedCurrent.isNotEmpty &&
        _profileById(normalizedCurrent) == null) {
      currentProfileId = null;
    }
    final normalizedFocused = focusedProfileId?.trim() ?? '';
    if (normalizedFocused.isNotEmpty &&
        _profileById(normalizedFocused) == null) {
      focusedProfileId = null;
      if (workflowSurface == MobileWorkflowSurface.profile &&
          (draft.id?.trim() ?? '').isNotEmpty) {
        draft = _defaultDraft();
      }
    }
  }

  String _duplicatedLabel(String sourceLabel) {
    final trimmed = sourceLabel.trim();
    if (trimmed.isEmpty) {
      return _copy.duplicatedItemFallbackLabel;
    }
    return _copy.duplicatedItemLabel(trimmed);
  }

  MobilePlatformModePreferences _normalizePlatformModePreferences(
    PlatformTunnelMode mode,
    MobilePlatformModePreferences? current,
  ) {
    final resolvedExecutionPlan = _resolveStoredExecutionPlan(
      mode,
      current?.executionPlan,
    );
    final allowedPackages = _normalizePackageNames(current?.allowedPackages);
    final disallowedPackages = _normalizePackageNames(
      current?.disallowedPackages,
    );
    if (!_modeSupportsAppRouting(mode)) {
      return MobilePlatformModePreferences(
        executionPlan: resolvedExecutionPlan,
        applicationRoutingPolicy:
            PlatformTunnelApplicationRoutingPolicy.allApps,
        underlayRoutePolicy: PlatformTunnelUnderlayRoutePolicy.standard,
      );
    }
    return MobilePlatformModePreferences(
      executionPlan: resolvedExecutionPlan,
      applicationRoutingPolicy:
          current?.applicationRoutingPolicy ??
          PlatformTunnelApplicationRoutingPolicy.allApps,
      underlayRoutePolicy:
          current?.underlayRoutePolicy ??
          PlatformTunnelUnderlayRoutePolicy.standard,
      allowedPackages: allowedPackages,
      disallowedPackages: disallowedPackages,
    );
  }

  RuntimeExecutionPlan? _resolveStoredExecutionPlan(
    PlatformTunnelMode mode,
    RuntimeExecutionPlan? current,
  ) {
    if (current != null) {
      for (final descriptor in executionPlanOptionsForMode(mode)) {
        if (_sameExecutionPlan(descriptor.plan, current)) {
          return current;
        }
      }
    }
    return _defaultExecutionPlanForMode(mode);
  }

  RuntimeExecutionPlan? _defaultExecutionPlanForMode(PlatformTunnelMode mode) {
    final options = executionPlanOptionsForMode(mode);
    for (final descriptor in options) {
      if (descriptor.isDefault) {
        return descriptor.plan;
      }
    }
    if (options.length == 1) {
      return options.first.plan;
    }
    return null;
  }

  RuntimeExecutionPlan? _resolvedExecutionPlanForMode(PlatformTunnelMode mode) {
    return modePreferencesFor(mode).executionPlan;
  }

  bool get _hostSupportsTransportProfileStore {
    final info = hostConnection?.info;
    if (info == null) {
      return false;
    }
    return info.capabilities.contains(Capability.vpnTransportProfileStore) &&
        info.transportProfileStore != null;
  }

  RuntimeExecutionPlanDescriptor?
  _transportProfileExecutionPlanDescriptorForMode(
    PlatformTunnelMode mode, {
    RuntimeExecutionPlan? plan,
  }) {
    final capability = capabilityForMode(mode);
    if (capability == null) {
      return null;
    }
    final selectedPlan = plan ?? _resolvedExecutionPlanForMode(mode);
    if (selectedPlan != null) {
      for (final descriptor in capability.executionPlans) {
        if (_sameExecutionPlan(descriptor.plan, selectedPlan) &&
            descriptor.transportProfile != null) {
          return descriptor;
        }
      }
    }
    for (final descriptor in capability.executionPlans) {
      if (descriptor.transportProfile != null && descriptor.isDefault) {
        return descriptor;
      }
    }
    for (final descriptor in capability.executionPlans) {
      if (descriptor.transportProfile != null) {
        return descriptor;
      }
    }
    return null;
  }

  TransportProfilePrerequisiteStatus? _transportProfilePrerequisiteForMode(
    PlatformTunnelMode mode, {
    RuntimeExecutionPlan? plan,
  }) {
    return _transportProfileExecutionPlanDescriptorForMode(
      mode,
      plan: plan,
    )?.transportProfile;
  }

  String? _transportProfileBlockReasonForMode(
    PlatformTunnelMode mode, {
    RuntimeExecutionPlan? plan,
  }) {
    final prerequisite = _transportProfilePrerequisiteForMode(mode, plan: plan);
    if (prerequisite == null || prerequisite.isCompatible) {
      return null;
    }
    final hostMessage = prerequisite.message.trim();
    if (hostMessage.isNotEmpty &&
        prerequisite.missingKind != null &&
        !_hostSupportsTransportProfileStore) {
      return hostMessage;
    }
    return _copy.vpnTransportProfileRequiredBeforeStarting;
  }

  TransportProfileImportAdapter? _activeTransportProfileImportAdapter() {
    final mode = activePlatformTunnelMode;
    if (mode == null) {
      return null;
    }
    return _transportProfileImportAdapterForMode(mode);
  }

  TransportProfileImportAdapter? _transportProfileImportAdapterForMode(
    PlatformTunnelMode mode,
  ) {
    final capability = hostConnection?.info?.transportProfileStore;
    if (capability == null || capability.importAdapters.isEmpty) {
      return null;
    }
    final prerequisite = _transportProfilePrerequisiteForMode(mode);
    final requiredKinds =
        prerequisite?.requiredKinds ??
        _transportProfileExecutionPlanDescriptorForMode(
          mode,
        )?.requiredTransportProfileKinds ??
        const <TransportProfileKind>[];
    final allowedAdapters =
        prerequisite?.importAdapters ?? const <TransportProfileImportAdapter>[];
    for (final descriptor in capability.importAdapters) {
      if (allowedAdapters.isNotEmpty &&
          !allowedAdapters.contains(descriptor.id)) {
        continue;
      }
      if (!_transportProfileImportAdapterSupportedForKinds(
        descriptor,
        requiredKinds,
      )) {
        continue;
      }
      return descriptor.id;
    }
    return null;
  }

  bool _transportProfileImportAdapterSupportedForKinds(
    TransportProfileImportAdapterDescriptor descriptor,
    List<TransportProfileKind> requiredKinds,
  ) {
    if (requiredKinds.isNotEmpty &&
        !requiredKinds.contains(descriptor.profileKind)) {
      return false;
    }
    return descriptor.materialAcquisitionMethod?.canAcquireInShell == true;
  }

  TransportProfileKind? _profileKindForImportAdapter(
    TransportProfileImportAdapter adapter,
  ) {
    final capability = hostConnection?.info?.transportProfileStore;
    if (capability == null) {
      return null;
    }
    for (final descriptor in capability.importAdapters) {
      if (descriptor.id == adapter) {
        return descriptor.profileKind;
      }
    }
    return null;
  }

  TransportProfileReference? _transportProfileReferenceForPlan(
    PlatformTunnelMode mode,
    RuntimeExecutionPlan plan,
  ) {
    final prerequisite = _transportProfilePrerequisiteForMode(mode, plan: plan);
    if (prerequisite == null || !prerequisite.isCompatible) {
      return null;
    }
    return prerequisite.selectedProfile ?? prerequisite.defaultProfile;
  }

  TransportProfileStatus? _transportProfileById(String rawProfileId) {
    final profileId = rawProfileId.trim();
    if (profileId.isEmpty) {
      return null;
    }
    for (final profile in transportProfiles) {
      if (profile.id == profileId) {
        return profile;
      }
    }
    return null;
  }

  TransportProfileKind? _firstTransportProfileKind(
    List<TransportProfileKind>? kinds,
  ) {
    if (kinds == null || kinds.isEmpty) {
      return null;
    }
    return kinds.first;
  }

  String _transportProfileKindLabel(TransportProfileKind kind) {
    if (kind == TransportProfileKind.wireGuardNativeV1) {
      return 'WireGuard';
    }
    return kind.value;
  }

  String? _platformTunnelRuntimeDefaultsBlockReason({
    required PlatformTunnelMode mode,
    required RuntimeExecutionPlan executionPlan,
    required RuntimeDefaults runtimeDefaults,
  }) {
    if (!_requiresRemoteWireGuardPeerEndpoint(mode, executionPlan)) {
      return null;
    }
    final peerAddress = runtimeDefaults.peerAddress.trim();
    if (!_isLoopbackEndpoint(peerAddress)) {
      return null;
    }
    return _copy.loopbackPeerBlockReason(mode.label, peerAddress);
  }

  bool _requiresRemoteWireGuardPeerEndpoint(
    PlatformTunnelMode mode,
    RuntimeExecutionPlan executionPlan,
  ) {
    return mode == PlatformTunnelMode.androidVpnService &&
        executionPlan.accessMethod == RuntimeAccessMethod.turnCredentials &&
        executionPlan.carrierFamily == RuntimeCarrierFamily.turnDatagram &&
        executionPlan.engineFamily == RuntimeEngineFamily.wireguardNative &&
        executionPlan.hostAdapter == RuntimeHostAdapter.androidVpnService;
  }

  bool _isLoopbackEndpoint(String endpoint) {
    final host = _endpointHost(endpoint);
    if (host == null) {
      return false;
    }
    if (host.toLowerCase() == 'localhost') {
      return true;
    }
    final address = InternetAddress.tryParse(host);
    return address?.isLoopback ?? false;
  }

  String? _endpointHost(String endpoint) {
    final trimmed = endpoint.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.startsWith('[')) {
      final closingBracket = trimmed.indexOf(']');
      if (closingBracket <= 1) {
        return null;
      }
      return trimmed.substring(1, closingBracket);
    }
    final separator = trimmed.lastIndexOf(':');
    if (separator <= 0) {
      return trimmed;
    }
    return trimmed.substring(0, separator);
  }

  PlatformTunnelApplicationRoutingPolicy _effectiveRoutingPolicyForMode(
    PlatformTunnelMode mode,
    MobilePlatformModePreferences preferences,
  ) {
    if (!_modeSupportsAppRouting(mode)) {
      return PlatformTunnelApplicationRoutingPolicy.allApps;
    }
    return preferences.applicationRoutingPolicy;
  }

  List<String> _effectiveAllowedPackagesForMode(
    PlatformTunnelMode mode,
    MobilePlatformModePreferences preferences,
  ) {
    if (_effectiveRoutingPolicyForMode(mode, preferences) !=
        PlatformTunnelApplicationRoutingPolicy.allowedPackages) {
      return const <String>[];
    }
    return _normalizePackageNames(preferences.allowedPackages);
  }

  List<String> _effectiveDisallowedPackagesForMode(
    PlatformTunnelMode mode,
    MobilePlatformModePreferences preferences,
  ) {
    if (_effectiveRoutingPolicyForMode(mode, preferences) !=
        PlatformTunnelApplicationRoutingPolicy.disallowedPackages) {
      return const <String>[];
    }
    return _normalizePackageNames(preferences.disallowedPackages);
  }

  PlatformTunnelUnderlayRoutePolicy _requestedUnderlayRoutePolicyForMode(
    PlatformTunnelMode mode,
    MobilePlatformModePreferences preferences,
  ) {
    if (!_modeSupportsAppRouting(mode)) {
      return PlatformTunnelUnderlayRoutePolicy.standard;
    }
    return preferences.underlayRoutePolicy;
  }

  PlatformTunnelUnderlayRoutePolicy _startedUnderlayRoutePolicyForMode(
    PlatformTunnelMode mode,
    PlatformTunnelStartResult? result,
  ) {
    if (!_modeSupportsAppRouting(mode)) {
      return PlatformTunnelUnderlayRoutePolicy.standard;
    }
    return result?.underlayRoutePolicy ??
        PlatformTunnelUnderlayRoutePolicy.standard;
  }

  String? _routingSelectionBlockReason(
    PlatformTunnelMode mode,
    MobilePlatformModePreferences preferences,
  ) {
    switch (_effectiveRoutingPolicyForMode(mode, preferences)) {
      case PlatformTunnelApplicationRoutingPolicy.allApps:
        return null;
      case PlatformTunnelApplicationRoutingPolicy.allowedPackages:
        return _effectiveAllowedPackagesForMode(mode, preferences).isEmpty
            ? _copy.selectAtLeastOneIncludedApp(mode.label)
            : null;
      case PlatformTunnelApplicationRoutingPolicy.disallowedPackages:
        return _effectiveDisallowedPackagesForMode(mode, preferences).isEmpty
            ? _copy.selectAtLeastOneExcludedApp(mode.label)
            : null;
    }
  }

  String? _underlayRoutePolicySelectionBlockReason(
    PlatformTunnelMode mode,
    MobilePlatformModePreferences preferences,
  ) {
    final policy = _requestedUnderlayRoutePolicyForMode(mode, preferences);
    if (_modeSupportsUnderlayRoutePolicy(mode, policy)) {
      return null;
    }
    return _copy.developmentWifiRoutingUnavailableForHost(mode.label);
  }

  String _executionPlanSelectionRequiredMessage(PlatformTunnelMode mode) {
    final capability = capabilityForMode(mode);
    if (capability == null) {
      return _copy.selectedMobileModeNotAdvertisedByConnectedHost;
    }
    if (executionPlanOptionsForMode(mode).isEmpty) {
      final hostMessage = capability.message.trim();
      if (hostMessage.isNotEmpty) {
        return hostMessage;
      }
      return _copy.modeDoesNotAdvertiseSupportedExecutionPath(mode.label);
    }
    return _copy.selectExecutionPathBeforeStarting(mode.label);
  }

  void _moveModePreferences({
    required String fromScope,
    required String toScope,
  }) {
    final normalizedFrom = fromScope.trim();
    final normalizedTo = toScope.trim();
    if (normalizedFrom.isEmpty ||
        normalizedTo.isEmpty ||
        normalizedFrom == normalizedTo) {
      return;
    }
    final prefix = '$normalizedFrom::';
    final next = <String, MobilePlatformModePreferences>{
      ...platformModePreferences,
    };
    var changed = false;
    for (final entry in platformModePreferences.entries) {
      if (!entry.key.startsWith(prefix)) {
        continue;
      }
      final modeSuffix = entry.key.substring(prefix.length);
      next.remove(entry.key);
      next['$normalizedTo::$modeSuffix'] = entry.value;
      changed = true;
    }
    if (!changed) {
      return;
    }
    platformModePreferences = next;
    _scheduleStatePersist();
  }

  void _dropModePreferencesForScope(String scope) {
    final normalized = scope.trim();
    if (normalized.isEmpty) {
      return;
    }
    final prefix = '$normalized::';
    final next = <String, MobilePlatformModePreferences>{
      for (final entry in platformModePreferences.entries)
        if (!entry.key.startsWith(prefix)) entry.key: entry.value,
    };
    if (next.length == platformModePreferences.length) {
      return;
    }
    platformModePreferences = next;
    _scheduleStatePersist();
  }

  bool _sameModePreferences(
    MobilePlatformModePreferences left,
    MobilePlatformModePreferences right,
  ) {
    return _sameExecutionPlan(left.executionPlan, right.executionPlan) &&
        left.applicationRoutingPolicy == right.applicationRoutingPolicy &&
        left.underlayRoutePolicy == right.underlayRoutePolicy &&
        _sameStringLists(left.allowedPackages, right.allowedPackages) &&
        _sameStringLists(left.disallowedPackages, right.disallowedPackages);
  }

  bool _sameExecutionPlan(
    RuntimeExecutionPlan? left,
    RuntimeExecutionPlan? right,
  ) {
    if (left == null || right == null) {
      return left == right;
    }
    return left.accessMethod == right.accessMethod &&
        left.carrierFamily == right.carrierFamily &&
        left.engineFamily == right.engineFamily &&
        left.hostAdapter == right.hostAdapter;
  }

  bool _sameStringLists(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  bool _modeSupportsAppRouting(PlatformTunnelMode? mode) {
    return mode == PlatformTunnelMode.androidVpnService;
  }

  bool _modeSupportsUnderlayRoutePolicy(
    PlatformTunnelMode? mode,
    PlatformTunnelUnderlayRoutePolicy policy,
  ) {
    if (policy == PlatformTunnelUnderlayRoutePolicy.standard) {
      return true;
    }
    final capability = capabilityForMode(mode);
    if (capability == null) {
      return false;
    }
    return capability.supportedUnderlayRoutePolicies.contains(policy);
  }

  String _underlayRoutePolicyLabel(PlatformTunnelUnderlayRoutePolicy policy) {
    return switch (policy) {
      PlatformTunnelUnderlayRoutePolicy.standard =>
        _copy.routingProfileStandard,
      PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork =>
        _copy.routingProfileDevelopmentWifi,
    };
  }

  void _clearSelectedResolutionSelection() {
    selectedResolutionId = null;
  }

  void _clearSelectedReusableResolutionSelection() {
    final selected = _selectedResolutionRecord();
    if (selected?.state == ResolutionState.resolved) {
      selectedResolutionId = null;
    }
  }

  void _notify() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }
}

int _managedProviderNameSort(
  ManagedProviderRecord left,
  ManagedProviderRecord right,
) {
  final leftLabel = left.name.isEmpty ? left.id : left.name;
  final rightLabel = right.name.isEmpty ? right.id : right.name;
  return leftLabel.toLowerCase().compareTo(rightLabel.toLowerCase());
}

int _providerTemplateNameSort(
  ProviderTemplateRecord left,
  ProviderTemplateRecord right,
) {
  final leftLabel = left.name.isEmpty ? left.id : left.name;
  final rightLabel = right.name.isEmpty ? right.id : right.name;
  return leftLabel.toLowerCase().compareTo(rightLabel.toLowerCase());
}

Map<String, ProfileProviderBinding> _dropManagedProviderBindings(
  String managedProviderId,
  Map<String, ProfileProviderBinding> bindings,
) {
  final next = <String, ProfileProviderBinding>{};
  for (final entry in bindings.entries) {
    final binding = entry.value;
    if (binding.managedProviderId == managedProviderId) {
      next[entry.key] = const ProfileProviderBinding(
        mode: ProfileProviderMode.custom,
      );
      continue;
    }
    next[entry.key] = binding;
  }
  return next;
}

List<String> _normalizePackageNames(Iterable<String>? values) {
  final normalized = (values ?? const <String>[])
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .toSet()
      .toList(growable: false);
  normalized.sort();
  return normalized;
}

List<String> _togglePackage(
  List<String> current,
  String packageName,
  bool selected,
) {
  return _togglePackages(current, <String>[packageName], selected);
}

List<String> _togglePackages(
  List<String> current,
  Iterable<String> packageNames,
  bool selected,
) {
  final next = current.toSet();
  final normalizedPackages = _normalizePackageNames(packageNames);
  if (selected) {
    next.addAll(normalizedPackages);
  } else {
    next.removeAll(normalizedPackages);
  }
  final sorted = next.toList(growable: false);
  sorted.sort();
  return sorted;
}

Future<Directory> defaultDiagnosticsDirectory() async {
  final root = await getApplicationDocumentsDirectory();
  return Directory(_join(<String>[root.path, 'diagnostics']));
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

String _formatNoticeTimestamp(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)} '
      '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}:${_twoDigits(local.second)}';
}

String _portableProfileSuggestedFilename(PortableProfileEnvelope envelope) {
  final rawName = envelope.displayName.trim();
  final slug = rawName.isEmpty
      ? 'profile'
      : rawName
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'^-+|-+$'), '');
  final safeSlug = slug.isEmpty ? 'profile' : slug;
  return '$safeSlug.portable-profile.json';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
