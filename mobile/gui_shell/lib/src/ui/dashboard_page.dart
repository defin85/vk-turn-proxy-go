import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_shell_core/home_workflow_surface.dart';
import 'package:flutter_shell_core/portable_profile_transfer.dart';
import 'package:flutter_shell_core/provider_source_catalog_surface.dart';
import 'package:flutter_shell_core/routing_content_surface.dart' as routing;
import 'package:flutter_shell_core/shell_visuals.dart';
import 'package:flutter_shell_core/support_content_surface.dart' as support;
import 'package:flutter_shell_core/vpn_transport_profile_editor.dart';
import 'package:flutter_shell_core/workflow_library_surface.dart' as workflow;
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/mobile_host_bridge.dart';
import 'package:mobile_gui_shell/src/control/mobile_platform_app_inventory.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_controller.dart';
import 'package:mobile_gui_shell/src/ui/owned_browser_challenge.dart';
import 'package:mobile_gui_shell/src/ui/portable_profile_transfer_dialogs.dart';
import 'package:mobile_gui_shell/src/ui/profile_editor.dart';
import 'package:mobile_gui_shell/src/ui/provider_config_editor.dart';
import 'package:mobile_gui_shell/src/ui/transport_profile_portable_transfer_dialogs.dart';

const double _compactNavigationBreakpoint = 840;
const double _providerListDetailBreakpoint = 920;

enum _DashboardDestination { home, profiles, providers, routing, support }

enum _SupportSurface { activity, diagnostics }

enum _ActivitySurface { resolutions, sessions }

enum _DiagnosticsSurface { overview, events }

enum _ProfileImportAction { file, qr, paste }

enum _ProviderRootSurface { savedProviders, templates }

enum _ProviderChooserSurface { families, templates }

enum _InlineActionDensity { compact, medium, wide }

enum _InlineActionVariant { filledTonal, outlined }

class _ProviderChooserResult {
  const _ProviderChooserResult.family(this.providerId) : preset = null;

  const _ProviderChooserResult.template(this.preset) : providerId = null;

  final String? providerId;
  final ProviderPreset? preset;
}

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
  _DashboardDestination _destination = _DashboardDestination.home;
  _SupportSurface _supportSurface = _SupportSurface.activity;
  _ActivitySurface _activitySurface = _ActivitySurface.resolutions;
  _DiagnosticsSurface _diagnosticsSurface = _DiagnosticsSurface.overview;
  bool _portableImportRouteScheduled = false;

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
        if (!mounted) {
          await widget.controller.cancelChallenge(challenge.id);
          return;
        }
        await widget.controller.cancelChallenge(
          challenge.id,
          noticeOverride: context.shellText.challengeContinuationCancelled(
            challenge.id,
          ),
        );
        return;
      }
      await widget.controller.continueOwnedBrowserChallenge(
        challenge.id,
        browserContinuation,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _destination = _DashboardDestination.home;
      });
    } catch (error) {
      if (!mounted) {
        await widget.controller.cancelChallenge(challenge.id);
        return;
      }
      await widget.controller.cancelChallenge(
        challenge.id,
        noticeOverride: context.shellText.challengeContinuationFailed(
          challengeId: challenge.id,
          error: error,
        ),
      );
    }
  }

  String _openChallengeLabel(ChallengeRecord? challenge) {
    if (challenge == null) {
      return context.shellText.mobileOpenBrowser;
    }
    return widget.controller.challengeRequiresOwnedBrowser(challenge)
        ? context.shellText.mobileContinueInApp
        : context.shellText.mobileOpenBrowser;
  }

  bool _showsManualChallengeContinue(ChallengeRecord? challenge) {
    if (challenge == null) {
      return false;
    }
    return !widget.controller.challengeRequiresOwnedBrowser(challenge);
  }

  Future<void> _openVPNTransportProfileEditorForMode(
    PlatformTunnelMode mode,
  ) async {
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => _VPNTransportProfileManagerPage(
          controller: widget.controller,
          mode: mode,
        ),
      ),
    );
  }

  void _openSupport({_SupportSurface surface = _SupportSurface.activity}) {
    setState(() {
      _supportSurface = surface;
      _destination = _DashboardDestination.support;
    });
  }

  void _openDiagnostics() {
    _openSupport(surface: _SupportSurface.diagnostics);
  }

  void _openProfiles() {
    setState(() {
      _destination = _DashboardDestination.profiles;
    });
  }

  void _openProviders() {
    widget.controller.showProviderWorkspace();
    setState(() {
      _destination = _DashboardDestination.providers;
    });
  }

  void _returnToProviderRoot() {
    widget.controller.showProviderWorkspace();
  }

  Future<void> _openNewProviderFlow() async {
    final result = await Navigator.of(context).push<_ProviderChooserResult>(
      MaterialPageRoute<_ProviderChooserResult>(
        builder: (BuildContext context) =>
            _ProviderChooserPage(controller: widget.controller),
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    if (result.providerId != null) {
      widget.controller.resetManagedProviderDraft(
        preferredProvider: result.providerId,
      );
      return;
    }
    final preset = result.preset;
    if (preset != null) {
      widget.controller.applyPreset(preset);
    }
  }

  void _openHome() {
    setState(() {
      _destination = _DashboardDestination.home;
    });
  }

  void _openRouting() {
    setState(() {
      _destination = _DashboardDestination.routing;
    });
    unawaited(widget.controller.ensureInstalledAppsLoaded());
  }

  void _selectDestination(_DashboardDestination destination) {
    switch (destination) {
      case _DashboardDestination.routing:
        _openRouting();
        return;
      case _DashboardDestination.support:
        _openSupport(surface: _supportSurface);
        return;
      case _DashboardDestination.profiles:
        _openProfiles();
        return;
      case _DashboardDestination.providers:
        _openProviders();
        return;
      case _DashboardDestination.home:
        _openHome();
        return;
    }
  }

  void _ensurePortableImportDestination() {
    if (widget.controller.pendingPortableProfileImportEnvelope == null) {
      _portableImportRouteScheduled = false;
      return;
    }
    if (_destination != _DashboardDestination.profiles) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _destination = _DashboardDestination.profiles;
        });
      });
      return;
    }
    final route = ModalRoute.of(context);
    if (_portableImportRouteScheduled || (route != null && !route.isCurrent)) {
      return;
    }
    _portableImportRouteScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final currentRoute = ModalRoute.of(context);
      if (currentRoute != null && !currentRoute.isCurrent) {
        _portableImportRouteScheduled = false;
        return;
      }
      widget.controller.showProfileWorkspace();
      Navigator.of(context)
          .push<void>(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => _ProfileWorkspacePage(
                controller: widget.controller,
                title: context.shellText.importPortableProfile,
              ),
            ),
          )
          .whenComplete(() {
            _portableImportRouteScheduled = false;
          });
    });
  }

  _DashboardDestination _activeDestination(bool routingSupported) {
    if (_destination == _DashboardDestination.routing && !routingSupported) {
      return _DashboardDestination.home;
    }
    return _destination;
  }

  List<_DashboardDestination> _primaryDestinations({
    required bool wide,
    required bool routingSupported,
  }) {
    return <_DashboardDestination>[
      _DashboardDestination.home,
      _DashboardDestination.profiles,
      _DashboardDestination.providers,
      if (wide && routingSupported) _DashboardDestination.routing,
      _DashboardDestination.support,
    ];
  }

  Widget _buildDestinationBody(
    _DashboardDestination destination, {
    required bool compactRoutingRoute,
  }) {
    return switch (destination) {
      _DashboardDestination.home => _HomePage(
        controller: widget.controller,
        onOpenProfiles: _openProfiles,
        onOpenSupport: _openSupport,
        headerAccessory: _ShellHeaderAccessory(
          controller: widget.controller,
          onOpenDiagnostics: _openDiagnostics,
        ),
        onLaunchChallengeSurface: _launchChallengeSurface,
        openChallengeLabel: _openChallengeLabel,
        showsManualChallengeContinue: _showsManualChallengeContinue,
        onOpenVPNTransportProfileEditor: _openVPNTransportProfileEditorForMode,
      ),
      _DashboardDestination.profiles => _ProfilesPage(
        controller: widget.controller,
        onOpenRouting: _openRouting,
        headerAccessory: _ShellHeaderAccessory(
          controller: widget.controller,
          onOpenDiagnostics: _openDiagnostics,
        ),
      ),
      _DashboardDestination.providers => _ProvidersPage(
        controller: widget.controller,
        headerAccessory: _ShellHeaderAccessory(
          controller: widget.controller,
          onOpenDiagnostics: _openDiagnostics,
        ),
        onOpenNewProviderFlow: _openNewProviderFlow,
        onReturnToRoot: _returnToProviderRoot,
      ),
      _DashboardDestination.routing => _RoutingPage(
        controller: widget.controller,
        onBack: compactRoutingRoute ? _openHome : null,
        onOpenProfiles: _openProfiles,
        onOpenVPNTransportProfileEditor: _openVPNTransportProfileEditorForMode,
        headerAccessory: _ShellHeaderAccessory(
          controller: widget.controller,
          onOpenDiagnostics: _openDiagnostics,
        ),
      ),
      _DashboardDestination.support => _SupportPage(
        controller: widget.controller,
        supportSurface: _supportSurface,
        activitySurface: _activitySurface,
        diagnosticsSurface: _diagnosticsSurface,
        headerAccessory: _ShellHeaderAccessory(
          controller: widget.controller,
          onOpenDiagnostics: _openDiagnostics,
        ),
        onSupportSurfaceChanged: (_SupportSurface surface) {
          setState(() {
            _supportSurface = surface;
          });
        },
        onActivitySurfaceChanged: (_ActivitySurface surface) {
          setState(() {
            _activitySurface = surface;
          });
        },
        onDiagnosticsSurfaceChanged: (_DiagnosticsSurface surface) {
          setState(() {
            _diagnosticsSurface = surface;
          });
        },
        onLaunchChallengeSurface: _launchChallengeSurface,
        openChallengeLabel: _openChallengeLabel,
        showsManualChallengeContinue: _showsManualChallengeContinue,
      ),
    };
  }

  NavigationDestination _destinationNavItem(
    BuildContext context,
    _DashboardDestination destination,
  ) {
    return switch (destination) {
      _DashboardDestination.home => NavigationDestination(
        icon: Icon(Icons.shield_outlined),
        selectedIcon: Icon(Icons.shield),
        label: t.commonHome,
      ),
      _DashboardDestination.profiles => NavigationDestination(
        icon: Icon(Icons.folder_outlined),
        selectedIcon: Icon(Icons.folder),
        label: t.commonProfiles,
      ),
      _DashboardDestination.providers => NavigationDestination(
        icon: Icon(Icons.cloud_outlined),
        selectedIcon: Icon(Icons.cloud),
        label: t.commonProviders,
      ),
      _DashboardDestination.routing => NavigationDestination(
        icon: Icon(Icons.alt_route_outlined),
        selectedIcon: Icon(Icons.alt_route),
        label: t.commonRouting,
      ),
      _DashboardDestination.support => NavigationDestination(
        icon: Icon(Icons.support_agent_outlined),
        selectedIcon: Icon(Icons.support_agent),
        label: t.commonSupport,
      ),
    };
  }

  NavigationRailDestination _destinationRailItem(
    BuildContext context,
    _DashboardDestination destination,
  ) {
    return switch (destination) {
      _DashboardDestination.home => NavigationRailDestination(
        icon: Icon(Icons.shield_outlined),
        selectedIcon: Icon(Icons.shield),
        label: Text(t.commonHome),
      ),
      _DashboardDestination.profiles => NavigationRailDestination(
        icon: Icon(Icons.folder_outlined),
        selectedIcon: Icon(Icons.folder),
        label: Text(t.commonProfiles),
      ),
      _DashboardDestination.providers => NavigationRailDestination(
        icon: Icon(Icons.cloud_outlined),
        selectedIcon: Icon(Icons.cloud),
        label: Text(t.commonProviders),
      ),
      _DashboardDestination.routing => NavigationRailDestination(
        icon: Icon(Icons.alt_route_outlined),
        selectedIcon: Icon(Icons.alt_route),
        label: Text(t.commonRouting),
      ),
      _DashboardDestination.support => NavigationRailDestination(
        icon: Icon(Icons.support_agent_outlined),
        selectedIcon: Icon(Icons.support_agent),
        label: Text(t.commonSupport),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        _ensurePortableImportDestination();
        final width = MediaQuery.sizeOf(context).width;
        final wide = width >= _compactNavigationBreakpoint;
        final routingSupported = widget.controller.activeModeSupportsAppRouting;
        final destination = _activeDestination(routingSupported);
        final primaryDestinations = _primaryDestinations(
          wide: wide,
          routingSupported: routingSupported,
        );
        final compactRoutingRoute =
            !wide && destination == _DashboardDestination.routing;
        final body = _buildDestinationBody(
          destination,
          compactRoutingRoute: compactRoutingRoute,
        );

        if (wide) {
          final selectedIndex = primaryDestinations.indexOf(destination);
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: <Widget>[
                  NavigationRail(
                    selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (int index) {
                      _selectDestination(primaryDestinations[index]);
                    },
                    destinations: primaryDestinations
                        .map(
                          (_DashboardDestination destination) =>
                              _destinationRailItem(context, destination),
                        )
                        .toList(growable: false),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              ),
            ),
          );
        }

        final compactDestinations = primaryDestinations
            .where(
              (destination) => destination != _DashboardDestination.routing,
            )
            .toList(growable: false);
        final selectedIndex = compactDestinations.indexOf(
          compactRoutingRoute ? _DashboardDestination.home : destination,
        );
        return Scaffold(
          body: SafeArea(child: body),
          bottomNavigationBar: compactRoutingRoute
              ? null
              : NavigationBar(
                  selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
                  onDestinationSelected: (int index) {
                    _selectDestination(compactDestinations[index]);
                  },
                  destinations: compactDestinations
                      .map(
                        (_DashboardDestination destination) =>
                            _destinationNavItem(context, destination),
                      )
                      .toList(growable: false),
                ),
        );
      },
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.controller,
    required this.onOpenProfiles,
    required this.onOpenSupport,
    required this.headerAccessory,
    required this.onLaunchChallengeSurface,
    required this.openChallengeLabel,
    required this.showsManualChallengeContinue,
    required this.onOpenVPNTransportProfileEditor,
  });

  final MobileShellController controller;
  final VoidCallback onOpenProfiles;
  final void Function({_SupportSurface surface}) onOpenSupport;
  final Widget headerAccessory;
  final Future<void> Function(ChallengeRecord challenge)
  onLaunchChallengeSurface;
  final String Function(ChallengeRecord? challenge) openChallengeLabel;
  final bool Function(ChallengeRecord? challenge) showsManualChallengeContinue;
  final Future<void> Function(PlatformTunnelMode mode)
  onOpenVPNTransportProfileEditor;

  @override
  Widget build(BuildContext context) {
    final selectedProfile = _selectedProfile(controller);
    final homeChallenge = controller.activeHomeChallenge;
    final activeMode = controller.activePlatformTunnelMode;
    final activeResult = activeMode == null
        ? null
        : controller.platformTunnelResultFor(activeMode);
    final tunnelReady = activeResult?.ready == true;
    final showRuntimeCards =
        controller.profiles.isNotEmpty || tunnelReady || homeChallenge != null;
    final notice = controller.surfaceNotice;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: <Widget>[
        _PageHeader(
          title: t.mobileHomeTitle,
          subtitle: t.mobileHomeSubtitle,
          trailing: headerAccessory,
        ),
        const SizedBox(height: 12),
        HomeWorkflowBody(
          noticeMessage: notice,
          noticeAction: controller.requiresLocalStateReset
              ? HomeWorkflowAction(
                  label: context.shellText.resetLocalState,
                  style: HomeWorkflowActionStyle.outlined,
                  onPressed: controller.busy
                      ? null
                      : () => unawaited(controller.clearLocalState()),
                )
              : null,
          emptyState: controller.profiles.isEmpty
              ? _mobileHomeEmptyStateData(context, onOpenProfiles)
              : null,
          profileSummary: selectedProfile == null
              ? null
              : _mobileHomeProfileSummaryData(context, selectedProfile),
          primaryAction: showRuntimeCards
              ? _mobileHomePrimaryActionData(
                  context,
                  controller: controller,
                  hasSelectedProfile: selectedProfile != null,
                  onOpenProfiles: onOpenProfiles,
                  tunnelReady: tunnelReady,
                  challenge: homeChallenge,
                  onLaunchChallengeSurface: onLaunchChallengeSurface,
                  openChallengeLabel: openChallengeLabel,
                  showsManualChallengeContinue: showsManualChallengeContinue,
                  onOpenVPNTransportProfileEditor:
                      onOpenVPNTransportProfileEditor,
                )
              : null,
          modeSection: showRuntimeCards
              ? _mobileHomeModeSectionData(context, controller)
              : null,
          supportSection: showRuntimeCards
              ? _mobileHomeSupportSectionData(
                  context,
                  controller,
                  onOpenActivity: () =>
                      onOpenSupport(surface: _SupportSurface.activity),
                  onOpenDiagnostics: () =>
                      onOpenSupport(surface: _SupportSurface.diagnostics),
                )
              : null,
        ),
      ],
    );
  }
}

