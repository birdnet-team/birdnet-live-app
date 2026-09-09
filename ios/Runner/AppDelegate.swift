import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// Directory name holding the most recent shared recording, both in the
  /// legacy App Group container and in this app's temporary directory it is
  /// imported into.
  private static let sharedMediaDirName = "shared_audio"

  /// Must match `Runner.entitlements`. Only reachable now through files the
  /// 1.1.2 Share extension left behind — see `queueStagedSharedFile`.
  private static let appGroupIdentifier = "group.de.tu-chemnitz.mi.kahst.birdnet-live"

  /// A shared audio document waiting to be picked up by Dart. Set on both cold
  /// and warm launches; drained by `takePendingSharedFile`.
  private var pendingSharedFile: [String: String]?
  private var sharedMediaChannel: FlutterMethodChannel?
  private var lastQueuedStagedURI: String?

  /// A document URL queued straight out of `launchOptions`.
  ///
  /// iOS delivers the same URL again through `application(_:open:)` moments
  /// after launch. This lets that second delivery be recognised and dropped
  /// once, without suppressing a genuine re-open of the same document later.
  private var launchDocumentURI: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller = window?.rootViewController as! FlutterViewController

    let wakelockChannel = FlutterMethodChannel(
      name: "com.birdnet/wakelock",
      binaryMessenger: controller.binaryMessenger
    )
    wakelockChannel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "enable":
        UIApplication.shared.isIdleTimerDisabled = true
        result(nil)
      case "disable":
        UIApplication.shared.isIdleTimerDisabled = false
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Audio decoder channel — decode compressed audio to PCM via AVFoundation.
    let audioChannel = FlutterMethodChannel(
      name: "com.birdnet/audio_decoder",
      binaryMessenger: controller.binaryMessenger
    )
    audioChannel.setMethodCallHandler { (call, result) in
      if call.method == "cancelDecode" {
        NativeAudioDecoder.isCancelled = true
        result(nil)
        return
      }
      guard call.method == "decode" || call.method == "inspect" || call.method == "decodeRange" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterError(code: "INVALID_ARG", message: "Missing 'path' argument", details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let decoded: [String: Any]
          if call.method == "inspect" {
            decoded = try NativeAudioDecoder.inspect(path: path)
          } else if call.method == "decodeRange" {
            guard let startSample = args["startSample"] as? Int,
                  let count = args["count"] as? Int else {
              DispatchQueue.main.async {
                result(FlutterError(code: "INVALID_ARG", message: "Missing 'startSample' or 'count' argument", details: nil))
              }
              return
            }
            decoded = try NativeAudioDecoder.decodeRange(path: path, startSample: startSample, count: count)
          } else {
            guard let tempPcmPath = args["tempPcmPath"] as? String else {
              DispatchQueue.main.async {
                result(FlutterError(code: "INVALID_ARG", message: "Missing 'tempPcmPath' argument", details: nil))
              }
              return
            }
            decoded = try NativeAudioDecoder.decode(path: path, tempPcmPath: tempPcmPath)
          }
          DispatchQueue.main.async {
            result(decoded)
          }
        } catch {
          DispatchQueue.main.async {
            let code = call.method == "inspect" ? "INSPECT_ERROR" : "DECODE_ERROR"
            result(FlutterError(code: code, message: error.localizedDescription, details: nil))
          }
        }
      }
    }

    // Shared-media channel — share-sheet and "Open With" hand-off, both of
    // which arrive as documents through CFBundleDocumentTypes.
    //
    // Split up on purpose: `takePendingSharedFile` answers immediately with the
    // URL so Dart can open File Analysis right away, `importSharedFile` does
    // the potentially slow copy behind that screen's own progress indicator,
    // and `discardSharedFile` releases the staging copy when Dart decides not
    // to open the file after all.
    let sharedMediaChannel = FlutterMethodChannel(
      name: "com.birdnet/shared_media",
      binaryMessenger: controller.binaryMessenger
    )
    sharedMediaChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "takePendingSharedFile":
        let pending = self.pendingSharedFile
        self.pendingSharedFile = nil
        result(pending)
      case "importSharedFile":
        guard let args = call.arguments as? [String: Any],
              let uri = args["uri"] as? String, !uri.isEmpty else {
          result(FlutterError(code: "INVALID_ARG", message: "Missing 'uri'", details: nil))
          return
        }
        let name = args["name"] as? String
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            let path = try AppDelegate.importSharedFile(uri: uri, displayName: name)
            DispatchQueue.main.async { result(path) }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(
                code: "IMPORT_ERROR",
                message: error.localizedDescription,
                details: nil
              ))
            }
          }
        }
      case "discardSharedFile":
        guard let args = call.arguments as? [String: Any],
              let uri = args["uri"] as? String, !uri.isEmpty else {
          result(FlutterError(code: "INVALID_ARG", message: "Missing 'uri'", details: nil))
          return
        }
        DispatchQueue.global(qos: .utility).async {
          AppDelegate.removeStagedFile(uri: uri)
          DispatchQueue.main.async { result(nil) }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.sharedMediaChannel = sharedMediaChannel

    // A document that launched the app is queued here rather than waiting for
    // `application(_:open:)`, which iOS calls only after this returns. Dart
    // reads the hand-off before its first frame, and that read is dispatched to
    // this thread — so it cannot be served until this method finishes, but it
    // can easily be served before the later callback runs. Queueing here is
    // what lets a cold "Open With" land on File Analysis directly.
    if let url = launchOptions?[.url] as? URL, url.isFileURL {
      launchDocumentURI = url.absoluteString
      queueDocument(url)
    }
    queueStagedSharedFile()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    // Nothing writes to the App Group any more; this only drains a file the
    // 1.1.2 Share extension staged before the user updated.
    queueStagedSharedFile()
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    // A document opened through CFBundleDocumentTypes (Files' "Open With", or
    // a share source that hands over a document instead of using the
    // extension). Other custom schemes still belong to the plugins registered
    // on the superclass.
    guard url.isFileURL else {
      return super.application(app, open: url, options: options)
    }
    // Drop the replay of a document already queued from `launchOptions`, once.
    if let queued = launchDocumentURI {
      launchDocumentURI = nil
      if queued == url.absoluteString { return true }
    }
    queueDocument(url)
    return true
  }

  private func queueDocument(_ url: URL) {
    pendingSharedFile = ["uri": url.absoluteString, "name": url.lastPathComponent]
    sharedMediaChannel?.invokeMethod("onSharedFile", arguments: nil)
  }

  /// Picks up a recording the 1.1.2 Share extension left in the App Group.
  ///
  /// That target is gone — every share now arrives as a document — but a user
  /// who shared just before updating would otherwise never see the file, and
  /// nothing else prunes the App Group container. Remove this together with the
  /// entitlement once an update has had time to reach those users.
  private func queueStagedSharedFile() {
    // Do not overwrite a document URL that was delivered during the same app
    // activation. It should be handled before any older abandoned share.
    guard pendingSharedFile == nil,
          let staged = AppDelegate.stagedAppGroupFile(),
          let uri = staged["uri"],
          uri != lastQueuedStagedURI else { return }
    pendingSharedFile = staged
    lastQueuedStagedURI = uri
    sharedMediaChannel?.invokeMethod("onSharedFile", arguments: nil)
  }

  /// The recording the 1.1.2 Share extension left in the App Group container.
  ///
  /// It kept exactly one file there, but a crash mid-copy could leave more than
  /// one behind, so the newest wins.
  private static func stagedAppGroupFile() -> [String: String]? {
    let fileManager = FileManager.default
    guard let container = fileManager.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupIdentifier
    ) else { return nil }

    let directory = container.appendingPathComponent(sharedMediaDirName)
    guard let entries = try? fileManager.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.contentModificationDateKey],
      options: [.skipsHiddenFiles]
    ) else { return nil }

    let files = entries.filter { url in
      (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
    }
    let newest = files.max { lhs, rhs in
      let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?
        .contentModificationDate ?? .distantPast
      let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?
        .contentModificationDate ?? .distantPast
      return lhsDate < rhsDate
    }
    guard let url = newest else { return nil }
    return ["uri": url.absoluteString, "name": stagedDisplayName(url)]
  }

  /// The 1.1.2 Share extension prefixed staged files with a UUID so two
  /// hand-offs never reused the same URI. Keep that out of File Analysis.
  private static func stagedDisplayName(_ url: URL) -> String {
    let name = url.lastPathComponent
    guard let separator = name.range(of: "--") else { return name }
    let prefix = String(name[..<separator.lowerBound])
    guard UUID(uuidString: prefix) != nil else { return name }
    return String(name[separator.upperBound...])
  }

  /// Copies an incoming document into `tmp/shared_audio` and returns its path.
  ///
  /// The analysis pipeline works on real file paths and re-reads the recording
  /// while drawing the spectrogram, so the document is materialized somewhere
  /// we control. Only the most recent share is kept: the directory is emptied
  /// before each copy.
  private static func importSharedFile(uri: String, displayName: String?) throws -> String {
    guard let url = URL(string: uri) else {
      throw NSError(
        domain: "com.birdnet.sharedMedia",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Could not read the shared file"]
      )
    }
    let fileManager = FileManager.default
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent(sharedMediaDirName)
    if fileManager.fileExists(atPath: directory.path) {
      for item in (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? [] {
        try? fileManager.removeItem(at: directory.appendingPathComponent(item))
      }
    } else {
      try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // An empty name means the source provided none, so fall back to the URL
    // rather than letting it win and losing the real extension with it.
    let requestedName = (displayName ?? "").trimmingCharacters(in: .whitespaces)
    let destination = directory.appendingPathComponent(
      safeFileName(
        requestedName.isEmpty ? url.lastPathComponent : requestedName,
        fallbackExtension: url.pathExtension
      )
    )
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    try fileManager.copyItem(at: url, to: destination)

    removeStagedFile(at: url)
    return destination.path
  }

  /// Deletes the staging copy behind a hand-off, once the app is done with it.
  ///
  /// Called both after a successful import and when Dart gives up on a file it
  /// will not open, because neither staging area is pruned for us: documents
  /// handed over as a copy land in `Documents/Inbox`, which counts against the
  /// user's storage and is backed up, and a copy left by the 1.1.2 Share
  /// extension sits in the App Group container, which the system never
  /// touches.
  ///
  /// Anything outside those two directories is left alone — it belongs to
  /// whoever handed it to us.
  private static func removeStagedFile(uri: String) {
    guard let url = URL(string: uri), url.isFileURL else { return }
    removeStagedFile(at: url)
  }

  private static func removeStagedFile(at url: URL) {
    let fileManager = FileManager.default
    let appGroupStaging = fileManager
      .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
      .appendingPathComponent(sharedMediaDirName, isDirectory: true)
      .standardizedFileURL.path
    let inbox = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?
      .appendingPathComponent("Inbox", isDirectory: true)
      .standardizedFileURL.path
    let sourcePath = url.standardizedFileURL.path
    let isStaged =
      (inbox.map { sourcePath.hasPrefix($0 + "/") } ?? false)
      || (appGroupStaging.map { sourcePath.hasPrefix($0 + "/") } ?? false)
    if isStaged {
      try? fileManager.removeItem(at: url)
    }
  }

  /// Strips path components from a source-supplied name and makes sure the
  /// result still carries an extension — File Analysis labels the format from
  /// it, and the native decoder uses it as its container hint.
  private static func safeFileName(
    _ name: String,
    fallbackExtension: String? = nil
  ) -> String {
    var base = name.components(separatedBy: "/").last ?? name
    base = base.components(separatedBy: "\\").last ?? base
    base = base.components(separatedBy: .controlCharacters).joined()
      .trimmingCharacters(in: .whitespaces)
    if base.isEmpty || base == "." || base == ".." {
      base = "shared_audio"
    }
    if base.count > 120 {
      base = String(base.suffix(120))
    }
    if !(base as NSString).pathExtension.isEmpty { return base }
    let fallback = fallbackExtension?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    let resolvedExtension = fallback.flatMap { $0.isEmpty ? nil : $0 } ?? "audio"
    return "\(base).\(resolvedExtension)"
  }
}
