import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_shell_core/provider_settings_form.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/profile_draft.dart';

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
                        'App-owned provider catalog',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        selectedSavedProvider
                            ? 'Editing a managed provider record from the shipped provider catalog'
                            : 'Select a shipped provider family, then create a managed provider record',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: widget.busy ? null : widget.onReset,
                  child: const Text('New record'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                key: const ValueKey<String>(
                  'managed-provider-workspace-scroll',
                ),
                children: <Widget>[
                  Text(
                    'The app owns the supported provider catalog. Host descriptors only overlay current availability and reusable-field validation. Applying a managed record still snapshots its current provider values into the active profile draft.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (widget.supportedProviders.isEmpty)
                    _unavailableCard(
                      theme,
                      'This build does not advertise any shipped provider families yet.',
                    )
                  else ...<Widget>[
                    _supportedProviderCatalog(theme),
                    const SizedBox(height: 16),
                    if (supportedProvider != null)
                      _selectedFamilyCard(
                        theme,
                        provider: supportedProvider,
                        availability: hostAvailability,
                        descriptor: descriptor,
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Managed provider record',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This shell-owned record stores only reusable, non-secret provider-owned values for the selected shipped family.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _nameController,
                      label: 'Managed record name',
                      onChanged: (String value) => _pushDraft(name: value),
                    ),
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
                        'This mobile shell cannot render the provider settings schema for ${descriptor!.displayName}: ${descriptor.providerSettingsSupportError}. Save stays blocked until the host advertises a supported schema subset.',
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
              key: const ValueKey<String>('managed-provider-save-button'),
              onPressed: widget.busy || blockedBySchemaSupport
                  ? null
                  : () => unawaited(widget.onSave()),
              child: const Text('Save managed record'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              key: const ValueKey<String>('managed-provider-apply-button'),
              onPressed: widget.busy || widget.selectedManagedProviderId == null
                  ? null
                  : () => widget.onApplyToProfileDraft(
                      widget.selectedManagedProviderId!,
                    ),
              child: const Text('Apply record to profile draft'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const ValueKey<String>('managed-provider-delete-button'),
              onPressed: widget.busy || widget.selectedManagedProviderId == null
                  ? null
                  : () => unawaited(widget.onDelete()),
              child: const Text('Delete record'),
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

  Widget _supportedProviderCatalog(ThemeData theme) {
    final selectedProviderId = _selectedSupportedProvider()?.id
        .trim()
        .toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Supported provider families',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Shipped provider families stay visible here even when the connected host cannot currently run them.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ...widget.supportedProviders.map((
          SupportedProviderDefinition provider,
        ) {
          final availability = provider.availabilityFor(
            widget.providerDescriptors,
          );
          final descriptor = availability.descriptor;
          final selected =
              provider.id.trim().toLowerCase() == selectedProviderId;
          final managedFieldLabel = _managedFieldSurfaceLabel(descriptor);
          final canSelect =
              !widget.busy &&
              provider.id.trim().toLowerCase() !=
                  widget.draft.provider.trim().toLowerCase();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.08)
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                key: ValueKey<String>('supported-provider-card-${provider.id}'),
                borderRadius: BorderRadius.circular(14),
                onTap: !canSelect
                    ? null
                    : () => _pushDraft(
                        provider: provider.id,
                        providerSettings: const <String, dynamic>{},
                      ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              provider.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _stateChip(
                            theme,
                            label: availability.isAvailable
                                ? 'Available'
                                : 'Unavailable',
                            accent: availability.isAvailable,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        provider.description,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _metaChip(
                            theme,
                            label: selected
                                ? 'Selected family'
                                : 'Shipped by app',
                            accent: selected,
                          ),
                          _metaChip(
                            theme,
                            label: managedFieldLabel,
                            accent:
                                descriptor?.settingsSchema != null &&
                                descriptor?.providerSettingsSupportError ==
                                    null,
                          ),
                        ],
                      ),
                      if (availability.message.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          availability.message,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
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
    );
  }

  Widget _selectedFamilyCard(
    ThemeData theme, {
    required SupportedProviderDefinition provider,
    required SupportedProviderAvailability? availability,
    required ProviderDescriptor? descriptor,
  }) {
    final fieldLabel = _managedFieldSurfaceLabel(descriptor);
    final fieldAccent =
        descriptor?.settingsSchema != null &&
        descriptor?.providerSettingsSupportError == null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE6EDF7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  provider.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _metaChip(theme, label: 'Selected family', accent: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(provider.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _metaChip(theme, label: 'App-owned catalog', accent: true),
              if (availability != null)
                _metaChip(
                  theme,
                  label: availability.isAvailable
                      ? 'Host overlay: available'
                      : 'Host overlay: unavailable',
                  accent: availability.isAvailable,
                ),
              _metaChip(theme, label: fieldLabel, accent: fieldAccent),
            ],
          ),
        ],
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

  Widget _infoCard(ThemeData theme, String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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

  Widget _stateChip(
    ThemeData theme, {
    required String label,
    required bool accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (accent ? theme.colorScheme.primary : theme.colorScheme.error)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: accent ? theme.colorScheme.primary : theme.colorScheme.error,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _metaChip(
    ThemeData theme, {
    required String label,
    required bool accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:
            (accent
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.onSurfaceVariant)
                .withValues(alpha: accent ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: accent
              ? theme.colorScheme.secondary
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
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

  String _managedFieldSurfaceLabel(ProviderDescriptor? descriptor) {
    if (descriptor == null) {
      return 'No reusable fields yet';
    }
    if (descriptor.providerSettingsSupportError != null) {
      return 'Schema blocked in this shell';
    }
    if (descriptor.settingsSchema == null) {
      return 'No reusable fields yet';
    }
    return 'Reusable fields ready';
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
