import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';

import '../control/control_plane_models.dart';
import 'shell_visuals.dart';

enum SupportContentSurfaceVariant { desktop, mobile }

class SupportResolutionActions {
  const SupportResolutionActions({
    required this.onSelect,
    this.onOpenChallenge,
    this.openChallengeLabel,
    this.onContinueChallenge,
    this.onCancelChallenge,
    this.onMaterialize,
    this.onCopyExport,
    this.onShareExport,
    this.onOpenRoom,
    this.onOpenCamera,
    this.onOpenArchive,
    this.onCancel,
  });

  final VoidCallback onSelect;
  final Future<void> Function()? onOpenChallenge;
  final String? openChallengeLabel;
  final Future<void> Function()? onContinueChallenge;
  final Future<void> Function()? onCancelChallenge;
  final Future<void> Function()? onMaterialize;
  final Future<void> Function()? onCopyExport;
  final Future<void> Function()? onShareExport;
  final Future<void> Function()? onOpenRoom;
  final Future<void> Function()? onOpenCamera;
  final Future<void> Function()? onOpenArchive;
  final Future<void> Function()? onCancel;
}

typedef SupportResolutionActionResolver =
    SupportResolutionActions Function(
      ResolutionRecord resolution,
      ChallengeRecord? challenge,
    );

class SupportSessionActions {
  const SupportSessionActions({
    required this.onSelect,
    required this.onStop,
    required this.onExport,
    this.onOpenChallenge,
    this.openChallengeLabel,
    this.onContinueChallenge,
    this.onCancelChallenge,
  });

  final VoidCallback onSelect;
  final Future<void> Function() onStop;
  final Future<void> Function() onExport;
  final Future<void> Function()? onOpenChallenge;
  final String? openChallengeLabel;
  final Future<void> Function()? onContinueChallenge;
  final Future<void> Function()? onCancelChallenge;
}

typedef SupportSessionActionResolver =
    SupportSessionActions Function(
      SessionRecord session,
      ChallengeRecord? challenge,
    );

class SupportResolutionsSurface extends StatelessWidget {
  const SupportResolutionsSurface({
    super.key,
    required this.variant,
    required this.resolutions,
    required this.selectedResolutionId,
    required this.busy,
    required this.challengeForResolution,
    required this.actionsForResolution,
    this.scrollKey,
  });

