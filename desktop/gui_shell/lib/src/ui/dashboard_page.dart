import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_shell_core/shell_visuals.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FocusNode _activeWorkbenchFocusNode = FocusNode(
    debugLabel: 'desktop-active-workbench',
  );
  bool? _lastCompactSupportDrawer;

  DesktopShellController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreWorkflowFocus();
    });
  }

  @override
  void dispose() {
    _activeWorkbenchFocusNode.dispose();
    super.dispose();
  }

  void _openNavigationDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _showHomeRoute() {
    controller.showHome();
    _restoreWorkflowFocus();
  }

  void _showProfilesRoute() {
    controller.showProfiles();
    _restoreWorkflowFocus();
  }

  void _showRoutingRoute() {
    controller.showRouting();
    _restoreWorkflowFocus();
  }

  void _showActivityRoute() {
    controller.showActivityRoute();
    _restoreWorkflowFocus();
  }

  void _showDiagnosticsRoute() {
    controller.showDiagnosticsRoute();
    _restoreWorkflowFocus();
  }

  void _showSettingsRoute() {
    controller.showSettings();
    _restoreWorkflowFocus();
  }

  void _restoreWorkflowFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final focusedContext = FocusManager.instance.primaryFocus?.context;
      if (focusedContext != null) {
        final keepsEditableFocus =
            focusedContext.widget is EditableText ||
            focusedContext.findAncestorWidgetOfExactType<EditableText>() !=
                null;
        if (keepsEditableFocus) {
          return;
        }
      }
      _activeWorkbenchFocusNode.requestFocus();
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

  void _syncSupportPresentation({required bool compactDrawer}) {
    if (_lastCompactSupportDrawer == compactDrawer) {
      return;
    }
    _lastCompactSupportDrawer = compactDrawer;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final scaffold = _scaffoldKey.currentState;
      if (!compactDrawer) {
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
    required bool compactDrawer,
  }) {
    if (compactDrawer) {
      _openOverlayInspector(pane);
    } else {
      controller.toggleInspector(pane: pane);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final showCompactLayout = constraints.maxWidth < _compactWidth;
        _syncSupportPresentation(compactDrawer: showCompactLayout);
        final shellChromeListenable = Listenable.merge(<Listenable>[
          controller.shellChromeRevision,
          controller.workflowRevision,
        ]);
        final shortcuts = <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.digit1, control: true):
              _showHomeRoute,
          const SingleActivator(LogicalKeyboardKey.digit2, control: true):
              _showProfilesRoute,
          const SingleActivator(LogicalKeyboardKey.digit3, control: true):
              _showRoutingRoute,
          const SingleActivator(LogicalKeyboardKey.digit4, control: true):
              _showSettingsRoute,
          const SingleActivator(
            LogicalKeyboardKey.keyD,
            control: true,
            shift: true,
          ): () => _handleInspectorAction(
            pane: DesktopInspectorPane.diagnostics,
            compactDrawer: showCompactLayout,
          ),
          const SingleActivator(
            LogicalKeyboardKey.keyL,
            control: true,
            shift: true,
          ): () => _handleInspectorAction(
            pane: DesktopInspectorPane.activity,
            compactDrawer: showCompactLayout,
          ),
          const SingleActivator(LogicalKeyboardKey.escape): () {
            final shouldRestoreWorkflowFocus =
                controller.isInspectorOpen ||
                (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) ||
                (_scaffoldKey.currentState?.isDrawerOpen ?? false);
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
                if (!showCompactLayout ||
                    isOpened ||
                    !controller.isInspectorOpen) {
                  return;
                }
                controller.closeInspector();
                _restoreWorkflowFocus();
              },
              drawer: showCompactLayout
                  ? Drawer(
                      child: SafeArea(
                        child: _CompactNavigationDrawer(
                          controller: controller,
                          onShowHome: () {
                            Navigator.of(context).maybePop();
                            _showHomeRoute();
                          },
                          onShowProfiles: () {
                            Navigator.of(context).maybePop();
                            _showProfilesRoute();
                          },
                          onShowRouting: () {
                            Navigator.of(context).maybePop();
                            _showRoutingRoute();
                          },
                          onShowActivity: () {
                            Navigator.of(context).maybePop();
                            _showActivityRoute();
                          },
                          onShowDiagnostics: () {
                            Navigator.of(context).maybePop();
                            _showDiagnosticsRoute();
                          },
                          onShowSettings: () {
                            Navigator.of(context).maybePop();
                            _showSettingsRoute();
                          },
                        ),
                      ),
                    )
                  : null,
              endDrawer: showCompactLayout
                  ? SizedBox(
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
                    )
                  : null,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      AnimatedBuilder(
                        animation: shellChromeListenable,
                        builder: (BuildContext context, Widget? child) {
                          return _DesktopShellBar(
                            controller: controller,
                            showNavigationButton: showCompactLayout,
                            showPersistentInspector: !showCompactLayout,
                            onOpenNavigation: _openNavigationDrawer,
                            onOpenDiagnostics: () => _handleInspectorAction(
                              pane: DesktopInspectorPane.diagnostics,
                              compactDrawer: showCompactLayout,
                            ),
                            onOpenActivity: () => _handleInspectorAction(
                              pane: DesktopInspectorPane.activity,
                              compactDrawer: showCompactLayout,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: _ShellBody(
                          controller: controller,
                          compactLayout: showCompactLayout,
                          activeWorkbenchFocusNode: _activeWorkbenchFocusNode,
                          onShowHome: _showHomeRoute,
                          onShowProfiles: _showProfilesRoute,
                          onShowRouting: _showRoutingRoute,
                          onShowActivity: _showActivityRoute,
                          onShowDiagnostics: _showDiagnosticsRoute,
                          onShowSettings: _showSettingsRoute,
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
    required this.activeWorkbenchFocusNode,
    required this.onShowHome,
    required this.onShowProfiles,
    required this.onShowRouting,
    required this.onShowActivity,
    required this.onShowDiagnostics,
    required this.onShowSettings,
    required this.onClosePersistentInspector,
  });

  final DesktopShellController controller;
  final bool compactLayout;
  final FocusNode activeWorkbenchFocusNode;
  final VoidCallback onShowHome;
  final VoidCallback onShowProfiles;
  final VoidCallback onShowRouting;
  final VoidCallback onShowActivity;
  final VoidCallback onShowDiagnostics;
  final VoidCallback onShowSettings;
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
            final showFocusedAssurance =
                controller.activeWorkbenchRoute != DesktopWorkbenchRoute.home &&
                (controller.status != ShellStatus.ready ||
                    controller.hasLiveWork);
            final showSupportPane =
                !compactLayout &&
                controller.isInspectorOpen &&
                !controller.showsSupportRoute;
            final mainColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (showFocusedAssurance) ...<Widget>[
                  AnimatedBuilder(
                    animation: Listenable.merge(<Listenable>[
                      controller.shellChromeRevision,
                      controller.workflowRevision,
                    ]),
                    builder: (BuildContext context, Widget? child) {
                      return _FocusedAssurancePane(controller: controller);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: FocusTraversalGroup(
                    child: Focus(
                      key: const ValueKey<String>(
                        'desktop-active-workflow-focus',
                      ),
                      focusNode: activeWorkbenchFocusNode,
                      child: _CanvasSurface(controller: controller),
                    ),
                  ),
                ),
              ],
            );

            if (compactLayout) {
              return mainColumn;
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: 248,
                  child: AnimatedBuilder(
                    animation: controller.workflowRevision,
                    builder: (BuildContext context, Widget? child) {
                      return _ExpandedNavigationPad(
                        controller: controller,
                        onShowHome: onShowHome,
                        onShowProfiles: onShowProfiles,
                        onShowRouting: onShowRouting,
                        onShowActivity: onShowActivity,
                        onShowDiagnostics: onShowDiagnostics,
                        onShowSettings: onShowSettings,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: mainColumn),
                if (showSupportPane) ...<Widget>[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 420,
                    child: FocusTraversalGroup(
                      child: AnimatedBuilder(
                        animation: controller.inspectorRevision,
                        builder: (BuildContext context, Widget? child) {
                          return _InspectorSurface(
                            controller: controller,
                            compact: true,
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
    final routineReadyChrome =
        controller.status == ShellStatus.ready && !controller.hasLiveWork;
    final statusTitle = switch (controller.status) {
      ShellStatus.booting => t.desktopStatusConnectingTitle,
      ShellStatus.ready => t.desktopStatusReadyTitle,
      ShellStatus.blocked => t.desktopStatusBlockedTitle,
    };
    final detail =
        connection?.message ??
        switch (controller.status) {
          ShellStatus.booting => t.desktopStatusStartingDetail,
          ShellStatus.ready => t.desktopStatusConnectedDetail,
          ShellStatus.blocked => t.desktopStatusWaitingDetail,
        };
    final tone = switch (connection?.state) {
      HostLifecycleState.ready => ShellSemanticTone.ready,
      HostLifecycleState.incompatible => ShellSemanticTone.attention,
      HostLifecycleState.failed => ShellSemanticTone.danger,
      _ => ShellSemanticTone.info,
    };
    final tonePalette = context.shellVisuals.tone(tone);
    final shouldShowNotice =
        controller.notice != null &&
        !(routineReadyChrome && controller.notice == connection?.message);
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
            tooltip: t.commonOpenWorkflowsTooltip,
          ),
        PopupMenuButton<String>(
          tooltip: t.localeSwitchTooltip,
          onSelected: (String value) {
            unawaited(
              controller.selectLocaleOverride(value.isEmpty ? null : value),
            );
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            CheckedPopupMenuItem<String>(
              key: ValueKey<String>(shellLocaleMenuItemKey(null)),
              value: '',
              checked: controller.usesSystemLocale,
              child: Text(t.localeSystemDefault),
            ),
            for (final locale in AppLocale.values)
              CheckedPopupMenuItem<String>(
                key: ValueKey<String>(shellLocaleMenuItemKey(locale)),
                value: shellLocaleTag(locale),
                checked:
                    !controller.usesSystemLocale &&
                    controller.activeLocale == locale,
                child: Text(shellLocaleDisplayName(context, locale)),
              ),
          ],
          child: const Icon(Icons.translate_rounded),
        ),
        FilledButton.tonal(
          key: const ValueKey<String>('desktop-open-diagnostics-button'),
          onPressed: onOpenDiagnostics,
          child: Text(t.commonDiagnostics),
        ),
        FilledButton.tonal(
          key: const ValueKey<String>('desktop-open-activity-button'),
          onPressed: controller.hasLiveWork ? onOpenActivity : null,
          child: Text(
            controller.hasLiveWork
                ? '${t.commonLiveWork} (${controller.resolutions.length + controller.sessions.length})'
                : t.commonLiveWork,
          ),
        ),
        FilledButton.tonal(
          onPressed: controller.busy
              ? null
              : () => unawaited(controller.reconnect()),
          child: Text(t.commonReconnect),
        ),
        FilledButton(
          onPressed: controller.busy || controller.status != ShellStatus.ready
              ? null
              : () => unawaited(controller.refresh()),
          child: Text(t.commonRefresh),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Card(
          color: tonePalette.container,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              routineReadyChrome ? 14 : 18,
              routineReadyChrome ? 12 : 16,
              routineReadyChrome ? 14 : 18,
              routineReadyChrome ? 12 : 16,
            ),
            child: routineReadyChrome
                ? _CompactReadyShellBarSummary(
                    controller: controller,
                    hostInfo: hostInfo,
                    actions: actions,
                    stacked: stacked,
                    showPersistentInspector: showPersistentInspector,
                  )
                : stacked
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
        if (shouldShowNotice) ...<Widget>[
          const SizedBox(height: 10),
          _NoticeBanner(
            message: controller.notice!,
            compact: routineReadyChrome,
          ),
        ],
      ],
    );
  }
}

class _CompactReadyShellBarSummary extends StatelessWidget {
  const _CompactReadyShellBarSummary({
    required this.controller,
    required this.hostInfo,
    required this.actions,
    required this.stacked,
    required this.showPersistentInspector,
  });

  final DesktopShellController controller;
  final HostInfo? hostInfo;
  final Widget actions;
  final bool stacked;
  final bool showPersistentInspector;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = context.shellText;
    final readyTone = context.shellVisuals.tone(ShellSemanticTone.ready);
    final detail = _routineConnectionDetail(
      copy: copy,
      message: controller.hostConnection?.message,
    );
    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: readyTone.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              t.desktopStatusReadyTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (detail.isNotEmpty) ...<Widget>[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _Tag(label: copy.guiBuildTag(controller.appBuild.shortLabel)),
            if (hostInfo != null)
              _Tag(label: copy.hostBuildTag(hostInfo!.build.shortLabel)),
            if (hostInfo != null)
              _Tag(label: copy.contractTag(hostInfo!.contractVersion)),
            if (controller.hostConnection?.launched == true)
              _Tag(label: copy.launched),
          ],
        ),
      ],
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[summary, const SizedBox(height: 10), actions],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: summary),
        const SizedBox(width: 16),
        SizedBox(
          width: showPersistentInspector ? 344 : 284,
          child: Align(alignment: Alignment.topRight, child: actions),
        ),
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
    final copy = context.shellText;
    final shortDetail = controller.status == ShellStatus.ready
        ? t.desktopReadyWorkflowDetail
        : detail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          t.desktopShellLabel,
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
            _Tag(label: copy.guiBuildTag(controller.appBuild.shortLabel)),
            if (hostInfo != null)
              _Tag(label: copy.hostBuildTag(hostInfo!.build.shortLabel)),
            if (hostInfo != null)
              _Tag(label: copy.contractTag(hostInfo!.contractVersion)),
            if (controller.hostConnection?.launched == true)
              _Tag(label: copy.launched),
            if (controller.hostConnection?.launchSpec != null)
              _Tag(label: controller.hostConnection!.launchSpec!.description),
          ],
        ),
      ],
    );
  }
}

