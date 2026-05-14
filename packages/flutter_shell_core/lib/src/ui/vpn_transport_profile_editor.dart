import 'dart:async';

import 'package:flutter/material.dart';

import '../control/runtime_execution_planning.dart';
import 'shell_visuals.dart';

enum VPNTransportProfileEditorVariant { mobile, desktop }

enum VPNTransportProfileEditorMode { create, edit }

enum VPNTransportProfileSurfaceLayout { modal, page }

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
    this.layout = VPNTransportProfileSurfaceLayout.modal,
    this.contentPadding,
    this.maxWidth,
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
  final VPNTransportProfileSurfaceLayout layout;
  final EdgeInsetsGeometry? contentPadding;
  final double? maxWidth;

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

  bool get _page => widget.layout == VPNTransportProfileSurfaceLayout.page;

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
    final content = SingleChildScrollView(
      child: Padding(
        padding:
            widget.contentPadding ??
            EdgeInsets.all(_page ? 0 : (_desktop ? 24 : 18)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!_page) ...<Widget>[
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
            ],
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
                  (TransportProfileStructuredFieldDescriptor field) => Padding(
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
    );
    final maxWidth = widget.maxWidth ?? (_page ? null : (_desktop ? 660 : 560));
    if (maxWidth == null) {
      return content;
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: content,
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
    if (field.secret) {
      return '';
    }
    final draftValue = _initialDraftValueFor(field);
    if (field.id == TransportProfileStructuredFieldId.displayName) {
      return firstNonEmpty(
        firstNonEmpty(
          widget.existingProfile?.displayName.trim() ?? '',
          _initialTextForDraftValue(draftValue),
        ),
        firstNonEmpty(field.defaultString, _kindLabel(widget.schema.kind)),
      );
    }
    final draftText = _initialTextForDraftValue(draftValue);
    if (widget.mode == VPNTransportProfileEditorMode.edit &&
        draftText.isNotEmpty) {
      return draftText;
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

  Object? _initialDraftValueFor(
    TransportProfileStructuredFieldDescriptor field,
  ) {
    final draft = widget.existingProfile?.structuredDraft;
    if (draft == null) {
      return null;
    }
    if (draft.fields.containsKey(field.id)) {
      return draft.fields[field.id];
    }
    return switch (field.id) {
      TransportProfileStructuredFieldId.displayName => draft.displayName,
      TransportProfileStructuredFieldId.interfaceAddresses =>
        draft.interfaceAddresses,
      TransportProfileStructuredFieldId.dnsServers => draft.dnsServers,
      TransportProfileStructuredFieldId.mtu => draft.mtu,
      TransportProfileStructuredFieldId.peerPublicKey => draft.peerPublicKey,
      TransportProfileStructuredFieldId.allowedIps => draft.allowedIps,
      TransportProfileStructuredFieldId.endpoint => draft.endpoint,
      TransportProfileStructuredFieldId.persistentKeepalive =>
        draft.persistentKeepaliveSeconds,
      _ => null,
    };
  }

  String _initialTextForDraftValue(Object? value) {
    if (value is String) {
      return value.trim();
    }
    if (value is int) {
      return value == 0 ? '' : '$value';
    }
    if (value is Iterable<String>) {
      return value
          .map((String item) => item.trim())
          .where((String item) => item.isNotEmpty)
          .join('\n');
    }
    if (value is Iterable<dynamic>) {
      return value
          .whereType<String>()
          .map((String item) => item.trim())
          .where((String item) => item.isNotEmpty)
          .join('\n');
    }
    return '';
  }

  TransportProfileSecretUpdateAction _initialSecretActionFor(
    TransportProfileStructuredFieldDescriptor field,
  ) {
    final actions = field.secretUpdateActions;
    final draftAction = _initialDraftSecretActionFor(field);
    if (draftAction != null && actions.contains(draftAction)) {
      return draftAction;
    }
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

  TransportProfileSecretUpdateAction? _initialDraftSecretActionFor(
    TransportProfileStructuredFieldDescriptor field,
  ) {
    final draft = widget.existingProfile?.structuredDraft;
    if (draft == null) {
      return null;
    }
    final fieldAction = draft.secretActions[field.id];
    if (fieldAction != null) {
      return fieldAction;
    }
    return switch (field.id) {
      TransportProfileStructuredFieldId.interfacePrivateKey =>
        draft.interfacePrivateKeyAction,
      TransportProfileStructuredFieldId.peerPresharedKey =>
        draft.peerPresharedKeyAction,
      _ => null,
    };
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
    return _transportProfileKindLabel(kind);
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
    this.onImportPortable,
    this.onEdit,
    this.onValidate,
    this.onForget,
    this.onSelect,
    this.onExportPortable,
    this.onClose,
    this.layout = VPNTransportProfileSurfaceLayout.modal,
    this.contentPadding,
    this.maxWidth,
  });

  final VPNTransportProfileEditorVariant variant;
  final List<TransportProfileStatus> profiles;
  final List<TransportProfileKind> requiredKinds;
  final RuntimeExecutionPlan? executionPlan;
  final Future<void> Function()? onCreate;
  final Future<void> Function()? onImport;
  final Future<void> Function()? onImportPortable;
  final Future<void> Function(TransportProfileStatus profile)? onEdit;
  final Future<void> Function(TransportProfileStatus profile)? onValidate;
  final Future<void> Function(TransportProfileStatus profile)? onForget;
  final Future<void> Function(TransportProfileStatus profile)? onSelect;
  final Future<void> Function(TransportProfileStatus profile)? onExportPortable;
  final VoidCallback? onClose;
  final VPNTransportProfileSurfaceLayout layout;
  final EdgeInsetsGeometry? contentPadding;
  final double? maxWidth;

  bool get _desktop => variant == VPNTransportProfileEditorVariant.desktop;

  bool get _page => layout == VPNTransportProfileSurfaceLayout.page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleProfiles = _visibleProfiles();
    final rows = visibleProfiles
        .map(
          (TransportProfileStatus profile) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TransportProfileManagerRow(
              variant: variant,
              pageLayout: _page,
              profile: profile,
              selected: _selectedForPlan(profile),
              selectable: _selectable(profile),
              kindLabel: _kindLabel(profile.kind),
              onEdit:
                  onEdit == null ||
                      !profile.actions.contains(
                        TransportProfileLifecycleAction.updateStructured,
                      )
                  ? null
                  : () => onEdit!(profile),
              onValidate:
                  onValidate == null ||
                      !profile.actions.contains(
                        TransportProfileLifecycleAction.validate,
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
              onSelect:
                  onSelect == null ||
                      !profile.actions.contains(
                        TransportProfileLifecycleAction.selectForStartup,
                      )
                  ? null
                  : () => onSelect!(profile),
              onExportPortable:
                  onExportPortable == null ||
                      !profile.actions.contains(
                        TransportProfileLifecycleAction.exportPortable,
                      )
                  ? null
                  : () => onExportPortable!(profile),
            ),
          ),
        )
        .toList(growable: false);
    final content = Padding(
      padding:
          contentPadding ?? EdgeInsets.all(_page ? 0 : (_desktop ? 24 : 18)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!_page) ...<Widget>[
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
          ],
          if (!_page) const SizedBox(height: 14),
          _ManagerActionStrip(
            pageLayout: _page,
            requiredKinds: requiredKinds,
            kindLabelFor: _kindLabel,
            onCreate: onCreate,
            onImport: onImport,
            onImportPortable: onImportPortable,
          ),
          const SizedBox(height: 14),
          if (visibleProfiles.isEmpty)
            _EmptyTransportProfileList(requiredKinds: requiredKinds)
          else if (_page)
            Column(children: rows)
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: _desktop ? 460 : 420),
              child: SingleChildScrollView(child: Column(children: rows)),
            ),
        ],
      ),
    );
    final effectiveMaxWidth =
        maxWidth ?? (_page ? null : (_desktop ? 720 : 580));
    if (effectiveMaxWidth == null) {
      return content;
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
      child: content,
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
    return 'Required kind: ${requiredKinds.map(_kindLabel).join(', ')}';
  }

  String _kindLabel(TransportProfileKind kind) {
    return _transportProfileKindLabel(kind);
  }
}

