import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/desktop_host_supervisor.dart';
import 'package:gui_shell/src/control/desktop_shell_controller.dart';
import 'package:gui_shell/src/ui/profile_library_panel.dart';
import 'package:gui_shell/src/ui/provider_config_editor.dart';
import 'package:gui_shell/src/ui/profile_editor.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.controller});

  final DesktopShellController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final theme = Theme.of(context);
        final busy = controller.busy || controller.status != ShellStatus.ready;
        final profileLibrary = ProfileLibraryPanel(
          presets: controller.presetCatalog,
          providerDescriptors: controller.providerDescriptors,
          managedProviders: controller.managedProviders,
          profiles: controller.profiles,
          selectedManagedProviderId: controller.selectedManagedProviderId,
          activeSurface: controller.workspaceSurface,
          selectedProfileId: controller.selectedProfileId,
          busy: busy,
          onApplyPreset: controller.applyPreset,
          onSelectManagedProvider: controller.selectManagedProvider,
          onCreateManagedProvider: controller.resetManagedProviderDraft,
          onSelectProfile: controller.selectProfile,
          onCreateDraft: controller.resetDraft,
        );
        final profileWorkspace =
            controller.workspaceSurface == DesktopWorkspaceSurface.profile
            ? ProfileEditorPanel(
                providerDescriptors: controller.providerDescriptors,
                managedProviders: controller.managedProviders,
                initialManagedProviderId:
                    controller.draft.providerBinding.managedProviderId,
                selectedProfileId: controller.selectedProfileId,
                draft: controller.draft,
                busy: busy,
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
            : ProviderConfigEditorPanel(
                supportedProviders: controller.supportedProviderCatalog,
                providerDescriptors: controller.providerDescriptors,
                selectedManagedProviderId: controller.selectedManagedProviderId,
                draft: controller.managedProviderDraft,
                busy: busy,
                onDraftChanged: controller.updateManagedProviderDraft,
                onSave: controller.saveManagedProviderDraft,
                onDelete: controller.deleteSelectedManagedProvider,
                onReset: controller.resetManagedProviderDraft,
                onApplyToProfileDraft: controller.useManagedProviderForDraft,
              );
        final hasLiveWork =
            controller.resolutions.isNotEmpty || controller.sessions.isNotEmpty;

        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints rootConstraints) {
                final compactHeading = rootConstraints.maxWidth >= 1180;

                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Desktop control shell',
                        style:
                            (compactHeading
                                    ? theme.textTheme.headlineMedium
                                    : theme.textTheme.displaySmall)
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.primary,
                                ),
                      ),
                      SizedBox(height: compactHeading ? 4 : 8),
                      Text(
                        'Profiles, sidecar supervision, challenge handoff, session states, and diagnostics without terminal-only workflows.',
                        style:
                            (compactHeading
                                    ? theme.textTheme.bodyMedium
                                    : theme.textTheme.bodyLarge)
                                ?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                      ),
                      SizedBox(height: compactHeading ? 14 : 20),
                      _OperationalHeader(controller: controller),
                      SizedBox(height: compactHeading ? 16 : 20),
                      Expanded(
                        child: LayoutBuilder(
                          builder:
                              (
                                BuildContext context,
                                BoxConstraints constraints,
                              ) {
                                if (constraints.maxWidth >= 1440) {
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      SizedBox(
                                        width: 300,
                                        child: profileLibrary,
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: <Widget>[
                                            Expanded(child: profileWorkspace),
                                            if (hasLiveWork) ...<Widget>[
                                              const SizedBox(height: 20),
                                              SizedBox(
                                                height: 360,
                                                child: _ActivityWorkspace(
                                                  controller: controller,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      SizedBox(
                                        width: 360,
                                        child: _SecondaryInspector(
                                          controller: controller,
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                if (constraints.maxWidth >= 1120) {
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      SizedBox(
                                        width: 280,
                                        child: profileLibrary,
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: <Widget>[
                                            Expanded(child: profileWorkspace),
                                            if (hasLiveWork) ...<Widget>[
                                              const SizedBox(height: 20),
                                              SizedBox(
                                                height: 320,
                                                child: _ActivityWorkspace(
                                                  controller: controller,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 20),
                                            SizedBox(
                                              height: 340,
                                              child: _SecondaryInspector(
                                                controller: controller,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                return SingleChildScrollView(
                                  child: Column(
                                    children: <Widget>[
                                      SizedBox(
                                        height: 260,
                                        child: profileLibrary,
                                      ),
                                      const SizedBox(height: 20),
                                      SizedBox(
                                        height: 760,
                                        child: profileWorkspace,
                                      ),
                                      if (hasLiveWork) ...<Widget>[
                                        const SizedBox(height: 20),
                                        SizedBox(
                                          height: 420,
                                          child: _ActivityWorkspace(
                                            controller: controller,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 20),
                                      SizedBox(
                                        height: 420,
                                        child: _SecondaryInspector(
                                          controller: controller,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _OperationalHeader extends StatelessWidget {
  const _OperationalHeader({required this.controller});

  final DesktopShellController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connection = controller.hostConnection;
    final hostInfo = connection?.info;
    final status = controller.status;
    final title = switch (status) {
      ShellStatus.booting => 'Connecting to local host',
      ShellStatus.ready => 'Local host ready',
      ShellStatus.blocked => 'Local host blocked',
    };
    final detail =
        connection?.message ??
        switch (status) {
          ShellStatus.booting =>
            'Starting local host and negotiating capabilities.',
          ShellStatus.ready => 'Connected to local host.',
          ShellStatus.blocked => 'Waiting for local host negotiation.',
        };
    final color = switch (connection?.state) {
      HostLifecycleState.ready => const Color(0xFFDEF2E1),
      HostLifecycleState.incompatible => const Color(0xFFFFE5CC),
      HostLifecycleState.failed => const Color(0xFFFFE0DF),
      _ => const Color(0xFFE5ECF6),
    };
    final tunnelSummary = _platformTunnelHeaderSummary(controller);
    final tunnelModes = controller.platformTunnels.length;
    final readyTunnelModes = controller.platformTunnels
        .where((PlatformTunnelCapability capability) => capability.available)
        .length;

    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final stacked = constraints.maxWidth < 1100;
            final hostSummary = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(detail),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _Tag(
                      label: 'GUI ${controller.appBuild.shortLabel}',
                      dense: false,
                    ),
                    if (hostInfo != null)
                      _Tag(label: 'Host ${hostInfo.build.shortLabel}'),
                    if (hostInfo != null)
                      _Tag(label: 'Contract ${hostInfo.contractVersion}'),
                    if (connection?.launched == true) _Tag(label: 'launched'),
                    if (connection?.launchSpec != null)
                      _Tag(label: connection!.launchSpec!.description),
                  ],
                ),
              ],
            );
            final operationsAside = Column(
              crossAxisAlignment: stacked
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.66),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: stacked
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        readyTunnelModes > 0
                            ? '$readyTunnelModes/$tunnelModes tunnel modes ready'
                            : 'Platform tunnel summary',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tunnelSummary,
                        textAlign: stacked ? TextAlign.start : TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: stacked ? WrapAlignment.start : WrapAlignment.end,
                  children: <Widget>[
                    FilledButton.tonal(
                      onPressed: controller.busy
                          ? null
                          : () => unawaited(controller.reconnect()),
                      child: const Text('Reconnect'),
                    ),
                    FilledButton(
                      onPressed:
                          controller.busy ||
                              controller.status != ShellStatus.ready
                          ? null
                          : () => unawaited(controller.refresh()),
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              ],
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (stacked)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      hostSummary,
                      const SizedBox(height: 14),
                      operationsAside,
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: hostSummary),
                      const SizedBox(width: 18),
                      SizedBox(width: 320, child: operationsAside),
                    ],
                  ),
                if (controller.notice != null) ...<Widget>[
                  const SizedBox(height: 14),
                  _NoticeBanner(message: controller.notice!),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActivityWorkspace extends StatelessWidget {
  const _ActivityWorkspace({required this.controller});

  final DesktopShellController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initialIndex =
        controller.sessions.isNotEmpty &&
            (controller.selectedSessionId != null ||
                controller.resolutions.isEmpty)
        ? 1
        : 0;

    return DefaultTabController(
      key: ValueKey<String>(
        'activity-${controller.resolutions.length}-${controller.sessions.length}-${controller.selectedResolutionId ?? 'none'}-${controller.selectedSessionId ?? 'none'}',
      ),
      length: 2,
      initialIndex: initialIndex,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Live work',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Inspect the currently selected resolution or session without dedicating the full desktop canvas to empty activity panels.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TabBar(
                isScrollable: true,
                tabs: <Widget>[
                  Tab(text: 'Resolutions (${controller.resolutions.length})'),
                  Tab(text: 'Sessions (${controller.sessions.length})'),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    _ResolutionsPanel(controller: controller, embedded: true),
                    _SessionsPanel(controller: controller, embedded: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryInspector extends StatelessWidget {
  const _SecondaryInspector({required this.controller});

  final DesktopShellController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Diagnostics',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Secondary support surfaces stay here: typed events and detailed platform-tunnel startup evidence.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const TabBar(
                    tabs: <Widget>[
                      Tab(text: 'Events'),
                      Tab(text: 'Tunnel detail'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _EventsPanel(controller: controller),
                _PlatformTunnelPanel(controller: controller, compact: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformTunnelPanel extends StatelessWidget {
  const _PlatformTunnelPanel({required this.controller, this.compact = false});

  final DesktopShellController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platformTunnels = controller.platformTunnels;
    final showCompactUnavailableSummary =
        platformTunnels.isNotEmpty &&
        platformTunnels.every(
          (PlatformTunnelCapability capability) => !capability.available,
        ) &&
        platformTunnels.every(
          (PlatformTunnelCapability capability) =>
              controller.platformTunnelResultFor(capability.mode) == null,
        );
    final body = switch ((
      platformTunnels.isEmpty,
      compact,
      showCompactUnavailableSummary,
    )) {
      (true, _, _) => <Widget>[
        Text(
          'The connected host did not report any desktop platform tunnel modes.',
          style: theme.textTheme.bodyMedium,
        ),
      ],
      (false, true, true) => <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: platformTunnels.map((PlatformTunnelCapability capability) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    _compactPlatformTunnelStatusLabel(capability),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed:
                        controller.busy ||
                            controller.hostConnection?.isReady != true
                        ? null
                        : () => unawaited(
                            controller.startPlatformTunnel(capability.mode),
                          ),
                    child: const Text('Request startup'),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
      (_, _, true) => platformTunnels.map((
        PlatformTunnelCapability capability,
      ) {
        return Padding(
          padding: EdgeInsets.only(bottom: compact ? 8 : 12),
          child: _CompactPlatformTunnelCard(
            capability: capability,
            busy: controller.busy,
            ready: controller.hostConnection?.isReady == true,
            compact: compact,
            onStart: () => controller.startPlatformTunnel(capability.mode),
          ),
        );
      }).toList(),
      _ => platformTunnels.map((PlatformTunnelCapability capability) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _PlatformTunnelCard(
            capability: capability,
            result: controller.platformTunnelResultFor(capability.mode),
            busy: controller.busy,
            ready: controller.hostConnection?.isReady == true,
            onStart: () => controller.startPlatformTunnel(capability.mode),
          ),
        );
      }).toList(),
    };

    return Card(
      color: const Color(0xFFE6EDF7),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Platform tunnel modes',
              style:
                  (compact
                          ? theme.textTheme.titleSmall
                          : theme.textTheme.titleLarge)
                      ?.copyWith(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: compact ? 4 : 6),
            Text(
              showCompactUnavailableSummary
                  ? compact
                        ? 'Fail-closed platform tunnel checks stay collapsed until you explicitly test startup.'
                        : 'The connected host only reports fail-closed platform tunnel modes, so this section stays compact until you explicitly test startup.'
                  : 'The desktop shell reads typed host tunnel capabilities and startup stages instead of guessing system routing support from the OS or app bundle.',
              style:
                  (compact
                          ? theme.textTheme.bodySmall
                          : theme.textTheme.bodyMedium)
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            SizedBox(height: compact ? 10 : 14),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: body,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactPlatformTunnelCard extends StatelessWidget {
  const _CompactPlatformTunnelCard({
    required this.capability,
    required this.busy,
    required this.ready,
    required this.compact,
    required this.onStart,
  });

  final PlatformTunnelCapability capability;
  final bool busy;
  final bool ready;
  final bool compact;
  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
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
                  color: const Color(0xFFFFF1D6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'unavailable',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            _compactPlatformTunnelCapabilitySummary(capability),
            style: compact
                ? theme.textTheme.bodySmall
                : theme.textTheme.bodyMedium,
          ),
          SizedBox(height: compact ? 8 : 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: busy || !ready ? null : () => unawaited(onStart()),
              child: const Text('Request startup'),
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(16),
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
                ? 'No startup request yet. Use the typed host contract to verify the fail-closed path.'
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

class _ResolutionsPanel extends StatelessWidget {
  const _ResolutionsPanel({required this.controller, this.embedded = false});

  final DesktopShellController controller;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
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
          'Invite resolution stays separate from runtime sessions until you explicitly start on this device or copy a handoff link.',
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
                  key: const ValueKey<String>('resolutions-scroll'),
                  itemCount: controller.resolutions.length,
                  separatorBuilder: (_, int index) =>
                      const SizedBox(height: 14),
                  itemBuilder: (BuildContext context, int index) {
                    final resolution = controller.resolutions[index];
                    final challenge = controller.activeChallengeForResolution(
                      resolution,
                    );
                    return _ResolutionCard(
                      resolution: resolution,
                      challenge: challenge,
                      busy:
                          controller.busy ||
                          controller.status != ShellStatus.ready,
                      selected:
                          controller.selectedResolutionId == resolution.id,
                      onSelect: () =>
                          controller.selectResolution(resolution.id),
                      onCancel: resolution.isTerminal
                          ? null
                          : () => controller.cancelResolution(resolution.id),
                      onMaterialize:
                          resolution.state == ResolutionState.resolved &&
                              resolution.supportsAction(
                                ArtifactAction.startOnThisDevice,
                              )
                          ? () =>
                                controller.materializeResolution(resolution.id)
                          : null,
                      onCopyExport:
                          resolution.state == ResolutionState.resolved &&
                              resolution.supportsAction(
                                ArtifactAction.exportHandoff,
                              )
                          ? () => controller.copyResolutionExport(resolution.id)
                          : null,
                      onOpenRoom:
                          resolution.state == ResolutionState.resolved &&
                              resolution.supportsAction(ArtifactAction.openRoom)
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
                      onContinueChallenge: challenge == null
                          ? null
                          : () => controller.continueChallenge(challenge.id),
                      onCancelChallenge: challenge == null
                          ? null
                          : () => controller.cancelChallenge(challenge.id),
                    );
                  },
                ),
        ),
      ],
    );

    if (embedded) {
      return content;
    }

    return Card(
      child: Padding(padding: const EdgeInsets.all(20), child: content),
    );
  }
}

class _SessionsPanel extends StatelessWidget {
  const _SessionsPanel({required this.controller, this.embedded = false});

  final DesktopShellController controller;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
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
                    'No active or recent sessions yet.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  key: const ValueKey<String>('sessions-scroll'),
                  itemCount: controller.sessions.length,
                  separatorBuilder: (_, int index) =>
                      const SizedBox(height: 14),
                  itemBuilder: (BuildContext context, int index) {
                    final session = controller.sessions[index];
                    final challenge = controller.activeChallengeFor(session);
                    return _SessionCard(
                      session: session,
                      challenge: challenge,
                      busy:
                          controller.busy ||
                          controller.status != ShellStatus.ready,
                      selected: controller.selectedSessionId == session.id,
                      onSelect: () => controller.selectSession(session.id),
                      onStop: () => controller.stopSession(session.id),
                      onExport: () => controller.exportDiagnostics(session.id),
                      onContinueChallenge: challenge == null
                          ? null
                          : () => controller.continueChallenge(challenge.id),
                      onCancelChallenge: challenge == null
                          ? null
                          : () => controller.cancelChallenge(challenge.id),
                    );
                  },
                ),
        ),
      ],
    );

    if (embedded) {
      return content;
    }

    return Card(
      child: Padding(padding: const EdgeInsets.all(20), child: content),
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
    required this.onCancel,
    required this.onMaterialize,
    required this.onCopyExport,
    required this.onOpenRoom,
    required this.onOpenCamera,
    required this.onOpenArchive,
    required this.onContinueChallenge,
    required this.onCancelChallenge,
  });

  final ResolutionRecord resolution;
  final ChallengeRecord? challenge;
  final bool busy;
  final bool selected;
  final VoidCallback onSelect;
  final Future<void> Function()? onCancel;
  final Future<void> Function()? onMaterialize;
  final Future<void> Function()? onCopyExport;
  final Future<void> Function()? onOpenRoom;
  final Future<void> Function()? onOpenCamera;
  final Future<void> Function()? onOpenArchive;
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
                  'Export expiry ${resolution.export.expiresAt!.toLocal().toIso8601String()}'
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
                      if ((challenge!.openUrl ?? '').isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        SelectableText(
                          challenge!.openUrl!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          FilledButton(
                            onPressed: busy || onContinueChallenge == null
                                ? null
                                : () => unawaited(onContinueChallenge!.call()),
                            child: const Text('Continue after browser step'),
                          ),
                          OutlinedButton(
                            onPressed: busy || onCancelChallenge == null
                                ? null
                                : () => unawaited(onCancelChallenge!.call()),
                            child: const Text('Cancel challenge'),
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
                    onPressed: busy || onMaterialize == null
                        ? null
                        : () => unawaited(onMaterialize!.call()),
                    child: const Text('Start on this device'),
                  ),
                  OutlinedButton(
                    onPressed: busy || onCopyExport == null
                        ? null
                        : () => unawaited(onCopyExport!.call()),
                    child: const Text('Copy handoff'),
                  ),
                  if (onOpenRoom != null)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => unawaited(onOpenRoom!.call()),
                      child: const Text('Open room'),
                    ),
                  if (onOpenCamera != null)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => unawaited(onOpenCamera!.call()),
                      child: const Text('Open camera'),
                    ),
                  if (onOpenArchive != null)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => unawaited(onOpenArchive!.call()),
                      child: const Text('Open archive'),
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

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.challenge,
    required this.busy,
    required this.selected,
    required this.onSelect,
    required this.onStop,
    required this.onExport,
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
                            onPressed: busy || onContinueChallenge == null
                                ? null
                                : () => unawaited(onContinueChallenge!.call()),
                            child: const Text('Continue in browser'),
                          ),
                          OutlinedButton(
                            onPressed: busy || onCancelChallenge == null
                                ? null
                                : () => unawaited(onCancelChallenge!.call()),
                            child: const Text('Cancel challenge'),
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

  final DesktopShellController controller;

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
              'Typed state transitions and challenge updates from /v1/events.',
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
                      key: const ValueKey<String>('events-scroll'),
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
  const _Tag({required this.label, this.dense = false});

  final String label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 10 : 12,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: dense ? Theme.of(context).textTheme.bodySmall : null,
      ),
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

String _platformTunnelHeaderSummary(DesktopShellController controller) {
  final platformTunnels = controller.platformTunnels;
  if (platformTunnels.isEmpty) {
    return 'No platform tunnel modes reported by the connected host.';
  }

  final readyCount = platformTunnels
      .where((PlatformTunnelCapability capability) => capability.available)
      .length;
  if (readyCount > 0) {
    return 'Use Diagnostics -> Tunnel detail to inspect startup stages and fail-closed results for the reported modes.';
  }

  final startupRequested = platformTunnels.any(
    (PlatformTunnelCapability capability) =>
        controller.platformTunnelResultFor(capability.mode) != null,
  );
  if (startupRequested) {
    return 'All reported tunnel modes are still fail-closed; inspect Diagnostics -> Tunnel detail for the latest startup evidence.';
  }

  return 'All reported tunnel modes are currently fail-closed. Use Diagnostics -> Tunnel detail when you want to test startup explicitly.';
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
    return 'The host reports that this mode is available.';
  }
  return 'The host reports that this mode is unavailable.';
}

String _compactPlatformTunnelCapabilitySummary(
  PlatformTunnelCapability capability,
) {
  final buffer = StringBuffer(
    capability.available
        ? '${capability.mode.label} is available for the connected host.'
        : '${capability.mode.label} is unavailable',
  );
  if (capability.missingPrerequisite != null) {
    buffer.write(
      ' because ${capability.missingPrerequisite!.label} is still missing.',
    );
  } else if (!capability.available) {
    buffer.write(' for the connected host.');
  }
  if (capability.message.isNotEmpty) {
    buffer.write(' ${capability.message}');
  }
  return buffer.toString();
}

String _compactPlatformTunnelStatusLabel(PlatformTunnelCapability capability) {
  final missing = capability.missingPrerequisite;
  if (missing == null) {
    return '${capability.mode.label} unavailable';
  }
  return '${capability.mode.label}: ${missing.label} missing';
}

String _platformTunnelResultSummary(PlatformTunnelStartResult result) {
  if (result.ready) {
    return '${result.mode.label} reached ready state for the desktop host tunnel path.';
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
