import AppIntents
import UIKit

/// Entry points that open the app straight into Live Mode and start
/// listening: the iOS counterpart of the Android "Quick Listen" widget.
///
/// Three native surfaces feed one queue on `AppDelegate`
/// (`queueQuickAction`), which reaches Dart over the same
/// `com.birdnet/quick_action_intents` channel Android uses. Dart does not know
/// which surface fired; see `lib/shared/services/quick_action_service.dart`.
///
/// - `StartListeningIntent`: an App Intent. Shortcuts, Siri, Spotlight, and the
///   Action Button pick it up on their own, and `BirdNETLiveShortcuts`
///   publishes it with spoken phrases so nobody has to build a shortcut first.
/// - `birdnetlive://listen`: a URL scheme (`CFBundleURLTypes` in Info.plist)
///   for the Shortcuts "Open URL" action, automations, and NFC tags.
/// - A static home-screen quick action (`UIApplicationShortcutItems` in
///   Info.plist) in the app icon's long-press menu.
enum QuickAction {
  /// Must match `QuickActionService.startListeningAction` in Dart and
  /// `QuickListenContract.ACTION_START_LISTENING` on Android.
  static let startListening = "startListening"

  /// Registered in Info.plist under `CFBundleURLTypes`.
  static let urlScheme = "birdnetlive"
  private static let listenTarget = "listen"

  /// `UIApplicationShortcutItemType` of the long-press menu entry in Info.plist.
  private static let startListeningShortcutItemType = "com.birdnet.startListening"

  /// The action a `birdnetlive://` URL asks for, or nil for any other URL.
  /// Prefix of the action that carries an upload-destination join link
  /// (#284); the rest is the URL. Dart's quick-action listener routes it.
  static let joinPrefix = "join:"

  static func action(for url: URL) -> String? {
    if isJoinLink(url) { return joinPrefix + url.absoluteString }
    guard url.scheme?.lowercased() == urlScheme else { return nil }
    // `birdnetlive://listen` parses as a host, `birdnetlive:listen` as a path.
    let target = url.host
      ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return target.lowercased() == listenTarget ? startListening : nil
  }

  /// `birdnetlive://join?...` or the docs-site landing page.
  static func isJoinLink(_ url: URL) -> Bool {
    let scheme = url.scheme?.lowercased()
    if scheme == urlScheme {
      let target = url.host
        ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      return target.lowercased() == "join"
    }
    return scheme == "https" && url.host?.lowercased() == "birdnet-team.github.io"
      && url.path.hasPrefix("/birdnet-live-app/join")
  }

  /// The action behind a home-screen quick action, or nil if it is not ours.
  static func action(for item: UIApplicationShortcutItem) -> String? {
    item.type == startListeningShortcutItemType ? startListening : nil
  }
}

/// "Start Listening" as the system sees it: in the Shortcuts app, in Siri, in
/// Spotlight, and in the Action Button picker.
///
/// `openAppWhenRun` makes the system bring the app to the foreground first, so
/// `perform` runs inside the app process and can hand the action to
/// `AppDelegate` directly. On a cold start that happens before Dart's launch
/// read, on a warm start the channel delivers it to the mounted listener.
struct StartListeningIntent: AppIntent {
  static let title: LocalizedStringResource = "Start Listening"
  static var description: IntentDescription? = IntentDescription(
    "Opens Live Mode and starts listening right away."
  )
  static let openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    (UIApplication.shared.delegate as? AppDelegate)?
      .queueQuickAction(QuickAction.startListening)
    return .result()
  }
}

/// Publishes the intent as an App Shortcut: it shows up under BirdNET Live in
/// the Shortcuts app and the Action Button picker without any setup, and the
/// phrases work with Siri. Phrase translations live in the
/// `<locale>.lproj/AppShortcuts.strings` files: a string catalog for App
/// Shortcuts would need a 17.0 deployment target.
///
/// iOS 17 only because the initializer that carries a title and icon is; on
/// iOS 16 the intent is still available as a plain Shortcuts action.
@available(iOS 17.0, *)
struct BirdNETLiveShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: StartListeningIntent(),
      phrases: [
        "Start listening with \(.applicationName)",
        "Listen for birds with \(.applicationName)",
        "Identify a bird with \(.applicationName)",
      ],
      shortTitle: "Start Listening",
      systemImageName: "mic.fill"
    )
  }
}
