import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_shell_core/home_workflow_surface.dart';
import 'package:flutter_shell_core/routing_content_surface.dart' as routing;
import 'package:flutter_shell_core/shell_visuals.dart';
import 'package:flutter_shell_core/support_content_surface.dart' as support;
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

  void _showProvidersRoute() {
    controller.showProviders();
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
              _showProvidersRoute,
          const SingleActivator(LogicalKeyboardKey.digit4, control: true):
              _showRoutingRoute,
          const SingleActivator(LogicalKeyboardKey.digit5, control: true):
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
                          onShowProviders: () {
                            Navigator.of(context).maybePop();
                            _showProvidersRoute();
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
                          onShowProviders: _showProvidersRoute,
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
    required this.onShowProviders,
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
  final VoidCallback onShowProviders;
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
                        onShowProviders: onShowProviders,
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
    required this.onShowProviders,
    required this.onShowRouting,
    required this.onShowActivity,
    required this.onShowDiagnostics,
    required this.onShowSettings,
  });

  final DesktopShellController controller;
  final VoidCallback onShowHome;
  final VoidCallback onShowProfiles;
  final VoidCallback onShowProviders;
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
            onShowProviders();
          case 3:
            onShowRouting();
          case 4:
            onShowActivity();
          case 5:
            onShowDiagnostics();
          case 6:
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
          key: ValueKey<String>('desktop-section-provider'),
          icon: Icon(Icons.tune_outlined),
          label: Text(t.commonProviders),
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
    required this.onShowProviders,
    required this.onShowRouting,
    required this.onShowActivity,
    required this.onShowDiagnostics,
    required this.onShowSettings,
  });

  final DesktopShellController controller;
  final VoidCallback onShowHome;
  final VoidCallback onShowProfiles;
  final VoidCallback onShowProviders;
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
              subtitle: t.commonSavedProfiles,
              selected:
                  controller.activeWorkbenchRoute ==
                  DesktopWorkbenchRoute.profiles,
              onTap: onShowProfiles,
            ),
            const SizedBox(height: 8),
            _SectionListTile(
              key: const ValueKey<String>('desktop-section-provider'),
              icon: Icons.tune_outlined,
              title: t.commonProviders,
              subtitle: t.commonProviderRecords,
              selected:
                  controller.activeWorkbenchRoute ==
                  DesktopWorkbenchRoute.providers,
              onTap: onShowProviders,
            ),
            const SizedBox(height: 8),
            _SectionListTile(
              key: const ValueKey<String>('desktop-section-routing'),
              icon: Icons.route_outlined,
              title: t.commonRouting,
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
          case DesktopWorkbenchRoute.providers:
            return _ProvidersWorkbenchSurface(controller: controller);
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: ListView(
          primary: false,
          children: <Widget>[
            _WorkbenchRouteHeader(
              title: copy.overview,
              detail: _workflowAssuranceSummary(context, controller),
            ),
            const SizedBox(height: 16),
            HomeWorkflowBody(
              emptyState: controller.profiles.isEmpty
                  ? _desktopHomeEmptyStateData(context, controller)
                  : null,
              profileSummary: controller.selectedSavedProfile == null
                  ? null
                  : _desktopHomeProfileSummaryData(
                      context,
                      controller.selectedSavedProfile!,
                    ),
              primaryAction: _desktopHomePrimaryActionData(context, controller),
              modeSection: _desktopHomeModeSectionData(context, controller),
              supportSection: _desktopHomeSupportSectionData(
                context,
                controller,
              ),
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
          onBack: controller.canReturnFromCanvasRoute
              ? controller.returnFromCanvasRoute
              : null,
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
      case DesktopCanvasRoute.profileEditor:
      case DesktopCanvasRoute.managedProviderEditor:
      case DesktopCanvasRoute.managedProviderPicker:
      case DesktopCanvasRoute.presetPicker:
      case DesktopCanvasRoute.providerFamilyPicker:
        break;
    }

    return ProfileEditorPanel(
      providerDescriptors: controller.providerDescriptors,
      managedProviders: controller.managedProviders,
      initialManagedProviderId:
          controller.draft.providerBinding.managedProviderId,
      selectedProfileId: controller.selectedProfileId,
      draft: controller.draft,
      busy: busy,
      onDraftChanged: controller.updateDraft,
      onActivateManagedProviderMode: controller.activateManagedProviderMode,
      onUseCustomProvider: controller.useCustomProviderForDraft,
      onSave: controller.saveDraft,
      onDelete: controller.deleteSelectedProfile,
      onReset: controller.resetDraft,
      onResolve: controller.startResolutionFromDraft,
      onStart: controller.startSelectedProfile,
      onPreparePortableExport: controller.selectedPortableProfileEnvelope,
      onCopyPortableExportText: controller.copyPortableProfileEnvelopeText,
      onSavePortableExportFile: controller.savePortableProfileEnvelopeToFile,
      onImportPortableFromFile:
          controller.importPortableProfileEnvelopeFromFile,
      onPreviewPortableImport: controller.previewPortableProfileEnvelope,
      onConfirmPortableImport: controller.confirmPortableProfileImport,
      onOpenSavedProfiles: () async {
        controller.openSavedProfilePicker();
      },
      onBrowseManagedProviders: () async {
        controller.openManagedProviderPickerForProfile();
      },
    );
  }
}

class _ProvidersWorkbenchSurface extends StatelessWidget {
  const _ProvidersWorkbenchSurface({required this.controller});

  final DesktopShellController controller;

  @override
  Widget build(BuildContext context) {
    final busy = controller.busy || controller.status != ShellStatus.ready;

    switch (controller.activeCanvasRoute) {
      case DesktopCanvasRoute.managedProviderPicker:
        return _CanvasRouteFrame(
          title: context.shellText.desktopProviderRecordsLibraryTitle,
          detail: context.shellText.desktopProviderRecordsRouteDetail,
          onBack: controller.canReturnFromCanvasRoute
              ? controller.returnFromCanvasRoute
              : null,
          child: ManagedProvidersLibrarySurface(
            managedProviders: controller.managedProviders,
            selectedManagedProviderId: controller.selectedManagedProviderId,
            onSelectManagedProvider: controller.selectManagedProvider,
            onCreateManagedProvider: controller.startManagedProviderCreation,
            onOpenPresetBootstrap: () {
              controller.openPresetPicker(
                returnTarget: DesktopCanvasRoute.managedProviderPicker,
              );
            },
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
      case DesktopCanvasRoute.managedProviderEditor:
      case DesktopCanvasRoute.profileEditor:
      case DesktopCanvasRoute.savedProfilePicker:
      case DesktopCanvasRoute.managedProviderPickerForProfile:
        break;
    }

    return ProviderConfigEditorPanel(
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
      onBrowseManagedProviders: () async {
        controller.openManagedProviderPicker();
      },
    );
  }
}

class _RoutingWorkbenchSurface extends StatelessWidget {
  const _RoutingWorkbenchSurface({required this.controller});

  final DesktopShellController controller;

  @override
  Widget build(BuildContext context) {
    final copy = context.shellText;
    final spec = controller.draft.spec;
    final selectedProfile = controller.selectedSavedProfile;
    final busy = controller.busy || controller.status != ShellStatus.ready;

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
              child: routing.RoutingContentSurface(
                variant: routing.RoutingContentSurfaceVariant.desktop,
                spec: spec,
                selectedProfileName: selectedProfile?.name.isEmpty == true
                    ? selectedProfile?.id
                    : selectedProfile?.name,
                selectedProfileProvider: selectedProfile?.spec.provider,
                busy: busy,
                hostReady: controller.hostConnection?.isReady == true,
                platformTunnels: controller.platformTunnels,
                platformTunnelResultFor: controller.platformTunnelResultFor,
                onSpecChanged: (ProfileSpec nextSpec) {
                  controller.updateDraft(
                    controller.draft.copyWith(spec: nextSpec),
                  );
                },
                onSave: busy ? null : controller.saveDraft,
                onOpenProfiles: controller.showProfiles,
                onStartProfile: busy || selectedProfile == null
                    ? null
                    : controller.startSelectedProfile,
                onStartPlatformTunnel: controller.startPlatformTunnel,
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
  const _WorkbenchRouteHeader({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
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

class _CanvasRouteFrame extends StatelessWidget {
  const _CanvasRouteFrame({
    required this.title,
    required this.detail,
    this.onBack,
    required this.child,
  });

  final String title;
  final String detail;
  final VoidCallback? onBack;
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
                if (onBack != null) ...<Widget>[
                  IconButton(
                    key: const ValueKey<String>(
                      'desktop-canvas-route-back-button',
                    ),
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                    tooltip: context.shellText.back,
                  ),
                  const SizedBox(width: 8),
                ],
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
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
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
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
                support.SupportDiagnosticsOverviewSurface(
                  variant: support.SupportContentSurfaceVariant.desktop,
                  children: <Widget>[
                    _PlatformTunnelPanel(
                      controller: controller,
                      compact: false,
                    ),
                  ],
                ),
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
                _ResolutionsPanel(controller: controller),
                _SessionsPanel(controller: controller),
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
      color: context.shellVisuals.tone(ShellSemanticTone.info).container,
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
      decoration: shellSurfaceDecoration(
        context,
        style: ShellSurfaceStyle.highlight,
        tone: ShellSemanticTone.info,
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
              ShellToneBadge(
                label: copy.unavailableLowercase,
                tone: ShellSemanticTone.attention,
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: shellSurfaceDecoration(
        context,
        style: ShellSurfaceStyle.highlight,
        tone: ShellSemanticTone.info,
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
              ShellToneBadge(
                label: capability.available
                    ? copy.availableLowercase
                    : copy.unavailableLowercase,
                tone: capability.available
                    ? ShellSemanticTone.ready
                    : ShellSemanticTone.attention,
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
  const _ResolutionsPanel({required this.controller});

  final DesktopShellController controller;

  @override
  Widget build(BuildContext context) {
    return support.SupportResolutionsSurface(
      variant: support.SupportContentSurfaceVariant.desktop,
      resolutions: controller.resolutions,
      selectedResolutionId: controller.selectedResolutionId,
      busy: controller.busy || controller.status != ShellStatus.ready,
      challengeForResolution: controller.activeChallengeForResolution,
      actionsForResolution:
          (ResolutionRecord resolution, ChallengeRecord? challenge) =>
              support.SupportResolutionActions(
                onSelect: () => controller.selectResolution(resolution.id),
                onCancel: resolution.isTerminal
                    ? null
                    : () => controller.cancelResolution(resolution.id),
                onMaterialize:
                    resolution.state == ResolutionState.resolved &&
                        resolution.supportsAction(
                          ArtifactAction.startOnThisDevice,
                        )
                    ? () => controller.materializeResolution(resolution.id)
                    : null,
                onCopyExport:
                    resolution.state == ResolutionState.resolved &&
                        resolution.supportsAction(ArtifactAction.exportHandoff)
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
                        resolution.supportsAction(ArtifactAction.openCamera)
                    ? () => controller.openResolutionExternalAction(
                        resolution.id,
                        ArtifactAction.openCamera,
                      )
                    : null,
                onOpenArchive:
                    resolution.state == ResolutionState.resolved &&
                        resolution.supportsAction(ArtifactAction.openArchive)
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
              ),
      scrollKey: const ValueKey<String>('resolutions-scroll'),
    );
  }
}

class _SessionsPanel extends StatelessWidget {
  const _SessionsPanel({required this.controller});

  final DesktopShellController controller;

  @override
  Widget build(BuildContext context) {
    return support.SupportSessionsSurface(
      variant: support.SupportContentSurfaceVariant.desktop,
      sessions: controller.sessions,
      selectedSessionId: controller.selectedSessionId,
      busy: controller.busy || controller.status != ShellStatus.ready,
      challengeForSession: controller.activeChallengeFor,
      actionsForSession: (SessionRecord session, ChallengeRecord? challenge) =>
          support.SupportSessionActions(
            onSelect: () => controller.selectSession(session.id),
            onStop: () => controller.stopSession(session.id),
            onExport: () => controller.exportDiagnostics(session.id),
            onContinueChallenge: challenge == null
                ? null
                : () => controller.continueChallenge(challenge.id),
            onCancelChallenge: challenge == null
                ? null
                : () => controller.cancelChallenge(challenge.id),
          ),
      scrollKey: const ValueKey<String>('sessions-scroll'),
    );
  }
}

class _EventsPanel extends StatelessWidget {
  const _EventsPanel({required this.controller});

  final DesktopShellController controller;

  @override
  Widget build(BuildContext context) {
    return support.SupportEventStreamSurface(
      variant: support.SupportContentSurfaceVariant.desktop,
      events: controller.events,
      scrollKey: const ValueKey<String>('events-scroll'),
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
    DesktopWorkbenchRoute.providers => 2,
    DesktopWorkbenchRoute.routing => 3,
    DesktopWorkbenchRoute.activity => 4,
    DesktopWorkbenchRoute.diagnostics => 5,
    DesktopWorkbenchRoute.settings => 6,
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

HomeWorkflowEmptyStateData _desktopHomeEmptyStateData(
  BuildContext context,
  DesktopShellController controller,
) {
  return HomeWorkflowEmptyStateData(
    title: context.shellText.homeNoSavedProfilesYet,
    message: context.shellText.homeNoSavedProfilesMessage,
    actions: <HomeWorkflowAction>[
      HomeWorkflowAction(
        label: t.commonSavedProfiles,
        onPressed: controller.showProfiles,
      ),
      HomeWorkflowAction(
        label: t.commonRouting,
        style: HomeWorkflowActionStyle.tonal,
        onPressed: controller.showRouting,
      ),
    ],
  );
}

HomeWorkflowProfileSummaryData _desktopHomeProfileSummaryData(
  BuildContext context,
  ProfileRecord profile,
) {
  final copy = context.shellText;
  return HomeWorkflowProfileSummaryData(
    eyebrow: copy.currentProfile,
    title: profile.name.isEmpty ? profile.id : profile.name,
    subtitle: '${profile.spec.provider} -> ${profile.spec.peerAddress}',
    caption: copy.listeningOn(profile.spec.listenAddress),
  );
}

HomeWorkflowPrimaryActionData _desktopHomePrimaryActionData(
  BuildContext context,
  DesktopShellController controller,
) {
  final copy = context.shellText;
  final selectedProfile = controller.selectedSavedProfile;
  final challenge = _desktopHomePrimaryChallenge(controller);
  if (challenge != null) {
    return HomeWorkflowPrimaryActionData(
      tone: ShellSemanticTone.attention,
      eyebrow: copy.providerStepTone,
      title: copy.finishProviderValidation,
      subtitle: copy.desktopSupportReadyLiveDetail,
      leadingIcon: Icons.travel_explore_rounded,
      primaryAction: HomeWorkflowAction(
        label: copy.openActivity,
        icon: Icons.view_list_rounded,
        onPressed: controller.showActivityRoute,
      ),
      annotation: copy.challengeKind(challenge.kind),
      secondaryActions: <HomeWorkflowAction>[
        HomeWorkflowAction(
          label: copy.iveCompletedIt,
          style: HomeWorkflowActionStyle.outlined,
          onPressed: controller.busy
              ? null
              : () => unawaited(controller.continueChallenge(challenge.id)),
        ),
        HomeWorkflowAction(
          label: copy.cancelChallenge,
          style: HomeWorkflowActionStyle.text,
          onPressed: controller.busy
              ? null
              : () => unawaited(controller.cancelChallenge(challenge.id)),
        ),
      ],
    );
  }
  if (controller.hasLiveWork) {
    return HomeWorkflowPrimaryActionData(
      tone: ShellSemanticTone.ready,
      eyebrow: copy.connectionLiveTone,
      title: t.commonLiveWork,
      subtitle: copy.desktopResolutionsSessionsCompact(
        controller.resolutions.length,
        controller.sessions.length,
      ),
      leadingIcon: Icons.shield_rounded,
      primaryAction: HomeWorkflowAction(
        label: copy.openActivity,
        icon: Icons.view_list_rounded,
        onPressed: controller.showActivityRoute,
      ),
      secondaryActions: <HomeWorkflowAction>[
        HomeWorkflowAction(
          label: copy.openDiagnostics,
          style: HomeWorkflowActionStyle.outlined,
          onPressed: controller.showDiagnosticsRoute,
        ),
      ],
    );
  }
  if (selectedProfile == null) {
    return HomeWorkflowPrimaryActionData(
      tone: ShellSemanticTone.neutral,
      eyebrow: copy.setupNeededTone,
      title: copy.profileRequired,
      subtitle: copy.chooseOrFinishProfileBeforeStartingVpn,
      leadingIcon: Icons.folder_open_rounded,
      primaryAction: HomeWorkflowAction(
        label: copy.continueInProfiles,
        key: const ValueKey<String>('desktop-open-profile-library-button'),
        icon: Icons.arrow_forward_rounded,
        onPressed: controller.showProfiles,
      ),
      secondaryActions: <HomeWorkflowAction>[
        HomeWorkflowAction(
          label: t.commonRouting,
          style: HomeWorkflowActionStyle.tonal,
          onPressed: controller.showRouting,
        ),
      ],
    );
  }
  return HomeWorkflowPrimaryActionData(
    tone: ShellSemanticTone.info,
    eyebrow: copy.mainActionTone,
    title: copy.startOnThisDevice,
    subtitle:
        '${selectedProfile.name.isEmpty ? selectedProfile.id : selectedProfile.name} · ${selectedProfile.spec.provider}',
    leadingIcon: Icons.power_rounded,
    primaryAction: HomeWorkflowAction(
      key: const ValueKey<String>('desktop-home-start-selected-profile'),
      label: copy.startOnThisDevice,
      icon: Icons.power_settings_new_rounded,
      onPressed: controller.status == ShellStatus.ready && !controller.busy
          ? () => unawaited(controller.startSelectedProfile())
          : null,
    ),
    secondaryActions: <HomeWorkflowAction>[
      HomeWorkflowAction(
        key: const ValueKey<String>('desktop-open-profile-library-button'),
        label: t.commonProfiles,
        style: HomeWorkflowActionStyle.tonal,
        onPressed: controller.showProfiles,
      ),
      HomeWorkflowAction(
        label: t.commonRouting,
        style: HomeWorkflowActionStyle.outlined,
        onPressed: controller.showRouting,
      ),
    ],
  );
}

HomeWorkflowModeSectionData _desktopHomeModeSectionData(
  BuildContext context,
  DesktopShellController controller,
) {
  return HomeWorkflowModeSectionData(
    title: context.shellText.currentMode,
    summary: _desktopHomeModeSummary(context, controller),
    detail: _desktopHomeModeDetail(context, controller),
  );
}

HomeWorkflowSupportSectionData _desktopHomeSupportSectionData(
  BuildContext context,
  DesktopShellController controller,
) {
  final latestResult = _desktopLatestPlatformTunnelResult(controller);
  final liveSummary = latestResult == null
      ? context.shellText.noStartupRequestYetShort
      : _platformTunnelResultSummary(context, latestResult);
  return HomeWorkflowSupportSectionData(
    title: context.shellText.needDeeperDetail,
    summary: context.shellText.resolutionsSessionsSummary(
      resolutions: controller.resolutions.length,
      sessions: controller.sessions.length,
      liveSummary: liveSummary,
    ),
    actions: <HomeWorkflowAction>[
      HomeWorkflowAction(
        label: context.shellText.openActivity,
        style: HomeWorkflowActionStyle.tonal,
        onPressed: controller.hasLiveWork ? controller.showActivityRoute : null,
      ),
      HomeWorkflowAction(
        label: context.shellText.openDiagnostics,
        style: HomeWorkflowActionStyle.outlined,
        onPressed: controller.showDiagnosticsRoute,
      ),
    ],
  );
}

ChallengeRecord? _desktopHomePrimaryChallenge(
  DesktopShellController controller,
) {
  for (final resolution in controller.resolutions) {
    if (resolution.state != ResolutionState.challengeRequired) {
      continue;
    }
    final challenge = controller.activeChallengeForResolution(resolution);
    if (challenge != null) {
      return challenge;
    }
  }
  for (final session in controller.sessions) {
    if (session.state != SessionState.challengeRequired) {
      continue;
    }
    final challenge = controller.activeChallengeFor(session);
    if (challenge != null) {
      return challenge;
    }
  }
  return null;
}

PlatformTunnelStartResult? _desktopLatestPlatformTunnelResult(
  DesktopShellController controller,
) {
  for (final capability in controller.platformTunnels) {
    final result = controller.platformTunnelResultFor(capability.mode);
    if (result != null) {
      return result;
    }
  }
  return null;
}

String _desktopHomeModeSummary(
  BuildContext context,
  DesktopShellController controller,
) {
  final copy = context.shellText;
  if (controller.platformTunnels.isEmpty) {
    return copy.desktopNoPlatformTunnelModesReported;
  }
  final readyCount = controller.platformTunnels
      .where((PlatformTunnelCapability capability) => capability.available)
      .length;
  if (readyCount > 0) {
    return copy.desktopTunnelModesReadySummary(
      readyCount,
      controller.platformTunnels.length,
    );
  }
  if (controller.platformTunnels.length == 1) {
    return _compactPlatformTunnelCapabilitySummary(
      context,
      controller.platformTunnels.single,
    );
  }
  return copy.desktopTypedHostTunnelSummary;
}

String? _desktopHomeModeDetail(
  BuildContext context,
  DesktopShellController controller,
) {
  final latestResult = _desktopLatestPlatformTunnelResult(controller);
  if (latestResult != null) {
    return _platformTunnelResultSummary(context, latestResult);
  }
  for (final capability in controller.platformTunnels) {
    final message = capability.message.trim();
    if (message.isNotEmpty) {
      return message;
    }
  }
  return null;
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
