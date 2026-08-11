// =============================================================================
// Share Extension — "Share with BirdNET Live" on iOS
// =============================================================================
//
// Puts BirdNET Live in the system share sheet for audio attachments, from any
// app that offers one (Voice Memos, Files, Mail, messaging apps, recorders).
//
// The extension has no UI of its own: it copies the attachment into the shared
// App Group container and dismisses. AppDelegate picks the file up the next
// time BirdNET Live becomes active and hands it to File Analysis. The App Group
// is the only supported way across the sandbox boundary — a Share extension
// cannot launch its containing app.
//
// Deliberately kept free of Flutter and of any pod: the extension has a tight
// memory budget, and linking the engine into it would risk the system killing
// it before the hand-off completes.
// =============================================================================

import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
  /// Must match the App Group in both entitlements files and
  /// `AppDelegate.appGroupIdentifier`.
  private static let appGroupIdentifier = "group.de.tu-chemnitz.mi.kahst.birdnet-live"

  /// Directory inside the App Group container used to pass the file across.
  private static let sharedMediaDirName = "shared_audio"

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    handleSharedItem()
  }

  private func handleSharedItem() {
    guard let provider = firstAudioProvider() else {
      finish()
      return
    }
    // Load the concrete registered type rather than `public.audio` itself, so
    // the source hands over the real file (and its extension) instead of a
    // transcoded stand-in.
    guard let typeIdentifier = provider.registeredTypeIdentifiers.first(where: {
      UTType($0)?.conforms(to: .audio) ?? false
    }) else {
      finish()
      return
    }

    provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) {
      [weak self] url, loadError in
      // The URL is only valid for the duration of this callback, so the copy
      // has to happen here rather than on a queue we hop to.
      let copyResult: Result<String, Error> = Result {
        guard let url = url else {
          throw loadError ?? NSError(
            domain: "com.birdnet.shareExtension",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Shared audio file unavailable"]
          )
        }
        return try ShareViewController.copyIntoAppGroup(
          url,
          displayName: provider.suggestedName
        )
      }
      DispatchQueue.main.async {
        switch copyResult {
        case .success:
          self?.finish()
        case .failure(let error):
          self?.fail(error)
        }
      }
    }
  }

  private func firstAudioProvider() -> NSItemProvider? {
    guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
      return nil
    }
    for item in items {
      for provider in item.attachments ?? [] {
        let isAudio = provider.registeredTypeIdentifiers.contains {
          UTType($0)?.conforms(to: .audio) ?? false
        }
        if isAudio { return provider }
      }
    }
    return nil
  }

  /// Copies [url] into the App Group container and returns the stored name.
  ///
  /// Only the most recent share is kept: the directory is emptied first, so a
  /// share the user abandoned never gets picked up in place of this one.
  @discardableResult
  private static func copyIntoAppGroup(_ url: URL, displayName: String?) throws -> String {
    let fileManager = FileManager.default
    guard let container = fileManager.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupIdentifier
    ) else {
      throw NSError(
        domain: "com.birdnet.shareExtension",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "App Group container unavailable"]
      )
    }

    let directory = container.appendingPathComponent(sharedMediaDirName)
    if fileManager.fileExists(atPath: directory.path) {
      for item in (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? [] {
        try? fileManager.removeItem(at: directory.appendingPathComponent(item))
      }
    } else {
      try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // A unique path lets AppDelegate distinguish a new share from an older
    // delivery even when the source uses the same file name repeatedly.
    let originalName = safeFileName(
      displayName ?? url.lastPathComponent,
      fallbackExtension: url.pathExtension
    )
    let deliveryID = UUID().uuidString
    let name = "\(deliveryID)--\(originalName)"
    let temporary = directory.appendingPathComponent(".\(deliveryID).tmp")
    let destination = directory.appendingPathComponent(name)
    do {
      // Publish with an atomic move so AppDelegate never sees a file left
      // partially copied after an extension timeout or crash.
      try fileManager.copyItem(at: url, to: temporary)
      try fileManager.moveItem(at: temporary, to: destination)
    } catch {
      try? fileManager.removeItem(at: temporary)
      throw error
    }
    return name
  }

  /// Strips path components from a source-supplied name and makes sure the
  /// result still carries an extension — File Analysis labels the format from
  /// it, and the decoder uses it as its container hint.
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

  private func finish() {
    extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
  }

  private func fail(_ error: Error) {
    extensionContext?.cancelRequest(withError: error)
  }
}
