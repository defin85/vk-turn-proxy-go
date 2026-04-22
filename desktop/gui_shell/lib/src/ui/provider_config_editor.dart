import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
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
    final editorTitle = selectedSavedProvider
        ? copy.desktopProviderRecord
        : copy.desktopNewProviderRecord;
    final editorDetail = selectedSavedProvider
        ? copy.desktopEditReusableProviderRecord
        : copy.desktopCreateReusableProviderRecord;
    final parametersTitle = supportedProvider == null
        ? copy.desktopRecordParameters
        : copy.desktopParametersFor(supportedProvider.title);
    final parametersDetail = supportedProvider == null
        ? copy.desktopChooseProviderFamilyFirst
        : copy.desktopEditReusableParametersFor(supportedProvider.title);
    final blockedBySchemaSupport =
        descriptor?.providerSettingsSupportError != null &&
        widget.draft.providerSettings.isNotEmpty;
    final unsupportedSelectedFamily =
        widget.draft.provider.trim().isNotEmpty && supportedProvider == null;
    final hostAvailability = supportedProvider?.availabilityFor(
      widget.providerDescriptors,
    );

    return Card(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final stackHeader = constraints.maxWidth < 1080;
          final headerActions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton(
                key: const ValueKey<String>('managed-provider-save-action'),
                onPressed: widget.busy || blockedBySchemaSupport
                    ? null
                    : () => unawaited(widget.onSave()),
                child: Text(_nextStepTitle(supportedProvider)),
              ),
              FilledButton.tonal(
                key: const ValueKey<String>('managed-provider-apply-action'),
                onPressed:
                    widget.busy || widget.selectedManagedProviderId == null
                    ? null
                    : () => widget.onApplyToProfileDraft(
                        widget.selectedManagedProviderId!,
                      ),
                child: Text(copy.desktopUseInProfileDraft),
              ),
              OutlinedButton(
                key: const ValueKey<String>('managed-provider-delete-action'),
                onPressed:
                    widget.busy || widget.selectedManagedProviderId == null
                    ? null
                    : () => unawaited(widget.onDelete()),
                child: Text(copy.delete),
              ),
              FilledButton.tonalIcon(
                onPressed: widget.busy ? null : widget.onReset,
                icon: const Icon(Icons.tune),
                label: Text(copy.desktopNewRecord),
              ),
            ],
          );
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
                  child: ListView(
                    key: const ValueKey<String>(
                      'managed-provider-workspace-scroll',
                    ),
                    primary: true,
                    children: <Widget>[
                      if (widget.supportedProviders.isEmpty)
                        _unavailableCard(
                          theme,
                          copy.desktopNoShippedProviderFamilies,
                        )
                      else ...<Widget>[
                        Text(
                          copy.desktopRecordName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          copy.desktopRecordNameHelp,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _nameController,
                          label: copy.desktopRecordName,
                          onChanged: (String value) => _pushDraft(name: value),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          copy.desktopAttachedFamily,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          copy.desktopAttachedFamilyHelp,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _familyEntryCard(
                          theme,
                          provider: supportedProvider,
                          availability: hostAvailability,
                        ),
                        if (unsupportedSelectedFamily) ...<Widget>[
                          const SizedBox(height: 12),
                          _unavailableCard(
                            theme,
                            copy.selectedManagedProviderFamilyNotInSupportedCatalog,
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (supportedProvider != null)
                          _selectedFamilyCard(
                            theme,
                            provider: supportedProvider,
                            availability: hostAvailability,
                            descriptor: descriptor,
                          ),
                        const SizedBox(height: 16),
                        if (descriptor != null) ...<Widget>[
                          Text(
                            copy.desktopFamilyCharacteristics,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            copy.desktopFamilyCharacteristicsHelp,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _descriptorSummary(theme, descriptor),
                          const SizedBox(height: 16),
                        ],
                        if (hostAvailability != null &&
                            !hostAvailability.isAvailable) ...<Widget>[
                          _unavailableCard(theme, hostAvailability.message),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          parametersTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          parametersDetail,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (descriptor?.providerSettingsSupportError != null &&
                            widget.draft.providerSettings.isNotEmpty)
                          _unavailableCard(
                            theme,
                            copy.desktopProviderRecordSupportError(
                              providerName: descriptor!.displayName,
                              error: descriptor.providerSettingsSupportError!,
                            ),
                          )
                        else if (descriptor?.settingsSchema == null)
                          _infoCard(
                            theme,
                            supportedProvider == null
                                ? copy.desktopChooseProviderFamilyFirst
                                : copy.desktopNoEditableRecordParameters(
                                    supportedProvider.title,
                                  ),
                          )
                        else if (descriptor != null) ...<Widget>[
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
              ],
            ),
          );
        },
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

  Widget _familyEntryCard(
    ThemeData theme, {
    required SupportedProviderDefinition? provider,
    required SupportedProviderAvailability? availability,
  }) {
    final copy = context.shellText;
    final title = provider == null
        ? copy.desktopNoFamilyAttachedYet
        : copy.desktopSelectedFamily;
    final detail = provider == null
        ? copy.desktopOpenFamilyChooserFirst
        : copy.desktopFamilyAttachedToRecord(provider.title);

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
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (provider != null) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _metaChip(theme, label: copy.desktopShippedByApp, accent: true),
                if (availability != null)
                  _metaChip(
                    theme,
                    label: availability.isAvailable
                        ? copy.desktopHostOverlayAvailable
                        : copy.desktopHostOverlayUnavailable,
                    accent: availability.isAvailable,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            provider == null
                ? copy.desktopUseActionStripToChooseFamily
                : copy.desktopFamiliesReadonlyEditBelow,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _nextStepTitle(SupportedProviderDefinition? provider) {
    if (provider == null) {
      return context.shellText.desktopChooseFamily;
    }
    if (widget.draft.name.trim().isEmpty) {
      return context.shellText.desktopSaveDraft;
    }
    return context.shellText.desktopSaveRecord;
  }

  Widget _selectedFamilyCard(
    ThemeData theme, {
    required SupportedProviderDefinition provider,
    required SupportedProviderAvailability? availability,
    required ProviderDescriptor? descriptor,
  }) {
    final fieldLabel = _managedFieldSurfaceLabel(descriptor);
    final copy = context.shellText;
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
              _metaChip(theme, label: copy.selectedFamily, accent: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(provider.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _metaChip(theme, label: copy.desktopReadOnlyFamily, accent: true),
              if (availability != null)
                _metaChip(
                  theme,
                  label: availability.isAvailable
                      ? copy.desktopHostOverlayAvailable
                      : copy.desktopHostOverlayUnavailable,
                  accent: availability.isAvailable,
                ),
              _metaChip(theme, label: fieldLabel, accent: fieldAccent),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            copy.desktopAttachedFamilyCardHelp,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
    if (providerId.isEmpty) {
      return widget.supportedProviders.isEmpty
          ? null
          : widget.supportedProviders.first;
    }
    for (final provider in widget.supportedProviders) {
      if (provider.id.trim().toLowerCase() == providerId) {
        return provider;
      }
    }
    return null;
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
      return context.shellText.desktopNoEditableParametersYet;
    }
    if (descriptor.providerSettingsSupportError != null) {
      return context.shellText.schemaBlockedInShell;
    }
    if (descriptor.settingsSchema == null) {
      return context.shellText.desktopNoEditableParameters;
    }
    return context.shellText.desktopEditableParametersReady;
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
