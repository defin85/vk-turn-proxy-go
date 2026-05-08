import 'package:flutter/material.dart';
import 'package:flutter_shell_core/control_plane_models.dart';
import 'package:flutter_shell_core/transport_profile_portable_transfer.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:qr_flutter/qr_flutter.dart';

enum PortableTransportProfileImportSource { file, paste }

Future<String?> showPortableTransportProfilePassphraseDialog({
  required BuildContext context,
  required String title,
  required String actionLabel,
  String? errorText,
  String? message,
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return _PortableTransportProfilePassphraseDialog(
        title: title,
        actionLabel: actionLabel,
        errorText: errorText,
        message: message,
      );
    },
  );
}

Future<PortableTransportProfileImportSource?>
showPortableTransportProfileImportSourceDialog({
  required BuildContext context,
}) {
  return showDialog<PortableTransportProfileImportSource>(
    context: context,
    builder: (BuildContext context) {
      final copy = context.shellText;
      return AlertDialog(
        title: Text(copy.importPortableProfile),
        content: const Text(
          'Choose how to load the encrypted VPN transport-profile envelope into this desktop workspace.',
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>(
              'transport-profile-portable-import-source-cancel',
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(copy.cancel),
          ),
          TextButton(
            key: const ValueKey<String>(
              'transport-profile-portable-import-source-paste',
            ),
            onPressed: () => Navigator.of(
              context,
            ).pop(PortableTransportProfileImportSource.paste),
            child: Text(copy.pasteEnvelope),
          ),
          FilledButton(
            key: const ValueKey<String>(
              'transport-profile-portable-import-source-file',
            ),
            onPressed: () => Navigator.of(
              context,
            ).pop(PortableTransportProfileImportSource.file),
            child: Text(copy.importFromFile),
          ),
        ],
      );
    },
  );
}

Future<String?> showPortableTransportProfilePasteDialog({
  required BuildContext context,
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return const _PortableTransportProfilePasteDialog();
    },
  );
}

Future<void> showPortableTransportProfileExportDialog({
  required BuildContext context,
  required PortableTransportProfileEnvelopeCarriage carriage,
  required TransportProfilePortableTransferCapability capability,
  required Future<void> Function() onCopyText,
  required Future<void> Function() onSaveFile,
}) async {
  await showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      final copy = context.shellText;
      final kindLabel = _transportProfileKindLabel(carriage.profileKind);
      final displayName = _displayLabel(carriage.displayName, kindLabel);
      final canRenderQr = carriage.fitsQrBounds(capability);
      return AlertDialog(
        key: const ValueKey<String>('transport-profile-portable-export-dialog'),
        title: Text(copy.exportPortableProfile),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(kindLabel),
                const SizedBox(height: 12),
                _warningBanner(
                  context,
                  'This envelope contains host-owned VPN transport secrets. Treat it like a credential.',
                ),
                const SizedBox(height: 16),
                if (canRenderQr) ...<Widget>[
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: QrImageView(
                        data: carriage.envelope,
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
                    copy.portableQrUnavailableDesktop(carriage.encodedBytes),
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
          FilledButton.tonal(onPressed: onCopyText, child: Text(copy.copyText)),
          FilledButton(onPressed: onSaveFile, child: Text(copy.saveFile)),
        ],
      );
    },
  );
}

Future<void> showPortableTransportProfileImportPreviewDialog({
  required BuildContext context,
  required TransportProfilePortableTransferPreview preview,
  Future<void> Function()? onConfirm,
}) async {
  await showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      final copy = context.shellText;
      final kindLabel = _transportProfileKindLabel(preview.profileKind);
      final displayName = _displayLabel(preview.displayName, kindLabel);
      final resolvedDisplayName = preview.resolvedDisplayName.trim();
      final blockedMessage = _blockedReasonMessage(preview.blockedReason);
      final canConfirm =
          onConfirm != null &&
          preview.outcome ==
              TransportProfilePortableTransferPreviewOutcome.importable;
      final title = switch (preview.outcome) {
        TransportProfilePortableTransferPreviewOutcome.blocked =>
          'Portable import blocked',
        TransportProfilePortableTransferPreviewOutcome.alreadyPresent =>
          'Already on this device',
        TransportProfilePortableTransferPreviewOutcome.importable =>
          copy.importPortableProfile,
        _ => copy.importPortableProfile,
      };
      return AlertDialog(
        key: const ValueKey<String>(
          'transport-profile-portable-import-preview',
        ),
        title: Text(title),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (kindLabel.isNotEmpty) Text(kindLabel),
                if (preview.outcome ==
                    TransportProfilePortableTransferPreviewOutcome
                        .blocked) ...<Widget>[
                  const SizedBox(height: 12),
                  _warningBanner(context, blockedMessage),
                ],
                if (preview.outcome ==
                    TransportProfilePortableTransferPreviewOutcome
                        .alreadyPresent) ...<Widget>[
                  const SizedBox(height: 12),
                  _warningBanner(
                    context,
                    'An identical VPN transport profile is already stored on this device.',
                  ),
                ],
                if (preview.outcome ==
                    TransportProfilePortableTransferPreviewOutcome
                        .importable) ...<Widget>[
                  const SizedBox(height: 12),
                  _warningBanner(
                    context,
                    'Import creates a new local transport-profile record and does not auto-select it for startup.',
                  ),
                ],
                if (resolvedDisplayName.isNotEmpty &&
                    resolvedDisplayName != displayName) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    'Will be imported as "$resolvedDisplayName".',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if (preview.warnings.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  for (final warning in preview.warnings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _warningBanner(context, _warningMessage(warning)),
                    ),
                ],
                if (preview.compatibility != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    'Compatibility: ${preview.compatibility!.state.value}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (preview.compatibility!.message.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        preview.compatibility!.message.trim(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
                if (preview.existingProfiles.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    'Existing profiles',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final profile in preview.existingProfiles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        _existingProfileSummary(profile),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
                if (preview.selectionRequired) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    'You may still need to select an existing profile for startup after this review.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(canConfirm ? copy.cancel : copy.close),
          ),
          if (canConfirm)
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await onConfirm();
              },
              child: Text(copy.importProfile),
            ),
        ],
      );
    },
  );
}

