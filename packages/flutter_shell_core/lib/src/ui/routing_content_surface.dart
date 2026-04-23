import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';

import '../control/control_plane_models.dart';
import 'shell_visuals.dart';

enum RoutingContentSurfaceVariant { desktop, mobile }

class RoutingContentSurface extends StatefulWidget {
  const RoutingContentSurface({
    super.key,
    required this.variant,
    required this.spec,
    required this.busy,
    required this.hostReady,
    required this.platformTunnels,
    required this.platformTunnelResultFor,
    required this.onSpecChanged,
    required this.onOpenProfiles,
    required this.onStartPlatformTunnel,
    this.selectedProfileName,
    this.selectedProfileProvider,
    this.onSave,
    this.onStartProfile,
    this.onStopPlatformTunnel,
  });

  final RoutingContentSurfaceVariant variant;
  final ProfileSpec spec;
  final bool busy;
  final bool hostReady;
  final List<PlatformTunnelCapability> platformTunnels;
  final PlatformTunnelStartResult? Function(PlatformTunnelMode mode)
  platformTunnelResultFor;
  final ValueChanged<ProfileSpec> onSpecChanged;
  final VoidCallback onOpenProfiles;
  final Future<void> Function(PlatformTunnelMode mode) onStartPlatformTunnel;
  final String? selectedProfileName;
  final String? selectedProfileProvider;
  final Future<void> Function()? onSave;
  final Future<void> Function()? onStartProfile;
  final Future<void> Function(PlatformTunnelMode mode)? onStopPlatformTunnel;

  @override
  State<RoutingContentSurface> createState() => _RoutingContentSurfaceState();
}

class _RoutingContentSurfaceState extends State<RoutingContentSurface> {
  late final TextEditingController _listenAddressController;
  late final TextEditingController _peerAddressController;
  late final TextEditingController _connectionsController;
  late final TextEditingController _turnServerController;
  late final TextEditingController _turnPortController;
  late final TextEditingController _bindInterfaceController;

  bool get _desktop => widget.variant == RoutingContentSurfaceVariant.desktop;

  @override
  void initState() {
    super.initState();
    _listenAddressController = TextEditingController();
    _peerAddressController = TextEditingController();
    _connectionsController = TextEditingController();
    _turnServerController = TextEditingController();
    _turnPortController = TextEditingController();
    _bindInterfaceController = TextEditingController();
    _syncFromSpec();
  }

