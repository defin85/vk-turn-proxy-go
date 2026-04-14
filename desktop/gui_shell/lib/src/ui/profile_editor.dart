import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_shell_core/provider_settings_form.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/profile_draft.dart';

class ProfileEditorPanel extends StatefulWidget {
  ProfileEditorPanel({
    super.key,
    required this.providerDescriptors,
    required this.selectedProfileId,
    required this.draft,
    required this.busy,
    required this.onDraftChanged,
    required this.onSave,
    required this.onDelete,
    required this.onReset,
    required this.onResolve,
    required this.onStart,
    this.onBrowseManagedProviders,
    List<ManagedProviderRecord>? managedProviders,
    String? initialManagedProviderId,
    void Function({String? managedProviderId})? onActivateManagedProviderMode,
    VoidCallback? onUseCustomProvider,
    List<ProviderConfigRecord>? availableProviderConfigs,
    ValueChanged<String>? onApplyProviderConfig,
  }) : managedProviders =
           managedProviders ??
           (availableProviderConfigs ?? const <ProviderConfigRecord>[])
               .map(ManagedProviderRecord.fromLegacyProviderConfig)
               .toList(growable: false),
       selectedManagedProviderId = initialManagedProviderId,
       onActivateManagedProviderMode =
           onActivateManagedProviderMode ??
           _legacyManagedProviderActivator(onApplyProviderConfig),
       onUseCustomProvider = onUseCustomProvider ?? _noop;

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
  final Future<void> Function()? onBrowseManagedProviders;
  final Future<void> Function() onSave;
  final Future<void> Function() onDelete;
  final VoidCallback onReset;
  final Future<void> Function() onResolve;
  final Future<void> Function() onStart;

  @override
  State<ProfileEditorPanel> createState() => _ProfileEditorPanelState();
}

void _noop() {}

void Function({String? managedProviderId}) _legacyManagedProviderActivator(
  ValueChanged<String>? onApplyProviderConfig,
) {
  return ({String? managedProviderId}) {
    if (managedProviderId != null && onApplyProviderConfig != null) {
      onApplyProviderConfig(managedProviderId);
    }
  };
}

class _ProfileEditorPanelState extends State<ProfileEditorPanel> {
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
  void didUpdateWidget(covariant ProfileEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft != widget.draft) {
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
    final theme = Theme.of(context);
    final descriptor = _selectedDescriptor();
    final managedMode = widget.draft.providerBinding.isManaged;
    final profileScopeLabel = widget.selectedProfileId == null
        ? 'Editing an unsaved draft'
        : 'Editing a saved profile workspace';
    final stepTitle = _nextStepTitle(descriptor);
    final stepDetail = _nextStepDetail(descriptor);
    final nextStepCard = _nextStepCard(
      theme,
      title: stepTitle,
      detail: stepDetail,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: <Widget>[
          FilledButton(
            key: const ValueKey<String>('profile-resolve-action'),
            onPressed: widget.busy ? null : () => unawaited(widget.onResolve()),
            child: const Text('Resolve invite'),
          ),
          FilledButton.tonal(
            key: const ValueKey<String>('profile-save-action'),
            onPressed: widget.busy ? null : () => unawaited(widget.onSave()),
            child: const Text('Save profile'),
          ),
        ],
      ),
    );

