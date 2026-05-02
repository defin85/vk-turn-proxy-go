import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';

import '../control/control_plane_models.dart';
import '../control/runtime_execution_planning.dart';
import 'shell_visuals.dart';

enum RoutingContentSurfaceVariant { desktop, mobile }

class RoutingContentSurface extends StatefulWidget {
  const RoutingContentSurface({
    super.key,
    required this.variant,
    required this.busy,
    required this.hostReady,
    required this.platformTunnels,
    required this.platformTunnelResultFor,
    this.platformTunnelStatusFor,
    this.transportProfileStatusSummaryForMode,
    this.transportProfileImportAdapterLabelForMode,
    this.platformTunnelStartBlockReasonForMode,
    this.canConfigureTransportProfileForMode,
    this.canEditTransportProfileForMode,
    this.transportProfileConfiguredForMode,
    this.onEditTransportProfile,
    this.onImportTransportProfile,
    this.onForgetTransportProfile,
  });

  final RoutingContentSurfaceVariant variant;
  final bool busy;
  final bool hostReady;
  final List<PlatformTunnelCapability> platformTunnels;
  final PlatformTunnelStartResult? Function(PlatformTunnelMode mode)
  platformTunnelResultFor;
  final PlatformTunnelStatus? Function(PlatformTunnelMode mode)?
  platformTunnelStatusFor;
  final String? Function(PlatformTunnelMode mode)?
  transportProfileStatusSummaryForMode;
  final String? Function(PlatformTunnelMode mode)?
  transportProfileImportAdapterLabelForMode;
  final String? Function(PlatformTunnelMode mode)?
  platformTunnelStartBlockReasonForMode;
  final bool Function(PlatformTunnelMode mode)?
  canConfigureTransportProfileForMode;
  final bool Function(PlatformTunnelMode mode)? canEditTransportProfileForMode;
  final bool Function(PlatformTunnelMode mode)?
  transportProfileConfiguredForMode;
  final Future<void> Function(PlatformTunnelMode mode)? onEditTransportProfile;
  final Future<void> Function(PlatformTunnelMode mode)?
  onImportTransportProfile;
  final Future<void> Function(PlatformTunnelMode mode)?
  onForgetTransportProfile;

  @override
  State<RoutingContentSurface> createState() => _RoutingContentSurfaceState();
}

class _RoutingContentSurfaceState extends State<RoutingContentSurface> {
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
    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: _buildTunnelPanel(context),
        ),
      ),
    );
  }

  Widget _buildMobileSurface(BuildContext context) {
    return _buildTunnelPanel(context);
  }

  Widget _buildTunnelPanel(BuildContext context) {
    return _RoutingPlatformTunnelPanel(
      variant: widget.variant,
      hostReady: widget.hostReady,
      busy: widget.busy,
      platformTunnels: widget.platformTunnels,
      platformTunnelResultFor: widget.platformTunnelResultFor,
      platformTunnelStatusFor: widget.platformTunnelStatusFor,
      transportProfileStatusSummaryForMode:
          widget.transportProfileStatusSummaryForMode,
      transportProfileImportAdapterLabelForMode:
          widget.transportProfileImportAdapterLabelForMode,
      platformTunnelStartBlockReasonForMode:
          widget.platformTunnelStartBlockReasonForMode,
      canConfigureTransportProfileForMode:
          widget.canConfigureTransportProfileForMode,
      canEditTransportProfileForMode: widget.canEditTransportProfileForMode,
      transportProfileConfiguredForMode:
          widget.transportProfileConfiguredForMode,
      onEditTransportProfile: widget.onEditTransportProfile,
      onImportTransportProfile: widget.onImportTransportProfile,
      onForgetTransportProfile: widget.onForgetTransportProfile,
    );
  }
}

class _RoutingPlatformTunnelPanel extends StatefulWidget {
  const _RoutingPlatformTunnelPanel({
    required this.variant,
    required this.hostReady,
    required this.busy,
    required this.platformTunnels,
    required this.platformTunnelResultFor,
    this.platformTunnelStatusFor,
    this.transportProfileStatusSummaryForMode,
    this.transportProfileImportAdapterLabelForMode,
    this.platformTunnelStartBlockReasonForMode,
    this.canConfigureTransportProfileForMode,
    this.canEditTransportProfileForMode,
    this.transportProfileConfiguredForMode,
    this.onEditTransportProfile,
    this.onImportTransportProfile,
    this.onForgetTransportProfile,
  });