  @override
  void didUpdateWidget(covariant RoutingContentSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spec != widget.spec) {
      _syncFromSpec();
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

  void _syncFromSpec() {
    final spec = widget.spec;
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
    widget.onSpecChanged(update(widget.spec));
  }

  @override
  Widget build(BuildContext context) {
    final surfaceKey = ValueKey<String>(
      'routing-content-surface-${widget.variant.name}',
    );
    final content = switch (widget.variant) {
      RoutingContentSurfaceVariant.desktop => _buildDesktopSurface(context),
      RoutingContentSurfaceVariant.mobile => _buildMobileSurface(context),
    };
    return KeyedSubtree(key: surfaceKey, child: content);
  }

  Widget _buildDesktopSurface(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final stacked = constraints.maxWidth < 1320;
        final specCard = _RoutingSpecCard(
          variant: widget.variant,
          title: context.shellText.desktopProfileSettings,
          subtitle: context.shellText.desktopEditableParametersReady,
          child: _buildSpecForm(context),
        );
        final tunnelPanel = _RoutingPlatformTunnelPanel(
          variant: widget.variant,
          hostReady: widget.hostReady,
          busy: widget.busy,
          platformTunnels: widget.platformTunnels,
          platformTunnelResultFor: widget.platformTunnelResultFor,
          onStartPlatformTunnel: widget.onStartPlatformTunnel,
          onStopPlatformTunnel: widget.onStopPlatformTunnel,
        );
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: specCard),
              const SizedBox(height: 12),
              SizedBox(height: 320, child: tunnelPanel),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(child: specCard),
            const SizedBox(width: 12),
            SizedBox(width: 420, child: tunnelPanel),
          ],
        );
      },
    );
  }

  Widget _buildMobileSurface(BuildContext context) {
    final summary = _selectedProfileSummary(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _RoutingSpecCard(
          variant: widget.variant,
          title: context.shellText.currentProfile,
          subtitle: summary,
          child: _buildSpecForm(context),
        ),
        const SizedBox(height: 12),
        _RoutingPlatformTunnelPanel(
          variant: widget.variant,
          hostReady: widget.hostReady,
          busy: widget.busy,
          platformTunnels: widget.platformTunnels,
          platformTunnelResultFor: widget.platformTunnelResultFor,
          onStartPlatformTunnel: widget.onStartPlatformTunnel,
          onStopPlatformTunnel: widget.onStopPlatformTunnel,
        ),
      ],
    );
  }

  String _selectedProfileSummary(BuildContext context) {
    final profileName = widget.selectedProfileName?.trim() ?? '';
    final provider = widget.selectedProfileProvider?.trim() ?? '';
    if (profileName.isNotEmpty && provider.isNotEmpty) {
      return '$profileName · $provider';
    }
    if (profileName.isNotEmpty) {
      return profileName;
    }
    if (provider.isNotEmpty) {
      return provider;
    }
    return context.shellText.chooseOrFinishProfileBeforeStartingVpn;
  }

  Widget _buildSpecForm(BuildContext context) {
    final copy = context.shellText;
    final fields = <Widget>[
      _RoutingTextField(
        key: _fieldKey('listen-address'),
        controller: _listenAddressController,
        label: copy.localUdpListen,
        onChanged: (String value) => _updateSpec(
          (ProfileSpec current) =>
              current.copyWith(listenAddress: value.trim()),
        ),
      ),
      _formSpacing(),
      _RoutingTextField(
        key: _fieldKey('peer-address'),
        controller: _peerAddressController,
        label: copy.peerAddress,
        onChanged: (String value) => _updateSpec(
          (ProfileSpec current) => current.copyWith(peerAddress: value.trim()),
        ),
      ),
      _formSpacing(),
      _RoutingTextField(
        key: _fieldKey('connections'),
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
      _formSpacing(height: 16),
      DropdownButtonFormField<TransportMode>(
        key: _fieldKey('mode'),
        initialValue: widget.spec.mode,
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
          _updateSpec((ProfileSpec current) => current.copyWith(mode: value));
        },
      ),
      _formSpacing(),
      DropdownButtonFormField<String>(
        key: _fieldKey('log-level'),
        initialValue: widget.spec.logLevel,
        decoration: InputDecoration(labelText: copy.logLevel),
        items: const <String>['debug', 'info', 'warn', 'error']
            .map(
              (String level) =>
                  DropdownMenuItem<String>(value: level, child: Text(level)),
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
      _formSpacing(),
      SwitchListTile.adaptive(
        key: _fieldKey('dtls-switch'),
        contentPadding: EdgeInsets.zero,
        title: Text(copy.dtlsEnabled),
        value: widget.spec.useDtls,
        onChanged: (bool value) => _updateSpec(
          (ProfileSpec current) => current.copyWith(useDtls: value),
        ),
      ),
      _formSpacing(),
      _RoutingTextField(
        key: _fieldKey('turn-server'),
        controller: _turnServerController,
        label: copy.turnOverride,
        onChanged: (String value) => _updateSpec(
          (ProfileSpec current) => current.copyWith(
            turnServer: value.trim().isEmpty ? null : value.trim(),
          ),
        ),
      ),
      _formSpacing(),
      _RoutingTextField(
        key: _fieldKey('turn-port'),
        controller: _turnPortController,
        label: copy.turnPort,
        onChanged: (String value) => _updateSpec(
          (ProfileSpec current) => current.copyWith(
            turnPort: value.trim().isEmpty ? null : value.trim(),
          ),
        ),
      ),
      _formSpacing(),
      _RoutingTextField(
        key: _fieldKey('bind-interface'),
        controller: _bindInterfaceController,
        label: copy.bindInterface,
        onChanged: (String value) => _updateSpec(
          (ProfileSpec current) => current.copyWith(
            bindInterface: value.trim().isEmpty ? null : value.trim(),
          ),
        ),
      ),
      _formSpacing(height: 18),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: <Widget>[
          FilledButton(
            key: _actionKey('save-profile'),
            onPressed: widget.busy || widget.onSave == null
                ? null
                : () => unawaited(widget.onSave!.call()),
            child: Text(copy.saveProfile),
          ),
          FilledButton.tonal(
            key: _actionKey('open-profiles'),
            onPressed: widget.onOpenProfiles,
            child: Text(copy.openProfiles),
          ),
          OutlinedButton(
            key: _actionKey('start-profile'),
            onPressed: widget.busy || widget.onStartProfile == null
                ? null
                : () => unawaited(widget.onStartProfile!.call()),
            child: Text(copy.startOnThisDevice),
          ),
        ],
      ),
    ];
    if (_desktop) {
      return ListView(primary: false, children: fields);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fields,
    );
  }

  Widget _formSpacing({double height = 12}) {
    return SizedBox(height: height);
  }

  Key _fieldKey(String suffix) {
    final prefix = switch (widget.variant) {
      RoutingContentSurfaceVariant.desktop => 'desktop',
      RoutingContentSurfaceVariant.mobile => 'mobile',
    };
    return ValueKey<String>('$prefix-routing-$suffix-field');
  }

  Key _actionKey(String suffix) {
    final prefix = switch (widget.variant) {
      RoutingContentSurfaceVariant.desktop => 'desktop',
      RoutingContentSurfaceVariant.mobile => 'mobile',
    };
    return ValueKey<String>('$prefix-routing-$suffix');
  }
}