    return Card(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final pinActionHeader = constraints.maxHeight >= 360;
          return Padding(
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
                            'Profile workspace',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            profileScopeLabel,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: widget.busy ? null : widget.onReset,
                      icon: const Icon(Icons.add),
                      label: const Text('Fresh draft'),
                    ),
                  ],
                ),
                if (pinActionHeader) ...<Widget>[
                  const SizedBox(height: 16),
                  nextStepCard,
                ],
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    key: const ValueKey<String>('profile-workspace-scroll'),
                    primary: true,
                    children: <Widget>[
                      if (!pinActionHeader) ...<Widget>[
                        nextStepCard,
                        const SizedBox(height: 16),
                      ],
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(
                              Icons.playlist_add_check_circle_outlined,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Task-first workspace',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Use this workspace to shape the active profile, save it if needed, then resolve or start. Saved-profile browsing now opens only from an explicit secondary surface.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (descriptor != null) ...<Widget>[
                        _providerDescriptorCard(theme, descriptor),
                        const SizedBox(height: 16),
                      ],
                      _field(
                        controller: _nameController,
                        label: 'Profile name',
                        onChanged: (String value) => _pushDraft(name: value),
                      ),
                      _providerModeCard(theme, managedMode),
                      _providerField(),
                      _field(
                        controller: _linkController,
                        label: _providerLinkLabel(descriptor),
                        maxLines: 3,
                        onChanged: (String value) => _pushDraft(
                          spec: widget.draft.spec.copyWith(link: value.trim()),
                        ),
                      ),
                      _providerFlowCard(theme, descriptor),
                      ..._providerSettingsSection(theme, descriptor),
                      const SizedBox(height: 20),
                      Text(
                        'Operator-managed runtime defaults',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'These runtime defaults stay separate from the provider input. They are reused only after the resolution reaches a family that supports Start on this device.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(top: 8),
                        title: const Text('Inspect or edit runtime defaults'),
                        subtitle: Text(
                          _runtimeDefaultsSummary(widget.draft.spec),
                        ),
                        children: _runtimeDefaultsFields(),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Operator/support actions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Direct profile start remains available for support work, but descriptor-driven resolution stays primary.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(top: 8),
                        title: const Text('Inspect support-only actions'),
                        subtitle: const Text(
                          'Start or delete the saved profile without expanding the first read by default.',
                        ),
                        children: <Widget>[
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: <Widget>[
                              FilledButton.tonal(
                                key: const ValueKey<String>(
                                  'profile-start-action',
                                ),
                                onPressed:
                                    widget.busy ||
                                        widget.selectedProfileId == null
                                    ? null
                                    : () => unawaited(widget.onStart()),
                                child: const Text('Start saved profile'),
                              ),
                              OutlinedButton(
                                key: const ValueKey<String>(
                                  'profile-delete-action',
                                ),
                                onPressed:
                                    widget.busy ||
                                        widget.selectedProfileId == null
                                    ? null
                                    : () => unawaited(widget.onDelete()),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  Widget _nextStepCard(
    ThemeData theme, {
    required String title,
    required String detail,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F1E4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _providerDescriptorCard(
    ThemeData theme,
    ProviderDescriptor descriptor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE6EDF7),
        borderRadius: BorderRadius.circular(18),
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
              _workflowTag('Input: ${descriptor.inputKind.value}'),
              _workflowTag('Auth: ${descriptor.authPosture.label}'),
              _workflowTag('Browser: ${descriptor.browserPolicy.label}'),
              for (final family in descriptor.artifactFamilies)
                _workflowTag('Family: ${family.label}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _providerField() {
    if (widget.draft.providerBinding.isManaged) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _providerController,
          enabled: false,
          decoration: const InputDecoration(labelText: 'Provider family'),
        ),
      );
    }
    return _field(
      controller: _providerController,
      label: 'Provider',
      onChanged: (String value) =>
          _pushDraft(spec: widget.draft.spec.copyWith(provider: value.trim())),
    );
  }

  Widget _providerFlowCard(ThemeData theme, ProviderDescriptor? descriptor) {
    final message = switch (descriptor?.browserPolicy) {
      ProviderBrowserPolicy.externalRequired =>
        'This provider requires an external browser when challenge continuation appears.',
      ProviderBrowserPolicy.embeddedAllowed =>
        'This provider allows an embedded browser surface, but the host still controls whether a browser challenge appears.',
      _ => 'This provider does not report a required browser surface.',
    };
    final continuation = descriptor?.mayRequireBrowserContinuation == true
        ? 'Browser continuation may appear for this provider.'
        : 'No browser challenge mode is currently advertised for this provider.';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1D6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(continuation, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  String _providerLinkLabel(ProviderDescriptor? descriptor) {
    if (descriptor == null) {
      return 'Provider input';
    }
    return switch (descriptor.inputKind) {
      ProviderInputKind.link => 'Provider link',
    };
  }

  String _nextStepTitle(ProviderDescriptor? descriptor) {
    if (widget.draft.spec.link.trim().isEmpty) {
      return 'Step 1 · Add the provider input';
    }
    if (descriptor?.mayRequireBrowserContinuation == true) {
      return 'Step 2 · Resolve, then continue in browser if needed';
    }
    return 'Step 2 · Resolve this profile from the active editor';
  }

  String _nextStepDetail(ProviderDescriptor? descriptor) {
    if (widget.draft.spec.link.trim().isEmpty) {
      return 'Keep the main editor calm: choose the provider mode, add the current input, then resolve or save when the draft is ready.';
    }
    if (descriptor?.mayRequireBrowserContinuation == true) {
      return 'The normal path is resolve first. If the host reports a browser challenge, continue there and then return to the same workflow.';
    }
    return 'Resolve stays primary for the common path. Save the profile when you need to keep this draft for later runtime starts.';
  }

  ProviderDescriptor? _selectedDescriptor() {
    final providerId = widget.draft.spec.provider.trim().toLowerCase();
    for (final descriptor in widget.providerDescriptors) {
      if (descriptor.id.trim().toLowerCase() == providerId) {
        return descriptor;
      }
    }
    return null;
  }

  Widget _workflowTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }

  Widget _field({
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

  List<Widget> _providerSettingsSection(
    ThemeData theme,
    ProviderDescriptor? descriptor,
  ) {
    final schema = descriptor?.settingsSchema;
    if (schema == null) {
      return const <Widget>[];
    }

    final section = <Widget>[
      const SizedBox(height: 8),
      Text(
        'Provider settings',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
    ];

    final supportError = descriptor?.providerSettingsSupportError;
    if (supportError != null) {
      section.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE2DE),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'This desktop shell cannot render the provider settings schema for ${descriptor!.displayName}: $supportError. Save and resolve stay blocked until the host advertises a supported schema subset.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
      return section;
    }

    section.add(
      Text(
        'Profile-retained settings stay with the saved profile. Prompt-only values remain only in the in-memory draft used for immediate resolution starts.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
    section.add(const SizedBox(height: 8));
    section.add(
      ProviderSettingsForm(
        descriptor: descriptor!,
        values: widget.draft.spec.providerSettings,
        enabled: !widget.busy,
        onChanged: (Map<String, dynamic> values) {
          _pushDraft(
            spec: widget.draft.spec.copyWith(providerSettings: values),
          );
        },
      ),
    );
    return section;
  }

  List<Widget> _runtimeDefaultsFields() {
    return <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: _field(
              controller: _listenController,
              label: 'Local UDP listen',
              onChanged: (String value) => _pushDraft(
                spec: widget.draft.spec.copyWith(listenAddress: value.trim()),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _field(
              controller: _peerController,
              label: 'Peer address',
              onChanged: (String value) => _pushDraft(
                spec: widget.draft.spec.copyWith(peerAddress: value.trim()),
              ),
            ),
          ),
        ],
      ),
      Row(
        children: <Widget>[
          Expanded(
            child: _field(
              controller: _connectionsController,
              label: 'Connections',
              onChanged: (String value) => _pushDraft(
                spec: widget.draft.spec.copyWith(
                  connections: int.tryParse(value.trim()) ?? 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<TransportMode>(
              initialValue: widget.draft.spec.mode,
              decoration: const InputDecoration(labelText: 'TURN mode'),
              items: TransportMode.values
                  .map(
                    (TransportMode mode) => DropdownMenuItem<TransportMode>(
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
                      _pushDraft(spec: widget.draft.spec.copyWith(mode: mode));
                    },
            ),
          ),
        ],
      ),
      Row(
        children: <Widget>[
          Expanded(
            child: _field(
              controller: _turnServerController,
              label: 'TURN override',
              onChanged: (String value) => _pushDraft(
                spec: widget.draft.spec.copyWith(turnServer: value.trim()),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _field(
              controller: _turnPortController,
              label: 'TURN port',
              onChanged: (String value) => _pushDraft(
                spec: widget.draft.spec.copyWith(turnPort: value.trim()),
              ),
            ),
          ),
        ],
      ),
      _field(
        controller: _bindInterfaceController,
        label: 'Bind interface',
        onChanged: (String value) => _pushDraft(
          spec: widget.draft.spec.copyWith(bindInterface: value.trim()),
        ),
      ),
      _field(
        controller: _logLevelController,
        label: 'Log level',
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
        title: const Text('DTLS enabled'),
      ),
    ];
  }

  String _runtimeDefaultsSummary(ProfileSpec spec) {
    final turnOverride = (spec.turnServer ?? '').isEmpty
        ? 'provider TURN'
        : '${spec.turnServer}${(spec.turnPort ?? '').isEmpty ? '' : ':${spec.turnPort}'}';
    final dtlsLabel = spec.useDtls ? 'DTLS on' : 'DTLS off';
    return '${spec.listenAddress} -> ${spec.peerAddress} | ${spec.connections} conn | ${spec.mode.value} | $dtlsLabel | $turnOverride';
  }

  void _pushDraft({String? name, ProfileSpec? spec}) {
    widget.onDraftChanged(
      widget.draft.copyWith(
        name: name ?? widget.draft.name,
        spec: spec ?? widget.draft.spec,
      ),
    );
  }

  void _syncFromDraft() {
    _nameController.text = widget.draft.name;
    _providerController.text = widget.draft.spec.provider;
    _linkController.text = widget.draft.spec.link;
    _listenController.text = widget.draft.spec.listenAddress;
    _peerController.text = widget.draft.spec.peerAddress;
    _connectionsController.text = widget.draft.spec.connections.toString();
    _turnServerController.text = widget.draft.spec.turnServer ?? '';
    _turnPortController.text = widget.draft.spec.turnPort ?? '';
    _bindInterfaceController.text = widget.draft.spec.bindInterface ?? '';
    _logLevelController.text = widget.draft.spec.logLevel;
  }

  Widget _providerModeCard(ThemeData theme, bool managedMode) {
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
              'Provider mode',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No managed providers are available yet. Use custom mode for direct provider entry or create a provider record from the explicit provider-record surface first.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            ChoiceChip(
              selected: true,
              label: const Text('Custom provider'),
              onSelected: widget.busy
                  ? null
                  : (_) => widget.onUseCustomProvider(),
            ),
          ],
        ),
      );
    }

    _selectedManagedProviderId ??=
        widget.selectedManagedProviderId ?? widget.managedProviders.first.id;
    final selectedManagedProviderId =
        widget.managedProviders.any(
          (ManagedProviderRecord provider) =>
              provider.id == _selectedManagedProviderId,
        )
        ? _selectedManagedProviderId
        : widget.managedProviders.first.id;
    _selectedManagedProviderId = selectedManagedProviderId;

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
            'Provider mode',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            managedMode
                ? 'Managed mode snapshots values from a saved provider record, then keeps further profile edits local to this draft.'
                : 'Custom mode lets you type a raw provider id and prompt-only inputs without mutating the managed provider catalog.',
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
                label: const Text('Managed provider'),
                onSelected: widget.busy
                    ? null
                    : (_) => widget.onActivateManagedProviderMode(
                        managedProviderId: selectedManagedProviderId,
                      ),
              ),
              ChoiceChip(
                selected: !managedMode,
                label: const Text('Custom provider'),
                onSelected: widget.busy
                    ? null
                    : (_) => widget.onUseCustomProvider(),
              ),
            ],
          ),
          if (managedMode) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Managed provider',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(() {
                    final provider = widget.managedProviders.firstWhere(
                      (ManagedProviderRecord provider) =>
                          provider.id == selectedManagedProviderId,
                    );
                    return provider.name.isEmpty
                        ? selectedManagedProviderId!
                        : provider.name;
                  }(), style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Browse reusable records from the explicit secondary surface when you need a different source.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Use the action strip above the editor when you need to pick a different reusable record.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