  final RoutingContentSurfaceVariant variant;
  final bool hostReady;
  final bool busy;
  final List<PlatformTunnelCapability> platformTunnels;
  final PlatformTunnelStartResult? Function(PlatformTunnelMode mode)
  platformTunnelResultFor;
  final PlatformTunnelStatus? Function(PlatformTunnelMode mode)?
  platformTunnelStatusFor;
  final String? Function(PlatformTunnelMode mode)?
  transportProfileStatusSummaryForMode;
  final String? Function(PlatformTunnelMode mode)?
  transportProfileImportAdapterLabelForMode;
  final String? Function(PlatformTunnelMode mode)?
  platformTunnelStartBlockReasonForMode;
  final bool Function(PlatformTunnelMode mode)?
  canConfigureTransportProfileForMode;
  final bool Function(PlatformTunnelMode mode)? canEditTransportProfileForMode;
  final bool Function(PlatformTunnelMode mode)?
  transportProfileConfiguredForMode;
  final Future<void> Function(PlatformTunnelMode mode)? onEditTransportProfile;
  final Future<void> Function(PlatformTunnelMode mode)?
  onImportTransportProfile;
  final Future<void> Function(PlatformTunnelMode mode)?
  onForgetTransportProfile;

  @override
  State<_RoutingPlatformTunnelPanel> createState() =>
      _RoutingPlatformTunnelPanelState();
}

