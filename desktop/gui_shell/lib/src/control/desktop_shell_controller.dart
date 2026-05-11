import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter_shell_core/portable_profile_transfer.dart';
import 'package:flutter_shell_core/transport_profile_portable_transfer.dart';
import 'package:flutter/foundation.dart';
import 'package:gui_shell/src/build/app_build_identity.dart';
import 'package:gui_shell/src/control/control_plane_client.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/desktop_handoff_adapter.dart';
import 'package:gui_shell/src/control/desktop_host_supervisor.dart';
import 'package:gui_shell/src/control/desktop_portable_profile_transfer_adapter.dart';
import 'package:gui_shell/src/control/profile_draft.dart';
import 'package:gui_shell/src/control/shell_state_store.dart';

typedef DirectoryProvider = Future<Directory> Function();
typedef VPNTransportProfileContentPicker = Future<String?> Function();

enum ShellStatus { booting, ready, blocked }

enum DesktopWorkspaceSurface { profile, providerConfig, provider }

enum DesktopShellSection { profileWorkflow, providerWorkflow }

enum DesktopWorkbenchRoute {
  home,
  profiles,
  providers,
  routing,
  vpnTransportProfiles,
  activity,
  diagnostics,
  settings,
}

enum DesktopCanvasRoute {
  profileEditor,
  savedProfilePicker,
  managedProviderPickerForProfile,
  managedProviderEditor,
  managedProviderPicker,
  presetPicker,
  providerFamilyPicker,
}

enum DesktopInspectorPane { diagnostics, activity }

abstract class BrowserLauncher {
  Future<bool> open(String url);
}

class DesktopBrowserLauncher implements BrowserLauncher {
  const DesktopBrowserLauncher();

  @override
  Future<bool> open(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme.isEmpty) {
      return false;
    }

    late final ProcessResult result;
    if (Platform.isWindows) {
      result = await Process.run('cmd', <String>['/c', 'start', '', trimmed]);
    } else if (Platform.isMacOS) {
      result = await Process.run('open', <String>[trimmed]);
    } else {
      result = await Process.run('xdg-open', <String>[trimmed]);
    }
    return result.exitCode == 0;
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

class DesktopShellController extends ChangeNotifier {
  DesktopShellController({
    required this.api,
    required this.supervisor,
    DesktopShellStateStore? stateStore,
    DirectoryProvider? diagnosticsDirectoryProvider,
    BrowserLauncher? browserLauncher,
    DesktopHandoffAdapter? handoffAdapter,
    DesktopPortableProfileTransferAdapter? portableProfileTransferAdapter,
    VPNTransportProfileContentPicker? transportProfileContentPicker,
    DateTime Function()? clock,
    BuildIdentity? appBuild,
  }) : _diagnosticsDirectoryProvider =
           diagnosticsDirectoryProvider ?? _defaultDiagnosticsDirectory,
       _browserLauncher = browserLauncher ?? const DesktopBrowserLauncher(),
       _handoffAdapter =
           handoffAdapter ?? const ClipboardDesktopHandoffAdapter(),
       _portableProfileTransferAdapter =
           portableProfileTransferAdapter ??
           const SystemDesktopPortableProfileTransferAdapter(),
       _transportProfileContentPicker =
           transportProfileContentPicker ?? _pickVPNTransportProfileContents,
       _stateStore = stateStore ?? FileDesktopShellStateStore(),
       _clock = clock ?? DateTime.now,
       appBuild = appBuild ?? AppBuildIdentity.current;

  final ControlPlaneApi api;
  final HostSupervisor supervisor;
  final DirectoryProvider _diagnosticsDirectoryProvider;
  final BrowserLauncher _browserLauncher;
  final DesktopHandoffAdapter _handoffAdapter;
  final DesktopPortableProfileTransferAdapter _portableProfileTransferAdapter;
  final VPNTransportProfileContentPicker _transportProfileContentPicker;
  final DesktopShellStateStore _stateStore;
  final DateTime Function() _clock;
  final BuildIdentity appBuild;
  final ValueNotifier<int> shellChromeRevision = ValueNotifier<int>(0);
  final ValueNotifier<int> workflowRevision = ValueNotifier<int>(0);
  final ValueNotifier<int> inspectorLayoutRevision = ValueNotifier<int>(0);
  final ValueNotifier<int> inspectorRevision = ValueNotifier<int>(0);

  ShellStatus status = ShellStatus.booting;
  HostConnectionResult? hostConnection;
  List<ProviderDescriptor> providerDescriptors = const <ProviderDescriptor>[];
  List<RemoteProviderSourceDescriptor> providerSources =
      const <RemoteProviderSourceDescriptor>[];
  List<ManagedProviderRecord> managedProviders =
      const <ManagedProviderRecord>[];
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
  DesktopShellSection activeSection = DesktopShellSection.profileWorkflow;
  DesktopWorkbenchRoute activeWorkbenchRoute = DesktopWorkbenchRoute.home;
  DesktopCanvasRoute activeCanvasRoute = DesktopCanvasRoute.profileEditor;
  DesktopInspectorPane activeInspectorPane = DesktopInspectorPane.diagnostics;
  bool isInspectorOpen = false;
  RuntimeDefaults materializeDefaults = const RuntimeDefaults(
    listenAddress: '127.0.0.1:9001',
    peerAddress: '127.0.0.1:56000',
  );
  String? selectedProfileId;
  String? selectedManagedProviderId;
  String? selectedResolutionId;
  String? selectedSessionId;
  Map<String, ProfileProviderBinding> profileBindings =
      <String, ProfileProviderBinding>{};
  final Map<PlatformTunnelMode, PlatformTunnelStartResult>
  _platformTunnelResults = <PlatformTunnelMode, PlatformTunnelStartResult>{};
  final Map<PlatformTunnelMode, ProviderTransportCompatibilityCandidate>
  _providerTransportCompatibilityCandidates =
      <PlatformTunnelMode, ProviderTransportCompatibilityCandidate>{};
  final Set<PlatformTunnelMode> _platformTunnelStartsInFlight =
      <PlatformTunnelMode>{};
  PlatformTunnelMode? _pendingPlatformTunnelStartMode;
  String? _pendingPlatformTunnelStartResolutionId;
  String? notice;
  bool busy = false;

  final Map<String, ChallengeRecord> _challengeCache =
      <String, ChallengeRecord>{};
  StreamSubscription<EventRecord>? _eventSubscription;
  Timer? _pollTimer;
  Timer? _debounceTimer;
  Timer? _persistTimer;
  bool _recoveringHost = false;
  bool _disposed = false;
  bool _shuttingDown = false;
  bool _suppressEventStreamClosure = false;
  int _portableImportNonce = 0;
  String? _persistedStateSignature;
  bool _restoredState = false;
  Future<void>? _shutdownFuture;
  String? localeOverrideTag;
  Object? _restoreStateError;

  List<PlatformTunnelCapability> get platformTunnels =>
      hostConnection?.info?.platformTunnels ??
      const <PlatformTunnelCapability>[];

  bool get hostSupportsTransportProfileStore {
    final info = hostConnection?.info;
    if (info == null) {
      return false;
    }
    return info.capabilities.contains(Capability.vpnTransportProfileStore) &&
        info.transportProfileStore != null;
  }

  bool get hostSupportsProviderTransportCompatibility {
    final info = hostConnection?.info;
    if (info == null) {
      return false;
    }
    return info.capabilities.contains(
          Capability.providerTransportCompatibility,
        ) &&
        info.providerTransportCompatibility != null;
  }

