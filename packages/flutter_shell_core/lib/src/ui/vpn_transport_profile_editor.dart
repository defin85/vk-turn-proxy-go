import 'dart:async';

import 'package:flutter/material.dart';

import '../control/runtime_execution_planning.dart';
import 'shell_visuals.dart';

enum VPNTransportProfileEditorVariant { mobile, desktop }

enum VPNTransportProfileEditorMode { create, edit }

class VPNTransportProfileEditorSurface extends StatefulWidget {
  const VPNTransportProfileEditorSurface({
    super.key,
    required this.variant,
    required this.mode,
    required this.schema,
    required this.onValidate,
    required this.onSave,
    this.existingProfile,
    this.defaultFor,
    this.onSaved,
    this.onCancel,
    this.onImportFallback,
  });

  final VPNTransportProfileEditorVariant variant;
  final VPNTransportProfileEditorMode mode;
  final TransportProfileEditableKindSchema schema;
  final TransportProfileStatus? existingProfile;
  final RuntimeExecutionPlan? defaultFor;
  final Future<TransportProfileStructuredValidationResult> Function(
    TransportProfileStructuredValidationRequest request,
  )
  onValidate;
  final Future<TransportProfileStructuredSaveResult> Function(
    TransportProfileStructuredDraft draft,
  )
  onSave;
  final ValueChanged<TransportProfileStructuredSaveResult>? onSaved;
  final VoidCallback? onCancel;
  final VoidCallback? onImportFallback;

  @override
  State<VPNTransportProfileEditorSurface> createState() =>
      _VPNTransportProfileEditorSurfaceState();
}