class _CompactNavigationDrawer extends StatelessWidget {
  const _CompactNavigationDrawer({
    required this.controller,
    required this.onShowHome,
    required this.onShowProfiles,
    required this.onShowRouting,
    required this.onShowActivity,
    required this.onShowDiagnostics,
    required this.onShowSettings,
  });

  final DesktopShellController controller;
  final VoidCallback onShowHome;
  final VoidCallback onShowProfiles;
  final VoidCallback onShowRouting;
  final VoidCallback onShowActivity;
  final VoidCallback onShowDiagnostics;
  final VoidCallback onShowSettings;

  @override
  Widget build(BuildContext context) {
    return NavigationDrawer(
      key: const ValueKey<String>('desktop-section-drawer'),
      selectedIndex: _workbenchIndex(controller.activeWorkbenchRoute),
      onDestinationSelected: (int index) {
        Navigator.of(context).maybePop();
        switch (index) {
          case 0:
            onShowHome();
          case 1:
            onShowProfiles();
          case 2:
            onShowRouting();
          case 3:
            onShowActivity();
          case 4:
            onShowDiagnostics();
          case 5:
            onShowSettings();
        }
      },
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
          child: Text(t.commonWorkflows),
        ),
        NavigationDrawerDestination(
          key: ValueKey<String>('desktop-section-home'),
          icon: Icon(Icons.home_outlined),
          label: Text(t.commonHome),
        ),
        NavigationDrawerDestination(
          key: ValueKey<String>('desktop-section-profiles'),
          icon: Icon(Icons.fact_check_outlined),
          label: Text(t.commonProfiles),
        ),
        NavigationDrawerDestination(
          key: ValueKey<String>('desktop-section-routing'),
          icon: Icon(Icons.route_outlined),
          label: Text(t.commonRouting),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
          child: Text(t.commonSupport),
        ),
        NavigationDrawerDestination(
          key: ValueKey<String>('desktop-section-activity'),
          icon: Icon(Icons.stream_outlined),
          label: Text(t.commonLiveWork),
        ),
        NavigationDrawerDestination(
          key: ValueKey<String>('desktop-section-diagnostics'),
          icon: Icon(Icons.medical_services_outlined),
          label: Text(t.commonDiagnostics),
        ),
        NavigationDrawerDestination(
          key: ValueKey<String>('desktop-section-settings'),
          icon: Icon(Icons.settings_outlined),
          label: Text(t.commonSettings),
        ),
      ],
    );
  }
}

