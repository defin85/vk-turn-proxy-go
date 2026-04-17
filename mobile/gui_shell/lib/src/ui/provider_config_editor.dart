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
    required this.onSaveAsTemplate,
    required this.onDelete,
    required this.onApplyToProfileDraft,
    required this.onClose,
    this.showCloseButton = false,
  });

  final List<SupportedProviderDefinition> supportedProviders;
  final List<ProviderDescriptor> providerDescriptors;
  final String? selectedManagedProviderId;
  final ManagedProviderDraft draft;
  final bool busy;
  final ValueChanged<ManagedProviderDraft> onDraftChanged;
  final Future<void> Function() onSave;
  final VoidCallback onSaveAsTemplate;
  final Future<void> Function() onDelete;
  final ValueChanged<String> onApplyToProfileDraft;
  final VoidCallback onClose;
  final bool showCloseButton;

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
    final canRenderReusableSettings =
        descriptor != null &&
        descriptor.settingsSchema != null &&
        descriptor.providerSettingsSupportError == null;
    final editorTitle = selectedSavedProvider
        ? 'Edit provider'
        : 'New provider';
    final editorDetail = selectedSavedProvider
        ? 'Edit this saved reusable provider.'
        : 'Finish this saved reusable provider for later use in Profiles.';
    final blockedBySchemaSupport =
        descriptor?.providerSettingsSupportError != null &&
        widget.draft.providerSettings.isNotEmpty;
    final hostAvailability = supportedProvider?.availabilityFor(
      widget.providerDescriptors,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                if (widget.showCloseButton) ...<Widget>[
                  const SizedBox(width: 12),
                  IconButton(
                    key: const ValueKey<String>(
                      'managed-provider-close-button',
                    ),
                    tooltip: 'Close provider editor',
                    onPressed: widget.busy ? null : widget.onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                key: const ValueKey<String>(
                  'managed-provider-workspace-scroll',
                ),
                padding: const EdgeInsets.only(bottom: 8),
                children: <Widget>[
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
                    Text(
                      'Shown in Profiles when choosing a saved reusable provider.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Provider type',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Chosen when this saved provider was created. Use this pane to name it and review reusable settings.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (supportedProvider != null)
                      _selectedFamilyCard(
                        theme,
                        provider: supportedProvider,
                        availability: hostAvailability,
                        descriptor: descriptor,
                        compactNote: descriptor?.settingsSchema == null
                            ? supportedProvider.title.isEmpty
                                  ? 'No reusable settings yet. Save this as a named provider for Profiles.'
                                  : 'No reusable settings yet. Save ${supportedProvider.title} as a named provider for Profiles.'
                            : null,
                      ),
                    if (hostAvailability != null &&
                        !hostAvailability.isAvailable) ...<Widget>[
                      const SizedBox(height: 12),
                      _unavailableCard(theme, hostAvailability.message),
                    ],
                    if (descriptor?.providerSettingsSupportError != null &&
                        widget.draft.providerSettings.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      _unavailableCard(
                        theme,
                        'This mobile shell cannot render the provider settings schema for ${descriptor!.displayName}: ${descriptor.providerSettingsSupportError}. Save stays blocked until the host advertises a supported schema subset.',
                      ),
                    ] else if (canRenderReusableSettings) ...<Widget>[
                      const SizedBox(height: 20),
                      Text(
                        'Reusable provider settings',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'These reusable values are applied when this provider is used in a profile.',
                        style: theme.textTheme.bodySmall?.copyWith(
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
            const Divider(height: 1),
            const SizedBox(height: 16),
            OverflowBar(
              spacing: 12,
              overflowSpacing: 12,
              alignment: MainAxisAlignment.start,
              children: <Widget>[
                FilledButton(
                  key: const ValueKey<String>('managed-provider-save-button'),
                  onPressed: widget.busy || blockedBySchemaSupport
                      ? null
                      : () => unawaited(widget.onSave()),
                  child: const Text('Save provider'),
                ),
                TextButton.icon(
                  key: const ValueKey<String>(
                    'managed-provider-save-template-button',
                  ),
                  onPressed: widget.busy || blockedBySchemaSupport
                      ? null
                      : widget.onSaveAsTemplate,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Save as template'),
                ),
                if (widget.selectedManagedProviderId != null)
                  TextButton.icon(
                    key: const ValueKey<String>(
                      'managed-provider-apply-button',
                    ),
                    onPressed: widget.busy
                        ? null
                        : () => widget.onApplyToProfileDraft(
                            widget.selectedManagedProviderId!,
                          ),
                    icon: const Icon(Icons.assignment_turned_in_outlined),
                    label: const Text('Use in profile draft'),
                  ),
                if (widget.selectedManagedProviderId != null)
                  OutlinedButton(
                    key: const ValueKey<String>(
                      'managed-provider-delete-button',
                    ),
                    onPressed: widget.busy
                        ? null
                        : () => unawaited(widget.onDelete()),
                    child: const Text('Delete provider'),
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

  Widget _selectedFamilyCard(
    ThemeData theme, {
    required SupportedProviderDefinition provider,
    required SupportedProviderAvailability? availability,
    required ProviderDescriptor? descriptor,
    String? compactNote,
  }) {
    final fieldLabel = _managedFieldSurfaceLabel(descriptor);
    final fieldAccent =
        descriptor?.settingsSchema != null &&
        descriptor?.providerSettingsSupportError == null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.38,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
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
              if (availability != null)
                _metaChip(
                  theme,
                  label: availability.isAvailable ? 'Available' : 'Unavailable',
                  accent: availability.isAvailable,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            provider.description,
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _metaChip(theme, label: 'Selected type', accent: true),
              _metaChip(theme, label: fieldLabel, accent: fieldAccent),
            ],
          ),
          if (compactNote != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              compactNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
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

class ProviderTemplateEditorPanel extends StatefulWidget {
  const ProviderTemplateEditorPanel({
    super.key,
    required this.supportedProviders,
    required this.providerDescriptors,
    required this.selectedProviderTemplateId,
    required this.draft,
    required this.busy,
    required this.onDraftChanged,
    required this.onSave,
    required this.onDelete,
    required this.onUseTemplate,
    required this.onClose,
    this.showCloseButton = false,
  });

  final List<SupportedProviderDefinition> supportedProviders;
  final List<ProviderDescriptor> providerDescriptors;
  final String? selectedProviderTemplateId;
  final ProviderTemplateDraft draft;
  final bool busy;
  final ValueChanged<ProviderTemplateDraft> onDraftChanged;
  final Future<void> Function() onSave;
  final Future<void> Function() onDelete;
  final ValueChanged<String> onUseTemplate;
  final VoidCallback onClose;
  final bool showCloseButton;

  @override
  State<ProviderTemplateEditorPanel> createState() =>
      _ProviderTemplateEditorPanelState();
}

class _ProviderTemplateEditorPanelState
    extends State<ProviderTemplateEditorPanel> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.draft.name);
  }

  @override
  void didUpdateWidget(covariant ProviderTemplateEditorPanel oldWidget) {
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
    final selectedTemplate = widget.selectedProviderTemplateId != null;
    final canRenderReusableSettings =
        descriptor != null &&
        descriptor.settingsSchema != null &&
        descriptor.providerSettingsSupportError == null;
    final editorTitle = selectedTemplate ? 'Edit template' : 'New template';
    final editorDetail = selectedTemplate
        ? 'Edit starting values for future providers.'
        : 'Save a starting point for future providers.';
    final blockedBySchemaSupport =
        descriptor?.providerSettingsSupportError != null &&
        widget.draft.providerSettings.isNotEmpty;
    final hostAvailability = supportedProvider?.availabilityFor(
      widget.providerDescriptors,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                if (widget.showCloseButton) ...<Widget>[
                  const SizedBox(width: 12),
                  IconButton(
                    key: const ValueKey<String>(
                      'provider-template-close-button',
                    ),
                    tooltip: 'Close template editor',
                    onPressed: widget.busy ? null : widget.onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                key: const ValueKey<String>(
                  'provider-template-workspace-scroll',
                ),
                padding: const EdgeInsets.only(bottom: 8),
                children: <Widget>[
                  if (widget.supportedProviders.isEmpty)
                    _unavailableCard(
                      theme,
                      'This build does not advertise any shipped provider families yet.',
                    )
                  else ...<Widget>[
                    _field(
                      controller: _nameController,
                      label: 'Template name',
                      onChanged: (String value) => _pushDraft(name: value),
                    ),
                    Text(
                      'Shown when choosing a starting point for new providers.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Provider type',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Chosen when this template was created. Use this pane to name it and review reusable starting values.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (supportedProvider != null)
                      _selectedFamilyCard(
                        theme,
                        provider: supportedProvider,
                        availability: hostAvailability,
                        descriptor: descriptor,
                        compactNote: descriptor?.settingsSchema == null
                            ? supportedProvider.title.isEmpty
                                  ? 'No reusable settings yet. Save this template as a named starting point.'
                                  : 'No reusable settings yet. Save ${supportedProvider.title} as a named starting point.'
                            : null,
                      ),
                    if (hostAvailability != null &&
                        !hostAvailability.isAvailable) ...<Widget>[
                      const SizedBox(height: 12),
                      _unavailableCard(theme, hostAvailability.message),
                    ],
                    if (descriptor?.providerSettingsSupportError != null &&
                        widget.draft.providerSettings.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      _unavailableCard(
                        theme,
                        'This mobile shell cannot render the provider settings schema for ${descriptor!.displayName}: ${descriptor.providerSettingsSupportError}. Save stays blocked until the host advertises a supported schema subset.',
                      ),
                    ] else if (canRenderReusableSettings) ...<Widget>[
                      const SizedBox(height: 20),
                      Text(
                        'Reusable provider settings',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'These values prefill a new provider when this template is used.',
                        style: theme.textTheme.bodySmall?.copyWith(
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
            const Divider(height: 1),
            const SizedBox(height: 16),
            OverflowBar(
              spacing: 12,
              overflowSpacing: 12,
              alignment: MainAxisAlignment.start,
              children: <Widget>[
                FilledButton(
                  key: const ValueKey<String>('provider-template-save-button'),
                  onPressed: widget.busy || blockedBySchemaSupport
                      ? null
                      : () => unawaited(widget.onSave()),
                  child: const Text('Save template'),
                ),
                if (widget.selectedProviderTemplateId != null)
                  TextButton.icon(
                    key: const ValueKey<String>('provider-template-use-button'),
                    onPressed: widget.busy
                        ? null
                        : () => widget.onUseTemplate(
                            widget.selectedProviderTemplateId!,
                          ),
                    icon: const Icon(Icons.playlist_add_check_outlined),
                    label: const Text('Use template'),
                  ),
                if (widget.selectedProviderTemplateId != null)
                  OutlinedButton(
                    key: const ValueKey<String>(
                      'provider-template-delete-button',
                    ),
                    onPressed: widget.busy
                        ? null
                        : () => unawaited(widget.onDelete()),
                    child: const Text('Delete template'),
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

  Widget _selectedFamilyCard(
    ThemeData theme, {
    required SupportedProviderDefinition provider,
    required SupportedProviderAvailability? availability,
    required ProviderDescriptor? descriptor,
    String? compactNote,
  }) {
    final fieldLabel = _managedFieldSurfaceLabel(descriptor);
    final fieldAccent =
        descriptor?.settingsSchema != null &&
        descriptor?.providerSettingsSupportError == null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.38,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
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
              if (availability != null)
                _metaChip(
                  theme,
                  label: availability.isAvailable ? 'Available' : 'Unavailable',
                  accent: availability.isAvailable,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            provider.description,
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _metaChip(theme, label: 'Selected type', accent: true),
              _metaChip(theme, label: fieldLabel, accent: fieldAccent),
            ],
          ),
          if (compactNote != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              compactNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
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
