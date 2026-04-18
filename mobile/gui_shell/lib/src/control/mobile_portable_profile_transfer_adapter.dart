import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const String _portableProfileIngressChannelName =
    'com.defin85.vk_turn_proxy_go/mobile_portable_profile_transfer/ingress';

abstract class MobilePortableProfileTransferAdapter {
  Stream<String> get ingressPayloads;
  Future<void> copyEnvelopeText(String payload);
  Future<void> shareEnvelopeText(String payload);
  Future<void> shareEnvelopeFile({
    required String suggestedName,
    required String payload,
  });
  Future<String?> openEnvelopeText();
}

class SystemMobilePortableProfileTransferAdapter
    implements MobilePortableProfileTransferAdapter {
  SystemMobilePortableProfileTransferAdapter({EventChannel? ingressChannel})
    : _ingressChannel =
          ingressChannel ??
          const EventChannel(_portableProfileIngressChannelName);

  XTypeGroup get _portableProfileJsonTypeGroup => XTypeGroup(
    label: currentShellText.portableProfileJson,
    extensions: const <String>['json'],
    mimeTypes: const <String>['application/json', 'text/plain'],
    uniformTypeIdentifiers: const <String>['public.json', 'public.plain-text'],
  );

  final EventChannel _ingressChannel;
  Stream<String>? _ingressPayloads;

  @override
  Stream<String> get ingressPayloads => _ingressPayloads ??= _ingressChannel
      .receiveBroadcastStream()
      .where((dynamic payload) => payload is String)
      .cast<String>()
      .map((String payload) => payload.trim())
      .where((String payload) => payload.isNotEmpty);

  @override
  Future<void> copyEnvelopeText(String payload) {
    return Clipboard.setData(ClipboardData(text: payload));
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

  @override
  Future<void> shareEnvelopeFile({
    required String suggestedName,
    required String payload,
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$suggestedName');
    await file.writeAsString(payload);
    await SharePlus.instance.share(
      ShareParams(
        text: currentShellText.portableProfileEnvelope,
        files: <XFile>[XFile(file.path)],
      ),
    );
  }

  @override
  Future<void> shareEnvelopeText(String payload) {
    return SharePlus.instance.share(ShareParams(text: payload));
  }
}