class _ProfilesPage extends StatelessWidget {
  const _ProfilesPage({
    required this.controller,
    required this.onOpenRouting,
    required this.headerAccessory,
  });

  final MobileShellController controller;
  final VoidCallback onOpenRouting;
  final Widget headerAccessory;

  void _openProfileWorkspace(
    BuildContext context, {
    required String title,
    bool resetDraft = false,
    String? profileId,
  }) {
    if (resetDraft) {
      controller.resetDraft();
    } else if (profileId != null) {
      controller.focusProfile(profileId);
    }
    controller.showProfileWorkspace();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            _ProfileWorkspacePage(controller: controller, title: title),
      ),
    );
  }

  Future<void> _showPortableExport(BuildContext context) async {
    final envelope = controller.selectedPortableProfileEnvelope();
    if (envelope == null || !context.mounted) {
      return;
    }
    await showPortableProfileExportDialog(
      context: context,
      envelope: envelope,
      onCopyText: controller.copyPortableProfileEnvelopeText,
      onShareText: controller.sharePortableProfileEnvelopeText,
      onShareFile: controller.sharePortableProfileEnvelopeFile,
    );
  }

  Future<void> _showPortableImportPreview(
    BuildContext context,
    PortableProfileEnvelope envelope,
  ) async {
    await showPortableProfileImportPreviewDialog(
      context: context,
      envelope: envelope,
      onConfirm: controller.confirmPortableProfileImport,
    );
  }

  Future<void> _importPortableFromFile(BuildContext context) async {
    final envelope = await controller.importPortableProfileEnvelopeFromFile();
    if (envelope == null || !context.mounted) {
      return;
    }
    await _showPortableImportPreview(context, envelope);
  }

  Future<void> _scanPortableQr(BuildContext context) async {
    final payload = await showPortableProfileQrScanner(context);
    if (payload == null || payload.trim().isEmpty || !context.mounted) {
      return;
    }
    final envelope = controller.previewPortableProfileEnvelope(payload);
    if (envelope == null || !context.mounted) {
      return;
    }
    await _showPortableImportPreview(context, envelope);
  }

  Future<void> _pastePortableEnvelope(BuildContext context) async {
    final envelope = await showPortableProfilePasteDialog(
      context: context,
      onPreviewImport: controller.previewPortableProfileEnvelope,
    );
    if (envelope == null || !context.mounted) {
      return;
    }
    await _showPortableImportPreview(context, envelope);
  }

  void _copySelectedProfile(BuildContext context) {
    final source = controller.focusedSavedProfile;
    if (source == null) {
      return;
    }
    controller.duplicateSelectedProfile();
    _openProfileWorkspace(context, title: context.shellText.copyProfile);
  }

  void _focusProfile(ProfileRecord profile) {
    if (controller.focusedProfileId == profile.id) {
      return;
    }
    controller.focusProfile(profile.id);
  }

  void _copyProfile(BuildContext context, ProfileRecord profile) {
    _focusProfile(profile);
    _copySelectedProfile(context);
  }

  void _exportProfile(BuildContext context, ProfileRecord profile) {
    _focusProfile(profile);
    unawaited(_showPortableExport(context));
  }

  void _deleteProfile(ProfileRecord profile) {
    _focusProfile(profile);
    unawaited(controller.deleteSelectedProfile());
  }

  @override
  Widget build(BuildContext context) {
    final wide =
        MediaQuery.sizeOf(context).width >= _compactNavigationBreakpoint;
    final notice = controller.surfaceNotice;
    final menuActions = <_CardActionEntry>[
      if (!wide && controller.activeModeSupportsAppRouting)
        _CardActionEntry(
          id: 'routing',
          label: t.mobileProfilesRouting,
          onSelected: () async {
            onOpenRouting();
          },
        ),
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _PageHeader(
                title: t.mobileProfilesTitle,
                subtitle: t.mobileProfilesSubtitle,
              ),
            ),
            const SizedBox(width: 8),
            headerAccessory,
            const SizedBox(width: 12),
            _ActionOverflowButton(
              tooltip: t.mobileProfilesActionsTooltip,
              enabled: !controller.busy,
              actions: menuActions,
            ),
          ],
        ),
        if (notice != null) ...<Widget>[
          const SizedBox(height: 12),
          _NoticeBanner(message: notice),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            FilledButton.icon(
              key: const ValueKey<String>('profiles-new-button'),
              onPressed: controller.busy
                  ? null
                  : () => _openProfileWorkspace(
                      context,
                      title: t.mobileProfilesAddProfile,
                      resetDraft: true,
                    ),
              icon: const Icon(Icons.add),
              label: Text(t.mobileProfilesAddProfile),
            ),
            PopupMenuButton<_ProfileImportAction>(
              key: const ValueKey<String>('profiles-import-button'),
              enabled: !controller.busy,
              onSelected: (_ProfileImportAction action) {
                switch (action) {
                  case _ProfileImportAction.file:
                    unawaited(_importPortableFromFile(context));
                  case _ProfileImportAction.qr:
                    unawaited(_scanPortableQr(context));
                  case _ProfileImportAction.paste:
                    unawaited(_pastePortableEnvelope(context));
                }
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<_ProfileImportAction>>[
                    PopupMenuItem<_ProfileImportAction>(
                      value: _ProfileImportAction.file,
                      child: Text(context.shellText.importFromFile),
                    ),
                    PopupMenuItem<_ProfileImportAction>(
                      value: _ProfileImportAction.qr,
                      child: Text(context.shellText.scanPortableProfileQr),
                    ),
                    PopupMenuItem<_ProfileImportAction>(
                      value: _ProfileImportAction.paste,
                      child: Text(context.shellText.pasteEnvelope),
                    ),
                  ],
              child: IgnorePointer(
                child: FilledButton.tonalIcon(
                  onPressed: controller.busy ? null : () {},
                  icon: const Icon(Icons.move_to_inbox_outlined),
                  label: Text(context.shellText.importPortableProfile),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _ProfilesListSection(
          controller: controller,
          onEditProfile: (ProfileRecord profile) => _openProfileWorkspace(
            context,
            title: context.shellText.mobileEditProfile,
            profileId: profile.id,
          ),
          onCopyProfile: (ProfileRecord profile) =>
              _copyProfile(context, profile),
          onExportProfile: (ProfileRecord profile) =>
              _exportProfile(context, profile),
          onDeleteProfile: _deleteProfile,
        ),
      ],
    );
  }
}

class _ProfilesListSection extends StatelessWidget {
  const _ProfilesListSection({
    required this.controller,
    required this.onEditProfile,
    required this.onCopyProfile,
    required this.onExportProfile,
    required this.onDeleteProfile,
  });

  final MobileShellController controller;
  final ValueChanged<ProfileRecord> onEditProfile;
  final ValueChanged<ProfileRecord> onCopyProfile;
  final ValueChanged<ProfileRecord> onExportProfile;
  final ValueChanged<ProfileRecord> onDeleteProfile;

  @override
  Widget build(BuildContext context) {
    return workflow.SavedProfilesLibrarySurface(
      variant: workflow.WorkflowLibrarySurfaceVariant.mobile,
      profiles: controller.profiles,
      activeProfileId: controller.focusedProfileId,
      emptyState: workflow.WorkflowEmptyStateData(
        title: t.mobileProfilesEmptyTitle,
        message: t.mobileProfilesEmptyMessage,
      ),
      itemBuilder: (BuildContext context, ProfileRecord profile, bool active) {
        return _ProfileListItem(
          profile: profile,
          focused: active,
          busy: controller.busy,
          currentForHome: controller.selectedProfileId == profile.id,
          onSelect: () => controller.focusProfile(profile.id),
          onEdit: () => onEditProfile(profile),
          onCopy: () => onCopyProfile(profile),
          onMakeCurrent: () => controller.makeProfileCurrent(profile.id),
          onExport: () => onExportProfile(profile),
          onDelete: () => onDeleteProfile(profile),
        );
      },
    );
  }
}

class _ProfileListItem extends StatelessWidget {
  const _ProfileListItem({
    required this.profile,
    required this.focused,
    required this.busy,
    required this.currentForHome,
    required this.onSelect,
    required this.onEdit,
    required this.onCopy,
    required this.onMakeCurrent,
    required this.onExport,
    required this.onDelete,
  });

  final ProfileRecord profile;
  final bool focused;
  final bool busy;
  final bool currentForHome;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onMakeCurrent;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = profile.name.trim().isEmpty
        ? profile.id
        : profile.name.trim();
    return _SelectableListRow(
      selected: focused,
      tile: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        onTap: onSelect,
        leading: CircleAvatar(
          backgroundColor: focused
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          foregroundColor: focused
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurfaceVariant,
          child: Text(_profileInitials(profile)),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 4),
            Text(
              _profileSummary(context, profile),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (currentForHome) ...<Widget>[
              const SizedBox(height: 8),
              _StatusChip(
                label: context.shellText.mobileSelectedForHome,
                accent: true,
              ),
            ],
          ],
        ),
      ),
      actions: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final density = _inlineActionDensityForWidth(constraints.maxWidth);
          final overflowActions = <_CardActionEntry>[
            if (!currentForHome)
              _CardActionEntry(
                id: 'profiles-make-current-button',
                label: context.shellText.makeCurrent,
                onSelected: () async => onMakeCurrent(),
              ),
            _CardActionEntry(
              id: 'profiles-export-button',
              label: context.shellText.exportSavedProfile,
              onSelected: () async => onExport(),
            ),
            _CardActionEntry(
              id: 'profiles-delete-button',
              label: context.shellText.deleteProfile,
              onSelected: () async => onDelete(),
            ),
          ];
          final inlineActions = <_InlineActionDescriptor>[
            _InlineActionDescriptor(
              id: 'profiles-edit-button',
              label: context.shellText.mobileEditProfile,
              icon: Icons.edit_outlined,
              onPressed: onEdit,
              variant: _InlineActionVariant.filledTonal,
            ),
            if (density != _InlineActionDensity.compact)
              _InlineActionDescriptor(
                id: 'profiles-copy-button',
                label: context.shellText.copyProfile,
                icon: Icons.content_copy_outlined,
                onPressed: onCopy,
                variant: _InlineActionVariant.outlined,
              ),
            if (!currentForHome && density == _InlineActionDensity.wide)
              _InlineActionDescriptor(
                id: 'profiles-make-current-button',
                label: context.shellText.makeCurrent,
                icon: Icons.home_outlined,
                onPressed: onMakeCurrent,
                variant: _InlineActionVariant.outlined,
              ),
          ];
          if (density == _InlineActionDensity.wide) {
            overflowActions.removeWhere(
              (_CardActionEntry action) =>
                  action.id == 'profiles-make-current-button',
            );
          }
          final actionPlan = _planInlineActions(
            context: context,
            maxWidth: constraints.maxWidth,
            inlineActions: inlineActions,
            overflowActions: overflowActions,
          );
          return _InlineActionStrip(
            busy: busy,
            overflowTooltip: MaterialLocalizations.of(context).showMenuTooltip,
            overflowKey: const ValueKey<String>('profiles-actions-overflow'),
            inlineActions: actionPlan.inlineActions,
            overflowActions: actionPlan.overflowActions,
          );
        },
      ),
    );
  }
}

_InlineActionDensity _inlineActionDensityForWidth(double width) {
  if (width < 520) {
    return _InlineActionDensity.compact;
  }
  if (width < 860) {
    return _InlineActionDensity.medium;
  }
  return _InlineActionDensity.wide;
}

const double _inlineActionSpacing = 10;
const double _inlineActionOverflowWidth = 48;
const double _inlineActionHorizontalPadding = 32;
const double _inlineActionIconWidth = 18;
const double _inlineActionIconGap = 8;
const double _inlineActionSafetyMargin = 32;

class _InlineActionDescriptor {
  const _InlineActionDescriptor({
    required this.id,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.variant,
  });

  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final _InlineActionVariant variant;

  _CardActionEntry toOverflowAction() {
    return _CardActionEntry(
      id: id,
      label: label,
      onSelected: () async => onPressed(),
    );
  }
}

class _InlineActionPlan {
  const _InlineActionPlan({
    required this.inlineActions,
    required this.overflowActions,
  });

  final List<_InlineActionDescriptor> inlineActions;
  final List<_CardActionEntry> overflowActions;
}

_InlineActionPlan _planInlineActions({
  required BuildContext context,
  required double maxWidth,
  required List<_InlineActionDescriptor> inlineActions,
  required List<_CardActionEntry> overflowActions,
}) {
  final visibleActions = <_InlineActionDescriptor>[];
  final hiddenActions = <_CardActionEntry>[...overflowActions];
  var usedWidth = 0.0;
  for (var index = 0; index < inlineActions.length; index += 1) {
    final action = inlineActions[index];
    final actionWidth = _estimateInlineActionWidth(context, action);
    final spacingBefore = visibleActions.isEmpty ? 0.0 : _inlineActionSpacing;
    final actionsRemaining = inlineActions.length - index - 1;
    final needsOverflowAfterThis =
        hiddenActions.isNotEmpty || actionsRemaining > 0;
    final reservedOverflowWidth = needsOverflowAfterThis
        ? (visibleActions.isEmpty
              ? _inlineActionOverflowWidth
              : _inlineActionSpacing + _inlineActionOverflowWidth)
        : 0.0;
    final nextUsedWidth =
        usedWidth + spacingBefore + actionWidth + reservedOverflowWidth;
    final forceInline = visibleActions.isEmpty;
    if (forceInline || nextUsedWidth <= maxWidth) {
      visibleActions.add(action);
      usedWidth += spacingBefore + actionWidth;
      continue;
    }
    hiddenActions.add(action.toOverflowAction());
  }
  return _InlineActionPlan(
    inlineActions: visibleActions,
    overflowActions: hiddenActions,
  );
}

double _estimateInlineActionWidth(
  BuildContext context,
  _InlineActionDescriptor action,
) {
  final textPainter = TextPainter(
    text: TextSpan(
      text: action.label,
      style: Theme.of(context).textTheme.labelLarge,
    ),
    maxLines: 1,
    textDirection: Directionality.of(context),
  )..layout();
  return textPainter.width +
      _inlineActionHorizontalPadding +
      _inlineActionIconWidth +
      _inlineActionIconGap +
      _inlineActionSafetyMargin;
}

class _InlineActionStrip extends StatelessWidget {
  const _InlineActionStrip({
    required this.busy,
    required this.overflowTooltip,
    required this.overflowKey,
    required this.inlineActions,
    required this.overflowActions,
  });

