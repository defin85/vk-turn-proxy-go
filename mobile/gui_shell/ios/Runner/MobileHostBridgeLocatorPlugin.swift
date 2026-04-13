import Flutter
import UIKit

private let mobileHostBridgeChannelName =
  "com.defin85.vk_turn_proxy_go/mobile_host_bridge"
private let mobileHostBridgeBrowserReturnSignalChannelName =
  "com.defin85.vk_turn_proxy_go/mobile_host_bridge/browser_return_signals"
private let mobileHostUrlInfoKey = "VKTMobileHostURL"
private let defaultLoopbackControlPlaneURL = "http://127.0.0.1:7777"

final class MobileHostBridgeLocatorPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private static weak var shared: MobileHostBridgeLocatorPlugin?
  private static var pendingBrowserReturnSignals = [[String: String]]()

  private var browserReturnEventSink: FlutterEventSink?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: mobileHostBridgeChannelName,
      binaryMessenger: registrar.messenger()
    )
    let eventChannel = FlutterEventChannel(
      name: mobileHostBridgeBrowserReturnSignalChannelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = MobileHostBridgeLocatorPlugin()
    shared = instance
    registrar.addMethodCallDelegate(instance, channel: channel)
    eventChannel.setStreamHandler(instance)
  }

  static func emitBrowserReturnSignal(kind: String, uri: String?) {
    var payload = ["kind": kind]
    if let uri, !uri.isEmpty {
      payload["uri"] = uri
    }
    if let sink = shared?.browserReturnEventSink {
      sink(payload)
      return
    }
    pendingBrowserReturnSignals.append(payload)
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

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    browserReturnEventSink = events
    flushPendingBrowserReturnSignals()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    browserReturnEventSink = nil
    return nil
  }

  private func flushPendingBrowserReturnSignals() {
    guard let sink = browserReturnEventSink else {
      return
    }
    for payload in Self.pendingBrowserReturnSignals {
      sink(payload)
    }
    Self.pendingBrowserReturnSignals.removeAll(keepingCapacity: false)
  }
}
