import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:mobile_gui_shell/src/build/app_build_identity.dart';
import 'package:mobile_gui_shell/src/control/control_plane_client.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/mobile_handoff_adapter.dart';
import 'package:mobile_gui_shell/src/control/mobile_host_bridge.dart';
import 'package:mobile_gui_shell/src/control/mobile_platform_app_inventory.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_state_store.dart';
import 'package:mobile_gui_shell/src/control/profile_draft.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

typedef DirectoryProvider = Future<Directory> Function();
typedef IDFactory = String Function();

enum ShellStatus { booting, ready, blocked }

enum MobileWorkflowSurface { profile, providerConfig, provider }

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

class MobileShellController extends ChangeNotifier {
  MobileShellController({
    required this.bridge,
    required this.stateStore,
    BrowserLauncher? browserLauncher,
    MobileHandoffAdapter? handoffAdapter,
    MobilePlatformAppInventory? appInventory,
    DirectoryProvider? diagnosticsDirectoryProvider,
    DateTime Function()? clock,
    IDFactory? idFactory,
    BuildIdentity? appBuild,
  }) : _browserLauncher = browserLauncher ?? ExternalBrowserLauncher(),
       _handoffAdapter = handoffAdapter ?? const SystemMobileHandoffAdapter(),
       _appInventory = appInventory ?? PlatformMobilePlatformAppInventory(),
       _diagnosticsDirectoryProvider =
           diagnosticsDirectoryProvider ?? defaultDiagnosticsDirectory,
       _clock = clock ?? DateTime.now,
       _idFactory =
           idFactory ??
           (() => DateTime.now().microsecondsSinceEpoch.toRadixString(16)),
       appBuild = appBuild ?? AppBuildIdentity.current;

  final MobileHostBridge bridge;
  final MobileShellStateStore stateStore;
  final BrowserLauncher _browserLauncher;
  final MobileHandoffAdapter _handoffAdapter;
  final MobilePlatformAppInventory _appInventory;
  final DirectoryProvider _diagnosticsDirectoryProvider;
  final DateTime Function() _clock;
  final IDFactory _idFactory;
  final BuildIdentity appBuild;

  static const String _draftModePreferenceScope = '__draft__';

  ShellStatus status = ShellStatus.booting;
  MobileHostConnectionResult? hostConnection;
  List<ProviderDescriptor> providerDescriptors = const <ProviderDescriptor>[];
  List<ManagedProviderRecord> managedProviders =
      const <ManagedProviderRecord>[];
  List<ProfileRecord> profiles = const <ProfileRecord>[];
  List<ResolutionRecord> resolutions = const <ResolutionRecord>[];
  List<SessionRecord> sessions = const <SessionRecord>[];
  List<EventRecord> events = const <EventRecord>[];
  ProfileDraft draft = ProfileDraft.defaults();
  ManagedProviderDraft managedProviderDraft = ManagedProviderDraft.defaults();
  MobileWorkflowSurface workflowSurface = MobileWorkflowSurface.profile;
  String? selectedProfileId;
  PlatformTunnelMode? selectedPlatformTunnelMode;
  String? selectedManagedProviderId;
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
  String? notice;
  bool busy = false;
  bool _requiresLocalStateReset = false;
  String? _blockedLocalStateMessage;

  final Map<String, ChallengeRecord> _challengeCache =
      <String, ChallengeRecord>{};
  StreamSubscription<EventRecord>? _eventSubscription;
  StreamSubscription<MobileBrowserReturnSignal>? _browserReturnSubscription;
  Timer? _pollTimer;
  Timer? _debounceTimer;
  Timer? _persistTimer;
  bool _disposed = false;
  String? _persistedStateSignature;
  String? _browserHandoffChallengeId;
  final Set<String> _autoContinuedChallengeIds = <String>{};

  static const List<Capability> requiredCapabilities = <Capability>[
    Capability.mobileHostBridge,
    Capability.platformTunnels,
    Capability.profiles,
    Capability.providerRuntimeArtifacts,
    Capability.runtimeExecutionPlanning,
    Capability.sessions,
    Capability.challenges,
    Capability.diagnostics,
    Capability.eventStream,
  ];

  bool get requiresLocalStateReset => _requiresLocalStateReset;

