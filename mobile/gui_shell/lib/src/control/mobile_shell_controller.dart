import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:mobile_gui_shell/src/build/app_build_identity.dart';
import 'package:mobile_gui_shell/src/control/control_plane_client.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/mobile_handoff_adapter.dart';
import 'package:mobile_gui_shell/src/control/mobile_host_bridge.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_state_store.dart';
import 'package:mobile_gui_shell/src/control/profile_draft.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

typedef DirectoryProvider = Future<Directory> Function();
typedef IDFactory = String Function();

enum ShellStatus { booting, ready, blocked }

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
    DirectoryProvider? diagnosticsDirectoryProvider,
    DateTime Function()? clock,
    IDFactory? idFactory,
    BuildIdentity? appBuild,
  }) : _browserLauncher = browserLauncher ?? ExternalBrowserLauncher(),
       _handoffAdapter =
           handoffAdapter ?? const ClipboardMobileHandoffAdapter(),
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
  final DirectoryProvider _diagnosticsDirectoryProvider;
  final DateTime Function() _clock;
  final IDFactory _idFactory;
  final BuildIdentity appBuild;

  ShellStatus status = ShellStatus.booting;
  MobileHostConnectionResult? hostConnection;
  List<ProfileRecord> profiles = const <ProfileRecord>[];
  List<ResolutionRecord> resolutions = const <ResolutionRecord>[];
  List<SessionRecord> sessions = const <SessionRecord>[];
  List<EventRecord> events = const <EventRecord>[];
  ProfileDraft draft = ProfileDraft.defaults();
  String? selectedProfileId;
  String? selectedResolutionId;
  String? selectedSessionId;
  final Map<PlatformTunnelMode, PlatformTunnelStartResult>
  _platformTunnelResults = <PlatformTunnelMode, PlatformTunnelStartResult>{};
  String? notice;
  bool busy = false;
  bool _requiresLocalStateReset = false;
  String? _blockedLocalStateMessage;

  final Map<String, ChallengeRecord> _challengeCache =
      <String, ChallengeRecord>{};
  StreamSubscription<EventRecord>? _eventSubscription;
  Timer? _pollTimer;
  Timer? _debounceTimer;
  Timer? _persistTimer;
  bool _disposed = false;
  String? _persistedStateSignature;

  static const List<Capability> requiredCapabilities = <Capability>[
    Capability.mobileHostBridge,
    Capability.platformTunnels,
    Capability.profiles,
    Capability.providerResolutionHandoff,
    Capability.sessions,
    Capability.challenges,
    Capability.diagnostics,
    Capability.eventStream,
  ];

  bool get requiresLocalStateReset => _requiresLocalStateReset;

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
    if (_requiresLocalStateReset) {
      hostConnection = MobileHostConnectionResult(
        state: MobileHostLifecycleState.failed,
        message:
            _blockedLocalStateMessage ??
            'Local mobile shell state must be reset before runtime control can continue.',
        description: 'local mobile shell state',
      );
      status = ShellStatus.blocked;
      busy = false;
      _notify();
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
      if (hostConnection?.isReady == true) {
        unawaited(refresh());
      } else if (!busy) {
        unawaited(reconnect());
      }
    }
  }

  Future<void> refresh() async {
    if (hostConnection?.isReady != true) {
      _notify();
      return;
    }
    try {
      final nextResolutions = await bridge.resolutions();
      final nextSessions = _orderedSessions(await bridge.sessions());
      final nextChallenges = await _loadActiveChallenges(
        nextSessions,
        nextResolutions,
      );
      resolutions = nextResolutions;
      selectedResolutionId = _resolveSelectedResolutionId(nextResolutions);
      _replaceSessions(nextSessions);
      _mergeChallenges(nextChallenges);
      _notify();
    } catch (error) {
      await _handleBridgeFailure(error);
    }
  }

  void selectProfile(String profileId) {
    selectedProfileId = profileId;
    final selected = profiles.firstWhere(
      (ProfileRecord profile) => profile.id == profileId,
      orElse: () => ProfileDraft.defaults().toProfile(),
    );
    draft = ProfileDraft.fromProfile(selected);
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
    draft = nextDraft;
    _scheduleStatePersist();
    notifyListeners();
  }

  void resetDraft() {
    selectedProfileId = null;
    draft = ProfileDraft.defaults();
    _scheduleStatePersist();
    notifyListeners();
  }

  Future<void> clearLocalState() async {
    busy = true;
    _notify();
    try {
      await _stopRuntimeMonitoring();
      await stateStore.clear();
      _challengeCache.clear();
      profiles = const <ProfileRecord>[];
      resolutions = const <ResolutionRecord>[];
      sessions = const <SessionRecord>[];
      events = const <EventRecord>[];
      draft = ProfileDraft.defaults();
      selectedProfileId = null;
      selectedResolutionId = null;
      selectedSessionId = null;
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
    busy = true;
    _notify();
    try {
      var profile = draft.toProfile();
      if (profile.id.isEmpty) {
        profile = profile.copyWith(id: _idFactory());
      }
      if (hostConnection?.isReady == true) {
        profile = await bridge.upsertProfile(profile);
      }
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
    busy = true;
    _notify();
    try {
      profiles = profiles
          .where((ProfileRecord profile) => profile.id != profileId)
          .toList(growable: false);
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
      final resolution = await bridge.startResolution(
        provider: draft.spec.provider,
        link: draft.spec.link,
        interactiveProvider: draft.spec.interactiveProvider,
      );
      selectedResolutionId = resolution.id;
      notice = 'Started mobile resolution ${resolution.id}.';
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

  Future<void> copyResolutionExport(String resolutionId) async {
    await _runBridgeMutation(() async {
      final exported = await bridge.exportResolution(resolutionId);
      await _handoffAdapter.copyLink(exported.link);
      selectedResolutionId = resolutionId;
      notice =
          'Copied handoff link for $resolutionId. Expires ${_formatNoticeTimestamp(exported.expiresAt)}.';
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
    notice = opened
        ? 'Opened mobile browser handoff for ${challenge.kind}. Return here after the browser step.'
        : 'Failed to open the mobile browser handoff URL.';
    _notify();
  }

  Future<void> continueChallenge(String challengeId) async {
    await _runBridgeMutation(() async {
      final challenge = await bridge.continueChallenge(challengeId);
      _challengeCache[challenge.id] = challenge;
      notice = 'Continued challenge $challengeId.';
      await refresh();
    });
  }

  Future<void> cancelChallenge(String challengeId) async {
    await _runBridgeMutation(() async {
      final challenge = await bridge.cancelChallenge(challengeId);
      _challengeCache[challenge.id] = challenge;
      notice = 'Cancelled challenge $challengeId.';
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
      final result = await bridge.startPlatformTunnel(mode: mode);
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

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _persistTimer?.cancel();
    _pollTimer?.cancel();
    _eventSubscription?.cancel();
    unawaited(bridge.dispose());
    super.dispose();
  }

  Future<void> _connectBridge() async {
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

    if (hostConnection?.isReady != true) {
      await _stopRuntimeMonitoring();
      _challengeCache.clear();
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
    final currentID = selectedResolutionId?.trim() ?? '';
    if (currentID.isEmpty) {
      return nextResolutions.first.id;
    }
    for (final resolution in nextResolutions) {
      if (resolution.id == currentID) {
        return resolution.id;
      }
    }
    return nextResolutions.first.id;
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
    for (final challenge in challenges) {
      _challengeCache[challenge.id] = challenge;
    }
  }

  void _scheduleRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(refresh());
    });
  }

  Future<void> _runBridgeMutation(Future<void> Function() action) async {
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
      selectedProfileId = state.selectedProfileId;
      draft = state.draft;
      _persistedStateSignature = state.signature();
    } catch (error) {
      _requiresLocalStateReset = true;
      _blockedLocalStateMessage =
          'Failed to restore mobile shell state: $error';
      notice = _blockedLocalStateMessage;
    }
  }

  void _scheduleStatePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 150), () {
      unawaited(_persistState());
    });
  }

  Future<void> _persistState() async {
    final next = MobileShellState(
      profiles: profiles,
      selectedProfileId: selectedProfileId,
      draft: draft,
    );
    final signature = next.signature();
    if (signature == _persistedStateSignature) {
      return;
    }
    try {
      await stateStore.save(next);
      _persistedStateSignature = signature;
    } catch (error) {
      notice = 'Failed to persist mobile shell state: $error';
      _notify();
    }
  }

  void _clearPlatformTunnelResults() {
    _platformTunnelResults.clear();
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

  void _notify() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }
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