class _ManagerActionStrip extends StatelessWidget {
  const _ManagerActionStrip({
    required this.pageLayout,
    required this.requiredKinds,
    required this.kindLabelFor,
    this.onCreate,
    this.onImport,
    this.onImportPortable,
  });

  final bool pageLayout;
  final List<TransportProfileKind> requiredKinds;
  final String Function(TransportProfileKind kind) kindLabelFor;
  final Future<void> Function()? onCreate;
  final Future<void> Function()? onImport;
  final Future<void> Function()? onImportPortable;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
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
      if (onImportPortable != null)
        OutlinedButton.icon(
          key: const ValueKey<String>('vpn-profile-manager-import-portable'),
          onPressed: () => unawaited(onImportPortable!()),
          icon: const Icon(Icons.qr_code_rounded),
          label: const Text('Import portable'),
        ),
    ];
    if (!pageLayout) {
      return Wrap(spacing: 8, runSpacing: 8, children: actions);
    }
    final filter = ShellToneBadge(
      label: _requiredKindsLabel(),
      icon: Icons.filter_alt_rounded,
      tone: ShellSemanticTone.info,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final actionWrap = Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: actions,
        );
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              filter,
              if (actions.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                actionWrap,
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: filter),
            ),
            if (actions.isNotEmpty) actionWrap,
          ],
        );
      },
    );
  }

  String _requiredKindsLabel() {
    if (requiredKinds.isEmpty) {
      return 'All transport profiles';
    }
    if (requiredKinds.length == 1) {
      return '${kindLabelFor(requiredKinds.single)} required';
    }
    return '${requiredKinds.map(kindLabelFor).join(', ')} required';
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
    required this.variant,
    required this.pageLayout,
    required this.profile,
    required this.selected,
    required this.selectable,
    required this.kindLabel,
    this.onEdit,
    this.onValidate,
    this.onForget,
    this.onSelect,
    this.onExportPortable,
  });

  final VPNTransportProfileEditorVariant variant;
  final bool pageLayout;
  final TransportProfileStatus profile;
  final bool selected;
  final bool selectable;
  final String kindLabel;
  final Future<void> Function()? onEdit;
  final Future<void> Function()? onValidate;
  final Future<void> Function()? onForget;
  final Future<void> Function()? onSelect;
  final Future<void> Function()? onExportPortable;

  bool get _compactActions =>
      pageLayout && variant == VPNTransportProfileEditorVariant.mobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = firstNonEmpty(profile.displayName, kindLabel);
    final status = _profileStatusText();
    return Container(
      key: ValueKey<String>('vpn-profile-manager-row-${profile.id}'),
      width: double.infinity,
      padding: EdgeInsets.all(pageLayout ? 16 : 12),
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
                label: selected ? 'Selected' : kindLabel,
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
          _buildActions(context),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final inlineActions = <Widget>[
      if (onSelect != null && !selected)
        FilledButton.tonalIcon(
          key: ValueKey<String>('vpn-profile-manager-select-${profile.id}'),
          onPressed: selectable ? () => unawaited(onSelect!()) : null,
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: const Text('Select'),
        ),
      if (onEdit != null)
        OutlinedButton.icon(
          key: ValueKey<String>('vpn-profile-manager-edit-${profile.id}'),
          onPressed: () => unawaited(onEdit!()),
          icon: const Icon(Icons.edit_rounded),
          label: const Text('Edit'),
        ),
    ];
    final overflowActions = <PopupMenuEntry<String>>[
      if (onExportPortable != null)
        PopupMenuItem<String>(
          key: ValueKey<String>('vpn-profile-manager-export-${profile.id}'),
          value: 'export',
          child: const Text('Export'),
        ),
      if (onValidate != null)
        PopupMenuItem<String>(
          key: ValueKey<String>('vpn-profile-manager-validate-${profile.id}'),
          value: 'validate',
          child: const Text('Validate'),
        ),
      if (onForget != null)
        PopupMenuItem<String>(
          key: ValueKey<String>('vpn-profile-manager-forget-${profile.id}'),
          value: 'forget',
          child: const Text('Forget'),
        ),
    ];
    if (_compactActions) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          ...inlineActions,
          if (overflowActions.isNotEmpty)
            PopupMenuButton<String>(
              key: ValueKey<String>('vpn-profile-manager-more-${profile.id}'),
              tooltip: 'More actions',
              icon: const Icon(Icons.more_horiz_rounded),
              itemBuilder: (BuildContext context) => overflowActions,
              onSelected: (String action) {
                if (action == 'export') {
                  unawaited(onExportPortable!());
                } else if (action == 'validate') {
                  unawaited(onValidate!());
                } else if (action == 'forget') {
                  unawaited(_confirmForget(context));
                }
              },
            ),
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        ...inlineActions,
        if (onExportPortable != null)
          OutlinedButton.icon(
            key: ValueKey<String>('vpn-profile-manager-export-${profile.id}'),
            onPressed: () => unawaited(onExportPortable!()),
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Export'),
          ),
        if (onValidate != null)
          OutlinedButton.icon(
            key: ValueKey<String>('vpn-profile-manager-validate-${profile.id}'),
            onPressed: () => unawaited(onValidate!()),
            icon: const Icon(Icons.fact_check_rounded),
            label: const Text('Validate'),
          ),
        if (onForget != null)
          TextButton.icon(
            key: ValueKey<String>('vpn-profile-manager-forget-${profile.id}'),
            onPressed: () => unawaited(_confirmForget(context)),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Forget'),
          ),
      ],
    );
  }

  Future<void> _confirmForget(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Forget VPN profile?'),
          content: Text(
            'Remove "${profile.displayName}" from saved VPN transport profiles.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Forget'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await onForget!();
    }
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

String _transportProfileKindLabel(TransportProfileKind kind) {
  if (kind == TransportProfileKind.wireGuardNativeV1) {
    return 'WireGuard';
  }
  return kind.value;
}
