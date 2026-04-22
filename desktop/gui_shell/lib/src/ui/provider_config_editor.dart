import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_shell_core/flutter_shell_core.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';

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
    final headerActions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        FilledButton(
          key: const ValueKey<String>('managed-provider-save-action'),
          onPressed: busy || blockedBySchemaSupport
              ? null
              : () => unawaited(onSave()),
          child: Text(_nextStepTitle(context, supportedProvider)),
        ),
        FilledButton.tonal(
          key: const ValueKey<String>('managed-provider-apply-action'),
          onPressed: busy || selectedManagedProviderId == null
              ? null
              : () => onApplyToProfileDraft(selectedManagedProviderId!),
          child: Text(copy.desktopUseInProfileDraft),
        ),
        OutlinedButton(
          key: const ValueKey<String>('managed-provider-delete-action'),
          onPressed: busy || selectedManagedProviderId == null
              ? null
              : () => unawaited(onDelete()),
          child: Text(copy.delete),
        ),
        FilledButton.tonalIcon(
          onPressed: busy ? null : onReset,
          icon: const Icon(Icons.tune),
          label: Text(copy.desktopNewRecord),
        ),
      ],
    );

    return Card(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final stackHeader = constraints.maxWidth < 1080;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (stackHeader)
                  Column(
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
                      const SizedBox(height: 14),
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
                        ),
                      ),
                      const SizedBox(width: 16),
                      Flexible(child: headerActions),
                    ],
                  ),
                const SizedBox(height: 16),
                Expanded(
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
              ],
            ),
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
