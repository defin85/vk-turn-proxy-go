import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gui_shell/src/control/control_plane_client.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/desktop_host_supervisor.dart';
import 'package:gui_shell/src/control/profile_draft.dart';
import 'package:gui_shell/src/control/shell_state_store.dart';

typedef DirectoryProvider = Future<Directory> Function();

enum ShellStatus {
  booting,
  ready,
  blocked,
}

class DesktopShellController extends ChangeNotifier {
  DesktopShellController({
    required this.api,
    required this.supervisor,
    DesktopShellStateStore? stateStore,
    DirectoryProvider? diagnosticsDirectoryProvider,
    DateTime Function()? clock,
  })  : _diagnosticsDirectoryProvider = diagnosticsDirectoryProvider ?? _defaultDiagnosticsDirectory,
        _stateStore = stateStore ?? FileDesktopShellStateStore(),
        _clock = clock ?? DateTime.now;

  final ControlPlaneApi api;
  final HostSupervisor supervisor;
  final DirectoryProvider _diagnosticsDirectoryProvider;
  final DesktopShellStateStore _stateStore;
  final DateTime Function() _clock;

  ShellStatus status = ShellStatus.booting;
  HostConnectionResult? hostConnection;
  List<ProfileRecord> profiles = const <ProfileRecord>[];
  List<SessionRecord> sessions = const <SessionRecord>[];
  List<EventRecord> events = const <EventRecord>[];
  ProfileDraft draft = ProfileDraft.defaults();
  String? selectedProfileId;
  String? selectedSessionId;
  String? notice;
  bool busy = false;

  final Map<String, ChallengeRecord> _challengeCache = <String, ChallengeRecord>{};
  StreamSubscription<EventRecord>? _eventSubscription;
  Timer? _pollTimer;
  Timer? _debounceTimer;
  Timer? _persistTimer;
  bool _recoveringHost = false;
  bool _disposed = false;
  bool _suppressEventStreamClosure = false;
  String? _persistedStateSignature;
  bool _restoredState = false;

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

