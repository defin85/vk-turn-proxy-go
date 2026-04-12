import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/profile_draft.dart';

class ProfileEditorPanel extends StatefulWidget {
  const ProfileEditorPanel({
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
  });

  final List<ProviderDescriptor> providerDescriptors;
  final String? selectedProfileId;
  final ProfileDraft draft;
  final bool busy;
  final ValueChanged<ProfileDraft> onDraftChanged;
  final Future<void> Function() onSave;
  final Future<void> Function() onDelete;
  final VoidCallback onReset;
  final Future<void> Function() onResolve;
  final Future<void> Function() onStart;

  @override
  State<ProfileEditorPanel> createState() => _ProfileEditorPanelState();
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
  final Map<String, TextEditingController> _providerSettingControllers =
      <String, TextEditingController>{};

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
    for (final controller in _providerSettingControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final descriptor = _selectedDescriptor();
    final profileScopeLabel = widget.selectedProfileId == null
        ? 'Editing an unsaved draft'
        : 'Editing a saved profile workspace';

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
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                key: const ValueKey<String>('profile-workspace-scroll'),
                children: <Widget>[
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
                        const Icon(Icons.playlist_add_check_circle_outlined),
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
                                'Use this workspace to shape the active profile, save it if needed, then resolve or start. Saved-profile browsing now stays in the separate library rail.',
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
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      FilledButton(
                        onPressed: widget.busy
                            ? null
                            : () => unawaited(widget.onSave()),
                        child: const Text('Save profile'),
                      ),
                      FilledButton.tonal(
                        onPressed: widget.busy
                            ? null
                            : () => unawaited(widget.onResolve()),
                        child: const Text('Resolve invite'),
                      ),
                    ],
                  ),
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
                    subtitle: Text(_runtimeDefaultsSummary(widget.draft.spec)),
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
                    'Direct profile start and raw transport tuning remain available for support work, but descriptor-driven resolution is the primary provider entry path.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      FilledButton.tonal(
                        onPressed:
                            widget.busy || widget.selectedProfileId == null
                            ? null
                            : () => unawaited(widget.onStart()),
                        child: const Text('Start saved profile'),
                      ),
                      OutlinedButton(
                        onPressed:
                            widget.busy || widget.selectedProfileId == null
                            ? null
                            : () => unawaited(widget.onDelete()),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
    if (widget.providerDescriptors.isEmpty) {
      return _field(
        controller: _providerController,
        label: 'Provider',
        onChanged: (String value) => _pushDraft(
          spec: widget.draft.spec.copyWith(provider: value.trim()),
        ),
      );
    }

    final providerId =
        _selectedDescriptor()?.id ?? widget.providerDescriptors.first.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: providerId,
        decoration: const InputDecoration(labelText: 'Provider'),
        items: widget.providerDescriptors
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
                  spec: widget.draft.spec.copyWith(
                    provider: value,
                    link: value == widget.draft.spec.provider
                        ? widget.draft.spec.link
                        : '',
                  ),
                );
              },
      ),
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

  ProviderDescriptor? _selectedDescriptor() {
    final providerId = widget.draft.spec.provider.trim().toLowerCase();
    for (final descriptor in widget.providerDescriptors) {
      if (descriptor.id.trim().toLowerCase() == providerId) {
        return descriptor;
      }
    }
    return widget.providerDescriptors.isEmpty
        ? null
        : widget.providerDescriptors.first;
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
    section.addAll(
      descriptor!.providerSettingsFields.map(
        (ProviderSettingsField field) => _providerSettingsField(field),
      ),
    );
    return section;
  }

  Widget _providerSettingsField(ProviderSettingsField field) {
    final property = field.property;
    final label = property.title.isEmpty ? field.key : property.title;

    switch (property.control) {
      case ProviderSettingControl.select:
        final items = property.enumValues
            .map(
              (dynamic value) => DropdownMenuItem<dynamic>(
                value: value,
                child: Text('$value'),
              ),
            )
            .toList(growable: false);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<dynamic>(
            initialValue: widget.draft.spec.providerSettings[field.key],
            decoration: InputDecoration(
              labelText: label,
              helperText: property.description.isEmpty
                  ? null
                  : property.description,
            ),
            items: items,
            onChanged: widget.busy
                ? null
                : (dynamic value) => _updateProviderSetting(field.key, value),
          ),
        );
      case ProviderSettingControl.checkbox:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value:
              widget.draft.spec.providerSettings[field.key] as bool? ?? false,
          onChanged: widget.busy
              ? null
              : (bool value) => _updateProviderSetting(field.key, value),
          title: Text(label),
          subtitle: property.description.isEmpty
              ? null
              : Text(property.description),
        );
      case ProviderSettingControl.text:
      case ProviderSettingControl.textarea:
      case ProviderSettingControl.password:
        return _field(
          controller: _providerSettingController(field.key),
          label: label,
          maxLines: property.control == ProviderSettingControl.textarea ? 3 : 1,
          obscureText: property.control == ProviderSettingControl.password,
          keyboardType: switch (property.type) {
            ProviderSettingType.integer => TextInputType.number,
            ProviderSettingType.number => const TextInputType.numberWithOptions(
              decimal: true,
            ),
            _ => TextInputType.text,
          },
          onChanged: (String value) {
            final trimmed = value.trim();
            if (trimmed.isEmpty) {
              _removeProviderSetting(field.key);
              return;
            }
            final nextValue = switch (property.type) {
              ProviderSettingType.integer => int.tryParse(trimmed) ?? trimmed,
              ProviderSettingType.number => double.tryParse(trimmed) ?? trimmed,
              ProviderSettingType.boolean => trimmed.toLowerCase() == 'true',
              _ => value,
            };
            _updateProviderSetting(field.key, nextValue);
          },
        );
      case null:
        return const SizedBox.shrink();
    }
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
    _syncProviderSettingControllers(_selectedDescriptor());
  }

  TextEditingController _providerSettingController(String key) {
    return _providerSettingControllers.putIfAbsent(
      key,
      () => TextEditingController(),
    );
  }

  void _updateProviderSetting(String key, dynamic value) {
    final nextSettings = Map<String, dynamic>.from(
      widget.draft.spec.providerSettings,
    );
    if (value == null) {
      nextSettings.remove(key);
    } else {
      nextSettings[key] = value;
    }
    _pushDraft(
      spec: widget.draft.spec.copyWith(providerSettings: nextSettings),
    );
  }

  void _removeProviderSetting(String key) {
    final nextSettings = Map<String, dynamic>.from(
      widget.draft.spec.providerSettings,
    );
    if (nextSettings.remove(key) != null) {
      _pushDraft(
        spec: widget.draft.spec.copyWith(providerSettings: nextSettings),
      );
    }
  }

  void _syncProviderSettingControllers(ProviderDescriptor? descriptor) {
    final activeKeys =
        descriptor?.providerSettingsFields
            .where((ProviderSettingsField field) {
              return field.property.control == ProviderSettingControl.text ||
                  field.property.control == ProviderSettingControl.textarea ||
                  field.property.control == ProviderSettingControl.password;
            })
            .map((ProviderSettingsField field) => field.key)
            .toSet() ??
        <String>{};
    final removable = _providerSettingControllers.keys
        .where((String key) => !activeKeys.contains(key))
        .toList(growable: false);
    for (final key in removable) {
      _providerSettingControllers.remove(key)?.dispose();
    }
    for (final key in activeKeys) {
      final controller = _providerSettingController(key);
      final value = widget.draft.spec.providerSettings[key];
      final text = value == null ? '' : '$value';
      if (controller.text == text) {
        continue;
      }
      controller.value = controller.value.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
        composing: TextRange.empty,
      );
    }
  }
}
