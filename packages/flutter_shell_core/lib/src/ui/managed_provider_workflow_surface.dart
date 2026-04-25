import 'package:flutter/material.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';

import '../control/control_plane_models.dart';
import '../control/profile_draft.dart';
import 'provider_settings_form.dart';
import 'shell_visuals.dart';

enum ManagedProviderWorkflowVariant { mobile, desktop }

class ManagedProviderWorkflowBody extends StatefulWidget {
  const ManagedProviderWorkflowBody({
    super.key,
    required this.variant,
    required this.supportedProviders,
    required this.providerDescriptors,
    required this.selectedManagedProviderId,
    required this.draft,
    required this.busy,
    required this.onDraftChanged,
    this.leadingChildren = const <Widget>[],
    this.bottomChildren = const <Widget>[],
    this.nameFieldKey,
  });

  final ManagedProviderWorkflowVariant variant;
  final List<SupportedProviderDefinition> supportedProviders;
  final List<ProviderDescriptor> providerDescriptors;
  final String? selectedManagedProviderId;
  final ManagedProviderDraft draft;
  final bool busy;
  final ValueChanged<ManagedProviderDraft> onDraftChanged;
  final List<Widget> leadingChildren;
  final List<Widget> bottomChildren;
  final Key? nameFieldKey;

  @override
  State<ManagedProviderWorkflowBody> createState() =>
      _ManagedProviderWorkflowBodyState();
}

