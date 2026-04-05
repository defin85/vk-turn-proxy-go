import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:gui_shell/src/control/control_plane_client.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';

enum HostLifecycleState {
  ready,
  unavailable,
  incompatible,
  failed,
}

class HostConnectionResult {
  const HostConnectionResult({
    required this.state,
    required this.message,
    this.info,
    this.launched = false,
    this.launchSpec,
  });

  final HostLifecycleState state;
  final String message;
  final HostInfo? info;
  final bool launched;
  final SidecarLaunchSpec? launchSpec;

  bool get isReady => state == HostLifecycleState.ready;
}

abstract class HostSupervisor {
  Future<HostConnectionResult> ensureReady();
  Future<void> dispose();
}

class SidecarLaunchSpec {
  const SidecarLaunchSpec({
    required this.executable,
    this.arguments = const <String>[],
    this.workingDirectory,
    required this.description,
  });

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final String description;
}

abstract class SidecarLocator {
  Future<List<SidecarLaunchSpec>> candidates(String listenAddress);
}

class DefaultSidecarLocator implements SidecarLocator {
  const DefaultSidecarLocator();

  @override
  Future<List<SidecarLaunchSpec>> candidates(String listenAddress) async {
    final specs = <SidecarLaunchSpec>[];
    final executableName = Platform.isWindows ? 'clientd.exe' : 'clientd';

    final envPath = Platform.environment['GUI_SHELL_CLIENTD_PATH'];
    if (envPath != null && envPath.trim().isNotEmpty) {
      specs.add(
        SidecarLaunchSpec(
          executable: envPath.trim(),
          arguments: <String>['-listen', listenAddress],
          description: 'GUI_SHELL_CLIENTD_PATH',
        ),
      );
    }

    final resolved = File(Platform.resolvedExecutable);
    final sibling = _join(<String>[resolved.parent.path, executableName]);
    if (File(sibling).existsSync()) {
      specs.add(
        SidecarLaunchSpec(
          executable: sibling,
          arguments: <String>['-listen', listenAddress],
          description: 'sidecar next to app executable',
        ),
      );
    }

    if (Platform.isMacOS) {
      final frameworks = macOSBundledSidecarPath(resolved.path, executableName);
      if (File(frameworks).existsSync()) {
        specs.add(
          SidecarLaunchSpec(
            executable: frameworks,
            arguments: <String>['-listen', listenAddress],
            description: 'bundled sidecar in Frameworks',
          ),
        );
      }
    }

    specs.add(
      SidecarLaunchSpec(
        executable: executableName,
        arguments: <String>['-listen', listenAddress],
        description: 'clientd from PATH',
      ),
    );

    final repoRoot = _findRepoRoot(Directory.current);
    if (repoRoot != null) {
      specs.add(
        SidecarLaunchSpec(
          executable: 'go',
          arguments: <String>['run', './cmd/clientd', '-listen', listenAddress],
          workingDirectory: repoRoot.path,
          description: 'repo-local go run fallback',
        ),
      );
    }

    return specs;
  }
}

abstract class ManagedSidecarProcess {
  Future<int> get exitCode;
  bool kill([ProcessSignal signal]);
}

typedef SidecarStarter = Future<ManagedSidecarProcess> Function(SidecarLaunchSpec spec);

class DesktopHostSupervisor implements HostSupervisor {
  DesktopHostSupervisor({
    required this.client,
    required this.listenAddress,
    required this.locator,
    this.supportedVersions = const <String>[ControlPlaneClient.contractVersion],
    this.requiredCapabilities = const <Capability>[
      Capability.desktopSidecar,
      Capability.profiles,
      Capability.sessions,
      Capability.challenges,
      Capability.diagnostics,
      Capability.eventStream,
    ],
    this.startupTimeout = const Duration(seconds: 45),
    this.probeInterval = const Duration(milliseconds: 250),
    SidecarStarter? starter,
  }) : _starter = starter ?? _startSystemProcess;

  final ControlPlaneApi client;
  final String listenAddress;
  final SidecarLocator locator;
  final List<String> supportedVersions;
  final List<Capability> requiredCapabilities;
  final Duration startupTimeout;
  final Duration probeInterval;
  final SidecarStarter _starter;

  ManagedSidecarProcess? _ownedProcess;