  final SupportContentSurfaceVariant variant;
  final List<ResolutionRecord> resolutions;
  final String? selectedResolutionId;
  final bool busy;
  final ChallengeRecord? Function(ResolutionRecord resolution)
  challengeForResolution;
  final SupportResolutionActionResolver actionsForResolution;
  final Key? scrollKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceKey = ValueKey<String>(
      'support-resolutions-surface-${variant.name}',
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final compact =
            variant == SupportContentSurfaceVariant.mobile &&
            constraints.maxHeight < 260;
        return KeyedSubtree(
          key: surfaceKey,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.shellText.resolutionsTitle,
                    style:
                        (compact
                                ? theme.textTheme.titleLarge
                                : theme.textTheme.headlineSmall)
                            ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (!compact) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      context.shellText.resolutionsSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Expanded(
                    child: resolutions.isEmpty
                        ? Center(
                            child: Text(
                              context.shellText.noProviderResolutionsYet,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.separated(
                            key: scrollKey,
                            itemCount: resolutions.length,
                            separatorBuilder: (_, int index) =>
                                const SizedBox(height: 14),
                            itemBuilder: (BuildContext context, int index) {
                              final resolution = resolutions[index];
                              final challenge = challengeForResolution(
                                resolution,
                              );
                              final actions = actionsForResolution(
                                resolution,
                                challenge,
                              );
                              return _SupportResolutionCard(
                                variant: variant,
                                resolution: resolution,
                                challenge: challenge,
                                busy: busy,
                                selected: selectedResolutionId == resolution.id,
                                actions: actions,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class SupportSessionsSurface extends StatelessWidget {
  const SupportSessionsSurface({
    super.key,
    required this.variant,
    required this.sessions,
    required this.selectedSessionId,
    required this.busy,
    required this.challengeForSession,
    required this.actionsForSession,
    this.scrollKey,
  });

  final SupportContentSurfaceVariant variant;
  final List<SessionRecord> sessions;
  final String? selectedSessionId;
  final bool busy;
  final ChallengeRecord? Function(SessionRecord session) challengeForSession;
  final SupportSessionActionResolver actionsForSession;
  final Key? scrollKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceKey = ValueKey<String>(
      'support-sessions-surface-${variant.name}',
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final compact =
            variant == SupportContentSurfaceVariant.mobile &&
            constraints.maxHeight < 220;
        final emptyCopy = switch (variant) {
          SupportContentSurfaceVariant.desktop =>
            context.shellText.desktopNoSessionsYet,
          SupportContentSurfaceVariant.mobile =>
            context.shellText.noMobileSessionsYet,
        };
        return KeyedSubtree(
          key: surfaceKey,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.shellText.sessionsTitle,
                    style:
                        (compact
                                ? theme.textTheme.titleLarge
                                : theme.textTheme.headlineSmall)
                            ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: sessions.isEmpty
                        ? Center(
                            child: Text(
                              emptyCopy,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.separated(
                            key: scrollKey,
                            itemCount: sessions.length,
                            separatorBuilder: (_, int index) =>
                                const SizedBox(height: 14),
                            itemBuilder: (BuildContext context, int index) {
                              final session = sessions[index];
                              final challenge = challengeForSession(session);
                              final actions = actionsForSession(
                                session,
                                challenge,
                              );
                              return _SupportSessionCard(
                                variant: variant,
                                session: session,
                                challenge: challenge,
                                busy: busy,
                                selected: selectedSessionId == session.id,
                                actions: actions,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class SupportDiagnosticsOverviewSurface extends StatelessWidget {
  const SupportDiagnosticsOverviewSurface({
    super.key,
    required this.variant,
    required this.children,
    this.emptyMessage,
    this.scrollKey,
  });

  final SupportContentSurfaceVariant variant;
  final List<Widget> children;
  final String? emptyMessage;
  final Key? scrollKey;

  @override
  Widget build(BuildContext context) {
    final surfaceKey =
        scrollKey ??
        ValueKey<String>(
          'support-diagnostics-overview-surface-${variant.name}',
        );
    if (children.isEmpty) {
      return KeyedSubtree(
        key: surfaceKey,
        child: Center(
          child: Text(emptyMessage ?? context.shellText.noEventsYet),
        ),
      );
    }
    if (variant == SupportContentSurfaceVariant.desktop &&
        children.length == 1) {
      return KeyedSubtree(key: surfaceKey, child: children.single);
    }
    return ListView.separated(
      key: surfaceKey,
      itemCount: children.length,
      separatorBuilder: (_, int index) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) => children[index],
    );
  }
}

class SupportEventStreamSurface extends StatelessWidget {
  const SupportEventStreamSurface({
    super.key,
    required this.variant,
    required this.events,
    this.scrollKey,
  });

  final SupportContentSurfaceVariant variant;
  final List<EventRecord> events;
  final Key? scrollKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = switch (variant) {
      SupportContentSurfaceVariant.desktop =>
        context.shellText.desktopEventStreamSubtitle,
      SupportContentSurfaceVariant.mobile =>
        context.shellText.eventStreamSubtitle,
    };
    final surfaceKey = ValueKey<String>(
      'support-event-stream-surface-${variant.name}',
    );
    return KeyedSubtree(
      key: surfaceKey,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.shellText.eventStream,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: events.isEmpty
                    ? Center(
                        child: Text(
                          context.shellText.noEventsYet,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        key: scrollKey,
                        itemCount: events.length,
                        separatorBuilder: (_, int index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (BuildContext context, int index) {
                          final event = events[index];
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
      ),
    );
  }
}

class _SupportResolutionCard extends StatelessWidget {
  const _SupportResolutionCard({
    required this.variant,
    required this.resolution,
    required this.challenge,
    required this.busy,
    required this.selected,
    required this.actions,
  });

  final SupportContentSurfaceVariant variant;
  final ResolutionRecord resolution;
  final ChallengeRecord? challenge;
  final bool busy;
  final bool selected;
  final SupportResolutionActions actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final containerColor = selected
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
    final dangerPalette = context.shellVisuals.tone(ShellSemanticTone.danger);
    final challengePalette = context.shellVisuals.tone(
      ShellSemanticTone.attention,
    );

    return Material(
      color: containerColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: actions.onSelect,
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
                  _SupportResolutionStateChip(state: resolution.state),
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
                  context.shellText.turnCredentialsSummary(
                    address: resolution.credentials!.address,
                    username: resolution.credentials!.usernameRedacted,
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (resolution.artifact != null) ...<Widget>[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _SupportSurfaceTag(
                      label: resolution.artifact!.family.label,
                    ),
                    for (final action in resolution.artifact!.actions)
                      _SupportSurfaceTag(
                        label:
                            '${action.id.label} · ${context.shellText.actionExecutionOwnerLabel(action.executionOwner.value)}',
                      ),
                  ],
                ),
              ],
              if (resolution.export.expiresAt != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  context.shellText.exportExpiry(
                    timestamp: _formatSupportTimestamp(
                      resolution.export.expiresAt!,
                      variant,
                    ),
                    source: resolution.export.expirySource,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (resolution.failure != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  context.shellText.failureSummary(
                    stage:
                        resolution.failure!.stage ??
                        context.shellText.failureFallback,
                    message:
                        resolution.failure!.message ??
                        context.shellText.unknownValue,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: dangerPalette.onContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (challenge != null) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: shellSurfaceDecoration(
                    context,
                    style: ShellSurfaceStyle.highlight,
                    tone: ShellSemanticTone.attention,
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.shellText.challengeKind(challenge!.kind),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: challengePalette.onContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        challenge!.prompt ?? challenge!.stage,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: challengePalette.onContainer,
                        ),
                      ),
                      if (variant == SupportContentSurfaceVariant.desktop &&
                          (challenge!.openUrl ?? '').isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        SelectableText(
                          challenge!.openUrl!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 10),
                      switch (variant) {
                        SupportContentSurfaceVariant.desktop =>
                          _buildDesktopResolutionChallengeActions(context),
                        SupportContentSurfaceVariant.mobile =>
                          _buildMobileChallengeActions(context),
                      },
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              switch (variant) {
                SupportContentSurfaceVariant.desktop =>
                  _buildDesktopResolutionActions(context),
                SupportContentSurfaceVariant.mobile =>
                  _buildMobileResolutionActions(context),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopResolutionChallengeActions(BuildContext context) {
    final hasOpenChallenge = actions.onOpenChallenge != null;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        if (hasOpenChallenge)
          FilledButton(
            onPressed: busy
                ? null
                : () => unawaited(actions.onOpenChallenge!.call()),
            child: Text(
              actions.openChallengeLabel ?? context.shellText.mobileOpenBrowser,
            ),
          ),
        if (actions.onContinueChallenge != null)
          hasOpenChallenge
              ? OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => unawaited(actions.onContinueChallenge!.call()),
                  child: Text(context.shellText.continueAfterBrowserStep),
                )
              : FilledButton(
                  onPressed: busy
                      ? null
                      : () => unawaited(actions.onContinueChallenge!.call()),
                  child: Text(context.shellText.continueAfterBrowserStep),
                ),
        if (actions.onCancelChallenge != null)
          OutlinedButton(
            onPressed: busy
                ? null
                : () => unawaited(actions.onCancelChallenge!.call()),
            child: Text(context.shellText.cancelChallenge),
          ),
      ],
    );
  }

  Widget _buildMobileChallengeActions(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        if (actions.onOpenChallenge != null)
          FilledButton.tonal(
            onPressed: busy
                ? null
                : () => unawaited(actions.onOpenChallenge!.call()),
            child: Text(
              actions.openChallengeLabel ?? context.shellText.mobileOpenBrowser,
            ),
          ),
        if (actions.onContinueChallenge != null)
          FilledButton(
            onPressed: busy
                ? null
                : () => unawaited(actions.onContinueChallenge!.call()),
            child: Text(context.shellText.iveCompletedIt),
          ),
        if (actions.onCancelChallenge != null)
          _SupportActionOverflowButton(
            tooltip: context.shellText.moreChallengeActions,
            enabled: !busy,
            actions: <_SupportActionEntry>[
              _SupportActionEntry(
                id: 'cancel-challenge',
                label: context.shellText.cancelChallenge,
                onSelected: actions.onCancelChallenge!,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildDesktopResolutionActions(BuildContext context) {
    final copy = context.shellText;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        FilledButton.tonal(
          onPressed: busy || actions.onMaterialize == null
              ? null
              : () => unawaited(actions.onMaterialize!.call()),
          child: Text(copy.startOnThisDevice),
        ),
        OutlinedButton(
          onPressed: busy || actions.onCopyExport == null
              ? null
              : () => unawaited(actions.onCopyExport!.call()),
          child: Text(copy.copyHandoff),
        ),
        if (actions.onOpenRoom != null)
          OutlinedButton(
            onPressed: busy
                ? null
                : () => unawaited(actions.onOpenRoom!.call()),
            child: Text(copy.openRoom),
          ),
        if (actions.onOpenCamera != null)
          OutlinedButton(
            onPressed: busy
                ? null
                : () => unawaited(actions.onOpenCamera!.call()),
            child: Text(copy.openCamera),
          ),
        if (actions.onOpenArchive != null)
          OutlinedButton(
            onPressed: busy
                ? null
                : () => unawaited(actions.onOpenArchive!.call()),
            child: Text(copy.openArchive),
          ),
        if (actions.onCancel != null)
          OutlinedButton(
            onPressed: busy ? null : () => unawaited(actions.onCancel!.call()),
            child: Text(copy.cancelResolution),
          ),
      ],
    );
  }

  Widget _buildMobileResolutionActions(BuildContext context) {
    final primaryAction = _mobileResolutionPrimaryAction(context);
    return _SupportActionRow(
      busy: busy,
      primaryAction: primaryAction,
      secondaryActions: _mobileResolutionSecondaryActions(
        context,
        primaryAction,
      ),
      overflowTooltip: context.shellText.moreResolutionActions,
    );
  }

  _SupportActionEntry? _mobileResolutionPrimaryAction(BuildContext context) {
    final candidates = <_SupportActionEntry>[
      if (actions.onMaterialize != null)
        _SupportActionEntry(
          id: 'materialize',
          label: context.shellText.startOnThisDevice,
          onSelected: actions.onMaterialize!,
        ),
      if (actions.onShareExport != null)
        _SupportActionEntry(
          id: 'share-export',
          label: context.shellText.shareHandoff,
          onSelected: actions.onShareExport!,
        ),
      if (actions.onOpenRoom != null)
        _SupportActionEntry(
          id: 'open-room',
          label: context.shellText.openRoom,
          onSelected: actions.onOpenRoom!,
        ),
      if (actions.onOpenCamera != null)
        _SupportActionEntry(
          id: 'open-camera',
          label: context.shellText.openCamera,
          onSelected: actions.onOpenCamera!,
        ),
      if (actions.onOpenArchive != null)
        _SupportActionEntry(
          id: 'open-archive',
          label: context.shellText.openArchive,
          onSelected: actions.onOpenArchive!,
        ),
      if (actions.onCopyExport != null)
        _SupportActionEntry(
          id: 'copy-export',
          label: context.shellText.copyHandoff,
          onSelected: actions.onCopyExport!,
        ),
      if (actions.onCancel != null)
        _SupportActionEntry(
          id: 'cancel-resolution',
          label: context.shellText.cancelResolution,
          onSelected: actions.onCancel!,
        ),
    ];
    return candidates.isEmpty ? null : candidates.first;
  }

  List<_SupportActionEntry> _mobileResolutionSecondaryActions(
    BuildContext context,
    _SupportActionEntry? primaryAction,
  ) {
    final primaryId = primaryAction?.id;
    return <_SupportActionEntry>[
      if (actions.onCopyExport != null)
        _SupportActionEntry(
          id: 'copy-export',
          label: context.shellText.copyHandoff,
          onSelected: actions.onCopyExport!,
        ),
      if (actions.onShareExport != null)
        _SupportActionEntry(
          id: 'share-export',
          label: context.shellText.shareHandoff,
          onSelected: actions.onShareExport!,
        ),
      if (actions.onOpenRoom != null)
        _SupportActionEntry(
          id: 'open-room',
          label: context.shellText.openRoom,
          onSelected: actions.onOpenRoom!,
        ),
      if (actions.onOpenCamera != null)
        _SupportActionEntry(
          id: 'open-camera',
          label: context.shellText.openCamera,
          onSelected: actions.onOpenCamera!,
        ),
      if (actions.onOpenArchive != null)
        _SupportActionEntry(
          id: 'open-archive',
          label: context.shellText.openArchive,
          onSelected: actions.onOpenArchive!,
        ),
      if (actions.onCancel != null)
        _SupportActionEntry(
          id: 'cancel-resolution',
          label: context.shellText.cancelResolution,
          onSelected: actions.onCancel!,
        ),
    ].where((entry) => entry.id != primaryId).toList(growable: false);
  }
}

class _SupportSessionCard extends StatelessWidget {
  const _SupportSessionCard({
    required this.variant,
    required this.session,
    required this.challenge,
    required this.busy,
    required this.selected,
    required this.actions,
  });

  final SupportContentSurfaceVariant variant;
  final SessionRecord session;
  final ChallengeRecord? challenge;
  final bool busy;
  final bool selected;
  final SupportSessionActions actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final containerColor = selected
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
    final dangerPalette = context.shellVisuals.tone(ShellSemanticTone.danger);
    final challengePalette = context.shellVisuals.tone(
      ShellSemanticTone.attention,
    );

    return Material(
      color: containerColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: actions.onSelect,
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
                  _SupportSessionStateChip(state: session.state),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${session.profile.provider} -> ${session.profile.peerAddress}',
              ),
              Text(
                context.shellText.sessionListenConnections(
                  listen: session.profile.listenAddress,
                  connections: session.profile.connections,
                ),
                style: theme.textTheme.bodySmall,
              ),
              if (variant == SupportContentSurfaceVariant.mobile) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  context.shellText.sessionUpdated(
                    timestamp: _formatSupportTimestamp(
                      session.updatedAt,
                      variant,
                    ),
                    sessionId: _shortSupportId(session.id),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (session.failure != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  context.shellText.failureSummary(
                    stage:
                        session.failure!.stage ??
                        context.shellText.failureFallback,
                    message:
                        session.failure!.message ??
                        context.shellText.unknownValue,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: dangerPalette.onContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (challenge != null) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: shellSurfaceDecoration(
                    context,
                    style: ShellSurfaceStyle.highlight,
                    tone: ShellSemanticTone.attention,
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.shellText.challengeKind(challenge!.kind),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: challengePalette.onContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        challenge!.prompt ?? challenge!.stage,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: challengePalette.onContainer,
                        ),
                      ),
                      const SizedBox(height: 10),
                      switch (variant) {
                        SupportContentSurfaceVariant.desktop =>
                          _buildDesktopSessionChallengeActions(context),
                        SupportContentSurfaceVariant.mobile =>
                          _buildMobileSessionChallengeActions(context),
                      },
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              switch (variant) {
                SupportContentSurfaceVariant.desktop =>
                  _buildDesktopSessionActions(context),
                SupportContentSurfaceVariant.mobile =>
                  _buildMobileSessionActions(context),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSessionChallengeActions(BuildContext context) {
    final hasOpenChallenge = actions.onOpenChallenge != null;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        if (hasOpenChallenge)
          FilledButton.tonal(
            onPressed: busy
                ? null
                : () => unawaited(actions.onOpenChallenge!.call()),
            child: Text(
              actions.openChallengeLabel ?? context.shellText.mobileOpenBrowser,
            ),
          ),
        if (actions.onContinueChallenge != null)
          hasOpenChallenge
              ? OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => unawaited(actions.onContinueChallenge!.call()),
                  child: Text(context.shellText.continueInBrowser),
                )
              : FilledButton.tonal(
                  onPressed: busy
                      ? null
                      : () => unawaited(actions.onContinueChallenge!.call()),
                  child: Text(context.shellText.continueInBrowser),
                ),
        if (actions.onCancelChallenge != null)
          OutlinedButton(
            onPressed: busy
                ? null
                : () => unawaited(actions.onCancelChallenge!.call()),
            child: Text(context.shellText.cancelChallenge),
          ),
      ],
    );
  }

  Widget _buildMobileSessionChallengeActions(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        if (actions.onOpenChallenge != null)
          FilledButton.tonal(
            onPressed: busy
                ? null
                : () => unawaited(actions.onOpenChallenge!.call()),
            child: Text(
              actions.openChallengeLabel ?? context.shellText.mobileOpenBrowser,
            ),
          ),
        if (actions.onContinueChallenge != null)
          FilledButton(
            onPressed: busy
                ? null
                : () => unawaited(actions.onContinueChallenge!.call()),
            child: Text(context.shellText.iveCompletedIt),
          ),
        if (actions.onCancelChallenge != null)
          _SupportActionOverflowButton(
            tooltip: context.shellText.moreChallengeActions,
            enabled: !busy,
            actions: <_SupportActionEntry>[
              _SupportActionEntry(
                id: 'cancel-challenge',
                label: context.shellText.cancelChallenge,
                onSelected: actions.onCancelChallenge!,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildDesktopSessionActions(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        FilledButton.tonal(
          onPressed: busy ? null : () => unawaited(actions.onExport()),
          child: Text(context.shellText.exportDiagnostics),
        ),
        if (session.state != SessionState.stopped &&
            session.state != SessionState.failed)
          OutlinedButton(
            onPressed: busy ? null : () => unawaited(actions.onStop()),
            child: Text(context.shellText.stopSession),
          ),
      ],
    );
  }

  Widget _buildMobileSessionActions(BuildContext context) {
    final primaryAction = _mobileSessionPrimaryAction(context);
    return _SupportActionRow(
      busy: busy,
      primaryAction: primaryAction,
      secondaryActions: _mobileSessionSecondaryActions(context, primaryAction),
      overflowTooltip: context.shellText.moreSessionActions,
    );
  }

  _SupportActionEntry _mobileSessionPrimaryAction(BuildContext context) {
    if (session.state != SessionState.stopped &&
        session.state != SessionState.failed) {
      return _SupportActionEntry(
        id: 'stop-session',
        label: context.shellText.stopSession,
        onSelected: actions.onStop,
      );
    }
    return _SupportActionEntry(
      id: 'export-diagnostics',
      label: context.shellText.exportDiagnostics,
      onSelected: actions.onExport,
    );
  }

  List<_SupportActionEntry> _mobileSessionSecondaryActions(
    BuildContext context,
    _SupportActionEntry primaryAction,
  ) {
    return <_SupportActionEntry>[
      _SupportActionEntry(
        id: 'export-diagnostics',
        label: context.shellText.exportDiagnostics,
        onSelected: actions.onExport,
      ),
      if (session.state != SessionState.stopped &&
          session.state != SessionState.failed)
        _SupportActionEntry(
          id: 'stop-session',
          label: context.shellText.stopSession,
          onSelected: actions.onStop,
        ),
    ].where((entry) => entry.id != primaryAction.id).toList(growable: false);
  }
}

class _SupportResolutionStateChip extends StatelessWidget {
  const _SupportResolutionStateChip({required this.state});

  final ResolutionState state;

  @override
  Widget build(BuildContext context) {
    final tone = switch (state) {
      ResolutionState.resolved => ShellSemanticTone.ready,
      ResolutionState.challengeRequired => ShellSemanticTone.attention,
      ResolutionState.failed ||
      ResolutionState.cancelled ||
      ResolutionState.expired => ShellSemanticTone.danger,
      _ => ShellSemanticTone.info,
    };
    return ShellToneBadge(
      label: context.shellText.resolutionStateLabel(state.value),
      tone: tone,
    );
  }
}

class _SupportSessionStateChip extends StatelessWidget {
  const _SupportSessionStateChip({required this.state});

  final SessionState state;

  @override
  Widget build(BuildContext context) {
    final tone = switch (state) {
      SessionState.ready => ShellSemanticTone.ready,
      SessionState.challengeRequired => ShellSemanticTone.attention,
      SessionState.failed => ShellSemanticTone.danger,
      SessionState.stopped => ShellSemanticTone.neutral,
      _ => ShellSemanticTone.info,
    };
    return ShellToneBadge(
      label: context.shellText.sessionStateLabel(state.value),
      tone: tone,
    );
  }
}

class _SupportSurfaceTag extends StatelessWidget {
  const _SupportSurfaceTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SupportActionRow extends StatelessWidget {
  const _SupportActionRow({
    required this.busy,
    required this.primaryAction,
    required this.secondaryActions,
    required this.overflowTooltip,
  });

  final bool busy;
  final _SupportActionEntry? primaryAction;
  final List<_SupportActionEntry> secondaryActions;
  final String overflowTooltip;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        if (primaryAction != null)
          FilledButton(
            onPressed: busy
                ? null
                : () => unawaited(primaryAction!.onSelected()),
            child: Text(primaryAction!.label),
          ),
        if (secondaryActions.isNotEmpty)
          _SupportActionOverflowButton(
            tooltip: overflowTooltip,
            enabled: !busy,
            actions: secondaryActions,
          ),
      ],
    );
  }
}

class _SupportActionOverflowButton extends StatelessWidget {
  const _SupportActionOverflowButton({
    required this.tooltip,
    required this.enabled,
    required this.actions,
  });

  final String tooltip;
  final bool enabled;
  final List<_SupportActionEntry> actions;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SupportActionEntry>(
      tooltip: tooltip,
      enabled: enabled,
      onSelected: (_SupportActionEntry action) =>
          unawaited(action.onSelected()),
      itemBuilder: (BuildContext context) {
        return actions
            .map(
              (_SupportActionEntry action) =>
                  PopupMenuItem<_SupportActionEntry>(
                    value: action,
                    child: Text(action.label),
                  ),
            )
            .toList(growable: false);
      },
      child: const Icon(Icons.more_horiz),
    );
  }
}

class _SupportActionEntry {
  const _SupportActionEntry({
    required this.id,
    required this.label,
    required this.onSelected,
  });

  final String id;
  final String label;
  final Future<void> Function() onSelected;
}

String _formatSupportTimestamp(
  DateTime value,
  SupportContentSurfaceVariant variant,
) {
  final local = value.toLocal();
  if (variant == SupportContentSurfaceVariant.desktop) {
    return local.toIso8601String();
  }
  return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)} '
      '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}:${_twoDigits(local.second)}';
}

String _shortSupportId(String value) {
  final trimmed = value.trim();
  if (trimmed.length <= 12) {
    return trimmed;
  }
  return '${trimmed.substring(0, 12)}...';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