class _VPNTransportProfileEditorSurfaceState
    extends State<VPNTransportProfileEditorSurface> {
  final Map<TransportProfileStructuredFieldId, TextEditingController>
  _controllers = <TransportProfileStructuredFieldId, TextEditingController>{};
  final Map<
    TransportProfileStructuredFieldId,
    TransportProfileSecretUpdateAction
  >
  _secretActions =
      <TransportProfileStructuredFieldId, TransportProfileSecretUpdateAction>{};
  final Map<TransportProfileStructuredFieldId, String> _fieldErrors =
      <TransportProfileStructuredFieldId, String>{};

  bool _saving = false;
  String? _formError;
  TransportProfileStructuredSaveResult? _savedResult;

  bool get _desktop =>
      widget.variant == VPNTransportProfileEditorVariant.desktop;

  List<TransportProfileStructuredFieldDescriptor> get _fields {
    final fields = widget.schema.fields.toList(growable: false);
    fields.sort((left, right) {
      final order = left.order.compareTo(right.order);
      if (order != 0) {
        return order;
      }
      return left.id.value.compareTo(right.id.value);
    });
    return fields;
  }

  List<TransportProfileStructuredFieldDescriptor> get _unsupportedFields =>
      _fields
          .where(
            (TransportProfileStructuredFieldDescriptor field) =>
                !field.supportedByShell,
          )
          .toList(growable: false);

  @override
  void initState() {
    super.initState();
    for (final field in _fields) {
      _controllers[field.id] = TextEditingController(
        text: _initialValueFor(field),
      );
      if (field.secret) {
        _secretActions[field.id] = _initialSecretActionFor(field);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final savedResult = _savedResult;
    final unsupportedFields = _unsupportedFields;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: _desktop ? 660 : 560),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(_desktop ? 24 : 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.mode == VPNTransportProfileEditorMode.create
                              ? 'Create VPN profile'
                              : 'Edit VPN profile',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _kindLabel(widget.schema.kind),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onCancel != null)
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _saving ? null : widget.onCancel,
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (unsupportedFields.isNotEmpty) ...<Widget>[
                _UnsupportedSchemaNotice(fields: unsupportedFields),
                const SizedBox(height: 14),
              ],
              ..._fields
                  .where(
                    (TransportProfileStructuredFieldDescriptor field) =>
                        field.supportedByShell,
                  )
                  .map(
                    (TransportProfileStructuredFieldDescriptor field) =>
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildField(context, field),
                        ),
                  ),
              if (_formError?.trim().isNotEmpty == true) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  _formError!.trim(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              if (savedResult != null) ...<Widget>[
                const SizedBox(height: 16),
                _SavedProfileResult(result: savedResult),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.icon(
                    key: const ValueKey<String>('vpn-profile-editor-save'),
                    onPressed: _saving || unsupportedFields.isNotEmpty
                        ? null
                        : () => unawaited(_save()),
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      widget.mode == VPNTransportProfileEditorMode.create
                          ? 'Save profile'
                          : 'Save changes',
                    ),
                  ),
                  if (widget.onImportFallback != null)
                    OutlinedButton.icon(
                      key: const ValueKey<String>(
                        'vpn-profile-editor-import-fallback',
                      ),
                      onPressed: _saving ? null : widget.onImportFallback,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Import'),
                    ),
                  if (savedResult != null && widget.onCancel != null)
                    TextButton(
                      onPressed: _saving ? null : widget.onCancel,
                      child: const Text('Done'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    BuildContext context,
    TransportProfileStructuredFieldDescriptor field,
  ) {
    if (field.secret) {
      return _buildSecretField(context, field);
    }
    final controller = _controllers[field.id]!;
    return _textField(
      controller: controller,
      field: field,
      keyboardType:
          field.valueKind == TransportProfileStructuredFieldValueKind.integer
          ? TextInputType.number
          : null,
      maxLines:
          field.valueKind == TransportProfileStructuredFieldValueKind.stringList
          ? 2
          : 1,
    );
  }

  Widget _buildSecretField(
    BuildContext context,
    TransportProfileStructuredFieldDescriptor field,
  ) {
    final theme = Theme.of(context);
    final actions = field.secretUpdateActions.isEmpty
        ? const <TransportProfileSecretUpdateAction>[
            TransportProfileSecretUpdateAction.replaceSubmitted,
          ]
        : field.secretUpdateActions;
    final selected =
        _secretActions[field.id] ??
        (actions.contains(TransportProfileSecretUpdateAction.replaceSubmitted)
            ? TransportProfileSecretUpdateAction.replaceSubmitted
            : actions.first);
    final replacing =
        selected == TransportProfileSecretUpdateAction.replaceSubmitted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DropdownButtonFormField<TransportProfileSecretUpdateAction>(
          key: ValueKey<String>('vpn-profile-editor-${field.id.value}-action'),
          initialValue: actions.contains(selected) ? selected : actions.first,
          decoration: InputDecoration(
            labelText: _labelFor(field),
            helperText: _helperTextFor(field),
            border: const OutlineInputBorder(),
          ),
          items: actions
              .map(
                (TransportProfileSecretUpdateAction action) =>
                    DropdownMenuItem<TransportProfileSecretUpdateAction>(
                      value: action,
                      child: Text(_secretActionLabel(action)),
                    ),
              )
              .toList(growable: false),
          onChanged: _saving
              ? null
              : (TransportProfileSecretUpdateAction? action) {
                  if (action == null) {
                    return;
                  }
                  setState(() {
                    _secretActions[field.id] = action;
                    _fieldErrors.remove(field.id);
                    _formError = null;
                    if (action !=
                        TransportProfileSecretUpdateAction.replaceSubmitted) {
                      _controllers[field.id]?.clear();
                    }
                  });
                },
        ),
        if (replacing) ...<Widget>[
          const SizedBox(height: 8),
          _textField(
            controller: _controllers[field.id]!,
            field: field,
            obscureText: true,
            labelOverride: widget.mode == VPNTransportProfileEditorMode.edit
                ? 'New ${_labelFor(field).toLowerCase()}'
                : null,
          ),
        ] else ...<Widget>[
          const SizedBox(height: 6),
          Text(
            _secretActionHint(selected),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required TransportProfileStructuredFieldDescriptor field,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool obscureText = false,
    String? labelOverride,
  }) {
    return TextField(
      key: ValueKey<String>('vpn-profile-editor-${field.id.value}'),
      controller: controller,
      keyboardType: keyboardType,
      maxLines: obscureText ? 1 : maxLines,
      obscureText: obscureText,
      enabled: !_saving,
      decoration: InputDecoration(
        labelText: labelOverride ?? _labelFor(field),
        helperText: _helperTextFor(field),
        hintText: field.placeholder.trim().isEmpty
            ? null
            : field.placeholder.trim(),
        border: const OutlineInputBorder(),
        errorText: _fieldErrors[field.id],
      ),
      onChanged: (_) {
        if (_fieldErrors.containsKey(field.id) || _formError != null) {
          setState(() {
            _fieldErrors.remove(field.id);
            _formError = null;
          });
        }
      },
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _formError = null;
      _fieldErrors.clear();
      _savedResult = null;
    });
    try {
      final draft = _buildDraft();
      final validation = await widget.onValidate(
        TransportProfileStructuredValidationRequest(
          profileId: widget.existingProfile?.id ?? '',
          draft: draft,
        ),
      );
      if (!validation.valid) {
        _clearSecretControllers();
        _applyValidationErrors(validation.errors);
        return;
      }
      final result = await widget.onSave(draft);
      _clearSecretControllers();
      widget.onSaved?.call(result);
      if (mounted) {
        setState(() {
          _savedResult = result;
        });
      }
    } catch (error) {
      _clearSecretControllers();
      if (mounted) {
        setState(() {
          _formError = '$error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _applyValidationErrors(
    List<TransportProfileFieldValidationError> errors,
  ) {
    if (!mounted) {
      return;
    }
    setState(() {
      for (final error in errors) {
        _fieldErrors[error.field] = error.message.trim().isEmpty
            ? error.violation
            : error.message;
      }
      _formError = errors.isEmpty ? 'Profile validation failed' : null;
    });
  }

  TransportProfileStructuredDraft _buildDraft() {
    final fields = <TransportProfileStructuredFieldId, Object?>{};
    final secretActions =
        <
          TransportProfileStructuredFieldId,
          TransportProfileSecretUpdateAction
        >{};
    for (final field in _fields) {
      if (!field.supportedByShell) {
        continue;
      }
      final controller = _controllers[field.id];
      if (field.secret) {
        final action =
            _secretActions[field.id] ??
            TransportProfileSecretUpdateAction.replaceSubmitted;
        secretActions[field.id] = action;
        if (action == TransportProfileSecretUpdateAction.replaceSubmitted) {
          final submitted = controller?.text.trim() ?? '';
          if (submitted.isNotEmpty) {
            fields[field.id] = submitted;
          }
        }
        continue;
      }
      final raw = controller?.text.trim() ?? '';
      if (field.valueKind == TransportProfileStructuredFieldValueKind.string) {
        if (raw.isNotEmpty) {
          fields[field.id] = raw;
        }
      } else if (field.valueKind ==
          TransportProfileStructuredFieldValueKind.stringList) {
        final values = _splitList(raw);
        if (values.isNotEmpty) {
          fields[field.id] = values;
        }
      } else if (field.valueKind ==
          TransportProfileStructuredFieldValueKind.integer) {
        if (raw.isNotEmpty) {
          fields[field.id] = int.tryParse(raw) ?? 0;
        }
      }
    }
    return TransportProfileStructuredDraft(
      kind: widget.schema.kind,
      schemaVersion: widget.schema.schemaVersion,
      fields: fields,
      secretActions: secretActions,
      defaultFor: widget.defaultFor,
    );
  }

  void _clearSecretControllers() {
    for (final field in _fields.where(
      (TransportProfileStructuredFieldDescriptor field) => field.secret,
    )) {
      _controllers[field.id]?.clear();
    }
  }

  String _initialValueFor(TransportProfileStructuredFieldDescriptor field) {
    if (field.id == TransportProfileStructuredFieldId.displayName) {
      return widget.existingProfile?.displayName.trim().isNotEmpty == true
          ? widget.existingProfile!.displayName.trim()
          : firstNonEmpty(field.defaultString, _kindLabel(widget.schema.kind));
    }
    if (field.valueKind ==
        TransportProfileStructuredFieldValueKind.stringList) {
      return field.defaultStringList.join('\n');
    }
    if (field.valueKind == TransportProfileStructuredFieldValueKind.integer &&
        field.defaultInteger != 0) {
      return '${field.defaultInteger}';
    }
    return field.defaultString;
  }

  TransportProfileSecretUpdateAction _initialSecretActionFor(
    TransportProfileStructuredFieldDescriptor field,
  ) {
    final actions = field.secretUpdateActions;
    if (widget.mode == VPNTransportProfileEditorMode.create &&
        actions.contains(TransportProfileSecretUpdateAction.generateHost)) {
      return TransportProfileSecretUpdateAction.generateHost;
    }
    if (widget.mode == VPNTransportProfileEditorMode.edit &&
        actions.contains(TransportProfileSecretUpdateAction.preserveExisting)) {
      return TransportProfileSecretUpdateAction.preserveExisting;
    }
    if (actions.contains(TransportProfileSecretUpdateAction.replaceSubmitted)) {
      return TransportProfileSecretUpdateAction.replaceSubmitted;
    }
    return actions.isEmpty
        ? TransportProfileSecretUpdateAction.replaceSubmitted
        : actions.first;
  }

  List<String> _splitList(String raw) {
    return raw
        .split(RegExp(r'[\n,]'))
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
  }

  String _labelFor(TransportProfileStructuredFieldDescriptor field) {
    if (field.displayName.trim().isNotEmpty) {
      return field.displayName.trim();
    }
    return switch (field.id) {
      TransportProfileStructuredFieldId.displayName => 'Name',
      TransportProfileStructuredFieldId.interfacePrivateKey => 'Private key',
      TransportProfileStructuredFieldId.interfaceAddresses =>
        'Interface addresses',
      TransportProfileStructuredFieldId.dnsServers => 'DNS servers',
      TransportProfileStructuredFieldId.mtu => 'MTU',
      TransportProfileStructuredFieldId.peerPublicKey => 'Peer public key',
      TransportProfileStructuredFieldId.peerPresharedKey =>
        'Peer preshared key',
      TransportProfileStructuredFieldId.allowedIps => 'Allowed IPs',
      TransportProfileStructuredFieldId.endpoint => 'Endpoint',
      TransportProfileStructuredFieldId.persistentKeepalive =>
        'Persistent keepalive',
      _ => field.id.value,
    };
  }

  String? _helperTextFor(TransportProfileStructuredFieldDescriptor field) {
    final help = field.helpText.trim();
    return help.isEmpty ? null : help;
  }

  String _kindLabel(TransportProfileKind kind) {
    if (kind == TransportProfileKind.wireGuardNativeV1) {
      return 'WireGuard';
    }
    return kind.value;
  }

  String _secretActionLabel(TransportProfileSecretUpdateAction action) {
    return switch (action) {
      TransportProfileSecretUpdateAction.preserveExisting =>
        'Preserve existing',
      TransportProfileSecretUpdateAction.replaceSubmitted => 'Replace',
      TransportProfileSecretUpdateAction.generateHost => 'Generate',
    };
  }

  String _secretActionHint(TransportProfileSecretUpdateAction action) {
    return switch (action) {
      TransportProfileSecretUpdateAction.preserveExisting =>
        'Existing secret material will be preserved.',
      TransportProfileSecretUpdateAction.generateHost =>
        'The host will generate this secret on save.',
      TransportProfileSecretUpdateAction.replaceSubmitted =>
        'Enter replacement secret material.',
    };
  }
}

class _UnsupportedSchemaNotice extends StatelessWidget {
  const _UnsupportedSchemaNotice({required this.fields});

  final List<TransportProfileStructuredFieldDescriptor> fields;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: shellSurfaceDecoration(
        context,
        style: ShellSurfaceStyle.highlight,
        tone: ShellSemanticTone.attention,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Profile schema is not supported',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          for (final field in fields)
            Text(
              firstNonEmpty(
                field.unsupportedReason,
                '${field.id.value}: ${field.valueKind.value}',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _SavedProfileResult extends StatelessWidget {
  const _SavedProfileResult({required this.result});

  final TransportProfileStructuredSaveResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final generated = result.generatedKeys
        .where(
          (TransportProfileGeneratedKey key) =>
              key.field ==
              TransportProfileStructuredFieldId.interfacePrivateKey,
        )
        .toList(growable: false);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: shellSurfaceDecoration(
        context,
        style: ShellSurfaceStyle.highlight,
        tone: ShellSemanticTone.ready,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Profile saved',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (generated.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Generated public key',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              generated.first.publicKey,
              key: const ValueKey<String>(
                'vpn-profile-editor-generated-public-key',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class VPNTransportProfileManagerSurface extends StatelessWidget {
  const VPNTransportProfileManagerSurface({
    super.key,
    required this.variant,
    required this.profiles,
    this.requiredKinds = const <TransportProfileKind>[],
    this.executionPlan,
    this.onCreate,
    this.onImport,
    this.onEdit,
    this.onValidate,
    this.onForget,
    this.onSelect,
    this.onClose,
  });

  final VPNTransportProfileEditorVariant variant;
  final List<TransportProfileStatus> profiles;
  final List<TransportProfileKind> requiredKinds;
  final RuntimeExecutionPlan? executionPlan;
  final Future<void> Function()? onCreate;
  final Future<void> Function()? onImport;
  final Future<void> Function(TransportProfileStatus profile)? onEdit;
  final Future<void> Function(TransportProfileStatus profile)? onValidate;
  final Future<void> Function(TransportProfileStatus profile)? onForget;
  final Future<void> Function(TransportProfileStatus profile)? onSelect;
  final VoidCallback? onClose;

  bool get _desktop => variant == VPNTransportProfileEditorVariant.desktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleProfiles = _visibleProfiles();
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: _desktop ? 720 : 580),
      child: Padding(
        padding: EdgeInsets.all(_desktop ? 24 : 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'VPN transport profiles',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    tooltip: 'Close',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _managerSubtitle(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (onCreate != null)
                  FilledButton.icon(
                    key: const ValueKey<String>('vpn-profile-manager-create'),
                    onPressed: () => unawaited(onCreate!()),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create'),
                  ),
                if (onImport != null)
                  OutlinedButton.icon(
                    key: const ValueKey<String>('vpn-profile-manager-import'),
                    onPressed: () => unawaited(onImport!()),
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Import'),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (visibleProfiles.isEmpty)
              _EmptyTransportProfileList(requiredKinds: requiredKinds)
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: _desktop ? 460 : 420),
                child: SingleChildScrollView(
                  child: Column(
                    children: visibleProfiles
                        .map(
                          (TransportProfileStatus profile) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TransportProfileManagerRow(
                              profile: profile,
                              selected: _selectedForPlan(profile),
                              selectable: _selectable(profile),
                              onEdit:
                                  onEdit == null ||
                                      !profile.actions.contains(
                                        TransportProfileLifecycleAction
                                            .updateStructured,
                                      )
                                  ? null
                                  : () => onEdit!(profile),
                              onValidate:
                                  onValidate == null ||
                                      !profile.actions.contains(
                                        TransportProfileLifecycleAction
                                            .validate,
                                      )
                                  ? null
                                  : () => onValidate!(profile),
                              onForget:
                                  onForget == null ||
                                      !profile.actions.contains(
                                        TransportProfileLifecycleAction.forget,
                                      )
                                  ? null
                                  : () => onForget!(profile),
                              onSelect: onSelect == null
                                  ? null
                                  : () => onSelect!(profile),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<TransportProfileStatus> _visibleProfiles() {
    final out = profiles
        .where((TransportProfileStatus profile) {
          return requiredKinds.isEmpty || requiredKinds.contains(profile.kind);
        })
        .toList(growable: false);
    out.sort((left, right) {
      final selectedCompare = _selectedForPlan(
        right,
      ).toString().compareTo(_selectedForPlan(left).toString());
      if (selectedCompare != 0) {
        return selectedCompare;
      }
      final compatibilityCompare = right.compatibility.state.value.compareTo(
        left.compatibility.state.value,
      );
      if (compatibilityCompare != 0) {
        return compatibilityCompare;
      }
      return left.displayName.compareTo(right.displayName);
    });
    return out;
  }

  bool _selectable(TransportProfileStatus profile) {
    return executionPlan != null &&
        profile.actions.contains(
          TransportProfileLifecycleAction.selectForStartup,
        ) &&
        profile.compatibility.state ==
            TransportProfileCompatibilityState.compatible &&
        (requiredKinds.isEmpty || requiredKinds.contains(profile.kind));
  }

  bool _selectedForPlan(TransportProfileStatus profile) {
    if (executionPlan == null) {
      return false;
    }
    return profile.defaultFor.any(
      (TransportProfileDefaultBinding binding) =>
          _samePlan(binding.plan, executionPlan!),
    );
  }

  bool _samePlan(RuntimeExecutionPlan left, RuntimeExecutionPlan right) {
    return left.accessMethod == right.accessMethod &&
        left.carrierFamily == right.carrierFamily &&
        left.engineFamily == right.engineFamily &&
        left.hostAdapter == right.hostAdapter;
  }

  String _managerSubtitle() {
    if (requiredKinds.isEmpty) {
      return 'Host-owned transport material, redacted on ordinary reads.';
    }
    return 'Required kind: ${requiredKinds.map((kind) => kind.value).join(', ')}';
  }
}

class _EmptyTransportProfileList extends StatelessWidget {
  const _EmptyTransportProfileList({required this.requiredKinds});

  final List<TransportProfileKind> requiredKinds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: shellSurfaceDecoration(
        context,
        style: ShellSurfaceStyle.highlight,
        tone: ShellSemanticTone.attention,
      ),
      child: Text(
        requiredKinds.isEmpty
            ? 'No VPN transport profiles configured.'
            : 'No compatible VPN transport profiles configured.',
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}

class _TransportProfileManagerRow extends StatelessWidget {
  const _TransportProfileManagerRow({
    required this.profile,
    required this.selected,
    required this.selectable,
    this.onEdit,
    this.onValidate,
    this.onForget,
    this.onSelect,
  });

  final TransportProfileStatus profile;
  final bool selected;
  final bool selectable;
  final Future<void> Function()? onEdit;
  final Future<void> Function()? onValidate;
  final Future<void> Function()? onForget;
  final Future<void> Function()? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = firstNonEmpty(profile.displayName, profile.kind.value);
    final status = _profileStatusText();
    return Container(
      key: ValueKey<String>('vpn-profile-manager-row-${profile.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: shellSurfaceDecoration(
        context,
        style: ShellSurfaceStyle.highlight,
        tone: selected
            ? ShellSemanticTone.ready
            : profile.isUsable
            ? ShellSemanticTone.info
            : ShellSemanticTone.attention,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ShellToneBadge(
                label: selected ? 'Selected' : profile.kind.value,
                tone: selected
                    ? ShellSemanticTone.ready
                    : ShellSemanticTone.info,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (onSelect != null)
                FilledButton.tonalIcon(
                  key: ValueKey<String>(
                    'vpn-profile-manager-select-${profile.id}',
                  ),
                  onPressed: selectable && !selected
                      ? () => unawaited(onSelect!())
                      : null,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Select'),
                ),
              if (onEdit != null)
                OutlinedButton.icon(
                  key: ValueKey<String>(
                    'vpn-profile-manager-edit-${profile.id}',
                  ),
                  onPressed: () => unawaited(onEdit!()),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit'),
                ),
              if (onValidate != null)
                OutlinedButton.icon(
                  key: ValueKey<String>(
                    'vpn-profile-manager-validate-${profile.id}',
                  ),
                  onPressed: () => unawaited(onValidate!()),
                  icon: const Icon(Icons.fact_check_rounded),
                  label: const Text('Validate'),
                ),
              if (onForget != null)
                TextButton.icon(
                  key: ValueKey<String>(
                    'vpn-profile-manager-forget-${profile.id}',
                  ),
                  onPressed: () => unawaited(onForget!()),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Forget'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _profileStatusText() {
    final validation = profile.validation.state.value;
    final compatibility = profile.compatibility.state.value;
    if (profile.validation.message.trim().isNotEmpty) {
      return '$validation / $compatibility: ${profile.validation.message.trim()}';
    }
    if (profile.compatibility.message.trim().isNotEmpty) {
      return '$validation / $compatibility: ${profile.compatibility.message.trim()}';
    }
    return '$validation / $compatibility';
  }
}

String firstNonEmpty(String first, String second) {
  if (first.trim().isNotEmpty) {
    return first.trim();
  }
  return second.trim();
}