  @override
  Future<HostConnectionResult> ensureReady() async {
    final initial = await _probeHost();
    if (initial.isReady || initial.state == HostLifecycleState.incompatible) {
      return initial;
    }

    final candidates = await locator.candidates(listenAddress);
    if (candidates.isEmpty) {
      return const HostConnectionResult(
        state: HostLifecycleState.unavailable,
        message: 'No compatible local host was found and no launch candidates are configured.',
      );
    }

    Object? lastError;
    HostConnectionResult? lastResult;
    for (final spec in candidates) {
      try {
        final process = await _starter(spec);
        _ownedProcess = process;
        final result = await _waitForReady(spec, process);
        if (result.isReady) {
          return result;
        }
        lastResult = result;
      } catch (error) {
        lastError = error;
      }
      await dispose();
    }

    if (lastResult != null) {
      return lastResult;
    }

    return HostConnectionResult(
      state: HostLifecycleState.failed,
      message: lastError == null
          ? 'Local host launch failed without a reported error.'
          : 'Local host launch failed: $lastError',
    );
  }

  @override
  Future<void> dispose() async {
    final process = _ownedProcess;
    _ownedProcess = null;
    if (process == null) {
      return;
    }
    process.kill(ProcessSignal.sigterm);
    await process.exitCode.timeout(const Duration(seconds: 5), onTimeout: () {
      process.kill(ProcessSignal.sigkill);
      return -1;
    });
  }

  Future<HostConnectionResult> _probeHost() async {
    try {
      final info = await client.negotiate(
        supportedVersions: supportedVersions,
        requiredCapabilities: requiredCapabilities,
      );
      return HostConnectionResult(
        state: HostLifecycleState.ready,
        info: info,
        message: 'Connected to local host $listenAddress',
      );
    } on ControlPlaneError catch (error) {
      if (error.incompatibleHost) {
        return HostConnectionResult(
          state: HostLifecycleState.incompatible,
          message: error.message,
        );
      }
      return HostConnectionResult(
        state: HostLifecycleState.unavailable,
        message: error.message,
      );
    }
  }

  Future<HostConnectionResult> _waitForReady(
    SidecarLaunchSpec spec,
    ManagedSidecarProcess process,
  ) async {
    final deadline = DateTime.now().add(startupTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final result = await _probeHost();
      if (result.isReady) {
        return HostConnectionResult(
          state: HostLifecycleState.ready,
          info: result.info,
          launched: true,
          launchSpec: spec,
          message: 'Launched ${spec.description} on $listenAddress',
        );
      }
      if (result.state == HostLifecycleState.incompatible) {
        return HostConnectionResult(
          state: HostLifecycleState.incompatible,
          message: result.message,
          launchSpec: spec,
        );
      }

      final exit = await process.exitCode.timeout(
        probeInterval,
        onTimeout: () => _processStillRunning,
      );
      if (exit != _processStillRunning) {
        return HostConnectionResult(
          state: HostLifecycleState.failed,
          message: '${spec.description} exited with code $exit before the control plane became ready.',
          launchSpec: spec,
        );
      }
    }
    return HostConnectionResult(
      state: HostLifecycleState.failed,
      message: '${spec.description} did not become ready within ${startupTimeout.inSeconds}s.',
      launchSpec: spec,
    );
  }
}

class _SystemManagedSidecarProcess implements ManagedSidecarProcess {
  _SystemManagedSidecarProcess(this._process) {
    _process.stdout.transform(utf8.decoder).listen((String _) {});
    _process.stderr.transform(utf8.decoder).listen((String _) {});
  }

  final Process _process;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    return _process.kill(signal);
  }
}

Future<ManagedSidecarProcess> _startSystemProcess(SidecarLaunchSpec spec) async {
  final process = await Process.start(
    spec.executable,
    spec.arguments,
    workingDirectory: spec.workingDirectory,
  );
  return _SystemManagedSidecarProcess(process);
}

String macOSBundledSidecarPath(String resolvedExecutablePath, String executableName) {
  final resolved = File(resolvedExecutablePath);
  return _join(<String>[resolved.parent.parent.path, 'Frameworks', executableName]);
}

Directory? _findRepoRoot(Directory start) {
  Directory current = start.absolute;
  while (true) {
    if (File(_join(<String>[current.path, 'go.mod'])).existsSync() &&
        Directory(_join(<String>[current.path, 'cmd', 'clientd'])).existsSync()) {
      return current;
    }
    if (current.parent.path == current.path) {
      return null;
    }
    current = current.parent;
  }
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

const int _processStillRunning = -1000000;