  bool get hostSupportsConferenceRoomActions {
    final info = hostConnection?.info;
    if (info == null) {
      return false;
    }
    return info.capabilities.contains(Capability.conferenceRoomActions) &&
        (info.conferenceRoomActions?.supportsOpenRoom ?? false);
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

  bool platformTunnelStartInFlight(PlatformTunnelMode mode) {
    return _platformTunnelStartsInFlight.contains(mode);
  }

  ProviderTransportCompatibilityCandidate?
  providerTransportCompatibilityCandidateForMode(PlatformTunnelMode mode) {
    return _providerTransportCompatibilityCandidates[mode];
  }

  String? providerTransportCompatibilitySummaryForMode(
    PlatformTunnelMode mode,
  ) {
    final candidate = providerTransportCompatibilityCandidateForMode(mode);
    if (candidate == null) {
      return null;
    }
    return _providerTransportCompatibilityMessage(
      candidate,
      prefix: 'Provider/transport compatibility',
    );
  }

  bool platformTunnelModeRequiresVPNTransportProfile(PlatformTunnelMode mode) {
    return _transportProfilePrerequisiteForMode(mode) != null;
  }

  bool canConfigureVPNTransportProfileForMode(PlatformTunnelMode mode) {
    return hostSupportsTransportProfileStore &&
        platformTunnelModeRequiresVPNTransportProfile(mode) &&
        _transportProfileImportAdapterForMode(mode) != null;
  }

  TransportProfilePortableTransferCapability?
  get portableTransportProfileTransferCapability =>
      hostConnection?.info?.transportProfileStore?.portableTransfer;

  bool canImportPortableVPNTransportProfileForMode(PlatformTunnelMode mode) {
    final capability = portableTransportProfileTransferCapability;
    if (!hostSupportsTransportProfileStore ||
        capability == null ||
        capability.importPaths.isEmpty) {
      return false;
    }
    final requiredKinds = vpnTransportProfileRequiredKindsForMode(mode);
    return _portableTransferSupportsAnyKind(capability, requiredKinds);
  }

  bool canExportPortableVPNTransportProfileRecord(
    TransportProfileStatus profile,
  ) {
    final capability = portableTransportProfileTransferCapability;
    return capability != null &&
        capability.exportPaths.isNotEmpty &&
        profile.actions.contains(
          TransportProfileLifecycleAction.exportPortable,
        ) &&
        _portableTransferSupportsKind(capability, profile.kind);
  }

  bool canEditVPNTransportProfileForMode(PlatformTunnelMode mode) {
    final schema = vpnTransportProfileEditorSchemaForMode(mode);
    if (schema == null) {
      return false;
    }
    final configured = activeVPNTransportProfileConfiguredForMode(mode);
    return configured
        ? schema.supportsStructuredUpdate
        : schema.supportsStructuredCreate;
  }

  TransportProfileEditableKindSchema? vpnTransportProfileEditorSchemaForMode(
    PlatformTunnelMode mode,
  ) {
    final descriptor = _transportProfileExecutionPlanDescriptorForMode(mode);
    final prerequisite = descriptor?.transportProfile;
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

  RuntimeExecutionPlan? vpnTransportProfileExecutionPlanForMode(
    PlatformTunnelMode mode,
  ) {
    return _transportProfileExecutionPlanDescriptorForMode(mode)?.plan;
  }

  bool activeVPNTransportProfileConfiguredForMode(PlatformTunnelMode mode) {
    return vpnTransportProfileStatusForMode(mode) != null;
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

  String? platformTunnelStartPreparationBlockReason(PlatformTunnelMode mode) {
    final executionPlan = _defaultPlatformTunnelExecutionPlan(
      _platformTunnelCapabilityFor(mode),
    );
    if (executionPlan == null) {
      final transportProfileBlockReason = _transportProfileBlockReasonForMode(
        mode,
      );
      if (transportProfileBlockReason != null) {
        return transportProfileBlockReason;
      }
      return null;
    }
    final transportProfileBlockReason = _transportProfileBlockReasonForMode(
      mode,
      plan: executionPlan,
    );
    if (transportProfileBlockReason != null) {
      return transportProfileBlockReason;
    }
    return _providerTransportCompatibilityBlockReasonForMode(mode);
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

  DesktopWorkspaceSurface get workspaceSurface => switch (activeCanvasRoute) {
    DesktopCanvasRoute.profileEditor ||
    DesktopCanvasRoute.savedProfilePicker ||
    DesktopCanvasRoute.managedProviderPickerForProfile =>
      DesktopWorkspaceSurface.profile,
    DesktopCanvasRoute.managedProviderEditor ||
    DesktopCanvasRoute.managedProviderPicker ||
    DesktopCanvasRoute.presetPicker ||
    DesktopCanvasRoute.providerFamilyPicker =>
      DesktopWorkspaceSurface.providerConfig,
  };

  DesktopCanvasRoute? _canvasRouteReturnTarget;

  DesktopCanvasRoute? get canvasRouteReturnTarget => _canvasRouteReturnTarget;

  bool get canReturnFromCanvasRoute =>
      _canvasRouteReturnTarget != null &&
      activeCanvasRoute != _canvasRouteReturnTarget;

  bool get hasLiveWork => resolutions.isNotEmpty || sessions.isNotEmpty;

  String? get hostStatusMessage {
    final message = hostConnection?.message.trim() ?? '';
    return message.isEmpty ? null : message;
  }

  AppLocale get activeLocale => LocaleSettings.currentLocale;
  ShellText get _copy => currentShellText;

  bool get usesSystemLocale => localeOverrideTag == null;

  Future<void> selectLocaleOverride(String? rawLocale) async {
    final previousHostMessage = hostStatusMessage;
    final locale = parseShellLocale(rawLocale);
    localeOverrideTag = locale == null ? null : shellLocaleTag(locale);
    await restoreShellLocale(localeOverrideTag);
    _scheduleStatePersist();
    if (_restoreStateError != null) {
      notice = _copy.failedToRestoreDesktopShellState(_restoreStateError!);
    }
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
    if (hostConnection != null || status != ShellStatus.booting) {
      await reconnect();
      return;
    }
    _notify();
  }

  ProviderConfigDraft get providerConfigDraft =>
      ProviderConfigDraft.fromJson(managedProviderDraft.toJson());

  String? get selectedProviderConfigId => selectedManagedProviderId;

  ProviderDescriptor? get activeProviderConfigDescriptor =>
      activeManagedProviderDescriptor;

  bool get showsSupportRoute =>
      activeWorkbenchRoute == DesktopWorkbenchRoute.activity ||
      activeWorkbenchRoute == DesktopWorkbenchRoute.diagnostics;

  void showHome() {
    _showWorkbenchRoute(DesktopWorkbenchRoute.home);
  }

  void showProfiles() {
    _showSectionWorkbench(DesktopShellSection.profileWorkflow);
  }

  void showProviders() {
    _showSectionWorkbench(DesktopShellSection.providerWorkflow);
  }

  void showRouting() {
    _showWorkbenchRoute(DesktopWorkbenchRoute.routing);
  }

  void showVPNTransportProfiles() {
    _showWorkbenchRoute(DesktopWorkbenchRoute.vpnTransportProfiles);
  }

  void showActivityRoute() {
    _showWorkbenchRoute(
      DesktopWorkbenchRoute.activity,
      closeInspectorIfOpen: true,
    );
  }

  void showDiagnosticsRoute() {
    _showWorkbenchRoute(
      DesktopWorkbenchRoute.diagnostics,
      closeInspectorIfOpen: true,
    );
  }

  void showSettings() {
    _showWorkbenchRoute(DesktopWorkbenchRoute.settings);
  }

  void showProfileWorkflow() {
    _showSectionWorkbench(DesktopShellSection.profileWorkflow);
  }

  void showProviderWorkflow() {
    _showSectionWorkbench(DesktopShellSection.providerWorkflow);
  }

  void openSavedProfilePicker() {
    activeWorkbenchRoute = DesktopWorkbenchRoute.profiles;
    _openCanvasRoute(
      DesktopCanvasRoute.savedProfilePicker,
      returnTarget: DesktopCanvasRoute.profileEditor,
    );
    _notifyWorkflow();
  }

  void openManagedProviderPickerForProfile() {
    activeWorkbenchRoute = DesktopWorkbenchRoute.profiles;
    _openCanvasRoute(
      DesktopCanvasRoute.managedProviderPickerForProfile,
      returnTarget: DesktopCanvasRoute.profileEditor,
    );
    _notifyWorkflow();
  }

  void openManagedProviderPicker() {
    activeWorkbenchRoute = DesktopWorkbenchRoute.providers;
    _openCanvasRoute(
      DesktopCanvasRoute.managedProviderPicker,
      returnTarget: DesktopCanvasRoute.managedProviderEditor,
    );
    _notifyWorkflow();
  }

  void openPresetPicker({
    DesktopCanvasRoute returnTarget = DesktopCanvasRoute.managedProviderEditor,
  }) {
    activeWorkbenchRoute = DesktopWorkbenchRoute.providers;
    _openCanvasRoute(
      DesktopCanvasRoute.presetPicker,
      returnTarget: returnTarget,
    );
    _notifyWorkflow();
  }

  void openProviderFamilyPicker() {
    activeWorkbenchRoute = DesktopWorkbenchRoute.providers;
    _openCanvasRoute(
      DesktopCanvasRoute.providerFamilyPicker,
      returnTarget: DesktopCanvasRoute.managedProviderEditor,
    );
    _notifyWorkflow();
  }

  void returnFromCanvasRoute() {
    if (!canReturnFromCanvasRoute) {
      return;
    }
    final returnTarget = _canvasRouteReturnTarget!;
    activeSection = _sectionForCanvasRoute(returnTarget);
    activeCanvasRoute = returnTarget;
    _canvasRouteReturnTarget = null;
    _notifyWorkflow();
  }

  void openInspector({
    DesktopInspectorPane pane = DesktopInspectorPane.diagnostics,
  }) {
    final wasOpen = isInspectorOpen;
    activeInspectorPane = pane;
    isInspectorOpen = true;
    _notifyInspector(layoutChanged: !wasOpen);
  }

  void closeInspector() {
    if (!isInspectorOpen) {
      return;
    }
    isInspectorOpen = false;
    _notifyInspector(layoutChanged: true);
  }

  void toggleInspector({
    DesktopInspectorPane pane = DesktopInspectorPane.diagnostics,
  }) {
    if (isInspectorOpen && activeInspectorPane == pane) {
      closeInspector();
      return;
    }
    openInspector(pane: pane);
  }

  Future<void> initialize() async {
    await _restorePersistedState();
    await _connectHost();
  }

  Future<void> reconnect() async {
    await _stopRuntimeMonitoring();
    await _connectHost();
  }

  Future<void> shutdown() {
    return _shutdownFuture ??= _shutdownInternal();
  }

  Future<void> _connectHost() async {
    busy = true;
    status = ShellStatus.booting;
    _notify();

    try {
      hostConnection = await supervisor.ensureReady();
    } catch (error) {
      hostConnection = HostConnectionResult(
        state: HostLifecycleState.failed,
        message: '$error',
      );
    }

    _clearPlatformTunnelResults();

    if (hostConnection?.isReady != true) {
      await _stopRuntimeMonitoring();
      _challengeCache.clear();
      providerDescriptors = const <ProviderDescriptor>[];
      providerSources = const <RemoteProviderSourceDescriptor>[];
      transportProfiles = const <TransportProfileStatus>[];
      platformTunnelStatuses = const <PlatformTunnelStatus>[];
      resolutions = const <ResolutionRecord>[];
      sessions = const <SessionRecord>[];
      _providerTransportCompatibilityCandidates.clear();
      selectedResolutionId = null;
      selectedSessionId = null;
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
    } catch (error) {
      await _handleHostFailure(error);
      return;
    }
    await refresh();
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

  Future<void> refresh() async {
    if (status != ShellStatus.ready) {
      _notify();
      return;
    }
    try {
      final nextProviders = await api.providers();
      final nextProviderSources = await api.providerSources();
      final nextTransportProfiles = hostSupportsTransportProfileStore
          ? await api.transportProfiles()
          : const <TransportProfileStatus>[];
      final nextPlatformTunnelStatuses = platformTunnels.isNotEmpty
          ? await api.platformTunnelStatuses()
          : const <PlatformTunnelStatus>[];
      final nextProfiles = await api.profiles();
      final nextResolutions = await api.resolutions();
      final nextSessions = await api.sessions();
      final nextChallenges = await _loadActiveChallenges(
        nextSessions,
        nextResolutions,
      );

      providerDescriptors = nextProviders;
      providerSources = nextProviderSources;
      managedProviders = _overlayManagedProviders(managedProviders);
      transportProfiles = nextTransportProfiles;
      _replacePlatformTunnelStatuses(nextPlatformTunnelStatuses);
      profiles = nextProfiles;
      resolutions = nextResolutions;
      sessions = nextSessions;
      _mergeChallenges(nextChallenges);

      draft = _normalizeDraft(draft);
      managedProviderDraft = _normalizeManagedProviderDraft(
        managedProviderDraft,
      );

      if (!_restoredState && selectedProfileId == null && profiles.isNotEmpty) {
        selectProfile(profiles.first.id, showWorkbench: false);
        return;
      } else if (selectedProfileId != null &&
          !profiles.any(
            (ProfileRecord profile) => profile.id == selectedProfileId,
          )) {
        selectedProfileId = null;
        draft = ProfileDraft.defaults();
        materializeDefaults = RuntimeDefaults.fromProfileSpec(draft.spec);
      }

      if (selectedManagedProviderId != null &&
          !managedProviders.any(
            (ManagedProviderRecord provider) =>
                provider.id == selectedManagedProviderId,
          )) {
        selectedManagedProviderId = null;
        managedProviderDraft = _defaultManagedProviderDraft();
      }

      if (selectedSessionId == null && sessions.isNotEmpty) {
        selectedSessionId = sessions.first.id;
      } else if (selectedSessionId != null &&
          !sessions.any(
            (SessionRecord session) => session.id == selectedSessionId,
          )) {
        selectedSessionId = null;
      }
      if (selectedResolutionId == null && resolutions.isNotEmpty) {
        selectedResolutionId = resolutions.first.id;
      } else if (selectedResolutionId != null &&
          !resolutions.any(
            (ResolutionRecord resolution) =>
                resolution.id == selectedResolutionId,
          )) {
        selectedResolutionId = null;
      }

      await _refreshProviderTransportCompatibilityCandidates();
      _scheduleStatePersist();
      _notify();
    } catch (error) {
      await _handleHostFailure(error);
    }
  }

  void selectProfile(String profileId, {bool showWorkbench = true}) {
    _restoredState = true;
    if (showWorkbench) {
      _showEditorWorkbench(DesktopShellSection.profileWorkflow, notify: false);
    }
    selectedProfileId = profileId;
    final selected = profiles.firstWhere(
      (ProfileRecord profile) => profile.id == profileId,
      orElse: () => ProfileDraft.defaults().toProfile(),
    );
    draft = _normalizeDraft(
      ProfileDraft.fromProfile(
        selected,
        providerBinding:
            profileBindings[profileId] ?? const ProfileProviderBinding(),
      ),
    );
    materializeDefaults = RuntimeDefaults.fromProfileSpec(selected.spec);
    _scheduleStatePersist();
    _notifyWorkflow();
  }

  void selectSession(String sessionId) {
    selectedSessionId = sessionId;
    _notifyInspector();
  }

  void selectResolution(String resolutionId) {
    selectedResolutionId = resolutionId;
    _notifyInspector();
  }

  void updateDraft(ProfileDraft nextDraft) {
    _restoredState = true;
    _showEditorWorkbench(DesktopShellSection.profileWorkflow, notify: false);
    draft = _normalizeDraft(nextDraft);
    materializeDefaults = RuntimeDefaults.fromProfileSpec(draft.spec);
    _scheduleStatePersist();
    _notifyWorkflow();
  }

  void useCustomProviderForDraft() {
    _restoredState = true;
    _showEditorWorkbench(DesktopShellSection.profileWorkflow, notify: false);
    draft = _normalizeDraft(draft.asCustomProvider());
    selectedManagedProviderId = null;
    materializeDefaults = RuntimeDefaults.fromProfileSpec(draft.spec);
    _scheduleStatePersist();
    _notifyWorkflow();
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
    _restoredState = true;
    _showEditorWorkbench(DesktopShellSection.profileWorkflow, notify: false);
    selectedProfileId = null;
    draft = _defaultDraft();
    materializeDefaults = RuntimeDefaults.fromProfileSpec(draft.spec);
    _scheduleStatePersist();
    _notifyWorkflow();
  }

  void selectManagedProvider(String providerId) {
    _showEditorWorkbench(DesktopShellSection.providerWorkflow, notify: false);
    selectedManagedProviderId = providerId;
    final selected =
        managedProviderById(providerId) ??
        _defaultManagedProviderDraft().toRecord();
    managedProviderDraft = _normalizeManagedProviderDraft(
      ManagedProviderDraft.fromRecord(selected),
    );
    _notifyWorkflow();
  }

  void selectProviderConfig(String configId) {
    selectManagedProvider(configId);
  }

  void updateManagedProviderDraft(ManagedProviderDraft nextDraft) {
    _showEditorWorkbench(DesktopShellSection.providerWorkflow, notify: false);
    managedProviderDraft = _normalizeManagedProviderDraft(nextDraft);
    _notifyWorkflow();
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
    _showEditorWorkbench(DesktopShellSection.providerWorkflow, notify: false);
    selectedManagedProviderId = null;
    managedProviderDraft = preset == null
        ? _defaultManagedProviderDraft(preferredProvider: preferredProvider)
        : _normalizeManagedProviderDraft(
            ManagedProviderDraft.fromPreset(
              preset,
              descriptor: descriptorForProvider(preset.provider),
            ),
          );
    _notifyWorkflow();
  }

  void startManagedProviderCreation() {
    selectedManagedProviderId = null;
    managedProviderDraft = _defaultManagedProviderDraft();
    activeWorkbenchRoute = DesktopWorkbenchRoute.providers;
    _openCanvasRoute(
      DesktopCanvasRoute.providerFamilyPicker,
      returnTarget: DesktopCanvasRoute.managedProviderPicker,
    );
    _notifyWorkflow();
  }

  void resetProviderConfigDraft({String? preferredProvider}) {
    resetManagedProviderDraft(preferredProvider: preferredProvider);
  }

  Future<void> saveDraft() async {
    await _runMutation(() async {
      final descriptor = activeProviderDescriptor;
      if (descriptor == null) {
        notice = _copy.selectedProviderNotAdvertisedByConnectedHost;
        return;
      }
      final blockReason = _providerSettingsBlockReason(descriptor);
      if (blockReason != null) {
        notice = blockReason;
        return;
      }
      final saved = await api.upsertProfile(
        draft.toProfile().copyWith(
          spec: draft.spec.copyWith(
            providerSettings: descriptor.profileRetainedProviderSettings(
              draft.spec.providerSettings,
            ),
          ),
        ),
      );
      profileBindings = <String, ProfileProviderBinding>{
        ...profileBindings,
        saved.id: draft.providerBinding,
      };
      notice = _copy.savedProfile(saved.name.isEmpty ? saved.id : saved.name);
      await refresh();
      selectProfile(saved.id);
    });
  }

  Future<void> saveManagedProviderDraft() async {
    await _runMutation(() async {
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
          ? 'managed-provider-${now.microsecondsSinceEpoch.toRadixString(16)}'
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
      notice = _copy.savedManagedProvider(
        saved.name.isEmpty ? saved.id : saved.name,
      );
      _showEditorWorkbench(DesktopShellSection.providerWorkflow, notify: false);
      selectedManagedProviderId = saved.id;
      managedProviderDraft = ManagedProviderDraft.fromRecord(saved);
      _scheduleStatePersist();
    });
  }

  Future<void> saveProviderConfigDraft() async {
    await saveManagedProviderDraft();
  }

  Future<void> deleteSelectedProfile() async {
    final profileId = selectedProfileId;
    if (profileId == null) {
      return;
    }
    await _runMutation(() async {
      await api.deleteProfile(profileId);
      profileBindings = <String, ProfileProviderBinding>{
        for (final entry in profileBindings.entries)
          if (entry.key != profileId) entry.key: entry.value,
      };
      notice = _copy.deletedProfile(profileId);
      resetDraft();
      await refresh();
    });
  }

  PortableProfileEnvelope? selectedPortableProfileEnvelope() {
    final selected = selectedSavedProfile;
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
    await _runMutation(() async {
      await _portableProfileTransferAdapter.copyEnvelopeText(
        envelope.toPrettyJson(),
      );
      final profileLabel = envelope.displayName;
      notice = envelope.isSecretBearing
          ? _copy.copiedSecretBearingPortableProfile(profileLabel)
          : _copy.copiedPortableProfile(profileLabel);
    });
  }

  Future<void> savePortableProfileEnvelopeToFile(
    PortableProfileEnvelope envelope,
  ) async {
    await _runMutation(() async {
      final path = await _portableProfileTransferAdapter.saveEnvelopeText(
        suggestedName: _portableProfileSuggestedFilename(envelope),
        payload: envelope.toPrettyJson(),
      );
      if (path == null) {
        return;
      }
      final profileLabel = envelope.displayName;
      notice = envelope.isSecretBearing
          ? _copy.savedSecretBearingPortableProfile(profileLabel, path)
          : _copy.savedPortableProfile(profileLabel, path);
    });
  }

  Future<PortableProfileEnvelope?>
  importPortableProfileEnvelopeFromFile() async {
    final payload = await _portableProfileTransferAdapter.openEnvelopeText();
    if (payload == null) {
      return null;
    }
    return previewPortableProfileEnvelope(payload);
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
    await _runMutation(() async {
      final imported = importPortableProfileEnvelope(
        envelope,
        idFactory: _nextPortableImportId,
      );
      final savedProfile = await api.upsertProfile(imported.profile);
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
        savedProfile.id: imported.providerBinding,
      };
      notice = envelope.isSecretBearing
          ? _copy.importedSecretBearingProfile(
              savedProfile.name.isEmpty ? savedProfile.id : savedProfile.name,
            )
          : _copy.importedProfile(
              savedProfile.name.isEmpty ? savedProfile.id : savedProfile.name,
            );
      _showEditorWorkbench(DesktopShellSection.profileWorkflow, notify: false);
      await refresh();
      selectProfile(savedProfile.id);
    });
  }

  String _nextPortableImportId() {
    _portableImportNonce += 1;
    final seed = _clock().microsecondsSinceEpoch.toRadixString(16);
    return 'portable-$seed-${_portableImportNonce.toRadixString(16)}';
  }

  Future<void> deleteSelectedManagedProvider() async {
    final providerId = selectedManagedProviderId;
    if (providerId == null) {
      return;
    }
    await _runMutation(() async {
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
      _showEditorWorkbench(DesktopShellSection.providerWorkflow, notify: false);
      _scheduleStatePersist();
    });
  }

  Future<void> deleteSelectedProviderConfig() async {
    await deleteSelectedManagedProvider();
  }

  Future<void> startSelectedProfile() async {
    final profileId = selectedProfileId;
    if (profileId == null) {
      return;
    }
    await _runMutation(() async {
      final session = await api.startSession(profileId: profileId);
      selectedSessionId = session.id;
      notice = _copy.startedSession(session.id);
      await refresh();
    });
  }

  void useManagedProviderForDraft(String managedProviderId) {
    final provider = managedProviderById(managedProviderId);
    if (provider == null) {
      notice = _copy.managedProviderNoLongerAvailable(managedProviderId);
      _notify();
      return;
    }
    _showEditorWorkbench(DesktopShellSection.profileWorkflow, notify: false);
    draft = _normalizeDraft(draft.applyManagedProvider(provider));
    selectedManagedProviderId = managedProviderId;
    materializeDefaults = RuntimeDefaults.fromProfileSpec(draft.spec);
    notice = _copy.appliedManagedProviderToActiveProfileDraft(
      provider.name.isEmpty ? provider.id : provider.name,
    );
    _scheduleStatePersist();
    _notifyWorkflow();
  }

  void applyProviderConfigToDraft(String configId) {
    useManagedProviderForDraft(configId);
  }

  void applyPreset(ProviderPreset preset) {
    resetManagedProviderDraft(preset: preset);
    notice = _copy.seededManagedProviderDraftFromPreset(preset.title);
    _notifyWorkflow();
  }

  Future<void> startResolutionFromDraft() async {
    await _runMutation(() async {
      final descriptor = activeProviderDescriptor;
      if (descriptor == null) {
        notice = _copy.selectedProviderNotAdvertisedByConnectedHost;
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
    await _runMutation(() async {
      final resolution = await api.cancelResolution(resolutionId);
      selectedResolutionId = resolution.id;
      notice = _copy.cancelledResolution(resolution.id);
      await refresh();
    });
  }

  Future<void> materializeResolution(String resolutionId) async {
    await _runMutation(() async {
      final session = await api.materializeResolution(
        resolutionId: resolutionId,
        runtimeDefaults: materializeDefaults,
      );
      selectedResolutionId = resolutionId;
      selectedSessionId = session.id;
      notice = _copy.startedSessionFromResolution(session.id, resolutionId);
      await refresh();
    });
  }

  Future<void> copyResolutionExport(String resolutionId) async {
    await _runMutation(() async {
      final exported = await api.exportResolution(resolutionId);
      await _handoffAdapter.copyLink(exported.link);
      selectedResolutionId = resolutionId;
      notice = _copy.copiedHandoffLink(
        resolutionId,
        _formatNoticeTimestamp(exported.expiresAt),
      );
    });
  }

  Future<void> openResolutionExternalAction(
    String resolutionId,
    ArtifactAction action,
  ) async {
    await _runMutation(() async {
      final resolution = _resolutionById(resolutionId);
      if (resolution == null) {
        notice = _copy.resolutionNoLongerAvailable(resolutionId);
        return;
      }
      if (action == ArtifactAction.openRoom &&
          !hostSupportsConferenceRoomActions) {
        notice = _copy.resolutionDoesNotAdvertiseAction(
          resolutionId,
          action.label,
        );
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

  Future<void> openChallengeInBrowser(ChallengeRecord challenge) async {
    if (!canOpenChallengeInBrowser(challenge)) {
      notice = challenge.prompt ?? _copy.challengeHasNoBrowserHandoffUrl;
      _notify();
      return;
    }
    final url = challenge.openUrl?.trim() ?? '';
    if (url.isEmpty) {
      notice = _copy.challengeHasNoBrowserHandoffUrl;
      _notify();
      return;
    }
    final opened = await _browserLauncher.open(url);
    notice = opened
        ? _copy.openedMobileBrowserHandoff(challenge.kind)
        : _copy.failedToOpenMobileBrowserHandoffUrl;
    _notify();
  }

  bool canOpenChallengeInBrowser(ChallengeRecord challenge) {
    // Desktop provider browser continuations are host-driven. Opening openUrl
    // with xdg-open would leave the controlled browser session.
    return false;
  }

  Future<void> stopSession(String sessionId) async {
    await _runMutation(() async {
      await api.stopSession(sessionId);
      notice = _copy.stoppedSession(sessionId);
      await refresh();
    });
  }

  Future<void> continueChallenge(String challengeId) async {
    await _runMutation(() async {
      final challenge = await api.continueChallenge(challengeId);
      _challengeCache[challenge.id] = challenge;
      notice = _challengeContinuedNotice(challenge);
      await refresh();
      await _startPendingPlatformTunnelIfResolutionReady();
    });
  }

  Future<void> cancelChallenge(String challengeId) async {
    await _runMutation(() async {
      final challenge = await api.cancelChallenge(challengeId);
      _challengeCache[challenge.id] = challenge;
      notice = _copy.cancelledChallenge(challengeId);
      await refresh();
    });
  }

  Future<void> exportDiagnostics(String sessionId) async {
    await _runMutation(() async {
      final diagnostics = await api.diagnostics(sessionId);
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

  Future<void> importVPNTransportProfileForMode(PlatformTunnelMode mode) async {
    await _runMutation(() async {
      final descriptor = _transportProfileExecutionPlanDescriptorForMode(mode);
      final prerequisite = descriptor?.transportProfile;
      final adapter = _transportProfileImportAdapterForMode(mode);
      if (adapter == null) {
        notice = _copy.vpnTransportProfileRequiredBeforeStarting;
        return;
      }
      final material = await _transportProfileContentPicker();
      if (material == null) {
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
      await api.importTransportProfile(
        TransportProfileImportRequest(
          adapter: adapter,
          kind: kind,
          displayName: _transportProfileKindLabel(kind),
          material: material,
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
  validateStructuredVPNTransportProfileForMode(
    PlatformTunnelMode mode,
    TransportProfileStructuredValidationRequest request,
  ) {
    final schema = vpnTransportProfileEditorSchemaForMode(mode);
    if (schema == null || !schema.supportsDraftValidation) {
      throw StateError('Structured VPN profile editing is unavailable.');
    }
    return api.validateStructuredTransportProfileDraft(request);
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
        ? await api.createStructuredTransportProfile(
            TransportProfileStructuredCreateRequest(draft: draft),
          )
        : await api.updateStructuredTransportProfile(
            existing.id,
            TransportProfileStructuredUpdateRequest(draft: draft),
          );
    await _refreshHostInfo();
    await refresh();
    notice = _copy.vpnTransportProfileConfigured;
    _notify();
    return result;
  }

  Future<void> forgetVPNTransportProfileForMode(PlatformTunnelMode mode) async {
    await _runMutation(() async {
      final profile = vpnTransportProfileStatusForMode(mode);
      if (profile == null) {
        notice = _copy.vpnTransportProfileRequiredBeforeStarting;
        return;
      }
      await api.forgetTransportProfile(profile.id);
      await _refreshHostInfo();
      await refresh();
      notice = _copy.vpnTransportProfileCleared;
    });
  }

  Future<void> forgetVPNTransportProfileRecord(
    TransportProfileStatus profile,
  ) async {
    await _runMutation(() async {
      await api.forgetTransportProfile(profile.id);
      await _refreshHostInfo();
      await refresh();
      notice = _copy.vpnTransportProfileCleared;
      _notify();
    });
  }

  Future<void> validateVPNTransportProfileRecord(
    TransportProfileStatus profile,
  ) async {
    await _runMutation(() async {
      await api.validateTransportProfile(profile.id);
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
    await _runMutation(() async {
      final plan = vpnTransportProfileExecutionPlanForMode(mode);
      if (plan == null) {
        notice = _copy.vpnTransportProfileRequiredBeforeStarting;
        return;
      }
      await api.selectTransportProfileForStartup(
        profile.id,
        TransportProfileSelectForStartupRequest(plan: plan),
      );
      await _refreshHostInfo();
      await refresh();
      notice = _copy.vpnTransportProfileConfigured;
      _notify();
    });
  }

  Future<PortableTransportProfileEnvelopeCarriage?>
  exportPortableVPNTransportProfileRecord(
    TransportProfileStatus profile, {
    required String passphrase,
  }) async {
    PortableTransportProfileEnvelopeCarriage? carriage;
    await _runMutation(() async {
      final capability = portableTransportProfileTransferCapability;
      if (capability == null ||
          capability.exportPaths.isEmpty ||
          !_portableTransferSupportsKind(capability, profile.kind) ||
          !profile.actions.contains(
            TransportProfileLifecycleAction.exportPortable,
          )) {
        notice = 'Portable VPN transport-profile export is unavailable.';
        return;
      }
      if (passphrase.isEmpty) {
        notice = 'Passphrase is required.';
        return;
      }
      final result = await api.exportTransportProfilePortable(
        profile.id,
        TransportProfilePortableExportRequest(passphrase: passphrase),
      );
      carriage = PortableTransportProfileEnvelopeCarriage.fromExportResult(
        result,
      );
      notice =
          'Prepared portable VPN transport profile '
          '${_portableTransportProfileDisplayLabel(result.displayName, result.profileKind)}.';
    });
    return carriage;
  }

  Future<void> copyPortableVPNTransportProfileEnvelopeText(
    PortableTransportProfileEnvelopeCarriage carriage,
  ) async {
    await _runMutation(() async {
      await _portableProfileTransferAdapter.copyEnvelopeText(carriage.envelope);
      notice =
          'Copied portable VPN transport profile '
          '${_portableTransportProfileDisplayLabel(carriage.displayName, carriage.profileKind)}.';
    });
  }

  Future<void> savePortableVPNTransportProfileEnvelopeToFile(
    PortableTransportProfileEnvelopeCarriage carriage,
  ) async {
    await _runMutation(() async {
      final path = await _portableProfileTransferAdapter.saveEnvelopeText(
        suggestedName: _portableTransportProfileSuggestedFilename(carriage),
        payload: carriage.envelope,
      );
      if (path == null) {
        return;
      }
      notice =
          'Saved portable VPN transport profile '
          '${_portableTransportProfileDisplayLabel(carriage.displayName, carriage.profileKind)} '
          'to $path.';
    });
  }

  Future<String?> openPortableVPNTransportProfileEnvelopeText() async {
    try {
      return await _portableProfileTransferAdapter.openEnvelopeText();
    } catch (error) {
      notice = '$error';
      _notify();
      return null;
    }
  }

  Future<TransportProfilePortableTransferPreview?>
  previewPortableVPNTransportProfileImport({
    required String envelope,
    required String passphrase,
  }) async {
    TransportProfilePortableTransferPreview? preview;
    await _runMutation(() async {
      final capability = portableTransportProfileTransferCapability;
      if (capability == null || capability.importPaths.isEmpty) {
        notice = 'Portable VPN transport-profile import is unavailable.';
        return;
      }
      if (passphrase.isEmpty) {
        notice = 'Passphrase is required.';
        return;
      }
      preview = await api.previewTransportProfilePortableImport(
        TransportProfilePortableImportRequest(
          envelope: envelope,
          passphrase: passphrase,
        ),
      );
    });
    return preview;
  }

  Future<TransportProfileStatus?> confirmPortableVPNTransportProfileImport({
    required String envelope,
    required String passphrase,
  }) async {
    TransportProfileStatus? imported;
    await _runMutation(() async {
      final capability = portableTransportProfileTransferCapability;
      if (capability == null || capability.importPaths.isEmpty) {
        notice = 'Portable VPN transport-profile import is unavailable.';
        return;
      }
      if (passphrase.isEmpty) {
        notice = 'Passphrase is required.';
        return;
      }
      imported = await api.confirmTransportProfilePortableImport(
        TransportProfilePortableImportRequest(
          envelope: envelope,
          passphrase: passphrase,
        ),
      );
      await _refreshHostInfo();
      await refresh();
      notice =
          'Imported portable VPN transport profile '
          '${_portableTransportProfileDisplayLabel(imported!.displayName, imported!.kind)}.';
    });
    return imported;
  }

  Future<void> startPlatformTunnel(PlatformTunnelMode mode) async {
    await _runMutation(() async {
      if (platformTunnelStartInFlight(mode)) {
        return;
      }
      final capability = _platformTunnelCapabilityFor(mode);
      if (capability == null) {
        _clearPendingPlatformTunnelStart(mode);
        notice = _copy.desktopNoPlatformTunnelModesReported;
        return;
      }
      if (!capability.available) {
        _clearPendingPlatformTunnelStart(mode);
        final message = capability.message.trim();
        notice = message.isNotEmpty
            ? message
            : _copy.desktopTypedHostTunnelSummary;
        return;
      }
      final preparationBlockReason = platformTunnelStartPreparationBlockReason(
        mode,
      );
      if (preparationBlockReason != null) {
        _clearPendingPlatformTunnelStart(mode);
        notice = preparationBlockReason;
        return;
      }
      final requiresResolution = _platformTunnelModeRequiresResolution(mode);
      final resolutionId = requiresResolution
          ? await _ensureResolutionForPlatformTunnel(
              mode,
              rememberStartupIntent: true,
            )
          : _platformTunnelResolutionIdFor(mode);
      if (requiresResolution && resolutionId == null) {
        return;
      }
      await _refreshProviderTransportCompatibilityForMode(
        mode,
        resolutionId: resolutionId,
      );
      final compatibilityBlockReason =
          _providerTransportCompatibilityBlockReasonForMode(mode);
      if (compatibilityBlockReason != null) {
        _clearPendingPlatformTunnelStart(mode);
        notice = compatibilityBlockReason;
        return;
      }
      final executionPlan = _defaultPlatformTunnelExecutionPlan(capability);
      final transportProfile = executionPlan == null
          ? null
          : _transportProfileReferenceForPlan(mode, executionPlan);
      final providerTransportCompatibility =
          await _providerTransportCompatibilityStartupReference(
            mode: mode,
            resolutionId: resolutionId,
            executionPlan: executionPlan,
            transportProfile: transportProfile,
          );
      _clearPendingPlatformTunnelStart(mode);
      _schedulePlatformTunnelStart(
        mode: mode,
        capability: capability,
        resolutionId: resolutionId,
        executionPlan: executionPlan,
        transportProfile: transportProfile,
        providerTransportCompatibility: providerTransportCompatibility,
      );
      await Future<void>.value();
    });
  }

  Future<void> stopPlatformTunnel(PlatformTunnelMode mode) async {
    await _runMutation(() async {
      final result = await api.stopPlatformTunnel(mode: mode);
      _platformTunnelResults.remove(mode);
      _clearPendingPlatformTunnelStart(mode);
      final message = result.message.trim();
      notice = message.isEmpty
          ? _copy.platformTunnelDisconnected(mode.label)
          : message;
      await refresh();
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
      notice = _copy.providerExpectsLinkEntryOnlyDesktop(
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
    return api.startResolution(
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
    PlatformTunnelMode mode, {
    required bool rememberStartupIntent,
  }) async {
    final selectedResolution = _selectedResolutionRecord();
    if (selectedResolution != null) {
      switch (selectedResolution.state) {
        case ResolutionState.resolved:
          return selectedResolution.id;
        case ResolutionState.challengeRequired:
          if (rememberStartupIntent) {
            _rememberPendingPlatformTunnelStart(mode, selectedResolution.id);
          }
          notice = _copy.challengeMustCompleteBeforeStarting(mode.label);
          return null;
        case ResolutionState.starting:
          if (rememberStartupIntent) {
            _rememberPendingPlatformTunnelStart(mode, selectedResolution.id);
          }
          notice = _copy.waitForProviderResolutionBeforeStarting(mode.label);
          return null;
        case ResolutionState.failed ||
            ResolutionState.cancelled ||
            ResolutionState.expired:
          _clearPendingPlatformTunnelStart(mode);
          selectedResolutionId = null;
          break;
      }
    }

    final descriptor = descriptorForProvider(draft.spec.provider);
    if (descriptor == null) {
      _clearPendingPlatformTunnelStart(mode);
      notice = _copy.selectedProviderNotAdvertisedByConnectedHost;
      return null;
    }
    final resolution = await _startResolutionForDraft(draft, descriptor);
    if (resolution == null) {
      _clearPendingPlatformTunnelStart(mode);
      return null;
    }
    selectedResolutionId = resolution.id;
    await refresh();
    final refreshedResolution = _resolutionById(resolution.id) ?? resolution;
    switch (refreshedResolution.state) {
      case ResolutionState.resolved:
        return refreshedResolution.id;
      case ResolutionState.challengeRequired:
        if (rememberStartupIntent) {
          _rememberPendingPlatformTunnelStart(mode, refreshedResolution.id);
        }
        notice = _copy.resolutionStartedThenCompleteChallengeBeforeStarting(
          _resolutionStartedNotice(descriptor, refreshedResolution.id),
          mode.label,
        );
        return null;
      case ResolutionState.starting:
        if (rememberStartupIntent) {
          _rememberPendingPlatformTunnelStart(mode, refreshedResolution.id);
        }
        notice = _copy.resolutionStartedThenWaitForFinishBeforeStarting(
          _resolutionStartedNotice(descriptor, refreshedResolution.id),
          mode.label,
        );
        return null;
      case ResolutionState.failed ||
          ResolutionState.cancelled ||
          ResolutionState.expired:
        _clearPendingPlatformTunnelStart(mode);
        notice = _resolutionUnavailableForPlatformTunnelNotice(
          mode,
          refreshedResolution,
        );
        return null;
    }
  }

  Future<void> _startPendingPlatformTunnelIfResolutionReady() async {
    final mode = _pendingPlatformTunnelStartMode;
    final resolutionId = _pendingPlatformTunnelStartResolutionId?.trim() ?? '';
    if (mode == null || resolutionId.isEmpty) {
      return;
    }
    final resolution = _resolutionById(resolutionId);
    if (resolution == null) {
      return;
    }
    switch (resolution.state) {
      case ResolutionState.resolved:
        final capability = _platformTunnelCapabilityFor(mode);
        if (capability == null) {
          _clearPendingPlatformTunnelStart(mode);
          notice = _copy.desktopNoPlatformTunnelModesReported;
          return;
        }
        if (!capability.available) {
          _clearPendingPlatformTunnelStart(mode);
          final message = capability.message.trim();
          notice = message.isNotEmpty
              ? message
              : _copy.desktopTypedHostTunnelSummary;
          return;
        }
        final preparationBlockReason =
            platformTunnelStartPreparationBlockReason(mode);
        if (preparationBlockReason != null) {
          _clearPendingPlatformTunnelStart(mode);
          notice = preparationBlockReason;
          return;
        }
        await _refreshProviderTransportCompatibilityForMode(
          mode,
          resolutionId: resolution.id,
        );
        final compatibilityBlockReason =
            _providerTransportCompatibilityBlockReasonForMode(mode);
        if (compatibilityBlockReason != null) {
          _clearPendingPlatformTunnelStart(mode);
          notice = compatibilityBlockReason;
          return;
        }
        final executionPlan = _defaultPlatformTunnelExecutionPlan(capability);
        final transportProfile = executionPlan == null
            ? null
            : _transportProfileReferenceForPlan(mode, executionPlan);
        final providerTransportCompatibility =
            await _providerTransportCompatibilityStartupReference(
              mode: mode,
              resolutionId: resolution.id,
              executionPlan: executionPlan,
              transportProfile: transportProfile,
            );
        _clearPendingPlatformTunnelStart(mode);
        _schedulePlatformTunnelStart(
          mode: mode,
          capability: capability,
          resolutionId: resolution.id,
          executionPlan: executionPlan,
          transportProfile: transportProfile,
          providerTransportCompatibility: providerTransportCompatibility,
        );
        await Future<void>.value();
        return;
      case ResolutionState.failed ||
          ResolutionState.cancelled ||
          ResolutionState.expired:
        _clearPendingPlatformTunnelStart(mode);
        notice = _resolutionUnavailableForPlatformTunnelNotice(
          mode,
          resolution,
        );
        return;
      case ResolutionState.challengeRequired:
      case ResolutionState.starting:
        return;
    }
  }

  void _schedulePlatformTunnelStart({
    required PlatformTunnelMode mode,
    required PlatformTunnelCapability capability,
    required String? resolutionId,
    required RuntimeExecutionPlan? executionPlan,
    required TransportProfileReference? transportProfile,
    required ProviderTransportCompatibilityStartupReference?
    providerTransportCompatibility,
  }) {
    if (_platformTunnelStartsInFlight.contains(mode)) {
      return;
    }
    _platformTunnelStartsInFlight.add(mode);
    _platformTunnelResults.remove(mode);
    _rememberPlatformTunnelLocalStatus(
      _startingPlatformTunnelStatus(
        mode: mode,
        capability: capability,
        resolutionId: resolutionId,
      ),
    );
    _notify();
    final startFuture = _startPlatformTunnelWithCapability(
      mode: mode,
      capability: capability,
      resolutionId: resolutionId,
      executionPlan: executionPlan,
      transportProfile: transportProfile,
      providerTransportCompatibility: providerTransportCompatibility,
    );
    unawaited(
      startFuture
          .then<void>((_) {})
          .catchError((Object error, StackTrace _) async {
            if (error is ControlPlaneError) {
              if (error.statusCode == 0 ||
                  error.incompatibleHost ||
                  error.statusCode >= 500) {
                await _handleHostFailure(error, scheduleRecovery: true);
                return;
              }
              notice = error.message;
              return;
            }
            notice = '$error';
          })
          .whenComplete(() {
            _platformTunnelStartsInFlight.remove(mode);
            final status = platformTunnelStatusFor(mode);
            if (status?.state == PlatformTunnelLifecycleState.starting) {
              _removePlatformTunnelLocalStatus(mode);
            }
            _notify();
          }),
    );
  }

  Future<void> _startPlatformTunnelWithCapability({
    required PlatformTunnelMode mode,
    required PlatformTunnelCapability capability,
    required String? resolutionId,
    required RuntimeExecutionPlan? executionPlan,
    required TransportProfileReference? transportProfile,
    required ProviderTransportCompatibilityStartupReference?
    providerTransportCompatibility,
  }) async {
    final result = await api.startPlatformTunnel(
      mode: mode,
      resolutionId: resolutionId,
      runtimeDefaults: _platformTunnelRuntimeDefaultsFor(mode),
      executionPlan: executionPlan,
      transportProfile: transportProfile,
      providerTransportCompatibility: providerTransportCompatibility,
      underlayRoutePolicy: _defaultPlatformTunnelUnderlayRoutePolicy(
        capability,
      ),
    );
    if (result.ready) {
      await refresh();
    }
    _platformTunnelResults[mode] = result;
    _rememberPlatformTunnelLocalStatus(
      _statusFromPlatformTunnelStartResult(
        result,
        sourceResolutionId: resolutionId,
      ),
    );
    if (result.ready) {
      final sessionId = _resolvePlatformTunnelReadySessionId(
        sessionId: result.sessionId,
        resolutionId: resolutionId,
      );
      if (sessionId != null) {
        selectedSessionId = sessionId;
      }
    }
    notice = _platformTunnelNotice(result);
  }

  void _rememberPendingPlatformTunnelStart(
    PlatformTunnelMode mode,
    String resolutionId,
  ) {
    final normalized = resolutionId.trim();
    if (normalized.isEmpty) {
      return;
    }
    _pendingPlatformTunnelStartMode = mode;
    _pendingPlatformTunnelStartResolutionId = normalized;
  }

  void _clearPendingPlatformTunnelStart([PlatformTunnelMode? mode]) {
    if (mode != null && _pendingPlatformTunnelStartMode != mode) {
      return;
    }
    _pendingPlatformTunnelStartMode = null;
    _pendingPlatformTunnelStartResolutionId = null;
  }

  String? _resolvePlatformTunnelReadySessionId({
    required String sessionId,
    required String? resolutionId,
  }) {
    final explicitSessionId = sessionId.trim();
    if (explicitSessionId.isNotEmpty &&
        sessions.any(
          (SessionRecord session) => session.id == explicitSessionId,
        )) {
      return explicitSessionId;
    }

    final normalizedResolutionId = resolutionId?.trim() ?? '';
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

  PlatformTunnelCapability? _platformTunnelCapabilityFor(
    PlatformTunnelMode mode,
  ) {
    for (final capability in platformTunnels) {
      if (capability.mode == mode) {
        return capability;
      }
    }
    return null;
  }

  String? _platformTunnelResolutionIdFor(PlatformTunnelMode mode) {
    if (!_platformTunnelModeRequiresResolution(mode)) {
      return null;
    }
    final resolutionId = selectedResolutionId?.trim() ?? '';
    return resolutionId.isEmpty ? null : resolutionId;
  }

  RuntimeDefaults? _platformTunnelRuntimeDefaultsFor(PlatformTunnelMode mode) {
    if (!_platformTunnelModeRequiresRuntimeDefaults(mode)) {
      return null;
    }
    return materializeDefaults;
  }

  RuntimeExecutionPlan? _defaultPlatformTunnelExecutionPlan(
    PlatformTunnelCapability? capability,
  ) {
    if (capability == null) {
      return null;
    }
    final descriptor = _defaultPlatformTunnelExecutionPlanDescriptor(
      capability,
    );
    return descriptor?.plan;
  }

  RuntimeExecutionPlanDescriptor? _defaultPlatformTunnelExecutionPlanDescriptor(
    PlatformTunnelCapability? capability,
  ) {
    if (capability == null) {
      return null;
    }
    for (final descriptor in capability.executionPlans) {
      if (descriptor.isDefault) {
        return descriptor;
      }
    }
    if (capability.executionPlans.length == 1) {
      return capability.executionPlans.first;
    }
    return null;
  }

  RuntimeExecutionPlanDescriptor?
  _transportProfileExecutionPlanDescriptorForMode(
    PlatformTunnelMode mode, {
    RuntimeExecutionPlan? plan,
  }) {
    final capability = _platformTunnelCapabilityFor(mode);
    if (capability == null) {
      return null;
    }
    final selectedPlan =
        plan ?? _defaultPlatformTunnelExecutionPlan(capability);
    if (selectedPlan != null) {
      for (final descriptor in capability.executionPlans) {
        if (_sameExecutionPlan(descriptor.plan, selectedPlan) &&
            descriptor.transportProfile != null) {
          return descriptor;
        }
      }
    }
    final defaultDescriptor = _defaultPlatformTunnelExecutionPlanDescriptor(
      capability,
    );
    if (defaultDescriptor?.transportProfile != null) {
      return defaultDescriptor;
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
    final descriptor = _transportProfileExecutionPlanDescriptorForMode(
      mode,
      plan: plan,
    );
    final prerequisite = descriptor?.transportProfile;
    if (prerequisite == null) {
      return null;
    }
    final hasSelectedOrDefault =
        prerequisite.selectedProfile?.profileId.trim().isNotEmpty == true ||
        prerequisite.defaultProfile?.profileId.trim().isNotEmpty == true;
    if (!hasSelectedOrDefault &&
        descriptor?.supportState !=
            RuntimeExecutionPlanSupportState.supported) {
      final descriptorMessage = descriptor?.message?.trim() ?? '';
      if (descriptorMessage.isNotEmpty) {
        return descriptorMessage;
      }
      final prerequisiteMessage = prerequisite.message.trim();
      if (prerequisiteMessage.isNotEmpty) {
        return prerequisiteMessage;
      }
      return _copy.vpnTransportProfileRequiredBeforeStarting;
    }
    if (prerequisite.isCompatible) {
      return null;
    }
    final hostMessage = prerequisite.message.trim();
    if (hostMessage.isNotEmpty &&
        prerequisite.missingKind != null &&
        !hostSupportsTransportProfileStore) {
      return hostMessage;
    }
    return _copy.vpnTransportProfileRequiredBeforeStarting;
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

  bool _portableTransferSupportsAnyKind(
    TransportProfilePortableTransferCapability capability,
    List<TransportProfileKind> kinds,
  ) {
    if (kinds.isEmpty) {
      return capability.supportedKinds.isNotEmpty;
    }
    return kinds.any(
      (TransportProfileKind kind) =>
          _portableTransferSupportsKind(capability, kind),
    );
  }

  bool _portableTransferSupportsKind(
    TransportProfilePortableTransferCapability capability,
    TransportProfileKind kind,
  ) {
    return capability.supportedKinds.contains(kind);
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

  Future<ProviderTransportCompatibilityStartupReference?>
  _providerTransportCompatibilityStartupReference({
    required PlatformTunnelMode mode,
    required String? resolutionId,
    required RuntimeExecutionPlan? executionPlan,
    required TransportProfileReference? transportProfile,
  }) async {
    final selected =
        _providerTransportCompatibilityCandidates[mode] ??
        await _providerTransportCompatibilityCandidate(
          resolutionId: resolutionId,
          executionPlan: executionPlan,
          transportProfile: transportProfile,
        );
    return selected?.toStartupReference(
      fallbackTransportProfile: transportProfile,
    );
  }

  Future<void> _refreshProviderTransportCompatibilityCandidates() async {
    final next =
        <PlatformTunnelMode, ProviderTransportCompatibilityCandidate>{};
    if (!hostSupportsProviderTransportCompatibility) {
      _providerTransportCompatibilityCandidates
        ..clear()
        ..addAll(next);
      return;
    }
    for (final capability in platformTunnels) {
      final mode = capability.mode;
      final candidate = await _providerTransportCompatibilityCandidateForMode(
        mode,
        resolutionId: _platformTunnelResolutionIdFor(mode),
      );
      if (candidate != null) {
        next[mode] = candidate;
      }
    }
    _providerTransportCompatibilityCandidates
      ..clear()
      ..addAll(next);
  }

  Future<void> _refreshProviderTransportCompatibilityForMode(
    PlatformTunnelMode mode, {
    required String? resolutionId,
  }) async {
    final candidate = await _providerTransportCompatibilityCandidateForMode(
      mode,
      resolutionId: resolutionId,
    );
    if (candidate == null) {
      _providerTransportCompatibilityCandidates.remove(mode);
      return;
    }
    _providerTransportCompatibilityCandidates[mode] = candidate;
  }

  Future<ProviderTransportCompatibilityCandidate?>
  _providerTransportCompatibilityCandidateForMode(
    PlatformTunnelMode mode, {
    required String? resolutionId,
  }) {
    final executionPlan = _defaultPlatformTunnelExecutionPlan(
      _platformTunnelCapabilityFor(mode),
    );
    final transportProfile = executionPlan == null
        ? null
        : _transportProfileReferenceForPlan(mode, executionPlan);
    return _providerTransportCompatibilityCandidate(
      resolutionId: resolutionId,
      executionPlan: executionPlan,
      transportProfile: transportProfile,
    );
  }

  Future<ProviderTransportCompatibilityCandidate?>
  _providerTransportCompatibilityCandidate({
    required String? resolutionId,
    required RuntimeExecutionPlan? executionPlan,
    required TransportProfileReference? transportProfile,
  }) async {
    final trimmedResolutionId = resolutionId?.trim() ?? '';
    if (!hostSupportsProviderTransportCompatibility ||
        trimmedResolutionId.isEmpty ||
        executionPlan == null ||
        transportProfile == null ||
        transportProfile.isEmpty) {
      return null;
    }
    final response = await api.providerTransportCompatibilityCandidates(
      ProviderTransportCompatibilityRequest(
        resolutionId: trimmedResolutionId,
        executionPlan: executionPlan,
        transportProfile: transportProfile,
      ),
    );
    ProviderTransportCompatibilityCandidate? selected;
    for (final candidate in response.candidates) {
      selected ??= candidate;
      if (candidate.isStartable) {
        selected = candidate;
        break;
      }
    }
    return selected;
  }

  String? _providerTransportCompatibilityBlockReasonForMode(
    PlatformTunnelMode mode,
  ) {
    final candidate = _providerTransportCompatibilityCandidates[mode];
    if (candidate == null || candidate.isStartable) {
      return null;
    }
    return _providerTransportCompatibilityMessage(
      candidate,
      prefix: 'provider/transport compatibility',
    );
  }

  String _providerTransportCompatibilityMessage(
    ProviderTransportCompatibilityCandidate candidate, {
    required String prefix,
  }) {
    final parts = <String>['$prefix: ${candidate.status.value}'];
    final axis = candidate.failingAxis?.value.trim() ?? '';
    if (axis.isNotEmpty) {
      parts.add('axis $axis');
    }
    final reason = candidate.reasonCode?.value.trim() ?? '';
    if (reason.isNotEmpty) {
      parts.add('reason $reason');
    }
    final source = candidate.source;
    if (source != null && !source.isEmpty) {
      final sourceRef = source.sourceId.trim().isNotEmpty
          ? source.sourceId.trim()
          : source.resolutionId.trim();
      if (sourceRef.isNotEmpty) {
        parts.add('source $sourceRef');
      }
    }
    final profile = candidate.selectedTransportProfile;
    if (profile != null && !profile.isEmpty) {
      parts.add('VPN transport ${profile.profileId}');
    }
    final message = candidate.message.trim();
    return message.isEmpty ? parts.join('; ') : '${parts.join('; ')}. $message';
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

  bool _sameExecutionPlan(
    RuntimeExecutionPlan left,
    RuntimeExecutionPlan right,
  ) {
    return left.accessMethod == right.accessMethod &&
        left.carrierFamily == right.carrierFamily &&
        left.engineFamily == right.engineFamily &&
        left.hostAdapter == right.hostAdapter;
  }

  PlatformTunnelUnderlayRoutePolicy _defaultPlatformTunnelUnderlayRoutePolicy(
    PlatformTunnelCapability? capability,
  ) {
    if (capability?.supportedUnderlayRoutePolicies.contains(
          PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork,
        ) ??
        false) {
      return PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork;
    }
    return PlatformTunnelUnderlayRoutePolicy.standard;
  }

  bool _platformTunnelModeRequiresResolution(PlatformTunnelMode mode) {
    return mode == PlatformTunnelMode.windowsWintun ||
        mode == PlatformTunnelMode.linuxTun;
  }

  bool _platformTunnelModeRequiresRuntimeDefaults(PlatformTunnelMode mode) {
    return mode == PlatformTunnelMode.windowsWintun ||
        mode == PlatformTunnelMode.linuxTun;
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

  ProfileRecord? get selectedSavedProfile {
    final profileId = selectedProfileId?.trim() ?? '';
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

  @override
  void dispose() {
    _disposed = true;
    unawaited(shutdown());
    shellChromeRevision.dispose();
    workflowRevision.dispose();
    inspectorLayoutRevision.dispose();
    inspectorRevision.dispose();
    super.dispose();
  }

  Future<void> _shutdownInternal() async {
    _shuttingDown = true;
    await supervisor.dispose();
    await _stopRuntimeMonitoring(
      eventSubscriptionCancelTimeout: const Duration(milliseconds: 250),
    );
  }

  void _startEventStream() {
    _eventSubscription?.cancel();
    _eventSubscription = api.events().listen(
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
        _notifyInspector();
      },
      onError: (Object error) {
        if (_suppressEventStreamClosure || _disposed || _shuttingDown) {
          return;
        }
        unawaited(_handleHostFailure(error));
      },
      onDone: () {
        if (_disposed ||
            _shuttingDown ||
            _suppressEventStreamClosure ||
            status != ShellStatus.ready) {
          return;
        }
        unawaited(
          _handleHostFailure(
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
    sessions = updated;
  }

  void _scheduleRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(refresh());
    });
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    if (status != ShellStatus.ready || hostConnection?.isReady != true) {
      notice = hostConnection?.message ?? _copy.localHostNotReady;
      _notify();
      return;
    }
    busy = true;
    _notify();
    try {
      await action();
    } on ControlPlaneError catch (error) {
      if (error.statusCode == 0 ||
          error.incompatibleHost ||
          error.statusCode >= 500) {
        await _handleHostFailure(error, scheduleRecovery: true);
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
        loaded.add(await api.challenge(id));
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
    for (final challenge in challenges) {
      _challengeCache[challenge.id] = challenge;
    }
  }

  Future<void> _stopRuntimeMonitoring({
    Duration? eventSubscriptionCancelTimeout,
  }) async {
    _suppressEventStreamClosure = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _persistTimer?.cancel();
    _persistTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    final eventSubscription = _eventSubscription;
    _eventSubscription = null;
    if (eventSubscription != null) {
      final cancelFuture = eventSubscription.cancel();
      if (eventSubscriptionCancelTimeout != null) {
        await cancelFuture.timeout(
          eventSubscriptionCancelTimeout,
          onTimeout: () {},
        );
      } else {
        await cancelFuture;
      }
    }
    _suppressEventStreamClosure = false;
  }

  Future<void> _handleHostFailure(
    Object error, {
    bool scheduleRecovery = true,
  }) async {
    if (_shuttingDown) {
      return;
    }
    await _stopRuntimeMonitoring();
    final message = error is ControlPlaneError ? error.message : '$error';
    hostConnection = HostConnectionResult(
      state: HostLifecycleState.unavailable,
      message: message,
    );
    _clearPlatformTunnelResults();
    transportProfiles = const <TransportProfileStatus>[];
    resolutions = const <ResolutionRecord>[];
    sessions = const <SessionRecord>[];
    selectedResolutionId = null;
    selectedSessionId = null;
    status = ShellStatus.blocked;
    notice = message;
    busy = false;
    _notify();

    if (!scheduleRecovery || _recoveringHost || _disposed) {
      return;
    }
    unawaited(_recoverHost());
  }

  Future<void> _recoverHost() async {
    if (_recoveringHost || _disposed || _shuttingDown) {
      return;
    }
    _recoveringHost = true;
    try {
      await _connectHost();
    } finally {
      _recoveringHost = false;
    }
  }

  Future<void> _restorePersistedState() async {
    try {
      final state = await _stateStore.load();
      _restoreStateError = null;
      if (state == null) {
        return;
      }
      profiles = state.profiles;
      managedProviders = state.managedProviders;
      profileBindings = state.profileBindings;
      selectedProfileId = state.selectedProfileId;
      draft = state.draft;
      materializeDefaults = state.runtimeDefaults;
      localeOverrideTag = state.localeTag;
      managedProviderDraft = _defaultManagedProviderDraft();
      _persistedStateSignature = state.signature();
      _restoredState = true;
    } catch (error) {
      _restoreStateError = error;
      notice = _copy.failedToRestoreDesktopShellState(error);
    }
  }

  Future<void> _rehydrateProfiles() async {
    if (profiles.isEmpty) {
      return;
    }
    final restored = <ProfileRecord>[];
    for (final profile in profiles) {
      restored.add(await api.upsertProfile(profile));
    }
    profiles = restored;
    _scheduleStatePersist();
  }

  Future<void> _refreshHostInfo() async {
    final current = hostConnection;
    if (current == null || !current.isReady) {
      return;
    }
    final nextInfo = await api.hostInfo();
    hostConnection = HostConnectionResult(
      state: current.state,
      message: current.message,
      info: nextInfo,
      launched: current.launched,
      launchSpec: current.launchSpec,
    );
  }

  void _scheduleStatePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 150), () {
      unawaited(_persistState());
    });
  }

  Future<void> _persistState() async {
    final next = DesktopShellState(
      profiles: profiles,
      managedProviders: managedProviders,
      profileBindings: profileBindings,
      selectedProfileId: selectedProfileId,
      draft: draft,
      runtimeDefaults: materializeDefaults,
      localeTag: localeOverrideTag,
    );
    final sanitized = next.sanitizedForPersistence(providerDescriptors);
    final signature = sanitized.signature();
    if (signature == _persistedStateSignature) {
      return;
    }
    try {
      await _stateStore.save(sanitized);
      _persistedStateSignature = signature;
    } catch (error) {
      notice = _copy.failedToPersistDesktopShellState(error);
      _notify();
    }
  }

  void _clearPlatformTunnelResults() {
    _platformTunnelResults.clear();
    platformTunnelStatuses = const <PlatformTunnelStatus>[];
    _platformTunnelStartsInFlight.clear();
    _providerTransportCompatibilityCandidates.clear();
    _clearPendingPlatformTunnelStart();
  }

  void _replacePlatformTunnelStatuses(List<PlatformTunnelStatus> nextStatuses) {
    final merged = <PlatformTunnelStatus>[...nextStatuses];
    final seenModes = nextStatuses.map((PlatformTunnelStatus status) {
      return status.mode;
    }).toSet();
    for (final mode in _platformTunnelStartsInFlight) {
      if (seenModes.contains(mode)) {
        continue;
      }
      final existing = platformTunnelStatusFor(mode);
      if (existing != null &&
          existing.state == PlatformTunnelLifecycleState.starting) {
        merged.add(existing);
        continue;
      }
      final capability = _platformTunnelCapabilityFor(mode);
      if (capability == null) {
        continue;
      }
      merged.add(
        _startingPlatformTunnelStatus(
          mode: mode,
          capability: capability,
          resolutionId: _platformTunnelResolutionIdFor(mode),
        ),
      );
    }
    platformTunnelStatuses = merged;
    final seenStatusModes = <PlatformTunnelMode>{};
    for (final status in merged) {
      seenStatusModes.add(status.mode);
      final result = _platformTunnelResultFromStatus(status);
      if (result == null) {
        _platformTunnelResults.remove(status.mode);
      } else {
        _platformTunnelResults[status.mode] = result;
      }
    }
    _platformTunnelResults.removeWhere(
      (PlatformTunnelMode mode, PlatformTunnelStartResult _) =>
          !seenStatusModes.contains(mode),
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
        providerTransportCompatibility: status.providerTransportCompatibility,
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
      providerTransportCompatibility: status.providerTransportCompatibility,
      remoteIngress: status.remoteIngress,
      dataplane: status.dataplane,
      stage: status.stage,
      missingPrerequisite: status.missingPrerequisite,
      startupAttemptId: status.startupAttemptId,
      underlayRoutePolicy: status.underlayRoutePolicy,
      message: status.message,
    );
  }

  PlatformTunnelStatus _startingPlatformTunnelStatus({
    required PlatformTunnelMode mode,
    required PlatformTunnelCapability capability,
    required String? resolutionId,
  }) {
    final executionPlan = _defaultPlatformTunnelExecutionPlan(capability);
    final transportProfile = executionPlan == null
        ? null
        : _transportProfileReferenceForPlan(mode, executionPlan);
    return PlatformTunnelStatus(
      mode: mode,
      state: PlatformTunnelLifecycleState.starting,
      ready: false,
      sourceResolutionId: (resolutionId ?? '').trim(),
      executionPlan: executionPlan,
      transportProfile: transportProfile,
      underlayRoutePolicy: _defaultPlatformTunnelUnderlayRoutePolicy(
        capability,
      ),
      updatedAt: _clock().toUtc(),
    );
  }

  PlatformTunnelStatus _statusFromPlatformTunnelStartResult(
    PlatformTunnelStartResult result, {
    required String? sourceResolutionId,
  }) {
    final PlatformTunnelLifecycleState state;
    if (result.ready) {
      state = PlatformTunnelLifecycleState.ready;
    } else if (result.stage == PlatformTunnelStartupStage.permissionAcquire &&
        result.missingPrerequisite == PlatformTunnelPrerequisite.permission) {
      state = PlatformTunnelLifecycleState.permission;
    } else if (result.stage == PlatformTunnelStartupStage.profileValidate ||
        result.missingPrerequisite ==
            PlatformTunnelPrerequisite.transportProfile) {
      state = PlatformTunnelLifecycleState.setupNeeded;
    } else {
      state = PlatformTunnelLifecycleState.failed;
    }
    return PlatformTunnelStatus(
      mode: result.mode,
      state: state,
      ready: result.ready,
      sessionId: result.sessionId,
      sourceResolutionId: (sourceResolutionId ?? '').trim(),
      executionPlan: result.executionPlan,
      transportProfile: result.transportProfile,
      providerTransportCompatibility: result.providerTransportCompatibility,
      remoteIngress: result.remoteIngress,
      dataplane: result.dataplane,
      underlayRoutePolicy: result.underlayRoutePolicy,
      stage: result.stage,
      missingPrerequisite: result.missingPrerequisite,
      startupAttemptId: result.startupAttemptId,
      message: result.message,
      updatedAt: _clock().toUtc(),
    );
  }

  void _rememberPlatformTunnelLocalStatus(PlatformTunnelStatus status) {
    final next = <PlatformTunnelStatus>[];
    var replaced = false;
    for (final existing in platformTunnelStatuses) {
      if (existing.mode == status.mode) {
        if (!replaced) {
          next.add(status);
          replaced = true;
        }
        continue;
      }
      next.add(existing);
    }
    if (!replaced) {
      next.add(status);
    }
    platformTunnelStatuses = next;
  }

  void _removePlatformTunnelLocalStatus(PlatformTunnelMode mode) {
    platformTunnelStatuses = platformTunnelStatuses
        .where((PlatformTunnelStatus status) {
          return status.mode != mode;
        })
        .toList(growable: false);
  }

  void _relocalizeReadyHostConnection() {
    final current = hostConnection;
    if (current == null || !current.isReady) {
      return;
    }
    final endpoint = _localHostEndpointFromMessage(current.message);
    if (endpoint == null) {
      return;
    }
    final message = current.launched && current.launchSpec != null
        ? _copy.launchedLocalHost(current.launchSpec!.description, endpoint)
        : _copy.connectedToLocalHost(endpoint);
    hostConnection = HostConnectionResult(
      state: current.state,
      message: message,
      info: current.info,
      launched: current.launched,
      launchSpec: current.launchSpec,
    );
  }

  String? _localHostEndpointFromMessage(String? message) {
    if (message == null || message.isEmpty) {
      return null;
    }
    final match = RegExp(r'([A-Za-z0-9._:-]+:\d+)$').firstMatch(message);
    final endpoint = match?.group(1)?.trim();
    return endpoint == null || endpoint.isEmpty ? null : endpoint;
  }

  String _platformTunnelNotice(PlatformTunnelStartResult result) {
    if (result.ready) {
      return _copy.platformTunnelReadyForLocalHost(result.mode.label);
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
      return _copy.startedResolutionForProviderWithExternalBrowser(
        resolutionId,
        descriptor.displayName,
      );
    }
    if (descriptor.mayRequireBrowserContinuation) {
      return _copy.startedResolutionForProviderWithBrowserContinuation(
        resolutionId,
        descriptor.displayName,
      );
    }
    return _copy.startedResolutionForProvider(
      resolutionId,
      descriptor.displayName,
    );
  }

  String _challengeContinuedNotice(ChallengeRecord challenge) {
    final descriptor = descriptorForProvider(challenge.provider);
    if (descriptor == null) {
      return _copy.continuedChallenge(challenge.id);
    }
    if (descriptor.browserPolicy == ProviderBrowserPolicy.externalRequired) {
      return _copy.continuedChallengeWithExternalBrowser(
        challenge.id,
        descriptor.displayName,
      );
    }
    if ((challenge.resolutionId ?? '').isNotEmpty) {
      return _copy.continuedChallengeForResolution(
        challenge.id,
        descriptor.displayName,
      );
    }
    return _copy.continuedChallengeForSession(
      challenge.id,
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
    final rawProvider = candidate.provider.trim();
    final supported = rawProvider.isEmpty
        ? (supportedProviderCatalog.isEmpty
              ? null
              : supportedProviderCatalog.first)
        : supportedProviderDefinitionFor(rawProvider);
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
    return _copy.desktopProviderSettingsRuntimeUnsupported(
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
      return _copy.desktopReusableSettingsRuntimeUnsupported(
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
                message: _copy.desktopReusableSettingsRuntimeUnsupported(
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

  void _notify() {
    if (_disposed) {
      return;
    }
    _bump(shellChromeRevision);
    _bump(workflowRevision);
    _bump(inspectorRevision);
    notifyListeners();
  }

  void _notifyWorkflow() {
    if (_disposed) {
      return;
    }
    _bump(workflowRevision);
    notifyListeners();
  }

  void _notifyInspector({bool layoutChanged = false}) {
    if (_disposed) {
      return;
    }
    if (layoutChanged) {
      _bump(inspectorLayoutRevision);
    }
    _bump(inspectorRevision);
    notifyListeners();
  }

  void _bump(ValueNotifier<int> notifier) {
    notifier.value = notifier.value + 1;
  }

  void _showCanvasRouteForSection(
    DesktopShellSection section,
    DesktopCanvasRoute route,
  ) {
    activeSection = section;
    activeCanvasRoute = route;
    _canvasRouteReturnTarget = null;
  }

  void _showSectionWorkbench(
    DesktopShellSection section, {
    bool notify = true,
  }) {
    _showCanvasRouteForSection(section, _defaultRouteForSection(section));
    activeWorkbenchRoute = _workbenchRouteForSection(section);
    if (notify) {
      _notifyWorkflow();
    }
  }

  void _showEditorWorkbench(DesktopShellSection section, {bool notify = true}) {
    _showCanvasRouteForSection(section, _editorRouteForSection(section));
    activeWorkbenchRoute = _workbenchRouteForSection(section);
    if (notify) {
      _notifyWorkflow();
    }
  }

  void _showWorkbenchRoute(
    DesktopWorkbenchRoute route, {
    bool closeInspectorIfOpen = false,
  }) {
    activeWorkbenchRoute = route;
    if (closeInspectorIfOpen && isInspectorOpen) {
      isInspectorOpen = false;
      _notify();
      return;
    }
    _notifyWorkflow();
  }

  void _openCanvasRoute(
    DesktopCanvasRoute route, {
    required DesktopCanvasRoute returnTarget,
  }) {
    activeSection = _sectionForCanvasRoute(route);
    activeCanvasRoute = route;
    _canvasRouteReturnTarget = returnTarget;
  }
}

DesktopCanvasRoute _editorRouteForSection(DesktopShellSection section) {
  return switch (section) {
    DesktopShellSection.profileWorkflow => DesktopCanvasRoute.profileEditor,
    DesktopShellSection.providerWorkflow =>
      DesktopCanvasRoute.managedProviderEditor,
  };
}

DesktopCanvasRoute _defaultRouteForSection(DesktopShellSection section) {
  return switch (section) {
    DesktopShellSection.profileWorkflow =>
      DesktopCanvasRoute.savedProfilePicker,
    DesktopShellSection.providerWorkflow =>
      DesktopCanvasRoute.managedProviderPicker,
  };
}

DesktopWorkbenchRoute _workbenchRouteForSection(DesktopShellSection section) {
  return switch (section) {
    DesktopShellSection.profileWorkflow => DesktopWorkbenchRoute.profiles,
    DesktopShellSection.providerWorkflow => DesktopWorkbenchRoute.providers,
  };
}

DesktopShellSection _sectionForCanvasRoute(DesktopCanvasRoute route) {
  return switch (route) {
    DesktopCanvasRoute.profileEditor ||
    DesktopCanvasRoute.savedProfilePicker ||
    DesktopCanvasRoute.managedProviderPickerForProfile =>
      DesktopShellSection.profileWorkflow,
    DesktopCanvasRoute.managedProviderEditor ||
    DesktopCanvasRoute.managedProviderPicker ||
    DesktopCanvasRoute.presetPicker ||
    DesktopCanvasRoute.providerFamilyPicker =>
      DesktopShellSection.providerWorkflow,
  };
}

int _managedProviderNameSort(
  ManagedProviderRecord left,
  ManagedProviderRecord right,
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

Future<Directory> _defaultDiagnosticsDirectory() async {
  final environment = Platform.environment;
  if (Platform.isWindows) {
    final appData = environment['APPDATA'] ?? environment['USERPROFILE'];
    if (appData != null && appData.isNotEmpty) {
      return Directory(
        _join(<String>[appData, 'vk-turn-proxy-go', 'diagnostics']),
      );
    }
  }

  final home = environment['HOME'];
  if (home != null && home.isNotEmpty) {
    return Directory(_join(<String>[home, '.vk-turn-proxy-go', 'diagnostics']));
  }
  return Directory(
    _join(<String>[Directory.systemTemp.path, 'vk-turn-proxy-go-diagnostics']),
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

String _formatNoticeTimestamp(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)} '
      '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}:${_twoDigits(local.second)}';
}

String _portableProfileSuggestedFilename(PortableProfileEnvelope envelope) {
  final rawName = envelope.displayName.trim();
  final safeSlug = _portableTransferSlug(rawName, fallback: 'profile');
  return '$safeSlug.portable-profile.json';
}

String _portableTransportProfileSuggestedFilename(
  PortableTransportProfileEnvelopeCarriage carriage,
) {
  final safeSlug = _portableTransferSlug(
    carriage.displayName,
    fallback: _portableTransportProfileKindLabel(
      carriage.profileKind,
    ).toLowerCase(),
  );
  return '$safeSlug.portable-transport-profile.json';
}

String _portableTransferSlug(String rawName, {required String fallback}) {
  final slug = rawName.trim().isEmpty
      ? fallback
      : rawName
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? fallback : slug;
}

String _portableTransportProfileDisplayLabel(
  String displayName,
  TransportProfileKind kind,
) {
  final trimmed = displayName.trim();
  if (trimmed.isNotEmpty) {
    return trimmed;
  }
  return _portableTransportProfileKindLabel(kind);
}

String _portableTransportProfileKindLabel(TransportProfileKind kind) {
  if (kind == TransportProfileKind.wireGuardNativeV1) {
    return 'WireGuard';
  }
  return kind.value;
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