    if (hostConnection?.isReady != true) {
      await _stopRuntimeMonitoring();
      _challengeCache.clear();
      sessions = const <SessionRecord>[];
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
      final nextProfiles = await api.profiles();
      final nextSessions = await api.sessions();
      final nextChallenges = await _loadActiveChallenges(nextSessions);

      profiles = nextProfiles;
      sessions = nextSessions;
      _mergeChallenges(nextChallenges);

      if (!_restoredState && selectedProfileId == null && profiles.isNotEmpty) {
        selectProfile(profiles.first.id);
        return;
      } else if (selectedProfileId != null &&
          !profiles.any((ProfileRecord profile) => profile.id == selectedProfileId)) {
        selectedProfileId = null;
        draft = ProfileDraft.defaults();
      }

      if (selectedSessionId == null && sessions.isNotEmpty) {
        selectedSessionId = sessions.first.id;
      } else if (selectedSessionId != null &&
          !sessions.any((SessionRecord session) => session.id == selectedSessionId)) {
        selectedSessionId = null;
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
    draft = ProfileDraft.fromProfile(selected);
    _scheduleStatePersist();
    notifyListeners();
  }

  void selectSession(String sessionId) {
    selectedSessionId = sessionId;
    notifyListeners();
  }

  void updateDraft(ProfileDraft nextDraft) {
    _restoredState = true;
    draft = nextDraft;
    _scheduleStatePersist();
    notifyListeners();
  }

  void resetDraft() {
    _restoredState = true;
    selectedProfileId = null;
    draft = ProfileDraft.defaults();
    _scheduleStatePersist();
    notifyListeners();
  }

  Future<void> saveDraft() async {
    await _runMutation(() async {
      final saved = await api.upsertProfile(draft.toProfile());
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
      notice = 'Continued challenge $challengeId.';
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
      final directory = await _diagnosticsDirectoryProvider();
      await directory.create(recursive: true);

      final timestamp = _clock().toUtc().toIso8601String().replaceAll(':', '-');
      final file = File(_join(<String>[directory.path, '$sessionId-$timestamp.json']));
      await file.writeAsString(diagnostics.toPrettyJson());

      notice = 'Exported diagnostics to ${file.path}.';
      selectedSessionId = sessionId;
    });
  }

  ChallengeRecord? activeChallengeFor(SessionRecord session) {
    final challengeID = session.activeChallengeId;
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
        if (_disposed || _suppressEventStreamClosure || status != ShellStatus.ready) {
          return;
        }
        unawaited(_handleHostFailure(const ControlPlaneError(
          statusCode: 0,
          code: 'connection_closed',
          message: 'event stream closed',
        )));
      },
    );
  }

  void _applyEvent(EventRecord event) {
    final index = sessions.indexWhere((SessionRecord session) => session.id == event.sessionId);
    if (index < 0) {
      return;
    }
    final current = sessions[index];
    final nextActiveChallengeId = switch (event.challenge?.status) {
      ChallengeStatus.pending || ChallengeStatus.continuing => event.challenge!.id,
      ChallengeStatus.completed || ChallengeStatus.cancelled || ChallengeStatus.failed => '',
      null => current.activeChallengeId,
    };
    final next = current.copyWith(
      state: event.state ?? current.state,
      activeChallengeId: nextActiveChallengeId,
      updatedAt: event.timestamp,
      failure: event.type == EventType.sessionFailed
          ? FailureInfo(stage: event.stage, message: event.message)
          : current.failure,
      stoppedAt: event.type == EventType.sessionStopped ? event.timestamp : current.stoppedAt,
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
      if (error.statusCode == 0 || error.incompatibleHost || error.statusCode >= 500) {
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

  Future<List<ChallengeRecord>> _loadActiveChallenges(List<SessionRecord> nextSessions) async {
    final ids = nextSessions
        .map((SessionRecord session) => session.activeChallengeId)
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
    final activeIDs = sessions
        .map((SessionRecord session) => session.activeChallengeId)
        .whereType<String>()
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet();

    _challengeCache.removeWhere((String id, ChallengeRecord _) => !activeIDs.contains(id));
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

  Future<void> _handleHostFailure(Object error, {bool scheduleRecovery = true}) async {
    await _stopRuntimeMonitoring();
    final message = error is ControlPlaneError ? error.message : '$error';
    hostConnection = HostConnectionResult(
      state: HostLifecycleState.unavailable,
      message: message,
    );
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
    );
    final signature = next.signature();
    if (signature == _persistedStateSignature) {
      return;
    }
    try {
      await _stateStore.save(next);
      _persistedStateSignature = signature;
    } catch (error) {
      notice = 'Failed to persist desktop shell state: $error';
      _notify();
    }
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
      return Directory(_join(<String>[appData, 'vk-turn-proxy-go', 'diagnostics']));
    }
  }

  final home = environment['HOME'];
  if (home != null && home.isNotEmpty) {
    return Directory(_join(<String>[home, '.vk-turn-proxy-go', 'diagnostics']));
  }
  return Directory(_join(<String>[Directory.systemTemp.path, 'vk-turn-proxy-go-diagnostics']));
}

String _join(List<String> parts) {
  final filtered = parts.where((String part) => part.isNotEmpty).toList(growable: false);
  if (filtered.isEmpty) {
    return '';
  }
  var value = filtered.first;
  for (final part in filtered.skip(1)) {
    if (value.endsWith(Platform.pathSeparator)) {
      value = '$value${part.replaceFirst(RegExp(r'^[\\/]+'), '')}';
      continue;
    }
    value = '$value${Platform.pathSeparator}${part.replaceFirst(RegExp(r'^[\\/]+'), '')}';
  }
  return value;
}
