import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/mobile_host_bridge.dart';
import 'package:mobile_gui_shell/src/control/mobile_platform_app_inventory.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_controller.dart';
import 'package:mobile_gui_shell/src/ui/owned_browser_challenge.dart';
import 'package:mobile_gui_shell/src/ui/profile_editor.dart';
import 'package:mobile_gui_shell/src/ui/provider_config_editor.dart';

const double _compactNavigationBreakpoint = 840;
const double _providerListDetailBreakpoint = 920;

enum _DashboardDestination { home, profiles, providers, routing, support }

enum _SupportSurface { activity, diagnostics }

enum _ActivitySurface { resolutions, sessions }

enum _DiagnosticsSurface { overview, events }

enum _ProviderChooserSurface { families, templates }

class _ProviderChooserResult {
  const _ProviderChooserResult.family(this.providerId)
    : preset = null,
      userTemplateId = null,
      editUserTemplate = false;

  const _ProviderChooserResult.template(this.preset)
    : providerId = null,
      userTemplateId = null,
      editUserTemplate = false;

  const _ProviderChooserResult.userTemplateUse(this.userTemplateId)
    : providerId = null,
      preset = null,
      editUserTemplate = false;

  const _ProviderChooserResult.userTemplateEdit(this.userTemplateId)
    : providerId = null,
      preset = null,
      editUserTemplate = true;