class _ManagedProviderWorkflowBodyState
    extends State<ManagedProviderWorkflowBody> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.draft.name);
  }

  @override
  void didUpdateWidget(covariant ManagedProviderWorkflowBody oldWidget) {
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
    final content = switch (widget.variant) {
      ManagedProviderWorkflowVariant.mobile => _buildMobileBody(context),
      ManagedProviderWorkflowVariant.desktop => _buildDesktopBody(context),
    };
    return KeyedSubtree(
      key: const ValueKey<String>('managed-provider-workflow-body'),
      child: content,
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    final theme = Theme.of(context);
    final copy = context.shellText;
    final supportedProvider = _selectedSupportedProvider();
    final descriptor = _selectedDescriptor();
    final canRenderReusableSettings =
        descriptor != null &&
        descriptor.settingsSchema != null &&
        descriptor.providerSettingsSupportError == null;
    final hostAvailability = supportedProvider?.availabilityFor(
      widget.providerDescriptors,
    );
    final children = <Widget>[
      ..._withSpacing(widget.leadingChildren, height: 16),
      if (widget.supportedProviders.isEmpty)
        _unavailableCard(theme, copy.mobileNoShippedProviderFamilies)
      else ...<Widget>[
        _field(
          key: widget.nameFieldKey,
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
          _mobileSelectedFamilyCard(
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
      ..._withSpacing(widget.bottomChildren, height: 16),
    ];

    return ListView(
      key: const ValueKey<String>('managed-provider-workspace-scroll'),
      padding: const EdgeInsets.only(bottom: 8),
      children: children,
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    final theme = Theme.of(context);
    final copy = context.shellText;
    final supportedProvider = _selectedSupportedProvider();
    final descriptor = _selectedDescriptor();
    final unsupportedSelectedFamily =
        widget.draft.provider.trim().isNotEmpty && supportedProvider == null;
    final hostAvailability = supportedProvider?.availabilityFor(
      widget.providerDescriptors,
    );
    final parametersTitle = supportedProvider == null
        ? copy.desktopRecordParameters
        : copy.desktopParametersFor(supportedProvider.title);
    final parametersDetail = supportedProvider == null
        ? copy.desktopChooseProviderFamilyFirst
        : copy.desktopEditReusableParametersFor(supportedProvider.title);
    final primaryChildren = <Widget>[
      ..._withSpacing(widget.leadingChildren, height: 16),
      if (widget.supportedProviders.isEmpty)
        _unavailableCard(theme, copy.desktopNoShippedProviderFamilies)
      else ...<Widget>[
        _desktopPanel(
          theme,
          title: copy.desktopRecordName,
          subtitle: '',
          child: _desktopField(
            key: widget.nameFieldKey,
            controller: _nameController,
            label: copy.desktopRecordName,
            onChanged: (String value) => _pushDraft(name: value),
          ),
        ),
        _desktopPanel(
          theme,
          title: parametersTitle,
          subtitle: parametersDetail,
          child: _desktopParametersContent(
            theme,
            supportedProvider: supportedProvider,
            descriptor: descriptor,
          ),
        ),
      ],
      ..._withSpacing(widget.bottomChildren, height: 16),
    ];
    final sidebarChildren = <Widget>[
      if (widget.supportedProviders.isNotEmpty) ...<Widget>[
        _desktopGroupHeader(
          theme,
          title: copy.desktopAttachedFamily,
          subtitle: copy.desktopAttachedFamilyHelp,
        ),
        _desktopFamilyEntryCard(
          theme,
          provider: supportedProvider,
          availability: hostAvailability,
        ),
        if (unsupportedSelectedFamily)
          _unavailableCard(
            theme,
            copy.selectedManagedProviderFamilyNotInSupportedCatalog,
          ),
        if (supportedProvider != null)
          _desktopSelectedFamilyCard(
            theme,
            provider: supportedProvider,
            availability: hostAvailability,
            descriptor: descriptor,
          ),
        if (hostAvailability != null && !hostAvailability.isAvailable)
          _unavailableCard(theme, hostAvailability.message),
        if (descriptor != null) ...<Widget>[
          _desktopGroupHeader(
            theme,
            title: copy.desktopFamilyCharacteristics,
            subtitle: copy.desktopFamilyCharacteristicsHelp,
          ),
          _descriptorSummary(theme, descriptor),
        ],
      ],
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final twoPaneLayout = constraints.maxWidth >= 980;
        final content = twoPaneLayout
            ? Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1160),
                  child: Row(
                    key: const ValueKey<String>(
                      'managed-provider-desktop-two-pane-layout',
                    ),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _withSpacing(primaryChildren, height: 12),
                        ),
                      ),
                      const SizedBox(width: 20),
                      SizedBox(
                        width: 280,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _withSpacing(sidebarChildren, height: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                key: const ValueKey<String>(
                  'managed-provider-desktop-stacked-layout',
                ),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _withSpacing(<Widget>[
                  ...primaryChildren,
                  ...sidebarChildren,
                ], height: 12),
              );

        return ListView(
          key: const ValueKey<String>('managed-provider-workspace-scroll'),
          primary: true,
          children: <Widget>[content],
        );
      },
    );
  }

  Widget _desktopParametersContent(
    ThemeData theme, {
    required SupportedProviderDefinition? supportedProvider,
    required ProviderDescriptor? descriptor,
  }) {
    final copy = context.shellText;
    if (descriptor?.providerSettingsSupportError != null &&
        widget.draft.providerSettings.isNotEmpty) {
      return _inlineMessage(
        theme,
        copy.desktopProviderRecordSupportError(
          providerName: descriptor!.displayName,
          error: descriptor.providerSettingsSupportError!,
        ),
        tone: ShellSemanticTone.danger,
      );
    }
    if (descriptor?.settingsSchema == null) {
      return _inlineMessage(
        theme,
        supportedProvider == null
            ? copy.desktopChooseProviderFamilyFirst
            : copy.desktopNoEditableRecordParameters(supportedProvider.title),
      );
    }
    return ProviderSettingsForm(
      descriptor: descriptor!,
      values: widget.draft.providerSettings,
      enabled: !widget.busy,
      onChanged: (Map<String, dynamic> values) {
        _pushDraft(providerSettings: values);
      },
    );
  }

  Widget _desktopPanel(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: shellSurfaceDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _desktopGroupHeader(
    ThemeData theme, {
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _field({
    Key? key,
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: key,
        controller: controller,
        enabled: !widget.busy,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      ),
    );
  }

  Widget _desktopField({
    Key? key,
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            key: key,
            controller: controller,
            enabled: !widget.busy,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _desktopFamilyEntryCard(
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
      decoration: shellSurfaceDecoration(
        context,
        style: ShellSurfaceStyle.highlight,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
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
                _metaChip(label: copy.desktopShippedByApp, accent: true),
                if (availability != null)
                  _metaChip(
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

  Widget _desktopSelectedFamilyCard(
    ThemeData theme, {
    required SupportedProviderDefinition provider,
    required SupportedProviderAvailability? availability,
    required ProviderDescriptor? descriptor,
  }) {
    final copy = context.shellText;
    final fieldLabel = _managedFieldSurfaceLabel(descriptor);
    final fieldAccent =
        descriptor?.settingsSchema != null &&
        descriptor?.providerSettingsSupportError == null;
    return Container(
      key: const ValueKey<String>('managed-provider-selected-family-card'),
      padding: const EdgeInsets.all(14),
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
              _metaChip(label: copy.selectedFamily, accent: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(provider.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _metaChip(label: copy.desktopReadOnlyFamily, accent: true),
              if (availability != null)
                _metaChip(
                  label: availability.isAvailable
                      ? copy.desktopHostOverlayAvailable
                      : copy.desktopHostOverlayUnavailable,
                  accent: availability.isAvailable,
                ),
              _metaChip(label: fieldLabel, accent: fieldAccent),
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

  Widget _mobileSelectedFamilyCard(
    ThemeData theme, {
    required SupportedProviderDefinition provider,
    required SupportedProviderAvailability? availability,
    required ProviderDescriptor? descriptor,
    String? compactNote,
  }) {
    final copy = context.shellText;
    final fieldLabel = _managedFieldSurfaceLabel(descriptor);
    final fieldAccent =
        descriptor?.settingsSchema != null &&
        descriptor?.providerSettingsSupportError == null;
    return Container(
      key: const ValueKey<String>('managed-provider-selected-family-card'),
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

  Widget _descriptorSummary(ThemeData theme, ProviderDescriptor descriptor) {
    return Container(
      key: const ValueKey<String>('managed-provider-descriptor-summary'),
      padding: const EdgeInsets.all(14),
      decoration: shellSurfaceDecoration(
        context,
        style: ShellSurfaceStyle.highlight,
        tone: ShellSemanticTone.info,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
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

  Widget _inlineMessage(
    ThemeData theme,
    String message, {
    ShellSemanticTone tone = ShellSemanticTone.neutral,
  }) {
    final palette = context.shellVisuals.tone(tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: shellSurfaceDecoration(
        context,
        style: ShellSurfaceStyle.highlight,
        tone: tone,
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
    return switch (widget.variant) {
      ManagedProviderWorkflowVariant.mobile =>
        widget.supportedProviders.isEmpty
            ? null
            : widget.supportedProviders.first,
      ManagedProviderWorkflowVariant.desktop => null,
    };
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
      return switch (widget.variant) {
        ManagedProviderWorkflowVariant.mobile =>
          context.shellText.noReusableFieldsYet,
        ManagedProviderWorkflowVariant.desktop =>
          context.shellText.desktopNoEditableParametersYet,
      };
    }
    if (descriptor.providerSettingsSupportError != null) {
      return context.shellText.schemaBlockedInShell;
    }
    if (descriptor.settingsSchema == null) {
      return switch (widget.variant) {
        ManagedProviderWorkflowVariant.mobile =>
          context.shellText.noReusableFieldsYet,
        ManagedProviderWorkflowVariant.desktop =>
          context.shellText.desktopNoEditableParameters,
      };
    }
    return switch (widget.variant) {
      ManagedProviderWorkflowVariant.mobile =>
        context.shellText.reusableFieldsReady,
      ManagedProviderWorkflowVariant.desktop =>
        context.shellText.desktopEditableParametersReady,
    };
  }

  void _pushDraft({String? name, Map<String, dynamic>? providerSettings}) {
    widget.onDraftChanged(
      widget.draft.copyWith(
        name: name ?? widget.draft.name,
        providerSettings: providerSettings ?? widget.draft.providerSettings,
      ),
    );
  }
}

List<Widget> _withSpacing(List<Widget> children, {required double height}) {
  if (children.isEmpty) {
    return const <Widget>[];
  }
  final spaced = <Widget>[];
  for (var index = 0; index < children.length; index += 1) {
    if (index > 0) {
      spaced.add(SizedBox(height: height));
    }
    spaced.add(children[index]);
  }
  return spaced;
}
