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
    this.onOpenSavedProfiles,
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
  final Future<void> Function()? onOpenSavedProfiles;
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

enum _ProfileEditorMenuAction {
  openSavedProfiles,
  openManagedProviders,
  resetDraft,
  exportPortableProfile,
  importPortableFromFile,
  importPortableFromPaste,
  resolveOnly,
  deleteProfile,
}

const double _kProfileDesktopBodyBreakpoint = 960;

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
    final hasSavedProfile = widget.selectedProfileId != null;
    final primaryLabel = hasSavedProfile
        ? copy.startSession
        : _nextStepTitle(context, descriptor);
    final primaryKey = hasSavedProfile
        ? const ValueKey<String>('profile-start-action')
        : const ValueKey<String>('profile-resolve-action');
    final VoidCallback? onPrimaryPressed = widget.busy
        ? null
        : () => unawaited(
            hasSavedProfile ? widget.onStart() : widget.onResolve(),
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final useDesktopBody =
                constraints.maxWidth >= _kProfileDesktopBodyBreakpoint;
            final stackedHeader = constraints.maxWidth < 840;
            final selectedManagedProvider = _selectedManagedProvider();
            final headerDescriptor =
                _descriptorForProviderId(selectedManagedProvider?.provider) ??
                descriptor;
            final headerBadges = <Widget>[
              if (!hasSavedProfile)
                ShellToneBadge(
                  label: copy.desktopUnsavedDraft,
                  tone: ShellSemanticTone.attention,
                ),
              ShellToneBadge(
                label: _headerProviderLabel(headerDescriptor),
                tone: ShellSemanticTone.info,
              ),
              ShellToneBadge(
                label: widget.draft.providerBinding.isManaged
                    ? copy.savedRecord
                    : copy.directInput,
              ),
              if (widget.draft.providerBinding.isManaged &&
                  selectedManagedProvider != null)
                ShellToneBadge(
                  label: _managedProviderLabel(selectedManagedProvider),
                  tone: ShellSemanticTone.info,
                ),
            ];
            final body = ProfileWorkflowBody(
              variant: useDesktopBody
                  ? ProfileWorkflowVariant.desktop
                  : ProfileWorkflowVariant.mobile,
              providerDescriptors: widget.providerDescriptors,
              managedProviders: widget.managedProviders,
              selectedManagedProviderId: widget.selectedManagedProviderId,
              selectedProfileId: widget.selectedProfileId,
              draft: widget.draft,
              busy: widget.busy,
              onDraftChanged: widget.onDraftChanged,
              onActivateManagedProviderMode:
                  widget.onActivateManagedProviderMode,
              onUseCustomProvider: widget.onUseCustomProvider,
              nameFieldKey: const ValueKey<String>('profile-name-field'),
            );
            final titleBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  copy.desktopProfileSettings,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: headerBadges),
              ],
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (stackedHeader) ...<Widget>[
                  titleBlock,
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildMoreActionsButton(context, hasSavedProfile),
                  ),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: titleBlock),
                      const SizedBox(width: 16),
                      _buildMoreActionsButton(context, hasSavedProfile),
                    ],
                  ),
                const SizedBox(height: 16),
                _actionBar(
                  hasSavedProfile: hasSavedProfile,
                  primaryKey: primaryKey,
                  primaryLabel: primaryLabel,
                  onPrimaryPressed: onPrimaryPressed,
                  onSavePressed: widget.busy
                      ? null
                      : () => unawaited(widget.onSave()),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ListView(
                      key: const ValueKey<String>('profile-workspace-scroll'),
                      primary: true,
                      children: <Widget>[
                        if (useDesktopBody)
                          body
                        else
                          Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 840),
                              child: body,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMoreActionsButton(BuildContext context, bool hasSavedProfile) {
    return PopupMenuButton<_ProfileEditorMenuAction>(
      key: const ValueKey<String>('profile-editor-more-actions-button'),
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      onSelected: (_ProfileEditorMenuAction action) {
        switch (action) {
          case _ProfileEditorMenuAction.openSavedProfiles:
            if (widget.onOpenSavedProfiles != null) {
              unawaited(widget.onOpenSavedProfiles!());
            }
            break;
          case _ProfileEditorMenuAction.openManagedProviders:
            if (widget.onBrowseManagedProviders != null) {
              unawaited(widget.onBrowseManagedProviders!());
            }
            break;
          case _ProfileEditorMenuAction.resetDraft:
            widget.onReset();
            break;
          case _ProfileEditorMenuAction.exportPortableProfile:
            unawaited(_showPortableExportDialog());
            break;
          case _ProfileEditorMenuAction.importPortableFromFile:
            unawaited(_importPortableFromFile());
            break;
          case _ProfileEditorMenuAction.importPortableFromPaste:
            unawaited(_showPortablePasteDialog());
            break;
          case _ProfileEditorMenuAction.resolveOnly:
            unawaited(widget.onResolve());
            break;
          case _ProfileEditorMenuAction.deleteProfile:
            unawaited(widget.onDelete());
            break;
        }
      },
      itemBuilder: (BuildContext context) {
        final items = <PopupMenuEntry<_ProfileEditorMenuAction>>[];
        if (widget.onOpenSavedProfiles != null) {
          items.add(
            PopupMenuItem<_ProfileEditorMenuAction>(
              key: const ValueKey<String>(
                'desktop-open-saved-profile-picker-button',
              ),
              value: _ProfileEditorMenuAction.openSavedProfiles,
              child: Text(context.shellText.desktopSavedProfilesLibraryTitle),
            ),
          );
        }
        if (widget.onBrowseManagedProviders != null) {
          items.add(
            PopupMenuItem<_ProfileEditorMenuAction>(
              key: const ValueKey<String>(
                'desktop-open-managed-provider-library-for-profile-button',
              ),
              value: _ProfileEditorMenuAction.openManagedProviders,
              child: Text(context.shellText.desktopManagedRecordsTitle),
            ),
          );
        }
        items.add(
          PopupMenuItem<_ProfileEditorMenuAction>(
            key: const ValueKey<String>('profile-reset-action'),
            value: _ProfileEditorMenuAction.resetDraft,
            child: Text(context.shellText.freshDraft),
          ),
        );
        items.add(
          PopupMenuItem<_ProfileEditorMenuAction>(
            key: const ValueKey<String>('profile-portable-import-file-action'),
            value: _ProfileEditorMenuAction.importPortableFromFile,
            child: Text(context.shellText.importFromFile),
          ),
        );
        items.add(
          PopupMenuItem<_ProfileEditorMenuAction>(
            key: const ValueKey<String>('profile-portable-import-paste-action'),
            value: _ProfileEditorMenuAction.importPortableFromPaste,
            child: Text(context.shellText.pasteEnvelope),
          ),
        );
        if (hasSavedProfile) {
          items.add(
            PopupMenuItem<_ProfileEditorMenuAction>(
              key: const ValueKey<String>('profile-portable-export-action'),
              value: _ProfileEditorMenuAction.exportPortableProfile,
              child: Text(context.shellText.exportSavedProfile),
            ),
          );
          items.add(
            PopupMenuItem<_ProfileEditorMenuAction>(
              key: const ValueKey<String>('profile-resolve-menu-action'),
              value: _ProfileEditorMenuAction.resolveOnly,
              child: Text(_nextStepTitle(context, _selectedDescriptor())),
            ),
          );
          items.add(
            PopupMenuItem<_ProfileEditorMenuAction>(
              key: const ValueKey<String>('profile-delete-action'),
              value: _ProfileEditorMenuAction.deleteProfile,
              child: Text(context.shellText.delete),
            ),
          );
        }
        return items;
      },
      icon: const Icon(Icons.more_horiz),
    );
  }

  Widget _actionBar({
    required bool hasSavedProfile,
    required Key primaryKey,
    required String primaryLabel,
    required VoidCallback? onPrimaryPressed,
    required VoidCallback? onSavePressed,
  }) {
    final theme = Theme.of(context);
    final copy = context.shellText;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final wideToolbar = constraints.maxWidth >= 820;
        final primaryButton = FilledButton.icon(
          key: primaryKey,
          onPressed: onPrimaryPressed,
          icon: Icon(
            hasSavedProfile ? Icons.play_arrow_rounded : Icons.sync_rounded,
          ),
          label: Text(primaryLabel),
        );
        final saveButton = FilledButton.tonalIcon(
          key: const ValueKey<String>('profile-save-action'),
          onPressed: onSavePressed,
          icon: const Icon(Icons.save_outlined),
          label: Text(copy.saveProfile),
        );
        if (wideToolbar) {
          return Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[saveButton, primaryButton],
            ),
          );
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.12,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                Expanded(child: primaryButton),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  key: const ValueKey<String>('profile-save-action'),
                  tooltip: copy.saveProfile,
                  onPressed: onSavePressed,
                  icon: const Icon(Icons.save_outlined),
                ),
              ],
            ),
          ),
        );
      },
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
    return _descriptorForProviderId(widget.draft.spec.provider);
  }

  ProviderDescriptor? _descriptorForProviderId(String? providerId) {
    final normalizedProviderId = providerId?.trim().toLowerCase() ?? '';
    if (normalizedProviderId.isEmpty) {
      return null;
    }
    for (final descriptor in widget.providerDescriptors) {
      if (descriptor.id.trim().toLowerCase() == normalizedProviderId) {
        return descriptor;
      }
    }
    return null;
  }

  ManagedProviderRecord? _selectedManagedProvider() {
    final managedProviderId =
        widget.selectedManagedProviderId ??
        widget.draft.providerBinding.managedProviderId;
    if (managedProviderId == null) {
      return null;
    }
    for (final managedProvider in widget.managedProviders) {
      if (managedProvider.id == managedProviderId) {
        return managedProvider;
      }
    }
    return null;
  }

  String _headerProviderLabel(ProviderDescriptor? descriptor) {
    final displayName = descriptor?.displayName.trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName;
    }
    final providerId = widget.draft.spec.provider.trim();
    if (providerId.isNotEmpty) {
      return providerId;
    }
    return context.shellText.notSet;
  }

  String _managedProviderLabel(ManagedProviderRecord record) {
    final displayName = record.name.trim();
    if (displayName.isNotEmpty) {
      return displayName;
    }
    final recordId = record.id.trim();
    return recordId.isEmpty ? context.shellText.notSet : recordId;
  }
}