  final String? providerId;
  final ProviderPreset? preset;
  final String? userTemplateId;
  final bool editUserTemplate;
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
      if (!mounted) {
        return;
      }
      setState(() {
        _destination = _DashboardDestination.home;
      });
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
    final result = await showDialog<_ProviderChooserResult>(
      context: context,
      builder: (BuildContext context) {
        return _DialogSurfaceFrame(
          maxWidth: 640,
          maxHeight: 720,
          child: _ProviderChooserDialog(
            supportedProviders: widget.controller.supportedProviderCatalog,
            providerDescriptors: widget.controller.providerDescriptors,
            userTemplates: widget.controller.providerTemplates,
            presets: widget.controller.presetCatalog,
            busy: widget.controller.busy,
          ),
        );
      },
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
      return;
    }
    final userTemplateId = result.userTemplateId;
    if (userTemplateId != null) {
      if (result.editUserTemplate) {
        widget.controller.selectProviderTemplate(userTemplateId);
        return;
      }
      widget.controller.useProviderTemplate(userTemplateId);
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
                title: 'Import portable profile',
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
        headerAccessory: _HostStatusIndicator(
          controller: widget.controller,
          onOpenDiagnostics: _openDiagnostics,
        ),
        onLaunchChallengeSurface: _launchChallengeSurface,
        openChallengeLabel: _openChallengeLabel,
        showsManualChallengeContinue: _showsManualChallengeContinue,
      ),
      _DashboardDestination.profiles => _ProfilesPage(
        controller: widget.controller,
        onOpenRouting: _openRouting,
        headerAccessory: _HostStatusIndicator(
          controller: widget.controller,
          onOpenDiagnostics: _openDiagnostics,
        ),
      ),
      _DashboardDestination.providers => _ProvidersPage(
        controller: widget.controller,
        headerAccessory: _HostStatusIndicator(
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
        headerAccessory: _HostStatusIndicator(
          controller: widget.controller,
          onOpenDiagnostics: _openDiagnostics,
        ),
      ),
      _DashboardDestination.support => _SupportPage(
        controller: widget.controller,
        supportSurface: _supportSurface,
        activitySurface: _activitySurface,
        diagnosticsSurface: _diagnosticsSurface,
        headerAccessory: _HostStatusIndicator(
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

  NavigationDestination _destinationNavItem(_DashboardDestination destination) {
    return switch (destination) {
      _DashboardDestination.home => const NavigationDestination(
        icon: Icon(Icons.shield_outlined),
        selectedIcon: Icon(Icons.shield),
        label: 'Home',
      ),
      _DashboardDestination.profiles => const NavigationDestination(
        icon: Icon(Icons.folder_outlined),
        selectedIcon: Icon(Icons.folder),
        label: 'Profiles',
      ),
      _DashboardDestination.providers => const NavigationDestination(
        icon: Icon(Icons.cloud_outlined),
        selectedIcon: Icon(Icons.cloud),
        label: 'Providers',
      ),
      _DashboardDestination.routing => const NavigationDestination(
        icon: Icon(Icons.alt_route_outlined),
        selectedIcon: Icon(Icons.alt_route),
        label: 'Routing',
      ),
      _DashboardDestination.support => const NavigationDestination(
        icon: Icon(Icons.support_agent_outlined),
        selectedIcon: Icon(Icons.support_agent),
        label: 'Support',
      ),
    };
  }

  NavigationRailDestination _destinationRailItem(
    _DashboardDestination destination,
  ) {
    return switch (destination) {
      _DashboardDestination.home => const NavigationRailDestination(
        icon: Icon(Icons.shield_outlined),
        selectedIcon: Icon(Icons.shield),
        label: Text('Home'),
      ),
      _DashboardDestination.profiles => const NavigationRailDestination(
        icon: Icon(Icons.folder_outlined),
        selectedIcon: Icon(Icons.folder),
        label: Text('Profiles'),
      ),
      _DashboardDestination.providers => const NavigationRailDestination(
        icon: Icon(Icons.cloud_outlined),
        selectedIcon: Icon(Icons.cloud),
        label: Text('Providers'),
      ),
      _DashboardDestination.routing => const NavigationRailDestination(
        icon: Icon(Icons.alt_route_outlined),
        selectedIcon: Icon(Icons.alt_route),
        label: Text('Routing'),
      ),
      _DashboardDestination.support => const NavigationRailDestination(
        icon: Icon(Icons.support_agent_outlined),
        selectedIcon: Icon(Icons.support_agent),
        label: Text('Support'),
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
                        .map(_destinationRailItem)
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
                      .map(_destinationNavItem)
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
  });

  final MobileShellController controller;
  final VoidCallback onOpenProfiles;
  final void Function({_SupportSurface surface}) onOpenSupport;
  final Widget headerAccessory;
  final Future<void> Function(ChallengeRecord challenge)
  onLaunchChallengeSurface;
  final String Function(ChallengeRecord? challenge) openChallengeLabel;
  final bool Function(ChallengeRecord? challenge) showsManualChallengeContinue;

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
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        _PageHeader(
          title: 'Home',
          subtitle:
              'Pick a profile, finish any provider browser step from here, then turn the current mobile VPN path on or off.',
          trailing: headerAccessory,
        ),
        if (notice != null) ...<Widget>[
          const SizedBox(height: 12),
          _NoticeBanner(message: notice),
        ],
        if (controller.requiresLocalStateReset) ...<Widget>[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: controller.busy
                  ? null
                  : () => unawaited(controller.clearLocalState()),
              child: const Text('Reset local state'),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (controller.profiles.isEmpty)
          _HomeEmptyState(onOpenProfiles: onOpenProfiles)
        else if (selectedProfile != null)
          _HomeProfileCard(profile: selectedProfile),
        if (showRuntimeCards) ...<Widget>[
          const SizedBox(height: 16),
          _HomePrimaryActionCard(
            controller: controller,
            hasSelectedProfile: selectedProfile != null,
            onOpenProfiles: onOpenProfiles,
            tunnelReady: tunnelReady,
            challenge: homeChallenge,
            onLaunchChallengeSurface: onLaunchChallengeSurface,
            openChallengeLabel: openChallengeLabel,
            showsManualChallengeContinue: showsManualChallengeContinue,
          ),
          const SizedBox(height: 16),
          _HomeModeCard(controller: controller),
          const SizedBox(height: 16),
          _HomeSupportActions(
            controller: controller,
            onOpenActivity: () =>
                onOpenSupport(surface: _SupportSurface.activity),
            onOpenDiagnostics: () =>
                onOpenSupport(surface: _SupportSurface.diagnostics),
          ),
        ],
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
      controller.selectProfile(profileId);
    }
    controller.showProfileWorkspace();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            _ProfileWorkspacePage(controller: controller, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide =
        MediaQuery.sizeOf(context).width >= _compactNavigationBreakpoint;
    final notice = controller.surfaceNotice;
    final menuActions = <_CardActionEntry>[
      _CardActionEntry(
        id: 'import-invite',
        label: 'Import invite',
        onSelected: () async {
          _openProfileWorkspace(
            context,
            title: 'Import invite',
            resetDraft: true,
          );
        },
      ),
      if (!wide && controller.activeModeSupportsAppRouting)
        _CardActionEntry(
          id: 'routing',
          label: 'Routing',
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
              child: const _PageHeader(
                title: 'Profiles',
                subtitle: 'Choose a saved profile or add a new one for Home.',
              ),
            ),
            const SizedBox(width: 8),
            headerAccessory,
            const SizedBox(width: 12),
            _ActionOverflowButton(
              tooltip: 'Profiles actions',
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
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: controller.busy
                ? null
                : () => _openProfileWorkspace(
                    context,
                    title: 'Add profile',
                    resetDraft: true,
                  ),
            icon: const Icon(Icons.add),
            label: const Text('Add profile'),
          ),
        ),
        const SizedBox(height: 20),
        _ProfilesListSection(
          controller: controller,
          onEditProfile: (ProfileRecord profile) => _openProfileWorkspace(
            context,
            title: 'Edit profile',
            profileId: profile.id,
          ),
        ),
      ],
    );
  }
}

class _ProfilesListSection extends StatelessWidget {
  const _ProfilesListSection({
    required this.controller,
    required this.onEditProfile,
  });

  final MobileShellController controller;
  final ValueChanged<ProfileRecord> onEditProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (controller.profiles.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'No saved profiles yet',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Create or import a profile, then use Home for the one-tap VPN workflow.',
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
              index < controller.profiles.length;
              index++
            ) ...<Widget>[
              _ProfileListItem(
                profile: controller.profiles[index],
                selected:
                    controller.selectedProfileId ==
                    controller.profiles[index].id,
                onSelect: () =>
                    controller.selectProfile(controller.profiles[index].id),
                onEdit: () => onEditProfile(controller.profiles[index]),
              ),
              if (index != controller.profiles.length - 1)
                const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileListItem extends StatelessWidget {
  const _ProfileListItem({
    required this.profile,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
  });

  final ProfileRecord profile;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = profile.name.trim().isEmpty
        ? profile.id
        : profile.name.trim();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      onTap: onSelect,
      leading: CircleAvatar(
        backgroundColor: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        foregroundColor: selected
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
            _profileSummary(profile),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (selected) ...<Widget>[
            const SizedBox(height: 8),
            _StatusChip(label: 'Selected for Home', accent: true),
          ],
        ],
      ),
      trailing: IconButton(
        tooltip: 'Edit profile',
        onPressed: onEdit,
        icon: const Icon(Icons.edit_outlined),
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
        final hasSavedProfile = controller.selectedProfileId != null;
        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: <Widget>[
              IconButton(
                key: const ValueKey<String>('profile-workspace-save-action'),
                tooltip: 'Save profile',
                onPressed: controller.busy
                    ? null
                    : () => unawaited(controller.saveDraft()),
                icon: const Icon(Icons.save_outlined),
              ),
              if (hasSavedProfile)
                IconButton(
                  key: const ValueKey<String>(
                    'profile-workspace-resolve-action',
                  ),
                  tooltip: 'Resolve invite',
                  onPressed: controller.busy
                      ? null
                      : () => unawaited(controller.startResolutionFromDraft()),
                  icon: const Icon(Icons.travel_explore_outlined),
                ),
              if (hasSavedProfile)
                IconButton(
                  key: const ValueKey<String>('profile-workspace-vpn-action'),
                  tooltip: _profileWorkspaceVpnLabel(controller),
                  onPressed: _profileWorkspaceVpnAction(controller),
                  icon: Icon(_profileWorkspaceVpnIcon(controller)),
                ),
            ],
          ),
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

String _profileWorkspaceVpnLabel(MobileShellController controller) {
  final mode = controller.activePlatformTunnelMode;
  if (mode == null) {
    return 'Turn on VPN';
  }
  final ready = controller.platformTunnelResultFor(mode)?.ready == true;
  return ready ? 'Turn off VPN' : 'Turn on VPN';
}

IconData _profileWorkspaceVpnIcon(MobileShellController controller) {
  final mode = controller.activePlatformTunnelMode;
  final ready =
      mode != null && controller.platformTunnelResultFor(mode)?.ready == true;
  return ready ? Icons.vpn_lock_outlined : Icons.shield_outlined;
}

VoidCallback? _profileWorkspaceVpnAction(MobileShellController controller) {
  final mode = controller.activePlatformTunnelMode;
  if (controller.busy ||
      controller.hostConnection?.isReady != true ||
      mode == null) {
    return null;
  }
  final ready = controller.platformTunnelResultFor(mode)?.ready == true;
  return () => unawaited(
    ready
        ? controller.stopPlatformTunnel(mode)
        : controller.startPlatformTunnel(mode),
  );
}

class _ProvidersPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final notice = controller.surfaceNotice;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final wide = constraints.maxWidth >= _providerListDetailBreakpoint;
        final showingDetail =
            controller.workflowSurface ==
                MobileWorkflowSurface.providerConfig ||
            controller.workflowSurface ==
                MobileWorkflowSurface.providerTemplate;
        final rootPanel = _ProviderRecordsRootSection(controller: controller);
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
            onClose: onReturnToRoot,
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
            onClose: onReturnToRoot,
            showCloseButton: wide,
          ),
          _ => const SizedBox.shrink(),
        };
        final rootChildren = <Widget>[
          _PageHeader(
            title: 'Providers',
            subtitle:
                'Choose a saved reusable provider or add a new one for Profiles.',
            trailing: headerAccessory,
          ),
          if (notice != null) ...<Widget>[
            const SizedBox(height: 12),
            _NoticeBanner(message: notice),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey<String>('managed-provider-create-button'),
              onPressed: controller.busy
                  ? null
                  : () => unawaited(onOpenNewProviderFlow()),
              icon: const Icon(Icons.add),
              label: const Text('Add provider'),
            ),
          ),
          const SizedBox(height: 20),
          rootPanel,
        ];

