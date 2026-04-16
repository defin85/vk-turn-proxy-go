import 'package:flutter/services.dart';

const String _mobileHostBridgeChannelName =
    'com.defin85.vk_turn_proxy_go/mobile_host_bridge';

class MobilePlatformApp {
  const MobilePlatformApp({
    required this.packageName,
    required this.label,
    this.systemApp = false,
  });

  factory MobilePlatformApp.fromJson(Map<dynamic, dynamic> json) {
    final packageName = (json['package_name'] as String? ?? '').trim();
    final label = (json['label'] as String? ?? '').trim();
    return MobilePlatformApp(
      packageName: packageName,
      label: label.isEmpty ? packageName : label,
      systemApp: json['system_app'] as bool? ?? false,
    );
  }

  final String packageName;
  final String label;
  final bool systemApp;
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

class PlatformMobilePlatformAppInventory
    implements MobilePlatformAppInventory {
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
      final apps =
          (payload ?? const <dynamic>[])
              .whereType<Map<dynamic, dynamic>>()
              .map(MobilePlatformApp.fromJson)
              .where(
                (MobilePlatformApp app) => app.packageName.isNotEmpty,
              )
              .toList(growable: false);
      return apps;
    } on MissingPluginException {
      throw const MobilePlatformAppInventoryError(
        'Native mobile host bridge plugin is unavailable for installed-app inventory.',
      );
    } on PlatformException catch (error) {
      throw MobilePlatformAppInventoryError(
        'Failed to list installed apps from the native platform: ${error.message ?? error.code}',
      );
    } catch (error) {
      throw MobilePlatformAppInventoryError(
        'Failed to list installed apps from the native platform: $error',
      );
    }
  }
}
