import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_shell_core/portable_profile_transfer.dart';
import 'package:flutter_shell_core/profile_workflow_surface.dart';
import 'package:flutter_shell_core/shell_visuals.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/profile_draft.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ProfileEditorPanel extends StatefulWidget {
  ProfileEditorPanel({
    super.key,
    required this.providerDescriptors,
    required this.selectedProfileId,
    required this.draft,
    required this.busy,
    required this.onDraftChanged,
    required this.onSave,
    required this.onDelete,
    required this.onReset,
    required this.onResolve,
    required this.onStart,
    required this.onPreparePortableExport,
    required this.onCopyPortableExportText,
    required this.onSavePortableExportFile,
    required this.onImportPortableFromFile,
    required this.onPreviewPortableImport,
    required this.onConfirmPortableImport,
    this.onBrowseManagedProviders,
    List<ManagedProviderRecord>? managedProviders,
    String? initialManagedProviderId,
    void Function({String? managedProviderId})? onActivateManagedProviderMode,
    VoidCallback? onUseCustomProvider,
    List<ProviderConfigRecord>? availableProviderConfigs,
    ValueChanged<String>? onApplyProviderConfig,
  }) : managedProviders =
           managedProviders ??
           (availableProviderConfigs ?? const <ProviderConfigRecord>[])
               .map(ManagedProviderRecord.fromLegacyProviderConfig)
               .toList(growable: false),
       selectedManagedProviderId = initialManagedProviderId,
       onActivateManagedProviderMode =
           onActivateManagedProviderMode ??
           _legacyManagedProviderActivator(onApplyProviderConfig),
       onUseCustomProvider = onUseCustomProvider ?? _noop;

  final List<ProviderDescriptor> providerDescriptors;
  final List<ManagedProviderRecord> managedProviders;
  final String? selectedManagedProviderId;
  final String? selectedProfileId;
  final ProfileDraft draft;
  final bool busy;
  final ValueChanged<ProfileDraft> onDraftChanged;
  final void Function({String? managedProviderId})
  onActivateManagedProviderMode;
  final VoidCallback onUseCustomProvider;
  final Future<void> Function()? onBrowseManagedProviders;
  final Future<void> Function() onSave;
  final Future<void> Function() onDelete;
  final VoidCallback onReset;
  final Future<void> Function() onResolve;
  final Future<void> Function() onStart;
  final PortableProfileEnvelope? Function() onPreparePortableExport;
  final Future<void> Function(PortableProfileEnvelope envelope)
  onCopyPortableExportText;
  final Future<void> Function(PortableProfileEnvelope envelope)
  onSavePortableExportFile;
  final Future<PortableProfileEnvelope?> Function() onImportPortableFromFile;
  final PortableProfileEnvelope? Function(String payload)
  onPreviewPortableImport;
  final Future<void> Function(PortableProfileEnvelope envelope)
  onConfirmPortableImport;

  @override
  State<ProfileEditorPanel> createState() => _ProfileEditorPanelState();
}

void _noop() {}

void Function({String? managedProviderId}) _legacyManagedProviderActivator(
  ValueChanged<String>? onApplyProviderConfig,
) {
  return ({String? managedProviderId}) {
    if (managedProviderId != null && onApplyProviderConfig != null) {
      onApplyProviderConfig(managedProviderId);
    }
  };
}

