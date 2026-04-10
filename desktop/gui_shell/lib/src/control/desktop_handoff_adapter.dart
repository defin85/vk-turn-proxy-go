import 'package:flutter/services.dart';

abstract class DesktopHandoffAdapter {
  Future<void> copyLink(String link);
}

class ClipboardDesktopHandoffAdapter implements DesktopHandoffAdapter {
  const ClipboardDesktopHandoffAdapter();

  @override
  Future<void> copyLink(String link) {
    return Clipboard.setData(ClipboardData(text: link));
  }
}