class _RoutingSpecCard extends StatelessWidget {
  const _RoutingSpecCard({
    required this.variant,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final RoutingContentSurfaceVariant variant;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final container = Container(
      padding: EdgeInsets.all(
        variant == RoutingContentSurfaceVariant.desktop ? 18 : 16,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: variant == RoutingContentSurfaceVariant.desktop ? 0.28 : 0.24,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style:
                (variant == RoutingContentSurfaceVariant.desktop
                        ? theme.textTheme.titleLarge
                        : theme.textTheme.titleMedium)
                    ?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (subtitle.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style:
                  (variant == RoutingContentSurfaceVariant.desktop
                          ? theme.textTheme.bodyMedium
                          : theme.textTheme.bodySmall)
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 16),
          if (variant == RoutingContentSurfaceVariant.desktop)
            Expanded(child: child)
          else
            child,
        ],
      ),
    );
    if (variant == RoutingContentSurfaceVariant.desktop) {
      return container;
    }
    return Card(
      child: Padding(padding: const EdgeInsets.all(4), child: container),
    );
  }
}

class _RoutingPlatformTunnelPanel extends StatelessWidget {
  const _RoutingPlatformTunnelPanel({
    required this.variant,
    required this.hostReady,
    required this.busy,
    required this.platformTunnels,
    required this.platformTunnelResultFor,
    required this.onStartPlatformTunnel,
    this.onStopPlatformTunnel,
  });

  final RoutingContentSurfaceVariant variant;
  final bool hostReady;
  final bool busy;
  final List<PlatformTunnelCapability> platformTunnels;
  final PlatformTunnelStartResult? Function(PlatformTunnelMode mode)
  platformTunnelResultFor;
  final Future<void> Function(PlatformTunnelMode mode) onStartPlatformTunnel;
  final Future<void> Function(PlatformTunnelMode mode)? onStopPlatformTunnel;

