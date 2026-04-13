import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/mobile_host_bridge.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_controller.dart';
import 'package:mobile_gui_shell/src/ui/owned_browser_challenge.dart';
import 'package:mobile_gui_shell/src/ui/profile_editor.dart';
import 'package:mobile_gui_shell/src/ui/provider_config_editor.dart';

enum _DashboardDestination { workflow, activity, diagnostics }

enum _ActivitySurface { resolutions, sessions }

enum _DiagnosticsSurface { overview, events }

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.controller,
    required this.ownedBrowserChallengeRunner,
  });

  final MobileShellController controller;
  final OwnedBrowserChallengeRunner ownedBrowserChallengeRunner;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  _DashboardDestination _destination = _DashboardDestination.workflow;
  _ActivitySurface _activitySurface = _ActivitySurface.resolutions;
  _DiagnosticsSurface _diagnosticsSurface = _DiagnosticsSurface.overview;

  Future<void> _launchChallengeSurface(ChallengeRecord challenge) async {
    if (!widget.controller.challengeRequiresOwnedBrowser(challenge)) {
      await widget.controller.openChallengeInBrowser(challenge);
      return;
    }
    try {
      final browserContinuation = await widget.ownedBrowserChallengeRunner.run(
        context,
        challenge,
      );
      if (browserContinuation == null) {
        await widget.controller.cancelChallenge(
          challenge.id,
          noticeOverride:
              'Cancelled the in-app browser continuation for challenge ${challenge.id} and marked the challenge cancelled.',
        );
        return;
      }
      await widget.controller.continueOwnedBrowserChallenge(
        challenge.id,
        browserContinuation,
      );
    } catch (error) {
      await widget.controller.cancelChallenge(
        challenge.id,
        noticeOverride:
            'In-app browser continuation failed: $error. Marked challenge ${challenge.id} as cancelled.',
      );
    }
  }

  String _openChallengeLabel(ChallengeRecord? challenge) {
    if (challenge == null) {
      return 'Open browser';
    }
    return widget.controller.challengeRequiresOwnedBrowser(challenge)
        ? 'Continue in app'
        : 'Open browser';
  }

  bool _showsManualChallengeContinue(ChallengeRecord? challenge) {
    if (challenge == null) {
      return false;
    }
    return !widget.controller.challengeRequiresOwnedBrowser(challenge);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          body: SafeArea(
            child: IndexedStack(
              index: _destination.index,
              children: <Widget>[
                _WorkflowPage(
                  controller: widget.controller,
                  onOpenActivity: () {
                    setState(() {
                      _destination = _DashboardDestination.activity;
                    });
                  },
                  onOpenDiagnostics: () {
                    setState(() {
                      _destination = _DashboardDestination.diagnostics;
                    });
                  },
                ),
                _ActivityPage(
                  controller: widget.controller,
                  surface: _activitySurface,
                  onLaunchChallengeSurface: _launchChallengeSurface,
                  openChallengeLabel: _openChallengeLabel,
                  showsManualChallengeContinue: _showsManualChallengeContinue,
                  onSurfaceChanged: (_ActivitySurface surface) {
                    setState(() {
                      _activitySurface = surface;
                    });
                  },
                ),
                _DiagnosticsPage(
                  controller: widget.controller,
                  surface: _diagnosticsSurface,
                  onSurfaceChanged: (_DiagnosticsSurface surface) {
                    setState(() {
                      _diagnosticsSurface = surface;
                    });
                  },
                ),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _destination.index,
            onDestinationSelected: (int index) {
              setState(() {
                _destination = _DashboardDestination.values[index];
              });
            },
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Workflow',
              ),
              NavigationDestination(
                icon: Icon(Icons.bolt_outlined),
                selectedIcon: Icon(Icons.bolt),
                label: 'Activity',
              ),
              NavigationDestination(
                icon: Icon(Icons.monitor_heart_outlined),
                selectedIcon: Icon(Icons.monitor_heart),
                label: 'Diagnostics',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WorkflowPage extends StatelessWidget {
  const _WorkflowPage({
    required this.controller,
    required this.onOpenActivity,
    required this.onOpenDiagnostics,
  });

  final MobileShellController controller;
  final VoidCallback onOpenActivity;
  final VoidCallback onOpenDiagnostics;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        _PageHeader(
          title: 'Mobile control shell',
          subtitle:
              'Phone-first workflow for profile selection, resolve, start, and browser handoff.',
        ),
        const SizedBox(height: 16),
        _WorkflowSummaryCard(
          controller: controller,
          onOpenDiagnostics: onOpenDiagnostics,
        ),
        if (controller.notice != null) ...<Widget>[
          const SizedBox(height: 12),
          _NoticeBanner(message: controller.notice!),
        ],
        const SizedBox(height: 12),
        _ActivitySummaryCard(
          resolutionsCount: controller.resolutions.length,
          sessionsCount: controller.sessions.length,
          onOpenActivity: onOpenActivity,
        ),
        const SizedBox(height: 20),
        _WorkflowSurfacePicker(controller: controller),
        const SizedBox(height: 16),
        _PresetLibrarySection(controller: controller),
        const SizedBox(height: 16),
        _ProviderConfigLibrarySection(controller: controller),
        const SizedBox(height: 20),
        if (controller.workflowSurface == MobileWorkflowSurface.profile)
          ProfileEditorPanel(
            profiles: controller.profiles,
            providerDescriptors: controller.providerDescriptors,
            managedProviders: controller.managedProviders,
            initialManagedProviderId:
                controller.draft.providerBinding.managedProviderId,
            selectedProfileId: controller.selectedProfileId,
            draft: controller.draft,
            busy: controller.busy,
            onSelectProfile: controller.selectProfile,
            onDraftChanged: controller.updateDraft,
            onActivateManagedProviderMode:
                controller.activateManagedProviderMode,
            onUseCustomProvider: controller.useCustomProviderForDraft,
            onSave: controller.saveDraft,
            onDelete: controller.deleteSelectedProfile,
            onReset: controller.resetDraft,
            onResolve: controller.startResolutionFromDraft,
            onStart: controller.startSelectedProfile,
          )
        else
          SizedBox(
            height: 640,
            child: ProviderConfigEditorPanel(
              supportedProviders: controller.supportedProviderCatalog,
              providerDescriptors: controller.providerDescriptors,
              selectedManagedProviderId: controller.selectedManagedProviderId,
              draft: controller.managedProviderDraft,
              busy: controller.busy,
              onDraftChanged: controller.updateManagedProviderDraft,
              onSave: controller.saveManagedProviderDraft,
              onDelete: controller.deleteSelectedManagedProvider,
              onReset: controller.resetManagedProviderDraft,
              onApplyToProfileDraft: controller.useManagedProviderForDraft,
            ),
          ),
      ],
    );
  }
}

class _WorkflowSurfacePicker extends StatelessWidget {
  const _WorkflowSurfacePicker({required this.controller});

  final MobileShellController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        ChoiceChip(
          selected: controller.workflowSurface == MobileWorkflowSurface.profile,
          label: const Text('Profile draft'),
          onSelected: (_) => controller.showProfileWorkspace(),
        ),
        ChoiceChip(
          selected: controller.workflowSurface != MobileWorkflowSurface.profile,
          label: const Text('Providers'),
          onSelected: (_) => controller.showProviderWorkspace(),
        ),
      ],
    );
  }
}

