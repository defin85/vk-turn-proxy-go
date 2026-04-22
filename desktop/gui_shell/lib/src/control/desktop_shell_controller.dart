import 'dart:async';
import 'dart:io';

import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter_shell_core/portable_profile_transfer.dart';
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

enum ShellStatus { booting, ready, blocked }

enum DesktopWorkspaceSurface { profile, providerConfig, provider }

enum DesktopShellSection { profileWorkflow, providerWorkflow }

enum DesktopWorkbenchRoute {
  home,
  profiles,
  routing,
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

class DesktopShellController extends ChangeNotifier {
  DesktopShellController({
    required this.api,
    required this.supervisor,
    DesktopShellStateStore? stateStore,
    DirectoryProvider? diagnosticsDirectoryProvider,
    BrowserLauncher? browserLauncher,
    DesktopHandoffAdapter? handoffAdapter,
    DesktopPortableProfileTransferAdapter? portableProfileTransferAdapter,
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
       _stateStore = stateStore ?? FileDesktopShellStateStore(),
       _clock = clock ?? DateTime.now,
       appBuild = appBuild ?? AppBuildIdentity.current;

  final ControlPlaneApi api;
  final HostSupervisor supervisor;
  final DirectoryProvider _diagnosticsDirectoryProvider;
  final BrowserLauncher _browserLauncher;
  final DesktopHandoffAdapter _handoffAdapter;
  final DesktopPortableProfileTransferAdapter _portableProfileTransferAdapter;
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
  List<ManagedProviderRecord> managedProviders =
      const <ManagedProviderRecord>[];
  List<ProfileRecord> profiles = const <ProfileRecord>[];
  List<ResolutionRecord> resolutions = const <ResolutionRecord>[];
  List<SessionRecord> sessions = const <SessionRecord>[];
  List<EventRecord> events = const <EventRecord>[];
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

  bool get systemTunnelSupported =>
      platformTunnels.any((PlatformTunnelCapability capability) {
        return capability.available;
      });

  PlatformTunnelStartResult? platformTunnelResultFor(PlatformTunnelMode mode) {
    return _platformTunnelResults[mode];
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
    _showEditorRouteForSection(activeSection);
    _showWorkbenchRoute(DesktopWorkbenchRoute.profiles);
  }

  void showRouting() {
    _showWorkbenchRoute(DesktopWorkbenchRoute.routing);
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
    _showEditorRouteForSection(DesktopShellSection.profileWorkflow);
    _showWorkbenchRoute(DesktopWorkbenchRoute.profiles);
  }

  void showProviderWorkflow() {
    _showEditorRouteForSection(DesktopShellSection.providerWorkflow);
    _showWorkbenchRoute(DesktopWorkbenchRoute.profiles);
  }

  void openSavedProfilePicker() {
    _openCanvasRoute(
      DesktopCanvasRoute.savedProfilePicker,
      returnTarget: DesktopCanvasRoute.profileEditor,
    );
    _notifyWorkflow();
  }

  void openManagedProviderPickerForProfile() {
    _openCanvasRoute(
      DesktopCanvasRoute.managedProviderPickerForProfile,
      returnTarget: DesktopCanvasRoute.profileEditor,
    );
    _notifyWorkflow();
  }

  void openManagedProviderPicker() {
    _openCanvasRoute(
      DesktopCanvasRoute.managedProviderPicker,
      returnTarget: DesktopCanvasRoute.managedProviderEditor,
    );
    _notifyWorkflow();
  }

  void openPresetPicker() {
    _openCanvasRoute(
      DesktopCanvasRoute.presetPicker,
      returnTarget: DesktopCanvasRoute.managedProviderEditor,
    );
    _notifyWorkflow();
  }

  void openProviderFamilyPicker() {
    _openCanvasRoute(
      DesktopCanvasRoute.providerFamilyPicker,
      returnTarget: DesktopCanvasRoute.managedProviderEditor,
    );
    _notifyWorkflow();
  }

  void returnFromCanvasRoute() {
    final returnTarget =
        _canvasRouteReturnTarget ?? _editorRouteForSection(activeSection);
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
      resolutions = const <ResolutionRecord>[];
      sessions = const <SessionRecord>[];
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
      final nextProfiles = await api.profiles();
      final nextResolutions = await api.resolutions();
      final nextSessions = await api.sessions();
      final nextChallenges = await _loadActiveChallenges(
        nextSessions,
        nextResolutions,
      );

      providerDescriptors = nextProviders;
      managedProviders = _overlayManagedProviders(managedProviders);
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

      _scheduleStatePersist();
      _notify();
    } catch (error) {
      await _handleHostFailure(error);
    }
  }

  void selectProfile(String profileId, {bool showWorkbench = true}) {
    _restoredState = true;
    if (showWorkbench) {
      _showEditorRouteForSection(DesktopShellSection.profileWorkflow);
      activeWorkbenchRoute = DesktopWorkbenchRoute.profiles;
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
    _showEditorRouteForSection(DesktopShellSection.profileWorkflow);
    activeWorkbenchRoute = DesktopWorkbenchRoute.profiles;
    draft = _normalizeDraft(nextDraft);
    materializeDefaults = RuntimeDefaults.fromProfileSpec(draft.spec);
    _scheduleStatePersist();
    _notifyWorkflow();
  }

  void useCustomProviderForDraft() {
    _restoredState = true;
    _showEditorRouteForSection(DesktopShellSection.profileWorkflow);
    activeWorkbenchRoute = DesktopWorkbenchRoute.profiles;
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
    _showEditorRouteForSection(DesktopShellSection.profileWorkflow);
    activeWorkbenchRoute = DesktopWorkbenchRoute.profiles;
    selectedProfileId = null;
    draft = _defaultDraft();
    materializeDefaults = RuntimeDefaults.fromProfileSpec(draft.spec);
    _scheduleStatePersist();
    _notifyWorkflow();
  }

  void selectManagedProvider(String providerId) {
    _showEditorRouteForSection(DesktopShellSection.providerWorkflow);
    activeWorkbenchRoute = DesktopWorkbenchRoute.profiles;
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
    _showEditorRouteForSection(DesktopShellSection.providerWorkflow);
    activeWorkbenchRoute = DesktopWorkbenchRoute.profiles;
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
    _showEditorRouteForSection(DesktopShellSection.providerWorkflow);
    activeWorkbenchRoute = DesktopWorkbenchRoute.profiles;
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
    activeWorkbenchRoute = DesktopWorkbenchRoute.profiles;
    _openCanvasRoute(
      DesktopCanvasRoute.providerFamilyPicker,
      returnTarget: DesktopCanvasRoute.managedProviderEditor,
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
      _showEditorRouteForSection(DesktopShellSection.providerWorkflow);
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
      _showEditorRouteForSection(DesktopShellSection.profileWorkflow);
      activeWorkbenchRoute = DesktopWorkbenchRoute.profiles;
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
      _showEditorRouteForSection(DesktopShellSection.providerWorkflow);
      activeWorkbenchRoute = DesktopWorkbenchRoute.profiles;
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
    _showEditorRouteForSection(DesktopShellSection.profileWorkflow);
    activeWorkbenchRoute = DesktopWorkbenchRoute.profiles;
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
      if (descriptor.inputKind != ProviderInputKind.link) {
        notice = _copy.providerExpectsLinkEntryOnlyDesktop(
          providerName: descriptor.displayName,
          inputKind: descriptor.inputKind.value,
        );
        return;
      }
      final blockReason = _providerSettingsBlockReason(descriptor);
      if (blockReason != null) {
        notice = blockReason;
        return;
      }
      final resolution = await api.startResolution(
        provider: descriptor.id,
        input: ProviderInputEnvelope(
          kind: descriptor.inputKind,
          link: draft.spec.link,
        ),
        providerSettings: descriptor.normalizeProviderSettings(
          draft.spec.providerSettings,
          applyDefaults: false,
        ),
      );
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

  Future<void> startPlatformTunnel(PlatformTunnelMode mode) async {
    await _runMutation(() async {
      final capability = _platformTunnelCapabilityFor(mode);
      if (capability == null) {
        notice = _copy.desktopNoPlatformTunnelModesReported;
        return;
      }
      if (!capability.available) {
        final message = capability.message.trim();
        notice = message.isNotEmpty
            ? message
            : _copy.desktopTypedHostTunnelSummary;
        return;
      }
      final result = await api.startPlatformTunnel(
        mode: mode,
        resolutionId: _platformTunnelResolutionIdFor(mode),
        runtimeDefaults: _platformTunnelRuntimeDefaultsFor(mode),
        executionPlan: _defaultPlatformTunnelExecutionPlan(capability),
        underlayRoutePolicy: _defaultPlatformTunnelUnderlayRoutePolicy(
          capability,
        ),
      );
      _platformTunnelResults[mode] = result;
      notice = _platformTunnelNotice(result);
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
    for (final descriptor in capability.executionPlans) {
      if (descriptor.isDefault) {
        return descriptor.plan;
      }
    }
    if (capability.executionPlans.length == 1) {
      return capability.executionPlans.first.plan;
    }
    return null;
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
    return mode == PlatformTunnelMode.windowsWintun;
  }

  bool _platformTunnelModeRequiresRuntimeDefaults(PlatformTunnelMode mode) {
    return mode == PlatformTunnelMode.windowsWintun;
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

  void _showEditorRouteForSection(DesktopShellSection section) {
    activeSection = section;
    activeCanvasRoute = _editorRouteForSection(section);
    _canvasRouteReturnTarget = null;
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
