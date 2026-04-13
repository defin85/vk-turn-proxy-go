import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_shell_core/provider_settings_form.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/profile_draft.dart';

class ProviderConfigEditorPanel extends StatefulWidget {
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
    final supportedProvider = _selectedSupportedProvider();
    final descriptor = _selectedDescriptor();
    final selectedSavedProvider = widget.selectedManagedProviderId != null;
    final blockedBySchemaSupport =
        descriptor?.providerSettingsSupportError != null &&
        widget.draft.providerSettings.isNotEmpty;
    final hostAvailability = supportedProvider?.availabilityFor(
      widget.providerDescriptors,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Providers workspace',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        selectedSavedProvider
                            ? 'Editing a managed provider record'
                            : 'Creating a managed provider record',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: widget.busy ? null : widget.onReset,
                  icon: const Icon(Icons.tune),
                  label: const Text('Fresh provider'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                key: const ValueKey<String>('provider-config-workspace-scroll'),
                children: <Widget>[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Managed providers are app-owned reusable records for shipped provider families. Applying one copies its current provider snapshot into the profile draft without creating a hidden live reference.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  if (widget.supportedProviders.isEmpty)
                    _unavailableCard(
                      theme,
                      'This build does not advertise any shipped provider families yet.',
                    )
                  else ...<Widget>[
                    _field(
                      controller: _nameController,
                      label: 'Provider name',
                      onChanged: (String value) => _pushDraft(name: value),
                    ),
                    _providerField(widget.supportedProviders),
                    if (hostAvailability != null &&
                        !hostAvailability.isAvailable) ...<Widget>[
                      _unavailableCard(theme, hostAvailability.message),
                      const SizedBox(height: 12),
                    ],
                    if (descriptor != null) ...<Widget>[
                      _descriptorSummary(theme, descriptor),
                      const SizedBox(height: 12),
                    ],
                    if (descriptor?.providerSettingsSupportError != null &&
                        widget.draft.providerSettings.isNotEmpty)
                      _unavailableCard(
                        theme,
                        'This desktop shell cannot render the provider settings schema for ${descriptor!.displayName}: ${descriptor.providerSettingsSupportError}. Save stays blocked until the host advertises a supported schema subset.',
                      )
                    else if (descriptor?.settingsSchema == null)
                      _infoCard(
                        theme,
                        supportedProvider == null
                            ? 'This managed provider currently has no reusable field surface in the shipped shell.'
                            : '${supportedProvider.title} currently has no reusable managed fields in this shipped shell. The record still stays valid as a named supported provider entry.',
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
                        'Only descriptor-retained, non-secret provider settings belong here. Runtime defaults and profile input stay in the profile workspace.',
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
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                FilledButton(
                  onPressed: widget.busy || blockedBySchemaSupport
                      ? null
                      : () => unawaited(widget.onSave()),
                  child: const Text('Save provider'),
                ),
                FilledButton.tonal(
                  onPressed:
                      widget.busy || widget.selectedManagedProviderId == null
                      ? null
                      : () => widget.onApplyToProfileDraft(
                          widget.selectedManagedProviderId!,
                        ),
                  child: const Text('Apply to profile draft'),
                ),
                OutlinedButton(
                  onPressed:
                      widget.busy || widget.selectedManagedProviderId == null
                      ? null
                      : () => unawaited(widget.onDelete()),
                  child: const Text('Delete'),
                ),
              ],
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

  Widget _providerField(List<SupportedProviderDefinition> providers) {
    if (providers.isEmpty) {
      return const SizedBox.shrink();
    }
    final selectedProviderId =
        _selectedSupportedProvider()?.id ?? providers.first.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: selectedProviderId,
        decoration: const InputDecoration(labelText: 'Provider'),
        items: providers
            .map(
              (SupportedProviderDefinition provider) =>
                  DropdownMenuItem<String>(
                    value: provider.id,
                    child: Text(provider.title),
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
        color: const Color(0xFFE6EDF7),
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
          const SizedBox(height: 6),
          Text(
            descriptor.description.isEmpty
                ? '${descriptor.authPosture.label}. ${descriptor.browserPolicy.label}.'
                : descriptor.description,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _unavailableCard(ThemeData theme, String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE2DE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message, style: theme.textTheme.bodyMedium),
    );
  }

  Widget _infoCard(ThemeData theme, String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message, style: theme.textTheme.bodyMedium),
    );
  }

  SupportedProviderDefinition? _selectedSupportedProvider() {
    final providerId = widget.draft.provider.trim().toLowerCase();
    for (final provider in widget.supportedProviders) {
      if (provider.id.trim().toLowerCase() == providerId) {
        return provider;
      }
    }
    return widget.supportedProviders.isEmpty
        ? null
        : widget.supportedProviders.first;
  }

  ProviderDescriptor? _selectedDescriptor() {
    final providerId = widget.draft.provider.trim().toLowerCase();
    for (final descriptor in widget.providerDescriptors) {
      if (descriptor.id.trim().toLowerCase() == providerId) {
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