  final bool busy;
  final String overflowTooltip;
  final ValueKey<String> overflowKey;
  final List<_InlineActionDescriptor> inlineActions;
  final List<_CardActionEntry> overflowActions;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      for (var index = 0; index < inlineActions.length; index += 1) ...<Widget>[
        if (index > 0) const SizedBox(width: _inlineActionSpacing),
        _buildInlineActionButton(inlineActions[index]),
      ],
      if (overflowActions.isNotEmpty) ...<Widget>[
        if (inlineActions.isNotEmpty)
          const SizedBox(width: _inlineActionSpacing),
        _ActionOverflowButton(
          key: overflowKey,
          tooltip: overflowTooltip,
          enabled: !busy,
          actions: overflowActions,
        ),
      ],
    ];
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _buildInlineActionButton(_InlineActionDescriptor action) {
    return switch (action.variant) {
      _InlineActionVariant.filledTonal => FilledButton.tonalIcon(
        key: ValueKey<String>(action.id),
        onPressed: busy ? null : action.onPressed,
        icon: Icon(action.icon),
        label: Text(action.label),
      ),
      _InlineActionVariant.outlined => OutlinedButton.icon(
        key: ValueKey<String>(action.id),
        onPressed: busy ? null : action.onPressed,
        icon: Icon(action.icon),
        label: Text(action.label),
      ),
    };
  }
}

class _SelectableListRow extends StatelessWidget {
  const _SelectableListRow({
    required this.selected,
    required this.tile,
    this.actions,
  });

  final bool selected;
  final Widget tile;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          tile,
          if (selected && actions != null) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: actions!,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileWorkspacePage extends StatelessWidget {
  const _ProfileWorkspacePage({required this.controller, required this.title});

  final MobileShellController controller;
  final String title;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final notice = controller.surfaceNotice;
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              if (notice != null) ...<Widget>[
                _NoticeBanner(message: notice),
                const SizedBox(height: 12),
              ],
              ProfileEditorPanel(
                key: const ValueKey<String>('profile-workspace-editor'),
                profiles: controller.profiles,
                providerDescriptors: controller.providerDescriptors,
                managedProviders: controller.managedProviders,
                initialManagedProviderId:
                    controller.draft.providerBinding.managedProviderId,
                selectedProfileId: controller.focusedProfileId,
                draft: controller.draft,
                busy: controller.busy,
                onSelectProfile: controller.focusProfile,
                onDraftChanged: controller.updateDraft,
                onActivateManagedProviderMode:
                    controller.activateManagedProviderMode,
                onUseCustomProvider: controller.useCustomProviderForDraft,
                onSave: controller.saveDraft,
                onDelete: controller.deleteSelectedProfile,
                onReset: controller.resetDraft,
                onResolve: controller.startResolutionFromDraft,
                onStart: controller.startSelectedProfile,
                onPreparePortableExport:
                    controller.selectedPortableProfileEnvelope,
                onCopyPortableExportText:
                    controller.copyPortableProfileEnvelopeText,
                onSharePortableExportText:
                    controller.sharePortableProfileEnvelopeText,
                onSharePortableExportFile:
                    controller.sharePortableProfileEnvelopeFile,
                onImportPortableFromFile:
                    controller.importPortableProfileEnvelopeFromFile,
                onPreviewPortableImport:
                    controller.previewPortableProfileEnvelope,
                onConfirmPortableImport:
                    controller.confirmPortableProfileImport,
                pendingPortableImportEnvelope:
                    controller.pendingPortableProfileImportEnvelope,
                onPendingPortableImportHandled:
                    controller.clearPendingPortableProfileImportPreview,
                showTitleBar: false,
                showSavedProfilesSection: false,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VPNTransportProfileManagerPage extends StatelessWidget {
  const _VPNTransportProfileManagerPage({
    required this.controller,
    required this.mode,
  });

  final MobileShellController controller;
  final PlatformTunnelMode mode;

  Future<void> _openEditor(
    BuildContext context, {
    TransportProfileStatus? existingProfile,
    bool createNew = false,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => _VPNTransportProfileEditorPage(
          controller: controller,
          mode: mode,
          existingProfile: existingProfile,
          createNew: createNew,
        ),
      ),
    );
  }

  Future<void> _showPortableExport(
    BuildContext context,
    TransportProfileStatus profile,
  ) async {
    final capability = controller.portableTransportProfileTransferCapability;
    if (capability == null) {
      return;
    }
    String? errorText;
    while (context.mounted) {
      final passphrase = await showPortableTransportProfilePassphraseDialog(
        context: context,
        title: context.shellText.exportPortableProfile,
        actionLabel: 'Prepare export',
        errorText: errorText,
        message:
            'Encrypt this VPN transport profile before copying, sharing, or rendering it as a QR payload.',
      );
      if (passphrase == null || !context.mounted) {
        return;
      }
      if (passphrase.isEmpty) {
        errorText = 'Passphrase is required.';
        continue;
      }
      final carriage = await controller.exportPortableVPNTransportProfileRecord(
        profile,
        passphrase: passphrase,
      );
      if (carriage == null || !context.mounted) {
        return;
      }
      await showPortableTransportProfileExportDialog(
        context: context,
        carriage: carriage,
        capability: capability,
        onCopyText: () =>
            controller.copyPortableVPNTransportProfileEnvelopeText(carriage),
        onShareText: () =>
            controller.sharePortableVPNTransportProfileEnvelopeText(carriage),
        onShareFile: () =>
            controller.sharePortableVPNTransportProfileEnvelopeFile(carriage),
      );
      return;
    }
  }

  Future<void> _showPortableImportPreview(
    BuildContext context,
    String payload,
  ) async {
    String? errorText;
    while (context.mounted) {
      final passphrase = await showPortableTransportProfilePassphraseDialog(
        context: context,
        title: context.shellText.importPortableProfile,
        actionLabel: context.shellText.previewImport,
        errorText: errorText,
        message:
            'Enter the passphrase that protects this portable VPN transport-profile envelope.',
      );
      if (passphrase == null || !context.mounted) {
        return;
      }
      if (passphrase.isEmpty) {
        errorText = 'Passphrase is required.';
        continue;
      }
      final preview = await controller.previewPortableVPNTransportProfileImport(
        envelope: payload,
        passphrase: passphrase,
      );
      if (preview == null || !context.mounted) {
        return;
      }
      if (preview.outcome ==
              TransportProfilePortableTransferPreviewOutcome.blocked &&
          preview.blockedReason ==
              TransportProfilePortableTransferBlockedReason.wrongPassphrase) {
        errorText = 'Wrong passphrase.';
        continue;
      }
      await showPortableTransportProfileImportPreviewDialog(
        context: context,
        preview: preview,
        onConfirm:
            preview.outcome ==
                TransportProfilePortableTransferPreviewOutcome.importable
            ? () => controller.confirmPortableVPNTransportProfileImport(
                envelope: payload,
                passphrase: passphrase,
              )
            : null,
      );
      return;
    }
  }

  Future<void> _importPortable(BuildContext context) async {
    final source = await showPortableTransportProfileImportSourceDialog(
      context: context,
    );
    if (source == null || !context.mounted) {
      return;
    }
    final payload = switch (source) {
      PortableTransportProfileImportSource.file =>
        await controller.openPortableVPNTransportProfileEnvelopeText(),
      PortableTransportProfileImportSource.paste =>
        await showPortableTransportProfilePasteDialog(context: context),
      PortableTransportProfileImportSource.scanQr =>
        await showPortableTransportProfileQrScanner(context),
    };
    if (payload == null || payload.trim().isEmpty || !context.mounted) {
      return;
    }
    await _showPortableImportPreview(context, payload.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final schema = controller.vpnTransportProfileEditorSchemaForMode(mode);
        final notice = controller.surfaceNotice;
        return Scaffold(
          key: const ValueKey<String>('vpn-transport-profile-manager-route'),
          appBar: AppBar(title: const Text('VPN transport profiles')),
          body: SafeArea(
            child: ListView(
              padding: _vpnTransportProfileRoutePadding(context),
              children: <Widget>[
                if (notice != null) ...<Widget>[
                  _NoticeBanner(message: notice),
                  const SizedBox(height: 12),
                ],
                VPNTransportProfileManagerSurface(
                  key: const ValueKey<String>(
                    'mobile-vpn-transport-profiles-route',
                  ),
                  variant: VPNTransportProfileEditorVariant.mobile,
                  layout: VPNTransportProfileSurfaceLayout.page,
                  profiles: controller.vpnTransportProfilesForMode(mode),
                  requiredKinds: controller
                      .vpnTransportProfileRequiredKindsForMode(mode),
                  executionPlan: controller
                      .vpnTransportProfileExecutionPlanForMode(mode),
                  onCreate: schema?.supportsStructuredCreate == true
                      ? () => _openEditor(context, createNew: true)
                      : null,
                  onImport:
                      controller.canConfigureVPNTransportProfileForMode(mode)
                      ? () => controller.importVPNTransportProfileForMode(mode)
                      : null,
                  onImportPortable:
                      controller.canImportPortableVPNTransportProfileForMode(
                        mode,
                      )
                      ? () => _importPortable(context)
                      : null,
                  onEdit: (TransportProfileStatus profile) =>
                      _openEditor(context, existingProfile: profile),
                  onExportPortable: (TransportProfileStatus profile) =>
                      _showPortableExport(context, profile),
                  onValidate: controller.validateVPNTransportProfileRecord,
                  onForget: controller.forgetVPNTransportProfileRecord,
                  onSelect: (TransportProfileStatus profile) => controller
                      .selectVPNTransportProfileForMode(mode, profile),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VPNTransportProfileEditorPage extends StatelessWidget {
  const _VPNTransportProfileEditorPage({
    required this.controller,
    required this.mode,
    this.existingProfile,
    this.createNew = false,
  });

  final MobileShellController controller;
  final PlatformTunnelMode mode;
  final TransportProfileStatus? existingProfile;
  final bool createNew;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final schema = controller.vpnTransportProfileEditorSchemaForMode(mode);
        if (schema == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('VPN transport profiles')),
            body: const SafeArea(child: SizedBox.shrink()),
          );
        }
        final existing = createNew
            ? null
            : existingProfile ??
                  controller.vpnTransportProfileStatusForMode(mode);
        final editorMode = existing == null
            ? VPNTransportProfileEditorMode.create
            : VPNTransportProfileEditorMode.edit;
        return Scaffold(
          key: const ValueKey<String>('vpn-transport-profile-editor-route'),
          appBar: AppBar(
            title: Text(
              editorMode == VPNTransportProfileEditorMode.create
                  ? 'Create VPN profile'
                  : 'Edit VPN profile',
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: VPNTransportProfileEditorSurface(
                variant: VPNTransportProfileEditorVariant.mobile,
                layout: VPNTransportProfileSurfaceLayout.page,
                contentPadding: _vpnTransportProfileRoutePadding(context),
                mode: editorMode,
                schema: schema,
                existingProfile: existing,
                defaultFor: controller.vpnTransportProfileExecutionPlanForMode(
                  mode,
                ),
                onValidate:
                    (TransportProfileStructuredValidationRequest request) {
                      return controller
                          .validateStructuredVPNTransportProfileForMode(
                            mode,
                            request,
                          );
                    },
                onSave: (TransportProfileStructuredDraft draft) {
                  return controller.saveStructuredVPNTransportProfileForMode(
                    mode,
                    draft,
                    existingProfile: existingProfile,
                    createNew: createNew,
                  );
                },
                onCancel: () => Navigator.of(context).pop(),
                onImportFallback:
                    controller.canConfigureVPNTransportProfileForMode(mode)
                    ? () {
                        Navigator.of(context).pop();
                        unawaited(
                          controller.importVPNTransportProfileForMode(mode),
                        );
                      }
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

EdgeInsets _vpnTransportProfileRoutePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= _compactNavigationBreakpoint) {
    return const EdgeInsets.fromLTRB(32, 20, 32, 28);
  }
  return const EdgeInsets.fromLTRB(16, 12, 16, 20);
}

class _ProvidersPage extends StatefulWidget {
  const _ProvidersPage({
    required this.controller,
    required this.headerAccessory,
    required this.onOpenNewProviderFlow,
    required this.onReturnToRoot,
  });

  final MobileShellController controller;
  final Widget headerAccessory;
  final Future<void> Function() onOpenNewProviderFlow;
  final VoidCallback onReturnToRoot;

  @override
  State<_ProvidersPage> createState() => _ProvidersPageState();
}

class _ProvidersPageState extends State<_ProvidersPage> {
  _ProviderRootSurface _surface = _ProviderRootSurface.savedProviders;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final notice = controller.surfaceNotice;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final wide = constraints.maxWidth >= _providerListDetailBreakpoint;
        final showingDetail =
            controller.workflowSurface ==
                MobileWorkflowSurface.providerConfig ||
            controller.workflowSurface ==
                MobileWorkflowSurface.providerTemplate;
        final detailPanel = switch (controller.workflowSurface) {
          MobileWorkflowSurface.providerConfig => ProviderConfigEditorPanel(
            key: const ValueKey<String>('provider-config-editor-panel'),
            supportedProviders: controller.supportedProviderCatalog,
            providerDescriptors: controller.providerDescriptors,
            selectedManagedProviderId: controller.selectedManagedProviderId,
            draft: controller.managedProviderDraft,
            busy: controller.busy,
            onDraftChanged: controller.updateManagedProviderDraft,
            onSave: controller.saveManagedProviderDraft,
            onSaveAsTemplate:
                controller.startProviderTemplateDraftFromManagedProvider,
            onDelete: controller.deleteSelectedManagedProvider,
            onApplyToProfileDraft: controller.useManagedProviderForDraft,
            onClose: widget.onReturnToRoot,
            showCloseButton: wide,
          ),
          MobileWorkflowSurface.providerTemplate => ProviderTemplateEditorPanel(
            key: const ValueKey<String>('provider-template-editor-panel'),
            supportedProviders: controller.supportedProviderCatalog,
            providerDescriptors: controller.providerDescriptors,
            selectedProviderTemplateId: controller.selectedProviderTemplateId,
            draft: controller.providerTemplateDraft,
            busy: controller.busy,
            onDraftChanged: controller.updateProviderTemplateDraft,
            onSave: controller.saveProviderTemplateDraft,
            onDelete: controller.deleteSelectedProviderTemplate,
            onUseTemplate: controller.useProviderTemplate,
            onClose: widget.onReturnToRoot,
            showCloseButton: wide,
          ),
          _ => const SizedBox.shrink(),
        };
        final rootPanel = _surface == _ProviderRootSurface.savedProviders
            ? _ProviderRecordsRootSection(controller: controller)
            : _TemplateRecordsRootSection(controller: controller);
        final rootChildren = <Widget>[
          _PageHeader(
            title: context.shellText.mobileProvidersTitle,
            subtitle: context.shellText.mobileProvidersSubtitle,
            trailing: widget.headerAccessory,
          ),
          if (notice != null) ...<Widget>[
            const SizedBox(height: 12),
            _NoticeBanner(message: notice),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              ChoiceChip(
                key: const ValueKey<String>('providers-surface-saved'),
                selected: _surface == _ProviderRootSurface.savedProviders,
                label: Text(context.shellText.savedProviders),
                onSelected: (_) {
                  setState(() {
                    _surface = _ProviderRootSurface.savedProviders;
                  });
                  widget.onReturnToRoot();
                },
              ),
              ChoiceChip(
                key: const ValueKey<String>('providers-surface-templates'),
                selected: _surface == _ProviderRootSurface.templates,
                label: Text(context.shellText.templates),
                onSelected: (_) {
                  setState(() {
                    _surface = _ProviderRootSurface.templates;
                  });
                  widget.onReturnToRoot();
                },
              ),
              FilledButton.icon(
                key: const ValueKey<String>('managed-provider-create-button'),
                onPressed: controller.busy
                    ? null
                    : () => unawaited(widget.onOpenNewProviderFlow()),
                icon: const Icon(Icons.add),
                label: Text(context.shellText.mobileAddProvider),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ProviderSourceCatalogSurface(
            sources: controller.providerSources,
            compact: true,
          ),
          const SizedBox(height: 20),
          rootPanel,
        ];

        if (wide && showingDetail) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Flexible(
                  flex: 5,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: rootChildren,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  flex: 7,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 840),
                      child: detailPanel,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (showingDetail) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runAlignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    OutlinedButton.icon(
                      key: const ValueKey<String>('providers-back-button'),
                      onPressed: widget.onReturnToRoot,
                      icon: const Icon(Icons.arrow_back),
                      label: Text(context.shellText.mobileBackToProviders),
                    ),
                    widget.headerAccessory,
                  ],
                ),
                if (notice != null) ...<Widget>[
                  const SizedBox(height: 12),
                  _NoticeBanner(message: notice),
                ],
                const SizedBox(height: 16),
                Expanded(
                  key: const ValueKey<String>('providers-detail-slot'),
                  child: detailPanel,
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: rootChildren,
        );
      },
    );
  }
}

String _profileInitials(ProfileRecord profile) {
  final source = profile.name.trim().isEmpty
      ? profile.spec.provider.trim()
      : profile.name.trim();
  if (source.isEmpty) {
    return '?';
  }
  return source.characters.first.toUpperCase();
}

String _profileSummary(BuildContext context, ProfileRecord profile) {
  final provider = profile.spec.provider.trim().isEmpty
      ? context.shellText.mobileNoProvider
      : profile.spec.provider.trim();
  final link = profile.spec.link.trim();
  if (link.isEmpty) {
    return provider;
  }
  final uri = Uri.tryParse(link);
  if (uri == null || uri.host.isEmpty) {
    return '$provider • ${context.shellText.mobileInputConfigured}';
  }
  final pathPreview = switch (uri.pathSegments.length) {
    0 => '',
    1 => '/${uri.pathSegments.first}',
    _ => '/${uri.pathSegments[0]}/${uri.pathSegments[1]}/...',
  };
  return '$provider • ${uri.host}$pathPreview';
}

class _SupportPage extends StatelessWidget {
  const _SupportPage({
    required this.controller,
    required this.supportSurface,
    required this.activitySurface,
    required this.diagnosticsSurface,
    required this.headerAccessory,
    required this.onSupportSurfaceChanged,
    required this.onActivitySurfaceChanged,
    required this.onDiagnosticsSurfaceChanged,
    required this.onLaunchChallengeSurface,
    required this.openChallengeLabel,
    required this.showsManualChallengeContinue,
  });

  final MobileShellController controller;
  final _SupportSurface supportSurface;
  final _ActivitySurface activitySurface;
  final _DiagnosticsSurface diagnosticsSurface;
  final Widget headerAccessory;
  final ValueChanged<_SupportSurface> onSupportSurfaceChanged;
  final ValueChanged<_ActivitySurface> onActivitySurfaceChanged;
  final ValueChanged<_DiagnosticsSurface> onDiagnosticsSurfaceChanged;
  final Future<void> Function(ChallengeRecord challenge)
  onLaunchChallengeSurface;
  final String Function(ChallengeRecord? challenge) openChallengeLabel;
  final bool Function(ChallengeRecord? challenge) showsManualChallengeContinue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final shellWide =
            MediaQuery.sizeOf(context).width >= _compactNavigationBreakpoint;
        final wide = shellWide && constraints.maxWidth >= 760;
        if (!wide) {
          return _buildCompact(context);
        }
        return _buildWide(context, constraints.maxWidth);
      },
    );
  }

  Widget _buildCompact(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: const ValueKey<String>('support-compact-scroll'),
      padding: EdgeInsets.zero,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _PageHeader(
                title: context.shellText.supportTitle,
                subtitle: context.shellText.supportSubtitle,
                trailing: headerAccessory,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  ChoiceChip(
                    selected: supportSurface == _SupportSurface.activity,
                    label: Text(
                      context.shellText.activity,
                      style: theme.textTheme.labelLarge,
                    ),
                    onSelected: (_) =>
                        onSupportSurfaceChanged(_SupportSurface.activity),
                  ),
                  ChoiceChip(
                    selected: supportSurface == _SupportSurface.diagnostics,
                    label: Text(
                      context.shellText.diagnostics,
                      style: theme.textTheme.labelLarge,
                    ),
                    onSelected: (_) =>
                        onSupportSurfaceChanged(_SupportSurface.diagnostics),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _EmbeddedBrowserStateCard(controller: controller),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: _compactSupportSurfaceHeight(context),
          child: switch (supportSurface) {
            _SupportSurface.activity => _ActivityPage(
              controller: controller,
              surface: activitySurface,
              onLaunchChallengeSurface: onLaunchChallengeSurface,
              openChallengeLabel: openChallengeLabel,
              showsManualChallengeContinue: showsManualChallengeContinue,
              onSurfaceChanged: onActivitySurfaceChanged,
              showHeader: false,
            ),
            _SupportSurface.diagnostics => _DiagnosticsPage(
              controller: controller,
              surface: diagnosticsSurface,
              onSurfaceChanged: onDiagnosticsSurfaceChanged,
              showHeader: false,
            ),
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildWide(BuildContext context, double maxWidth) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PageHeader(
            title: context.shellText.supportTitle,
            subtitle: context.shellText.supportSubtitle,
            trailing: headerAccessory,
          ),
          const SizedBox(height: 14),
          _SupportContextStrip(controller: controller),
          const SizedBox(height: 14),
          _SupportWideToolbar(
            controller: controller,
            supportSurface: supportSurface,
            onSupportSurfaceChanged: onSupportSurfaceChanged,
            activitySurface: activitySurface,
            onActivitySurfaceChanged: (_ActivitySurface surface) {
              onActivitySurfaceChanged(surface);
              onSupportSurfaceChanged(_SupportSurface.activity);
            },
            diagnosticsSurface: diagnosticsSurface,
            onDiagnosticsSurfaceChanged: onDiagnosticsSurfaceChanged,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: switch (supportSurface) {
              _SupportSurface.activity => _ActivityPage(
                controller: controller,
                surface: activitySurface,
                onLaunchChallengeSurface: onLaunchChallengeSurface,
                openChallengeLabel: openChallengeLabel,
                showsManualChallengeContinue: showsManualChallengeContinue,
                onSurfaceChanged: onActivitySurfaceChanged,
                showHeader: false,
                showSurfaceSelector: false,
              ),
              _SupportSurface.diagnostics => _SupportDiagnosticsWorkspace(
                controller: controller,
                surface: diagnosticsSurface,
                onSurfaceChanged: onDiagnosticsSurfaceChanged,
              ),
            },
          ),
        ],
      ),
    );
  }
}

double _compactSupportSurfaceHeight(BuildContext context) {
  final scaledHeight = MediaQuery.sizeOf(context).height * 0.52;
  if (scaledHeight < 440) {
    return 440;
  }
  if (scaledHeight > 560) {
    return 560;
  }
  return scaledHeight;
}

class _EmbeddedBrowserStateCard extends StatelessWidget {
  const _EmbeddedBrowserStateCard({required this.controller});

  final MobileShellController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.cookie_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.shellText.embeddedBrowserStateTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.shellText.embeddedBrowserStateBody,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.shellText.embeddedBrowserStateHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                key: const ValueKey<String>('forget-embedded-sign-in-button'),
                onPressed: controller.busy
                    ? null
                    : () =>
                          unawaited(controller.clearRememberedEmbeddedSignIn()),
                icon: const Icon(Icons.logout_rounded),
                label: Text(context.shellText.forgetEmbeddedSignIn),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportContextStrip extends StatelessWidget {
  const _SupportContextStrip({required this.controller});

  final MobileShellController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedProfile = controller.selectedSavedProfile;
    final profileName = selectedProfile?.name.trim().isNotEmpty == true
        ? selectedProfile!.name
        : selectedProfile?.id ?? '—';
    final hostTone = _hostIndicatorTone(context, controller);
    final hostPalette = context.shellVisuals.tone(hostTone.$2);
    final hostDetail =
        controller.hostStatusMessage ??
        controller.hostConnection?.description ??
        context.shellText.waitingForMobileHostBridge;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _SupportContextBadge(
          icon: hostTone.$3,
          accentColor: hostPalette.accent,
          label: hostTone.$1,
          value: hostDetail,
        ),
        _SupportContextBadge(
          icon: Icons.account_circle_outlined,
          accentColor: theme.colorScheme.primary,
          label: context.shellText.currentProfile,
          value: profileName,
        ),
      ],
    );
  }
}

class _SupportContextBadge extends StatelessWidget {
  const _SupportContextBadge({
    required this.icon,
    required this.accentColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color accentColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: accentColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportWideToolbar extends StatelessWidget {
  const _SupportWideToolbar({
    required this.supportSurface,
    required this.onSupportSurfaceChanged,
    required this.activitySurface,
    required this.onActivitySurfaceChanged,
    required this.diagnosticsSurface,
    required this.onDiagnosticsSurfaceChanged,
    required this.controller,
  });

  final _SupportSurface supportSurface;
  final ValueChanged<_SupportSurface> onSupportSurfaceChanged;
  final _ActivitySurface activitySurface;
  final ValueChanged<_ActivitySurface> onActivitySurfaceChanged;
  final _DiagnosticsSurface diagnosticsSurface;
  final ValueChanged<_DiagnosticsSurface> onDiagnosticsSurfaceChanged;
  final MobileShellController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _SupportToolbarChip(
          selected: supportSurface == _SupportSurface.activity,
          label: context.shellText.activity,
          tone: _SupportToolbarChipTone.primary,
          onPressed: () => onSupportSurfaceChanged(_SupportSurface.activity),
        ),
        _SupportToolbarChip(
          selected: supportSurface == _SupportSurface.diagnostics,
          label: context.shellText.diagnostics,
          tone: _SupportToolbarChipTone.secondary,
          onPressed: () => onSupportSurfaceChanged(_SupportSurface.diagnostics),
        ),
        const SizedBox(width: 4),
        if (supportSurface == _SupportSurface.activity) ...<Widget>[
          _SupportToolbarChip(
            selected: activitySurface == _ActivitySurface.resolutions,
            label: context.shellText.resolutionsCount(
              controller.resolutions.length,
            ),
            tone: _SupportToolbarChipTone.primary,
            onPressed: () =>
                onActivitySurfaceChanged(_ActivitySurface.resolutions),
          ),
          _SupportToolbarChip(
            selected: activitySurface == _ActivitySurface.sessions,
            label: context.shellText.sessionsCount(controller.sessions.length),
            tone: _SupportToolbarChipTone.primary,
            onPressed: () =>
                onActivitySurfaceChanged(_ActivitySurface.sessions),
          ),
        ] else ...<Widget>[
          _SupportToolbarChip(
            selected: diagnosticsSurface == _DiagnosticsSurface.overview,
            label: context.shellText.overview,
            tone: _SupportToolbarChipTone.secondary,
            onPressed: () =>
                onDiagnosticsSurfaceChanged(_DiagnosticsSurface.overview),
          ),
          _SupportToolbarChip(
            selected: diagnosticsSurface == _DiagnosticsSurface.events,
            label: context.shellText.eventsCount(controller.events.length),
            tone: _SupportToolbarChipTone.secondary,
            onPressed: () =>
                onDiagnosticsSurfaceChanged(_DiagnosticsSurface.events),
          ),
        ],
      ],
    );
  }
}

enum _SupportToolbarChipTone { primary, secondary }

class _SupportToolbarChip extends StatelessWidget {
  const _SupportToolbarChip({
    required this.selected,
    required this.label,
    required this.tone,
    required this.onPressed,
  });

  final bool selected;
  final String label;
  final _SupportToolbarChipTone tone;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPrimary = tone == _SupportToolbarChipTone.primary;
    final sideColor = selected
        ? (isPrimary
              ? theme.colorScheme.primary.withValues(alpha: 0.18)
              : theme.colorScheme.onSurface.withValues(alpha: 0.10))
        : (isPrimary
              ? theme.colorScheme.outlineVariant
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.72));
    final backgroundColor = selected
        ? (isPrimary
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.42,
                ))
        : theme.colorScheme.surface.withValues(alpha: isPrimary ? 0.72 : 0.54);
    final foregroundColor = selected
        ? (isPrimary ? theme.colorScheme.primary : theme.colorScheme.onSurface)
        : (isPrimary
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.78));
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      side: BorderSide(color: sideColor),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: backgroundColor,
      selectedColor: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      label: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: foregroundColor,
        ),
      ),
      onSelected: (_) => onPressed(),
    );
  }
}