class _PresetLibrarySection extends StatelessWidget {
  const _PresetLibrarySection({required this.controller});

  final MobileShellController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Presets',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bootstrap the main provider families without manually re-entering taxonomy every time.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ...controller.presetCatalog.map((ProviderPreset preset) {
              final availability = preset.availabilityFor(
                controller.providerDescriptors,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  key: ValueKey<String>('preset-card-${preset.id}'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              preset.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _StatusChip(
                            label: availability.isAvailable
                                ? 'Available'
                                : 'Unavailable',
                            accent: availability.isAvailable,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        preset.description,
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (!availability.isAvailable) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          availability.message,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      FilledButton.tonal(
                        key: ValueKey<String>('preset-use-${preset.id}'),
                        onPressed: controller.busy || !availability.isAvailable
                            ? null
                            : () => controller.applyPreset(preset),
                        child: const Text('Use preset'),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ProviderConfigLibrarySection extends StatelessWidget {
  const _ProviderConfigLibrarySection({required this.controller});

  final MobileShellController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Providers',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.tonal(
                  key: const ValueKey<String>('provider-config-create-button'),
                  onPressed: controller.busy
                      ? null
                      : controller.resetManagedProviderDraft,
                  child: const Text('New'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Managed provider records stay separate from profiles and prompt-only runtime input.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (controller.managedProviders.isEmpty)
              Text(
                'No managed providers yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...controller.managedProviders.map(
                (ManagedProviderRecord config) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color:
                        controller.workflowSurface !=
                                MobileWorkflowSurface.profile &&
                            controller.selectedManagedProviderId == config.id
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                        : theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.35,
                          ),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      key: ValueKey<String>(
                        'provider-config-item-${config.id}',
                      ),
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => controller.selectManagedProvider(config.id),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    config.name.isEmpty
                                        ? config.id
                                        : config.name,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                _StatusChip(
                                  label: config.availability.state.label,
                                  accent: config.isAvailable,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              config.provider,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (config
                                .availability
                                .message
                                .isNotEmpty) ...<Widget>[
                              const SizedBox(height: 4),
                              Text(
                                config.availability.message,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.accent});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = accent
        ? theme.colorScheme.primary.withValues(alpha: 0.14)
        : theme.colorScheme.surfaceContainerHighest;
    final foreground = accent
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActivityPage extends StatelessWidget {
  const _ActivityPage({
    required this.controller,
    required this.surface,
    required this.onLaunchChallengeSurface,
    required this.openChallengeLabel,
    required this.showsManualChallengeContinue,
    required this.onSurfaceChanged,
  });

  final MobileShellController controller;
  final _ActivitySurface surface;
  final Future<void> Function(ChallengeRecord challenge)
  onLaunchChallengeSurface;
  final String Function(ChallengeRecord? challenge) openChallengeLabel;
  final bool Function(ChallengeRecord? challenge) showsManualChallengeContinue;
  final ValueChanged<_ActivitySurface> onSurfaceChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _PageHeader(
            title: 'Activity',
            subtitle:
                'Inspect provider resolutions and session state without crowding the main workflow.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              ChoiceChip(
                selected: surface == _ActivitySurface.resolutions,
                label: Text(
                  'Resolutions (${controller.resolutions.length})',
                  style: theme.textTheme.labelLarge,
                ),
                onSelected: (_) =>
                    onSurfaceChanged(_ActivitySurface.resolutions),
              ),
              ChoiceChip(
                selected: surface == _ActivitySurface.sessions,
                label: Text(
                  'Sessions (${controller.sessions.length})',
                  style: theme.textTheme.labelLarge,
                ),
                onSelected: (_) => onSurfaceChanged(_ActivitySurface.sessions),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: switch (surface) {
              _ActivitySurface.resolutions => _ResolutionsPanel(
                controller: controller,
                onLaunchChallengeSurface: onLaunchChallengeSurface,
                openChallengeLabel: openChallengeLabel,
                showsManualChallengeContinue: showsManualChallengeContinue,
              ),
              _ActivitySurface.sessions => _SessionsPanel(
                controller: controller,
                onLaunchChallengeSurface: onLaunchChallengeSurface,
                openChallengeLabel: openChallengeLabel,
                showsManualChallengeContinue: showsManualChallengeContinue,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsPage extends StatelessWidget {
  const _DiagnosticsPage({
    required this.controller,
    required this.surface,
    required this.onSurfaceChanged,
  });

  final MobileShellController controller;
  final _DiagnosticsSurface surface;
  final ValueChanged<_DiagnosticsSurface> onSurfaceChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _PageHeader(
            title: 'Diagnostics',
            subtitle:
                'Detailed host readiness, platform tunnel detail, and recent typed events.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              ChoiceChip(
                selected: surface == _DiagnosticsSurface.overview,
                label: Text('Overview', style: theme.textTheme.labelLarge),
                onSelected: (_) =>
                    onSurfaceChanged(_DiagnosticsSurface.overview),
              ),
              ChoiceChip(
                selected: surface == _DiagnosticsSurface.events,
                label: Text(
                  'Events (${controller.events.length})',
                  style: theme.textTheme.labelLarge,
                ),
                onSelected: (_) => onSurfaceChanged(_DiagnosticsSurface.events),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: switch (surface) {
              _DiagnosticsSurface.overview => ListView(
                children: <Widget>[
                  _HostBanner(controller: controller),
                  const SizedBox(height: 12),
                  _SystemTunnelBanner(controller: controller),
                  if (controller.notice != null) ...<Widget>[
                    const SizedBox(height: 12),
                    _NoticeBanner(message: controller.notice!),
                  ],
                ],
              ),
              _DiagnosticsSurface.events => _EventsPanel(
                controller: controller,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _WorkflowSummaryCard extends StatelessWidget {
  const _WorkflowSummaryCard({
    required this.controller,
    required this.onOpenDiagnostics,
  });

  final MobileShellController controller;
  final VoidCallback onOpenDiagnostics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connection = controller.hostConnection;
    final hostInfo = connection?.info;
    final statusColor = _hostStatusColor(connection);
    final tunnelSummary = _homeTunnelSummary(controller);

    return Card(
      color: statusColor,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _homeWorkflowTitle(connection),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              connection?.message ??
                  'Waiting for mobile host bridge negotiation before workflow actions can continue.',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _Tag(label: 'GUI ${controller.appBuild.shortLabel}'),
                if (hostInfo != null)
                  _Tag(label: 'Host ${hostInfo.build.shortLabel}'),
                if (hostInfo != null)
                  _Tag(label: 'Contract ${hostInfo.contractVersion}'),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Tunnel summary',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(tunnelSummary, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: 14),
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
                FilledButton(
                  onPressed:
                      controller.busy ||
                          controller.hostConnection?.isReady != true
                      ? null
                      : () => unawaited(controller.refresh()),
                  child: const Text('Refresh'),
                ),
                OutlinedButton(
                  onPressed: onOpenDiagnostics,
                  child: const Text('Open diagnostics'),
                ),
                if (controller.requiresLocalStateReset)
                  OutlinedButton(
                    onPressed: controller.busy
                        ? null
                        : () => unawaited(controller.clearLocalState()),
                    child: const Text('Reset local state'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivitySummaryCard extends StatelessWidget {
  const _ActivitySummaryCard({
    required this.resolutionsCount,
    required this.sessionsCount,
    required this.onOpenActivity,
  });

  final int resolutionsCount;
  final int sessionsCount;
  final VoidCallback onOpenActivity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Live work',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Resolutions $resolutionsCount · Sessions $sessionsCount',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    resolutionsCount == 0 && sessionsCount == 0
                        ? 'Nothing active yet. Resolve or start from the workflow screen.'
                        : 'Move to Activity when you need current runtime state instead of draft editing.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: onOpenActivity,
              child: const Text('Open activity'),
            ),
          ],
        ),
      ),
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
    final color = _hostStatusColor(connection);

    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _diagnosticsHostTitle(connection),
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
  const _ResolutionsPanel({
    required this.controller,
    required this.onLaunchChallengeSurface,
    required this.openChallengeLabel,
    required this.showsManualChallengeContinue,
  });

  final MobileShellController controller;
  final Future<void> Function(ChallengeRecord challenge)
  onLaunchChallengeSurface;
  final String Function(ChallengeRecord? challenge) openChallengeLabel;
  final bool Function(ChallengeRecord? challenge) showsManualChallengeContinue;

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
              'Resolve the invite first, then use the capability-gated action set to start on this device, export a handoff, or open provider-native targets.',
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
                              : () => onLaunchChallengeSurface(challenge),
                          openChallengeLabel: openChallengeLabel(challenge),
                          onContinueChallenge:
                              challenge == null ||
                                  !showsManualChallengeContinue(challenge)
                              ? null
                              : () =>
                                    controller.continueChallenge(challenge.id),
                          onCancelChallenge: challenge == null
                              ? null
                              : () => controller.cancelChallenge(challenge.id),
                          onMaterialize:
                              resolution.state == ResolutionState.resolved &&
                                  resolution.supportsAction(
                                    ArtifactAction.startOnThisDevice,
                                  )
                              ? () => controller.materializeResolution(
                                  resolution.id,
                                )
                              : null,
                          onCopyExport:
                              resolution.state == ResolutionState.resolved &&
                                  resolution.supportsAction(
                                    ArtifactAction.exportHandoff,
                                  )
                              ? () => controller.copyResolutionExport(
                                  resolution.id,
                                )
                              : null,
                          onShareExport:
                              resolution.state == ResolutionState.resolved &&
                                  resolution.supportsAction(
                                    ArtifactAction.exportHandoff,
                                  )
                              ? () => controller.shareResolutionExport(
                                  resolution.id,
                                )
                              : null,
                          onOpenRoom:
                              resolution.state == ResolutionState.resolved &&
                                  resolution.supportsAction(
                                    ArtifactAction.openRoom,
                                  )
                              ? () => controller.openResolutionExternalAction(
                                  resolution.id,
                                  ArtifactAction.openRoom,
                                )
                              : null,
                          onOpenCamera:
                              resolution.state == ResolutionState.resolved &&
                                  resolution.supportsAction(
                                    ArtifactAction.openCamera,
                                  )
                              ? () => controller.openResolutionExternalAction(
                                  resolution.id,
                                  ArtifactAction.openCamera,
                                )
                              : null,
                          onOpenArchive:
                              resolution.state == ResolutionState.resolved &&
                                  resolution.supportsAction(
                                    ArtifactAction.openArchive,
                                  )
                              ? () => controller.openResolutionExternalAction(
                                  resolution.id,
                                  ArtifactAction.openArchive,
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
    required this.openChallengeLabel,
    required this.onContinueChallenge,
    required this.onCancelChallenge,
    required this.onMaterialize,
    required this.onCopyExport,
    required this.onShareExport,
    required this.onOpenRoom,
    required this.onOpenCamera,
    required this.onOpenArchive,
    required this.onCancel,
  });

  final ResolutionRecord resolution;
  final ChallengeRecord? challenge;
  final bool busy;
  final bool selected;
  final VoidCallback onSelect;
  final Future<void> Function()? onOpenChallenge;
  final String openChallengeLabel;
  final Future<void> Function()? onContinueChallenge;
  final Future<void> Function()? onCancelChallenge;
  final Future<void> Function()? onMaterialize;
  final Future<void> Function()? onCopyExport;
  final Future<void> Function()? onShareExport;
  final Future<void> Function()? onOpenRoom;
  final Future<void> Function()? onOpenCamera;
  final Future<void> Function()? onOpenArchive;
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
              if (resolution.artifact != null) ...<Widget>[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _Tag(label: resolution.artifact!.family.label),
                    for (final action in resolution.artifact!.actions)
                      _Tag(
                        label:
                            '${action.id.label} · ${action.executionOwner.value}',
                      ),
                  ],
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
                          if (onOpenChallenge != null)
                            FilledButton.tonal(
                              onPressed: busy
                                  ? null
                                  : () => unawaited(onOpenChallenge!.call()),
                              child: Text(openChallengeLabel),
                            ),
                          if (onContinueChallenge != null)
                            FilledButton(
                              onPressed: busy
                                  ? null
                                  : () =>
                                        unawaited(onContinueChallenge!.call()),
                              child: const Text("I've completed it"),
                            ),
                          if (onCancelChallenge != null)
                            _ActionOverflowButton(
                              tooltip: 'More challenge actions',
                              enabled: !busy,
                              actions: <_CardActionEntry>[
                                _CardActionEntry(
                                  id: 'cancel-challenge',
                                  label: 'Cancel challenge',
                                  onSelected: onCancelChallenge!,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _ActionRow(
                busy: busy,
                primaryAction: _primaryAction(),
                secondaryActions: _secondaryActions(),
                overflowTooltip: 'More resolution actions',
              ),
            ],
          ),
        ),
      ),
    );
  }

  _CardActionEntry? _primaryAction() {
    final actions = <_CardActionEntry>[
      if (onMaterialize != null)
        _CardActionEntry(
          id: 'materialize',
          label: 'Start on this device',
          onSelected: onMaterialize!,
        ),
      if (onShareExport != null)
        _CardActionEntry(
          id: 'share-export',
          label: 'Share handoff',
          onSelected: onShareExport!,
        ),
      if (onOpenRoom != null)
        _CardActionEntry(
          id: 'open-room',
          label: 'Open room',
          onSelected: onOpenRoom!,
        ),
      if (onOpenCamera != null)
        _CardActionEntry(
          id: 'open-camera',
          label: 'Open camera',
          onSelected: onOpenCamera!,
        ),
      if (onOpenArchive != null)
        _CardActionEntry(
          id: 'open-archive',
          label: 'Open archive',
          onSelected: onOpenArchive!,
        ),
      if (onCopyExport != null)
        _CardActionEntry(
          id: 'copy-export',
          label: 'Copy handoff',
          onSelected: onCopyExport!,
        ),
      if (onCancel != null)
        _CardActionEntry(
          id: 'cancel-resolution',
          label: 'Cancel resolution',
          onSelected: onCancel!,
        ),
    ];
    return actions.isEmpty ? null : actions.first;
  }

  List<_CardActionEntry> _secondaryActions() {
    final primaryId = _primaryAction()?.id;
    return <_CardActionEntry>[
      if (onCopyExport != null)
        _CardActionEntry(
          id: 'copy-export',
          label: 'Copy handoff',
          onSelected: onCopyExport!,
        ),
      if (onShareExport != null)
        _CardActionEntry(
          id: 'share-export',
          label: 'Share handoff',
          onSelected: onShareExport!,
        ),
      if (onOpenRoom != null)
        _CardActionEntry(
          id: 'open-room',
          label: 'Open room',
          onSelected: onOpenRoom!,
        ),
      if (onOpenCamera != null)
        _CardActionEntry(
          id: 'open-camera',
          label: 'Open camera',
          onSelected: onOpenCamera!,
        ),
      if (onOpenArchive != null)
        _CardActionEntry(
          id: 'open-archive',
          label: 'Open archive',
          onSelected: onOpenArchive!,
        ),
      if (onCancel != null)
        _CardActionEntry(
          id: 'cancel-resolution',
          label: 'Cancel resolution',
          onSelected: onCancel!,
        ),
    ].where((entry) => entry.id != primaryId).toList(growable: false);
  }
}

class _SessionsPanel extends StatelessWidget {
  const _SessionsPanel({
    required this.controller,
    required this.onLaunchChallengeSurface,
    required this.openChallengeLabel,
    required this.showsManualChallengeContinue,
  });

  final MobileShellController controller;
  final Future<void> Function(ChallengeRecord challenge)
  onLaunchChallengeSurface;
  final String Function(ChallengeRecord? challenge) openChallengeLabel;
  final bool Function(ChallengeRecord? challenge) showsManualChallengeContinue;

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
                              : () => onLaunchChallengeSurface(challenge),
                          openChallengeLabel: openChallengeLabel(challenge),
                          onContinueChallenge:
                              challenge == null ||
                                  !showsManualChallengeContinue(challenge)
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
    required this.openChallengeLabel,
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
  final String openChallengeLabel;
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
                          if (onOpenChallenge != null)
                            FilledButton.tonal(
                              onPressed: busy
                                  ? null
                                  : () => unawaited(onOpenChallenge!.call()),
                              child: Text(openChallengeLabel),
                            ),
                          if (onContinueChallenge != null)
                            FilledButton(
                              onPressed: busy
                                  ? null
                                  : () =>
                                        unawaited(onContinueChallenge!.call()),
                              child: const Text("I've completed it"),
                            ),
                          if (onCancelChallenge != null)
                            _ActionOverflowButton(
                              tooltip: 'More challenge actions',
                              enabled: !busy,
                              actions: <_CardActionEntry>[
                                _CardActionEntry(
                                  id: 'cancel-challenge',
                                  label: 'Cancel challenge',
                                  onSelected: onCancelChallenge!,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _ActionRow(
                busy: busy,
                primaryAction: _primaryAction(),
                secondaryActions: _secondaryActions(),
                overflowTooltip: 'More session actions',
              ),
            ],
          ),
        ),
      ),
    );
  }

  _CardActionEntry _primaryAction() {
    if (session.state != SessionState.stopped &&
        session.state != SessionState.failed) {
      return _CardActionEntry(
        id: 'stop-session',
        label: 'Stop session',
        onSelected: onStop,
      );
    }
    return _CardActionEntry(
      id: 'export-diagnostics',
      label: 'Export diagnostics',
      onSelected: onExport,
    );
  }

  List<_CardActionEntry> _secondaryActions() {
    final primaryId = _primaryAction().id;
    return <_CardActionEntry>[
      _CardActionEntry(
        id: 'export-diagnostics',
        label: 'Export diagnostics',
        onSelected: onExport,
      ),
      if (session.state != SessionState.stopped &&
          session.state != SessionState.failed)
        _CardActionEntry(
          id: 'stop-session',
          label: 'Stop session',
          onSelected: onStop,
        ),
    ].where((entry) => entry.id != primaryId).toList(growable: false);
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

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.busy,
    required this.primaryAction,
    required this.secondaryActions,
    required this.overflowTooltip,
  });

  final bool busy;
  final _CardActionEntry? primaryAction;
  final List<_CardActionEntry> secondaryActions;
  final String overflowTooltip;

  @override
  Widget build(BuildContext context) {
    if (primaryAction == null && secondaryActions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: <Widget>[
        if (primaryAction != null)
          Expanded(
            child: FilledButton(
              onPressed: busy
                  ? null
                  : () => unawaited(primaryAction!.onSelected()),
              child: Text(primaryAction!.label),
            ),
          ),
        if (primaryAction != null && secondaryActions.isNotEmpty)
          const SizedBox(width: 12),
        if (secondaryActions.isNotEmpty)
          _ActionOverflowButton(
            tooltip: overflowTooltip,
            enabled: !busy,
            actions: secondaryActions,
          ),
      ],
    );
  }
}

class _ActionOverflowButton extends StatelessWidget {
  const _ActionOverflowButton({
    required this.tooltip,
    required this.enabled,
    required this.actions,
  });

  final String tooltip;
  final bool enabled;
  final List<_CardActionEntry> actions;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_CardActionEntry>(
      enabled: enabled,
      tooltip: tooltip,
      icon: const Icon(Icons.more_horiz),
      onSelected: (_CardActionEntry action) => unawaited(action.onSelected()),
      itemBuilder: (BuildContext context) {
        return actions
            .map((entry) {
              return PopupMenuItem<_CardActionEntry>(
                value: entry,
                child: Text(entry.label),
              );
            })
            .toList(growable: false);
      },
    );
  }
}

class _CardActionEntry {
  const _CardActionEntry({
    required this.id,
    required this.label,
    required this.onSelected,
  });

  final String id;
  final String label;
  final Future<void> Function() onSelected;
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

Color _hostStatusColor(MobileHostConnectionResult? connection) {
  return switch (connection?.state) {
    MobileHostLifecycleState.ready => const Color(0xFFDEF2E1),
    MobileHostLifecycleState.incompatible => const Color(0xFFFFE5CC),
    MobileHostLifecycleState.failed => const Color(0xFFFFE0DF),
    _ => const Color(0xFFE5ECF6),
  };
}

String _diagnosticsHostTitle(MobileHostConnectionResult? connection) {
  return switch (connection?.state) {
    MobileHostLifecycleState.ready => 'Mobile host ready',
    MobileHostLifecycleState.incompatible => 'Mobile host incompatible',
    MobileHostLifecycleState.failed => 'Mobile host blocked',
    _ => 'Connecting to mobile host',
  };
}

String _homeWorkflowTitle(MobileHostConnectionResult? connection) {
  return switch (connection?.state) {
    MobileHostLifecycleState.ready => 'Workflow ready',
    MobileHostLifecycleState.incompatible =>
      'Workflow blocked by host mismatch',
    MobileHostLifecycleState.failed => 'Workflow blocked by host state',
    _ => 'Workflow is connecting to the mobile host',
  };
}

String _homeTunnelSummary(MobileShellController controller) {
  final capabilities = controller.platformTunnels;
  if (capabilities.isEmpty) {
    return 'No typed platform tunnel modes are reported yet. Device-wide capture still remains fail-closed on this slice.';
  }

  final available = capabilities.where((item) => item.available).length;
  final unavailable = capabilities.length - available;
  final lines = <String>[
    '$available available · $unavailable unavailable mobile tunnel modes.',
  ];
  for (final capability in capabilities.take(2)) {
    final result = controller.platformTunnelResultFor(capability.mode);
    final capabilitySummary = capability.available
        ? '${capability.mode.label}: available'
        : '${capability.mode.label}: ${capability.missingPrerequisite?.label ?? 'unavailable'}';
    lines.add(capabilitySummary);
    if (result != null) {
      lines.add(_platformTunnelResultSummary(result));
    }
  }
  if (capabilities.length > 2) {
    lines.add('Open diagnostics to inspect the rest of the reported modes.');
  }
  return lines.join(' ');
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