  String? get hostStatusMessage {
    final message = hostConnection?.message?.trim() ?? '';
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

  bool get activeModeSupportsAppRouting =>
      _modeSupportsAppRouting(activePlatformTunnelMode);

  bool get systemTunnelSupported =>
      platformTunnels.any((PlatformTunnelCapability capability) {
        return capability.available;
      });

  PlatformTunnelStartResult? platformTunnelResultFor(PlatformTunnelMode mode) {
    return _platformTunnelResults[mode];
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
          return descriptor.isSelectable;
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
          'Reset local mobile shell state before reconnecting.';
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
      final nextResolutions = _orderedResolutions(await bridge.resolutions());
      final nextSessions = _orderedSessions(await bridge.sessions());
      final nextChallenges = await _loadActiveChallenges(
        nextSessions,
        nextResolutions,
      );
      providerDescriptors = nextProviders;
      managedProviders = _overlayManagedProviders(managedProviders);
      resolutions = nextResolutions;
      draft = _normalizeDraft(draft);
      managedProviderDraft = _normalizeManagedProviderDraft(
        managedProviderDraft,
      );
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
          workflowSurface = MobileWorkflowSurface.profile;
        }
      }
      _normalizeSelectedPlatformTunnelMode();
      _notify();
    } catch (error) {
      await _handleBridgeFailure(error);
    }
  }

  void selectProfile(String profileId) {
    workflowSurface = MobileWorkflowSurface.profile;
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
    _clearSelectedResolutionSelection();
    _scheduleStatePersist();
    notifyListeners();
  }

  void selectSession(String sessionId) {
    selectedSessionId = sessionId;
    notifyListeners();
  }

  void selectResolution(String resolutionId) {
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
      notice = 'No managed providers are available yet.';
      _notify();
      return;
    }
    useManagedProviderForDraft(preferred);
  }

  void resetDraft() {
    workflowSurface = MobileWorkflowSurface.profile;
    selectedProfileId = null;
    draft = _defaultDraft();
    _clearSelectedResolutionSelection();
    _scheduleStatePersist();
    notifyListeners();
  }

  void showProfileWorkspace() {
    workflowSurface = MobileWorkflowSurface.profile;
    notifyListeners();
  }

  void showProviderWorkspace({String? preferredProvider}) {
    workflowSurface = MobileWorkflowSurface.providerConfig;
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

  Future<void> saveManagedProviderDraft() async {
    await _runBridgeMutation(() async {
      final supported = supportedProviderDefinitionFor(
        managedProviderDraft.provider,
      );
      if (supported == null) {
        notice =
            'The selected managed provider family is not part of the supported app catalog.';
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
      notice =
          'Saved managed provider ${saved.name.isEmpty ? saved.id : saved.name}.';
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
      notice = 'Deleted managed provider $providerId.';
      selectedManagedProviderId = null;
      managedProviderDraft = _defaultManagedProviderDraft();
      workflowSurface = MobileWorkflowSurface.profile;
      _scheduleStatePersist();
    });
  }

  Future<void> deleteSelectedProviderConfig() async {
    await deleteSelectedManagedProvider();
  }

  void useManagedProviderForDraft(String managedProviderId) {
    final provider = managedProviderById(managedProviderId);
    if (provider == null) {
      notice = 'Managed provider $managedProviderId is no longer available.';
      _notify();
      return;
    }
    workflowSurface = MobileWorkflowSurface.profile;
    draft = _normalizeDraft(draft.applyManagedProvider(provider));
    selectedManagedProviderId = managedProviderId;
    _clearSelectedResolutionSelection();
    notice =
        'Applied managed provider ${provider.name.isEmpty ? provider.id : provider.name} to the active mobile profile draft.';
    _scheduleStatePersist();
    _notify();
  }

  void applyProviderConfigToDraft(String configId) {
    useManagedProviderForDraft(configId);
  }

  void applyPreset(ProviderPreset preset) {
    resetManagedProviderDraft(preset: preset);
    notice =
        'Seeded a new managed provider draft from the ${preset.title} preset.';
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
      providerDescriptors = const <ProviderDescriptor>[];
      profiles = const <ProfileRecord>[];
      resolutions = const <ResolutionRecord>[];
      sessions = const <SessionRecord>[];
      events = const <EventRecord>[];
      draft = ProfileDraft.defaults();
      managedProviderDraft = ManagedProviderDraft.defaults();
      workflowSurface = MobileWorkflowSurface.profile;
      selectedProfileId = null;
      selectedPlatformTunnelMode = null;
      selectedManagedProviderId = null;
      profileBindings = <String, ProfileProviderBinding>{};
      platformModePreferences = <String, MobilePlatformModePreferences>{};
      selectedResolutionId = null;
      selectedSessionId = null;
      installedApps = const <MobilePlatformApp>[];
      installedAppsError = null;
      _persistedStateSignature = MobileShellState.empty().signature();
      _requiresLocalStateReset = false;
      _blockedLocalStateMessage = null;
      notice = 'Cleared local mobile shell state.';
      hostConnection = null;
      status = ShellStatus.booting;
    } catch (error) {
      notice = 'Failed to clear local mobile shell state: $error';
      status = ShellStatus.blocked;
      busy = false;
      _notify();
      return;
    }
    busy = false;
    _notify();
    await _connectBridge();
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
      final persistedDraftProfileId = selectedProfileId?.trim() ?? '';
      final descriptor = activeProviderDescriptor;
      if (descriptor == null) {
        notice =
            'The selected provider is not advertised by the connected mobile host.';
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
      selectProfile(profile.id);
      notice =
          'Saved mobile profile ${profile.name.isEmpty ? profile.id : profile.name}.';
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
    final profileId = selectedProfileId;
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
      resetDraft();
      notice = 'Deleted mobile profile $profileId.';
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

  Future<void> startSelectedProfile() async {
    final profileId = selectedProfileId;
    if (profileId == null) {
      return;
    }
    await _runBridgeMutation(() async {
      final session = await bridge.startSession(profileId: profileId);
      selectedSessionId = session.id;
      notice = 'Started mobile session ${session.id}.';
      await refresh();
    });
  }

  Future<void> startResolutionFromDraft() async {
    await _runBridgeMutation(() async {
      final descriptor = activeProviderDescriptor;
      if (descriptor == null) {
        notice =
            'The selected provider is not advertised by the connected mobile host.';
        return;
      }
      final resolution = await _startResolutionForCurrentDraft(descriptor);
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
      notice = 'Cancelled mobile resolution ${resolution.id}.';
      await refresh();
    });
  }

  Future<void> materializeResolution(String resolutionId) async {
    await _runBridgeMutation(() async {
      final resolution = _resolutionById(resolutionId);
      if (resolution == null) {
        notice = 'Resolution $resolutionId is no longer available.';
        return;
      }
      final advertised = resolution.artifact?.action(
        ArtifactAction.startOnThisDevice,
      );
      if (advertised == null ||
          advertised.executionOwner != ActionExecutionOwner.host) {
        notice =
            'Resolution $resolutionId does not advertise ${ArtifactAction.startOnThisDevice.label.toLowerCase()}.';
        return;
      }
      final session = await bridge.materializeResolution(
        resolutionId: resolutionId,
        runtimeDefaults: RuntimeDefaults.fromProfileSpec(draft.spec),
      );
      selectedResolutionId = resolutionId;
      selectedSessionId = session.id;
      notice =
          'Started mobile session ${session.id} from resolution $resolutionId. Ready is reported only after runtime startup succeeds.';
      await refresh();
    });
  }

  Future<void> copyResolutionExport(String resolutionId) async {
    await _runBridgeMutation(() async {
      final exported = await bridge.exportResolution(resolutionId);
      await _handoffAdapter.copyLink(exported.link);
      selectedResolutionId = resolutionId;
      notice =
          'Copied handoff link for $resolutionId. Expires ${_formatNoticeTimestamp(exported.expiresAt)}.';
    });
  }

  Future<void> shareResolutionExport(String resolutionId) async {
    await _runBridgeMutation(() async {
      final exported = await bridge.exportResolution(resolutionId);
      await _handoffAdapter.shareLink(exported.link);
      selectedResolutionId = resolutionId;
      notice =
          'Shared handoff link for $resolutionId. Expires ${_formatNoticeTimestamp(exported.expiresAt)}.';
    });
  }

  Future<void> openResolutionExternalAction(
    String resolutionId,
    ArtifactAction action,
  ) async {
    await _runBridgeMutation(() async {
      final resolution = _resolutionById(resolutionId);
      if (resolution == null) {
        notice = 'Resolution $resolutionId is no longer available.';
        return;
      }
      final advertised = resolution.artifact?.action(action);
      if (advertised == null ||
          advertised.executionOwner != ActionExecutionOwner.shellExternal) {
        notice =
            'Resolution $resolutionId does not advertise ${action.label.toLowerCase()}.';
        return;
      }
      final targetUrl = resolution.externalTargetUrl(action);
      if (targetUrl == null) {
        notice =
            'Resolution $resolutionId does not expose a browser target for ${action.label.toLowerCase()}.';
        return;
      }
      final opened = await _browserLauncher.open(targetUrl);
      final targetLabel = _externalActionTargetLabel(action);
      selectedResolutionId = resolutionId;
      notice = opened
          ? 'Opened $targetLabel for $resolutionId.'
          : 'Failed to open $targetLabel for $resolutionId.';
    });
  }

  Future<void> stopSession(String sessionId) async {
    await _runBridgeMutation(() async {
      await bridge.stopSession(sessionId);
      notice = 'Stopped session $sessionId.';
      await refresh();
    });
  }

  Future<void> openChallengeInBrowser(ChallengeRecord challenge) async {
    final url = challenge.openUrl?.trim() ?? '';
    if (url.isEmpty) {
      notice = 'This challenge does not expose a browser handoff URL.';
      _notify();
      return;
    }
    final opened = await _browserLauncher.open(url);
    if (opened) {
      _browserHandoffChallengeId = challenge.id;
    }
    notice = opened
        ? 'Opened mobile browser handoff for ${challenge.kind}. Return here after the browser step.'
        : 'Failed to open the mobile browser handoff URL.';
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
      notice = noticeOverride ?? 'Cancelled challenge $challengeId.';
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

      notice = 'Exported diagnostics to ${file.path}.';
      selectedSessionId = sessionId;
    });
  }

  Future<void> startPlatformTunnel(PlatformTunnelMode mode) async {
    await _runBridgeMutation(() async {
      final executionPlan = _resolvedExecutionPlanForMode(mode);
      if (executionPlan == null) {
        notice = _executionPlanSelectionRequiredMessage(mode);
        return;
      }
      final runtimeDefaults = RuntimeDefaults.fromProfileSpec(draft.spec);
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
      final resolutionId = await _ensureResolutionForPlatformTunnel(mode);
      if (resolutionId == null) {
        return;
      }
      var result = await bridge.startPlatformTunnel(
        mode: mode,
        resolutionId: resolutionId,
        runtimeDefaults: runtimeDefaults,
        executionPlan: executionPlan,
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
      );
      if (_requiresPlatformTunnelPermissionResume(mode, result)) {
        await bridge.requestPlatformTunnelPermission(mode: mode);
        result = await bridge.resumePlatformTunnel(
          startupAttemptId: result.startupAttemptId,
        );
      }
      _platformTunnelResults[mode] = result;
      notice = _platformTunnelNotice(result);
    });
  }

  Future<void> stopPlatformTunnel(PlatformTunnelMode mode) async {
    await _runBridgeMutation(() async {
      final result = await bridge.stopPlatformTunnel(mode: mode);
      _platformTunnelResults.remove(mode);
      final message = result.message.trim();
      notice = message.isEmpty ? '${mode.label} disconnected.' : message;
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

  Future<ResolutionRecord?> _startResolutionForCurrentDraft(
    ProviderDescriptor descriptor,
  ) async {
    if (descriptor.inputKind != ProviderInputKind.link) {
      notice =
          '${descriptor.displayName} expects ${descriptor.inputKind.value} input. This mobile shell currently supports link entry only.';
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
        link: draft.spec.link,
      ),
      providerSettings: descriptor.normalizeProviderSettings(
        draft.spec.providerSettings,
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
          return selectedResolution.id;
        case ResolutionState.challengeRequired:
          notice =
              'Complete the current provider challenge before starting ${mode.label}.';
          return null;
        case ResolutionState.starting:
          notice =
              'Wait for the current provider resolution before starting ${mode.label}.';
          return null;
        case ResolutionState.failed ||
            ResolutionState.cancelled ||
            ResolutionState.expired:
          _clearSelectedResolutionSelection();
          break;
      }
    }

    final descriptor = activeProviderDescriptor;
    if (descriptor == null) {
      notice =
          'The selected provider is not advertised by the connected mobile host.';
      return null;
    }
    final resolution = await _startResolutionForCurrentDraft(descriptor);
    if (resolution == null) {
      return null;
    }
    selectedResolutionId = resolution.id;
    await refresh();
    final refreshedResolution = _resolutionById(resolution.id) ?? resolution;
    switch (refreshedResolution.state) {
      case ResolutionState.resolved:
        return refreshedResolution.id;
      case ResolutionState.challengeRequired:
        notice =
            '${_resolutionStartedNotice(descriptor, refreshedResolution.id)} Complete the current provider challenge before starting ${mode.label}.';
        return null;
      case ResolutionState.starting:
        notice =
            '${_resolutionStartedNotice(descriptor, refreshedResolution.id)} Wait for the resolution to finish before starting ${mode.label}.';
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

  String _externalActionTargetLabel(ArtifactAction action) {
    return action.label.replaceFirst(RegExp(r'^Open\s+'), '').toLowerCase();
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

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _persistTimer?.cancel();
    _pollTimer?.cancel();
    _eventSubscription?.cancel();
    _browserReturnSubscription?.cancel();
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
            const ControlPlaneError(
              statusCode: 0,
              code: 'connection_closed',
              message: 'event stream closed',
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
        ? 'Detected ${_browserReturnSignalLabel(signalKind)} and continued challenge $challengeId.'
        : (browserContinuation != null
              ? 'Completed the in-app browser continuation for challenge $challengeId.'
              : 'Continued challenge $challengeId.');
    await refresh();
  }

  bool challengeRequiresOwnedBrowser(ChallengeRecord challenge) =>
      challenge.completionMode ==
          ChallengeCompletionMode.ownedBrowserObserved &&
      challenge.ownedBrowser != null &&
      challenge.ownedBrowser!.cookieUrls.isNotEmpty;

  String _localStateResetBlockMessage() {
    return _blockedLocalStateMessage ??
        'Reset local mobile shell state before runtime control can continue.';
  }

  String _browserReturnSignalLabel(BrowserReturnSignalKind? signalKind) {
    return switch (signalKind) {
      BrowserReturnSignalKind.appLink => 'app-link browser return',
      BrowserReturnSignalKind.universalLink => 'universal-link browser return',
      BrowserReturnSignalKind.foregroundResume =>
        'browser return on app resume',
      null => 'browser return',
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
      notice = hostConnection?.message ?? 'Mobile host bridge is not ready.';
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
      if (state == null) {
        return;
      }
      profiles = state.profiles;
      managedProviders = state.managedProviders;
      profileBindings = state.profileBindings;
      selectedProfileId = state.selectedProfileId;
      selectedPlatformTunnelMode = state.selectedPlatformTunnelMode;
      platformModePreferences = state.platformModePreferences;
      draft = state.draft;
      managedProviderDraft = _defaultManagedProviderDraft();
      _persistedStateSignature = state.signature();
    } catch (error) {
      _requiresLocalStateReset = true;
      _blockedLocalStateMessage =
          'Failed to restore mobile shell state: $error';
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
      profileBindings: profileBindings,
      selectedProfileId: selectedProfileId,
      selectedPlatformTunnelMode: selectedPlatformTunnelMode,
      platformModePreferences: platformModePreferences,
      draft: draft,
    );
    final sanitized = next.sanitizedForPersistence(providerDescriptors);
    final signature = sanitized.signature();
    if (signature == _persistedStateSignature) {
      return;
    }
    try {
      await stateStore.save(sanitized);
      _persistedStateSignature = signature;
    } catch (error) {
      notice = 'Failed to persist mobile shell state: $error';
      _notify();
    }
  }

  void _clearPlatformTunnelResults() {
    _platformTunnelResults.clear();
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
      return '${result.mode.label} is ready for the mobile host tunnel path.';
    }
    final buffer = StringBuffer(
      '${result.mode.label} blocked at ${result.stage?.label ?? 'Unknown stage'}.',
    );
    if (result.missingPrerequisite != null) {
      buffer.write(
        ' Missing prerequisite: ${result.missingPrerequisite!.label}.',
      );
    }
    if (result.message.isNotEmpty) {
      buffer.write(' ${result.message}');
    }
    return buffer.toString();
  }

  String _resolutionUnavailableForPlatformTunnelNotice(
    PlatformTunnelMode mode,
    ResolutionRecord resolution,
  ) {
    final stage = resolution.failure?.stage ?? resolution.state.value;
    final message =
        resolution.failure?.message ??
        'The provider did not return a startable artifact.';
    return 'Cannot start ${mode.label} because resolution ${resolution.id} ended at $stage: $message';
  }

  String _resolutionStartedNotice(
    ProviderDescriptor descriptor,
    String resolutionId,
  ) {
    if (descriptor.browserPolicy == ProviderBrowserPolicy.externalRequired) {
      return 'Started mobile resolution $resolutionId for ${descriptor.displayName}. Expect an external browser step when the provider requires it.';
    }
    if (descriptor.mayRequireBrowserContinuation) {
      return 'Started mobile resolution $resolutionId for ${descriptor.displayName}. Complete any browser continuation before expecting a resolved artifact.';
    }
    return 'Started mobile resolution $resolutionId for ${descriptor.displayName}.';
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
    return 'The connected mobile shell cannot render provider settings for ${descriptor.displayName}: $reason';
  }

  String? _managedProviderDraftBlockReason(ManagedProviderDraft provider) {
    final supported = supportedProviderDefinitionFor(provider.provider);
    if (supported == null) {
      return 'The selected managed provider is not part of the supported app catalog.';
    }
    final descriptor = descriptorForProvider(provider.provider);
    if (descriptor == null) {
      return null;
    }
    final schemaReason = descriptor.providerSettingsSupportError;
    if (schemaReason != null && provider.providerSettings.isNotEmpty) {
      return 'The connected mobile shell cannot render reusable settings for ${descriptor.displayName}: $schemaReason';
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
              availability: const ProviderConfigAvailability(
                state: ProviderConfigAvailabilityState.providerUnavailable,
                message:
                    'This managed provider is not part of the supported app catalog.',
              ),
            );
          }
          final descriptor = descriptorForProvider(provider.provider);
          if (descriptor == null) {
            return provider.copyWith(
              availability: ProviderConfigAvailability(
                state: ProviderConfigAvailabilityState.providerUnavailable,
                message:
                    'The connected host does not advertise the ${supported.title} provider family yet.',
              ),
            );
          }
          final schemaReason = descriptor.providerSettingsSupportError;
          if (schemaReason != null && provider.providerSettings.isNotEmpty) {
            return provider.copyWith(
              availability: ProviderConfigAvailability(
                state: ProviderConfigAvailabilityState.schemaUnsupported,
                message:
                    'The connected mobile shell cannot render reusable settings for ${descriptor.displayName}: $schemaReason',
              ),
            );
          }
          return provider.copyWith(
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
    final selected = selectedProfileId?.trim() ?? '';
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
      );
    }
    return MobilePlatformModePreferences(
      executionPlan: resolvedExecutionPlan,
      applicationRoutingPolicy:
          current?.applicationRoutingPolicy ??
          PlatformTunnelApplicationRoutingPolicy.allApps,
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
    return '${mode.label} still points to loopback peer $peerAddress. Configure an operator-managed remote peer endpoint before starting the mobile VPN path.';
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

  String? _routingSelectionBlockReason(
    PlatformTunnelMode mode,
    MobilePlatformModePreferences preferences,
  ) {
    switch (_effectiveRoutingPolicyForMode(mode, preferences)) {
      case PlatformTunnelApplicationRoutingPolicy.allApps:
        return null;
      case PlatformTunnelApplicationRoutingPolicy.allowedPackages:
        return _effectiveAllowedPackagesForMode(mode, preferences).isEmpty
            ? 'Select at least one app before starting ${mode.label} in included-apps mode.'
            : null;
      case PlatformTunnelApplicationRoutingPolicy.disallowedPackages:
        return _effectiveDisallowedPackagesForMode(mode, preferences).isEmpty
            ? 'Select at least one app before starting ${mode.label} in excluded-apps mode.'
            : null;
    }
  }

  String _executionPlanSelectionRequiredMessage(PlatformTunnelMode mode) {
    final capability = capabilityForMode(mode);
    if (capability == null) {
      return 'The selected mobile mode is not advertised by the connected host.';
    }
    if (capability.executionPlans.isEmpty) {
      return '${mode.label} does not advertise a supported execution path yet.';
    }
    return 'Select an execution path before starting ${mode.label}.';
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

  void _clearSelectedResolutionSelection() {
    selectedResolutionId = null;
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
  final next = current.toSet();
  if (selected) {
    next.add(packageName);
  } else {
    next.remove(packageName);
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

String _twoDigits(int value) => value.toString().padLeft(2, '0');
