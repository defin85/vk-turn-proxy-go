import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gui_shell/src/build/app_build_identity.dart';
import 'package:gui_shell/src/control/control_plane_client.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/desktop_handoff_adapter.dart';
import 'package:gui_shell/src/control/desktop_host_supervisor.dart';
import 'package:gui_shell/src/control/profile_draft.dart';
import 'package:gui_shell/src/control/shell_state_store.dart';

typedef DirectoryProvider = Future<Directory> Function();

enum ShellStatus { booting, ready, blocked }

enum DesktopWorkspaceSurface { profile, providerConfig, provider }

enum DesktopShellSection { profileWorkflow, providerWorkflow }

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
    DateTime Function()? clock,
    BuildIdentity? appBuild,
  }) : _diagnosticsDirectoryProvider =
           diagnosticsDirectoryProvider ?? _defaultDiagnosticsDirectory,
       _browserLauncher = browserLauncher ?? const DesktopBrowserLauncher(),
       _handoffAdapter =
           handoffAdapter ?? const ClipboardDesktopHandoffAdapter(),
       _stateStore = stateStore ?? FileDesktopShellStateStore(),
       _clock = clock ?? DateTime.now,
       appBuild = appBuild ?? AppBuildIdentity.current;

  final ControlPlaneApi api;
  final HostSupervisor supervisor;
  final DirectoryProvider _diagnosticsDirectoryProvider;
  final BrowserLauncher _browserLauncher;
  final DesktopHandoffAdapter _handoffAdapter;
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
  bool _suppressEventStreamClosure = false;
  String? _persistedStateSignature;
  bool _restoredState = false;

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

  DesktopWorkspaceSurface get workspaceSurface =>
      activeSection == DesktopShellSection.providerWorkflow
      ? DesktopWorkspaceSurface.providerConfig
      : DesktopWorkspaceSurface.profile;

  bool get hasLiveWork => resolutions.isNotEmpty || sessions.isNotEmpty;

  ProviderConfigDraft get providerConfigDraft =>
      ProviderConfigDraft.fromJson(managedProviderDraft.toJson());

  String? get selectedProviderConfigId => selectedManagedProviderId;

  ProviderDescriptor? get activeProviderConfigDescriptor =>
      activeManagedProviderDescriptor;

  void showProfileWorkflow() {
    activeSection = DesktopShellSection.profileWorkflow;
    _notifyWorkflow();
  }

  void showProviderWorkflow() {
    activeSection = DesktopShellSection.providerWorkflow;
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
        selectProfile(profiles.first.id);
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

  void selectProfile(String profileId) {
    _restoredState = true;
    activeSection = DesktopShellSection.profileWorkflow;
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
    activeSection = DesktopShellSection.profileWorkflow;
    draft = _normalizeDraft(nextDraft);
    materializeDefaults = RuntimeDefaults.fromProfileSpec(draft.spec);
    _scheduleStatePersist();
    _notifyWorkflow();
  }

  void useCustomProviderForDraft() {
    _restoredState = true;
    activeSection = DesktopShellSection.profileWorkflow;
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
      notice = 'No managed providers are available yet.';
      _notify();
      return;
    }
    useManagedProviderForDraft(preferred);
  }

  void resetDraft() {
    _restoredState = true;
    activeSection = DesktopShellSection.profileWorkflow;
    selectedProfileId = null;
    draft = _defaultDraft();
    materializeDefaults = RuntimeDefaults.fromProfileSpec(draft.spec);
    _scheduleStatePersist();
    _notifyWorkflow();
  }

  void selectManagedProvider(String providerId) {
    activeSection = DesktopShellSection.providerWorkflow;
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
    activeSection = DesktopShellSection.providerWorkflow;
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
    activeSection = DesktopShellSection.providerWorkflow;
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

  void resetProviderConfigDraft({String? preferredProvider}) {
    resetManagedProviderDraft(preferredProvider: preferredProvider);
  }

  Future<void> saveDraft() async {
    await _runMutation(() async {
      final descriptor = activeProviderDescriptor;
      if (descriptor == null) {
        notice =
            'The selected provider is not advertised by the connected host.';
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
      notice = 'Saved profile ${saved.name.isEmpty ? saved.id : saved.name}.';
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
      notice =
          'Saved managed provider ${saved.name.isEmpty ? saved.id : saved.name}.';
      activeSection = DesktopShellSection.providerWorkflow;
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
      notice = 'Deleted profile $profileId.';
      resetDraft();
      await refresh();
    });
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
      notice = 'Deleted managed provider $providerId.';
      selectedManagedProviderId = null;
      managedProviderDraft = _defaultManagedProviderDraft();
      activeSection = DesktopShellSection.providerWorkflow;
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
      notice = 'Started session ${session.id}.';
      await refresh();
    });
  }

  void useManagedProviderForDraft(String managedProviderId) {
    final provider = managedProviderById(managedProviderId);
    if (provider == null) {
      notice = 'Managed provider $managedProviderId is no longer available.';
      _notify();
      return;
    }
    activeSection = DesktopShellSection.profileWorkflow;
    draft = _normalizeDraft(draft.applyManagedProvider(provider));
    selectedManagedProviderId = managedProviderId;
    materializeDefaults = RuntimeDefaults.fromProfileSpec(draft.spec);
    notice =
        'Applied managed provider ${provider.name.isEmpty ? provider.id : provider.name} to the active profile draft.';
    _scheduleStatePersist();
    _notifyWorkflow();
  }

  void applyProviderConfigToDraft(String configId) {
    useManagedProviderForDraft(configId);
  }

  void applyPreset(ProviderPreset preset) {
    resetManagedProviderDraft(preset: preset);
    notice =
        'Seeded a new managed provider draft from the ${preset.title} preset.';
    _notifyWorkflow();
  }

  Future<void> startResolutionFromDraft() async {
    await _runMutation(() async {
      final descriptor = activeProviderDescriptor;
      if (descriptor == null) {
        notice =
            'The selected provider is not advertised by the connected host.';
        return;
      }
      if (descriptor.inputKind != ProviderInputKind.link) {
        notice =
            '${descriptor.displayName} expects ${descriptor.inputKind.value} input. This desktop shell currently supports link entry only.';
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
      notice = 'Cancelled resolution ${resolution.id}.';
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
      notice =
          'Started session ${session.id} from resolution $resolutionId. Ready is reported only after runtime startup succeeds.';
      await refresh();
    });
  }

  Future<void> copyResolutionExport(String resolutionId) async {
    await _runMutation(() async {
      final exported = await api.exportResolution(resolutionId);
      await _handoffAdapter.copyLink(exported.link);
      selectedResolutionId = resolutionId;
      notice =
          'Copied handoff link for $resolutionId. Expires ${_formatNoticeTimestamp(exported.expiresAt)}.';
    });
  }

  Future<void> openResolutionExternalAction(
    String resolutionId,
    ArtifactAction action,
  ) async {
    await _runMutation(() async {
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
    await _runMutation(() async {
      await api.stopSession(sessionId);
      notice = 'Stopped session $sessionId.';
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
      notice = 'Cancelled challenge $challengeId.';
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

      notice = 'Exported diagnostics to ${file.path}.';
      selectedSessionId = sessionId;
    });
  }

  Future<void> startPlatformTunnel(PlatformTunnelMode mode) async {
    await _runMutation(() async {
      final result = await api.startPlatformTunnel(mode: mode);
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
    shellChromeRevision.dispose();
    workflowRevision.dispose();
    inspectorLayoutRevision.dispose();
    inspectorRevision.dispose();
    unawaited(supervisor.dispose());
    super.dispose();
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
        if (_suppressEventStreamClosure || _disposed) {
          return;
        }
        unawaited(_handleHostFailure(error));
      },
      onDone: () {
        if (_disposed ||
            _suppressEventStreamClosure ||
            status != ShellStatus.ready) {
          return;
        }
        unawaited(
          _handleHostFailure(
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
      notice = hostConnection?.message ?? 'Local host is not ready.';
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

  Future<void> _stopRuntimeMonitoring() async {
    _suppressEventStreamClosure = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _persistTimer?.cancel();
    _persistTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _suppressEventStreamClosure = false;
  }

  Future<void> _handleHostFailure(
    Object error, {
    bool scheduleRecovery = true,
  }) async {
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
    if (_recoveringHost || _disposed) {
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
      if (state == null) {
        return;
      }
      profiles = state.profiles;
      managedProviders = state.managedProviders;
      profileBindings = state.profileBindings;
      selectedProfileId = state.selectedProfileId;
      draft = state.draft;
      materializeDefaults = state.runtimeDefaults;
      managedProviderDraft = _defaultManagedProviderDraft();
      _persistedStateSignature = state.signature();
      _restoredState = true;
    } catch (error) {
      notice = 'Failed to restore desktop shell state: $error';
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
      notice = 'Failed to persist desktop shell state: $error';
      _notify();
    }
  }

  void _clearPlatformTunnelResults() {
    _platformTunnelResults.clear();
  }

  String _platformTunnelNotice(PlatformTunnelStartResult result) {
    if (result.ready) {
      return '${result.mode.label} is ready for the local host tunnel path.';
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

  String _resolutionStartedNotice(
    ProviderDescriptor descriptor,
    String resolutionId,
  ) {
    if (descriptor.browserPolicy == ProviderBrowserPolicy.externalRequired) {
      return 'Started resolution $resolutionId for ${descriptor.displayName}. Finish the required external browser steps before expecting a resolved artifact.';
    }
    if (descriptor.mayRequireBrowserContinuation) {
      return 'Started resolution $resolutionId for ${descriptor.displayName}. Continue any browser challenge flow before expecting a resolved artifact.';
    }
    return 'Started resolution $resolutionId for ${descriptor.displayName}.';
  }

  String _challengeContinuedNotice(ChallengeRecord challenge) {
    final descriptor = descriptorForProvider(challenge.provider);
    if (descriptor == null) {
      return 'Continued challenge ${challenge.id}.';
    }
    if (descriptor.browserPolicy == ProviderBrowserPolicy.externalRequired) {
      return 'Continued challenge ${challenge.id}. Finish the external browser flow for ${descriptor.displayName} before expecting the next state transition.';
    }
    if ((challenge.resolutionId ?? '').isNotEmpty) {
      return 'Continued challenge ${challenge.id}. Finish the provider flow for ${descriptor.displayName} before expecting a resolved artifact.';
    }
    return 'Continued challenge ${challenge.id}. Finish the provider flow for ${descriptor.displayName} before expecting the session to reach ready.';
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
    return 'The connected desktop shell cannot render provider settings for ${descriptor.displayName}: $reason';
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
      return 'The connected desktop shell cannot render reusable settings for ${descriptor.displayName}: $schemaReason';
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
                    'The connected desktop shell cannot render reusable settings for ${descriptor.displayName}: $schemaReason',
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

String _twoDigits(int value) => value.toString().padLeft(2, '0');
