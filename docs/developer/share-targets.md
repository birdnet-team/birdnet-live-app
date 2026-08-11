# Share Targets

BirdNET Live registers as a system share target for audio files on Android and
iOS. Android shares and file-manager opens land immediately in File Analysis.
On iOS, document opens are immediate; Share-extension files are selected the
next time BirdNET Live becomes active.

## Shape of the feature

The hand-off is deliberately split across method-channel calls on
`com.birdnet/shared_media`:

| Call | Returns | Cost |
| --- | --- | --- |
| `takePendingSharedFile` | `{uri, name}` or `null` | instant |
| `importSharedFile` | local file path | a full file copy |
| `discardSharedFile` | nothing | a delete, or nothing at all |

Once the app receives the URI, `FileAnalysisScreen` can open before the copy
starts, and the copy then runs behind that screen's own spinner. A long
recording is hundreds of megabytes, and the analysis pipeline needs a real path
anyway: MediaExtractor, the pure-Dart WAV/FLAC readers, and the spectrogram all
seek by offset, so a `content://` stream has to be materialized first.

`name` is a hint, not a promise. Android leaves it null, because resolving a
display name costs a provider query and the capture runs on the main thread
inside `onCreate`; the import resolves it off the main thread instead. Either
way the platform falls back to the URI's own last path component, and always
ends up with a file extension — File Analysis labels the format from it, and
the native decoder uses it as its container hint.

Only the most recent import is kept. Each copy empties its destination
directory first, and that directory lives in the cache, so nothing accumulates.
The Dart bridge serializes every call because overlapping native copies would
otherwise delete each other's cache file.

`discardSharedFile` exists because the app can decide *not* to open a file it
was handed — a Session is already running, the import failed, or the listener
went away mid-hand-off. On iOS the staging copy is real storage the system
never reclaims, so dropping the file has to release it too; a successful
`importSharedFile` does the same release itself. On Android it is a no-op: the
shared URI belongs to the app that sent it, and no copy of ours exists until
the import creates one.

Dart side: `lib/shared/services/shared_media_service.dart` (the bridge) and
`_SharedAudioListener` in `lib/app.dart` (cold- and warm-start delivery,
onboarding gate, screen reuse). Both mirror the Quick Listen widget's
native-action bridge.

## Opening on the destination, not via Home

This applies to both native hand-offs — a shared file and a Quick Listen widget
tap — which share the machinery in `lib/app.dart`.

A hand-off that *launched* the app has to be read before the first frame, or
the user watches Home paint and then get navigated away from. `main()` starts
`takePendingSharedFile` and `takePendingNativeAction` alongside the preference
work and hands the results to `App.launchSharedFile` / `App.launchQuickAction`.

That read is safe because of thread ordering, not luck. The payload is captured
on the platform thread inside `MainActivity.onCreate` and
`didFinishLaunchingWithOptions`, and Dart's read is a channel message dispatched
to that same thread — so it cannot be served until those methods return. The
Dart entrypoint starting first does not matter.

The same ordering is why a document that launched the app on iOS is queued from
`launchOptions[.url]` rather than waiting for `application(_:open:)`: iOS calls
that only *after* `didFinishLaunchingWithOptions` returns, which is late enough
to lose the race. iOS then delivers the same URL again through that callback,
so `launchDocumentURI` drops the replay exactly once — a genuine re-open of the
same document later still works.

Reading early is not enough on its own, because the app still cannot decide
where to go without the readiness check, and on a cold start that check parses
every stored session looking for an unfinished ARU deployment. So the listener
holds the launch. `_LaunchFrameHold` wraps `deferFirstFrame`/`allowFirstFrame`:
the system launch screen stays up — frames are still built and laid out, only
compositing waits — and every path out of the handler releases it once the
destination is settled. The blocked-dialog path releases *before* awaiting the
dialog, which needs a screen behind it and stays up until dismissed. A
five-second timer is the backstop: a launch that never paints is worse than one
that paints Home.

The route pushed for a launch hand-off is an `_InstantMaterialPageRoute`, with
no entry transition. There is no previous screen to animate away from, and
animating one in would put Home on display for the length of the transition —
the exact thing this avoids. Home stays underneath so Back has somewhere to go,
and leaving the screen animates normally.

A cold start also replays a widget tap through the channel buffer, so
`_handleQuickAction` receives it twice. The launch delivery sets the reentrancy
guard synchronously, before the buffered copy can be drained, and only that
delivery owns the frame hold — otherwise the duplicate would let the app paint
while the real one was still deciding.

None of this applies to a warm hand-off: the app is already on screen, so it
arrives through the channel notification and pushes with the ordinary
transition from wherever the user was.

## Android

Two intent filters on `MainActivity`, both scoped to `audio/*`:

- `ACTION_SEND` — the share sheet.
- `ACTION_VIEW` — a file manager's "open with". No `BROWSABLE` category, so a
  web page cannot launch File Analysis.

`audio/*` is a deliberate limit. File managers that share every file as
`application/octet-stream` would otherwise put BirdNET Live in the share sheet
for PDFs and ZIPs.

`captureSharedMedia` remembers the URI and clears the intent's payload so an
activity re-creation does not replay the same share. `importSharedMedia` copies
into `cacheDir/shared_audio`. No storage permission is involved — the intent
carries a read grant for the URI.

