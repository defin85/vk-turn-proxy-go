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

  ShellStatus status = ShellStatus.booting;
  HostConnectionResult? hostConnection;
  List<ProviderDescriptor> providerDescriptors = const <ProviderDescriptor>[];
  List<ProfileRecord> profiles = const <ProfileRecord>[];
  List<ResolutionRecord> resolutions = const <ResolutionRecord>[];
  List<SessionRecord> sessions = const <SessionRecord>[];
  List<EventRecord> events = const <EventRecord>[];
  ProfileDraft draft = ProfileDraft.defaults();
  RuntimeDefaults materializeDefaults = const RuntimeDefaults(
    listenAddress: '127.0.0.1:9001',
    peerAddress: '127.0.0.1:56000',
  );
  String? selectedProfileId;
  String? selectedResolutionId;
  String? selectedSessionId;
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
      profiles = nextProfiles;
      resolutions = nextResolutions;
      sessions = nextSessions;
      _mergeChallenges(nextChallenges);

      draft = _normalizeDraft(draft);

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
    selectedProfileId = profileId;
    final selected = profiles.firstWhere(
      (ProfileRecord profile) => profile.id == profileId,
      orElse: () => ProfileDraft.defaults().toProfile(),
    );
    draft = _normalizeDraft(ProfileDraft.fromProfile(selected));
    materializeDefaults = RuntimeDefaults.fromProfileSpec(selected.spec);
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

  void updateDraft(ProfileDraft nextDraft) {
    _restoredState = true;
    draft = _normalizeDraft(nextDraft);
    materializeDefaults = RuntimeDefaults.fromProfileSpec(draft.spec);
    _scheduleStatePersist();
    notifyListeners();
  }

  void resetDraft() {
    _restoredState = true;
    selectedProfileId = null;
    draft = _defaultDraft();
    materializeDefaults = RuntimeDefaults.fromProfileSpec(draft.spec);
    _scheduleStatePersist();
    notifyListeners();
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
      notice = 'Saved profile ${saved.name.isEmpty ? saved.id : saved.name}.';
      await refresh();
      selectProfile(saved.id);
    });
  }

  Future<void> deleteSelectedProfile() async {
    final profileId = selectedProfileId;
    if (profileId == null) {
      return;
    }
    await _runMutation(() async {
      await api.deleteProfile(profileId);
      notice = 'Deleted profile $profileId.';
      resetDraft();
      await refresh();
    });
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

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _persistTimer?.cancel();
    _pollTimer?.cancel();
    _eventSubscription?.cancel();
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
        _notify();
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
      selectedProfileId = state.selectedProfileId;
      draft = state.draft;
      materializeDefaults = state.runtimeDefaults;
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

  ProfileDraft _normalizeDraft(ProfileDraft candidate) {
    if (providerDescriptors.isEmpty) {
      return candidate;
    }
    final descriptor =
        descriptorForProvider(candidate.spec.provider) ??
        providerDescriptors.first;
    final sameProvider =
        descriptor.id.trim().toLowerCase() ==
        candidate.spec.provider.trim().toLowerCase();
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

  String? _providerSettingsBlockReason(ProviderDescriptor descriptor) {
    final reason = descriptor.providerSettingsSupportError;
    if (reason == null) {
      return null;
    }
    return 'The connected desktop shell cannot render provider settings for ${descriptor.displayName}: $reason';
  }

  void _notify() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }
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
