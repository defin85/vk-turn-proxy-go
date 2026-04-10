import 'package:flutter/services.dart';

abstract class MobileHandoffAdapter {
  Future<void> copyLink(String link);
}

class ClipboardMobileHandoffAdapter implements MobileHandoffAdapter {
  const ClipboardMobileHandoffAdapter();

  @override
  Future<void> copyLink(String link) {
    return Clipboard.setData(ClipboardData(text: link));
  }
}
