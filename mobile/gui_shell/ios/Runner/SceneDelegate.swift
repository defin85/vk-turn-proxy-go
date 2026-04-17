import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    for urlContext in connectionOptions.urlContexts {
      emitURL(urlContext.url)
    }
    for activity in connectionOptions.userActivities {
      emitUniversalLink(activity)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    for urlContext in URLContexts {
      emitURL(urlContext.url)
    }
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    super.scene(scene, continue: userActivity)
    emitUniversalLink(userActivity)
  }

  private func emitURL(_ url: URL) {
    if url.isFileURL {
      MobileHostBridgeLocatorPlugin.emitPortableProfileIngress(url: url)
      return
    }
    MobileHostBridgeLocatorPlugin.emitBrowserReturnSignal(
      kind: "app_link",
      uri: url.absoluteString
    )
  }

  private func emitUniversalLink(_ activity: NSUserActivity) {
    guard activity.activityType == NSUserActivityTypeBrowsingWeb,
      let url = activity.webpageURL
    else {
      return
    }
    MobileHostBridgeLocatorPlugin.emitBrowserReturnSignal(
      kind: "universal_link",
      uri: url.absoluteString
    )
  }
}
