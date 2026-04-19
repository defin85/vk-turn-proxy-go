import 'package:flutter/material.dart';
import 'package:flutter_shell_core/portable_profile_transfer.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

Future<void> showPortableProfileExportDialog({
  required BuildContext context,
  required PortableProfileEnvelope envelope,
  required Future<void> Function(PortableProfileEnvelope envelope) onCopyText,
  required Future<void> Function(PortableProfileEnvelope envelope) onShareText,
  required Future<void> Function(PortableProfileEnvelope envelope) onShareFile,
}) async {
  await showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      final copy = context.shellText;
      final compactBytes = envelope.encodedUtf8Bytes;
      final canRenderQr = compactBytes <= 2200;
      return AlertDialog(
        title: Text(copy.exportSavedProfile),
        content: SizedBox(
          width: 560,
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
                if (envelope.isSecretBearing) ...<Widget>[
                  const SizedBox(height: 12),
                  _warningBanner(
                    context,
                    copy.portableExportSecretWarningMobile,
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  copy.portableProfileEnvelope,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (canRenderQr) ...<Widget>[
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
                    copy.portableQrUnavailableMobile(compactBytes),
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
            onPressed: () => onCopyText(envelope),
            child: Text(copy.copyText),
          ),
          FilledButton.tonal(
            onPressed: () => onShareText(envelope),
            child: Text(copy.shareText),
          ),
          FilledButton(
            onPressed: () => onShareFile(envelope),
            child: Text(copy.shareFile),
          ),
        ],
      );
    },
  );
}

Future<void> showPortableProfileImportPreviewDialog({
  required BuildContext context,
  required PortableProfileEnvelope envelope,
  required Future<void> Function(PortableProfileEnvelope envelope) onConfirm,
}) async {
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
                Text(copy.sourceModeLabel(envelope.providerBinding.mode.value)),
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
              await onConfirm(envelope);
            },
            child: Text(copy.importProfile),
          ),
        ],
      );
    },
  );
}

Future<PortableProfileEnvelope?> showPortableProfilePasteDialog({
  required BuildContext context,
  required PortableProfileEnvelope? Function(String payload) onPreviewImport,
}) async {
  return showDialog<PortableProfileEnvelope>(
    context: context,
    builder: (BuildContext context) {
      return _PortablePasteDialog(onPreviewImport: onPreviewImport);
    },
  );
}

Future<String?> showPortableProfileQrScanner(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute<String>(
      builder: (BuildContext context) => const _PortableQrScannerPage(),
    ),
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

class _PortableQrScannerPage extends StatefulWidget {
  const _PortableQrScannerPage();

  @override
  State<_PortableQrScannerPage> createState() => _PortableQrScannerPageState();
}

class _PortablePasteDialog extends StatefulWidget {
  const _PortablePasteDialog({required this.onPreviewImport});

  final PortableProfileEnvelope? Function(String payload) onPreviewImport;

  @override
  State<_PortablePasteDialog> createState() => _PortablePasteDialogState();
}

class _PortablePasteDialogState extends State<_PortablePasteDialog> {
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

  void _previewImport() {
    FocusManager.instance.primaryFocus?.unfocus();
    final envelope = widget.onPreviewImport(_controller.text);
    if (envelope == null) {
      setState(() {
        _errorText = context.shellText.payloadInvalidOrUnsupported;
      });
      return;
    }
    Navigator.of(context).pop(envelope);
  }

  @override
  Widget build(BuildContext context) {
    final copy = context.shellText;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
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
              controller: _controller,
              keyboardType: TextInputType.multiline,
              minLines: keyboardVisible ? 4 : 8,
              maxLines: keyboardVisible ? 10 : 16,
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
        FilledButton(
          onPressed: _previewImport,
          child: Text(copy.previewImport),
        ),
      ],
    );
  }
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
