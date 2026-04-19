import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter_shell_core/portable_profile_transfer.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/profile_draft.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ProfileEditorPanel extends StatefulWidget {
  ProfileEditorPanel({
    super.key,
    required this.profiles,
    required this.providerDescriptors,
    required this.selectedProfileId,
    required this.draft,
    required this.busy,
    required this.onSelectProfile,
    required this.onDraftChanged,
    required this.onSave,
    required this.onDelete,
    required this.onReset,
    required this.onResolve,
    required this.onStart,
    required this.onPreparePortableExport,
    required this.onCopyPortableExportText,
    required this.onSharePortableExportText,
    required this.onSharePortableExportFile,
    required this.onImportPortableFromFile,
    required this.onPreviewPortableImport,
    required this.onConfirmPortableImport,
    this.pendingPortableImportEnvelope,
    this.onPendingPortableImportHandled,
    List<ManagedProviderRecord>? managedProviders,
    String? initialManagedProviderId,
    void Function({String? managedProviderId})? onActivateManagedProviderMode,
    VoidCallback? onUseCustomProvider,
    List<ProviderConfigRecord>? availableProviderConfigs,
    ValueChanged<String>? onApplyProviderConfig,
    this.showTitleBar = true,
    this.showSavedProfilesSection = true,
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

  final List<ProfileRecord> profiles;
  final List<ProviderDescriptor> providerDescriptors;
  final List<ManagedProviderRecord> managedProviders;
  final String? selectedManagedProviderId;
  final String? selectedProfileId;
  final ProfileDraft draft;
  final bool busy;
  final ValueChanged<String> onSelectProfile;
  final ValueChanged<ProfileDraft> onDraftChanged;
  final void Function({String? managedProviderId})
  onActivateManagedProviderMode;
  final VoidCallback onUseCustomProvider;
  final bool showTitleBar;
  final bool showSavedProfilesSection;
  final Future<void> Function() onSave;
  final Future<void> Function() onDelete;
  final VoidCallback onReset;
  final Future<void> Function() onResolve;
  final Future<void> Function() onStart;
  final PortableProfileEnvelope? Function() onPreparePortableExport;
  final Future<void> Function(PortableProfileEnvelope envelope)
  onCopyPortableExportText;
  final Future<void> Function(PortableProfileEnvelope envelope)
  onSharePortableExportText;
  final Future<void> Function(PortableProfileEnvelope envelope)
  onSharePortableExportFile;
  final Future<PortableProfileEnvelope?> Function() onImportPortableFromFile;
  final PortableProfileEnvelope? Function(String payload)
  onPreviewPortableImport;
  final Future<void> Function(PortableProfileEnvelope envelope)
  onConfirmPortableImport;
  final PortableProfileEnvelope? pendingPortableImportEnvelope;
  final VoidCallback? onPendingPortableImportHandled;

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
  FocusNode? _nameFocusNode;
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
  String? _selectedManagedProviderId;
  String? _autoPreviewSignature;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _nameFocusNode = FocusNode();
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
    _schedulePendingPortableImportPreview();
  }

  @override
  void didUpdateWidget(covariant ProfileEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft != widget.draft) {
      _syncFromDraft();
    }
    if (widget.pendingPortableImportEnvelope == null) {
      _autoPreviewSignature = null;
      return;
    }
    if (oldWidget.pendingPortableImportEnvelope !=
        widget.pendingPortableImportEnvelope) {
      _schedulePendingPortableImportPreview();
    }
  }

  void _schedulePendingPortableImportPreview() {
    final envelope = widget.pendingPortableImportEnvelope;
    if (envelope == null) {
      _autoPreviewSignature = null;
      return;
    }
    final signature = envelope.encode();
    if (_autoPreviewSignature == signature) {
      return;
    }
    _autoPreviewSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onPendingPortableImportHandled?.call();
      unawaited(_showPortableImportPreview(envelope));
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode?.dispose();
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

  Future<void> _showPortableExportDialog() async {
    final envelope = widget.onPreparePortableExport();
    if (envelope == null || !mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final copy = context.shellText;
        return AlertDialog(
          title: Text(copy.exportPortableProfile),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    envelope.displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    copy.providerAndSource(
                      provider: envelope.profile.spec.provider,
                      source: envelope.providerBinding.mode.value,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (envelope.isSecretBearing)
                    _warningBanner(
                      context,
                      copy.portableExportSecretWarningMobile,
                    ),
                  if (!envelope.isSecretBearing)
                    Text(
                      copy.portableExportSeparateFromRuntimeMobile,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 12),
                  if (envelope.fitsQrBounds) ...<Widget>[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: QrImageView(
                          data: envelope.encode(),
                          version: QrVersions.auto,
                          size: 220,
                          gapless: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      copy.portableQrCompactJson,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ] else ...<Widget>[
                    _warningBanner(
                      context,
                      copy.portableQrUnavailableMobile(
                        envelope.encodedUtf8Bytes,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(copy.close),
            ),
            TextButton(
              onPressed: () =>
                  unawaited(widget.onCopyPortableExportText(envelope)),
              child: Text(copy.copyText),
            ),
            FilledButton.tonal(
              onPressed: () =>
                  unawaited(widget.onSharePortableExportText(envelope)),
              child: Text(copy.shareText),
            ),
            FilledButton(
              onPressed: () =>
                  unawaited(widget.onSharePortableExportFile(envelope)),
              child: Text(copy.shareFile),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importPortableFromFile() async {
    final envelope = await widget.onImportPortableFromFile();
    if (envelope == null || !mounted) {
      return;
    }
    await _showPortableImportPreview(envelope);
  }

  Future<void> _scanPortableQr() async {
    final payload = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext context) => const _PortableQrScannerPage(),
      ),
    );
    if (payload == null || payload.trim().isEmpty || !mounted) {
      return;
    }
    final envelope = widget.onPreviewPortableImport(payload);
    if (envelope == null || !mounted) {
      return;
    }
    await _showPortableImportPreview(envelope);
  }

  Future<void> _showPortableImportPreview(
    PortableProfileEnvelope envelope,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final copy = context.shellText;
        final snapshotName =
            envelope.managedProviderSnapshot?.name.isNotEmpty == true
            ? envelope.managedProviderSnapshot!.name
            : envelope.managedProviderSnapshot?.id ?? copy.missing;
        return AlertDialog(
          title: Text(copy.importPortableProfile),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    envelope.displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(copy.providerLabel(envelope.profile.spec.provider)),
                  Text(
                    copy.sourceModeLabel(envelope.providerBinding.mode.value),
                  ),
                  if (envelope.providerBinding.isManaged)
                    Text(copy.managedProviderSnapshot(snapshotName)),
                  const SizedBox(height: 12),
                  if (envelope.isSecretBearing)
                    _warningBanner(context, copy.portableImportSecretWarning),
                  if (!envelope.isSecretBearing)
                    Text(
                      copy.portableImportCreatesFreshIdsMobile,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(copy.cancel),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await widget.onConfirmPortableImport(envelope);
              },
              child: Text(copy.importProfile),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPortablePasteDialog() async {
    final controller = TextEditingController();
    String? errorText;
    PortableProfileEnvelope? previewEnvelope;
    try {
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          final copy = context.shellText;
          return StatefulBuilder(
            builder:
                (
                  BuildContext context,
                  void Function(VoidCallback fn) setState,
                ) {
                  final keyboardVisible =
                      MediaQuery.viewInsetsOf(context).bottom > 0;
                  return AlertDialog(
                    scrollable: true,
                    title: Text(copy.pastePortableProfileEnvelope),
                    content: SizedBox(
                      width: 520,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          TextField(
                            controller: controller,
                            keyboardType: TextInputType.multiline,
                            minLines: keyboardVisible ? 4 : 8,
                            maxLines: keyboardVisible ? 10 : 16,
                            decoration: InputDecoration(
                              labelText: copy.portableProfileJson,
                              errorText: errorText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            copy.previewOpensBeforeRecordsCreated,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(copy.cancel),
                      ),
                      FilledButton(
                        onPressed: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          final envelope = widget.onPreviewPortableImport(
                            controller.text,
                          );
                          if (envelope == null) {
                            setState(() {
                              errorText = copy.payloadInvalidOrUnsupported;
                            });
                            return;
                          }
                          previewEnvelope = envelope;
                          Navigator.of(context).pop();
                        },
                        child: Text(copy.previewImport),
                      ),
                    ],
                  );
                },
          );
        },
      );
      if (previewEnvelope != null && mounted) {
        await _showPortableImportPreview(previewEnvelope!);
      }
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = context.shellText;
    final descriptor = _selectedDescriptor();
    final managedMode = widget.draft.providerBinding.isManaged;
    final hasSavedProfile = widget.selectedProfileId != null;
    final primaryLabel = hasSavedProfile
        ? copy.startSavedProfile
        : copy.resolveInvite;
    final Future<void> Function() primaryAction = hasSavedProfile
        ? widget.onStart
        : widget.onResolve;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (widget.showTitleBar) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      copy.mobileProfilesTitleBar,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: widget.busy ? null : widget.onReset,
                    child: Text(copy.newItem),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (widget.showSavedProfilesSection) ...<Widget>[
              _savedProfilesSection(theme),
              const SizedBox(height: 16),
            ],
            _field(
              fieldKey: const ValueKey<String>('profile-editor-name-field'),
              controller: _nameController,
              focusNode: _nameFocusNode,
              label: copy.profileName,
              onChanged: (String value) => _pushDraft(name: value),
            ),
            _providerModeCard(theme, managedMode),
            _providerField(),
            _field(
              fieldKey: const ValueKey<String>('profile-editor-link-field'),
              controller: _linkController,
              label: _providerLinkLabel(context, descriptor),
              maxLines: 3,
              onChanged: (String value) => _pushDraft(
                spec: widget.draft.spec.copyWith(link: value.trim()),
              ),
            ),
            if (descriptor != null) ...<Widget>[
              _disclosureSection(
                title: copy.mobileProviderDetails,
                subtitle: copy.mobileProviderDetailsSubtitle,
                initiallyExpanded: false,
                children: <Widget>[
                  _providerDescriptorCard(theme, descriptor),
                  const SizedBox(height: 12),
                  _providerFlowCard(theme, descriptor),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (descriptor?.settingsSchema != null) ...<Widget>[
              _disclosureSection(
                title: copy.mobileProviderSettingsSection,
                subtitle: descriptor!.providerSettingsSupportError != null
                    ? copy.mobileProviderSettingsUnsupportedSubtitle
                    : copy.mobileProviderSettingsRetainedSubtitle,
                initiallyExpanded:
                    descriptor.providerSettingsSupportError != null,
                children: _providerSettingsSection(theme, descriptor),
              ),
              const SizedBox(height: 12),
            ],
            _disclosureSection(
              title: copy.mobileAdvancedRuntimeControls,
              subtitle: copy.mobileAdvancedRuntimeControlsSubtitle,
              initiallyExpanded: false,
              children: _advancedRuntimeSection(context),
            ),
            const SizedBox(height: 12),
            _disclosureSection(
              title: copy.mobilePortableTransfer,
              subtitle: copy.mobilePortableTransferSubtitle,
              sectionKey: const ValueKey<String>(
                'profile-editor-portable-transfer-section',
              ),
              initiallyExpanded: false,
              children: <Widget>[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    FilledButton.tonal(
                      key: const ValueKey<String>(
                        'profile-editor-portable-export-action',
                      ),
                      onPressed: widget.busy || !hasSavedProfile
                          ? null
                          : () => unawaited(_showPortableExportDialog()),
                      child: Text(copy.exportSavedProfile),
                    ),
                    OutlinedButton(
                      key: const ValueKey<String>(
                        'profile-editor-portable-import-file-action',
                      ),
                      onPressed: widget.busy
                          ? null
                          : () => unawaited(_importPortableFromFile()),
                      child: Text(copy.importFromFile),
                    ),
                    OutlinedButton(
                      key: const ValueKey<String>(
                        'profile-editor-portable-import-qr-action',
                      ),
                      onPressed: widget.busy
                          ? null
                          : () => unawaited(_scanPortableQr()),
                      child: Text(copy.scanPortableProfileQr),
                    ),
                    OutlinedButton(
                      key: const ValueKey<String>(
                        'profile-editor-portable-import-paste-action',
                      ),
                      onPressed: widget.busy
                          ? null
                          : () => unawaited(_showPortablePasteDialog()),
                      child: Text(copy.pasteEnvelope),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _footerActionBar(
              primaryLabel: primaryLabel,
              onPrimaryPressed: widget.busy
                  ? null
                  : () => unawaited(primaryAction.call()),
              onSavePressed: widget.busy
                  ? null
                  : () => unawaited(widget.onSave()),
              hasSavedProfile: hasSavedProfile,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    Key? fieldKey,
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
    FocusNode? focusNode,
    int maxLines = 1,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: fieldKey,
        controller: controller,
        focusNode: focusNode,
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

    final section = <Widget>[];

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
            context.shellText.mobileProviderSettingsSupportError(
              providerName: descriptor!.displayName,
              error: supportError,
            ),
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
      return section;
    }

    section.add(
      Text(
        context.shellText.mobileProviderSettingsRetainedHelp,
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

  List<Widget> _advancedRuntimeSection(BuildContext context) {
    return <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: _field(
              controller: _listenController,
              label: context.shellText.localUdpListen,
              onChanged: (String value) => _pushDraft(
                spec: widget.draft.spec.copyWith(listenAddress: value.trim()),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _field(
              controller: _peerController,
              label: context.shellText.peerAddress,
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
              label: context.shellText.connections,
              onChanged: (String value) => _pushDraft(
                spec: widget.draft.spec.copyWith(
                  connections: int.tryParse(value.trim()) ?? 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<TransportMode>(
                initialValue: widget.draft.spec.mode,
                decoration: InputDecoration(
                  labelText: context.shellText.turnMode,
                ),
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
                        _pushDraft(
                          spec: widget.draft.spec.copyWith(mode: mode),
                        );
                      },
              ),
            ),
          ),
        ],
      ),
      Row(
        children: <Widget>[
          Expanded(
            child: _field(
              controller: _turnServerController,
              label: context.shellText.turnOverride,
              onChanged: (String value) => _pushDraft(
                spec: widget.draft.spec.copyWith(turnServer: value.trim()),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _field(
              controller: _turnPortController,
              label: context.shellText.turnPort,
              onChanged: (String value) => _pushDraft(
                spec: widget.draft.spec.copyWith(turnPort: value.trim()),
              ),
            ),
          ),
        ],
      ),
      _field(
        controller: _bindInterfaceController,
        label: context.shellText.bindInterface,
        onChanged: (String value) => _pushDraft(
          spec: widget.draft.spec.copyWith(bindInterface: value.trim()),
        ),
      ),
      _field(
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

  Widget _savedProfilesSection(ThemeData theme) {
    if (widget.profiles.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          context.shellText.mobileNoSavedProfilesYetBuildDraft,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.shellText.mobileSavedProfiles,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: widget.profiles
              .map((ProfileRecord profile) {
                final label = profile.name.isEmpty ? profile.id : profile.name;
                return ChoiceChip(
                  selected: widget.selectedProfileId == profile.id,
                  label: Text(label),
                  onSelected: widget.busy
                      ? null
                      : (_) => widget.onSelectProfile(profile.id),
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _disclosureSection({
    Key? sectionKey,
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
          key: sectionKey,
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

  Widget _footerActionBar({
    required String primaryLabel,
    required VoidCallback? onPrimaryPressed,
    required VoidCallback? onSavePressed,
    required bool hasSavedProfile,
  }) {
    final theme = Theme.of(context);
    final copy = context.shellText;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final compact = constraints.maxWidth < 760;
        final saveButton = compact
            ? IconButton.filledTonal(
                key: const ValueKey<String>('profile-editor-save-action'),
                tooltip: copy.saveProfile,
                onPressed: onSavePressed,
                icon: const Icon(Icons.save_outlined),
              )
            : FilledButton.tonalIcon(
                key: const ValueKey<String>('profile-editor-save-action'),
                onPressed: onSavePressed,
                icon: const Icon(Icons.save_outlined),
                label: Text(copy.saveProfile),
              );
        final moreButton = hasSavedProfile
            ? PopupMenuButton<_ProfileEditorOverflowAction>(
                key: const ValueKey<String>('profile-editor-more-actions'),
                tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                enabled: !widget.busy,
                onSelected: (_ProfileEditorOverflowAction action) {
                  switch (action) {
                    case _ProfileEditorOverflowAction.resolve:
                      unawaited(widget.onResolve());
                    case _ProfileEditorOverflowAction.delete:
                      unawaited(widget.onDelete());
                  }
                },
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<_ProfileEditorOverflowAction>>[
                      PopupMenuItem<_ProfileEditorOverflowAction>(
                        key: const ValueKey<String>(
                          'profile-editor-resolve-action',
                        ),
                        value: _ProfileEditorOverflowAction.resolve,
                        child: Text(copy.resolveInvite),
                      ),
                      PopupMenuItem<_ProfileEditorOverflowAction>(
                        key: const ValueKey<String>(
                          'profile-editor-delete-action',
                        ),
                        value: _ProfileEditorOverflowAction.delete,
                        child: Text(copy.deleteProfile),
                      ),
                    ],
                icon: const Icon(Icons.more_horiz),
              )
            : null;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.16,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  key: const ValueKey<String>('profile-editor-primary-action'),
                  onPressed: onPrimaryPressed,
                  child: Text(primaryLabel),
                ),
              ),
              const SizedBox(width: 12),
              saveButton,
              if (moreButton != null) ...<Widget>[
                const SizedBox(width: 8),
                moreButton,
              ],
            ],
          ),
        );
      },
    );
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

  Widget _providerField() {
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
      fieldKey: const ValueKey<String>('profile-editor-provider-field'),
      controller: _providerController,
      label: t.commonProviders,
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
              _descriptorTag(copy.tagInput(descriptor.inputKind.value)),
              _descriptorTag(copy.tagAuth(descriptor.authPosture.label)),
              _descriptorTag(copy.tagBrowser(descriptor.browserPolicy.label)),
              for (final family in descriptor.artifactFamilies)
                _descriptorTag(copy.tagFamily(family.label)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _providerFlowCard(ThemeData theme, ProviderDescriptor? descriptor) {
    final message = switch (descriptor?.browserPolicy) {
      ProviderBrowserPolicy.externalRequired =>
        context.shellText.browserNeedsExternal,
      ProviderBrowserPolicy.embeddedAllowed =>
        context.shellText.browserAllowsEmbedded,
      _ => context.shellText.browserNotRequired,
    };
    final continuation = descriptor?.mayRequireBrowserContinuation == true
        ? context.shellText.browserContinuationMayAppear
        : context.shellText.browserContinuationNotAdvertised;

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

  String _providerLinkLabel(
    BuildContext context,
    ProviderDescriptor? descriptor,
  ) {
    if (descriptor == null) {
      return context.shellText.providerInput;
    }
    return switch (descriptor.inputKind) {
      ProviderInputKind.link => context.shellText.providerLink,
    };
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

  Widget _descriptorTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
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

  Widget _warningBanner(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE2DE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message, style: theme.textTheme.bodySmall),
    );
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
    _syncProviderSettingControllers(_selectedDescriptor());
  }

  void _syncControllerText(TextEditingController controller, String text) {
    if (controller.text == text) {
      return;
    }
    controller.value = controller.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
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

class _PortableQrScannerPage extends StatefulWidget {
  const _PortableQrScannerPage();

  @override
  State<_PortableQrScannerPage> createState() => _PortableQrScannerPageState();
}

class _PortableQrScannerPageState extends State<_PortableQrScannerPage> {
  late final MobileScannerController _controller;
  bool _handledDetection = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.shellText.scanPortableProfileQr)),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MobileScanner(
            controller: _controller,
            onDetect: (BarcodeCapture capture) {
              if (_handledDetection) {
                return;
              }
              for (final barcode in capture.barcodes) {
                final rawValue = barcode.rawValue?.trim() ?? '';
                if (rawValue.isEmpty) {
                  continue;
                }
                _handledDetection = true;
                Navigator.of(context).pop(rawValue);
                return;
              }
            },
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.64),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.shellText.pointCameraAtPortableProfileQr,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ProfileEditorOverflowAction { resolve, delete }