class _ProfileEditorPanelState extends State<ProfileEditorPanel> {
  Future<void> _showPortableExportDialog() async {
    final envelope = widget.onPreparePortableExport();
    if (envelope == null || !mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final copy = context.shellText;
        return AlertDialog(
          title: Text(copy.exportPortableProfile),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    envelope.displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    copy.providerAndSource(
                      provider: envelope.profile.spec.provider,
                      source: envelope.providerBinding.mode.value,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (envelope.isSecretBearing)
                    _warningBanner(
                      context,
                      copy.portableExportSecretWarningDesktop,
                    ),
                  if (!envelope.isSecretBearing)
                    Text(
                      copy.portableExportSeparateFromRuntimeDesktop,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 12),
                  if (envelope.fitsQrBounds) ...<Widget>[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: QrImageView(
                          data: envelope.encode(),
                          version: QrVersions.auto,
                          size: 240,
                          gapless: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      copy.portableQrCompactJson,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ] else ...<Widget>[
                    _warningBanner(
                      context,
                      copy.portableQrUnavailableDesktop(
                        envelope.encodedUtf8Bytes,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(copy.close),
            ),
            FilledButton.tonal(
              onPressed: () =>
                  unawaited(widget.onCopyPortableExportText(envelope)),
              child: Text(copy.copyText),
            ),
            FilledButton(
              onPressed: () =>
                  unawaited(widget.onSavePortableExportFile(envelope)),
              child: Text(copy.saveFile),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importPortableFromFile() async {
    final envelope = await widget.onImportPortableFromFile();
    if (envelope == null || !mounted) {
      return;
    }
    await _showPortableImportPreview(envelope);
  }

  Future<void> _showPortableImportPreview(
    PortableProfileEnvelope envelope,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final copy = context.shellText;
        final snapshotName =
            envelope.managedProviderSnapshot?.name.isNotEmpty == true
            ? envelope.managedProviderSnapshot!.name
            : envelope.managedProviderSnapshot?.id ?? copy.missing;
        return AlertDialog(
          title: Text(copy.importPortableProfile),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    envelope.displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(copy.providerLabel(envelope.profile.spec.provider)),
                  Text(
                    copy.sourceModeLabel(envelope.providerBinding.mode.value),
                  ),
                  if (envelope.providerBinding.isManaged)
                    Text(copy.managedProviderSnapshot(snapshotName)),
                  const SizedBox(height: 12),
                  if (envelope.isSecretBearing)
                    _warningBanner(context, copy.portableImportSecretWarning),
                  if (!envelope.isSecretBearing)
                    Text(
                      copy.portableImportCreatesFreshIdsDesktop,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(copy.cancel),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await widget.onConfirmPortableImport(envelope);
              },
              child: Text(copy.importProfile),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPortablePasteDialog() async {
    final controller = TextEditingController();
    String? errorText;
    try {
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          final copy = context.shellText;
          return StatefulBuilder(
            builder:
                (
                  BuildContext context,
                  void Function(VoidCallback fn) setState,
                ) {
                  return AlertDialog(
                    title: Text(copy.pastePortableProfileEnvelope),
                    content: SizedBox(
                      width: 560,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          TextField(
                            controller: controller,
                            minLines: 8,
                            maxLines: 16,
                            decoration: InputDecoration(
                              labelText: copy.portableProfileJson,
                              errorText: errorText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            copy.previewOpensBeforeRecordsCreated,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(copy.cancel),
                      ),
                      FilledButton(
                        onPressed: () {
                          final envelope = widget.onPreviewPortableImport(
                            controller.text,
                          );
                          if (envelope == null) {
                            setState(() {
                              errorText = copy.payloadInvalidOrUnsupported;
                            });
                            return;
                          }
                          Navigator.of(context).pop();
                          unawaited(_showPortableImportPreview(envelope));
                        },
                        child: Text(copy.previewImport),
                      ),
                    ],
                  );
                },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = context.shellText;
    final descriptor = _selectedDescriptor();
    final profileScopeLabel = widget.selectedProfileId == null
        ? copy.desktopUnsavedDraft
        : copy.desktopSavedProfileWorkspace;

    final headerActions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        FilledButton(
          key: const ValueKey<String>('profile-resolve-action'),
          onPressed: widget.busy ? null : () => unawaited(widget.onResolve()),
          child: Text(_nextStepTitle(context, descriptor)),
        ),
        Tooltip(
          message: widget.selectedProfileId == null
              ? copy.desktopSaveProfileFirst
              : copy.desktopStartSessionFromSavedProfile,
          child: FilledButton.tonal(
            key: const ValueKey<String>('profile-start-action'),
            onPressed: widget.busy || widget.selectedProfileId == null
                ? null
                : () => unawaited(widget.onStart()),
            child: Text(copy.startSession),
          ),
        ),
        FilledButton.tonal(
          key: const ValueKey<String>('profile-save-action'),
          onPressed: widget.busy ? null : () => unawaited(widget.onSave()),
          child: Text(copy.saveProfile),
        ),
        FilledButton.tonalIcon(
          onPressed: widget.busy ? null : widget.onReset,
          icon: const Icon(Icons.add),
          label: Text(copy.freshDraft),
        ),
      ],
    );

    final body = ProfileWorkflowBody(
      variant: ProfileWorkflowVariant.desktop,
      providerDescriptors: widget.providerDescriptors,
      managedProviders: widget.managedProviders,
      selectedManagedProviderId: widget.selectedManagedProviderId,
      selectedProfileId: widget.selectedProfileId,
      draft: widget.draft,
      busy: widget.busy,
      onDraftChanged: widget.onDraftChanged,
      onActivateManagedProviderMode: widget.onActivateManagedProviderMode,
      onUseCustomProvider: widget.onUseCustomProvider,
      trailingChildren: <Widget>[
        _portableTransferCard(theme),
        _supportActionsCard(theme),
      ],
      nameFieldKey: const ValueKey<String>('profile-name-field'),
    );

    return Card(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final stackHeader = constraints.maxWidth < 960;
          final lowHeightWorkbench = constraints.maxHeight < 220;

          if (lowHeightWorkbench) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                primary: false,
                children: <Widget>[
                  Text(
                    copy.desktopProfileWorkspaceTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profileScopeLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  headerActions,
                  const SizedBox(height: 12),
                  body,
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (stackHeader)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        copy.desktopProfileWorkspaceTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profileScopeLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      headerActions,
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              copy.desktopProfileWorkspaceTitle,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              profileScopeLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(child: headerActions),
                    ],
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    key: const ValueKey<String>('profile-workspace-scroll'),
                    primary: true,
                    children: <Widget>[body],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _supportActionsCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: shellSurfaceDecoration(
        context,
        style: ShellSurfaceStyle.highlight,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.shellText.desktopProfileMaintenance,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.shellText.desktopProfileMaintenanceSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 8),
            title: Text(context.shellText.desktopShowMaintenanceActions),
            subtitle: Text(context.shellText.desktopDeleteSavedProfileHint),
            children: <Widget>[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  OutlinedButton(
                    key: const ValueKey<String>('profile-delete-action'),
                    onPressed: widget.busy || widget.selectedProfileId == null
                        ? null
                        : () => unawaited(widget.onDelete()),
                    child: Text(context.shellText.delete),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _portableTransferCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: shellSurfaceDecoration(
        context,
        style: ShellSurfaceStyle.highlight,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.shellText.mobilePortableTransfer,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.shellText.desktopPortableTransferSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              FilledButton.tonal(
                key: const ValueKey<String>('profile-portable-export-action'),
                onPressed: widget.busy || widget.selectedProfileId == null
                    ? null
                    : () => unawaited(_showPortableExportDialog()),
                child: Text(context.shellText.exportSavedProfile),
              ),
              OutlinedButton(
                key: const ValueKey<String>(
                  'profile-portable-import-file-action',
                ),
                onPressed: widget.busy
                    ? null
                    : () => unawaited(_importPortableFromFile()),
                child: Text(context.shellText.importFromFile),
              ),
              OutlinedButton(
                key: const ValueKey<String>(
                  'profile-portable-import-paste-action',
                ),
                onPressed: widget.busy
                    ? null
                    : () => unawaited(_showPortablePasteDialog()),
                child: Text(context.shellText.pasteEnvelope),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _warningBanner(BuildContext context, String message) {
    final theme = Theme.of(context);
    final palette = context.shellVisuals.tone(ShellSemanticTone.danger);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: shellSurfaceDecoration(
        context,
        style: ShellSurfaceStyle.highlight,
        tone: ShellSemanticTone.danger,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(color: palette.onContainer),
      ),
    );
  }

  String _nextStepTitle(BuildContext context, ProviderDescriptor? descriptor) {
    if (descriptor?.mayRequireBrowserContinuation == true &&
        widget.draft.spec.link.trim().isNotEmpty) {
      return context.shellText.resolveInvite;
    }
    return context.shellText.resolveProfile;
  }

  ProviderDescriptor? _selectedDescriptor() {
    final providerId = widget.draft.spec.provider.trim().toLowerCase();
    for (final descriptor in widget.providerDescriptors) {
      if (descriptor.id.trim().toLowerCase() == providerId) {
        return descriptor;
      }
    }
    return null;
  }
}
