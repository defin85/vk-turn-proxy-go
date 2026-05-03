import 'package:flutter/material.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';

import '../control/control_plane_models.dart';
import '../control/profile_draft.dart';
import 'provider_settings_form.dart';
import 'shell_visuals.dart';

enum ProfileWorkflowVariant { mobile, desktop }

class ProfileWorkflowBody extends StatefulWidget {
  const ProfileWorkflowBody({
    super.key,
    required this.variant,
    required this.providerDescriptors,
    required this.managedProviders,
    required this.draft,
    required this.busy,
    required this.onDraftChanged,
    required this.onActivateManagedProviderMode,
    required this.onUseCustomProvider,
    this.selectedManagedProviderId,
    this.selectedProfileId,
    this.leadingChildren = const <Widget>[],
    this.trailingChildren = const <Widget>[],
    this.bottomChildren = const <Widget>[],
    this.nameFieldKey,
    this.providerFieldKey,
  });

  final ProfileWorkflowVariant variant;
  final List<ProviderDescriptor> providerDescriptors;
  final List<ManagedProviderRecord> managedProviders;
  final String? selectedManagedProviderId;
  final String? selectedProfileId;
  final ProfileDraft draft;
  final bool busy;
  final ValueChanged<ProfileDraft> onDraftChanged;
  final void Function({String? managedProviderId})
  onActivateManagedProviderMode;
  final VoidCallback onUseCustomProvider;
  final List<Widget> leadingChildren;
  final List<Widget> trailingChildren;
  final List<Widget> bottomChildren;
  final Key? nameFieldKey;
  final Key? providerFieldKey;

  @override
  State<ProfileWorkflowBody> createState() => _ProfileWorkflowBodyState();
}