class _ExpandedNavigationPad extends StatelessWidget {
  const _ExpandedNavigationPad({
    required this.controller,
    required this.onShowHome,
    required this.onShowProfiles,
    required this.onShowRouting,
    required this.onShowActivity,
    required this.onShowDiagnostics,
    required this.onShowSettings,
  });

  final DesktopShellController controller;
  final VoidCallback onShowHome;
  final VoidCallback onShowProfiles;
  final VoidCallback onShowRouting;
  final VoidCallback onShowActivity;
  final VoidCallback onShowDiagnostics;
  final VoidCallback onShowSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey<String>('desktop-section-rail'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          primary: false,
          children: <Widget>[
            Text(
              t.desktopShellLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _SectionListTile(
              key: const ValueKey<String>('desktop-section-home'),
              icon: Icons.home_outlined,
              title: t.commonHome,
              subtitle: context.shellText.overview,
              selected:
                  controller.activeWorkbenchRoute == DesktopWorkbenchRoute.home,
              onTap: onShowHome,
            ),
            const SizedBox(height: 8),
            _SectionListTile(
              key: const ValueKey<String>('desktop-section-profiles'),
              icon: Icons.fact_check_outlined,
              title: t.commonProfiles,
              subtitle: t.desktopSectionProfilesSubtitle,
              selected:
                  controller.activeWorkbenchRoute ==
                  DesktopWorkbenchRoute.profiles,
              onTap: onShowProfiles,
            ),
            const SizedBox(height: 8),
            _SectionListTile(
              key: const ValueKey<String>('desktop-section-routing'),
              icon: Icons.route_outlined,
              title: t.commonRouting,
              subtitle: context.shellText.desktopPlatformTunnelSummary,
              selected:
                  controller.activeWorkbenchRoute ==
                  DesktopWorkbenchRoute.routing,
              onTap: onShowRouting,
            ),
            const SizedBox(height: 12),
            Text(
              t.commonSupport,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _SectionListTile(
              key: const ValueKey<String>('desktop-section-activity'),
              icon: Icons.stream_outlined,
              title: t.commonLiveWork,
              subtitle: context.shellText.desktopInspectorActivitySubtitle,
              selected:
                  controller.activeWorkbenchRoute ==
                  DesktopWorkbenchRoute.activity,
              onTap: onShowActivity,
            ),
            const SizedBox(height: 8),
            _SectionListTile(
              key: const ValueKey<String>('desktop-section-diagnostics'),
              icon: Icons.medical_services_outlined,
              title: t.commonDiagnostics,
              subtitle: context.shellText.desktopInspectorDiagnosticsSubtitle,
              selected:
                  controller.activeWorkbenchRoute ==
                  DesktopWorkbenchRoute.diagnostics,
              onTap: onShowDiagnostics,
            ),
            const SizedBox(height: 8),
            _SectionListTile(
              key: const ValueKey<String>('desktop-section-settings'),
              icon: Icons.settings_outlined,
              title: t.commonSettings,
              subtitle: t.localeSwitchTooltip,
              selected:
                  controller.activeWorkbenchRoute ==
                  DesktopWorkbenchRoute.settings,
              onTap: onShowSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowQuickActions extends StatelessWidget {
  const _WorkflowQuickActions({
    required this.controller,
    required this.onOpenSavedProfiles,
    required this.onOpenManagedProvidersForProfile,
    required this.onOpenManagedProvidersForProvider,
    required this.onOpenPresetBootstrap,
    required this.onOpenProviderFamilies,
  });

  final DesktopShellController controller;
  final VoidCallback onOpenSavedProfiles;
  final VoidCallback onOpenManagedProvidersForProfile;
  final VoidCallback onOpenManagedProvidersForProvider;
  final VoidCallback onOpenPresetBootstrap;
  final VoidCallback onOpenProviderFamilies;

  @override
  Widget build(BuildContext context) {
    final profileWorkflow =
        controller.activeSection == DesktopShellSection.profileWorkflow;
    final actions = profileWorkflow
        ? <Widget>[
            FilledButton.tonal(
              key: const ValueKey<String>(
                'desktop-open-profile-library-button',
              ),
              onPressed: onOpenSavedProfiles,
              child: Text(t.commonSavedProfiles),
            ),
            OutlinedButton(
              key: const ValueKey<String>(
                'desktop-create-profile-draft-button',
              ),
              onPressed: controller.busy ? null : controller.resetDraft,
              child: Text(t.commonNewDraft),
            ),
            OutlinedButton(
              key: const ValueKey<String>(
                'desktop-context-open-profile-managed-providers-button',
              ),
              onPressed: controller.managedProviders.isEmpty
                  ? null
                  : onOpenManagedProvidersForProfile,
              child: Text(t.commonProviderRecords),
            ),
          ]
        : <Widget>[
            FilledButton.tonal(
              key: const ValueKey<String>(
                'desktop-open-preset-bootstrap-button',
              ),
              onPressed: onOpenPresetBootstrap,
              child: Text(t.commonNewFromPreset),
            ),
            FilledButton.tonal(
              key: const ValueKey<String>(
                'desktop-open-managed-provider-library-button',
              ),
              onPressed: onOpenManagedProvidersForProvider,
              child: Text(t.commonProviderRecords),
            ),
            OutlinedButton(
              key: const ValueKey<String>(
                'desktop-open-provider-family-chooser-button',
              ),
              onPressed: onOpenProviderFamilies,
              child: Text(t.commonProviderFamilies),
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < actions.length; i++) ...<Widget>[
          actions[i],
          if (i != actions.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _CanvasSurface extends StatelessWidget {
  const _CanvasSurface({required this.controller});

  final DesktopShellController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller.workflowRevision,
      builder: (BuildContext context, Widget? child) {
        switch (controller.activeWorkbenchRoute) {
          case DesktopWorkbenchRoute.home:
            return _HomeWorkbenchSurface(controller: controller);
          case DesktopWorkbenchRoute.profiles:
            return _ProfilesWorkbenchSurface(controller: controller);
          case DesktopWorkbenchRoute.routing:
            return _RoutingWorkbenchSurface(controller: controller);
          case DesktopWorkbenchRoute.activity:
            return _WorkbenchSupportRoute(
              title: t.commonLiveWork,
              detail: context.shellText.desktopInspectorActivitySubtitle,
              child: _ActivityInspectorBody(controller: controller),
            );
          case DesktopWorkbenchRoute.diagnostics:
            return _WorkbenchSupportRoute(
              title: t.commonDiagnostics,
              detail: context.shellText.desktopInspectorDiagnosticsSubtitle,
              child: _DiagnosticsInspectorBody(controller: controller),
            );
          case DesktopWorkbenchRoute.settings:
            return _SettingsWorkbenchSurface(controller: controller);
        }
      },
    );
  }
}

class _HomeWorkbenchSurface extends StatelessWidget {
  const _HomeWorkbenchSurface({required this.controller});

  final DesktopShellController controller;

  @override
  Widget build(BuildContext context) {
    final copy = context.shellText;
    final selectedProfile = controller.selectedSavedProfile;
    final activeWorkCount =
        controller.resolutions.length + controller.sessions.length;
    final readyTunnelModes = controller.platformTunnels
        .where((PlatformTunnelCapability capability) => capability.available)
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: ListView(
          primary: false,
          children: <Widget>[
            _WorkbenchRouteHeader(
              title: copy.overview,
              detail: _workflowAssuranceSummary(context, controller),
              trailing: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  FilledButton.tonal(
                    key: const ValueKey<String>(
                      'desktop-open-profile-library-button',
                    ),
                    onPressed: controller.showProfiles,
                    child: Text(t.commonProfiles),
                  ),
                  FilledButton.tonal(
                    key: const ValueKey<String>('desktop-home-open-routing'),
                    onPressed: controller.showRouting,
                    child: Text(t.commonRouting),
                  ),
                  OutlinedButton(
                    key: const ValueKey<String>('desktop-home-open-activity'),
                    onPressed: controller.hasLiveWork
                        ? controller.showActivityRoute
                        : null,
                    child: Text(t.commonLiveWork),
                  ),
                  OutlinedButton(
                    key: const ValueKey<String>(
                      'desktop-home-open-diagnostics',
                    ),
                    onPressed: controller.showDiagnosticsRoute,
                    child: Text(t.commonDiagnostics),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _WorkbenchStatCard(
                  title: t.desktopStatusReadyTitle,
                  value: switch (controller.status) {
                    ShellStatus.booting => t.desktopStatusConnectingTitle,
                    ShellStatus.ready => t.desktopStatusReadyTitle,
                    ShellStatus.blocked => t.desktopStatusBlockedTitle,
                  },
                  detail:
                      controller.hostConnection?.message ??
                      t.desktopStatusConnectedDetail,
                ),
                _WorkbenchStatCard(
                  title: copy.selectedProfileActions,
                  value: selectedProfile?.name.isNotEmpty == true
                      ? selectedProfile!.name
                      : (selectedProfile?.id ?? copy.homeNoSavedProfilesYet),
                  detail: selectedProfile == null
                      ? copy.desktopNoSavedProfilesYetShort
                      : '${selectedProfile.spec.provider} · ${selectedProfile.spec.listenAddress}',
                ),
                _WorkbenchStatCard(
                  title: t.commonLiveWork,
                  value: '$activeWorkCount',
                  detail: copy.desktopResolutionsSessionsCompact(
                    controller.resolutions.length,
                    controller.sessions.length,
                  ),
                ),
                _WorkbenchStatCard(
                  title: copy.desktopPlatformTunnelSummary,
                  value: readyTunnelModes > 0
                      ? copy.desktopTunnelModesReadySummary(
                          readyTunnelModes,
                          controller.platformTunnels.length,
                        )
                      : copy.desktopTypedHostTunnelSummary,
                  detail: _platformTunnelHeaderSummary(context, controller),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final stacked = constraints.maxWidth < 1120;
                final selectedProfileCard = _WorkbenchSummaryCard(
                  title: copy.selectedProfileActions,
                  detail: selectedProfile == null
                      ? copy.homeNoSavedProfilesYet
                      : selectedProfile.spec.provider,
                  child: selectedProfile == null
                      ? Text(copy.desktopNoSavedProfilesYetShort)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              selectedProfile.name.isEmpty
                                  ? selectedProfile.id
                                  : selectedProfile.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${selectedProfile.spec.listenAddress} -> ${selectedProfile.spec.peerAddress}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${selectedProfile.spec.mode.value} · ${selectedProfile.spec.useDtls ? copy.dtlsEnabled : copy.notSet}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: <Widget>[
                                FilledButton(
                                  key: const ValueKey<String>(
                                    'desktop-home-start-selected-profile',
                                  ),
                                  onPressed:
                                      controller.status == ShellStatus.ready &&
                                          !controller.busy
                                      ? () => unawaited(
                                          controller.startSelectedProfile(),
                                        )
                                      : null,
                                  child: Text(copy.startOnThisDevice),
                                ),
                                OutlinedButton(
                                  onPressed: controller.showProfiles,
                                  child: Text(t.commonProfiles),
                                ),
                              ],
                            ),
                          ],
                        ),
                );
                final supportCard = _WorkbenchSummaryCard(
                  title: t.commonSupport,
                  detail: controller.hasLiveWork
                      ? copy.desktopSupportReadyLiveDetail
                      : copy.desktopSupportReadyIdleDetail,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      FilledButton.tonal(
                        onPressed: controller.hasLiveWork
                            ? controller.showActivityRoute
                            : null,
                        child: Text(t.commonLiveWork),
                      ),
                      FilledButton.tonal(
                        onPressed: controller.showDiagnosticsRoute,
                        child: Text(t.commonDiagnostics),
                      ),
                      OutlinedButton(
                        onPressed: controller.showSettings,
                        child: Text(t.commonSettings),
                      ),
                    ],
                  ),
                );
                if (stacked) {
                  return Column(
                    children: <Widget>[
                      selectedProfileCard,
                      const SizedBox(height: 12),
                      supportCard,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: selectedProfileCard),
                    const SizedBox(width: 12),
                    Expanded(child: supportCard),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilesWorkbenchSurface extends StatelessWidget {
  const _ProfilesWorkbenchSurface({required this.controller});

  final DesktopShellController controller;

  @override
  Widget build(BuildContext context) {
    final busy = controller.busy || controller.status != ShellStatus.ready;

    switch (controller.activeCanvasRoute) {
      case DesktopCanvasRoute.savedProfilePicker:
        return _CanvasRouteFrame(
          title: context.shellText.desktopSavedProfilesLibraryTitle,
          detail: context.shellText.desktopSavedProfilesRouteDetail,
          onBack: controller.returnFromCanvasRoute,
          child: SavedProfilesLibrarySurface(
            profiles: controller.profiles,
            selectedProfileId: controller.selectedProfileId,
            busy: busy,
            onSelectProfile: controller.selectProfile,
            onCreateDraft: controller.resetDraft,
          ),
        );
      case DesktopCanvasRoute.managedProviderPickerForProfile:
        return _CanvasRouteFrame(
          title: context.shellText.desktopManagedRecordsTitle,
          detail: context.shellText.desktopManagedRecordsRouteDetail,
          onBack: controller.returnFromCanvasRoute,
          child: ManagedProvidersLibrarySurface(
            managedProviders: controller.managedProviders,
            selectedManagedProviderId:
                controller.draft.providerBinding.managedProviderId,
            onSelectManagedProvider: controller.useManagedProviderForDraft,
          ),
        );
      case DesktopCanvasRoute.managedProviderPicker:
        return _CanvasRouteFrame(
          title: context.shellText.desktopProviderRecordsLibraryTitle,
          detail: context.shellText.desktopProviderRecordsRouteDetail,
          onBack: controller.returnFromCanvasRoute,
          child: ManagedProvidersLibrarySurface(
            managedProviders: controller.managedProviders,
            selectedManagedProviderId: controller.selectedManagedProviderId,
            onSelectManagedProvider: controller.selectManagedProvider,
            onCreateManagedProvider: controller.startManagedProviderCreation,
          ),
        );
      case DesktopCanvasRoute.presetPicker:
        return _CanvasRouteFrame(
          title: context.shellText.desktopPresetBootstrapTitle,
          detail: context.shellText.desktopPresetBootstrapRouteDetail,
          onBack: controller.returnFromCanvasRoute,
          child: PresetBootstrapSurface(
            presets: controller.presetCatalog,
            providerDescriptors: controller.providerDescriptors,
            busy: busy,
            onApplyPreset: controller.applyPreset,
          ),
        );
      case DesktopCanvasRoute.providerFamilyPicker:
        return _CanvasRouteFrame(
          title: t.commonProviderFamilies,
          detail: context.shellText.desktopProviderFamiliesRouteDetail,
          onBack: controller.returnFromCanvasRoute,
          child: SupportedProviderChooserSurface(
            supportedProviders: controller.supportedProviderCatalog,
            providerDescriptors: controller.providerDescriptors,
            selectedProviderId: controller.managedProviderDraft.provider,
            busy: busy,
            onSelectProvider: (String providerId) {
              controller.updateManagedProviderDraft(
                controller.managedProviderDraft.copyWith(
                  provider: providerId,
                  providerSettings: const <String, dynamic>{},
                ),
              );
            },
          ),
        );
      case DesktopCanvasRoute.profileEditor:
      case DesktopCanvasRoute.managedProviderEditor:
        break;
    }

    final profileWorkflow =
        controller.activeSection == DesktopShellSection.profileWorkflow;
    final library = profileWorkflow
        ? SavedProfilesLibrarySurface(
            profiles: controller.profiles,
            selectedProfileId: controller.selectedProfileId,
            busy: busy,
            onSelectProfile: controller.selectProfile,
            onCreateDraft: controller.resetDraft,
          )
        : ManagedProvidersLibrarySurface(
            managedProviders: controller.managedProviders,
            selectedManagedProviderId: controller.selectedManagedProviderId,
            onSelectManagedProvider: controller.selectManagedProvider,
            onCreateManagedProvider: controller.startManagedProviderCreation,
          );
    final editor = profileWorkflow
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
            onPreparePortableExport: controller.selectedPortableProfileEnvelope,
            onCopyPortableExportText:
                controller.copyPortableProfileEnvelopeText,
            onSavePortableExportFile:
                controller.savePortableProfileEnvelopeToFile,
            onImportPortableFromFile:
                controller.importPortableProfileEnvelopeFromFile,
            onPreviewPortableImport: controller.previewPortableProfileEnvelope,
            onConfirmPortableImport: controller.confirmPortableProfileImport,
            onBrowseManagedProviders: () async {
              controller.showProviderWorkflow();
            },
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
            onChooseProviderFamily: () async {
              controller.openProviderFamilyPicker();
            },
            onOpenPresetBootstrap: () async {
              controller.openPresetPicker();
            },
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints shellConstraints) {
            final lowHeightWorkbench = shellConstraints.maxHeight < 440;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _WorkbenchRouteHeader(
                  title: t.commonProfiles,
                  detail: profileWorkflow
                      ? t.desktopSectionProfilesSubtitle
                      : t.desktopSectionProvidersSubtitle,
                  trailing: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      ChoiceChip(
                        key: const ValueKey<String>('desktop-section-profile'),
                        avatar: const Icon(Icons.fact_check_outlined, size: 18),
                        label: Text(t.commonProfiles),
                        selected:
                            controller.activeSection ==
                            DesktopShellSection.profileWorkflow,
                        onSelected: (_) => controller.showProfileWorkflow(),
                      ),
                      ChoiceChip(
                        key: const ValueKey<String>('desktop-section-provider'),
                        avatar: const Icon(Icons.tune_outlined, size: 18),
                        label: Text(t.commonProviderRecords),
                        selected:
                            controller.activeSection ==
                            DesktopShellSection.providerWorkflow,
                        onSelected: (_) => controller.showProviderWorkflow(),
                      ),
                    ],
                  ),
                ),
                if (!lowHeightWorkbench) ...<Widget>[
                  const SizedBox(height: 16),
                  _WorkflowQuickActions(
                    controller: controller,
                    onOpenSavedProfiles: controller.openSavedProfilePicker,
                    onOpenManagedProvidersForProfile:
                        controller.openManagedProviderPickerForProfile,
                    onOpenManagedProvidersForProvider:
                        controller.openManagedProviderPicker,
                    onOpenPresetBootstrap: controller.openPresetPicker,
                    onOpenProviderFamilies: controller.openProviderFamilyPicker,
                  ),
                ],
                const SizedBox(height: 16),
                Expanded(
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final stacked = constraints.maxWidth < 1280;
                          final lowHeightEditor = constraints.maxHeight < 260;
                          if (stacked &&
                              (lowHeightWorkbench || lowHeightEditor)) {
                            return editor;
                          }
                          if (stacked) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Expanded(flex: 3, child: library),
                                const SizedBox(height: 12),
                                Expanded(flex: 4, child: editor),
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              SizedBox(width: 360, child: library),
                              const SizedBox(width: 12),
                              Expanded(child: editor),
                            ],
                          );
                        },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RoutingWorkbenchSurface extends StatefulWidget {
  const _RoutingWorkbenchSurface({required this.controller});

  final DesktopShellController controller;

  @override
  State<_RoutingWorkbenchSurface> createState() =>
      _RoutingWorkbenchSurfaceState();
}

class _RoutingWorkbenchSurfaceState extends State<_RoutingWorkbenchSurface> {
  late final TextEditingController _listenAddressController;
  late final TextEditingController _peerAddressController;
  late final TextEditingController _connectionsController;
  late final TextEditingController _turnServerController;
  late final TextEditingController _turnPortController;
  late final TextEditingController _bindInterfaceController;

  DesktopShellController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _listenAddressController = TextEditingController();
    _peerAddressController = TextEditingController();
    _connectionsController = TextEditingController();
    _turnServerController = TextEditingController();
    _turnPortController = TextEditingController();
    _bindInterfaceController = TextEditingController();
    _syncFromDraft();
  }

  @override
  void didUpdateWidget(covariant _RoutingWorkbenchSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.draft != widget.controller.draft) {
      _syncFromDraft();
    }
  }

  @override
  void dispose() {
    _listenAddressController.dispose();
    _peerAddressController.dispose();
    _connectionsController.dispose();
    _turnServerController.dispose();
    _turnPortController.dispose();
    _bindInterfaceController.dispose();
    super.dispose();
  }

  void _syncFromDraft() {
    final spec = controller.draft.spec;
    _setText(_listenAddressController, spec.listenAddress);
    _setText(_peerAddressController, spec.peerAddress);
    _setText(_connectionsController, '${spec.connections}');
    _setText(_turnServerController, spec.turnServer ?? '');
    _setText(_turnPortController, spec.turnPort ?? '');
    _setText(_bindInterfaceController, spec.bindInterface ?? '');
  }

  void _setText(TextEditingController controller, String nextValue) {
    if (controller.text == nextValue) {
      return;
    }
    controller.value = controller.value.copyWith(
      text: nextValue,
      selection: TextSelection.collapsed(offset: nextValue.length),
      composing: TextRange.empty,
    );
  }

  void _updateSpec(ProfileSpec Function(ProfileSpec current) update) {
    controller.updateDraft(
      controller.draft.copyWith(spec: update(controller.draft.spec)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = context.shellText;
    final spec = controller.draft.spec;
    final selectedProfile = controller.selectedSavedProfile;
    final busy = controller.busy || controller.status != ShellStatus.ready;

    final routingForm = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListView(
        primary: false,
        children: <Widget>[
          Text(
            copy.desktopProfileSettings,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            copy.desktopEditableParametersReady,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _RoutingTextField(
            key: const ValueKey<String>('desktop-routing-listen-address-field'),
            controller: _listenAddressController,
            label: copy.localUdpListen,
            onChanged: (String value) => _updateSpec(
              (ProfileSpec current) =>
                  current.copyWith(listenAddress: value.trim()),
            ),
          ),
          const SizedBox(height: 12),
          _RoutingTextField(
            key: const ValueKey<String>('desktop-routing-peer-address-field'),
            controller: _peerAddressController,
            label: copy.peerAddress,
            onChanged: (String value) => _updateSpec(
              (ProfileSpec current) =>
                  current.copyWith(peerAddress: value.trim()),
            ),
          ),
          const SizedBox(height: 12),
          _RoutingTextField(
            key: const ValueKey<String>('desktop-routing-connections-field'),
            controller: _connectionsController,
            label: copy.connections,
            keyboardType: TextInputType.number,
            onChanged: (String value) {
              final parsed = int.tryParse(value.trim());
              if (parsed == null || parsed < 1) {
                return;
              }
              _updateSpec(
                (ProfileSpec current) => current.copyWith(connections: parsed),
              );
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<TransportMode>(
            key: const ValueKey<String>('desktop-routing-mode-field'),
            initialValue: spec.mode,
            decoration: InputDecoration(labelText: copy.turnMode),
            items: TransportMode.values
                .map(
                  (TransportMode mode) => DropdownMenuItem<TransportMode>(
                    value: mode,
                    child: Text(mode.value),
                  ),
                )
                .toList(growable: false),
            onChanged: (TransportMode? value) {
              if (value == null) {
                return;
              }
              _updateSpec(
                (ProfileSpec current) => current.copyWith(mode: value),
              );
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey<String>('desktop-routing-log-level-field'),
            initialValue: spec.logLevel,
            decoration: InputDecoration(labelText: copy.logLevel),
            items: const <String>['debug', 'info', 'warn', 'error']
                .map(
                  (String level) => DropdownMenuItem<String>(
                    value: level,
                    child: Text(level),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              _updateSpec(
                (ProfileSpec current) => current.copyWith(logLevel: value),
              );
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            key: const ValueKey<String>('desktop-routing-dtls-switch'),
            contentPadding: EdgeInsets.zero,
            title: Text(copy.dtlsEnabled),
            value: spec.useDtls,
            onChanged: (bool value) => _updateSpec(
              (ProfileSpec current) => current.copyWith(useDtls: value),
            ),
          ),
          const SizedBox(height: 12),
          _RoutingTextField(
            key: const ValueKey<String>('desktop-routing-turn-server-field'),
            controller: _turnServerController,
            label: copy.turnOverride,
            onChanged: (String value) => _updateSpec(
              (ProfileSpec current) => current.copyWith(
                turnServer: value.trim().isEmpty ? null : value.trim(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _RoutingTextField(
            key: const ValueKey<String>('desktop-routing-turn-port-field'),
            controller: _turnPortController,
            label: copy.turnPort,
            onChanged: (String value) => _updateSpec(
              (ProfileSpec current) => current.copyWith(
                turnPort: value.trim().isEmpty ? null : value.trim(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _RoutingTextField(
            key: const ValueKey<String>('desktop-routing-bind-interface-field'),
            controller: _bindInterfaceController,
            label: copy.bindInterface,
            onChanged: (String value) => _updateSpec(
              (ProfileSpec current) => current.copyWith(
                bindInterface: value.trim().isEmpty ? null : value.trim(),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton(
                key: const ValueKey<String>('desktop-routing-save-profile'),
                onPressed: busy
                    ? null
                    : () => unawaited(controller.saveDraft()),
                child: Text(copy.saveProfile),
              ),
              FilledButton.tonal(
                key: const ValueKey<String>('desktop-routing-open-profiles'),
                onPressed: controller.showProfiles,
                child: Text(t.commonProfiles),
              ),
              OutlinedButton(
                key: const ValueKey<String>('desktop-routing-start-profile'),
                onPressed: busy || selectedProfile == null
                    ? null
                    : () => unawaited(controller.startSelectedProfile()),
                child: Text(copy.startOnThisDevice),
              ),
            ],
          ),
        ],
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _WorkbenchRouteHeader(
              title: t.commonRouting,
              detail: selectedProfile == null
                  ? copy.desktopPlatformTunnelSummary
                  : '${selectedProfile.name.isEmpty ? selectedProfile.id : selectedProfile.name} · ${selectedProfile.spec.provider}',
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final stacked = constraints.maxWidth < 1320;
                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(child: routingForm),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 320,
                          child: _PlatformTunnelPanel(
                            controller: controller,
                            compact: false,
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(child: routingForm),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 420,
                        child: _PlatformTunnelPanel(
                          controller: controller,
                          compact: false,
                        ),
                      ),
                    ],
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

class _SettingsWorkbenchSurface extends StatelessWidget {
  const _SettingsWorkbenchSurface({required this.controller});

  final DesktopShellController controller;

  @override
  Widget build(BuildContext context) {
    final hostInfo = controller.hostConnection?.info;
    final copy = context.shellText;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: ListView(
          primary: false,
          children: <Widget>[
            _WorkbenchRouteHeader(
              title: t.commonSettings,
              detail: t.localeSwitchTooltip,
            ),
            const SizedBox(height: 16),
            _WorkbenchSummaryCard(
              title: t.localeSwitchTooltip,
              detail: controller.usesSystemLocale
                  ? t.localeSystemDefault
                  : shellLocaleDisplayName(context, controller.activeLocale),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  ChoiceChip(
                    label: Text(t.localeSystemDefault),
                    selected: controller.usesSystemLocale,
                    onSelected: (_) =>
                        unawaited(controller.selectLocaleOverride(null)),
                  ),
                  for (final locale in AppLocale.values)
                    ChoiceChip(
                      key: ValueKey<String>(shellLocaleMenuItemKey(locale)),
                      label: Text(shellLocaleDisplayName(context, locale)),
                      selected:
                          !controller.usesSystemLocale &&
                          controller.activeLocale == locale,
                      onSelected: (_) => unawaited(
                        controller.selectLocaleOverride(shellLocaleTag(locale)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _WorkbenchSummaryCard(
              title: t.desktopShellLabel,
              detail:
                  controller.hostConnection?.message ??
                  t.desktopStatusConnectedDetail,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _Tag(label: copy.guiBuildTag(controller.appBuild.shortLabel)),
                  if (hostInfo != null)
                    _Tag(label: copy.hostBuildTag(hostInfo.build.shortLabel)),
                  if (hostInfo != null)
                    _Tag(label: copy.contractTag(hostInfo.contractVersion)),
                  if (controller.hostConnection?.launched == true)
                    _Tag(label: copy.launched),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _WorkbenchSummaryCard(
              title: t.commonSupport,
              detail: _workflowAssuranceSummary(context, controller),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  FilledButton.tonal(
                    onPressed: controller.busy
                        ? null
                        : () => unawaited(controller.reconnect()),
                    child: Text(t.commonReconnect),
                  ),
                  FilledButton(
                    onPressed:
                        controller.busy ||
                            controller.status != ShellStatus.ready
                        ? null
                        : () => unawaited(controller.refresh()),
                    child: Text(t.commonRefresh),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkbenchSupportRoute extends StatelessWidget {
  const _WorkbenchSupportRoute({
    required this.title,
    required this.detail,
    required this.child,
  });

  final String title;
  final String detail;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _WorkbenchRouteHeader(title: title, detail: detail),
            const SizedBox(height: 16),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _WorkbenchRouteHeader extends StatelessWidget {
  const _WorkbenchRouteHeader({
    required this.title,
    required this.detail,
    this.trailing,
  });

  final String title;
  final String detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stacked = MediaQuery.sizeOf(context).width < 1320;
    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          detail,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    if (trailing == null) {
      return summary;
    }
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[summary, const SizedBox(height: 12), trailing!],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: summary),
        const SizedBox(width: 16),
        Flexible(child: trailing!),
      ],
    );
  }
}

class _WorkbenchStatCard extends StatelessWidget {
  const _WorkbenchStatCard({
    required this.title,
    required this.value,
    required this.detail,
  });

  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 240,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: shellSurfaceDecoration(
          context,
          style: ShellSurfaceStyle.highlight,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(detail, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _WorkbenchSummaryCard extends StatelessWidget {
  const _WorkbenchSummaryCard({
    required this.title,
    required this.detail,
    required this.child,
  });

  final String title;
  final String detail;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: shellSurfaceDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _RoutingTextField extends StatelessWidget {
  const _RoutingTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _CanvasRouteFrame extends StatelessWidget {
  const _CanvasRouteFrame({
    required this.title,
    required this.detail,
    required this.onBack,
    required this.child,
  });

  final String title;
  final String detail;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey<String>('desktop-canvas-route-frame'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                IconButton(
                  key: const ValueKey<String>(
                    'desktop-canvas-route-back-button',
                  ),
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: context.shellText.back,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
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
            const SizedBox(height: 12),
            Expanded(child: child),
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
    final copy = context.shellText;
    final readyTunnelModes = controller.platformTunnels
        .where((PlatformTunnelCapability capability) => capability.available)
        .length;
    final tunnelModes = controller.platformTunnels.length;
    final stateLabel = switch (controller.status) {
      ShellStatus.booting => t.desktopStatusConnectingTitle,
      ShellStatus.ready => t.desktopStatusReadyTitle,
      ShellStatus.blocked => t.desktopStatusBlockedTitle,
    };
    final tone = switch (controller.hostConnection?.state) {
      HostLifecycleState.ready => ShellSemanticTone.ready,
      HostLifecycleState.incompatible => ShellSemanticTone.attention,
      HostLifecycleState.failed => ShellSemanticTone.danger,
      _ => ShellSemanticTone.info,
    };
    final tonePalette = context.shellVisuals.tone(tone);
    final showPinnedSummary =
        controller.status != ShellStatus.ready || controller.hasLiveWork;

    return Card(
      color: tonePalette.container,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final stacked = constraints.maxWidth < 820;
            final summary = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  copy.desktopWorkflowReadiness,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _workflowAssuranceSummary(context, controller),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            );
            final chips = Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: stacked ? WrapAlignment.start : WrapAlignment.end,
              children: <Widget>[
                _AssuranceChip(label: stateLabel, tone: tone),
                _AssuranceChip(
                  label: readyTunnelModes > 0
                      ? copy.desktopTunnelModesReadySummary(
                          readyTunnelModes,
                          tunnelModes,
                        )
                      : copy.desktopPlatformTunnelSummary,
                  tone: readyTunnelModes > 0
                      ? ShellSemanticTone.ready
                      : ShellSemanticTone.neutral,
                ),
                if (controller.hasLiveWork)
                  _AssuranceChip(
                    label: copy.desktopResolutionsSessionsCompact(
                      controller.resolutions.length,
                      controller.sessions.length,
                    ),
                    tone: ShellSemanticTone.info,
                  ),
                if (controller.hostConnection?.isReady != true)
                  _AssuranceChip(
                    label: copy.desktopSupportContextPinned,
                    tone: ShellSemanticTone.attention,
                  ),
              ],
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (stacked) ...<Widget>[
                  summary,
                  const SizedBox(height: 10),
                  chips,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: summary),
                      const SizedBox(width: 12),
                      Flexible(child: chips),
                    ],
                  ),
                const SizedBox(height: 8),
                Text(
                  _platformTunnelHeaderSummary(context, controller),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (showPinnedSummary) ...<Widget>[
                  const SizedBox(height: 10),
                  _PinnedSupportSummary(controller: controller),
                ],
              ],
            );
          },
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
    final copy = context.shellText;
    final title = switch (controller.status) {
      ShellStatus.blocked => copy.desktopSupportAttentionRequired,
      ShellStatus.booting => copy.desktopSupportContextWarmingUp,
      ShellStatus.ready =>
        controller.hasLiveWork
            ? copy.desktopLiveWorkActive
            : copy.desktopSupportNote,
    };
    final detail = switch (controller.status) {
      ShellStatus.blocked =>
        controller.notice ??
            controller.hostConnection?.message ??
            copy.desktopSupportBlockedDetail,
      ShellStatus.booting =>
        controller.notice ?? copy.desktopSupportBootingDetail,
      ShellStatus.ready =>
        controller.hasLiveWork
            ? copy.desktopSupportReadyLiveDetail
            : copy.desktopSupportReadyIdleDetail,
    };
    final tone = switch (controller.status) {
      ShellStatus.blocked => ShellSemanticTone.danger,
      ShellStatus.booting => ShellSemanticTone.info,
      ShellStatus.ready =>
        controller.hasLiveWork
            ? ShellSemanticTone.info
            : ShellSemanticTone.neutral,
    };
    final palette = context.shellVisuals.tone(tone);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: shellSurfaceDecoration(
        context,
        style: ShellSurfaceStyle.highlight,
        tone: tone,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            controller.status == ShellStatus.ready
                ? Icons.stream_outlined
                : Icons.warning_amber_rounded,
            size: 18,
            color: palette.accent,
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
  const _AssuranceChip({
    required this.label,
    this.tone = ShellSemanticTone.neutral,
  });

  final String label;
  final ShellSemanticTone tone;

  @override
  Widget build(BuildContext context) {
    return ShellToneBadge(label: label, tone: tone);
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
          padding: const EdgeInsets.all(12),
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
    final copy = context.shellText;
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
                        copy.desktopInspector,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        controller.activeInspectorPane ==
                                DesktopInspectorPane.diagnostics
                            ? copy.desktopInspectorDiagnosticsSubtitle
                            : copy.desktopInspectorActivitySubtitle,
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
                  tooltip: copy.close,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<DesktopInspectorPane>(
              segments: <ButtonSegment<DesktopInspectorPane>>[
                ButtonSegment<DesktopInspectorPane>(
                  value: DesktopInspectorPane.diagnostics,
                  label: Text(copy.diagnostics),
                  icon: Icon(Icons.medical_services_outlined),
                ),
                ButtonSegment<DesktopInspectorPane>(
                  value: DesktopInspectorPane.activity,
                  label: Text(t.commonLiveWork),
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
          TabBar(
            tabs: <Widget>[
              Tab(text: context.shellText.events),
              Tab(text: context.shellText.desktopTunnelDetail),
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
              Tab(
                text: context.shellText.resolutionsCount(
                  controller.resolutions.length,
                ),
              ),
              Tab(
                text: context.shellText.sessionsCount(
                  controller.sessions.length,
                ),
              ),
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
    final copy = context.shellText;
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
          copy.desktopNoPlatformTunnelModesReported,
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
                    _compactPlatformTunnelStatusLabel(context, capability),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
              copy.desktopPlatformTunnelModes,
              style:
                  (compact
                          ? theme.textTheme.titleSmall
                          : theme.textTheme.titleLarge)
                      ?.copyWith(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: compact ? 4 : 6),
            Text(
              _platformTunnelHeaderSummary(context, controller),
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
    final copy = context.shellText;

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
                child: Text(
                  copy.unavailableLowercase,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            _compactPlatformTunnelCapabilitySummary(context, capability),
            style: compact
                ? theme.textTheme.bodySmall
                : theme.textTheme.bodyMedium,
          ),
          SizedBox(height: compact ? 8 : 10),
          if (capability.available)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: busy || !ready ? null : () => unawaited(onStart()),
                child: Text(copy.requestStartup),
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
    final copy = context.shellText;
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
                  capability.available
                      ? copy.availableLowercase
                      : copy.unavailableLowercase,
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
            _platformTunnelCapabilitySummary(context, capability),
            style: theme.textTheme.bodyMedium,
          ),
          if (capability.message.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(capability.message, style: theme.textTheme.bodySmall),
          ],
          if (capability.available) ...<Widget>[
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: busy || !ready ? null : () => unawaited(onStart()),
              child: Text(copy.requestStartup),
            ),
            const SizedBox(height: 10),
            Text(
              result == null
                  ? copy.desktopNoStartupRequestYet
                  : _platformTunnelResultSummary(context, result!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else if (result != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              _platformTunnelResultSummary(context, result!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
    final copy = context.shellText;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          copy.resolutionsTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          copy.resolutionsSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: controller.resolutions.isEmpty
              ? Center(
                  child: Text(
                    copy.noProviderResolutionsYet,
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
    final copy = context.shellText;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          copy.sessionsTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: controller.sessions.isEmpty
              ? Center(
                  child: Text(
                    copy.desktopNoSessionsYet,
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
    final copy = context.shellText;
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
                  copy.turnCredentialsSummary(
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
                    _Tag(label: resolution.artifact!.family.label),
                    for (final action in resolution.artifact!.actions)
                      _Tag(
                        label:
                            '${action.id.label} · ${copy.actionExecutionOwnerLabel(action.executionOwner.value)}',
                      ),
                  ],
                ),
              ],
              if (resolution.export.expiresAt != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  copy.exportExpiry(
                    timestamp: resolution.export.expiresAt!
                        .toLocal()
                        .toIso8601String(),
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
                  copy.failureSummary(
                    stage: resolution.failure!.stage ?? copy.failureFallback,
                    message: resolution.failure!.message ?? copy.unknownValue,
                  ),
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
                        copy.challengeKind(challenge!.kind),
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
                            child: Text(copy.continueAfterBrowserStep),
                          ),
                          OutlinedButton(
                            onPressed: busy || onCancelChallenge == null
                                ? null
                                : () => unawaited(onCancelChallenge!.call()),
                            child: Text(copy.cancelChallenge),
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
                    child: Text(copy.startOnThisDevice),
                  ),
                  OutlinedButton(
                    onPressed: busy || onCopyExport == null
                        ? null
                        : () => unawaited(onCopyExport!.call()),
                    child: Text(copy.copyHandoff),
                  ),
                  if (onOpenRoom != null)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => unawaited(onOpenRoom!.call()),
                      child: Text(copy.openRoom),
                    ),
                  if (onOpenCamera != null)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => unawaited(onOpenCamera!.call()),
                      child: Text(copy.openCamera),
                    ),
                  if (onOpenArchive != null)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => unawaited(onOpenArchive!.call()),
                      child: Text(copy.openArchive),
                    ),
                  if (onCancel != null)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => unawaited(onCancel!.call()),
                      child: Text(copy.cancelResolution),
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
    final copy = context.shellText;
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
                copy.sessionListenConnections(
                  listen: session.profile.listenAddress,
                  connections: session.profile.connections,
                ),
                style: theme.textTheme.bodySmall,
              ),
              if (session.failure != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  copy.failureSummary(
                    stage: session.failure!.stage ?? copy.failureFallback,
                    message: session.failure!.message ?? copy.unknownValue,
                  ),
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
                        copy.challengeKind(challenge!.kind),
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
                            child: Text(copy.continueInBrowser),
                          ),
                          OutlinedButton(
                            onPressed: busy || onCancelChallenge == null
                                ? null
                                : () => unawaited(onCancelChallenge!.call()),
                            child: Text(copy.cancelChallenge),
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
                    child: Text(copy.exportDiagnostics),
                  ),
                  if (session.state != SessionState.stopped &&
                      session.state != SessionState.failed)
                    OutlinedButton(
                      onPressed: busy ? null : () => unawaited(onStop()),
                      child: Text(copy.stopSession),
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
    final copy = context.shellText;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              copy.eventStream,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              copy.desktopEventStreamSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: controller.events.isEmpty
                  ? Center(
                      child: Text(
                        copy.noEventsYet,
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

class _ResolutionStateChip extends StatelessWidget {
  const _ResolutionStateChip({required this.state});

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

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ShellToneBadge(label: label);
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.message, this.compact = false});

  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ShellNoticeBanner(message: message, compact: compact);
  }
}

int _workbenchIndex(DesktopWorkbenchRoute route) {
  return switch (route) {
    DesktopWorkbenchRoute.home => 0,
    DesktopWorkbenchRoute.profiles => 1,
    DesktopWorkbenchRoute.routing => 2,
    DesktopWorkbenchRoute.activity => 3,
    DesktopWorkbenchRoute.diagnostics => 4,
    DesktopWorkbenchRoute.settings => 5,
  };
}

String _workflowAssuranceSummary(
  BuildContext context,
  DesktopShellController controller,
) {
  final copy = context.shellText;
  return switch (controller.status) {
    ShellStatus.booting => copy.desktopWorkflowAssuranceBooting,
    ShellStatus.blocked =>
      controller.hostConnection?.message ??
          copy.desktopWorkflowAssuranceBlocked,
    ShellStatus.ready =>
      controller.hasLiveWork
          ? copy.desktopWorkflowAssuranceReadyLive
          : copy.desktopWorkflowAssuranceReadyIdle,
  };
}

String _routineConnectionDetail({required ShellText copy, String? message}) {
  if (message == null || message.isEmpty) {
    return '';
  }
  final prefixes = <String>[
    copy.connectedToLocalHost(''),
    const ShellText().connectedToLocalHost(''),
  ];
  for (final prefix in prefixes) {
    if (prefix.isNotEmpty && message.startsWith(prefix)) {
      return message.substring(prefix.length).trimLeft();
    }
  }
  return message;
}

String _platformTunnelHeaderSummary(
  BuildContext context,
  DesktopShellController controller,
) {
  final copy = context.shellText;
  final platformTunnels = controller.platformTunnels;
  if (platformTunnels.isEmpty) {
    return copy.desktopNoPlatformTunnelModesReported;
  }

  final readyCount = platformTunnels
      .where((PlatformTunnelCapability capability) => capability.available)
      .length;
  if (readyCount > 0) {
    return copy.desktopUseDiagnosticsForReportedModes;
  }

  final startupRequested = platformTunnels.any(
    (PlatformTunnelCapability capability) =>
        controller.platformTunnelResultFor(capability.mode) != null,
  );
  if (startupRequested) {
    return copy.desktopAllModesFailClosedLatestEvidence;
  }

  return copy.desktopTypedHostTunnelSummary;
}

String _platformTunnelCapabilitySummary(
  BuildContext context,
  PlatformTunnelCapability capability,
) {
  return context.shellText.desktopPlatformTunnelCapabilitySummary(
    available: capability.available,
    satisfiedPrerequisites: capability.satisfiedPrerequisites
        .map((PlatformTunnelPrerequisite prerequisite) => prerequisite.label)
        .toList(growable: false),
    missingPrerequisite: capability.missingPrerequisite?.label,
  );
}

String _compactPlatformTunnelCapabilitySummary(
  BuildContext context,
  PlatformTunnelCapability capability,
) {
  return context.shellText.desktopCompactPlatformTunnelCapabilitySummary(
    modeLabel: capability.mode.label,
    available: capability.available,
    missingPrerequisite: capability.missingPrerequisite?.label,
    message: capability.message,
  );
}

String _compactPlatformTunnelStatusLabel(
  BuildContext context,
  PlatformTunnelCapability capability,
) {
  return context.shellText.desktopCompactPlatformTunnelStatusLabel(
    modeLabel: capability.mode.label,
    missingPrerequisite: capability.missingPrerequisite?.label,
  );
}

String _platformTunnelResultSummary(
  BuildContext context,
  PlatformTunnelStartResult result,
) {
  final copy = context.shellText;
  return copy.desktopPlatformTunnelResultSummary(
    modeLabel: result.mode.label,
    ready: result.ready,
    stageLabel: result.stage?.label ?? copy.unknownStage,
    missingPrerequisite: result.missingPrerequisite?.label,
    message: result.message,
  );
}
