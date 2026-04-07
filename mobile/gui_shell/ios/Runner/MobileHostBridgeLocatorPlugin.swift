import Flutter
import UIKit

private let mobileHostBridgeChannelName =
  "com.defin85.vk_turn_proxy_go/mobile_host_bridge"
private let mobileHostUrlInfoKey = "VKTMobileHostURL"
private let defaultLoopbackControlPlaneURL = "http://127.0.0.1:7777"

final class MobileHostBridgeLocatorPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: mobileHostBridgeChannelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = MobileHostBridgeLocatorPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "resolveHost":
      result(resolveHostConfiguration())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func resolveHostConfiguration() -> [String: String] {
    if let configured = configuredHostURL() {
      return [
        "base_url": configured,
        "description": "ios Info.plist \(mobileHostUrlInfoKey)",
      ]
    }
    return [
      "base_url": defaultLoopbackControlPlaneURL,
      "description": "ios loopback default",
    ]
  }

  private func configuredHostURL() -> String? {
    guard let raw = Bundle.main.object(forInfoDictionaryKey: mobileHostUrlInfoKey) as? String else {
      return nil
    }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
