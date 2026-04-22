import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_shell_core/portable_profile_transfer.dart';
import 'package:flutter_shell_core/profile_workflow_surface.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/profile_draft.dart';
import 'package:mobile_gui_shell/src/ui/portable_profile_transfer_dialogs.dart';

class ProfileEditorPanel extends StatefulWidget {
  ProfileEditorPanel({
    super.key,
    required this.profiles,
    required this.providerDescriptors,
    required this.selectedProfileId,
    required this.draft,
    required this.busy,
    required this.onSelectProfile,
    required this.onDraftChanged,
    required this.onSave,
    required this.onDelete,
    required this.onReset,
    required this.onResolve,
    required this.onStart,
    required this.onPreparePortableExport,
    required this.onCopyPortableExportText,
    required this.onSharePortableExportText,
    required this.onSharePortableExportFile,
    required this.onImportPortableFromFile,
    required this.onPreviewPortableImport,
    required this.onConfirmPortableImport,
    this.pendingPortableImportEnvelope,
    this.onPendingPortableImportHandled,
    List<ManagedProviderRecord>? managedProviders,
    String? initialManagedProviderId,
    void Function({String? managedProviderId})? onActivateManagedProviderMode,
    VoidCallback? onUseCustomProvider,
    List<ProviderConfigRecord>? availableProviderConfigs,
    ValueChanged<String>? onApplyProviderConfig,
    this.showTitleBar = true,
    this.showSavedProfilesSection = true,
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

  final List<ProfileRecord> profiles;
  final List<ProviderDescriptor> providerDescriptors;
  final List<ManagedProviderRecord> managedProviders;
  final String? selectedManagedProviderId;
  final String? selectedProfileId;
  final ProfileDraft draft;
  final bool busy;
  final ValueChanged<String> onSelectProfile;
  final ValueChanged<ProfileDraft> onDraftChanged;
  final void Function({String? managedProviderId})
  onActivateManagedProviderMode;
  final VoidCallback onUseCustomProvider;
  final bool showTitleBar;
  final bool showSavedProfilesSection;
  final Future<void> Function() onSave;
  final Future<void> Function() onDelete;
  final VoidCallback onReset;
  final Future<void> Function() onResolve;
  final Future<void> Function() onStart;
  final PortableProfileEnvelope? Function() onPreparePortableExport;
  final Future<void> Function(PortableProfileEnvelope envelope)
  onCopyPortableExportText;
  final Future<void> Function(PortableProfileEnvelope envelope)
  onSharePortableExportText;
  final Future<void> Function(PortableProfileEnvelope envelope)
  onSharePortableExportFile;
  final Future<PortableProfileEnvelope?> Function() onImportPortableFromFile;
  final PortableProfileEnvelope? Function(String payload)
  onPreviewPortableImport;
  final Future<void> Function(PortableProfileEnvelope envelope)
  onConfirmPortableImport;
  final PortableProfileEnvelope? pendingPortableImportEnvelope;
  final VoidCallback? onPendingPortableImportHandled;

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
  String? _autoPreviewSignature;

  @override
  void initState() {
    super.initState();
    _schedulePendingPortableImportPreview();
  }

  @override
  void didUpdateWidget(covariant ProfileEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pendingPortableImportEnvelope == null) {
      _autoPreviewSignature = null;
      return;
    }
    if (oldWidget.pendingPortableImportEnvelope !=
        widget.pendingPortableImportEnvelope) {
      _schedulePendingPortableImportPreview();
    }
  }

  void _schedulePendingPortableImportPreview() {
    final envelope = widget.pendingPortableImportEnvelope;
    if (envelope == null) {
      _autoPreviewSignature = null;
      return;
    }
    final signature = envelope.encode();
    if (_autoPreviewSignature == signature) {
      return;
    }
    _autoPreviewSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onPendingPortableImportHandled?.call();
      unawaited(_showPortableImportPreview(envelope));
    });
  }

  Future<void> _showPortableImportPreview(
    PortableProfileEnvelope envelope,
  ) async {
    await showPortableProfileImportPreviewDialog(
      context: context,
      envelope: envelope,
      onConfirm: widget.onConfirmPortableImport,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = context.shellText;
    final hasSavedProfile = widget.selectedProfileId != null;
    final primaryLabel = hasSavedProfile
        ? copy.startSavedProfile
        : copy.resolveInvite;
    final Future<void> Function() primaryAction = hasSavedProfile
        ? widget.onStart
        : widget.onResolve;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (widget.showTitleBar) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      copy.mobileProfilesTitleBar,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: widget.busy ? null : widget.onReset,
                    child: Text(copy.newItem),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            ProfileWorkflowBody(
              variant: ProfileWorkflowVariant.mobile,
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
              leadingChildren: widget.showSavedProfilesSection
                  ? <Widget>[_savedProfilesSection(theme)]
                  : const <Widget>[],
              bottomChildren: <Widget>[
                _footerActionBar(
                  primaryLabel: primaryLabel,
                  onPrimaryPressed: widget.busy
                      ? null
                      : () => unawaited(primaryAction.call()),
                  onSavePressed: widget.busy
                      ? null
                      : () => unawaited(widget.onSave()),
                ),
              ],
              nameFieldKey: const ValueKey<String>('profile-editor-name-field'),
              providerFieldKey: const ValueKey<String>(
                'profile-editor-provider-field',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _savedProfilesSection(ThemeData theme) {
    if (widget.profiles.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          context.shellText.mobileNoSavedProfilesYetBuildDraft,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.shellText.mobileSavedProfiles,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: widget.profiles
              .map((ProfileRecord profile) {
                final label = profile.name.isEmpty ? profile.id : profile.name;
                return ChoiceChip(
                  selected: widget.selectedProfileId == profile.id,
                  label: Text(label),
                  onSelected: widget.busy
                      ? null
                      : (_) => widget.onSelectProfile(profile.id),
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _footerActionBar({
    required String primaryLabel,
    required VoidCallback? onPrimaryPressed,
    required VoidCallback? onSavePressed,
  }) {
    final theme = Theme.of(context);
    final copy = context.shellText;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final compact = constraints.maxWidth < 760;
        final saveButton = compact
            ? IconButton.filledTonal(
                key: const ValueKey<String>('profile-editor-save-action'),
                tooltip: copy.saveProfile,
                onPressed: onSavePressed,
                icon: const Icon(Icons.save_outlined),
              )
            : FilledButton.tonalIcon(
                key: const ValueKey<String>('profile-editor-save-action'),
                onPressed: onSavePressed,
                icon: const Icon(Icons.save_outlined),
                label: Text(copy.saveProfile),
              );
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.16,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  key: const ValueKey<String>('profile-editor-primary-action'),
                  onPressed: onPrimaryPressed,
                  child: Text(primaryLabel),
                ),
              ),
              const SizedBox(width: 12),
              saveButton,
            ],
          ),
        );
      },
    );
  }
}