class _SupportDiagnosticsWorkspace extends StatelessWidget {
  const _SupportDiagnosticsWorkspace({
    required this.controller,
    required this.surface,
    required this.onSurfaceChanged,
  });

  final MobileShellController controller;
  final _DiagnosticsSurface surface;
  final ValueChanged<_DiagnosticsSurface> onSurfaceChanged;

  @override
  Widget build(BuildContext context) {
    return _DiagnosticsPage(
      controller: controller,
      surface: surface,
      onSurfaceChanged: onSurfaceChanged,
      showHeader: false,
      includeEmbeddedBrowserStateCard: true,
      showSurfaceSelector: false,
    );
  }
}

class _RoutingPage extends StatefulWidget {
  const _RoutingPage({
    required this.controller,
    this.onBack,
    required this.onOpenProfiles,
    required this.onOpenVPNTransportProfileEditor,
    required this.headerAccessory,
  });

  final MobileShellController controller;
  final VoidCallback? onBack;
  final VoidCallback onOpenProfiles;
  final Future<void> Function(PlatformTunnelMode mode)
  onOpenVPNTransportProfileEditor;
  final Widget headerAccessory;

  @override
  State<_RoutingPage> createState() => _RoutingPageState();
}

class _RoutingPageState extends State<_RoutingPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showRoutingProfileSheet({
    required ShellText copy,
    required MobileShellController controller,
    required PlatformTunnelUnderlayRoutePolicy underlayRoutePolicy,
    required bool showDevelopmentWifiProfile,
    required bool developmentWifiUnsupported,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  copy.routingProfile,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              RadioGroup<PlatformTunnelUnderlayRoutePolicy>(
                groupValue: underlayRoutePolicy,
                onChanged: (PlatformTunnelUnderlayRoutePolicy? nextValue) {
                  if (nextValue == null) {
                    return;
                  }
                  controller.updateUnderlayRoutePolicy(nextValue);
                  Navigator.of(context).pop();
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    RadioListTile<PlatformTunnelUnderlayRoutePolicy>(
                      value: PlatformTunnelUnderlayRoutePolicy.standard,
                      title: Text(copy.routingProfileStandard),
                      subtitle: Text(copy.routingProfileStandardDescription),
                    ),
                    if (showDevelopmentWifiProfile)
                      RadioListTile<PlatformTunnelUnderlayRoutePolicy>(
                        value: PlatformTunnelUnderlayRoutePolicy
                            .preserveActiveLocalNetwork,
                        enabled: !developmentWifiUnsupported,
                        title: Text(copy.routingProfileDevelopmentWifi),
                        subtitle: Text(
                          developmentWifiUnsupported
                              ? copy.developmentWifiRoutingSavedButUnsupported
                              : copy.routingProfileDevelopmentWifiDescription,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAppScopeSheet({
    required ShellText copy,
    required MobileShellController controller,
    required PlatformTunnelApplicationRoutingPolicy routingPolicy,
    required int selectedCount,
    required int totalCount,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        final summary = copy.routingScopeSummary(
          selectedCount: selectedCount,
          totalCount: totalCount,
        );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  copy.appScope,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              RadioGroup<PlatformTunnelApplicationRoutingPolicy>(
                groupValue: routingPolicy,
                onChanged: (PlatformTunnelApplicationRoutingPolicy? nextValue) {
                  if (nextValue == null) {
                    return;
                  }
                  controller.updateApplicationRoutingPolicy(nextValue);
                  Navigator.of(context).pop();
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    RadioListTile<PlatformTunnelApplicationRoutingPolicy>(
                      value: PlatformTunnelApplicationRoutingPolicy.allApps,
                      title: Text(copy.allApps),
                      subtitle: Text(copy.allInstalledAppsUseVpnPath),
                    ),
                    RadioListTile<PlatformTunnelApplicationRoutingPolicy>(
                      value: PlatformTunnelApplicationRoutingPolicy
                          .allowedPackages,
                      title: Text(copy.includedApps),
                      subtitle: Text(summary),
                    ),
                    RadioListTile<PlatformTunnelApplicationRoutingPolicy>(
                      value: PlatformTunnelApplicationRoutingPolicy
                          .disallowedPackages,
                      title: Text(copy.excludedApps),
                      subtitle: Text(summary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);
    final copy = context.shellText;
    final mode = controller.activePlatformTunnelMode;
    final preferences = controller.activePlatformModePreferences;
    final routingPolicy = preferences.applicationRoutingPolicy;
    final underlayRoutePolicy = preferences.underlayRoutePolicy;
    final showDevelopmentWifiProfile =
        controller.activeModeSupportsDevelopmentUnderlayRouting ||
        underlayRoutePolicy ==
            PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork;
    final developmentWifiUnsupported =
        showDevelopmentWifiProfile &&
        !controller.activeModeSupportsDevelopmentUnderlayRouting;
    final selectedPackages = switch (routingPolicy) {
      PlatformTunnelApplicationRoutingPolicy.allApps => const <String>[],
      PlatformTunnelApplicationRoutingPolicy.allowedPackages =>
        preferences.allowedPackages,
      PlatformTunnelApplicationRoutingPolicy.disallowedPackages =>
        preferences.disallowedPackages,
    };
    final query = _searchController.text.trim().toLowerCase();
    final filteredApps = controller.installedApps
        .where((MobilePlatformApp app) {
          if (query.isEmpty) {
            return true;
          }
          return app.label.toLowerCase().contains(query) ||
              app.packageName.toLowerCase().contains(query);
        })
        .toList(growable: false);
    final filteredPackageNames = filteredApps
        .map((MobilePlatformApp app) => app.packageName)
        .toList(growable: false);
    final selectedVisibleCount = filteredApps
        .where(
          (MobilePlatformApp app) => selectedPackages.contains(app.packageName),
        )
        .length;
    final routingProfileLabel = switch (underlayRoutePolicy) {
      PlatformTunnelUnderlayRoutePolicy.standard => copy.routingProfileStandard,
      PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork =>
        copy.routingProfileDevelopmentWifi,
    };
    final routingProfileDetail = switch (underlayRoutePolicy) {
      PlatformTunnelUnderlayRoutePolicy.standard => null,
      PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork =>
        developmentWifiUnsupported
            ? copy.developmentWifiRoutingSavedButUnsupported
            : null,
    };
    final appScopeLabel = switch (routingPolicy) {
      PlatformTunnelApplicationRoutingPolicy.allApps => copy.allApps,
      PlatformTunnelApplicationRoutingPolicy.allowedPackages =>
        copy.includedApps,
      PlatformTunnelApplicationRoutingPolicy.disallowedPackages =>
        copy.excludedApps,
    };
    final appScopeDetail =
        routingPolicy == PlatformTunnelApplicationRoutingPolicy.allApps
        ? copy.allInstalledAppsUseVpnPath
        : copy.routingScopeSummary(
            selectedCount: selectedPackages.length,
            totalCount: controller.installedApps.length,
          );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        if (widget.onBack != null) ...<Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
              label: Text(context.shellText.back),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _PageHeader(
          title: context.shellText.routingTitle,
          subtitle: context.shellText.routingSubtitle,
          trailing: widget.headerAccessory,
        ),
        if (controller.surfaceNotice != null) ...<Widget>[
          const SizedBox(height: 12),
          _NoticeBanner(message: controller.surfaceNotice!),
        ],
        const SizedBox(height: 16),
        routing.RoutingContentSurface(
          variant: routing.RoutingContentSurfaceVariant.mobile,
          busy: controller.busy,
          hostReady: controller.hostConnection?.isReady == true,
          platformTunnels: controller.platformTunnels,
          platformTunnelResultFor: controller.platformTunnelResultFor,
          platformTunnelStatusFor: controller.platformTunnelStatusFor,
          transportProfileStatusSummaryForMode:
              controller.vpnTransportProfileStatusSummaryForMode,
          transportProfileImportAdapterLabelForMode:
              controller.vpnTransportProfileImportAdapterLabelForMode,
          providerTransportCompatibilitySummaryForMode:
              controller.providerTransportCompatibilitySummaryForMode,
          platformTunnelStartBlockReasonForMode:
              controller.platformTunnelStartPreparationBlockReason,
          canConfigureTransportProfileForMode:
              controller.canConfigureVPNTransportProfileForMode,
          canEditTransportProfileForMode:
              controller.canEditVPNTransportProfileForMode,
          transportProfileConfiguredForMode:
              controller.activeVPNTransportProfileConfiguredForMode,
          onEditTransportProfile: widget.onOpenVPNTransportProfileEditor,
          onImportTransportProfile: controller.importVPNTransportProfileForMode,
          onManageTransportProfiles: widget.onOpenVPNTransportProfileEditor,
          onForgetTransportProfile: controller.forgetVPNTransportProfileForMode,
        ),
        const SizedBox(height: 12),
        if (!controller.activeModeSupportsAppRouting || mode == null)
          _RoutingUnavailableCard(onOpenProfiles: widget.onOpenProfiles)
        else ...<Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final splitSections = constraints.maxWidth >= 760;
                          final profileControl = _RoutingCompactSelectorCard(
                            key: const ValueKey<String>(
                              'routing-profile-control',
                            ),
                            icon: Icons.route_outlined,
                            title: copy.routingProfile,
                            value: routingProfileLabel,
                            detail: routingProfileDetail,
                            onTap: () => unawaited(
                              _showRoutingProfileSheet(
                                copy: copy,
                                controller: controller,
                                underlayRoutePolicy: underlayRoutePolicy,
                                showDevelopmentWifiProfile:
                                    showDevelopmentWifiProfile,
                                developmentWifiUnsupported:
                                    developmentWifiUnsupported,
                              ),
                            ),
                          );
                          final appScopeControl = _RoutingCompactSelectorCard(
                            key: const ValueKey<String>(
                              'routing-app-scope-control',
                            ),
                            icon: Icons.apps_outlined,
                            title: copy.appScope,
                            value: appScopeLabel,
                            detail: appScopeDetail,
                            onTap: () => unawaited(
                              _showAppScopeSheet(
                                copy: copy,
                                controller: controller,
                                routingPolicy: routingPolicy,
                                selectedCount: selectedPackages.length,
                                totalCount: controller.installedApps.length,
                              ),
                            ),
                          );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (splitSections)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(child: profileControl),
                                    const SizedBox(width: 10),
                                    Expanded(child: appScopeControl),
                                  ],
                                )
                              else ...<Widget>[
                                profileControl,
                                const SizedBox(height: 10),
                                appScopeControl,
                              ],
                            ],
                          );
                        },
                  ),
                  if (routingPolicy !=
                      PlatformTunnelApplicationRoutingPolicy
                          .allApps) ...<Widget>[
                    const SizedBox(height: 10),
                    Divider(height: 1, color: theme.colorScheme.outlineVariant),
                    const SizedBox(height: 10),
                    _RoutingFilterToolbar(
                      searchController: _searchController,
                      searchLabel: copy.searchApps,
                      summary: copy.routingVisibleAppsSummary(
                        visibleCount: filteredApps.length,
                        totalCount: controller.installedApps.length,
                        selectedCount: selectedVisibleCount,
                      ),
                      onSearchChanged: () => setState(() {}),
                      actionsEnabled: filteredPackageNames.isNotEmpty,
                      bulkActionsLabel: copy.bulkActions,
                      selectVisibleLabel: copy.selectVisibleApps,
                      clearVisibleLabel: copy.clearVisibleApps,
                      onSelectVisible: () =>
                          controller.updateRoutingPackageSelectionBatch(
                            packageNames: filteredPackageNames,
                            selected: true,
                          ),
                      onClearVisible: () =>
                          controller.updateRoutingPackageSelectionBatch(
                            packageNames: filteredPackageNames,
                            selected: false,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (routingPolicy == PlatformTunnelApplicationRoutingPolicy.allApps)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  copy.allInstalledAppsUseVpnPath,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            )
          else ...<Widget>[
            if (controller.loadingInstalledApps)
              const Center(child: CircularProgressIndicator())
            else if (controller.installedAppsError != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        controller.installedAppsError!,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () => unawaited(
                          controller.ensureInstalledAppsLoaded(force: true),
                        ),
                        child: Text(copy.retryAppScan),
                      ),
                    ],
                  ),
                ),
              )
            else if (filteredApps.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    query.isEmpty
                        ? copy.noInstalledAppsReported
                        : copy.noInstalledAppsMatchSearch,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              )
            else
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: List<Widget>.generate(filteredApps.length, (
                    int index,
                  ) {
                    final app = filteredApps[index];
                    final selected = selectedPackages.contains(app.packageName);
                    return Column(
                      children: <Widget>[
                        _RoutingAppListTile(
                          app: app,
                          selected: selected,
                          onChanged: (bool nextValue) {
                            controller.updateRoutingPackageSelection(
                              packageName: app.packageName,
                              selected: nextValue,
                            );
                          },
                        ),
                        if (index != filteredApps.length - 1)
                          const Divider(height: 1),
                      ],
                    );
                  }),
                ),
              ),
          ],
        ],
      ],
    );
  }
}

