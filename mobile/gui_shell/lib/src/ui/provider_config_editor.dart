import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_shell_core/provider_settings_form.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/profile_draft.dart';

class ProviderConfigEditorPanel extends StatefulWidget {
  const ProviderConfigEditorPanel({
    super.key,
    required this.providerDescriptors,
    required this.selectedProviderConfigId,
    required this.draft,
    required this.busy,
    required this.onDraftChanged,
    required this.onSave,
    required this.onDelete,
    required this.onReset,
    required this.onApplyToProfileDraft,
  });

  final List<ProviderDescriptor> providerDescriptors;
  final String? selectedProviderConfigId;
  final ProviderConfigDraft draft;
  final bool busy;
  final ValueChanged<ProviderConfigDraft> onDraftChanged;
  final Future<void> Function() onSave;
  final Future<void> Function() onDelete;
  final VoidCallback onReset;
  final ValueChanged<String> onApplyToProfileDraft;

  @override
  State<ProviderConfigEditorPanel> createState() =>
      _ProviderConfigEditorPanelState();
}

class _ProviderConfigEditorPanelState extends State<ProviderConfigEditorPanel> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.draft.name);
  }

  @override
  void didUpdateWidget(covariant ProviderConfigEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft != widget.draft &&
        _nameController.text != widget.draft.name) {
      _nameController.value = _nameController.value.copyWith(
        text: widget.draft.name,
        selection: TextSelection.collapsed(offset: widget.draft.name.length),
        composing: TextRange.empty,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editableDescriptors = widget.providerDescriptors
        .where(
          (ProviderDescriptor descriptor) => descriptor.settingsSchema != null,
        )
        .toList(growable: false);
    final descriptor = _selectedDescriptor();
    final selectedSavedConfig = widget.selectedProviderConfigId != null;
    final blockedByAvailability =
        selectedSavedConfig && !widget.draft.availability.isAvailable;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Provider configs',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: widget.busy ? null : widget.onReset,
                  child: const Text('New'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                key: const ValueKey<String>('provider-config-workspace-scroll'),
                children: <Widget>[
                  Text(
                    'Reusable provider configs keep non-secret, descriptor-retained provider settings separate from runtime profiles and runtime controls.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (blockedByAvailability)
                    _unavailableCard(
                      theme,
                      widget.draft.availability.message.isEmpty
                          ? 'This provider config is not compatible with the currently advertised provider descriptor.'
                          : widget.draft.availability.message,
                    )
                  else if (editableDescriptors.isEmpty && descriptor == null)
                    _unavailableCard(
                      theme,
                      'The connected mobile host does not currently advertise any provider with reusable provider settings.',
                    )
                  else ...<Widget>[
                    _field(
                      controller: _nameController,
                      label: 'Config name',
                      onChanged: (String value) => _pushDraft(name: value),
                    ),
                    _providerField(editableDescriptors),
                    if (descriptor != null) ...<Widget>[
                      _descriptorSummary(theme, descriptor),
                      const SizedBox(height: 12),
                    ],
                    if (descriptor?.providerSettingsSupportError != null)
                      _unavailableCard(
                        theme,
                        'This mobile shell cannot render the provider settings schema for ${descriptor!.displayName}: ${descriptor.providerSettingsSupportError}. Save and apply stay blocked until the host advertises a supported schema subset.',
                      )
                    else if (descriptor != null) ...<Widget>[
                      Text(
                        'Reusable provider settings',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Only descriptor-retained, non-secret provider settings belong here. Runtime defaults stay in the profile workspace.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ProviderSettingsForm(
                        descriptor: descriptor,
                        values: widget.draft.providerSettings,
                        enabled: !widget.busy,
                        onChanged: (Map<String, dynamic> values) {
                          _pushDraft(providerSettings: values);
                        },
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey<String>('provider-config-save-button'),
              onPressed: widget.busy || blockedByAvailability
                  ? null
                  : () => unawaited(widget.onSave()),
              child: const Text('Save config'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              key: const ValueKey<String>('provider-config-apply-button'),
              onPressed:
                  widget.busy ||
                      widget.selectedProviderConfigId == null ||
                      blockedByAvailability
                  ? null
                  : () => widget.onApplyToProfileDraft(
                      widget.selectedProviderConfigId!,
                    ),
              child: const Text('Apply to profile draft'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const ValueKey<String>('provider-config-delete-button'),
              onPressed: widget.busy || widget.selectedProviderConfigId == null
                  ? null
                  : () => unawaited(widget.onDelete()),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: !widget.busy,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      ),
    );
  }

  Widget _providerField(List<ProviderDescriptor> descriptors) {
    if (descriptors.isEmpty) {
      return const SizedBox.shrink();
    }
    final selectedProviderId =
        _selectedDescriptor()?.id ?? descriptors.first.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: selectedProviderId,
        decoration: const InputDecoration(labelText: 'Provider'),
        items: descriptors
            .map(
              (ProviderDescriptor descriptor) => DropdownMenuItem<String>(
                value: descriptor.id,
                child: Text(descriptor.displayName),
              ),
            )
            .toList(growable: false),
        onChanged: widget.busy
            ? null
            : (String? value) {
                if (value == null) {
                  return;
                }
                _pushDraft(
                  provider: value,
                  providerSettings: const <String, dynamic>{},
                );
              },
      ),
    );
  }

  Widget _descriptorSummary(ThemeData theme, ProviderDescriptor descriptor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            descriptor.displayName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (descriptor.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(descriptor.description, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _unavailableCard(ThemeData theme, String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE2DE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message, style: theme.textTheme.bodyMedium),
    );
  }

  ProviderDescriptor? _selectedDescriptor() {
    final providerId = widget.draft.provider.trim().toLowerCase();
    for (final descriptor in widget.providerDescriptors) {
      if (descriptor.settingsSchema == null) {
        continue;
      }
      if (descriptor.id.trim().toLowerCase() == providerId) {
        return descriptor;
      }
    }
    for (final descriptor in widget.providerDescriptors) {
      if (descriptor.settingsSchema != null) {
        return descriptor;
      }
    }
    return null;
  }

  void _pushDraft({
    String? name,
    String? provider,
    Map<String, dynamic>? providerSettings,
  }) {
    widget.onDraftChanged(
      widget.draft.copyWith(
        name: name ?? widget.draft.name,
        provider: provider ?? widget.draft.provider,
        providerSettings: providerSettings ?? widget.draft.providerSettings,
      ),
    );
  }
}
