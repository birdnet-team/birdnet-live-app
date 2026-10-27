import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var appDelegate: AppDelegate? {
    UIApplication.shared.delegate as? AppDelegate
  }

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    // Capture a cold-launch document or Quick Listen trigger before Flutter
    // forwards connection events. Dart's launch read runs on this thread after
    // the scene callback returns, so what is queued here opens directly.
    for context in connectionOptions.urlContexts {
      if !(appDelegate?.queueDocument(context.url) ?? false) {
        appDelegate?.queueQuickAction(url: context.url)
      }
    }
    if let shortcutItem = connectionOptions.shortcutItem {
      appDelegate?.queueQuickAction(shortcutItem: shortcutItem)
    }
    appDelegate?.queueStagedSharedFile()
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    // Own file URLs and birdnetlive:// URLs; continue forwarding other URLs to
    // Flutter plugins.
    let unhandled = Set(URLContexts.filter { context in
      guard let appDelegate = appDelegate else { return true }
      return !(appDelegate.queueDocument(context.url)
        || appDelegate.queueQuickAction(url: context.url))
    })
    if !unhandled.isEmpty {
      super.scene(scene, openURLContexts: unhandled)
    }
  }

  /// Home-screen quick action chosen while the app was already running. A cold
  /// launch from the same menu arrives through `connectionOptions.shortcutItem`
  /// above instead.
  override func windowScene(
    _ windowScene: UIWindowScene,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
    if appDelegate?.queueQuickAction(shortcutItem: shortcutItem) ?? false {
      completionHandler(true)
      return
    }
    super.windowScene(
      windowScene, performActionFor: shortcutItem, completionHandler: completionHandler
    )
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    // Drain recordings left by the 1.1.2 Share extension on later activations.
    appDelegate?.queueStagedSharedFile()
  }
}
