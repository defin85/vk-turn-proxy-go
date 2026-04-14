import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/desktop_host_supervisor.dart';
import 'package:gui_shell/src/control/desktop_shell_controller.dart';
import 'package:gui_shell/src/ui/profile_library_panel.dart';
import 'package:gui_shell/src/ui/provider_config_editor.dart';
import 'package:gui_shell/src/ui/profile_editor.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.controller});

  final DesktopShellController controller;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const double _compactWidth = 1180;
  static const double _persistentInspectorWidth = 1520;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FocusNode _profileWorkflowFocusNode = FocusNode(
    debugLabel: 'desktop-profile-workflow',
  );
  final FocusNode _providerWorkflowFocusNode = FocusNode(
    debugLabel: 'desktop-provider-workflow',
  );
  bool? _lastPersistentInspector;

  DesktopShellController get controller => widget.controller;

  FocusNode get _activeWorkflowFocusNode =>
      controller.activeSection == DesktopShellSection.profileWorkflow
      ? _profileWorkflowFocusNode
      : _providerWorkflowFocusNode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreWorkflowFocus();
    });
  }

  @override
  void dispose() {
    _profileWorkflowFocusNode.dispose();
    _providerWorkflowFocusNode.dispose();
    super.dispose();
  }

  void _openNavigationDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _restoreWorkflowFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _activeWorkflowFocusNode.requestFocus();
    });
  }

  void _openOverlayInspector(DesktopInspectorPane pane) {
    controller.openInspector(pane: pane);
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _closeOverlayInspector() {
    controller.closeInspector();
    Navigator.of(context).maybePop();
    _restoreWorkflowFocus();
  }

  void _syncInspectorPresentation({required bool persistent}) {
    if (_lastPersistentInspector == persistent) {
      return;
    }
    _lastPersistentInspector = persistent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final scaffold = _scaffoldKey.currentState;
      if (persistent) {
        if (scaffold?.isEndDrawerOpen ?? false) {
          Navigator.of(context).maybePop();
          _restoreWorkflowFocus();
        }
        return;
      }
      if (controller.isInspectorOpen && !(scaffold?.isEndDrawerOpen ?? false)) {
        scaffold?.openEndDrawer();
      }
    });
  }

  void _handleInspectorAction({
    required DesktopInspectorPane pane,
    required bool persistent,
  }) {
    if (persistent) {
      controller.toggleInspector(pane: pane);
      return;
    }
    _openOverlayInspector(pane);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final showCompactLayout = constraints.maxWidth < _compactWidth;
        final showPersistentInspector =
            constraints.maxWidth >= _persistentInspectorWidth;
        _syncInspectorPresentation(persistent: showPersistentInspector);
        final shellChromeListenable = Listenable.merge(<Listenable>[
          controller.shellChromeRevision,
          controller.workflowRevision,
        ]);
        final shortcuts = <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.digit1, control: true):
              controller.showProfileWorkflow,
          const SingleActivator(LogicalKeyboardKey.digit2, control: true):
              controller.showProviderWorkflow,
          const SingleActivator(
            LogicalKeyboardKey.keyD,
            control: true,
            shift: true,
          ): () => _handleInspectorAction(
            pane: DesktopInspectorPane.diagnostics,
            persistent: showPersistentInspector,
          ),
          const SingleActivator(
            LogicalKeyboardKey.keyL,
            control: true,
            shift: true,
          ): () => _handleInspectorAction(
            pane: DesktopInspectorPane.activity,
            persistent: showPersistentInspector,
          ),
          const SingleActivator(LogicalKeyboardKey.escape): () {
            final shouldRestoreWorkflowFocus =
                controller.isInspectorOpen ||
                (_scaffoldKey.currentState?.isEndDrawerOpen ?? false);
            if (controller.isInspectorOpen) {
              controller.closeInspector();
            }
            if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
              Navigator.of(context).maybePop();
            }
            if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
              Navigator.of(context).maybePop();
            }
            if (shouldRestoreWorkflowFocus) {
              _restoreWorkflowFocus();
            }
          },
        };

        return CallbackShortcuts(
          bindings: shortcuts,
          child: Focus(
            autofocus: true,
            child: Scaffold(
              key: _scaffoldKey,
              onEndDrawerChanged: (bool isOpened) {
                if (showPersistentInspector || isOpened || !controller.isInspectorOpen) {
                  return;
                }
                controller.closeInspector();
                _restoreWorkflowFocus();
              },
              drawer: showCompactLayout
                  ? Drawer(
                      child: SafeArea(
                        child: _CompactNavigationDrawer(controller: controller),
                      ),
                    )
                  : null,
              endDrawer: showPersistentInspector
                  ? null
                  : SizedBox(
                      width: 420,
                      child: Drawer(
                        child: SafeArea(
                          child: AnimatedBuilder(
                            animation: controller.inspectorRevision,
                            builder: (BuildContext context, Widget? child) {
                              return _InspectorSurface(
                                controller: controller,
                                compact: true,
                                onClose: _closeOverlayInspector,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      AnimatedBuilder(
                        animation: shellChromeListenable,
                        builder: (BuildContext context, Widget? child) {
                          return _DesktopShellBar(
                            controller: controller,
                            showNavigationButton: showCompactLayout,
                            showPersistentInspector: showPersistentInspector,
                            onOpenNavigation: _openNavigationDrawer,
                            onOpenDiagnostics: () => _handleInspectorAction(
                              pane: DesktopInspectorPane.diagnostics,
                              persistent: showPersistentInspector,
                            ),
                            onOpenActivity: () => _handleInspectorAction(
                              pane: DesktopInspectorPane.activity,
                              persistent: showPersistentInspector,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _ShellBody(
                          controller: controller,
                          compactLayout: showCompactLayout,
                          persistentInspector: showPersistentInspector,
                          activeWorkflowFocusNode: _activeWorkflowFocusNode,
                          onClosePersistentInspector: () {
                            controller.closeInspector();
                            _restoreWorkflowFocus();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShellBody extends StatelessWidget {
  const _ShellBody({
    required this.controller,
    required this.compactLayout,
    required this.persistentInspector,
    required this.activeWorkflowFocusNode,
    required this.onClosePersistentInspector,
  });

  final DesktopShellController controller;
  final bool compactLayout;
  final bool persistentInspector;
  final FocusNode activeWorkflowFocusNode;
  final VoidCallback onClosePersistentInspector;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        controller.shellChromeRevision,
        controller.workflowRevision,
        controller.inspectorLayoutRevision,
      ]),
      builder: (BuildContext context, Widget? child) {
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final contextPane = AnimatedBuilder(
              animation: controller.workflowRevision,
              builder: (BuildContext context, Widget? child) {
                final busy =
                    controller.busy || controller.status != ShellStatus.ready;
                return DesktopWorkflowPane(
                  section: controller.activeSection,
                  presets: controller.presetCatalog,
                  providerDescriptors: controller.providerDescriptors,
                  managedProviders: controller.managedProviders,
                  profiles: controller.profiles,
                  selectedProfileId: controller.selectedProfileId,
                  selectedManagedProviderId:
                      controller.selectedManagedProviderId,
                  busy: busy,
                  onApplyPreset: controller.applyPreset,
                  onSelectManagedProvider: controller.selectManagedProvider,
                  onCreateManagedProvider: controller.resetManagedProviderDraft,
                  onSelectProfile: controller.selectProfile,
                  onCreateDraft: controller.resetDraft,
                );
              },
            );
            final editorPane = AnimatedBuilder(
              animation: controller.workflowRevision,
              builder: (BuildContext context, Widget? child) {
                final busy =
                    controller.busy || controller.status != ShellStatus.ready;
                return controller.activeSection ==
                        DesktopShellSection.profileWorkflow
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
                        onUseCustomProvider:
                            controller.useCustomProviderForDraft,
                        onSave: controller.saveDraft,
                        onDelete: controller.deleteSelectedProfile,
                        onReset: controller.resetDraft,
                        onResolve: controller.startResolutionFromDraft,
                        onStart: controller.startSelectedProfile,
                      )
                    : ProviderConfigEditorPanel(
                        supportedProviders: controller.supportedProviderCatalog,
                        providerDescriptors: controller.providerDescriptors,
                        selectedManagedProviderId:
                            controller.selectedManagedProviderId,
                        draft: controller.managedProviderDraft,
                        busy: busy,
                        onDraftChanged: controller.updateManagedProviderDraft,
                        onSave: controller.saveManagedProviderDraft,
                        onDelete: controller.deleteSelectedManagedProvider,
                        onReset: controller.resetManagedProviderDraft,
                        onApplyToProfileDraft:
                            controller.useManagedProviderForDraft,
                      );
              },
            );
            final assurancePane = AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[
                controller.shellChromeRevision,
                controller.workflowRevision,
              ]),
              builder: (BuildContext context, Widget? child) {
                return _FocusedAssurancePane(controller: controller);
              },
            );
            final mainColumn = FocusTraversalGroup(
              child: Focus(
                key: const ValueKey<String>('desktop-active-workflow-focus'),
                focusNode: activeWorkflowFocusNode,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    assurancePane,
                    const SizedBox(height: 12),
                    Expanded(child: editorPane),
                  ],
                ),
              ),
            );

            if (compactLayout) {
              final contextHeight = constraints.maxHeight < 920 ? 248.0 : 284.0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: mainColumn),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: contextHeight,
                    child: FocusTraversalGroup(child: contextPane),
                  ),
                ],
              );
            }

            final showExpandedPad = persistentInspector;
            final showInspectorPane =
                persistentInspector && controller.isInspectorOpen;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (showExpandedPad)
                  FocusTraversalGroup(
                    child: SizedBox(
                      width: 312,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          AnimatedBuilder(
                            animation: controller.workflowRevision,
                            builder: (BuildContext context, Widget? child) {
                              return _ExpandedNavigationPad(
                                controller: controller,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Expanded(child: contextPane),
                        ],
                      ),
                    ),
                  )
                else ...<Widget>[
                  FocusTraversalGroup(
                    child: AnimatedBuilder(
                      animation: controller.workflowRevision,
                      builder: (BuildContext context, Widget? child) {
                        return _DesktopSectionRail(controller: controller);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 276,
                    child: FocusTraversalGroup(child: contextPane),
                  ),
                ],
                const SizedBox(width: 16),
                Expanded(child: mainColumn),
                if (showInspectorPane) ...<Widget>[
                  const SizedBox(width: 16),
                  FocusTraversalGroup(
                    child: SizedBox(
                      width: 372,
                      child: AnimatedBuilder(
                        animation: controller.inspectorRevision,
                        builder: (BuildContext context, Widget? child) {
                          return _InspectorSurface(
                            controller: controller,
                            compact: false,
                            onClose: onClosePersistentInspector,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _DesktopShellBar extends StatelessWidget {
  const _DesktopShellBar({
    required this.controller,
    required this.showNavigationButton,
    required this.showPersistentInspector,
    required this.onOpenNavigation,
    required this.onOpenDiagnostics,
    required this.onOpenActivity,
  });

  final DesktopShellController controller;
  final bool showNavigationButton;
  final bool showPersistentInspector;
  final VoidCallback onOpenNavigation;
  final VoidCallback onOpenDiagnostics;
  final VoidCallback onOpenActivity;

  @override
  Widget build(BuildContext context) {
    final connection = controller.hostConnection;
    final hostInfo = connection?.info;
    final statusTitle = switch (controller.status) {
      ShellStatus.booting => 'Connecting to local host',
      ShellStatus.ready => 'Local host ready',
      ShellStatus.blocked => 'Local host blocked',
    };
    final detail =
        connection?.message ??
        switch (controller.status) {
          ShellStatus.booting =>
            'Starting local host and negotiating capabilities.',
          ShellStatus.ready => 'Connected to local host.',
          ShellStatus.blocked => 'Waiting for local host negotiation.',
        };
    final tone = switch (connection?.state) {
      HostLifecycleState.ready => const Color(0xFFF7FAF6),
      HostLifecycleState.incompatible => const Color(0xFFFFF7E6),
      HostLifecycleState.failed => const Color(0xFFFFF0EC),
      _ => const Color(0xFFF4F7FA),
    };
    final stacked = MediaQuery.sizeOf(context).width < 1260;

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: stacked ? WrapAlignment.start : WrapAlignment.end,
      children: <Widget>[
        if (showNavigationButton)
          IconButton.filledTonal(
            key: const ValueKey<String>('desktop-navigation-drawer-button'),
            onPressed: onOpenNavigation,
            icon: const Icon(Icons.menu),
            tooltip: 'Open workflows',
          ),
        FilledButton.tonal(
          key: const ValueKey<String>('desktop-open-diagnostics-button'),
          onPressed: onOpenDiagnostics,
          child: const Text('Diagnostics'),
        ),
        FilledButton.tonal(
          key: const ValueKey<String>('desktop-open-activity-button'),
          onPressed: controller.hasLiveWork ? onOpenActivity : null,
          child: Text(
            controller.hasLiveWork
                ? 'Live work (${controller.resolutions.length + controller.sessions.length})'
                : 'Live work',
          ),
        ),
        FilledButton.tonal(
          onPressed: controller.busy
              ? null
              : () => unawaited(controller.reconnect()),
          child: const Text('Reconnect'),
        ),
        FilledButton(
          onPressed: controller.busy || controller.status != ShellStatus.ready
              ? null
              : () => unawaited(controller.refresh()),
          child: const Text('Refresh'),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Card(
          color: tone,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _ShellBarSummary(
                        controller: controller,
                        title: statusTitle,
                        detail: detail,
                        hostInfo: hostInfo,
                      ),
                      const SizedBox(height: 10),
                      actions,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: _ShellBarSummary(
                          controller: controller,
                          title: statusTitle,
                          detail: detail,
                          hostInfo: hostInfo,
                        ),
                      ),
                      const SizedBox(width: 20),
                      SizedBox(
                        width: showPersistentInspector ? 344 : 284,
                        child: Align(
                          alignment: Alignment.topRight,
                          child: actions,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (controller.notice != null) ...<Widget>[
          const SizedBox(height: 12),
          _NoticeBanner(message: controller.notice!),
        ],
      ],
    );
  }
}

class _ShellBarSummary extends StatelessWidget {
  const _ShellBarSummary({
    required this.controller,
    required this.title,
    required this.detail,
    required this.hostInfo,
  });

  final DesktopShellController controller;
  final String title;
  final String detail;
  final HostInfo? hostInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shortDetail = controller.status == ShellStatus.ready
        ? 'Focused editor stays primary; diagnostics and live work stay secondary until needed.'
        : detail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Desktop control shell',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          shortDetail,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _Tag(label: 'GUI ${controller.appBuild.shortLabel}'),
            if (hostInfo != null)
              _Tag(label: 'Host ${hostInfo!.build.shortLabel}'),
            if (hostInfo != null)
              _Tag(label: 'Contract ${hostInfo!.contractVersion}'),
            if (controller.hostConnection?.launched == true)
              const _Tag(label: 'launched'),
            if (controller.hostConnection?.launchSpec != null)
              _Tag(label: controller.hostConnection!.launchSpec!.description),
          ],
        ),
      ],
    );
  }
}

class _CompactNavigationDrawer extends StatelessWidget {
  const _CompactNavigationDrawer({required this.controller});

  final DesktopShellController controller;

  @override
  Widget build(BuildContext context) {
    return NavigationDrawer(
      key: const ValueKey<String>('desktop-section-drawer'),
      selectedIndex: _sectionIndex(controller.activeSection),
      onDestinationSelected: (int index) {
        Navigator.of(context).maybePop();
        if (index == 0) {
          controller.showProfileWorkflow();
        } else {
          controller.showProviderWorkflow();
        }
      },
      children: const <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(28, 20, 28, 12),
          child: Text('Workflows'),
        ),
        NavigationDrawerDestination(
          key: ValueKey<String>('desktop-section-profile'),
          icon: Icon(Icons.fact_check_outlined),
          label: Text('Profiles'),
        ),
        NavigationDrawerDestination(
          key: ValueKey<String>('desktop-section-provider'),
          icon: Icon(Icons.tune_outlined),
          label: Text('Providers'),
        ),
      ],
    );
  }
}

class _DesktopSectionRail extends StatelessWidget {
  const _DesktopSectionRail({required this.controller});

  final DesktopShellController controller;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      key: const ValueKey<String>('desktop-section-rail'),
      selectedIndex: _sectionIndex(controller.activeSection),
      labelType: NavigationRailLabelType.all,
      onDestinationSelected: (int index) {
        if (index == 0) {
          controller.showProfileWorkflow();
        } else {
          controller.showProviderWorkflow();
        }
      },
      destinations: const <NavigationRailDestination>[
        NavigationRailDestination(
          icon: Icon(Icons.fact_check_outlined),
          label: Text('Profiles'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.tune_outlined),
          label: Text('Providers'),
        ),
      ],
    );
  }
}

class _ExpandedNavigationPad extends StatelessWidget {
  const _ExpandedNavigationPad({required this.controller});

  final DesktopShellController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Workflows',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Keep switching visible, but quiet. The editor should still own the screen.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            _SectionListTile(
              key: const ValueKey<String>('desktop-section-profile'),
              icon: Icons.fact_check_outlined,
              title: 'Profiles',
              subtitle: 'Saved profiles and active draft work.',
              selected:
                  controller.activeSection ==
                  DesktopShellSection.profileWorkflow,
              onTap: controller.showProfileWorkflow,
            ),
            const SizedBox(height: 8),
            _SectionListTile(
              key: const ValueKey<String>('desktop-section-provider'),
              icon: Icons.tune_outlined,
              title: 'Providers',
              subtitle: 'Managed records and preset seeds.',
              selected:
                  controller.activeSection ==
                  DesktopShellSection.providerWorkflow,
              onTap: controller.showProviderWorkflow,
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusedAssurancePane extends StatelessWidget {
  const _FocusedAssurancePane({required this.controller});

  final DesktopShellController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readyTunnelModes = controller.platformTunnels
        .where((PlatformTunnelCapability capability) => capability.available)
        .length;
    final tunnelModes = controller.platformTunnels.length;
    final stateLabel = switch (controller.status) {
      ShellStatus.booting => 'Booting',
      ShellStatus.ready => 'Ready',
      ShellStatus.blocked => 'Blocked',
    };
    final tone = switch (controller.hostConnection?.state) {
      HostLifecycleState.ready => const Color(0xFFF2F7EF),
      HostLifecycleState.incompatible => const Color(0xFFFFF6E3),
      HostLifecycleState.failed => const Color(0xFFFFEEE9),
      _ => const Color(0xFFF2F4F8),
    };

    return Card(
      color: tone,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Workflow readiness',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _workflowAssuranceSummary(controller),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                _AssuranceChip(label: stateLabel),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _AssuranceChip(
                  label: readyTunnelModes > 0
                      ? '$readyTunnelModes/$tunnelModes tunnel modes ready'
                      : 'Platform tunnel summary',
                ),
                if (controller.hasLiveWork)
                  _AssuranceChip(
                    label:
                        '${controller.resolutions.length} resolutions · ${controller.sessions.length} sessions',
                  ),
                if (controller.hostConnection?.isReady != true)
                  _AssuranceChip(label: 'Support context pinned'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _platformTunnelHeaderSummary(controller),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (controller.status != ShellStatus.ready ||
                controller.hasLiveWork ||
                controller.notice != null) ...<Widget>[
              const SizedBox(height: 12),
              _PinnedSupportSummary(controller: controller),
            ],
          ],
        ),
      ),
    );
  }
}

class _PinnedSupportSummary extends StatelessWidget {
  const _PinnedSupportSummary({required this.controller});

  final DesktopShellController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = switch (controller.status) {
      ShellStatus.blocked => 'Support attention is required',
      ShellStatus.booting => 'Support context is warming up',
      ShellStatus.ready =>
        controller.hasLiveWork ? 'Live work is active' : 'Support note',
    };
    final detail = switch (controller.status) {
      ShellStatus.blocked =>
        controller.notice ??
            controller.hostConnection?.message ??
            'The local host is blocked or incompatible. Keep the recovery path visible from the primary workflow.',
      ShellStatus.booting =>
        controller.notice ??
            'Host negotiation is still in progress. Diagnostics stay one action away without reclaiming the full shell.',
      ShellStatus.ready =>
        controller.hasLiveWork
            ? 'Use Live work to inspect the current runtime without letting the support surface reclaim the full shell.'
            : 'Use Diagnostics or Live work when you need deeper inspection. The main workflow remains primary.',
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            controller.status == ShellStatus.ready
                ? Icons.stream_outlined
                : Icons.warning_amber_rounded,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssuranceChip extends StatelessWidget {
  const _AssuranceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionListTile extends StatelessWidget {
  const _SectionListTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = selected
        ? theme.colorScheme.primary.withValues(alpha: 0.1)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
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

class _InspectorSurface extends StatelessWidget {
  const _InspectorSurface({
    required this.controller,
    required this.compact,
    required this.onClose,
  });

  final DesktopShellController controller;
  final bool compact;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey<String>('desktop-inspector-surface'),
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Inspector',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        controller.activeInspectorPane ==
                                DesktopInspectorPane.diagnostics
                            ? 'Diagnostics and platform tunnel detail stay secondary to the main task canvas.'
                            : 'Live resolutions and sessions stay available on demand without reclaiming the full shell.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('desktop-inspector-close-button'),
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                  tooltip: 'Close inspector',
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<DesktopInspectorPane>(
              segments: const <ButtonSegment<DesktopInspectorPane>>[
                ButtonSegment<DesktopInspectorPane>(
                  value: DesktopInspectorPane.diagnostics,
                  label: Text('Diagnostics'),
                  icon: Icon(Icons.medical_services_outlined),
                ),
                ButtonSegment<DesktopInspectorPane>(
                  value: DesktopInspectorPane.activity,
                  label: Text('Live work'),
                  icon: Icon(Icons.stream_outlined),
                ),
              ],
              selected: <DesktopInspectorPane>{controller.activeInspectorPane},
              onSelectionChanged: (Set<DesktopInspectorPane> selection) {
                if (selection.isNotEmpty) {
                  controller.openInspector(pane: selection.first);
                }
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child:
                  controller.activeInspectorPane ==
                      DesktopInspectorPane.diagnostics
                  ? _DiagnosticsInspectorBody(controller: controller)
                  : _ActivityInspectorBody(controller: controller),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticsInspectorBody extends StatelessWidget {
  const _DiagnosticsInspectorBody({required this.controller});

  final DesktopShellController controller;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const TabBar(
            tabs: <Widget>[
              Tab(text: 'Events'),
              Tab(text: 'Tunnel detail'),
            ],
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

class _ActivityInspectorBody extends StatelessWidget {
  const _ActivityInspectorBody({required this.controller});

  final DesktopShellController controller;

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: 'Resolutions (${controller.resolutions.length})'),
              Tab(text: 'Sessions (${controller.sessions.length})'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _ResolutionsPanel(controller: controller, embedded: false),
                _SessionsPanel(controller: controller, embedded: false),
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

int _sectionIndex(DesktopShellSection section) {
  return switch (section) {
    DesktopShellSection.profileWorkflow => 0,
    DesktopShellSection.providerWorkflow => 1,
  };
}

String _workflowAssuranceSummary(DesktopShellController controller) {
  return switch (controller.status) {
    ShellStatus.booting =>
      'The shell is reconnecting to the local host. Keep the editor surface stable while negotiation completes.',
    ShellStatus.blocked =>
      controller.hostConnection?.message ??
          'The local host is blocked or incompatible. Keep the recovery path visible from the primary workflow surface.',
    ShellStatus.ready =>
      controller.hasLiveWork
          ? 'The local host is ready. Keep the current workflow dominant while live runtime detail stays one step away.'
          : 'The local host is ready. Routine support stays compact so the active workflow keeps visual priority.',
  };
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
