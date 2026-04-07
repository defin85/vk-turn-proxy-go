import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/profile_draft.dart';

class ProfileEditorPanel extends StatefulWidget {
  const ProfileEditorPanel({
    super.key,
    required this.profiles,
    required this.selectedProfileId,
    required this.draft,
    required this.busy,
    required this.onSelectProfile,
    required this.onDraftChanged,
    required this.onSave,
    required this.onDelete,
    required this.onReset,
    required this.onStart,
  });

  final List<ProfileRecord> profiles;
  final String? selectedProfileId;
  final ProfileDraft draft;
  final bool busy;
  final ValueChanged<String> onSelectProfile;
  final ValueChanged<ProfileDraft> onDraftChanged;
  final Future<void> Function() onSave;
  final Future<void> Function() onDelete;
  final VoidCallback onReset;
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
                    'Profiles',
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
                children: <Widget>[
                  _field(
                    controller: _nameController,
                    label: 'Profile name',
                    onChanged: (String value) => _pushDraft(name: value),
                  ),
                  _field(
                    controller: _providerController,
                    label: 'Provider',
                    onChanged: (String value) => _pushDraft(
                      spec: widget.draft.spec.copyWith(provider: value.trim()),
                    ),
                  ),
                  _field(
                    controller: _linkController,
                    label: 'Provider link',
                    maxLines: 3,
                    onChanged: (String value) => _pushDraft(
                      spec: widget.draft.spec.copyWith(link: value.trim()),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _field(
                          controller: _listenController,
                          label: 'Local UDP listen',
                          onChanged: (String value) => _pushDraft(
                            spec: widget.draft.spec.copyWith(
                              listenAddress: value.trim(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          controller: _peerController,
                          label: 'Peer address',
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
                          decoration: const InputDecoration(
                            labelText: 'TURN mode',
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
                                    spec: widget.draft.spec.copyWith(
                                      mode: mode,
                                    ),
                                  );
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
                            spec: widget.draft.spec.copyWith(
                              turnServer: value.trim(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          controller: _turnPortController,
                          label: 'TURN port',
                          onChanged: (String value) => _pushDraft(
                            spec: widget.draft.spec.copyWith(
                              turnPort: value.trim(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _field(
                    controller: _bindInterfaceController,
                    label: 'Bind interface',
                    onChanged: (String value) => _pushDraft(
                      spec: widget.draft.spec.copyWith(
                        bindInterface: value.trim(),
                      ),
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
                    value: widget.draft.spec.useDtls,
                    onChanged: widget.busy
                        ? null
                        : (bool enabled) => _pushDraft(
                            spec: widget.draft.spec.copyWith(useDtls: enabled),
                          ),
                    title: const Text('DTLS enabled'),
                  ),
                  SwitchListTile(
                    value: widget.draft.spec.interactiveProvider,
                    onChanged: widget.busy
                        ? null
                        : (bool enabled) => _pushDraft(
                            spec: widget.draft.spec.copyWith(
                              interactiveProvider: enabled,
                            ),
                          ),
                    title: const Text('Interactive provider challenges'),
                  ),
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
                  const SizedBox(height: 24),
                  Text(
                    'Saved profiles',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.profiles.isEmpty)
                    Text(
                      'No saved profiles yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  for (final ProfileRecord profile
                      in widget.profiles) ...<Widget>[
                    const SizedBox(height: 8),
                    Material(
                      color: widget.selectedProfileId == profile.id
                          ? theme.colorScheme.primary.withValues(alpha: 0.08)
                          : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => widget.onSelectProfile(profile.id),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                profile.name.isEmpty
                                    ? profile.id
                                    : profile.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${profile.spec.provider} -> ${profile.spec.peerAddress}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
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
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        enabled: !widget.busy,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      ),
    );
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
}
