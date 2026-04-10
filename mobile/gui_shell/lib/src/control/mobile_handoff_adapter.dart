import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

abstract class MobileHandoffAdapter {
  Future<void> copyLink(String link);
  Future<void> shareLink(String link);
}

class SystemMobileHandoffAdapter implements MobileHandoffAdapter {
  const SystemMobileHandoffAdapter();

  @override
  Future<void> copyLink(String link) {
    return Clipboard.setData(ClipboardData(text: link));
  }

  @override
  Future<void> shareLink(String link) {
    return SharePlus.instance.share(ShareParams(text: link));
  }
}
