import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter/services.dart';

abstract class DesktopPortableProfileTransferAdapter {
  Future<void> copyEnvelopeText(String payload);
  Future<String?> saveEnvelopeText({
    required String suggestedName,
    required String payload,
  });
  Future<String?> openEnvelopeText();
}

class SystemDesktopPortableProfileTransferAdapter
    implements DesktopPortableProfileTransferAdapter {
  const SystemDesktopPortableProfileTransferAdapter();

  XTypeGroup get _portableProfileJsonTypeGroup => XTypeGroup(
    label: currentShellText.portableProfileJson,
    extensions: const <String>['json'],
    mimeTypes: const <String>['application/json', 'text/plain'],
    uniformTypeIdentifiers: const <String>['public.json', 'public.plain-text'],
  );

  @override
  Future<void> copyEnvelopeText(String payload) {
    return Clipboard.setData(ClipboardData(text: payload));
  }

  @override
  Future<String?> saveEnvelopeText({
    required String suggestedName,
    required String payload,
  }) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: <XTypeGroup>[_portableProfileJsonTypeGroup],
    );
    if (location == null) {
      return null;
    }
    final file = File(location.path);
    await file.writeAsString(payload);
    return file.path;
  }

  @override
  Future<String?> openEnvelopeText() async {
    final file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[_portableProfileJsonTypeGroup],
    );
    if (file == null) {
      return null;
    }
    return file.readAsString();
  }
}