Widget _warningBanner(BuildContext context, String message) {
  final theme = Theme.of(context);
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1DC),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFFFD59E)),
    ),
    child: Text(
      message,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: const Color(0xFF7C4A03),
      ),
    ),
  );
}

class _PortableTransportProfilePassphraseDialog extends StatefulWidget {
  const _PortableTransportProfilePassphraseDialog({
    required this.title,
    required this.actionLabel,
    this.errorText,
    this.message,
  });

  final String title;
  final String actionLabel;
  final String? errorText;
  final String? message;

  @override
  State<_PortableTransportProfilePassphraseDialog> createState() =>
      _PortableTransportProfilePassphraseDialogState();
}

class _PortableTransportProfilePassphraseDialogState
    extends State<_PortableTransportProfilePassphraseDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = context.shellText;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if ((widget.message ?? '').trim().isNotEmpty) ...<Widget>[
              Text(widget.message!.trim()),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const ValueKey<String>(
                'transport-profile-portable-passphrase-field',
              ),
              controller: _controller,
              autofocus: true,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Passphrase',
                errorText: widget.errorText,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(copy.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.actionLabel)),
      ],
    );
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text);
  }
}

class _PortableTransportProfilePasteDialog extends StatefulWidget {
  const _PortableTransportProfilePasteDialog();

  @override
  State<_PortableTransportProfilePasteDialog> createState() =>
      _PortableTransportProfilePasteDialogState();
}

class _PortableTransportProfilePasteDialogState
    extends State<_PortableTransportProfilePasteDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = context.shellText;
    return AlertDialog(
      title: Text(copy.pastePortableProfileEnvelope),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>(
                'transport-profile-portable-paste-field',
              ),
              controller: _controller,
              minLines: 8,
              maxLines: 16,
              decoration: InputDecoration(
                labelText: copy.portableProfileJson,
                errorText: _errorText,
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
        FilledButton(onPressed: _submit, child: Text(copy.previewImport)),
      ],
    );
  }

  void _submit() {
    final payload = _controller.text.trim();
    if (payload.isEmpty) {
      setState(() {
        _errorText = context.shellText.payloadInvalidOrUnsupported;
      });
      return;
    }
    Navigator.of(context).pop(payload);
  }
}

String _transportProfileKindLabel(TransportProfileKind? kind) {
  if (kind == TransportProfileKind.wireGuardNativeV1) {
    return 'WireGuard';
  }
  return kind?.value ?? '';
}

String _displayLabel(String displayName, String fallback) {
  final trimmed = displayName.trim();
  if (trimmed.isNotEmpty) {
    return trimmed;
  }
  return fallback;
}

String _blockedReasonMessage(
  TransportProfilePortableTransferBlockedReason? reason,
) {
  return switch (reason) {
    TransportProfilePortableTransferBlockedReason.wrongPassphrase =>
      'Wrong passphrase. Re-enter the passphrase for this envelope.',
    TransportProfilePortableTransferBlockedReason.unsupportedEnvelope =>
      'This envelope format is not supported by the connected host.',
    TransportProfilePortableTransferBlockedReason.unsupportedProfileKind =>
      'The connected host does not support this VPN transport profile kind.',
    TransportProfilePortableTransferBlockedReason.incompatibleHost =>
      'The connected host cannot store this portable VPN transport profile.',
    TransportProfilePortableTransferBlockedReason.malformedEnvelope =>
      'The envelope is malformed or incomplete.',
    TransportProfilePortableTransferBlockedReason.missingRequiredProfileKind =>
      'This transport profile kind is not compatible with the selected startup path.',
    _ => 'Portable import is blocked.',
  };
}

String _warningMessage(TransportProfilePortableTransferPreviewWarning warning) {
  if (warning.message.trim().isNotEmpty) {
    return warning.message.trim();
  }
  return switch (warning.code) {
    TransportProfilePortableTransferPreviewWarningCode.displayNameConflict =>
      'A profile with the same name already exists on this device.',
    _ => 'Review this portable transport-profile warning before importing.',
  };
}

String _existingProfileSummary(
  TransportProfilePortableTransferExistingProfile profile,
) {
  final label = _displayLabel(
    profile.displayName,
    _transportProfileKindLabel(profile.kind),
  );
  if (profile.defaultFor.isNotEmpty) {
    return '$label - already selected for startup';
  }
  return label;
}