  bool get _desktop => variant == RoutingContentSurfaceVariant.desktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = Card(
      color: context.shellVisuals.tone(ShellSemanticTone.info).container,
      child: Padding(
        padding: EdgeInsets.all(_desktop ? 18 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.shellText.desktopPlatformTunnelModes,
              style:
                  (_desktop
                          ? theme.textTheme.titleLarge
                          : theme.textTheme.titleMedium)
                      ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              _headerSummary(context),
              style:
                  (_desktop
                          ? theme.textTheme.bodyMedium
                          : theme.textTheme.bodySmall)
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            if (_desktop)
              Expanded(child: _buildBody(context))
            else
              _buildBody(context),
          ],
        ),
      ),
    );
    return KeyedSubtree(
      key: ValueKey<String>('routing-platform-tunnel-surface-${variant.name}'),
      child: card,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (platformTunnels.isEmpty) {
      return Text(
        _desktop
            ? context.shellText.desktopNoPlatformTunnelModesReported
            : context.shellText.noPlatformTunnelModesReported,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final cards = platformTunnels
        .map((PlatformTunnelCapability capability) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RoutingPlatformTunnelCard(
              variant: variant,
              capability: capability,
              result: platformTunnelResultFor(capability.mode),
              busy: busy,
              hostReady: hostReady,
              onStart: () => onStartPlatformTunnel(capability.mode),
              onStop: onStopPlatformTunnel == null
                  ? null
                  : () => onStopPlatformTunnel!(capability.mode),
            ),
          );
        })
        .toList(growable: false);

    if (_desktop) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: cards,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: cards,
    );
  }

  String _headerSummary(BuildContext context) {
    if (platformTunnels.isEmpty) {
      return _desktop
          ? context.shellText.desktopNoPlatformTunnelModesReported
          : context.shellText.noPlatformTunnelModesReported;
    }
    final latestResult = _latestResult();
    if (latestResult != null) {
      return _platformTunnelResultSummary(context, latestResult);
    }
    for (final capability in platformTunnels) {
      final message = capability.message.trim();
      if (message.isNotEmpty) {
        return message;
      }
    }
    if (platformTunnels.any(
      (PlatformTunnelCapability capability) => capability.available,
    )) {
      return _desktop
          ? context.shellText.desktopUseDiagnosticsForReportedModes
          : context.shellText.mobileHostModeAvailable;
    }
    return _desktop
        ? context.shellText.desktopTypedHostTunnelSummary
        : context.shellText.mobileHostModeUnavailable;
  }

  PlatformTunnelStartResult? _latestResult() {
    for (final capability in platformTunnels) {
      final result = platformTunnelResultFor(capability.mode);
      if (result != null) {
        return result;
      }
    }
    return null;
  }
}

class _RoutingPlatformTunnelCard extends StatelessWidget {
  const _RoutingPlatformTunnelCard({
    required this.variant,
    required this.capability,
    required this.result,
    required this.busy,
    required this.hostReady,
    required this.onStart,
    this.onStop,
  });

  final RoutingContentSurfaceVariant variant;
  final PlatformTunnelCapability capability;
  final PlatformTunnelStartResult? result;
  final bool busy;
  final bool hostReady;
  final Future<void> Function() onStart;
  final Future<void> Function()? onStop;

  bool get _desktop => variant == RoutingContentSurfaceVariant.desktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final button = switch ((result?.ready == true, onStop != null)) {
      (true, true) => OutlinedButton(
        onPressed: busy || !hostReady ? null : () => unawaited(onStop!.call()),
        child: Text(context.shellText.disconnectVpn),
      ),
      _ when capability.available => FilledButton.tonal(
        onPressed: busy || !hostReady ? null : () => unawaited(onStart()),
        child: Text(context.shellText.requestStartup),
      ),
      _ => null,
    };

    return Container(
      padding: EdgeInsets.all(_desktop ? 16 : 14),
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
                  style:
                      (_desktop
                              ? theme.textTheme.titleMedium
                              : theme.textTheme.titleSmall)
                          ?.copyWith(fontWeight: FontWeight.w800),
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
            _platformTunnelCapabilitySummary(context, capability, variant),
            style: _desktop
                ? theme.textTheme.bodyMedium
                : theme.textTheme.bodySmall,
          ),
          if (capability.message.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              capability.message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (button != null) ...<Widget>[const SizedBox(height: 12), button],
          const SizedBox(height: 10),
          Text(
            result == null
                ? (_desktop
                      ? context.shellText.desktopNoStartupRequestYet
                      : context.shellText.noStartupRequestYet)
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

String _platformTunnelCapabilitySummary(
  BuildContext context,
  PlatformTunnelCapability capability,
  RoutingContentSurfaceVariant variant,
) {
  if (variant == RoutingContentSurfaceVariant.desktop) {
    return context.shellText.desktopPlatformTunnelCapabilitySummary(
      available: capability.available,
      satisfiedPrerequisites: capability.satisfiedPrerequisites
          .map((PlatformTunnelPrerequisite prerequisite) => prerequisite.label)
          .toList(growable: false),
      missingPrerequisite: capability.missingPrerequisite?.label,
    );
  }

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
  return copy.desktopPlatformTunnelResultSummary(
    modeLabel: result.mode.label,
    ready: result.ready,
    stageLabel: result.stage?.label ?? copy.unknownStage,
    missingPrerequisite: result.missingPrerequisite?.label,
    message: result.message,
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
