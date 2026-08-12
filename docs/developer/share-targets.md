# Share Targets

BirdNET Live registers as a system share target for audio files on Android and
iOS. Shares and file-manager opens land immediately in File Analysis on both
platforms.

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

One mechanism: `CFBundleDocumentTypes` in `Runner/Info.plist`. It covers both
the system share sheet and Files' "Open With", and the app launches straight
into File Analysis. The document arrives as a copy in `Documents/Inbox`, which
`AppDelegate.application(_:open:)` queues and `importSharedFile` moves into the
temporary directory.

`LSSupportsOpeningDocumentsInPlace` stays `false`: analysis re-reads the file
while drawing the spectrogram, so a copy we own is safer than a reference to a
document the source app may move or delete mid-run. The cost of that choice is
that `Documents/Inbox` counts against the user's storage and is backed up —
hence the discard path.

### Why there is no Share extension

Version 1.1.2 shipped a `ShareExtension` target. It was removed in favor of the
above, because the two cannot coexist usefully:

- **A Share extension cannot open its containing app.** Apple's
  [`NSExtensionContext.open` documentation](<https://developer.apple.com/documentation/foundation/nsextensioncontext/open(_:completionhandler:)>)
  lists only Today and iMessage as eligible extension points, and DTS states
  plainly that there is no supported way to launch the container app. The
  extension could therefore only stage the file into an App Group and wait for
  the user to switch to BirdNET Live by hand, which read as the share having
  done nothing at all.
- **Its mere presence suppressed the alternative.** Since iOS 16 an app with a
  Share extension does not also get the "Open in app" entry that
  `CFBundleDocumentTypes` contributes, and that entry *does* launch the app.
  The extension was hiding the very behavior we wanted.
- The unsupported workarounds — walking the responder chain to `UIApplication`,
  or any private LaunchServices call — are not an option for an App Store
  build. (For the record: iOS 18 force-fails the deprecated `openURL:` reached
  that way, though the `options:completionHandler:` form still goes through.
  Both are outside what Apple supports.)

The trade-off accepted by removing it: a share source that hands over an
in-memory attachment rather than a file URL no longer offers BirdNET Live at
all. Every audio source checked in practice — Voice Memos, Files, Mail,
messaging apps — hands over a file.

### The App Group is legacy

`group.de.tu-chemnitz.mi.kahst.birdnet-live` in `Runner/Runner.entitlements`,
and everything in `AppDelegate` that reads it, exists only to drain a recording
the 1.1.2 extension staged before the user updated. Nothing writes there any
more; the container is not a cache, so an orphaned file would sit there
untouched forever. Remove `queueStagedSharedFile`, `stagedAppGroupFile`,
`stagedDisplayName`, the App Group branch of `removeStagedFile`, and the
entitlement once an update has had time to reach those users.

## One-time provisioning setup

Nothing, as long as the App Group entitlement above is still in place — it is a
capability, so `de.tu-chemnitz.mi.kahst.birdnet-live` must keep **App Groups**
enabled in the developer portal with `group.de.tu-chemnitz.mi.kahst.birdnet-live`
ticked, or a device build will not sign. A failure reading "Provisioning profile
doesn't include the com.apple.security.application-groups entitlement" means the
capability was turned off. When the legacy drain is deleted, this goes with it.

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
- **iOS share sheet** — share a recording from Voice Memos. BirdNET Live must
  appear in the app row and open straight into File Analysis. If the entry is
  missing, check that no Share extension has crept back into the build: one
  suppresses it.
- **iOS Open With** — open an audio document with BirdNET Live from Files and
  verify the direct document URL is handled immediately.

The receiving half can be driven without touching the screen, which is worth
knowing when the share sheet itself is not what is under test:

```
xcrun devicectl device copy to --device <id> --domain-type appDataContainer \
  --domain-identifier de.tu-chemnitz.mi.kahst.birdnet-live \
  --source some.mp3 --destination Documents/some.mp3
xcrun devicectl device process launch --device <id> --terminate-existing \
  --payload-url "file:///…/Documents/some.mp3" de.tu-chemnitz.mi.kahst.birdnet-live
```

A copy appearing under `tmp/shared_audio/` in the app container means the whole
chain ran: `application(_:open:)` queued it, Dart drained it, File Analysis
imported it.

Also worth a pass: sharing while a File Analysis run is in progress (expect the
"Analysis in progress" dialog, and the running analysis untouched), and sharing
twice in a row (expect the file to swap in the open wizard rather than stacking
a second one).