        if (wide && showingDetail) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
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
                Row(
                  children: <Widget>[
                    OutlinedButton.icon(
                      key: const ValueKey<String>('providers-back-button'),
                      onPressed: onReturnToRoot,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to providers'),
                    ),
                    const Spacer(),
                    headerAccessory,
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

String _profileSummary(ProfileRecord profile) {
  final provider = profile.spec.provider.trim().isEmpty
      ? 'No provider'
      : profile.spec.provider.trim();
  final link = profile.spec.link.trim();
  if (link.isEmpty) {
    return provider;
  }
  final uri = Uri.tryParse(link);
  if (uri == null || uri.host.isEmpty) {
    return '$provider • input configured';
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _PageHeader(
                title: 'Support',
                subtitle:
                    'Activity, failures, logs, and diagnostics stay explicit but secondary to the main VPN workflow.',
                trailing: headerAccessory,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  ChoiceChip(
                    selected: supportSurface == _SupportSurface.activity,
                    label: Text('Activity', style: theme.textTheme.labelLarge),
                    onSelected: (_) =>
                        onSupportSurfaceChanged(_SupportSurface.activity),
                  ),
                  ChoiceChip(
                    selected: supportSurface == _SupportSurface.diagnostics,
                    label: Text(
                      'Diagnostics',
                      style: theme.textTheme.labelLarge,
                    ),
                    onSelected: (_) =>
                        onSupportSurfaceChanged(_SupportSurface.diagnostics),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: switch (supportSurface) {
            _SupportSurface.activity => _ActivityPage(
              controller: controller,
              surface: activitySurface,
              onLaunchChallengeSurface: onLaunchChallengeSurface,
              openChallengeLabel: openChallengeLabel,
              showsManualChallengeContinue: showsManualChallengeContinue,
              onSurfaceChanged: onActivitySurfaceChanged,
            ),
            _SupportSurface.diagnostics => _DiagnosticsPage(
              controller: controller,
              surface: diagnosticsSurface,
              onSurfaceChanged: onDiagnosticsSurfaceChanged,
            ),
          },
        ),
      ],
    );
  }
}

class _RoutingPage extends StatefulWidget {
  const _RoutingPage({
    required this.controller,
    this.onBack,
    required this.onOpenProfiles,
    required this.headerAccessory,
  });

  final MobileShellController controller;
  final VoidCallback? onBack;
  final VoidCallback onOpenProfiles;
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

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);
    final mode = controller.activePlatformTunnelMode;
    final preferences = controller.activePlatformModePreferences;
    final routingPolicy = preferences.applicationRoutingPolicy;
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

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        if (widget.onBack != null) ...<Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _PageHeader(
          title: 'Routing',
          subtitle:
              'Choose whether Android system VPN covers all apps, only selected apps, or every app except the selected list.',
          trailing: widget.headerAccessory,
        ),
        if (controller.surfaceNotice != null) ...<Widget>[
          const SizedBox(height: 12),
          _NoticeBanner(message: controller.surfaceNotice!),
        ],
        const SizedBox(height: 16),
        if (!controller.activeModeSupportsAppRouting || mode == null)
          _RoutingUnavailableCard(onOpenProfiles: widget.onOpenProfiles)
        else ...<Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${mode.label} scope',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _routingSummaryForHome(controller),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      ChoiceChip(
                        selected:
                            routingPolicy ==
                            PlatformTunnelApplicationRoutingPolicy.allApps,
                        label: const Text('All apps'),
                        onSelected: (_) =>
                            controller.updateApplicationRoutingPolicy(
                              PlatformTunnelApplicationRoutingPolicy.allApps,
                            ),
                      ),
                      ChoiceChip(
                        selected:
                            routingPolicy ==
                            PlatformTunnelApplicationRoutingPolicy
                                .allowedPackages,
                        label: const Text('Included apps'),
                        onSelected: (_) =>
                            controller.updateApplicationRoutingPolicy(
                              PlatformTunnelApplicationRoutingPolicy
                                  .allowedPackages,
                            ),
                      ),
                      ChoiceChip(
                        selected:
                            routingPolicy ==
                            PlatformTunnelApplicationRoutingPolicy
                                .disallowedPackages,
                        label: const Text('Excluded apps'),
                        onSelected: (_) =>
                            controller.updateApplicationRoutingPolicy(
                              PlatformTunnelApplicationRoutingPolicy
                                  .disallowedPackages,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (routingPolicy == PlatformTunnelApplicationRoutingPolicy.allApps)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'All installed apps will use the Android system VPN path for this mobile mode.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            )
          else ...<Widget>[
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search apps',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
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
                        child: const Text('Retry app scan'),
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
                        ? 'No installed apps were reported by the Android shell bridge.'
                        : 'No installed apps match this search.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: filteredApps
                        .map<Widget>((MobilePlatformApp app) {
                          final selected = selectedPackages.contains(
                            app.packageName,
                          );
                          return CheckboxListTile(
                            value: selected,
                            onChanged: (bool? nextValue) {
                              controller.updateRoutingPackageSelection(
                                packageName: app.packageName,
                                selected: nextValue ?? false,
                              );
                            },
                            title: Text(app.label),
                            subtitle: Text(app.packageName),
                            secondary: app.systemApp
                                ? const Icon(Icons.memory_outlined)
                                : const Icon(Icons.apps_outlined),
                          );
                        })
                        .toList(growable: false),
                  ),
                ),
              ),
          ],
        ],
      ],
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState({required this.onOpenProfiles});

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
              'No saved profiles yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create or import a profile first, then come back here for the fast VPN toggle.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton(
                  onPressed: onOpenProfiles,
                  child: const Text('Add profile'),
                ),
                FilledButton.tonal(
                  onPressed: onOpenProfiles,
                  child: const Text('Import invite'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeProfileCard extends StatelessWidget {
  const _HomeProfileCard({required this.profile});

  final ProfileRecord profile;

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
            Text(
              'Current profile',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              profile.name.isEmpty ? profile.id : profile.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${profile.spec.provider} -> ${profile.spec.peerAddress}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Listening on ${profile.spec.listenAddress}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeModeCard extends StatelessWidget {
  const _HomeModeCard({required this.controller});

  final MobileShellController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeMode = controller.activePlatformTunnelMode;
    final activeCapability = controller.activePlatformTunnelCapability;
    final executionPlans = activeMode == null
        ? const <RuntimeExecutionPlanDescriptor>[]
        : controller.executionPlanOptionsForMode(activeMode);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.22,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Current mode',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              activeMode == null
                  ? 'The connected host has not advertised a mobile tunnel mode yet.'
                  : _modeSummary(controller),
              style: theme.textTheme.bodySmall,
            ),
            if (activeCapability?.message.isNotEmpty == true) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                activeCapability!.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (controller.platformTunnels.length > 1) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: controller.platformTunnels
                    .map((capability) {
                      return ChoiceChip(
                        selected:
                            controller.activePlatformTunnelMode ==
                            capability.mode,
                        label: Text(capability.mode.label),
                        onSelected: (_) => controller.selectPlatformTunnelMode(
                          capability.mode,
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ],
            if (executionPlans.length > 1) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                'Execution path',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: executionPlans
                    .map((descriptor) {
                      return ChoiceChip(
                        selected: _sameExecutionPlanForUi(
                          descriptor.plan,
                          controller.activeExecutionPlan,
                        ),
                        label: Text(_executionPlanLabel(descriptor.plan)),
                        onSelected: (_) =>
                            controller.selectExecutionPlan(descriptor.plan),
                      );
                    })
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomePrimaryActionCard extends StatelessWidget {
  const _HomePrimaryActionCard({
    required this.controller,
    required this.hasSelectedProfile,
    required this.onOpenProfiles,
    required this.tunnelReady,
    required this.challenge,
    required this.onLaunchChallengeSurface,
    required this.openChallengeLabel,
    required this.showsManualChallengeContinue,
  });

  final MobileShellController controller;
  final bool hasSelectedProfile;
  final VoidCallback onOpenProfiles;
  final bool tunnelReady;
  final ChallengeRecord? challenge;
  final Future<void> Function(ChallengeRecord challenge)
  onLaunchChallengeSurface;
  final String Function(ChallengeRecord? challenge) openChallengeLabel;
  final bool Function(ChallengeRecord? challenge) showsManualChallengeContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = controller.activePlatformTunnelMode;
    final activeChallenge = challenge;
    final needsProfileSelection = !tunnelReady && !hasSelectedProfile;
    final stateTone = switch ((
      activeChallenge,
      tunnelReady,
      needsProfileSelection,
    )) {
      (final ChallengeRecord _, _, _) => const (
        'Provider step',
        Color(0xFFFFF3D6),
        Color(0xFFE4C16F),
        Color(0xFF8A4B00),
        Icons.travel_explore_rounded,
        Icons.open_in_browser_rounded,
      ),
      (null, true, _) => const (
        'Connection live',
        Color(0xFFE2F5E9),
        Color(0xFF88C9A4),
        Color(0xFF17693F),
        Icons.shield_rounded,
        Icons.power_settings_new_rounded,
      ),
      (null, false, true) => const (
        'Setup needed',
        Color(0xFFF0F3F7),
        Color(0xFFBAC3CF),
        Color(0xFF4A5868),
        Icons.folder_open_rounded,
        Icons.arrow_forward_rounded,
      ),
      (null, false, false) => const (
        'Main action',
        Color(0xFFE3F0FF),
        Color(0xFF90B8E6),
        Color(0xFF0D5EAF),
        Icons.power_rounded,
        Icons.power_settings_new_rounded,
      ),
    };
    final title = switch ((
      activeChallenge,
      tunnelReady,
      needsProfileSelection,
    )) {
      (final ChallengeRecord _, _, _) => 'Finish provider validation',
      (null, true, _) => 'VPN is on',
      (null, false, true) => 'Profile required',
      (null, false, false) => 'VPN is off',
    };
    final subtitle = switch ((
      activeChallenge,
      tunnelReady,
      needsProfileSelection,
    )) {
      (final ChallengeRecord challenge, _, _) =>
        controller.challengeRequiresOwnedBrowser(challenge)
            ? (challenge.prompt?.trim().isNotEmpty == true
                  ? challenge.prompt!
                  : 'Continue the provider flow in the in-app browser before VPN can start.')
            : 'Open the required browser step from Home, then return here and confirm completion before VPN can start.',
      (null, true, _) => 'Disconnect the current mobile VPN path from here.',
      (null, false, true) =>
        'Choose or finish a profile in Profiles before starting the current mobile VPN path.',
      (null, false, false) => 'Start the current mobile VPN path from here.',
    };
    final buttonLabel = switch ((
      activeChallenge,
      tunnelReady,
      needsProfileSelection,
    )) {
      (final ChallengeRecord challenge, _, _) => openChallengeLabel(challenge),
      (null, true, _) => 'Turn off VPN',
      (null, false, true) => 'Continue in Profiles',
      (null, false, false) => 'Turn on VPN',
    };
    final VoidCallback? onPressed;
    if (activeChallenge != null) {
      onPressed = controller.busy
          ? null
          : () => unawaited(onLaunchChallengeSurface(activeChallenge));
    } else if (needsProfileSelection) {
      onPressed = controller.busy ? null : onOpenProfiles;
    } else if (controller.busy ||
        controller.hostConnection?.isReady != true ||
        mode == null) {
      onPressed = null;
    } else {
      onPressed = () => unawaited(
        tunnelReady
            ? controller.stopPlatformTunnel(mode)
            : controller.startPlatformTunnel(mode),
      );
    }
    return Card(
      color: stateTone.$2,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              stateTone.$1,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: stateTone.$4,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: stateTone.$3.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(stateTone.$5, color: stateTone.$4, size: 28),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(subtitle, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            if (activeChallenge != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                'Challenge: ${activeChallenge.kind}',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPressed,
                icon: Icon(stateTone.$6, size: 22),
                style: FilledButton.styleFrom(
                  backgroundColor: stateTone.$4,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(68),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                label: Text(buttonLabel),
              ),
            ),
            if (activeChallenge != null) ...<Widget>[
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  if (showsManualChallengeContinue(activeChallenge))
                    OutlinedButton(
                      onPressed: controller.busy
                          ? null
                          : () => unawaited(
                              controller.continueChallenge(activeChallenge.id),
                            ),
                      child: const Text("I've completed it"),
                    ),
                  TextButton(
                    onPressed: controller.busy
                        ? null
                        : () => unawaited(
                            controller.cancelChallenge(activeChallenge.id),
                          ),
                    child: const Text('Cancel challenge'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeSupportActions extends StatelessWidget {
  const _HomeSupportActions({
    required this.controller,
    required this.onOpenActivity,
    required this.onOpenDiagnostics,
  });

  final MobileShellController controller;
  final VoidCallback onOpenActivity;
  final VoidCallback onOpenDiagnostics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeMode = controller.activePlatformTunnelMode;
    final activeResult = activeMode == null
        ? null
        : controller.platformTunnelResultFor(activeMode);
    final liveSummary = activeResult == null
        ? 'No startup request yet.'
        : _platformTunnelResultSummary(activeResult);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Need deeper detail?',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Resolutions ${controller.resolutions.length} · Sessions ${controller.sessions.length} · $liveSummary',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            FilledButton.tonal(
              onPressed: onOpenActivity,
              child: const Text('Open activity'),
            ),
            OutlinedButton(
              onPressed: onOpenDiagnostics,
              child: const Text('Open diagnostics'),
            ),
          ],
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
              'Routing is unavailable for this mode',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Only mobile modes that support per-app scope expose this surface. Pick another mode from home if the host advertises one.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            FilledButton.tonal(
              onPressed: onOpenProfiles,
              child: const Text('Open profiles'),
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
    final theme = Theme.of(context);
    if (controller.managedProviders.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'No saved providers yet',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Add a provider, then reuse it from Profiles.',
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
              index < controller.managedProviders.length;
              index++
            ) ...<Widget>[
              _ManagedProviderListItem(
                provider: controller.managedProviders[index],
                selected:
                    controller.workflowSurface ==
                        MobileWorkflowSurface.providerConfig &&
                    controller.selectedManagedProviderId ==
                        controller.managedProviders[index].id,
                onSelect: () => controller.selectManagedProvider(
                  controller.managedProviders[index].id,
                ),
              ),
              if (index != controller.managedProviders.length - 1)
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
    required this.onSelect,
  });

  final ManagedProviderRecord provider;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = provider.name.trim().isEmpty ? provider.id : provider.name;
    final familyTitle =
        supportedProviderDefinitionFor(provider.provider)?.title ??
        provider.provider;

    return ListTile(
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
            'Type: $familyTitle',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Used in Profiles',
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
    );
  }
}

class _ProviderChooserDialog extends StatefulWidget {
  const _ProviderChooserDialog({
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
  State<_ProviderChooserDialog> createState() => _ProviderChooserDialogState();
}

class _ProviderChooserDialogState extends State<_ProviderChooserDialog> {
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
    final filteredUserTemplates = widget.userTemplates
        .where((ProviderTemplateRecord template) {
          if (query.isEmpty) {
            return true;
          }
          final familyTitle =
              supportedProviderDefinitionFor(template.provider)?.title ?? '';
          final haystack =
              '${template.name} ${template.provider} $familyTitle ${template.availability.message}'
                  .toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
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
        mainAxisSize: MainAxisSize.min,
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
                      'Create provider',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _surface == _ProviderChooserSurface.families
                          ? 'Choose a provider type and configure a new saved provider.'
                          : 'Use a template to prefill a new provider. Templates are starting points, not saved providers.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const ValueKey<String>('provider-chooser-close-button'),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
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
                  'Provider types',
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
                label: Text('Templates', style: theme.textTheme.labelLarge),
                onSelected: (_) {
                  setState(() {
                    _surface = _ProviderChooserSurface.templates;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: switch (_surface) {
              _ProviderChooserSurface.families => ListView(
                primary: false,
                shrinkWrap: true,
                children: <Widget>[
                  if (widget.supportedProviders.isEmpty)
                    Text(
                      'This build does not advertise any shipped provider types yet.',
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
                                            ? 'Available'
                                            : 'Unavailable',
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
                primary: false,
                shrinkWrap: true,
                children: <Widget>[
                  TextField(
                    key: const ValueKey<String>(
                      'provider-template-search-field',
                    ),
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search templates',
                      prefixIcon: Icon(Icons.search),
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
                    'My templates',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (filteredUserTemplates.isEmpty)
                    Text(
                      widget.userTemplates.isEmpty
                          ? 'No saved templates yet. Save a provider as a template to reuse it here.'
                          : 'No saved templates match the current search.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    ...filteredUserTemplates.map((
                      ProviderTemplateRecord template,
                    ) {
                      final familyTitle =
                          supportedProviderDefinitionFor(
                            template.provider,
                          )?.title ??
                          template.provider;
                      final templateTitle = template.name.trim().isEmpty
                          ? template.id
                          : template.name.trim();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          key: ValueKey<String>(
                            'user-template-item-${template.id}',
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
                                      templateTitle,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  _StatusChip(
                                    label: template.availability.state.label,
                                    accent: template.isAvailable,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Type: $familyTitle',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Prefills new providers',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (template
                                  .availability
                                  .message
                                  .isNotEmpty) ...<Widget>[
                                const SizedBox(height: 4),
                                Text(
                                  template.availability.message,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  FilledButton.tonal(
                                    key: ValueKey<String>(
                                      'user-template-use-${template.id}',
                                    ),
                                    onPressed: widget.busy
                                        ? null
                                        : () {
                                            Navigator.of(context).pop(
                                              _ProviderChooserResult.userTemplateUse(
                                                template.id,
                                              ),
                                            );
                                          },
                                    child: const Text('Use template'),
                                  ),
                                  OutlinedButton(
                                    key: ValueKey<String>(
                                      'user-template-edit-${template.id}',
                                    ),
                                    onPressed: widget.busy
                                        ? null
                                        : () {
                                            Navigator.of(context).pop(
                                              _ProviderChooserResult.userTemplateEdit(
                                                template.id,
                                              ),
                                            );
                                          },
                                    child: const Text('Edit template'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 12),
                  Text(
                    'Shipped templates',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (filteredPresets.isEmpty)
                    Text(
                      'No shipped templates match the current search.',
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
                                        ? 'Available'
                                        : 'Unavailable',
                                    accent: availability.isAvailable,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Type: $familyTitle',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Starting point for new providers',
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
                                'Read-only shipped template',
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
                                child: const Text('Use template'),
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
                  if (controller.surfaceNotice != null) ...<Widget>[
                    const SizedBox(height: 12),
                    _NoticeBanner(message: controller.surfaceNotice!),
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
    final tone = _hostIndicatorTone(controller);
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
      tone.$3.withValues(
        alpha: isBlocked
            ? 0.08
            : isReady
            ? 0.04
            : 0.06,
      ),
      theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.82),
    );
    final borderColor = Color.alphaBlend(
      tone.$3.withValues(
        alpha: isBlocked
            ? 0.22
            : isReady
            ? 0.16
            : 0.18,
      ),
      theme.colorScheme.outlineVariant.withValues(alpha: 0.92),
    );
    final iconColor = Color.alphaBlend(
      tone.$3.withValues(
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
                    child: _HostStatusSheet(
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
                      Icon(tone.$4, color: iconColor, size: 18),
                      Positioned(
                        top: 7,
                        right: 7,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: tone.$3,
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

class _HostStatusSheet extends StatelessWidget {
  const _HostStatusSheet({
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
    final tone = _hostIndicatorTone(controller);

    return SingleChildScrollView(
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
                  color: tone.$2,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(tone.$4, color: tone.$3, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                      controller.hostStatusMessage ??
                          'Waiting for mobile host bridge negotiation.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Close',
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
              _Tag(label: 'GUI ${controller.appBuild.shortLabel}'),
              if (hostInfo != null)
                _Tag(label: 'Host ${hostInfo.build.shortLabel}'),
              if (hostInfo != null)
                _Tag(label: 'Contract ${hostInfo.contractVersion}'),
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
                child: const Text('Open diagnostics'),
              ),
              FilledButton.tonal(
                onPressed: controller.busy || controller.requiresLocalStateReset
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
                    'This mobile slice renders typed host capability and startup-stage results for the reported platform modes. Use the controls below to start or disconnect supported system-tunnel paths.',
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
                    onStop: () =>
                        controller.stopPlatformTunnel(capability.mode),
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
    required this.onStop,
  });

  final PlatformTunnelCapability capability;
  final PlatformTunnelStartResult? result;
  final bool busy;
  final bool ready;
  final Future<void> Function() onStart;
  final Future<void> Function() onStop;

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
          if (result?.ready == true)
            OutlinedButton(
              onPressed: busy || !ready ? null : () => unawaited(onStop()),
              child: const Text('Disconnect VPN'),
            )
          else
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

(String, Color, Color, IconData) _hostIndicatorTone(
  MobileShellController controller,
) {
  final connection = controller.hostConnection;
  if (controller.requiresLocalStateReset) {
    return (
      'Reset needed',
      const Color(0xFFFFE3E0),
      const Color(0xFFB3261E),
      Icons.error_rounded,
    );
  }
  return switch (connection?.state) {
    MobileHostLifecycleState.ready
        when controller.status == ShellStatus.ready =>
      (
        'Host ready',
        const Color(0xFFE2F4E8),
        const Color(0xFF1E6A3B),
        Icons.check_circle_rounded,
      ),
    MobileHostLifecycleState.incompatible => (
      'Host incompatible',
      const Color(0xFFFFE3E0),
      const Color(0xFFB3261E),
      Icons.sync_problem_rounded,
    ),
    MobileHostLifecycleState.failed || MobileHostLifecycleState.unavailable => (
      'Host blocked',
      const Color(0xFFFFE3E0),
      const Color(0xFFB3261E),
      Icons.error_rounded,
    ),
    _ => (
      'Connecting',
      const Color(0xFFE5ECF6),
      const Color(0xFF35516D),
      Icons.sync_rounded,
    ),
  };
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

String _modeSummary(MobileShellController controller) {
  final mode = controller.activePlatformTunnelMode;
  if (mode == null) {
    return 'No mobile tunnel mode is currently selected.';
  }
  final modeLabel = switch (mode) {
    PlatformTunnelMode.androidVpnService => 'Android system VPN mode',
    PlatformTunnelMode.appleNetworkExtension => 'Apple network extension mode',
    PlatformTunnelMode.windowsWintun => 'Windows Wintun mode',
    PlatformTunnelMode.linuxTun => 'Linux TUN mode',
  };
  final executionPlan = controller.activeExecutionPlan;
  final routingSummary = _routingSummaryForHome(controller);
  if (executionPlan == null) {
    return '$modeLabel. $routingSummary';
  }
  return '$modeLabel. $routingSummary Execution path: ${_executionPlanLabel(executionPlan)}.';
}

String _routingSummaryForHome(MobileShellController controller) {
  if (!controller.activeModeSupportsAppRouting) {
    return 'Per-app routing is unavailable for this mobile mode.';
  }
  final preferences = controller.activePlatformModePreferences;
  return switch (preferences.applicationRoutingPolicy) {
    PlatformTunnelApplicationRoutingPolicy.allApps =>
      'Scope: all installed apps.',
    PlatformTunnelApplicationRoutingPolicy.allowedPackages =>
      preferences.allowedPackages.isEmpty
          ? 'Scope: included apps, but no apps are selected yet.'
          : 'Scope: only ${preferences.allowedPackages.length} selected apps.',
    PlatformTunnelApplicationRoutingPolicy.disallowedPackages =>
      preferences.disallowedPackages.isEmpty
          ? 'Scope: excluded apps, but no apps are selected yet.'
          : 'Scope: all apps except ${preferences.disallowedPackages.length} selected apps.',
  };
}

String _executionPlanLabel(RuntimeExecutionPlan plan) {
  final engine = switch (plan.engineFamily) {
    RuntimeEngineFamily.wireguardNative => 'WireGuard native',
    RuntimeEngineFamily.customPacketOverlay => 'Custom packet overlay',
    RuntimeEngineFamily.proxyCoreAdapter => 'Proxy core adapter',
    RuntimeEngineFamily.trusttunnelNative => 'TrustTunnel native',
  };
  final carrier = switch (plan.carrierFamily) {
    RuntimeCarrierFamily.turnDatagram => 'TURN datagram',
    RuntimeCarrierFamily.turnDtlsOverlay => 'TURN DTLS overlay',
    RuntimeCarrierFamily.webrtcDataChannel => 'WebRTC data channel',
  };
  return '$engine over $carrier';
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

String _twoDigits(int value) => value.toString().padLeft(2, '0');
