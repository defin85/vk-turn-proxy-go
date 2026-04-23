import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_shell_core/flutter_shell_core.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';

enum _ProviderEditorMenuAction {
  openManagedProviders,
  openPresetBootstrap,
  chooseFamily,
  resetDraft,
  deleteRecord,
}

class ProviderConfigEditorPanel extends StatelessWidget {
  const ProviderConfigEditorPanel({
    super.key,
    required this.supportedProviders,
    required this.providerDescriptors,
    required this.selectedManagedProviderId,
    required this.draft,
    required this.busy,
    required this.onDraftChanged,
    required this.onSave,
    required this.onDelete,
    required this.onReset,
    required this.onApplyToProfileDraft,
    this.onChooseProviderFamily,
    this.onOpenPresetBootstrap,
    this.onBrowseManagedProviders,
  });

  final List<SupportedProviderDefinition> supportedProviders;
  final List<ProviderDescriptor> providerDescriptors;
  final String? selectedManagedProviderId;
  final ManagedProviderDraft draft;
  final bool busy;
  final ValueChanged<ManagedProviderDraft> onDraftChanged;
  final Future<void> Function() onSave;
  final Future<void> Function() onDelete;
  final VoidCallback onReset;
  final ValueChanged<String> onApplyToProfileDraft;
  final Future<void> Function()? onChooseProviderFamily;
  final Future<void> Function()? onOpenPresetBootstrap;
  final Future<void> Function()? onBrowseManagedProviders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = context.shellText;
    final supportedProvider = _selectedSupportedProvider();
    final descriptor = _selectedDescriptor();
    final selectedSavedProvider = selectedManagedProviderId != null;
    final editorTitle = selectedSavedProvider
        ? copy.desktopProviderRecord
        : copy.desktopNewProviderRecord;
    final editorDetail = selectedSavedProvider
        ? copy.desktopEditReusableProviderRecord
        : copy.desktopCreateReusableProviderRecord;
    final blockedBySchemaSupport =
        descriptor?.providerSettingsSupportError != null &&
        draft.providerSettings.isNotEmpty;
    final primaryActionKey = supportedProvider == null
        ? const ValueKey<String>('desktop-open-provider-family-chooser-button')
        : const ValueKey<String>('managed-provider-save-action');
    final primaryActionLabel = _nextStepTitle(context, supportedProvider);
    final VoidCallback? onPrimaryPressed = busy || blockedBySchemaSupport
        ? null
        : supportedProvider == null
        ? (onChooseProviderFamily == null
              ? null
              : () => unawaited(onChooseProviderFamily!()))
        : () => unawaited(onSave());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final stackedHeader = constraints.maxWidth < 960;
            final headerActions = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonalIcon(
                  key: const ValueKey<String>('managed-provider-reset-action'),
                  onPressed: busy ? null : onReset,
                  icon: const Icon(Icons.tune),
                  label: Text(copy.desktopNewRecord),
                ),
                _buildMoreActionsButton(context, selectedSavedProvider),
              ],
            );
            final titleBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  editorTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  editorDetail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (stackedHeader) ...<Widget>[
                  titleBlock,
                  const SizedBox(height: 14),
                  headerActions,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: titleBlock),
                      const SizedBox(width: 16),
                      Flexible(child: headerActions),
                    ],
                  ),
                const SizedBox(height: 16),
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: ManagedProviderWorkflowBody(
                        variant: ManagedProviderWorkflowVariant.desktop,
                        supportedProviders: supportedProviders,
                        providerDescriptors: providerDescriptors,
                        selectedManagedProviderId: selectedManagedProviderId,
                        draft: draft,
                        busy: busy,
                        onDraftChanged: onDraftChanged,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _footerActionBar(
                  context,
                  primaryKey: primaryActionKey,
                  primaryLabel: primaryActionLabel,
                  onPrimaryPressed: onPrimaryPressed,
                  onApplyPressed: busy || selectedManagedProviderId == null
                      ? null
                      : () => onApplyToProfileDraft(selectedManagedProviderId!),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMoreActionsButton(
    BuildContext context,
    bool selectedSavedProvider,
  ) {
    return PopupMenuButton<_ProviderEditorMenuAction>(
      key: const ValueKey<String>('managed-provider-more-actions-button'),
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      onSelected: (_ProviderEditorMenuAction action) {
        switch (action) {
          case _ProviderEditorMenuAction.openManagedProviders:
            if (onBrowseManagedProviders != null) {
              unawaited(onBrowseManagedProviders!());
            }
            break;
          case _ProviderEditorMenuAction.openPresetBootstrap:
            if (onOpenPresetBootstrap != null) {
              unawaited(onOpenPresetBootstrap!());
            }
            break;
          case _ProviderEditorMenuAction.chooseFamily:
            if (onChooseProviderFamily != null) {
              unawaited(onChooseProviderFamily!());
            }
            break;
          case _ProviderEditorMenuAction.resetDraft:
            onReset();
            break;
          case _ProviderEditorMenuAction.deleteRecord:
            unawaited(onDelete());
            break;
        }
      },
      itemBuilder: (BuildContext context) {
        final items = <PopupMenuEntry<_ProviderEditorMenuAction>>[];
        if (onBrowseManagedProviders != null) {
          items.add(
            PopupMenuItem<_ProviderEditorMenuAction>(
              key: const ValueKey<String>(
                'desktop-open-managed-provider-library-button',
              ),
              value: _ProviderEditorMenuAction.openManagedProviders,
              child: Text(context.shellText.desktopProviderRecordsLibraryTitle),
            ),
          );
        }
        if (onOpenPresetBootstrap != null) {
          items.add(
            PopupMenuItem<_ProviderEditorMenuAction>(
              key: const ValueKey<String>(
                'desktop-open-preset-bootstrap-button',
              ),
              value: _ProviderEditorMenuAction.openPresetBootstrap,
              child: Text(t.commonNewFromPreset),
            ),
          );
        }
        if (onChooseProviderFamily != null) {
          items.add(
            PopupMenuItem<_ProviderEditorMenuAction>(
              key: const ValueKey<String>(
                'desktop-open-provider-family-chooser-menu-item',
              ),
              value: _ProviderEditorMenuAction.chooseFamily,
              child: Text(context.shellText.desktopChooseFamily),
            ),
          );
        }
        items.add(
          PopupMenuItem<_ProviderEditorMenuAction>(
            key: const ValueKey<String>('managed-provider-reset-menu-action'),
            value: _ProviderEditorMenuAction.resetDraft,
            child: Text(context.shellText.desktopNewRecord),
          ),
        );
        if (selectedSavedProvider) {
          items.add(
            PopupMenuItem<_ProviderEditorMenuAction>(
              key: const ValueKey<String>('managed-provider-delete-action'),
              value: _ProviderEditorMenuAction.deleteRecord,
              child: Text(context.shellText.delete),
            ),
          );
        }
        return items;
      },
      icon: const Icon(Icons.more_horiz),
    );
  }

  Widget _footerActionBar(
    BuildContext context, {
    required Key primaryKey,
    required String primaryLabel,
    required VoidCallback? onPrimaryPressed,
    required VoidCallback? onApplyPressed,
  }) {
    final theme = Theme.of(context);
    final primaryButton = FilledButton(
      key: primaryKey,
      onPressed: onPrimaryPressed,
      child: Text(primaryLabel),
    );
    final applyButton = FilledButton.tonal(
      key: const ValueKey<String>('managed-provider-apply-action'),
      onPressed: onApplyPressed,
      child: Text(context.shellText.desktopUseInProfileDraft),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.16,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth < 640) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                primaryButton,
                const SizedBox(height: 12),
                applyButton,
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(child: primaryButton),
              const SizedBox(width: 12),
              applyButton,
            ],
          );
        },
      ),
    );
  }

  SupportedProviderDefinition? _selectedSupportedProvider() {
    final providerId = draft.provider.trim().toLowerCase();
    if (providerId.isEmpty) {
      return supportedProviders.isEmpty ? null : supportedProviders.first;
    }
    for (final provider in supportedProviders) {
      if (provider.id.trim().toLowerCase() == providerId) {
        return provider;
      }
    }
    return null;
  }

  ProviderDescriptor? _selectedDescriptor() {
    final providerId = draft.provider.trim().toLowerCase();
    for (final descriptor in providerDescriptors) {
      if (descriptor.id.trim().toLowerCase() == providerId) {
        return descriptor;
      }
    }
    return null;
  }

  String _nextStepTitle(
    BuildContext context,
    SupportedProviderDefinition? provider,
  ) {
    if (provider == null) {
      return context.shellText.desktopChooseFamily;
    }
    if (draft.name.trim().isEmpty) {
      return context.shellText.desktopSaveDraft;
    }
    return context.shellText.desktopSaveRecord;
  }
}