class _RoutingAppIcon extends StatelessWidget {
  const _RoutingAppIcon({required this.app});

  final MobilePlatformApp app;

  @override
  Widget build(BuildContext context) {
    final fallbackIcon = app.systemApp
        ? const Icon(Icons.memory_outlined)
        : const Icon(Icons.apps_outlined);
    final iconBytes = app.iconBytes;
    if (iconBytes == null || iconBytes.isEmpty) {
      return fallbackIcon;
    }
    return SizedBox(
      key: ValueKey<String>('routing-app-icon-${app.packageName}'),
      width: 24,
      height: 24,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          iconBytes,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallbackIcon,
        ),
      ),
    );
  }
}

class _RoutingCompactSelectorCard extends StatelessWidget {
  const _RoutingCompactSelectorCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    icon,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (detail != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  detail!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutingAppListTile extends StatelessWidget {
  const _RoutingAppListTile({
    required this.app,
    required this.selected,
    required this.onChanged,
  });

  final MobilePlatformApp app;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onChanged(!selected),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: <Widget>[
            _RoutingAppIcon(app: app),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    app.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    app.packageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Checkbox(
              value: selected,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (bool? nextValue) => onChanged(nextValue ?? false),
            ),
          ],
        ),
      ),
    );
  }
}

enum _RoutingBulkAction { selectVisible, clearVisible }

class _RoutingFilterToolbar extends StatelessWidget {
  const _RoutingFilterToolbar({
    required this.searchController,
    required this.searchLabel,
    required this.summary,
    required this.onSearchChanged,
    required this.actionsEnabled,
    required this.bulkActionsLabel,
    required this.selectVisibleLabel,
    required this.clearVisibleLabel,
    required this.onSelectVisible,
    required this.onClearVisible,
  });

