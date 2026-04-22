import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter_shell_core/provider_settings_form.dart';
import 'package:flutter_shell_core/shell_visuals.dart';
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
    final copy = context.shellText;
    final supportedProvider = _selectedSupportedProvider();
    final descriptor = _selectedDescriptor();
    final selectedSavedProvider = widget.selectedManagedProviderId != null;
    final canRenderReusableSettings =
        descriptor != null &&
        descriptor.settingsSchema != null &&
        descriptor.providerSettingsSupportError == null;
    final editorTitle = selectedSavedProvider
        ? copy.mobileEditProvider
        : copy.mobileNewProvider;
    final editorDetail = selectedSavedProvider
        ? copy.mobileEditSavedReusableProvider
        : copy.mobileFinishSavedReusableProvider;
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
                    tooltip: copy.mobileCloseProviderEditor,
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
                      copy.mobileNoShippedProviderFamilies,
                    )
                  else ...<Widget>[
                    _field(
                      controller: _nameController,
                      label: copy.mobileProviderName,
                      onChanged: (String value) => _pushDraft(name: value),
                    ),
                    Text(
                      copy.mobileProviderShownInProfiles,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      copy.providerType,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      copy.mobileProviderTypeChosenWhenCreated,
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
                            ? copy.mobileNoReusableSettingsYetNamedProvider(
                                supportedProvider.title,
                              )
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
                        copy.mobileProviderConfigSupportError(
                          providerName: descriptor!.displayName,
                          error: descriptor.providerSettingsSupportError!,
                        ),
                      ),
                    ] else if (canRenderReusableSettings) ...<Widget>[
                      const SizedBox(height: 20),
                      Text(
                        copy.mobileReusableProviderSettings,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        copy.mobileReusableValuesAppliedToProfile,
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
                  child: Text(copy.mobileSaveProvider),
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
    final copy = context.shellText;
    final fieldAccent =
        descriptor?.settingsSchema != null &&
        descriptor?.providerSettingsSupportError == null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: shellSurfaceDecoration(
        context,
        style: ShellSurfaceStyle.highlight,
        tone: ShellSemanticTone.info,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
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
                  label: availability.isAvailable
                      ? copy.available
                      : copy.unavailable,
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
              _metaChip(label: copy.selectedType, accent: true),
              _metaChip(label: fieldLabel, accent: fieldAccent),
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
    final palette = context.shellVisuals.tone(ShellSemanticTone.danger);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: shellSurfaceDecoration(
        context,
        style: ShellSurfaceStyle.highlight,
        tone: ShellSemanticTone.danger,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(color: palette.onContainer),
      ),
    );
  }

  Widget _metaChip({required String label, required bool accent}) {
    return ShellToneBadge(
      label: label,
      tone: accent ? ShellSemanticTone.info : ShellSemanticTone.neutral,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
      return context.shellText.noReusableFieldsYet;
    }
    if (descriptor.providerSettingsSupportError != null) {
      return context.shellText.schemaBlockedInShell;
    }
    if (descriptor.settingsSchema == null) {
      return context.shellText.noReusableFieldsYet;
    }
    return context.shellText.reusableFieldsReady;
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
    final copy = context.shellText;
    final supportedProvider = _selectedSupportedProvider();
    final descriptor = _selectedDescriptor();
    final selectedTemplate = widget.selectedProviderTemplateId != null;
    final canRenderReusableSettings =
        descriptor != null &&
        descriptor.settingsSchema != null &&
        descriptor.providerSettingsSupportError == null;
    final editorTitle = selectedTemplate
        ? copy.mobileEditTemplate
        : copy.mobileNewTemplate;
    final editorDetail = selectedTemplate
        ? copy.mobileEditTemplateStartingValues
        : copy.mobileSaveTemplateStartingPoint;
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
                    tooltip: copy.mobileCloseTemplateEditor,
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
                      copy.mobileNoShippedProviderFamilies,
                    )
                  else ...<Widget>[
                    _field(
                      controller: _nameController,
                      label: copy.mobileTemplateName,
                      onChanged: (String value) => _pushDraft(name: value),
                    ),
                    Text(
                      copy.mobileTemplateShownWhenChoosing,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      copy.providerType,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      copy.mobileTemplateTypeChosenWhenCreated,
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
                            ? copy.mobileNoReusableSettingsYetTemplate(
                                supportedProvider.title,
                              )
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
                        copy.mobileProviderConfigSupportError(
                          providerName: descriptor!.displayName,
                          error: descriptor.providerSettingsSupportError!,
                        ),
                      ),
                    ] else if (canRenderReusableSettings) ...<Widget>[
                      const SizedBox(height: 20),
                      Text(
                        copy.mobileReusableProviderSettings,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        copy.mobileReusableValuesPrefillProvider,
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
                  child: Text(copy.mobileSaveTemplate),
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
    final copy = context.shellText;
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
                  label: availability.isAvailable
                      ? copy.available
                      : copy.unavailable,
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
              _metaChip(theme, label: copy.selectedType, accent: true),
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
      return context.shellText.noReusableFieldsYet;
    }
    if (descriptor.providerSettingsSupportError != null) {
      return context.shellText.schemaBlockedInShell;
    }
    if (descriptor.settingsSchema == null) {
      return context.shellText.noReusableFieldsYet;
    }
    return context.shellText.reusableFieldsReady;
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
