import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/mobile_host_bridge.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_controller.dart';
import 'package:mobile_gui_shell/src/ui/profile_editor.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.controller});

  final MobileShellController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final theme = Theme.of(context);
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                Text(
                  'Mobile control shell',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Embedded-host orchestration, secure local profiles, browser handoff, and typed runtime state for Android and iOS.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _HostBanner(controller: controller),
                const SizedBox(height: 12),
                _SystemTunnelBanner(controller: controller),
                if (controller.notice != null) ...<Widget>[
                  const SizedBox(height: 12),
                  _NoticeBanner(message: controller.notice!),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 760,
                  child: ProfileEditorPanel(
                    profiles: controller.profiles,
                    selectedProfileId: controller.selectedProfileId,
                    draft: controller.draft,
                    busy: controller.busy,
                    onSelectProfile: controller.selectProfile,
                    onDraftChanged: controller.updateDraft,
                    onSave: controller.saveDraft,
                    onDelete: controller.deleteSelectedProfile,
                    onReset: controller.resetDraft,
                    onResolve: controller.startResolutionFromDraft,
                    onStart: controller.startSelectedProfile,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 420,
                  child: _ResolutionsPanel(controller: controller),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 460,
                  child: _SessionsPanel(controller: controller),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 320,
                  child: _EventsPanel(controller: controller),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HostBanner extends StatelessWidget {
  const _HostBanner({required this.controller});

  final MobileShellController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connection = controller.hostConnection;
    final hostInfo = connection?.info;
    final color = switch (connection?.state) {
      MobileHostLifecycleState.ready => const Color(0xFFDEF2E1),
      MobileHostLifecycleState.incompatible => const Color(0xFFFFE5CC),
      MobileHostLifecycleState.failed => const Color(0xFFFFE0DF),
      _ => const Color(0xFFE5ECF6),
    };

    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              connection?.isReady == true
                  ? 'Mobile host ready'
                  : 'Mobile host blocked',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              connection?.message ??
                  'Waiting for mobile host bridge negotiation.',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _Tag(label: 'GUI ${controller.appBuild.shortLabel}'),
                if (hostInfo != null)
                  _Tag(label: 'Host ${hostInfo.build.shortLabel}'),
                if (hostInfo != null)
                  _Tag(label: 'Contract ${hostInfo.contractVersion}'),
                if ((connection?.description ?? '').isNotEmpty)
                  _Tag(label: connection!.description),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.tonal(
                  onPressed: controller.busy
                      ? null
                      : controller.requiresLocalStateReset
                      ? null
                      : () => unawaited(controller.reconnect()),
                  child: const Text('Reconnect'),
                ),
                if (controller.requiresLocalStateReset)
                  OutlinedButton(
                    onPressed: controller.busy
                        ? null
                        : () => unawaited(controller.clearLocalState()),
                    child: const Text('Reset local state'),
                  ),
                FilledButton(
                  onPressed:
                      controller.busy ||
                          controller.hostConnection?.isReady != true
                      ? null
                      : () => unawaited(controller.refresh()),
                  child: const Text('Refresh'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolutionsPanel extends StatelessWidget {
  const _ResolutionsPanel({required this.controller});

  final MobileShellController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Resolutions',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Resolve the invite first, then copy the short-lived handoff link through the typed host contract when another device should consume it.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: controller.resolutions.isEmpty
                  ? Center(
                      child: Text(
                        'No provider resolutions yet.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: controller.resolutions.length,
                      separatorBuilder: (_, int index) =>
                          const SizedBox(height: 14),
                      itemBuilder: (BuildContext context, int index) {
                        final resolution = controller.resolutions[index];
                        final challenge = controller
                            .activeChallengeForResolution(resolution);
                        return _ResolutionCard(
                          resolution: resolution,
                          challenge: challenge,
                          busy: controller.busy,
                          selected:
                              controller.selectedResolutionId == resolution.id,
                          onSelect: () =>
                              controller.selectResolution(resolution.id),
                          onOpenChallenge: challenge == null
                              ? null
                              : () => controller.openChallengeInBrowser(
                                  challenge,
                                ),
                          onContinueChallenge: challenge == null
                              ? null
                              : () =>
                                    controller.continueChallenge(challenge.id),
                          onCancelChallenge: challenge == null
                              ? null
                              : () => controller.cancelChallenge(challenge.id),
                          onCopyExport:
                              resolution.export.supported &&
                                  resolution.state == ResolutionState.resolved
                              ? () => controller.copyResolutionExport(
                                  resolution.id,
                                )
                              : null,
                          onCancel: resolution.isTerminal
                              ? null
                              : () =>
                                    controller.cancelResolution(resolution.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemTunnelBanner extends StatelessWidget {
  const _SystemTunnelBanner({required this.controller});

  final MobileShellController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platformTunnels = controller.platformTunnels;

    return Card(
      color: const Color(0xFFE6EDF7),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.shield_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This mobile slice still does not yet claim device-wide tunnel capture as supported. Instead, it renders typed host capability and startup-stage results for the reported platform modes.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (platformTunnels.isEmpty)
              Text(
                'The connected mobile host did not report any platform tunnel modes.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...platformTunnels.map((PlatformTunnelCapability capability) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PlatformTunnelCard(
                    capability: capability,
                    result: controller.platformTunnelResultFor(capability.mode),
                    busy: controller.busy,
                    ready: controller.hostConnection?.isReady == true,
                    onStart: () =>
                        controller.startPlatformTunnel(capability.mode),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _PlatformTunnelCard extends StatelessWidget {
  const _PlatformTunnelCard({
    required this.capability,
    required this.result,
    required this.busy,
    required this.ready,
    required this.onStart,
  });

  final PlatformTunnelCapability capability;
  final PlatformTunnelStartResult? result;
  final bool busy;
  final bool ready;
  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = capability.available
        ? const Color(0xFFDEF2E1)
        : const Color(0xFFFFF1D6);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  capability.mode.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  capability.available ? 'available' : 'unavailable',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            capability.mode.value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _platformTunnelCapabilitySummary(capability),
            style: theme.textTheme.bodyMedium,
          ),
          if (capability.message.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(capability.message, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: busy || !ready ? null : () => unawaited(onStart()),
            child: const Text('Request startup'),
          ),
          const SizedBox(height: 10),
          Text(
            result == null
                ? 'No startup request yet. Use the typed mobile host contract to verify the fail-closed path.'
                : _platformTunnelResultSummary(result!),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResolutionCard extends StatelessWidget {
  const _ResolutionCard({
    required this.resolution,
    required this.challenge,
    required this.busy,
    required this.selected,
    required this.onSelect,
    required this.onOpenChallenge,
    required this.onContinueChallenge,
    required this.onCancelChallenge,
    required this.onCopyExport,
    required this.onCancel,
  });

  final ResolutionRecord resolution;
  final ChallengeRecord? challenge;
  final bool busy;
  final bool selected;
  final VoidCallback onSelect;
  final Future<void> Function()? onOpenChallenge;
  final Future<void> Function()? onContinueChallenge;
  final Future<void> Function()? onCancelChallenge;
  final Future<void> Function()? onCopyExport;
  final Future<void> Function()? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final containerColor = selected
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);

    return Material(
      color: containerColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      resolution.input.provider,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _ResolutionStateChip(state: resolution.state),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                resolution.input.linkRedacted.isEmpty
                    ? resolution.id
                    : resolution.input.linkRedacted,
                style: theme.textTheme.bodyMedium,
              ),
              if (resolution.credentials != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  'TURN ${resolution.credentials!.address} | ${resolution.credentials!.usernameRedacted}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (resolution.export.expiresAt != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  'Export expiry ${_formatSessionTimestamp(resolution.export.expiresAt!)}'
                  '${resolution.export.expirySource == null ? '' : ' via ${resolution.export.expirySource}'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (resolution.failure != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  '${resolution.failure!.stage ?? 'failure'}: ${resolution.failure!.message ?? 'unknown'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF7A1F16),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (challenge != null) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1D6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Challenge: ${challenge!.kind}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(challenge!.prompt ?? challenge!.stage),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          FilledButton.tonal(
                            onPressed: busy || onOpenChallenge == null
                                ? null
                                : () => unawaited(onOpenChallenge!.call()),
                            child: const Text('Open browser'),
                          ),
                          FilledButton(
                            onPressed: busy || onContinueChallenge == null
                                ? null
                                : () => unawaited(onContinueChallenge!.call()),
                            child: const Text("I've completed it"),
                          ),
                          OutlinedButton(
                            onPressed: busy || onCancelChallenge == null
                                ? null
                                : () => unawaited(onCancelChallenge!.call()),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: busy || onCopyExport == null
                        ? null
                        : () => unawaited(onCopyExport!.call()),
                    child: const Text('Copy handoff'),
                  ),
                  if (onCancel != null)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => unawaited(onCancel!.call()),
                      child: const Text('Cancel resolution'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionsPanel extends StatelessWidget {
  const _SessionsPanel({required this.controller});

  final MobileShellController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Sessions',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: controller.sessions.isEmpty
                  ? Center(
                      child: Text(
                        'No active or recent mobile sessions yet.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: controller.sessions.length,
                      separatorBuilder: (_, int index) =>
                          const SizedBox(height: 14),
                      itemBuilder: (BuildContext context, int index) {
                        final session = controller.sessions[index];
                        final challenge = controller.activeChallengeFor(
                          session,
                        );
                        return _SessionCard(
                          session: session,
                          challenge: challenge,
                          busy: controller.busy,
                          selected: controller.selectedSessionId == session.id,
                          onSelect: () => controller.selectSession(session.id),
                          onStop: () => controller.stopSession(session.id),
                          onExport: () =>
                              controller.exportDiagnostics(session.id),
                          onOpenChallenge: challenge == null
                              ? null
                              : () => controller.openChallengeInBrowser(
                                  challenge,
                                ),
                          onContinueChallenge: challenge == null
                              ? null
                              : () =>
                                    controller.continueChallenge(challenge.id),
                          onCancelChallenge: challenge == null
                              ? null
                              : () => controller.cancelChallenge(challenge.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.challenge,
    required this.busy,
    required this.selected,
    required this.onSelect,
    required this.onStop,
    required this.onExport,
    required this.onOpenChallenge,
    required this.onContinueChallenge,
    required this.onCancelChallenge,
  });

  final SessionRecord session;
  final ChallengeRecord? challenge;
  final bool busy;
  final bool selected;
  final VoidCallback onSelect;
  final Future<void> Function() onStop;
  final Future<void> Function() onExport;
  final Future<void> Function()? onOpenChallenge;
  final Future<void> Function()? onContinueChallenge;
  final Future<void> Function()? onCancelChallenge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final containerColor = selected
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);

    return Material(
      color: containerColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      session.profileName?.isNotEmpty == true
                          ? session.profileName!
                          : session.id,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _SessionStateChip(state: session.state),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${session.profile.provider} -> ${session.profile.peerAddress}',
              ),
              Text(
                'listen ${session.profile.listenAddress} | connections ${session.profile.connections}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Updated ${_formatSessionTimestamp(session.updatedAt)} | session ${_shortSessionId(session.id)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (session.failure != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  '${session.failure!.stage ?? 'failure'}: ${session.failure!.message ?? 'unknown'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF7A1F16),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (challenge != null) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1D6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Challenge: ${challenge!.kind}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(challenge!.prompt ?? challenge!.stage),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          FilledButton.tonal(
                            onPressed: busy || onOpenChallenge == null
                                ? null
                                : () => unawaited(onOpenChallenge!.call()),
                            child: const Text('Open browser'),
                          ),
                          FilledButton(
                            onPressed: busy || onContinueChallenge == null
                                ? null
                                : () => unawaited(onContinueChallenge!.call()),
                            child: const Text("I've completed it"),
                          ),
                          OutlinedButton(
                            onPressed: busy || onCancelChallenge == null
                                ? null
                                : () => unawaited(onCancelChallenge!.call()),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  FilledButton.tonal(
                    onPressed: busy ? null : () => unawaited(onExport()),
                    child: const Text('Export diagnostics'),
                  ),
                  if (session.state != SessionState.stopped &&
                      session.state != SessionState.failed)
                    OutlinedButton(
                      onPressed: busy ? null : () => unawaited(onStop()),
                      child: const Text('Stop session'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventsPanel extends StatelessWidget {
  const _EventsPanel({required this.controller});

  final MobileShellController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Event stream',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Typed state transitions and challenge updates from the mobile host bridge.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: controller.events.isEmpty
                  ? Center(
                      child: Text(
                        'No events yet.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: controller.events.length,
                      separatorBuilder: (_, int index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (BuildContext context, int index) {
                        final event = controller.events[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                event.timestamp.toIso8601String(),
                                style: theme.textTheme.labelSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                event.summary(),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                event.sessionId.isNotEmpty
                                    ? event.sessionId
                                    : (event.resolutionId ?? ''),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionStateChip extends StatelessWidget {
  const _SessionStateChip({required this.state});

  final SessionState state;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = switch (state) {
      SessionState.ready => (const Color(0xFFDEF2E1), const Color(0xFF285B38)),
      SessionState.challengeRequired => (
        const Color(0xFFFFF1D6),
        const Color(0xFF7E5514),
      ),
      SessionState.failed => (const Color(0xFFFFE0DF), const Color(0xFF7A1F16)),
      SessionState.stopped => (
        const Color(0xFFE1E6EC),
        const Color(0xFF334A5E),
      ),
      _ => (const Color(0xFFE6EDF7), const Color(0xFF245070)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        state.value,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ResolutionStateChip extends StatelessWidget {
  const _ResolutionStateChip({required this.state});

  final ResolutionState state;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = switch (state) {
      ResolutionState.resolved => (
        const Color(0xFFDEF2E1),
        const Color(0xFF285B38),
      ),
      ResolutionState.challengeRequired => (
        const Color(0xFFFFF1D6),
        const Color(0xFF7E5514),
      ),
      ResolutionState.failed ||
      ResolutionState.cancelled ||
      ResolutionState.expired => (
        const Color(0xFFFFE0DF),
        const Color(0xFF7A1F16),
      ),
      _ => (const Color(0xFFE6EDF7), const Color(0xFF245070)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        state.value,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFDF6C7),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            const Icon(Icons.info_outline),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

String _formatSessionTimestamp(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)} '
      '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}:${_twoDigits(local.second)}';
}

String _shortSessionId(String value) {
  final trimmed = value.trim();
  if (trimmed.length <= 12) {
    return trimmed;
  }
  return '${trimmed.substring(0, 12)}...';
}

String _platformTunnelCapabilitySummary(PlatformTunnelCapability capability) {
  if (capability.available && capability.satisfiedPrerequisites.isNotEmpty) {
    final satisfied = capability.satisfiedPrerequisites
        .map((PlatformTunnelPrerequisite prerequisite) => prerequisite.label)
        .join(', ');
    return 'Satisfied prerequisites: $satisfied';
  }
  if (!capability.available && capability.missingPrerequisite != null) {
    return 'Missing prerequisite: ${capability.missingPrerequisite!.label}';
  }
  if (capability.available) {
    return 'The mobile host reports that this mode is available.';
  }
  return 'The mobile host reports that this mode is unavailable.';
}

String _platformTunnelResultSummary(PlatformTunnelStartResult result) {
  if (result.ready) {
    return '${result.mode.label} reached ready state for the mobile host tunnel path.';
  }
  final buffer = StringBuffer(
    'Startup blocked at ${result.stage?.label ?? 'Unknown stage'}.',
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

String _twoDigits(int value) => value.toString().padLeft(2, '0');
