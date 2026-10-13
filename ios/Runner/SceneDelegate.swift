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
    // Capture a cold-launch document before Flutter forwards connection events.
    // Dart's launch read runs on this thread after the scene callback returns.
    for context in connectionOptions.urlContexts {
      appDelegate?.queueDocument(context.url)
    }
    appDelegate?.queueStagedSharedFile()
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    // Own file URLs; continue forwarding other URLs to Flutter plugins.
    let unhandled = Set(URLContexts.filter { context in
      !(appDelegate?.queueDocument(context.url) ?? false)
    })
    if !unhandled.isEmpty {
      super.scene(scene, openURLContexts: unhandled)
    }
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    // Drain recordings left by the 1.1.2 Share extension on later activations.
    appDelegate?.queueStagedSharedFile()
  }
}