class _ProfileWorkflowBodyState extends State<ProfileWorkflowBody> {
  late final TextEditingController _nameController;
  late final TextEditingController _providerController;
  late final TextEditingController _linkController;
  late final TextEditingController _listenController;
  late final TextEditingController _peerController;
  late final TextEditingController _connectionsController;
  late final TextEditingController _turnServerController;
  late final TextEditingController _turnPortController;
  late final TextEditingController _bindInterfaceController;
  late final TextEditingController _logLevelController;
  String? _selectedManagedProviderId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _providerController = TextEditingController();
    _linkController = TextEditingController();
    _listenController = TextEditingController();
    _peerController = TextEditingController();
    _connectionsController = TextEditingController();
    _turnServerController = TextEditingController();
    _turnPortController = TextEditingController();
    _bindInterfaceController = TextEditingController();
    _logLevelController = TextEditingController();
    _syncFromDraft();
  }

  @override
  void didUpdateWidget(covariant ProfileWorkflowBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft != widget.draft ||
        oldWidget.selectedManagedProviderId !=
            widget.selectedManagedProviderId ||
        oldWidget.managedProviders != widget.managedProviders) {
      _syncFromDraft();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _providerController.dispose();
    _linkController.dispose();
    _listenController.dispose();
    _peerController.dispose();
    _connectionsController.dispose();
    _turnServerController.dispose();
    _turnPortController.dispose();
    _bindInterfaceController.dispose();
    _logLevelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.variant) {
      ProfileWorkflowVariant.mobile => _buildMobileBody(context),
      ProfileWorkflowVariant.desktop => _buildDesktopBody(context),
    };
  }

  Widget _buildMobileBody(BuildContext context) {
    final theme = Theme.of(context);
    final copy = context.shellText;
    final descriptor = _selectedDescriptor();
    final managedMode = widget.draft.providerBinding.isManaged;
    final children = <Widget>[
      ..._withSpacing(widget.leadingChildren, height: 16),
      _field(
        key: widget.nameFieldKey,
        controller: _nameController,
        label: copy.profileName,
        onChanged: (String value) => _pushDraft(name: value),
      ),
      _mobileProviderModeCard(theme, managedMode),
      _mobileProviderField(),
      _field(
        key: widget.providerFieldKey,
        controller: _linkController,
        label: _providerLinkLabel(context, descriptor),
        maxLines: 3,
        onChanged: (String value) =>
            _pushDraft(spec: widget.draft.spec.copyWith(link: value.trim())),
      ),
    ];

    if (descriptor != null) {
      children.addAll(<Widget>[
        _mobileDisclosureSection(
          title: copy.mobileProviderDetails,
          subtitle: copy.mobileProviderDetailsSubtitle,
          initiallyExpanded: false,
          children: <Widget>[
            _providerDescriptorCard(theme, descriptor),
            const SizedBox(height: 12),
            _mobileProviderFlowCard(theme, descriptor),
          ],
        ),
        const SizedBox(height: 12),
      ]);
    }

    if (descriptor?.settingsSchema != null) {
      children.addAll(<Widget>[
        _mobileDisclosureSection(
          title: copy.mobileProviderSettingsSection,
          subtitle: descriptor!.providerSettingsSupportError != null
              ? copy.mobileProviderSettingsUnsupportedSubtitle
              : copy.mobileProviderSettingsRetainedSubtitle,
          initiallyExpanded: descriptor.providerSettingsSupportError != null,
          children: _mobileProviderSettingsChildren(theme, descriptor),
        ),
        const SizedBox(height: 12),
      ]);
    }

    children.add(
      _mobileDisclosureSection(
        title: copy.mobileAdvancedRuntimeControls,
        subtitle: copy.mobileAdvancedRuntimeControlsSubtitle,
        initiallyExpanded: false,
        children: _runtimeDefaultsFields(context),
      ),
    );
    children.addAll(_withSpacing(widget.bottomChildren, height: 16));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    final theme = Theme.of(context);
    final descriptor = _selectedDescriptor();
    final managedMode = widget.draft.providerBinding.isManaged;
    final selectedManagedProviderId = _resolvedManagedProviderId();
    final selectedManagedProvider = _managedProviderForId(
      selectedManagedProviderId,
    );
    final selectedManagedDescriptor = _descriptorForProviderId(
      selectedManagedProvider?.provider ?? widget.draft.spec.provider,
    );

    final settingsCard = _desktopProviderSettingsCard(theme, descriptor);
    final settingsChildren = settingsCard == null
        ? const <Widget>[]
        : <Widget>[settingsCard];
    final primaryChildren = <Widget>[
      _desktopField(
        key: widget.nameFieldKey,
        controller: _nameController,
        label: context.shellText.profileName,
        onChanged: (String value) => _pushDraft(name: value),
      ),
      _desktopPrimarySectionCard(
        theme,
        title: context.shellText.desktopProfileSettings,
        child: _desktopMainSettingsSection(
          context,
          theme,
          descriptor,
          managedMode: managedMode,
          selectedManagedProvider: selectedManagedProvider,
          selectedManagedDescriptor: selectedManagedDescriptor,
          sideBySide: true,
        ),
      ),
      ...settingsChildren,
    ];
    final sidebarChildren = <Widget>[
      _desktopSecondarySectionCard(
        theme,
        title: context.shellText.desktopChangeSource,
        child: _desktopProviderModeCard(
          theme,
          managedMode,
          selectedManagedProviderId: selectedManagedProviderId,
        ),
      ),
      if (_showsDesktopBrowserHandling(descriptor))
        _desktopSecondarySectionCard(
          theme,
          title: context.shellText.desktopBrowserHandling,
          child: Text(
            _desktopProviderFlowSummary(context, descriptor),
            style: theme.textTheme.bodySmall,
          ),
        ),
      if (!managedMode && descriptor != null)
        _providerDescriptorCard(theme, descriptor),
      ...widget.trailingChildren,
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final twoPaneLayout = constraints.maxWidth >= 1020;
        if (twoPaneLayout) {
          return Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1220),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _withSpacing(primaryChildren, height: 10),
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
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _withSpacing(<Widget>[
            ...primaryChildren,
            ...sidebarChildren,
          ], height: 12),
        );
      },
    );
  }

  List<Widget> _mobileProviderSettingsChildren(
    ThemeData theme,
    ProviderDescriptor descriptor,
  ) {
    final supportError = descriptor.providerSettingsSupportError;
    if (supportError != null) {
      return <Widget>[
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: shellSurfaceDecoration(
            context,
            style: ShellSurfaceStyle.highlight,
            tone: ShellSemanticTone.danger,
            borderRadius: const BorderRadius.all(Radius.circular(14)),
          ),
          child: Text(
            context.shellText.mobileProviderSettingsSupportError(
              providerName: descriptor.displayName,
              error: supportError,
            ),
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ];
    }
    return <Widget>[
      Text(
        context.shellText.mobileProviderSettingsRetainedHelp,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 8),
      ProviderSettingsForm(
        descriptor: descriptor,
        values: widget.draft.spec.providerSettings,
        enabled: !widget.busy,
        onChanged: _updateProviderSettings,
      ),
    ];
  }

  Widget? _desktopProviderSettingsCard(
    ThemeData theme,
    ProviderDescriptor? descriptor,
  ) {
    final schema = descriptor?.settingsSchema;
    if (schema == null) {
      return null;
    }

    final supportError = descriptor?.providerSettingsSupportError;
    if (supportError != null) {
      return _desktopPrimarySectionCard(
        theme,
        title: context.shellText.desktopProfileProviderSettings,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: shellSurfaceDecoration(
            context,
            style: ShellSurfaceStyle.highlight,
            tone: ShellSemanticTone.danger,
            borderRadius: const BorderRadius.all(Radius.circular(14)),
          ),
          child: Text(
            context.shellText.desktopProviderSettingsSupportError(
              providerName: descriptor!.displayName,
              error: supportError,
            ),
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return _desktopPrimarySectionCard(
      theme,
      title: context.shellText.desktopProfileProviderSettings,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.shellText.desktopProfileProviderSettingsHelp,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ProviderSettingsForm(
            descriptor: descriptor!,
            values: widget.draft.spec.providerSettings,
            enabled: !widget.busy,
            onChanged: _updateProviderSettings,
          ),
        ],
      ),
    );
  }

  Widget _desktopMainSettingsSection(
    BuildContext context,
    ThemeData theme,
    ProviderDescriptor? descriptor, {
    required bool managedMode,
    required ManagedProviderRecord? selectedManagedProvider,
    required ProviderDescriptor? selectedManagedDescriptor,
    required bool sideBySide,
  }) {
    final providerFields = <Widget>[];
    if (managedMode && selectedManagedProvider != null) {
      final recordName = selectedManagedProvider.name.isEmpty
          ? selectedManagedProvider.id
          : selectedManagedProvider.name;
      providerFields.add(
        _desktopMetadataField(
          key: const ValueKey<String>('profile-provider-record-field'),
          label: context.shellText.desktopProviderRecord,
          value: recordName,
        ),
      );
    }
    providerFields.add(
      _desktopProviderFamilyField(
        descriptor: selectedManagedDescriptor ?? descriptor,
        managedMode: managedMode,
      ),
    );

    final providerSummary = sideBySide && providerFields.length == 2
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: providerFields[0]),
              const SizedBox(width: 12),
              Expanded(child: providerFields[1]),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: providerFields,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        providerSummary,
        _desktopField(
          key: widget.providerFieldKey,
          controller: _linkController,
          label: _providerLinkLabel(context, descriptor),
          maxLines: 3,
          onChanged: (String value) =>
              _pushDraft(spec: widget.draft.spec.copyWith(link: value.trim())),
        ),
        const Divider(height: 16),
        Text(
          context.shellText.desktopRuntimeDefaults,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.shellText.desktopRuntimeDefaultsSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ..._runtimeDefaultsFields(context, desktop: true),
      ],
    );
  }

  Widget _desktopPrimarySectionCard(
    ThemeData theme, {
    required String title,
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _desktopSecondarySectionCard(
    ThemeData theme, {
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: shellSurfaceDecoration(
        context,
        style: ShellSurfaceStyle.highlight,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null && subtitle.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _mobileProviderModeCard(ThemeData theme, bool managedMode) {
    if (widget.managedProviders.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
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
              context.shellText.mobileProviderMode,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.shellText.mobileProviderModeNoManagedProviders,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            ChoiceChip(
              selected: true,
              label: Text(context.shellText.customProvider),
              onSelected: widget.busy
                  ? null
                  : (_) => widget.onUseCustomProvider(),
            ),
          ],
        ),
      );
    }

    final selectedManagedProviderId =
        _resolvedManagedProviderId() ?? widget.managedProviders.first.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            context.shellText.mobileProviderMode,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            managedMode
                ? context.shellText.mobileManagedModeSummary
                : context.shellText.mobileCustomModeSummary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              ChoiceChip(
                selected: managedMode,
                label: Text(context.shellText.managedProvider),
                onSelected: widget.busy
                    ? null
                    : (_) => widget.onActivateManagedProviderMode(
                        managedProviderId: selectedManagedProviderId,
                      ),
              ),
              ChoiceChip(
                selected: !managedMode,
                label: Text(context.shellText.customProvider),
                onSelected: widget.busy
                    ? null
                    : (_) => widget.onUseCustomProvider(),
              ),
            ],
          ),
          if (managedMode) ...<Widget>[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: selectedManagedProviderId,
              decoration: InputDecoration(
                labelText: context.shellText.mobileManagedProviderDropdown,
              ),
              items: widget.managedProviders
                  .map(
                    (ManagedProviderRecord provider) =>
                        DropdownMenuItem<String>(
                          value: provider.id,
                          child: Text(
                            provider.name.isEmpty ? provider.id : provider.name,
                          ),
                        ),
                  )
                  .toList(growable: false),
              onChanged: widget.busy
                  ? null
                  : (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _selectedManagedProviderId = value;
                      });
                      widget.onActivateManagedProviderMode(
                        managedProviderId: value,
                      );
                    },
            ),
          ],
        ],
      ),
    );
  }

  Widget _desktopProviderModeCard(
    ThemeData theme,
    bool managedMode, {
    String? selectedManagedProviderId,
  }) {
    if (widget.managedProviders.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.shellText.desktopNoSavedProviderRecords,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          ChoiceChip(
            selected: true,
            label: Text(context.shellText.directInput),
            onSelected: widget.busy
                ? null
                : (_) => widget.onUseCustomProvider(),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          managedMode
              ? context.shellText.desktopSavedRecordAttached
              : context.shellText.desktopDraftOwnsProviderInput,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            ChoiceChip(
              selected: managedMode,
              label: Text(context.shellText.savedRecord),
              onSelected: widget.busy
                  ? null
                  : (_) => widget.onActivateManagedProviderMode(
                      managedProviderId: selectedManagedProviderId,
                    ),
            ),
            ChoiceChip(
              selected: !managedMode,
              label: Text(context.shellText.directInput),
              onSelected: widget.busy
                  ? null
                  : (_) => widget.onUseCustomProvider(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _mobileProviderField() {
    if (widget.draft.providerBinding.isManaged) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _providerController,
          enabled: false,
          decoration: InputDecoration(
            labelText: context.shellText.providerFamily,
          ),
        ),
      );
    }
    return _field(
      key: widget.providerFieldKey,
      controller: _providerController,
      label: t.commonProviders,
      onChanged: (String value) =>
          _pushDraft(spec: widget.draft.spec.copyWith(provider: value.trim())),
    );
  }

  Widget _desktopProviderFamilyField({
    required ProviderDescriptor? descriptor,
    required bool managedMode,
  }) {
    if (managedMode) {
      final familyValue = _providerFamilyValue(descriptor);
      final displayName = descriptor?.displayName.trim() ?? '';
      return _desktopMetadataField(
        key: const ValueKey<String>('profile-managed-provider-family'),
        label: context.shellText.providerFamily,
        value: displayName.isNotEmpty ? displayName : familyValue,
        detail: displayName.isNotEmpty && displayName != familyValue
            ? familyValue
            : null,
      );
    }
    return _desktopField(
      key: widget.providerFieldKey,
      controller: _providerController,
      label: context.shellText.providerFamily,
      onChanged: (String value) =>
          _pushDraft(spec: widget.draft.spec.copyWith(provider: value.trim())),
    );
  }

  Widget _providerDescriptorCard(
    ThemeData theme,
    ProviderDescriptor descriptor,
  ) {
    final copy = context.shellText;
    return Container(
      key: const ValueKey<String>('profile-provider-descriptor-card'),
      padding: const EdgeInsets.all(16),
      decoration: shellSurfaceDecoration(
        context,
        style: ShellSurfaceStyle.highlight,
        tone: ShellSemanticTone.info,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            descriptor.displayName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            descriptor.description.isEmpty
                ? '${descriptor.authPosture.label}. ${descriptor.browserPolicy.label}.'
                : descriptor.description,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ShellToneBadge(label: copy.tagInput(descriptor.inputKind.value)),
              ShellToneBadge(label: copy.tagAuth(descriptor.authPosture.label)),
              ShellToneBadge(
                label: copy.tagBrowser(descriptor.browserPolicy.label),
              ),
              for (final family in descriptor.artifactFamilies)
                ShellToneBadge(label: copy.tagFamily(family.label)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mobileProviderFlowCard(
    ThemeData theme,
    ProviderDescriptor? descriptor,
  ) {
    final palette = context.shellVisuals.tone(ShellSemanticTone.attention);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: shellSurfaceDecoration(
        context,
        style: ShellSurfaceStyle.highlight,
        tone: ShellSemanticTone.attention,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _providerFlowMessage(context, descriptor),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.onContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _providerFlowContinuation(context, descriptor),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.onContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileDisclosureSection({
    required String title,
    required String subtitle,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          children: children,
        ),
      ),
    );
  }

  List<Widget> _runtimeDefaultsFields(
    BuildContext context, {
    bool desktop = false,
  }) {
    return <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: desktop
                ? _desktopField(
                    controller: _listenController,
                    label: context.shellText.localUdpListen,
                    onChanged: (String value) => _pushDraft(
                      spec: widget.draft.spec.copyWith(
                        listenAddress: value.trim(),
                      ),
                    ),
                  )
                : _field(
                    controller: _listenController,
                    label: context.shellText.localUdpListen,
                    onChanged: (String value) => _pushDraft(
                      spec: widget.draft.spec.copyWith(
                        listenAddress: value.trim(),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: desktop
                ? _desktopField(
                    controller: _peerController,
                    label: context.shellText.peerAddress,
                    onChanged: (String value) => _pushDraft(
                      spec: widget.draft.spec.copyWith(
                        peerAddress: value.trim(),
                      ),
                    ),
                  )
                : _field(
                    controller: _peerController,
                    label: context.shellText.peerAddress,
                    onChanged: (String value) => _pushDraft(
                      spec: widget.draft.spec.copyWith(
                        peerAddress: value.trim(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      Row(
        children: <Widget>[
          Expanded(
            child: desktop
                ? _desktopField(
                    controller: _connectionsController,
                    label: context.shellText.connections,
                    keyboardType: TextInputType.number,
                    onChanged: _updateConnections,
                  )
                : _field(
                    controller: _connectionsController,
                    label: context.shellText.connections,
                    keyboardType: TextInputType.number,
                    onChanged: _updateConnections,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: desktop
                ? _desktopDropdownField<TransportMode>(
                    label: context.shellText.turnMode,
                    initialValue: widget.draft.spec.mode,
                    items: TransportMode.values
                        .map(
                          (TransportMode mode) =>
                              DropdownMenuItem<TransportMode>(
                                value: mode,
                                child: Text(mode.value),
                              ),
                        )
                        .toList(growable: false),
                    onChanged: widget.busy
                        ? null
                        : (TransportMode? mode) {
                            if (mode == null) {
                              return;
                            }
                            _pushDraft(
                              spec: widget.draft.spec.copyWith(mode: mode),
                            );
                          },
                  )
                : DropdownButtonFormField<TransportMode>(
                    initialValue: widget.draft.spec.mode,
                    decoration: InputDecoration(
                      labelText: context.shellText.turnMode,
                    ),
                    items: TransportMode.values
                        .map(
                          (TransportMode mode) =>
                              DropdownMenuItem<TransportMode>(
                                value: mode,
                                child: Text(mode.value),
                              ),
                        )
                        .toList(growable: false),
                    onChanged: widget.busy
                        ? null
                        : (TransportMode? mode) {
                            if (mode == null) {
                              return;
                            }
                            _pushDraft(
                              spec: widget.draft.spec.copyWith(mode: mode),
                            );
                          },
                  ),
          ),
        ],
      ),
      Row(
        children: <Widget>[
          Expanded(
            child: desktop
                ? _desktopField(
                    controller: _turnServerController,
                    label: context.shellText.turnOverride,
                    onChanged: (String value) => _pushDraft(
                      spec: widget.draft.spec.copyWith(
                        turnServer: value.trim(),
                      ),
                    ),
                  )
                : _field(
                    controller: _turnServerController,
                    label: context.shellText.turnOverride,
                    onChanged: (String value) => _pushDraft(
                      spec: widget.draft.spec.copyWith(
                        turnServer: value.trim(),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: desktop
                ? _desktopField(
                    controller: _turnPortController,
                    label: context.shellText.turnPort,
                    onChanged: (String value) => _pushDraft(
                      spec: widget.draft.spec.copyWith(turnPort: value.trim()),
                    ),
                  )
                : _field(
                    controller: _turnPortController,
                    label: context.shellText.turnPort,
                    onChanged: (String value) => _pushDraft(
                      spec: widget.draft.spec.copyWith(turnPort: value.trim()),
                    ),
                  ),
          ),
        ],
      ),
      desktop
          ? _desktopField(
              controller: _bindInterfaceController,
              label: context.shellText.bindInterface,
              onChanged: (String value) => _pushDraft(
                spec: widget.draft.spec.copyWith(bindInterface: value.trim()),
              ),
            )
          : _field(
              controller: _bindInterfaceController,
              label: context.shellText.bindInterface,
              onChanged: (String value) => _pushDraft(
                spec: widget.draft.spec.copyWith(bindInterface: value.trim()),
              ),
            ),
      desktop
          ? _desktopField(
              controller: _logLevelController,
              label: context.shellText.logLevel,
              onChanged: (String value) => _pushDraft(
                spec: widget.draft.spec.copyWith(logLevel: value.trim()),
              ),
            )
          : _field(
              controller: _logLevelController,
              label: context.shellText.logLevel,
              onChanged: (String value) => _pushDraft(
                spec: widget.draft.spec.copyWith(logLevel: value.trim()),
              ),
            ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: widget.draft.spec.useDtls,
        onChanged: widget.busy
            ? null
            : (bool enabled) => _pushDraft(
                spec: widget.draft.spec.copyWith(useDtls: enabled),
              ),
        title: Text(context.shellText.dtlsEnabled),
      ),
    ];
  }

  Widget _desktopField({
    Key? key,
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _desktopFieldCaption(label),
          const SizedBox(height: 6),
          TextField(
            key: key,
            controller: controller,
            maxLines: maxLines,
            obscureText: obscureText,
            keyboardType: keyboardType,
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

  Widget _desktopDropdownField<T>({
    required String label,
    required T? initialValue,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _desktopFieldCaption(label),
          const SizedBox(height: 6),
          DropdownButtonFormField<T>(
            initialValue: initialValue,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            items: items,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _desktopFieldCaption(String label) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _field({
    Key? key,
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: key,
        controller: controller,
        maxLines: maxLines,
        obscureText: obscureText,
        keyboardType: keyboardType,
        enabled: !widget.busy,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      ),
    );
  }

  Widget _desktopMetadataField({
    Key? key,
    required String label,
    required String value,
    String? detail,
  }) {
    final theme = Theme.of(context);
    final displayValue = value.trim().isEmpty
        ? context.shellText.notSet
        : value.trim();
    final displayDetail = detail?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        key: key,
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
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              displayValue,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (displayDetail != null && displayDetail.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                displayDetail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _providerFlowMessage(
    BuildContext context,
    ProviderDescriptor? descriptor,
  ) {
    return switch (descriptor?.browserPolicy) {
      ProviderBrowserPolicy.externalRequired =>
        context.shellText.browserNeedsExternal,
      ProviderBrowserPolicy.embeddedAllowed =>
        context.shellText.browserAllowsEmbedded,
      _ => context.shellText.browserNotRequired,
    };
  }

  String _providerFlowContinuation(
    BuildContext context,
    ProviderDescriptor? descriptor,
  ) {
    return descriptor?.mayRequireBrowserContinuation == true
        ? context.shellText.browserContinuationMayAppear
        : context.shellText.browserContinuationNotAdvertised;
  }

  String _desktopProviderFlowSummary(
    BuildContext context,
    ProviderDescriptor? descriptor,
  ) {
    return '${_providerFlowMessage(context, descriptor)} ${_providerFlowContinuation(context, descriptor)}';
  }

  bool _showsDesktopBrowserHandling(ProviderDescriptor? descriptor) {
    return descriptor?.browserPolicy != ProviderBrowserPolicy.notRequired ||
        descriptor?.mayRequireBrowserContinuation == true;
  }

  String _providerLinkLabel(
    BuildContext context,
    ProviderDescriptor? descriptor,
  ) {
    if (descriptor == null) {
      return context.shellText.providerInput;
    }
    return switch (descriptor.inputKind) {
      ProviderInputKind.link => context.shellText.providerLink,
      ProviderInputKind.remoteVpsCatalog => context.shellText.providerInput,
    };
  }

  String _providerFamilyValue(ProviderDescriptor? descriptor) {
    final displayName = descriptor?.displayName.trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName;
    }
    return widget.draft.spec.provider.trim();
  }

  ProviderDescriptor? _selectedDescriptor() {
    return _descriptorForProviderId(widget.draft.spec.provider);
  }

  ProviderDescriptor? _descriptorForProviderId(String providerId) {
    final normalized = providerId.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    for (final descriptor in widget.providerDescriptors) {
      if (descriptor.id.trim().toLowerCase() == normalized) {
        return descriptor;
      }
    }
    return null;
  }

  String? _resolvedManagedProviderId() {
    if (widget.managedProviders.isEmpty) {
      _selectedManagedProviderId = null;
      return null;
    }
    _selectedManagedProviderId ??=
        widget.selectedManagedProviderId ?? widget.managedProviders.first.id;
    if (!widget.managedProviders.any(
      (ManagedProviderRecord provider) =>
          provider.id == _selectedManagedProviderId,
    )) {
      _selectedManagedProviderId = widget.managedProviders.first.id;
    }
    return _selectedManagedProviderId;
  }

  ManagedProviderRecord? _managedProviderForId(String? managedProviderId) {
    if (managedProviderId == null || managedProviderId.isEmpty) {
      return null;
    }
    for (final provider in widget.managedProviders) {
      if (provider.id == managedProviderId) {
        return provider;
      }
    }
    return null;
  }

  void _updateProviderSettings(Map<String, dynamic> values) {
    _pushDraft(spec: widget.draft.spec.copyWith(providerSettings: values));
  }

  void _pushDraft({String? name, ProfileSpec? spec}) {
    widget.onDraftChanged(
      widget.draft.copyWith(
        name: name ?? widget.draft.name,
        spec: spec ?? widget.draft.spec,
      ),
    );
  }

  void _updateConnections(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final connections = int.tryParse(trimmed);
    if (connections == null) {
      return;
    }
    _pushDraft(spec: widget.draft.spec.copyWith(connections: connections));
  }

  void _syncFromDraft() {
    _syncControllerText(_nameController, widget.draft.name);
    _syncControllerText(_providerController, widget.draft.spec.provider);
    _syncControllerText(_linkController, widget.draft.spec.link);
    _syncControllerText(_listenController, widget.draft.spec.listenAddress);
    _syncControllerText(_peerController, widget.draft.spec.peerAddress);
    _syncControllerText(
      _connectionsController,
      widget.draft.spec.connections.toString(),
    );
    _syncControllerText(
      _turnServerController,
      widget.draft.spec.turnServer ?? '',
    );
    _syncControllerText(_turnPortController, widget.draft.spec.turnPort ?? '');
    _syncControllerText(
      _bindInterfaceController,
      widget.draft.spec.bindInterface ?? '',
    );
    _syncControllerText(_logLevelController, widget.draft.spec.logLevel);
  }

  void _syncControllerText(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }
}

List<Widget> _withSpacing(List<Widget> children, {required double height}) {
  if (children.isEmpty) {
    return const <Widget>[];
  }
  final spaced = <Widget>[];
  for (final child in children) {
    if (spaced.isNotEmpty) {
      spaced.add(SizedBox(height: height));
    }
    spaced.add(child);
  }
  return spaced;
}
