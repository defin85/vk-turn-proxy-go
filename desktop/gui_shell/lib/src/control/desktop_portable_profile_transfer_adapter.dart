import 'dart:io';

import 'package:file_selector/file_selector.dart';
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

  static const XTypeGroup _portableProfileJsonTypeGroup = XTypeGroup(
    label: 'Portable profile JSON',
    extensions: <String>['json'],
    mimeTypes: <String>['application/json', 'text/plain'],
    uniformTypeIdentifiers: <String>['public.json', 'public.plain-text'],
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
      acceptedTypeGroups: const <XTypeGroup>[_portableProfileJsonTypeGroup],
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
      acceptedTypeGroups: const <XTypeGroup>[_portableProfileJsonTypeGroup],
    );
    if (file == null) {
      return null;
    }
    return file.readAsString();
  }
}
