import Flutter
import UIKit

private let mobileHostBridgeChannelName =
  "com.defin85.vk_turn_proxy_go/mobile_host_bridge"
private let mobileHostBridgeBrowserReturnSignalChannelName =
  "com.defin85.vk_turn_proxy_go/mobile_host_bridge/browser_return_signals"
private let mobilePortableProfileIngressChannelName =
  "com.defin85.vk_turn_proxy_go/mobile_portable_profile_transfer/ingress"
private let mobileHostUrlInfoKey = "VKTMobileHostURL"
private let defaultLoopbackControlPlaneURL = "http://127.0.0.1:7777"

final class MobileHostBridgeLocatorPlugin: NSObject, FlutterPlugin {
  private static weak var shared: MobileHostBridgeLocatorPlugin?
  private static var pendingBrowserReturnSignals = [[String: String]]()
  private static var pendingPortableProfileIngressPayloads = [String]()

  private var browserReturnEventSink: FlutterEventSink?
  private var portableProfileIngressEventSink: FlutterEventSink?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: mobileHostBridgeChannelName,
      binaryMessenger: registrar.messenger()
    )
    let browserReturnEventChannel = FlutterEventChannel(
      name: mobileHostBridgeBrowserReturnSignalChannelName,
      binaryMessenger: registrar.messenger()
    )
    let portableProfileIngressEventChannel = FlutterEventChannel(
      name: mobilePortableProfileIngressChannelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = MobileHostBridgeLocatorPlugin()
    shared = instance
    registrar.addMethodCallDelegate(instance, channel: channel)
    browserReturnEventChannel.setStreamHandler(
      _EventSinkStreamHandler(
        onListen: { events in
          instance.browserReturnEventSink = events
          instance.flushPendingBrowserReturnSignals()
        },
        onCancel: {
          instance.browserReturnEventSink = nil
        }
      )
    )
    portableProfileIngressEventChannel.setStreamHandler(
      _EventSinkStreamHandler(
        onListen: { events in
          instance.portableProfileIngressEventSink = events
          instance.flushPendingPortableProfileIngressPayloads()
        },
        onCancel: {
          instance.portableProfileIngressEventSink = nil
        }
      )
    )
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

  static func emitPortableProfileIngress(payload: String) {
    let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return
    }
    if let sink = shared?.portableProfileIngressEventSink {
      sink(trimmed)
      return
    }
    pendingPortableProfileIngressPayloads.append(trimmed)
  }

  static func emitPortableProfileIngress(url: URL) {
    guard let payload = readPortableProfilePayload(from: url) else {
      return
    }
    emitPortableProfileIngress(payload: payload)
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

  private func flushPendingBrowserReturnSignals() {
    guard let sink = browserReturnEventSink else {
      return
    }
    for payload in Self.pendingBrowserReturnSignals {
      sink(payload)
    }
    Self.pendingBrowserReturnSignals.removeAll(keepingCapacity: false)
  }

  private func flushPendingPortableProfileIngressPayloads() {
    guard let sink = portableProfileIngressEventSink else {
      return
    }
    for payload in Self.pendingPortableProfileIngressPayloads {
      sink(payload)
    }
    Self.pendingPortableProfileIngressPayloads.removeAll(keepingCapacity: false)
  }

  private static func readPortableProfilePayload(from url: URL) -> String? {
    let didAccess = url.startAccessingSecurityScopedResource()
    defer {
      if didAccess {
        url.stopAccessingSecurityScopedResource()
      }
    }
    guard let payload = try? String(contentsOf: url, encoding: .utf8) else {
      return nil
    }
    let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}

private final class _EventSinkStreamHandler: NSObject, FlutterStreamHandler {
  init(
    onListen: @escaping (FlutterEventSink) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.onListenHandler = onListen
    self.onCancelHandler = onCancel
  }

  private let onListenHandler: (FlutterEventSink) -> Void
  private let onCancelHandler: () -> Void

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    onListenHandler(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    onCancelHandler()
    return nil
  }
}