  final TextEditingController searchController;
  final String searchLabel;
  final String summary;
  final VoidCallback onSearchChanged;
  final bool actionsEnabled;
  final String bulkActionsLabel;
  final String selectVisibleLabel;
  final String clearVisibleLabel;
  final VoidCallback onSelectVisible;
  final VoidCallback onClearVisible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          key: const ValueKey<String>('routing-app-search-field'),
          controller: searchController,
          onChanged: (_) => onSearchChanged(),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search),
            labelText: searchLabel,
            border: const OutlineInputBorder(),
            suffixIcon: PopupMenuButton<_RoutingBulkAction>(
              key: const ValueKey<String>('routing-bulk-actions'),
              tooltip: bulkActionsLabel,
              enabled: actionsEnabled,
              onSelected: (_RoutingBulkAction action) {
                switch (action) {
                  case _RoutingBulkAction.selectVisible:
                    onSelectVisible();
                    return;
                  case _RoutingBulkAction.clearVisible:
                    onClearVisible();
                    return;
                }
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<_RoutingBulkAction>>[
                    PopupMenuItem<_RoutingBulkAction>(
                      value: _RoutingBulkAction.selectVisible,
                      child: Text(selectVisibleLabel),
                    ),
                    PopupMenuItem<_RoutingBulkAction>(
                      value: _RoutingBulkAction.clearVisible,
                      child: Text(clearVisibleLabel),
                    ),
                  ],
              icon: const Icon(Icons.done_all),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          summary,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RoutingUnavailableCard extends StatelessWidget {
  const _RoutingUnavailableCard({required this.onOpenProfiles});

  final VoidCallback onOpenProfiles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.shellText.routingUnavailableForMode,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.shellText.routingUnavailableMessage,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            FilledButton.tonal(
              onPressed: onOpenProfiles,
              child: Text(context.shellText.openProfiles),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderRecordsRootSection extends StatelessWidget {
  const _ProviderRecordsRootSection({required this.controller});

  final MobileShellController controller;

  @override
  Widget build(BuildContext context) {
    return workflow.ManagedProvidersLibrarySurface(
      variant: workflow.WorkflowLibrarySurfaceVariant.mobile,
      managedProviders: controller.managedProviders,
      activeManagedProviderId: controller.selectedManagedProviderId,
      emptyState: workflow.WorkflowEmptyStateData(
        title: context.shellText.noSavedProvidersYet,
        message: context.shellText.noSavedProvidersMessage,
      ),
      itemBuilder:
          (BuildContext context, ManagedProviderRecord provider, bool active) {
            return _ManagedProviderListItem(
              provider: provider,
              selected: active,
              busy: controller.busy,
              onSelect: () => controller.focusManagedProvider(provider.id),
              onEdit: () => controller.selectManagedProvider(provider.id),
              onCopy: controller.duplicateSelectedManagedProvider,
              onUseInProfile: () =>
                  controller.useManagedProviderForDraft(provider.id),
              onSaveAsTemplate:
                  controller.startProviderTemplateDraftFromManagedProvider,
              onDelete: () =>
                  unawaited(controller.deleteSelectedManagedProvider()),
            );
          },
    );
  }
}

class _TemplateRecordsRootSection extends StatelessWidget {
  const _TemplateRecordsRootSection({required this.controller});

  final MobileShellController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (controller.providerTemplates.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.shellText.noSavedTemplatesYet,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.shellText.noSavedTemplatesMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: <Widget>[
            for (
              var index = 0;
              index < controller.providerTemplates.length;
              index++
            ) ...<Widget>[
              _ProviderTemplateListItem(
                template: controller.providerTemplates[index],
                selected:
                    controller.selectedProviderTemplateId ==
                    controller.providerTemplates[index].id,
                busy: controller.busy,
                onSelect: () => controller.focusProviderTemplate(
                  controller.providerTemplates[index].id,
                ),
                onUse: () => controller.useProviderTemplate(
                  controller.providerTemplates[index].id,
                ),
                onCopy: controller.duplicateSelectedProviderTemplate,
                onEdit: () => controller.selectProviderTemplate(
                  controller.providerTemplates[index].id,
                ),
                onDelete: () =>
                    unawaited(controller.deleteSelectedProviderTemplate()),
              ),
              if (index != controller.providerTemplates.length - 1)
                const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _ManagedProviderListItem extends StatelessWidget {
  const _ManagedProviderListItem({
    required this.provider,
    required this.selected,
    required this.busy,
    required this.onSelect,
    required this.onEdit,
    required this.onCopy,
    required this.onUseInProfile,
    required this.onSaveAsTemplate,
    required this.onDelete,
  });

  final ManagedProviderRecord provider;
  final bool selected;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onUseInProfile;
  final VoidCallback onSaveAsTemplate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = provider.name.trim().isEmpty ? provider.id : provider.name;
    final familyTitle =
        supportedProviderDefinitionFor(provider.provider)?.title ??
        provider.provider;

    return _SelectableListRow(
      selected: selected,
      tile: ListTile(
        key: ValueKey<String>('managed-provider-item-${provider.id}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        onTap: onSelect,
        leading: CircleAvatar(
          backgroundColor: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          foregroundColor: selected
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurfaceVariant,
          child: const Icon(Icons.cloud_outlined),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 4),
            Text(
              context.shellText.typeLabel(familyTitle),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.shellText.usedInProfiles,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (provider.availability.message.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                provider.availability.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        trailing: _StatusChip(
          label: provider.availability.state.label,
          accent: provider.isAvailable,
        ),
      ),
      actions: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final density = _inlineActionDensityForWidth(constraints.maxWidth);
          final overflowActions = <_CardActionEntry>[
            if (density == _InlineActionDensity.compact)
              _CardActionEntry(
                id: 'providers-copy-button',
                label: context.shellText.copyProvider,
                onSelected: () async => onCopy(),
              ),
            if (density != _InlineActionDensity.wide)
              _CardActionEntry(
                id: 'providers-use-button',
                label: context.shellText.mobileUseInProfileDraft,
                onSelected: () async => onUseInProfile(),
              ),
            _CardActionEntry(
              id: 'providers-save-template-button',
              label: context.shellText.mobileSaveAsTemplate,
              onSelected: () async => onSaveAsTemplate(),
            ),
            _CardActionEntry(
              id: 'providers-delete-button',
              label: context.shellText.mobileDeleteProvider,
              onSelected: () async => onDelete(),
            ),
          ];
          final inlineActions = <_InlineActionDescriptor>[
            _InlineActionDescriptor(
              id: 'providers-edit-button',
              label: context.shellText.mobileEditProvider,
              icon: Icons.edit_outlined,
              onPressed: onEdit,
              variant: _InlineActionVariant.filledTonal,
            ),
            if (density != _InlineActionDensity.compact)
              _InlineActionDescriptor(
                id: 'providers-copy-button',
                label: context.shellText.copyProvider,
                icon: Icons.content_copy_outlined,
                onPressed: onCopy,
                variant: _InlineActionVariant.outlined,
              ),
            if (density == _InlineActionDensity.wide)
              _InlineActionDescriptor(
                id: 'providers-use-button',
                label: context.shellText.mobileUseInProfileDraft,
                icon: Icons.assignment_turned_in_outlined,
                onPressed: onUseInProfile,
                variant: _InlineActionVariant.outlined,
              ),
          ];
          if (density == _InlineActionDensity.wide) {
            overflowActions.removeWhere(
              (_CardActionEntry action) => action.id == 'providers-use-button',
            );
          }
          final actionPlan = _planInlineActions(
            context: context,
            maxWidth: constraints.maxWidth,
            inlineActions: inlineActions,
            overflowActions: overflowActions,
          );
          return _InlineActionStrip(
            busy: busy,
            overflowTooltip: MaterialLocalizations.of(context).showMenuTooltip,
            overflowKey: const ValueKey<String>('providers-actions-overflow'),
            inlineActions: actionPlan.inlineActions,
            overflowActions: actionPlan.overflowActions,
          );
        },
      ),
    );
  }
}

class _ProviderTemplateListItem extends StatelessWidget {
  const _ProviderTemplateListItem({
    required this.template,
    required this.selected,
    required this.busy,
    required this.onSelect,
    required this.onUse,
    required this.onCopy,
    required this.onEdit,
    required this.onDelete,
  });

  final ProviderTemplateRecord template;
  final bool selected;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback onUse;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = template.name.trim().isEmpty ? template.id : template.name;
    final familyTitle =
        supportedProviderDefinitionFor(template.provider)?.title ??
        template.provider;

    return _SelectableListRow(
      selected: selected,
      tile: ListTile(
        key: ValueKey<String>('provider-template-item-${template.id}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        onTap: onSelect,
        leading: CircleAvatar(
          backgroundColor: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          foregroundColor: selected
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurfaceVariant,
          child: const Icon(Icons.bookmark_border_rounded),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 4),
            Text(
              context.shellText.typeLabel(familyTitle),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.shellText.prefillsNewProviders,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (template.availability.message.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                template.availability.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        trailing: _StatusChip(
          label: template.availability.state.label,
          accent: template.isAvailable,
        ),
      ),
      actions: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final density = _inlineActionDensityForWidth(constraints.maxWidth);
          final overflowActions = <_CardActionEntry>[
            if (density == _InlineActionDensity.compact)
              _CardActionEntry(
                id: 'templates-copy-button',
                label: context.shellText.copyTemplate,
                onSelected: () async => onCopy(),
              ),
            if (density != _InlineActionDensity.wide)
              _CardActionEntry(
                id: 'templates-edit-button',
                label: context.shellText.mobileEditTemplate,
                onSelected: () async => onEdit(),
              ),
            _CardActionEntry(
              id: 'templates-delete-button',
              label: context.shellText.mobileDeleteTemplate,
              onSelected: () async => onDelete(),
            ),
          ];
          final inlineActions = <_InlineActionDescriptor>[
            _InlineActionDescriptor(
              id: 'templates-use-button',
              label: context.shellText.mobileUseTemplate,
              icon: Icons.playlist_add_check_outlined,
              onPressed: onUse,
              variant: _InlineActionVariant.filledTonal,
            ),
            if (density != _InlineActionDensity.compact)
              _InlineActionDescriptor(
                id: 'templates-copy-button',
                label: context.shellText.copyTemplate,
                icon: Icons.content_copy_outlined,
                onPressed: onCopy,
                variant: _InlineActionVariant.outlined,
              ),
            if (density == _InlineActionDensity.wide)
              _InlineActionDescriptor(
                id: 'templates-edit-button',
                label: context.shellText.mobileEditTemplate,
                icon: Icons.edit_outlined,
                onPressed: onEdit,
                variant: _InlineActionVariant.outlined,
              ),
          ];
          final actionPlan = _planInlineActions(
            context: context,
            maxWidth: constraints.maxWidth,
            inlineActions: inlineActions,
            overflowActions: overflowActions,
          );
          return _InlineActionStrip(
            busy: busy,
            overflowTooltip: MaterialLocalizations.of(context).showMenuTooltip,
            overflowKey: const ValueKey<String>('templates-actions-overflow'),
            inlineActions: actionPlan.inlineActions,
            overflowActions: actionPlan.overflowActions,
          );
        },
      ),
    );
  }
}

class _ProviderChooserPage extends StatelessWidget {
  const _ProviderChooserPage({required this.controller});

  final MobileShellController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        return Scaffold(
          key: const ValueKey<String>('provider-chooser-route'),
          appBar: AppBar(title: Text(context.shellText.createProvider)),
          body: SafeArea(
            child: _ProviderChooserPageBody(
              supportedProviders: controller.supportedProviderCatalog,
              providerDescriptors: controller.providerDescriptors,
              userTemplates: controller.providerTemplates,
              presets: controller.presetCatalog,
              busy: controller.busy,
            ),
          ),
        );
      },
    );
  }
}

class _ProviderChooserPageBody extends StatefulWidget {
  const _ProviderChooserPageBody({
    required this.supportedProviders,
    required this.providerDescriptors,
    required this.userTemplates,
    required this.presets,
    required this.busy,
  });

  final List<SupportedProviderDefinition> supportedProviders;
  final List<ProviderDescriptor> providerDescriptors;
  final List<ProviderTemplateRecord> userTemplates;
  final List<ProviderPreset> presets;
  final bool busy;

  @override
  State<_ProviderChooserPageBody> createState() =>
      _ProviderChooserPageBodyState();
}

class _ProviderChooserPageBodyState extends State<_ProviderChooserPageBody> {
  late final TextEditingController _searchController;
  _ProviderChooserSurface _surface = _ProviderChooserSurface.families;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();
    final filteredPresets = widget.presets
        .where((ProviderPreset preset) {
          if (query.isEmpty) {
            return true;
          }
          final familyTitle =
              supportedProviderDefinitionFor(preset.provider)?.title ?? '';
          final haystack =
              '${preset.title} ${preset.description} ${preset.provider} $familyTitle'
                  .toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _surface == _ProviderChooserSurface.families
                ? context.shellText.createProviderChooseType
                : context.shellText.createProviderUsePreset,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ChoiceChip(
                key: const ValueKey<String>(
                  'provider-chooser-surface-families',
                ),
                selected: _surface == _ProviderChooserSurface.families,
                label: Text(
                  context.shellText.providerTypes,
                  style: theme.textTheme.labelLarge,
                ),
                onSelected: (_) {
                  setState(() {
                    _surface = _ProviderChooserSurface.families;
                  });
                },
              ),
              ChoiceChip(
                key: const ValueKey<String>(
                  'provider-chooser-surface-templates',
                ),
                selected: _surface == _ProviderChooserSurface.templates,
                label: Text(
                  context.shellText.presets,
                  style: theme.textTheme.labelLarge,
                ),
                onSelected: (_) {
                  setState(() {
                    _surface = _ProviderChooserSurface.templates;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: switch (_surface) {
              _ProviderChooserSurface.families => ListView(
                children: <Widget>[
                  if (widget.supportedProviders.isEmpty)
                    Text(
                      context.shellText.noShippedProviderTypesYet,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    ...widget.supportedProviders.map((
                      SupportedProviderDefinition provider,
                    ) {
                      final availability = provider.availabilityFor(
                        widget.providerDescriptors,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            key: ValueKey<String>(
                              'provider-family-picker-item-${provider.id}',
                            ),
                            borderRadius: BorderRadius.circular(14),
                            onTap: widget.busy
                                ? null
                                : () {
                                    Navigator.of(context).pop(
                                      _ProviderChooserResult.family(
                                        provider.id,
                                      ),
                                    );
                                  },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          provider.title,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      _StatusChip(
                                        label: availability.isAvailable
                                            ? context.shellText.available
                                            : context.shellText.unavailable,
                                        accent: availability.isAvailable,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    provider.description,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  if (availability
                                      .message
                                      .isNotEmpty) ...<Widget>[
                                    const SizedBox(height: 4),
                                    Text(
                                      availability.message,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
              _ProviderChooserSurface.templates => ListView(
                children: <Widget>[
                  TextField(
                    key: const ValueKey<String>(
                      'provider-template-search-field',
                    ),
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: context.shellText.searchTemplates,
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (String value) {
                      setState(() {
                        _query = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.shellText.shippedPresets,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (filteredPresets.isEmpty)
                    Text(
                      context.shellText.noShippedTemplatesMatchSearch,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    ...filteredPresets.map((ProviderPreset preset) {
                      final availability = preset.availabilityFor(
                        widget.providerDescriptors,
                      );
                      final familyTitle =
                          supportedProviderDefinitionFor(
                            preset.provider,
                          )?.title ??
                          preset.provider;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          key: ValueKey<String>(
                            'template-picker-item-${preset.id}',
                          ),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.35),
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
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  _StatusChip(
                                    label: availability.isAvailable
                                        ? context.shellText.available
                                        : context.shellText.unavailable,
                                    accent: availability.isAvailable,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.shellText.typeLabel(familyTitle),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.shellText.startingPointForNewProviders,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                preset.description,
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.shellText.readOnlyShippedTemplate,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (availability.message.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 4),
                                Text(
                                  availability.message,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              FilledButton.tonal(
                                key: ValueKey<String>(
                                  'template-picker-use-${preset.id}',
                                ),
                                onPressed:
                                    widget.busy || !availability.isAvailable
                                    ? null
                                    : () {
                                        Navigator.of(context).pop(
                                          _ProviderChooserResult.template(
                                            preset,
                                          ),
                                        );
                                      },
                                child: Text(
                                  context.shellText.mobileUseTemplate,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            },
          ),
        ],
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

class _DialogSurfaceFrame extends StatelessWidget {
  const _DialogSurfaceFrame({
    required this.child,
    this.maxWidth = 560,
    this.maxHeight = 640,
  });

  final Widget child;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final resolvedHeight = size.height - 40 < maxHeight
        ? size.height - 40
        : maxHeight;
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: resolvedHeight,
        ),
        child: SizedBox(width: maxWidth, child: child),
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
    this.showHeader = true,
    this.showSurfaceSelector = true,
  });

  final MobileShellController controller;
  final _ActivitySurface surface;
  final Future<void> Function(ChallengeRecord challenge)
  onLaunchChallengeSurface;
  final String Function(ChallengeRecord? challenge) openChallengeLabel;
  final bool Function(ChallengeRecord? challenge) showsManualChallengeContinue;
  final ValueChanged<_ActivitySurface> onSurfaceChanged;
  final bool showHeader;
  final bool showSurfaceSelector;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (showHeader) ...<Widget>[
            _PageHeader(
              title: context.shellText.activity,
              subtitle: context.shellText.activityPageSubtitle,
            ),
            const SizedBox(height: 16),
          ],
          if (showSurfaceSelector) ...<Widget>[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                ChoiceChip(
                  selected: surface == _ActivitySurface.resolutions,
                  label: Text(
                    context.shellText.resolutionsCount(
                      controller.resolutions.length,
                    ),
                    style: theme.textTheme.labelLarge,
                  ),
                  onSelected: (_) =>
                      onSurfaceChanged(_ActivitySurface.resolutions),
                ),
                ChoiceChip(
                  selected: surface == _ActivitySurface.sessions,
                  label: Text(
                    context.shellText.sessionsCount(controller.sessions.length),
                    style: theme.textTheme.labelLarge,
                  ),
                  onSelected: (_) =>
                      onSurfaceChanged(_ActivitySurface.sessions),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
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
    this.showHeader = true,
    this.includeEmbeddedBrowserStateCard = false,
    this.showSurfaceSelector = true,
  });

  final MobileShellController controller;
  final _DiagnosticsSurface surface;
  final ValueChanged<_DiagnosticsSurface> onSurfaceChanged;
  final bool showHeader;
  final bool includeEmbeddedBrowserStateCard;
  final bool showSurfaceSelector;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (showHeader) ...<Widget>[
            _PageHeader(
              title: context.shellText.diagnostics,
              subtitle: context.shellText.diagnosticsPageSubtitle,
            ),
            const SizedBox(height: 16),
          ],
          if (showSurfaceSelector) ...<Widget>[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                ChoiceChip(
                  selected: surface == _DiagnosticsSurface.overview,
                  label: Text(
                    context.shellText.overview,
                    style: theme.textTheme.labelLarge,
                  ),
                  onSelected: (_) =>
                      onSurfaceChanged(_DiagnosticsSurface.overview),
                ),
                ChoiceChip(
                  selected: surface == _DiagnosticsSurface.events,
                  label: Text(
                    context.shellText.eventsCount(controller.events.length),
                    style: theme.textTheme.labelLarge,
                  ),
                  onSelected: (_) =>
                      onSurfaceChanged(_DiagnosticsSurface.events),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: switch (surface) {
              _DiagnosticsSurface.overview =>
                support.SupportDiagnosticsOverviewSurface(
                  variant: support.SupportContentSurfaceVariant.mobile,
                  children: <Widget>[
                    _HostBanner(controller: controller),
                    _SystemTunnelBanner(controller: controller),
                    if (controller.surfaceNotice != null)
                      _NoticeBanner(message: controller.surfaceNotice!),
                    if (includeEmbeddedBrowserStateCard)
                      _EmbeddedBrowserStateCard(controller: controller),
                  ],
                ),
              _DiagnosticsSurface.events => support.SupportEventStreamSurface(
                variant: support.SupportContentSurfaceVariant.mobile,
                events: controller.events,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
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
          ),
        ),
        if (trailing != null) ...<Widget>[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

class _ShellHeaderAccessory extends StatelessWidget {
  const _ShellHeaderAccessory({
    required this.controller,
    required this.onOpenDiagnostics,
  });

  final MobileShellController controller;
  final VoidCallback onOpenDiagnostics;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _HostStatusIndicator(
          controller: controller,
          onOpenDiagnostics: onOpenDiagnostics,
        ),
        const SizedBox(width: 8),
        _LocaleMenuButton(controller: controller),
      ],
    );
  }
}

class _LocaleMenuButton extends StatelessWidget {
  const _LocaleMenuButton({required this.controller});

  final MobileShellController controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
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
      child: SizedBox.square(
        dimension: 44,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
          ),
          child: const Icon(Icons.translate_rounded),
        ),
      ),
    );
  }
}

class _HostStatusIndicator extends StatelessWidget {
  const _HostStatusIndicator({
    required this.controller,
    required this.onOpenDiagnostics,
  });

  final MobileShellController controller;
  final VoidCallback onOpenDiagnostics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = _hostIndicatorTone(context, controller);
    final palette = context.shellVisuals.tone(tone.$2);
    final connectionState = controller.hostConnection?.state;
    final isReady =
        !controller.requiresLocalStateReset &&
        connectionState == MobileHostLifecycleState.ready &&
        controller.status == ShellStatus.ready;
    final isBlocked =
        controller.requiresLocalStateReset ||
        connectionState == MobileHostLifecycleState.incompatible ||
        connectionState == MobileHostLifecycleState.failed ||
        connectionState == MobileHostLifecycleState.unavailable;
    final borderRadius = BorderRadius.circular(14);
    final containerColor = Color.alphaBlend(
      palette.accent.withValues(
        alpha: isBlocked
            ? 0.08
            : isReady
            ? 0.04
            : 0.06,
      ),
      context.shellVisuals.highlightSurface,
    );
    final borderColor = Color.alphaBlend(
      palette.border.withValues(
        alpha: isBlocked
            ? 0.22
            : isReady
            ? 0.16
            : 0.18,
      ),
      theme.colorScheme.outlineVariant.withValues(alpha: 0.92),
    );
    final iconColor = Color.alphaBlend(
      palette.accent.withValues(
        alpha: isBlocked
            ? 0.78
            : isReady
            ? 0.68
            : 0.72,
      ),
      theme.colorScheme.onSurfaceVariant,
    );
    return Tooltip(
      message: tone.$1,
      child: Semantics(
        button: true,
        label: tone.$1,
        child: SizedBox.square(
          key: const ValueKey<String>('host-status-button'),
          dimension: 44,
          child: Material(
            color: Colors.transparent,
            borderRadius: borderRadius,
            child: InkWell(
              borderRadius: borderRadius,
              onTap: () => showDialog<void>(
                context: context,
                builder: (BuildContext context) {
                  return _DialogSurfaceFrame(
                    maxWidth: 520,
                    maxHeight: 420,
                    child: _HostStatusDialog(
                      controller: controller,
                      onOpenDiagnostics: onOpenDiagnostics,
                    ),
                  );
                },
              ),
              child: Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: borderRadius,
                    border: Border.all(color: borderColor),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: <Widget>[
                      Icon(tone.$3, color: iconColor, size: 18),
                      Positioned(
                        top: 7,
                        right: 7,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: palette.accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.surface,
                              width: 1.5,
                            ),
                          ),
                          child: const SizedBox(width: 9, height: 9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HostStatusDialog extends StatelessWidget {
  const _HostStatusDialog({
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
    final tone = _hostIndicatorTone(context, controller);
    final palette = context.shellVisuals.tone(tone.$2);

    return SingleChildScrollView(
      key: const ValueKey<String>('host-status-dialog'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.container,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(tone.$3, color: palette.accent, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _diagnosticsHostTitle(context, connection),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      controller.hostStatusMessage ??
                          context.shellText.waitingForMobileHostBridge,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const ValueKey<String>('host-status-close-button'),
                tooltip: context.shellText.close,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _Tag(
                label: context.shellText.guiBuildTag(
                  controller.appBuild.shortLabel,
                ),
              ),
              if (hostInfo != null)
                _Tag(
                  label: context.shellText.hostBuildTag(
                    hostInfo.build.shortLabel,
                  ),
                ),
              if (hostInfo != null)
                _Tag(
                  label: context.shellText.contractTag(
                    hostInfo.contractVersion,
                  ),
                ),
              if ((connection?.description ?? '').isNotEmpty)
                _Tag(label: connection!.description),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.tonal(
                onPressed: () {
                  Navigator.of(context).pop();
                  onOpenDiagnostics();
                },
                child: Text(context.shellText.openDiagnostics),
              ),
              FilledButton.tonal(
                onPressed: controller.busy || controller.requiresLocalStateReset
                    ? null
                    : () => unawaited(controller.reconnect()),
                child: Text(context.shellText.reconnect),
              ),
              if (controller.requiresLocalStateReset)
                OutlinedButton(
                  onPressed: controller.busy
                      ? null
                      : () => unawaited(controller.clearLocalState()),
                  child: Text(context.shellText.resetLocalState),
                ),
              FilledButton(
                onPressed:
                    controller.busy ||
                        controller.hostConnection?.isReady != true
                    ? null
                    : () => unawaited(controller.refresh()),
                child: Text(context.shellText.refresh),
              ),
            ],
          ),
        ],
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
    final tone = _hostIndicatorTone(context, controller);
    final palette = context.shellVisuals.tone(tone.$2);

    return Card(
      color: palette.container,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _diagnosticsHostTitle(context, connection),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              connection?.message ??
                  context.shellText.waitingForMobileHostBridge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _Tag(
                  label: context.shellText.guiBuildTag(
                    controller.appBuild.shortLabel,
                  ),
                ),
                if (hostInfo != null)
                  _Tag(
                    label: context.shellText.hostBuildTag(
                      hostInfo.build.shortLabel,
                    ),
                  ),
                if (hostInfo != null)
                  _Tag(
                    label: context.shellText.contractTag(
                      hostInfo.contractVersion,
                    ),
                  ),
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
                  child: Text(context.shellText.reconnect),
                ),
                if (controller.requiresLocalStateReset)
                  OutlinedButton(
                    onPressed: controller.busy
                        ? null
                        : () => unawaited(controller.clearLocalState()),
                    child: Text(context.shellText.resetLocalState),
                  ),
                FilledButton(
                  onPressed:
                      controller.busy ||
                          controller.hostConnection?.isReady != true
                      ? null
                      : () => unawaited(controller.refresh()),
                  child: Text(context.shellText.refresh),
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
    return support.SupportResolutionsSurface(
      variant: support.SupportContentSurfaceVariant.mobile,
      resolutions: controller.resolutions,
      selectedResolutionId: controller.selectedResolutionId,
      busy: controller.busy,
      challengeForResolution: controller.activeChallengeForResolution,
      actionsForResolution:
          (
            ResolutionRecord resolution,
            ChallengeRecord? challenge,
          ) => support.SupportResolutionActions(
            onSelect: () => controller.selectResolution(resolution.id),
            onOpenChallenge: challenge == null
                ? null
                : () => onLaunchChallengeSurface(challenge),
            openChallengeLabel: openChallengeLabel(challenge),
            onContinueChallenge:
                challenge == null || !showsManualChallengeContinue(challenge)
                ? null
                : () => controller.continueChallenge(challenge.id),
            onCancelChallenge: challenge == null
                ? null
                : () => controller.cancelChallenge(challenge.id),
            onMaterialize:
                resolution.state == ResolutionState.resolved &&
                    resolution.supportsAction(ArtifactAction.startOnThisDevice)
                ? () => controller.materializeResolution(resolution.id)
                : null,
            onCopyExport:
                resolution.state == ResolutionState.resolved &&
                    resolution.supportsAction(ArtifactAction.exportHandoff)
                ? () => controller.copyResolutionExport(resolution.id)
                : null,
            onShareExport:
                resolution.state == ResolutionState.resolved &&
                    resolution.supportsAction(ArtifactAction.exportHandoff)
                ? () => controller.shareResolutionExport(resolution.id)
                : null,
            onOpenRoom:
                resolution.state == ResolutionState.resolved &&
                    controller.hostSupportsConferenceRoomActions &&
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
            onCancel: resolution.isTerminal
                ? null
                : () => controller.cancelResolution(resolution.id),
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
    final panelPalette = context.shellVisuals.tone(ShellSemanticTone.info);

    return Card(
      color: panelPalette.container,
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
                    context.shellText.systemTunnelBannerText,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (platformTunnels.isEmpty)
              Text(
                context.shellText.noPlatformTunnelModesReported,
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
  const _PlatformTunnelCard({required this.capability, required this.result});

  final PlatformTunnelCapability capability;
  final PlatformTunnelStartResult? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
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
                    ? context.shellText.availableLowercase
                    : context.shellText.unavailableLowercase,
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
          const SizedBox(height: 10),
          Text(
            result == null
                ? context.shellText.noStartupRequestYet
                : _platformTunnelResultSummary(context, result!),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
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
    return support.SupportSessionsSurface(
      variant: support.SupportContentSurfaceVariant.mobile,
      sessions: controller.sessions,
      selectedSessionId: controller.selectedSessionId,
      busy: controller.busy,
      challengeForSession: controller.activeChallengeFor,
      actionsForSession: (SessionRecord session, ChallengeRecord? challenge) =>
          support.SupportSessionActions(
            onSelect: () => controller.selectSession(session.id),
            onStop: () => controller.stopSession(session.id),
            onExport: () => controller.exportDiagnostics(session.id),
            onOpenChallenge: challenge == null
                ? null
                : () => onLaunchChallengeSurface(challenge),
            openChallengeLabel: openChallengeLabel(challenge),
            onContinueChallenge:
                challenge == null || !showsManualChallengeContinue(challenge)
                ? null
                : () => controller.continueChallenge(challenge.id),
            onCancelChallenge: challenge == null
                ? null
                : () => controller.cancelChallenge(challenge.id),
          ),
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

class _ActionOverflowButton extends StatelessWidget {
  const _ActionOverflowButton({
    super.key,
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
                key: ValueKey<String>(entry.id),
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
    return ShellNoticeBanner(message: message);
  }
}

(String, ShellSemanticTone, IconData) _hostIndicatorTone(
  BuildContext context,
  MobileShellController controller,
) {
  final connection = controller.hostConnection;
  final copy = context.shellText;
  if (controller.requiresLocalStateReset) {
    return (copy.resetNeeded, ShellSemanticTone.danger, Icons.error_rounded);
  }
  return switch (connection?.state) {
    MobileHostLifecycleState.ready
        when controller.status == ShellStatus.ready =>
      (copy.hostReady, ShellSemanticTone.ready, Icons.check_circle_rounded),
    MobileHostLifecycleState.incompatible => (
      copy.hostIncompatible,
      ShellSemanticTone.danger,
      Icons.sync_problem_rounded,
    ),
    MobileHostLifecycleState.failed || MobileHostLifecycleState.unavailable => (
      copy.hostBlocked,
      ShellSemanticTone.danger,
      Icons.error_rounded,
    ),
    _ => (copy.connecting, ShellSemanticTone.info, Icons.sync_rounded),
  };
}

String _diagnosticsHostTitle(
  BuildContext context,
  MobileHostConnectionResult? connection,
) {
  final copy = context.shellText;
  return switch (connection?.state) {
    MobileHostLifecycleState.ready => copy.mobileHostReady,
    MobileHostLifecycleState.incompatible => copy.mobileHostIncompatible,
    MobileHostLifecycleState.failed => copy.mobileHostBlocked,
    _ => copy.connectingToMobileHost,
  };
}

String _platformTunnelCapabilitySummary(
  BuildContext context,
  PlatformTunnelCapability capability,
) {
  final copy = context.shellText;
  if (capability.available && capability.satisfiedPrerequisites.isNotEmpty) {
    final satisfied = capability.satisfiedPrerequisites
        .map((PlatformTunnelPrerequisite prerequisite) => prerequisite.label)
        .join(', ');
    return copy.satisfiedPrerequisites(satisfied);
  }
  if (!capability.available && capability.missingPrerequisite != null) {
    return copy.missingPrerequisite(capability.missingPrerequisite!.label);
  }
  if (capability.available) {
    return copy.mobileHostModeAvailable;
  }
  return copy.mobileHostModeUnavailable;
}

String _platformTunnelResultSummary(
  BuildContext context,
  PlatformTunnelStartResult result,
) {
  final copy = context.shellText;
  if (result.ready) {
    if (result.underlayRoutePolicy ==
        PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork) {
      return copy.platformTunnelReadyWithRoutingProfile(
        modeLabel: result.mode.label,
        profileLabel: _underlayRoutePolicyLabel(
          copy,
          result.underlayRoutePolicy!,
        ),
      );
    }
    return copy.platformTunnelReady(result.mode.label);
  }
  final buffer = StringBuffer(
    copy.startupBlockedAt(result.stage?.label ?? copy.unknownStage),
  );
  if (result.missingPrerequisite != null) {
    buffer.write(
      ' ${copy.missingPrerequisite(result.missingPrerequisite!.label)}.',
    );
  }
  if (result.message.isNotEmpty) {
    buffer.write(' ${result.message}');
  }
  return buffer.toString();
}

HomeWorkflowEmptyStateData _mobileHomeEmptyStateData(
  BuildContext context,
  VoidCallback onOpenProfiles,
) {
  return HomeWorkflowEmptyStateData(
    title: context.shellText.homeNoSavedProfilesYet,
    message: context.shellText.homeNoSavedProfilesMessage,
    actions: <HomeWorkflowAction>[
      HomeWorkflowAction(
        label: t.mobileProfilesAddProfile,
        onPressed: onOpenProfiles,
      ),
      HomeWorkflowAction(
        label: t.mobileProfilesImportInvite,
        onPressed: onOpenProfiles,
        style: HomeWorkflowActionStyle.tonal,
      ),
    ],
  );
}

HomeWorkflowProfileSummaryData _mobileHomeProfileSummaryData(
  BuildContext context,
  ProfileRecord profile,
) {
  return HomeWorkflowProfileSummaryData(
    eyebrow: context.shellText.currentProfile,
    title: profile.name.isEmpty ? profile.id : profile.name,
    subtitle: '${profile.spec.provider} -> ${profile.spec.peerAddress}',
    caption: context.shellText.listeningOn(profile.spec.listenAddress),
  );
}

HomeWorkflowPrimaryActionData _mobileHomePrimaryActionData(
  BuildContext context, {
  required MobileShellController controller,
  required bool hasSelectedProfile,
  required VoidCallback onOpenProfiles,
  required bool tunnelReady,
  required ChallengeRecord? challenge,
  required Future<void> Function(ChallengeRecord challenge)
  onLaunchChallengeSurface,
  required String Function(ChallengeRecord? challenge) openChallengeLabel,
  required bool Function(ChallengeRecord? challenge)
  showsManualChallengeContinue,
  required Future<void> Function(PlatformTunnelMode mode)
  onOpenVPNTransportProfileEditor,
}) {
  final activeChallenge = challenge;
  final needsProfileSelection = !tunnelReady && !hasSelectedProfile;
  final startBlockReason =
      activeChallenge == null && !tunnelReady && !needsProfileSelection
      ? _activePlatformTunnelStartBlockReason(controller)
      : null;
  final startBlocked = startBlockReason != null;
  final needsVPNTransportProfile =
      startBlocked &&
      controller.canConfigureVPNTransportProfile &&
      !controller.activeVPNTransportProfileConfigured;
  final activeMode = controller.activePlatformTunnelMode;
  final canEditVPNTransportProfile =
      activeMode != null &&
      controller.canEditVPNTransportProfileForMode(activeMode);
  final tone = switch ((
    activeChallenge,
    tunnelReady,
    needsProfileSelection,
    startBlocked,
  )) {
    (final ChallengeRecord _, _, _, _) => ShellSemanticTone.attention,
    (null, true, _, _) => ShellSemanticTone.ready,
    (null, false, true, _) => ShellSemanticTone.neutral,
    (null, false, false, true) => ShellSemanticTone.attention,
    (null, false, false, false) => ShellSemanticTone.info,
  };
  final title = switch ((
    activeChallenge,
    tunnelReady,
    needsProfileSelection,
    startBlocked,
  )) {
    (final ChallengeRecord _, _, _, _) =>
      context.shellText.finishProviderValidation,
    (null, true, _, _) => context.shellText.vpnIsOn,
    (null, false, true, _) => context.shellText.profileRequired,
    (null, false, false, true) => context.shellText.unavailable,
    (null, false, false, false) => context.shellText.vpnIsOff,
  };
  final subtitle = switch ((
    activeChallenge,
    tunnelReady,
    needsProfileSelection,
    startBlocked,
  )) {
    (final ChallengeRecord currentChallenge, _, _, _) =>
      controller.challengeRequiresOwnedBrowser(currentChallenge)
          ? (currentChallenge.prompt?.trim().isNotEmpty == true
                ? currentChallenge.prompt!
                : context.shellText.continueProviderFlowInApp)
          : context.shellText.openRequiredBrowserStepFromHome,
    (null, true, _, _) => context.shellText.disconnectCurrentMobileVpnPath,
    (null, false, true, _) =>
      context.shellText.chooseOrFinishProfileBeforeStartingVpn,
    (null, false, false, true) => startBlockReason!,
    (null, false, false, false) => context.shellText.startCurrentMobileVpnPath,
  };
  final vpnTransportProfileStatus =
      controller.activeVPNTransportProfileStatusSummary;
  final primaryAction = switch ((
    activeChallenge,
    tunnelReady,
    needsProfileSelection,
    startBlocked,
  )) {
    (final ChallengeRecord currentChallenge, _, _, _) => HomeWorkflowAction(
      label: openChallengeLabel(currentChallenge),
      icon: controller.challengeRequiresOwnedBrowser(currentChallenge)
          ? Icons.open_in_browser_rounded
          : Icons.arrow_forward_rounded,
      onPressed: controller.busy
          ? null
          : () => unawaited(onLaunchChallengeSurface(currentChallenge)),
    ),
    (null, true, _, _) => HomeWorkflowAction(
      label: context.shellText.mobileTurnOffVpn,
      icon: Icons.power_settings_new_rounded,
      onPressed: controller.busy || controller.hostConnection?.isReady != true
          ? null
          : () {
              final mode = controller.activePlatformTunnelMode;
              if (mode == null) {
                return;
              }
              unawaited(controller.stopPlatformTunnel(mode));
            },
    ),
    (null, false, true, _) => HomeWorkflowAction(
      label: context.shellText.continueInProfiles,
      icon: Icons.arrow_forward_rounded,
      onPressed: controller.busy ? null : onOpenProfiles,
    ),
    (null, false, false, true) =>
      canEditVPNTransportProfile
          ? HomeWorkflowAction(
              label: controller.activeVPNTransportProfileConfigured
                  ? 'Edit VPN profile'
                  : 'Create VPN profile',
              icon: controller.activeVPNTransportProfileConfigured
                  ? Icons.edit_rounded
                  : Icons.add_rounded,
              onPressed: controller.busy
                  ? null
                  : () =>
                        unawaited(onOpenVPNTransportProfileEditor(activeMode)),
            )
          : needsVPNTransportProfile
          ? HomeWorkflowAction(
              label: context.shellText.importVPNTransportProfile,
              icon: Icons.vpn_key_rounded,
              onPressed: controller.busy
                  ? null
                  : () =>
                        unawaited(onOpenVPNTransportProfileEditor(activeMode!)),
            )
          : HomeWorkflowAction(
              label: context.shellText.mobileTurnOnVpn,
              icon: Icons.power_settings_new_rounded,
              onPressed: null,
            ),
    (null, false, false, false) => HomeWorkflowAction(
      label: context.shellText.mobileTurnOnVpn,
      icon: Icons.power_settings_new_rounded,
      onPressed: controller.busy || controller.hostConnection?.isReady != true
          ? null
          : () {
              final mode = controller.activePlatformTunnelMode;
              if (mode == null) {
                return;
              }
              unawaited(controller.startPlatformTunnel(mode));
            },
    ),
  };

  final secondaryActions = <HomeWorkflowAction>[
    if (activeChallenge != null &&
        showsManualChallengeContinue(activeChallenge))
      HomeWorkflowAction(
        label: context.shellText.iveCompletedIt,
        style: HomeWorkflowActionStyle.outlined,
        onPressed: controller.busy
            ? null
            : () => unawaited(controller.continueChallenge(activeChallenge.id)),
      ),
    if (activeChallenge != null)
      HomeWorkflowAction(
        label: context.shellText.cancelChallenge,
        style: HomeWorkflowActionStyle.text,
        onPressed: controller.busy
            ? null
            : () => unawaited(controller.cancelChallenge(activeChallenge.id)),
      ),
    if (activeChallenge == null &&
        !tunnelReady &&
        canEditVPNTransportProfile &&
        !controller.activeVPNTransportProfileConfigured)
      HomeWorkflowAction(
        label: context.shellText.importVPNTransportProfile,
        icon: Icons.upload_file_rounded,
        style: HomeWorkflowActionStyle.outlined,
        onPressed: controller.busy
            ? null
            : () => unawaited(controller.importVPNTransportProfile()),
      ),
    if (activeChallenge == null &&
        !tunnelReady &&
        controller.canConfigureVPNTransportProfile &&
        controller.activeVPNTransportProfileConfigured)
      HomeWorkflowAction(
        label: context.shellText.replaceVPNTransportProfile,
        icon: Icons.upload_file_rounded,
        style: HomeWorkflowActionStyle.outlined,
        onPressed: controller.busy
            ? null
            : () => unawaited(controller.importVPNTransportProfile()),
      ),
    if (activeChallenge == null &&
        !tunnelReady &&
        controller.canConfigureVPNTransportProfile &&
        controller.activeVPNTransportProfileConfigured)
      HomeWorkflowAction(
        label: context.shellText.forgetVPNTransportProfile,
        icon: Icons.delete_outline_rounded,
        style: HomeWorkflowActionStyle.text,
        onPressed: controller.busy
            ? null
            : () => unawaited(controller.forgetVPNTransportProfile()),
      ),
  ];

  return HomeWorkflowPrimaryActionData(
    tone: tone,
    eyebrow: switch ((
      activeChallenge,
      tunnelReady,
      needsProfileSelection,
      startBlocked,
    )) {
      (final ChallengeRecord _, _, _, _) => context.shellText.providerStepTone,
      (null, true, _, _) => context.shellText.connectionLiveTone,
      (null, false, true, _) => context.shellText.setupNeededTone,
      (null, false, false, true) => context.shellText.setupNeededTone,
      (null, false, false, false) => context.shellText.mainActionTone,
    },
    title: title,
    subtitle: subtitle,
    leadingIcon: switch ((
      activeChallenge,
      tunnelReady,
      needsProfileSelection,
      startBlocked,
    )) {
      (final ChallengeRecord _, _, _, _) => Icons.travel_explore_rounded,
      (null, true, _, _) => Icons.shield_rounded,
      (null, false, true, _) => Icons.folder_open_rounded,
      (null, false, false, true) => Icons.block_rounded,
      (null, false, false, false) => Icons.power_rounded,
    },
    primaryAction: primaryAction,
    annotation: activeChallenge == null
        ? vpnTransportProfileStatus
        : context.shellText.challengeKind(activeChallenge.kind),
    secondaryActions: secondaryActions,
  );
}

String? _activePlatformTunnelStartBlockReason(
  MobileShellController controller,
) {
  final mode = controller.activePlatformTunnelMode;
  if (mode == null) {
    return null;
  }
  return controller.platformTunnelStartPreparationBlockReason(mode);
}

HomeWorkflowModeSectionData _mobileHomeModeSectionData(
  BuildContext context,
  MobileShellController controller,
) {
  final activeCapability = controller.activePlatformTunnelCapability;
  final choiceGroups = <HomeWorkflowChoiceGroup>[];
  if (controller.platformTunnels.length > 1) {
    choiceGroups.add(
      HomeWorkflowChoiceGroup(
        options: controller.platformTunnels
            .map(
              (PlatformTunnelCapability capability) => HomeWorkflowChoiceOption(
                label: capability.mode.label,
                selected:
                    controller.activePlatformTunnelMode == capability.mode,
                onSelected: () =>
                    controller.selectPlatformTunnelMode(capability.mode),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
  final executionPlans = controller.activePlatformTunnelMode == null
      ? const <RuntimeExecutionPlanDescriptor>[]
      : controller.executionPlanOptionsForMode(
          controller.activePlatformTunnelMode!,
        );
  if (executionPlans.length > 1) {
    choiceGroups.add(
      HomeWorkflowChoiceGroup(
        label: context.shellText.executionPath,
        options: executionPlans
            .map(
              (RuntimeExecutionPlanDescriptor descriptor) =>
                  HomeWorkflowChoiceOption(
                    label: _executionPlanLabel(context, descriptor.plan),
                    selected: _sameExecutionPlanForUi(
                      descriptor.plan,
                      controller.activeExecutionPlan,
                    ),
                    onSelected: () =>
                        controller.selectExecutionPlan(descriptor.plan),
                  ),
            )
            .toList(growable: false),
      ),
    );
  }
  return HomeWorkflowModeSectionData(
    title: context.shellText.currentMode,
    summary: _modeSummary(context, controller),
    detail: activeCapability?.message,
    choiceGroups: choiceGroups,
  );
}

HomeWorkflowSupportSectionData _mobileHomeSupportSectionData(
  BuildContext context,
  MobileShellController controller, {
  required VoidCallback onOpenActivity,
  required VoidCallback onOpenDiagnostics,
}) {
  final activeMode = controller.activePlatformTunnelMode;
  final activeResult = activeMode == null
      ? null
      : controller.platformTunnelResultFor(activeMode);
  final liveSummary = activeResult == null
      ? context.shellText.noStartupRequestYetShort
      : _platformTunnelResultSummary(context, activeResult);
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
        onPressed: onOpenActivity,
      ),
      HomeWorkflowAction(
        label: context.shellText.openDiagnostics,
        style: HomeWorkflowActionStyle.outlined,
        onPressed: onOpenDiagnostics,
      ),
    ],
  );
}

ProfileRecord? _selectedProfile(MobileShellController controller) {
  final profileId = controller.selectedProfileId?.trim() ?? '';
  if (profileId.isEmpty) {
    return null;
  }
  for (final profile in controller.profiles) {
    if (profile.id == profileId) {
      return profile;
    }
  }
  return null;
}

String _modeSummary(BuildContext context, MobileShellController controller) {
  final copy = context.shellText;
  final mode = controller.activePlatformTunnelMode;
  if (mode == null) {
    return copy.noMobileTunnelModeSelected;
  }
  final modeLabel = mode.label;
  final executionPlan = controller.activeExecutionPlan;
  final routingSummary = _routingSummaryForHome(context, controller);
  if (executionPlan == null) {
    return copy.modeSummary(
      modeLabel: modeLabel,
      routingSummary: routingSummary,
    );
  }
  return copy.modeSummary(
    modeLabel: modeLabel,
    routingSummary: routingSummary,
    executionPath: _executionPlanLabel(context, executionPlan),
  );
}

String _routingSummaryForHome(
  BuildContext context,
  MobileShellController controller,
) {
  final copy = context.shellText;
  if (!controller.activeModeSupportsAppRouting) {
    return copy.perAppRoutingUnavailable;
  }
  final preferences = controller.activePlatformModePreferences;
  final scopeSummary = switch (preferences.applicationRoutingPolicy) {
    PlatformTunnelApplicationRoutingPolicy.allApps =>
      copy.scopeAllInstalledApps,
    PlatformTunnelApplicationRoutingPolicy.allowedPackages =>
      preferences.allowedPackages.isEmpty
          ? copy.scopeIncludedAppsEmpty
          : copy.scopeOnlySelectedApps(preferences.allowedPackages.length),
    PlatformTunnelApplicationRoutingPolicy.disallowedPackages =>
      preferences.disallowedPackages.isEmpty
          ? copy.scopeExcludedAppsEmpty
          : copy.scopeAllExceptSelectedApps(
              preferences.disallowedPackages.length,
            ),
  };
  return copy.routingSummaryWithProfile(
    profileLabel: _underlayRoutePolicyLabel(
      copy,
      preferences.underlayRoutePolicy,
    ),
    scopeSummary: scopeSummary,
  );
}

String _underlayRoutePolicyLabel(
  ShellText copy,
  PlatformTunnelUnderlayRoutePolicy policy,
) {
  return switch (policy) {
    PlatformTunnelUnderlayRoutePolicy.standard => copy.routingProfileStandard,
    PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork =>
      copy.routingProfileDevelopmentWifi,
  };
}

String _executionPlanLabel(BuildContext context, RuntimeExecutionPlan plan) {
  final copy = context.shellText;
  return switch ((plan.engineFamily, plan.carrierFamily)) {
    (RuntimeEngineFamily.wireguardNative, RuntimeCarrierFamily.turnDatagram) =>
      copy.wireGuardNativeOverTurnDatagram,
    (
      RuntimeEngineFamily.wireguardNative,
      RuntimeCarrierFamily.turnDtlsOverlay,
    ) =>
      copy.wireGuardNativeOverTurnDtls,
    (
      RuntimeEngineFamily.wireguardNative,
      RuntimeCarrierFamily.webrtcDataChannel,
    ) =>
      copy.wireGuardNativeOverWebRtc,
    (
      RuntimeEngineFamily.customPacketOverlay,
      RuntimeCarrierFamily.turnDatagram,
    ) =>
      copy.customOverlayOverTurnDatagram,
    (
      RuntimeEngineFamily.customPacketOverlay,
      RuntimeCarrierFamily.turnDtlsOverlay,
    ) =>
      copy.customOverlayOverTurnDtls,
    (
      RuntimeEngineFamily.customPacketOverlay,
      RuntimeCarrierFamily.webrtcDataChannel,
    ) =>
      copy.customOverlayOverWebRtc,
    (RuntimeEngineFamily.proxyCoreAdapter, RuntimeCarrierFamily.turnDatagram) =>
      copy.proxyCoreOverTurnDatagram,
    (
      RuntimeEngineFamily.proxyCoreAdapter,
      RuntimeCarrierFamily.turnDtlsOverlay,
    ) =>
      copy.proxyCoreOverTurnDtls,
    (
      RuntimeEngineFamily.proxyCoreAdapter,
      RuntimeCarrierFamily.webrtcDataChannel,
    ) =>
      copy.proxyCoreOverWebRtc,
    (
      RuntimeEngineFamily.trusttunnelNative,
      RuntimeCarrierFamily.turnDatagram,
    ) =>
      copy.trustTunnelOverTurnDatagram,
    (
      RuntimeEngineFamily.trusttunnelNative,
      RuntimeCarrierFamily.turnDtlsOverlay,
    ) =>
      copy.trustTunnelOverTurnDtls,
    (
      RuntimeEngineFamily.trusttunnelNative,
      RuntimeCarrierFamily.webrtcDataChannel,
    ) =>
      copy.trustTunnelOverWebRtc,
  };
}

bool _sameExecutionPlanForUi(
  RuntimeExecutionPlan left,
  RuntimeExecutionPlan? right,
) {
  if (right == null) {
    return false;
  }
  return left.accessMethod == right.accessMethod &&
      left.carrierFamily == right.carrierFamily &&
      left.engineFamily == right.engineFamily &&
      left.hostAdapter == right.hostAdapter;
}
