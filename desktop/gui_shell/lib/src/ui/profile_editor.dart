import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter_shell_core/portable_profile_transfer.dart';
import 'package:flutter_shell_core/provider_settings_form.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/profile_draft.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
    required this.onPreparePortableExport,
    required this.onCopyPortableExportText,
    required this.onSavePortableExportFile,
    required this.onImportPortableFromFile,
    required this.onPreviewPortableImport,
    required this.onConfirmPortableImport,
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
  final PortableProfileEnvelope? Function() onPreparePortableExport;
  final Future<void> Function(PortableProfileEnvelope envelope)
  onCopyPortableExportText;
  final Future<void> Function(PortableProfileEnvelope envelope)
  onSavePortableExportFile;
  final Future<PortableProfileEnvelope?> Function() onImportPortableFromFile;
  final PortableProfileEnvelope? Function(String payload)
  onPreviewPortableImport;
  final Future<void> Function(PortableProfileEnvelope envelope)
  onConfirmPortableImport;

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
            width: 540,
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
                      copy.portableExportSecretWarningDesktop,
                    ),
                  if (!envelope.isSecretBearing)
                    Text(
                      copy.portableExportSeparateFromRuntimeDesktop,
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
                          size: 240,
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
                      copy.portableQrUnavailableDesktop(
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
            FilledButton.tonal(
              onPressed: () =>
                  unawaited(widget.onCopyPortableExportText(envelope)),
              child: Text(copy.copyText),
            ),
            FilledButton(
              onPressed: () =>
                  unawaited(widget.onSavePortableExportFile(envelope)),
              child: Text(copy.saveFile),
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
            width: 540,
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
                      copy.portableImportCreatesFreshIdsDesktop,
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
                  return AlertDialog(
                    title: Text(copy.pastePortableProfileEnvelope),
                    content: SizedBox(
                      width: 560,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          TextField(
                            controller: controller,
                            minLines: 8,
                            maxLines: 16,
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
                          final envelope = widget.onPreviewPortableImport(
                            controller.text,
                          );
                          if (envelope == null) {
                            setState(() {
                              errorText = copy.payloadInvalidOrUnsupported;
                            });
                            return;
                          }
                          Navigator.of(context).pop();
                          unawaited(_showPortableImportPreview(envelope));
                        },
                        child: Text(copy.previewImport),
                      ),
                    ],
                  );
                },
          );
        },
      );
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
    final selectedManagedProviderId = _resolvedManagedProviderId();
    final selectedManagedProvider = _managedProviderForId(
      selectedManagedProviderId,
    );
    final selectedManagedDescriptor = _descriptorForProviderId(
      selectedManagedProvider?.provider ?? widget.draft.spec.provider,
    );
    final profileScopeLabel = widget.selectedProfileId == null
        ? copy.desktopUnsavedDraft
        : copy.desktopSavedProfileWorkspace;

    return Card(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final stackHeader = constraints.maxWidth < 960;
          final twoPaneWorkspace = constraints.maxWidth >= 1020;
          final lowHeightWorkbench = constraints.maxHeight < 220;
          final headerActions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton(
                key: const ValueKey<String>('profile-resolve-action'),
                onPressed: widget.busy
                    ? null
                    : () => unawaited(widget.onResolve()),
                child: Text(_nextStepTitle(context, descriptor)),
              ),
              Tooltip(
                message: widget.selectedProfileId == null
                    ? copy.desktopSaveProfileFirst
                    : copy.desktopStartSessionFromSavedProfile,
                child: FilledButton.tonal(
                  key: const ValueKey<String>('profile-start-action'),
                  onPressed: widget.busy || widget.selectedProfileId == null
                      ? null
                      : () => unawaited(widget.onStart()),
                  child: Text(copy.startSession),
                ),
              ),
              FilledButton.tonal(
                key: const ValueKey<String>('profile-save-action'),
                onPressed: widget.busy
                    ? null
                    : () => unawaited(widget.onSave()),
                child: Text(copy.saveProfile),
              ),
              FilledButton.tonalIcon(
                onPressed: widget.busy ? null : widget.onReset,
                icon: const Icon(Icons.add),
                label: Text(copy.freshDraft),
              ),
            ],
          );
          if (lowHeightWorkbench) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                primary: false,
                children: <Widget>[
                  Text(
                    copy.desktopProfileWorkspaceTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profileScopeLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  headerActions,
                  const SizedBox(height: 12),
                  ..._primaryWorkspaceChildren(
                    theme,
                    descriptor,
                    managedMode,
                    selectedManagedProvider,
                    selectedManagedDescriptor,
                    twoPaneLayout: false,
                  ),
                  ..._secondaryWorkspaceChildren(
                    theme,
                    descriptor,
                    managedMode,
                    selectedManagedProviderId,
                  ),
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (stackHeader)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        copy.desktopProfileWorkspaceTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profileScopeLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
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
                              copy.desktopProfileWorkspaceTitle,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              profileScopeLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(child: headerActions),
                    ],
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    key: const ValueKey<String>('profile-workspace-scroll'),
                    primary: true,
                    children: twoPaneWorkspace
                        ? <Widget>[
                            Align(
                              alignment: Alignment.topLeft,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1220,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: _primaryWorkspaceChildren(
                                          theme,
                                          descriptor,
                                          managedMode,
                                          selectedManagedProvider,
                                          selectedManagedDescriptor,
                                          twoPaneLayout: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    SizedBox(
                                      width: 280,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: _secondaryWorkspaceChildren(
                                          theme,
                                          descriptor,
                                          managedMode,
                                          selectedManagedProviderId,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ]
                        : <Widget>[
                            ..._primaryWorkspaceChildren(
                              theme,
                              descriptor,
                              managedMode,
                              selectedManagedProvider,
                              selectedManagedDescriptor,
                              twoPaneLayout: false,
                            ),
                            ..._secondaryWorkspaceChildren(
                              theme,
                              descriptor,
                              managedMode,
                              selectedManagedProviderId,
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

  Widget _providerDescriptorCard(
    ThemeData theme,
    ProviderDescriptor descriptor,
  ) {
    final copy = context.shellText;
    return Container(
      key: const ValueKey<String>('profile-provider-descriptor-card'),
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
              _workflowTag(copy.tagInput(descriptor.inputKind.value)),
              _workflowTag(copy.tagAuth(descriptor.authPosture.label)),
              _workflowTag(copy.tagBrowser(descriptor.browserPolicy.label)),
              for (final family in descriptor.artifactFamilies)
                _workflowTag(copy.tagFamily(family.label)),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _primaryWorkspaceChildren(
    ThemeData theme,
    ProviderDescriptor? descriptor,
    bool managedMode,
    ManagedProviderRecord? selectedManagedProvider,
    ProviderDescriptor? selectedManagedDescriptor, {
    required bool twoPaneLayout,
  }) {
    final settingsCard = _providerSettingsCard(theme, descriptor);
    return <Widget>[
      _identityStrip(theme),
      const SizedBox(height: 10),
      _primarySectionCard(
        theme,
        title: context.shellText.desktopProfileSettings,
        child: _mainSettingsSection(
          context,
          theme,
          descriptor,
          managedMode: managedMode,
          selectedManagedProvider: selectedManagedProvider,
          selectedManagedDescriptor: selectedManagedDescriptor,
          sideBySide: twoPaneLayout,
        ),
      ),
      if (settingsCard != null) ...<Widget>[
        const SizedBox(height: 10),
        settingsCard,
      ],
    ];
  }

  List<Widget> _secondaryWorkspaceChildren(
    ThemeData theme,
    ProviderDescriptor? descriptor,
    bool managedMode,
    String? selectedManagedProviderId,
  ) {
    final children = <Widget>[
      _secondarySectionCard(
        theme,
        title: context.shellText.desktopChangeSource,
        subtitle: context.shellText.desktopChangeSourceSubtitle,
        child: _providerModeCard(
          theme,
          managedMode,
          selectedManagedProviderId: selectedManagedProviderId,
        ),
      ),
      const SizedBox(height: 12),
      _providerFlowCard(theme, descriptor),
    ];
    if (!managedMode && descriptor != null) {
      children.add(const SizedBox(height: 12));
      children.add(_providerDescriptorCard(theme, descriptor));
    }
    children.add(const SizedBox(height: 12));
    children.add(_portableTransferCard(theme));
    children.add(const SizedBox(height: 12));
    children.add(_supportActionsCard(theme));
    return children;
  }

  Widget _identityStrip(ThemeData theme) {
    return _field(
      key: const ValueKey<String>('profile-name-field'),
      controller: _nameController,
      label: context.shellText.profileName,
      onChanged: (String value) => _pushDraft(name: value),
    );
  }

  Widget _mainSettingsSection(
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
        _readOnlyField(
          context: context,
          key: const ValueKey<String>('profile-provider-record-field'),
          label: context.shellText.desktopProviderRecord,
          value: recordName,
        ),
      );
    }
    providerFields.add(
      _providerFamilyField(
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
        _field(
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
        ..._runtimeDefaultsFields(context),
      ],
    );
  }

  Widget _primarySectionCard(
    ThemeData theme, {
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.22,
        ),
        borderRadius: BorderRadius.circular(18),
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _supportActionsCard(ThemeData theme) {
    return _secondarySectionCard(
      theme,
      title: context.shellText.desktopProfileMaintenance,
      subtitle: context.shellText.desktopProfileMaintenanceSubtitle,
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8),
        title: Text(context.shellText.desktopShowMaintenanceActions),
        subtitle: Text(context.shellText.desktopDeleteSavedProfileHint),
        children: <Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              OutlinedButton(
                key: const ValueKey<String>('profile-delete-action'),
                onPressed: widget.busy || widget.selectedProfileId == null
                    ? null
                    : () => unawaited(widget.onDelete()),
                child: Text(context.shellText.delete),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _portableTransferCard(ThemeData theme) {
    return _secondarySectionCard(
      theme,
      title: context.shellText.mobilePortableTransfer,
      subtitle: context.shellText.desktopPortableTransferSubtitle,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: <Widget>[
          FilledButton.tonal(
            key: const ValueKey<String>('profile-portable-export-action'),
            onPressed: widget.busy || widget.selectedProfileId == null
                ? null
                : () => unawaited(_showPortableExportDialog()),
            child: Text(context.shellText.exportSavedProfile),
          ),
          OutlinedButton(
            key: const ValueKey<String>('profile-portable-import-file-action'),
            onPressed: widget.busy
                ? null
                : () => unawaited(_importPortableFromFile()),
            child: Text(context.shellText.importFromFile),
          ),
          OutlinedButton(
            key: const ValueKey<String>('profile-portable-import-paste-action'),
            onPressed: widget.busy
                ? null
                : () => unawaited(_showPortablePasteDialog()),
            child: Text(context.shellText.pasteEnvelope),
          ),
        ],
      ),
    );
  }

  Widget _secondarySectionCard(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(16),
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
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _providerFamilyField({
    required ProviderDescriptor? descriptor,
    required bool managedMode,
  }) {
    if (managedMode) {
      return _readOnlyField(
        context: context,
        key: const ValueKey<String>('profile-managed-provider-family'),
        label: context.shellText.providerFamily,
        value: _providerFamilyValue(descriptor),
      );
    }
    return _field(
      controller: _providerController,
      label: context.shellText.providerFamily,
      onChanged: (String value) =>
          _pushDraft(spec: widget.draft.spec.copyWith(provider: value.trim())),
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

    return _secondarySectionCard(
      theme,
      title: context.shellText.desktopBrowserHandling,
      subtitle: context.shellText.desktopBrowserHandlingSubtitle,
      child: Text('$message $continuation', style: theme.textTheme.bodySmall),
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

  String _providerFamilyValue(ProviderDescriptor? descriptor) {
    final displayName = descriptor?.displayName.trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName;
    }
    return widget.draft.spec.provider.trim();
  }

  String _nextStepTitle(BuildContext context, ProviderDescriptor? descriptor) {
    if (descriptor?.mayRequireBrowserContinuation == true &&
        widget.draft.spec.link.trim().isNotEmpty) {
      return context.shellText.resolveInvite;
    }
    return context.shellText.resolveProfile;
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

  Widget _readOnlyField({
    required BuildContext context,
    Key? key,
    required String label,
    required String value,
  }) {
    final displayValue = value.trim().isEmpty
        ? context.shellText.notSet
        : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        key: key,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        child: Text(displayValue),
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

  Widget? _providerSettingsCard(
    ThemeData theme,
    ProviderDescriptor? descriptor,
  ) {
    final schema = descriptor?.settingsSchema;
    if (schema == null) {
      return null;
    }

    final supportError = descriptor?.providerSettingsSupportError;
    if (supportError != null) {
      return _primarySectionCard(
        theme,
        title: context.shellText.desktopProfileProviderSettings,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE2DE),
            borderRadius: BorderRadius.circular(14),
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

    return _primarySectionCard(
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
            onChanged: (Map<String, dynamic> values) {
              _pushDraft(
                spec: widget.draft.spec.copyWith(providerSettings: values),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _runtimeDefaultsFields(BuildContext context) {
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

  void _pushDraft({String? name, ProfileSpec? spec}) {
    widget.onDraftChanged(
      widget.draft.copyWith(
        name: name ?? widget.draft.name,
        spec: spec ?? widget.draft.spec,
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

  Widget _providerModeCard(
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
}