class _RoutingPlatformTunnelPanelState
    extends State<_RoutingPlatformTunnelPanel> {
  late bool _detailsExpanded;

  bool get _desktop => widget.variant == RoutingContentSurfaceVariant.desktop;

  @override
  void initState() {
    super.initState();
    _detailsExpanded = _latestResult()?.ready == true || _hasStartBlock(widget);
  }

  @override
  void didUpdateWidget(covariant _RoutingPlatformTunnelPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousReady = _latestResultFor(oldWidget)?.ready == true;
    final nextReady = _latestResult()?.ready == true;
    final previousBlocked = _hasStartBlock(oldWidget);
    final nextBlocked = _hasStartBlock(widget);
    if ((!previousReady && nextReady) || (!previousBlocked && nextBlocked)) {
      _detailsExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latestResult = _latestResult();
    final summaryTone = _summaryTone(latestResult);
    final buttonLabel = _detailsExpanded
        ? context.shellText.hidePlatformTunnelDetails
        : context.shellText.showPlatformTunnelDetails;
    final card = Container(
      width: double.infinity,
      padding: EdgeInsets.all(_desktop ? 18 : 16),
      decoration: shellSurfaceDecoration(
        context,
        style: ShellSurfaceStyle.muted,
        tone: summaryTone,
      ),
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
                      context.shellText.desktopPlatformTunnelModes,
                      style:
                          (_desktop
                                  ? theme.textTheme.titleMedium
                                  : theme.textTheme.titleSmall)
                              ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _compactSummary(context, latestResult),
                      maxLines: _desktop ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (_desktop
                                  ? theme.textTheme.bodyMedium
                                  : theme.textTheme.bodySmall)
                              ?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  ShellToneBadge(
                    label: _statusBadgeLabel(context, latestResult),
                    tone: summaryTone,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    key: ValueKey<String>(
                      'routing-platform-tunnel-toggle-${widget.variant.name}',
                    ),
                    onPressed: () {
                      setState(() {
                        _detailsExpanded = !_detailsExpanded;
                      });
                    },
                    icon: Icon(
                      _detailsExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                    ),
                    label: Text(buttonLabel),
                  ),
                ],
              ),
            ],
          ),
          if (_detailsExpanded) ...<Widget>[
            const SizedBox(height: 14),
            _buildBody(context),
          ],
        ],
      ),
    );
    return KeyedSubtree(
      key: ValueKey<String>(
        'routing-platform-tunnel-surface-${widget.variant.name}',
      ),
      child: card,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (widget.platformTunnels.isEmpty) {
      return Text(
        _desktop
            ? context.shellText.desktopNoPlatformTunnelModesReported
            : context.shellText.noPlatformTunnelModesReported,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final cards = widget.platformTunnels
        .map((PlatformTunnelCapability capability) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RoutingPlatformTunnelCard(
              variant: widget.variant,
              capability: capability,
              result: widget.platformTunnelResultFor(capability.mode),
              status: widget.platformTunnelStatusFor?.call(capability.mode),
              busy: widget.busy,
              hostReady: widget.hostReady,
              transportProfileStatusSummary: widget
                  .transportProfileStatusSummaryForMode
                  ?.call(capability.mode),
              transportProfileImportAdapterLabel: widget
                  .transportProfileImportAdapterLabelForMode
                  ?.call(capability.mode),
              startBlockReason: widget.platformTunnelStartBlockReasonForMode
                  ?.call(capability.mode),
              canConfigureTransportProfile:
                  widget.canConfigureTransportProfileForMode?.call(
                    capability.mode,
                  ) ??
                  false,
              canEditTransportProfile:
                  widget.canEditTransportProfileForMode?.call(
                    capability.mode,
                  ) ??
                  false,
              transportProfileConfigured:
                  widget.transportProfileConfiguredForMode?.call(
                    capability.mode,
                  ) ??
                  false,
              onEditTransportProfile: widget.onEditTransportProfile == null
                  ? null
                  : () => widget.onEditTransportProfile!(capability.mode),
              onImportTransportProfile: widget.onImportTransportProfile == null
                  ? null
                  : () => widget.onImportTransportProfile!(capability.mode),
              onForgetTransportProfile: widget.onForgetTransportProfile == null
                  ? null
                  : () => widget.onForgetTransportProfile!(capability.mode),
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

  PlatformTunnelStartResult? _latestResult() {
    return _latestResultFor(widget);
  }

  bool _hasStartBlock(_RoutingPlatformTunnelPanel source) {
    for (final capability in source.platformTunnels) {
      final reason = source.platformTunnelStartBlockReasonForMode
          ?.call(capability.mode)
          ?.trim();
      if (reason?.isNotEmpty == true) {
        return true;
      }
    }
    return false;
  }

  PlatformTunnelStartResult? _latestResultFor(
    _RoutingPlatformTunnelPanel source,
  ) {
    for (final capability in source.platformTunnels) {
      final result = source.platformTunnelResultFor(capability.mode);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  ShellSemanticTone _summaryTone(PlatformTunnelStartResult? latestResult) {
    if (latestResult?.ready == true ||
        widget.platformTunnels.any(
          (PlatformTunnelCapability capability) => capability.available,
        )) {
      return ShellSemanticTone.ready;
    }
    return ShellSemanticTone.attention;
  }

  String _statusBadgeLabel(
    BuildContext context,
    PlatformTunnelStartResult? latestResult,
  ) {
    if (latestResult?.ready == true) {
      return context.shellText.sessionStateLabel('ready');
    }
    if (widget.platformTunnels.any(
      (PlatformTunnelCapability capability) => capability.available,
    )) {
      return context.shellText.availableLowercase;
    }
    return context.shellText.unavailableLowercase;
  }

  String _compactSummary(
    BuildContext context,
    PlatformTunnelStartResult? latestResult,
  ) {
    if (widget.platformTunnels.isEmpty) {
      return _desktop
          ? context.shellText.desktopNoPlatformTunnelModesReported
          : context.shellText.noPlatformTunnelModesReported;
    }
    if (latestResult != null) {
      return _platformTunnelResultSummary(context, latestResult);
    }
    if (widget.platformTunnels.length == 1) {
      final capability = widget.platformTunnels.single;
      if (_desktop) {
        return context.shellText.desktopCompactPlatformTunnelCapabilitySummary(
          modeLabel: capability.mode.label,
          available: capability.available,
          missingPrerequisite: capability.missingPrerequisite?.label,
        );
      }
      return '${capability.mode.label} · ${capability.available ? context.shellText.availableLowercase : context.shellText.unavailableLowercase}';
    }

    final availableCount = widget.platformTunnels
        .where((PlatformTunnelCapability capability) => capability.available)
        .length;
    return '$availableCount/${widget.platformTunnels.length} ${context.shellText.availableLowercase}';
  }
}

class _RoutingPlatformTunnelCard extends StatelessWidget {
  const _RoutingPlatformTunnelCard({
    required this.variant,
    required this.capability,
    required this.result,
    required this.status,
    required this.busy,
    required this.hostReady,
    this.transportProfileStatusSummary,
    this.transportProfileImportAdapterLabel,
    this.startBlockReason,
    this.canConfigureTransportProfile = false,
    this.canEditTransportProfile = false,
    this.transportProfileConfigured = false,
    this.onEditTransportProfile,
    this.onImportTransportProfile,
    this.onForgetTransportProfile,
  });

  final RoutingContentSurfaceVariant variant;
  final PlatformTunnelCapability capability;
  final PlatformTunnelStartResult? result;
  final PlatformTunnelStatus? status;
  final bool busy;
  final bool hostReady;
  final String? transportProfileStatusSummary;
  final String? transportProfileImportAdapterLabel;
  final String? startBlockReason;
  final bool canConfigureTransportProfile;
  final bool canEditTransportProfile;
  final bool transportProfileConfigured;
  final Future<void> Function()? onEditTransportProfile;
  final Future<void> Function()? onImportTransportProfile;
  final Future<void> Function()? onForgetTransportProfile;

  bool get _desktop => variant == RoutingContentSurfaceVariant.desktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final startBlocked = startBlockReason?.trim().isNotEmpty == true;
    final canImport =
        canConfigureTransportProfile && onImportTransportProfile != null;
    final canEdit = canEditTransportProfile && onEditTransportProfile != null;
    final canForget =
        transportProfileConfigured && onForgetTransportProfile != null;

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
          if (transportProfileStatusSummary?.trim().isNotEmpty ==
              true) ...<Widget>[
            const SizedBox(height: 10),
            _RoutingTransportProfileStatus(
              variant: variant,
              mode: capability.mode,
              status: transportProfileStatusSummary!.trim(),
              adapterLabel: transportProfileImportAdapterLabel,
              busy: busy,
              hostReady: hostReady,
              canEdit: canEdit,
              canImport: canImport,
              configured: transportProfileConfigured,
              canForget: canForget,
              onEdit: onEditTransportProfile,
              onImport: onImportTransportProfile,
              onForget: onForgetTransportProfile,
            ),
          ],
          if (startBlocked) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              startBlockReason!.trim(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
          if (status != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _platformTunnelStatusDetails(context, status!),
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

class _RoutingTransportProfileStatus extends StatelessWidget {
  const _RoutingTransportProfileStatus({
    required this.variant,
    required this.mode,
    required this.status,
    required this.adapterLabel,
    required this.busy,
    required this.hostReady,
    required this.canEdit,
    required this.canImport,
    required this.configured,
    required this.canForget,
    required this.onEdit,
    required this.onImport,
    required this.onForget,
  });

  final RoutingContentSurfaceVariant variant;
  final PlatformTunnelMode mode;
  final String status;
  final String? adapterLabel;
  final bool busy;
  final bool hostReady;
  final bool canEdit;
  final bool canImport;
  final bool configured;
  final bool canForget;
  final Future<void> Function()? onEdit;
  final Future<void> Function()? onImport;
  final Future<void> Function()? onForget;

  bool get _desktop => variant == RoutingContentSurfaceVariant.desktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = context.shellText;
    final adapter = adapterLabel?.trim() ?? '';
    final actions = <Widget>[
      if (canEdit)
        FilledButton.tonalIcon(
          key: ValueKey<String>(
            '${variant.name}-routing-${configured ? 'edit' : 'create'}-vpn-transport-profile-${mode.value}',
          ),
          onPressed: busy || !hostReady ? null : () => unawaited(onEdit!()),
          icon: Icon(configured ? Icons.edit_rounded : Icons.add_rounded),
          label: Text(configured ? 'Edit VPN profile' : 'Create VPN profile'),
        ),
      if (canImport)
        OutlinedButton.icon(
          key: ValueKey<String>(
            '${variant.name}-routing-${configured ? 'replace' : 'import'}-vpn-transport-profile-${mode.value}',
          ),
          onPressed: busy || !hostReady
              ? null
              : () => unawaited(
                  configured
                      ? _confirmAction(
                          context,
                          title: 'Replace VPN profile?',
                          message:
                              'Importing a new WireGuard profile will replace the current VPN transport profile for this mode.',
                          confirmLabel: copy.replaceVPNTransportProfile,
                          onConfirmed: onImport!,
                        )
                      : onImport!(),
                ),
          icon: Icon(
            configured ? Icons.upload_file_rounded : Icons.vpn_key_rounded,
          ),
          label: Text(
            configured
                ? copy.replaceVPNTransportProfile
                : copy.importVPNTransportProfile,
          ),
        ),
      if (canForget)
        TextButton.icon(
          key: ValueKey<String>(
            '${variant.name}-routing-forget-vpn-transport-profile-${mode.value}',
          ),
          onPressed: busy || !hostReady
              ? null
              : () => unawaited(
                  _confirmAction(
                    context,
                    title: 'Forget VPN profile?',
                    message:
                        'Remove the current VPN transport profile for this mode.',
                    confirmLabel: copy.forgetVPNTransportProfile,
                    onConfirmed: onForget!,
                  ),
                ),
          icon: const Icon(Icons.delete_outline_rounded),
          label: Text(copy.forgetVPNTransportProfile),
        ),
    ];
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_desktop ? 14 : 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.54),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            status,
            style:
                (_desktop
                        ? theme.textTheme.bodyMedium
                        : theme.textTheme.bodySmall)
                    ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (adapter.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              adapter,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function() onConfirmed,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await onConfirmed();
    }
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
    final ingress = _remoteIngressSummary(result.remoteIngress);
    if (result.underlayRoutePolicy ==
        PlatformTunnelUnderlayRoutePolicy.preserveActiveLocalNetwork) {
      final summary = copy.platformTunnelReadyWithRoutingProfile(
        modeLabel: result.mode.label,
        profileLabel: _underlayRoutePolicyLabel(
          copy,
          result.underlayRoutePolicy!,
        ),
      );
      return ingress == null ? summary : '$summary · $ingress';
    }
    final summary = copy.platformTunnelReady(result.mode.label);
    return ingress == null ? summary : '$summary · $ingress';
  }
  return copy.desktopPlatformTunnelResultSummary(
    modeLabel: result.mode.label,
    ready: result.ready,
    stageLabel: result.stage?.label ?? copy.unknownStage,
    missingPrerequisite: result.missingPrerequisite?.label,
    message: result.message,
  );
}

String _platformTunnelStatusDetails(
  BuildContext context,
  PlatformTunnelStatus status,
) {
  final copy = context.shellText;
  final parts = <String>[
    copy.sessionStateLabel(status.state.value.replaceAll('_', ' ')),
  ];
  if (status.sessionId.isNotEmpty) {
    parts.add('Session: ${status.sessionId}');
  }
  final scope = _platformTunnelScopeSummary(copy, status);
  if (scope != null) {
    parts.add(scope);
  }
  if (status.underlayRoutePolicy != null) {
    parts.add(_underlayRoutePolicyLabel(copy, status.underlayRoutePolicy!));
  }
  final ingress = _remoteIngressSummary(status.remoteIngress);
  if (ingress != null) {
    parts.add(ingress);
  }
  return parts.join(' · ');
}

String? _remoteIngressSummary(RuntimeRemoteIngressDiagnostics? ingress) {
  if (ingress == null) {
    return null;
  }
  final protocol = switch (ingress.protocol) {
    RuntimeRemoteIngressProtocol.dtlsCustomOverlay => 'DTLS overlay',
    RuntimeRemoteIngressProtocol.rawWireGuardDatagram => 'raw WireGuard',
    RuntimeRemoteIngressProtocol.udpProtocolMultiplexer => 'UDP mux',
  };
  final isolation = switch (ingress.isolation) {
    RuntimeRemoteIngressIsolation.dedicated => 'dedicated',
    RuntimeRemoteIngressIsolation.muxBacked => 'mux-backed',
  };
  final address = ingress.address.trim();
  if (address.isEmpty) {
    return 'Ingress: $protocol ($isolation)';
  }
  return 'Ingress: $protocol at $address ($isolation)';
}

String? _platformTunnelScopeSummary(
  ShellText copy,
  PlatformTunnelStatus status,
) {
  switch (status.applicationRoutingPolicy) {
    case PlatformTunnelApplicationRoutingPolicy.allApps:
      return copy.scopeAllInstalledApps;
    case PlatformTunnelApplicationRoutingPolicy.allowedPackages:
      return status.allowedPackages.isEmpty
          ? copy.scopeIncludedAppsEmpty
          : copy.scopeOnlySelectedApps(status.allowedPackages.length);
    case PlatformTunnelApplicationRoutingPolicy.disallowedPackages:
      return status.disallowedPackages.isEmpty
          ? copy.scopeExcludedAppsEmpty
          : copy.scopeAllExceptSelectedApps(status.disallowedPackages.length);
    case null:
      return null;
  }
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