The payload is captured before `FlutterActivity.onCreate`/`onNewIntent`, and
Flutter deep-link handling is disabled for `MainActivity`. Otherwise the
embedding interprets an audio `content://` URL as a named Flutter route before
the shared-media channel can consume it.

## iOS

iOS needs two mechanisms, because neither covers the whole surface on its own.

### Share extension (the main path)

The `ShareExtension` target puts BirdNET Live in the share sheet itself. It has
no UI: it copies the attachment into the shared App Group container and
dismisses. The user then opens or returns to BirdNET Live; AppDelegate scans the
staging directory on activation and queues the newest attachment.

Notes on the pieces that are not obvious:

- **App Group** — an extension cannot write into the host app's container, so
  the App Group carries the attachment across the sandbox boundary.
  `group.de.tu-chemnitz.mi.kahst.birdnet-live` is
  declared in `Runner/Runner.entitlements` and
  `ShareExtension/ShareExtension.entitlements`; all three strings must match.
- **Host-app activation** — iOS Share extensions cannot open their containing
  app; Apple's [`NSExtensionContext.open` documentation](<https://developer.apple.com/documentation/foundation/nsextensioncontext/open(_:completionhandler:)>)
  lists only Today and iMessage as supported iOS extension points. Do not reach
  `UIApplication` through the responder chain: it is an extension-unsafe
  workaround and an App Store review risk. The app instead checks the App Group
  during cold launch and every activation.
- **Activation rule** — a `SUBQUERY` predicate over `public.audio`. The
  count-based activation keys (`…SupportsFileWithMaxCount`) would also match
  images and PDFs.
- **No Flutter, no pods** — the extension links neither. It has a tight memory
  budget, and the engine would risk the system killing it before the hand-off.
- **Staging lifetime** — the App Group container is not a cache, so the system
  never prunes it. The host app deletes the staged copy once it imports *or*
  once it gives up on it (`discardSharedFile`), and the extension empties the
  directory before each new share, so nothing survives an abandoned share.
  `AppDelegate.removeStagedFile` is what both paths call, and it only touches
  the two directories the app owns — anything else was handed to us by someone
  who is still responsible for it. Staged
  names carry a UUID prefix so repeated shares of the same source filename are
  still distinct deliveries; File Analysis sees the original name. The
  extension copies to a hidden temporary path and atomically publishes the
  final file, so an extension timeout cannot expose a partial recording.
- **Versions** — the extension's `CFBundleShortVersionString` and
  `CFBundleVersion` must match the host app exactly or App Store validation
  rejects the build. `Flutter/Generated.xcconfig` is the target's base
  configuration, so `$(FLUTTER_BUILD_NAME)` and `$(FLUTTER_BUILD_NUMBER)`
  resolve the same way they do for Runner. Nothing to bump by hand.

### Document types (the fallback)

`CFBundleDocumentTypes` in `Runner/Info.plist` covers Files' "Open With" and
share sources that hand over a document rather than going through an extension.
`LSSupportsOpeningDocumentsInPlace` stays `false`: analysis re-reads the file
while drawing the spectrogram, so a copy we own is safer than a reference to a
document the source app may move or delete mid-run. The cost of that choice is
that iOS drops its copy into `Documents/Inbox`, which counts against the user's
storage and is backed up — hence the discard path.

Both paths converge on `pendingSharedFile` in `AppDelegate`.

## One-time provisioning setup

The App Group is a capability, so it has to exist in the developer portal
before a device build will sign:

1. In the Apple Developer portal, register the App Group
   `group.de.tu-chemnitz.mi.kahst.birdnet-live` if it does not exist.
2. Register the extension's bundle ID,
   `de.tu-chemnitz.mi.kahst.birdnet-live.ShareExtension`.
3. Enable the **App Groups** capability on *both* that ID and
   `de.tu-chemnitz.mi.kahst.birdnet-live`, and tick the group on each.
4. Let Xcode regenerate the provisioning profiles (automatic signing handles
   this once the capability is enabled on the IDs).

A build that fails with "Provisioning profile doesn't include the
com.apple.security.application-groups entitlement" means step 3 is incomplete.

## Testing

The share path cannot be exercised from the host test VM: `Platform.isAndroid`
and `Platform.isIOS` are both false there, so `SharedMediaService` short-circuits.
`test/shared/services/shared_media_service_test.dart` covers what remains
platform-independent — the `importSharedFile` channel contract and the route
presence tracking that decides whether a second share replaces an open wizard.

On device, worth covering both entry states:

- **Android cold** — force-quit the app, then share. The pending item is drained
  by `_SharedAudioListener.initState`.
- **Android warm** — leave the app running, then share. The native side notifies
  over the channel.
- **iOS Share extension** — share from another app, then open or return to
  BirdNET Live. AppDelegate discovers the staged item during activation.
- **iOS Open With** — open an audio document with BirdNET Live and verify the
  direct document URL is handled immediately.

Also worth a pass: sharing while a File Analysis run is in progress (expect the
"Analysis in progress" dialog, and the running analysis untouched), and sharing
twice in a row (expect the file to swap in the open wizard rather than stacking
a second one).
