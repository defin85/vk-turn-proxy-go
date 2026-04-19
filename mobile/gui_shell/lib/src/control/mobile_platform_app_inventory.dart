import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter/services.dart';

const String _mobileHostBridgeChannelName =
    'com.defin85.vk_turn_proxy_go/mobile_host_bridge';

class MobilePlatformApp {
  const MobilePlatformApp({
    required this.packageName,
    required this.label,
    this.systemApp = false,
    this.iconBytes,
  });

  factory MobilePlatformApp.fromJson(Map<dynamic, dynamic> json) {
    final packageName = (json['package_name'] as String? ?? '').trim();
    final label = (json['label'] as String? ?? '').trim();
    return MobilePlatformApp(
      packageName: packageName,
      label: label.isEmpty ? packageName : label,
      systemApp: json['system_app'] as bool? ?? false,
      iconBytes: _parseIconBytes(json['icon_bytes']),
    );
  }

  final String packageName;
  final String label;
  final bool systemApp;
  final Uint8List? iconBytes;

  static Uint8List? _parseIconBytes(dynamic rawValue) {
    if (rawValue is Uint8List) {
      return rawValue.isEmpty ? null : rawValue;
    }
    if (rawValue is List<int>) {
      return rawValue.isEmpty ? null : Uint8List.fromList(rawValue);
    }
    if (rawValue is List<dynamic>) {
      final values = rawValue.whereType<int>().toList(growable: false);
      return values.isEmpty ? null : Uint8List.fromList(values);
    }
    return null;
  }
}

class MobilePlatformAppInventoryError implements Exception {
  const MobilePlatformAppInventoryError(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class MobilePlatformAppInventory {
  Future<List<MobilePlatformApp>> listInstalledApps();
}

class PlatformMobilePlatformAppInventory implements MobilePlatformAppInventory {
  PlatformMobilePlatformAppInventory({MethodChannel? methodChannel})
    : _methodChannel =
          methodChannel ?? const MethodChannel(_mobileHostBridgeChannelName);

  final MethodChannel _methodChannel;

  @override
  Future<List<MobilePlatformApp>> listInstalledApps() async {
    try {
      final payload = await _methodChannel.invokeMethod<List<dynamic>>(
        'listInstalledApps',
      );
      final apps = (payload ?? const <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map(MobilePlatformApp.fromJson)
          .where((MobilePlatformApp app) => app.packageName.isNotEmpty)
          .toList(growable: false);
      return apps;
    } on MissingPluginException {
      throw MobilePlatformAppInventoryError(
        currentShellText
            .nativeMobileHostBridgePluginUnavailableForInstalledAppInventory,
      );
    } on PlatformException catch (error) {
      throw MobilePlatformAppInventoryError(
        currentShellText.failedToListInstalledAppsFromNativePlatform(
          error.message ?? error.code,
        ),
      );
    } catch (error) {
      throw MobilePlatformAppInventoryError(
        currentShellText.failedToListInstalledAppsFromNativePlatform(error),
      );
    }
  }
}
