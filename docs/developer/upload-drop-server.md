# Upload Destinations and the Drop Server

BirdNET Live can upload finalized sessions to one or more WebDAV
destinations so a project lead can collect field data from many phones
(issue #284). This page describes the protocol the app speaks, the reference
server shipped in `tools/webdav_drop_server/`, and the security model. The
user-facing side lives in the [Settings guide](../user/settings.md#upload-destinations).

## Shape of the feature

- **One-way.** The app only ever writes. Nothing is downloaded, nothing is
  deleted remotely, and deleting a session on the phone leaves the server
  copy alone.
- **Write-only credentials.** A contributor credential needs `OPTIONS`,
  `MKCOL`, `PUT`, and `HEAD`. It should not be able to `PROPFIND`, `GET`, or
  `DELETE`; the app's connection test warns when it can.
- **Any WebDAV server.** A Nextcloud or ownCloud File Drop share already has
  exactly these properties, and the app converts a share link
  (`https://host/s/TOKEN`) to its public WebDAV endpoint. The reference server
  exists for groups without Nextcloud and adds per-contributor tokens and a
  `collect` command.
- **Join link.** Contributors receive one link (or its QR code) that carries
  the endpoint, user name, secret, project name, and defaults in the URL
  fragment, which never reaches a web host. The parser in
  `lib/features/upload/join_link.dart` also accepts bare WebDAV URLs and
  Nextcloud share links.

## Code map

| Piece | Where |
| --- | --- |
| Destination model, keychain secret store, JSON list | `lib/features/upload/upload_destination*.dart`, `secret_store.dart` |
| Join-link parser | `lib/features/upload/join_link.dart` |
| Pre-save probe (same sequence as `conformance.py`) | `lib/features/upload/webdav_probe.dart` |
| Upload engine, queue store, job model | `lib/features/upload/upload_service.dart`, `upload_queue_store.dart`, `upload_job.dart` |
| Share dialog "Send to" tab | `lib/features/history/widgets/share_options_dialog.dart` |
| Library chip and status sheet | `lib/features/upload/upload_status_widgets.dart` |
| Native keychain halves | `SecureStoreChannel.kt`, `SecureStoreChannel.swift`, `secure_store_channel.cpp` |
| Native connectivity halves | `ConnectivityChannel.kt`, `ConnectivityChannel.swift` |

## What an upload writes

```
<collection>/<deviceId>/<sessionUuid>/v<version>/session.json    JSON export, always
<collection>/<deviceId>/<sessionUuid>/v<version>/<bundle>        Share output (ZIP or single file), if any
<collection>/<deviceId>/<sessionUuid>/v<version>/_complete.json  sizes + SHA-256, written last
```

`deviceId` is a random UUID per install (`PrefKeys.uploadDeviceId`),
`sessionUuid` the session's own UUID. A re-upload after an edit gets the next
version folder. Servers that refuse `MKCOL` get the same three files with the
folder path folded into the name (`<deviceId>__<uuid>__v1__session.json`).
A `412` on `PUT` is treated as "already there": the drop server refuses to
overwrite, and a retry after a kill between `PUT` and bookkeeping must not
fail.

The connection test writes `_joined/<deviceId>-<stamp>.json` so the project
lead sees which devices joined and when.

## Queue behavior

Jobs persist in `uploads.json` next to the destination list. A run is
triggered by enqueueing, app start, and return to foreground
(`_UploadQueueListener` in `app.dart`). Failed jobs back off 1, 2, 4 … minutes
up to six hours and give up after 30 attempts. Destinations with
"Upload on Wi-Fi only" wait while the device is on cellular; with no network
the run stops early.

On Android the queue also runs with the app closed: after every run the
service reports what is pending through `UploadWorkScheduler`
(`com.birdnet/upload_work`), and `UploadWorker.kt` enqueues one unique
WorkManager job with a `CONNECTED` or `UNMETERED` constraint. When it fires,
the worker starts a headless Flutter engine on `uploadQueueBackgroundMain`
(`upload_background.dart`), which builds the same providers as the app, runs
the queue once, and reports the remaining count so the worker retries with
backoff. `UploadQueueStore.tryLock` keeps the app and the worker from running
the queue at the same time. iOS has no background transfer yet; the queue
runs whenever the app is open or returns to the foreground.

## Reference server

`tools/webdav_drop_server/drop_server.py` is a standard-library HTTP server
with `init`, `create-project`, `invite`, `revoke`, `list`, `serve`, and
`collect` commands; `conformance.py` probes any endpoint the way the app
does. See the [README](https://github.com/birdnet-team/birdnet-live-app/tree/main/tools/webdav_drop_server)
there for deployment behind Caddy or nginx.

Security properties of the reference server:

- Tokens are stored as salted SHA-256 hashes and compared in constant time;
  each is bound to one project and lands under its own folder regardless of
  the path the client sends.
- Path segments are validated; `..`, backslashes, and control characters are
  refused.
- `PUT` to an existing path answers `412`; `DELETE`, `MOVE`, `COPY`, and
  `PROPPATCH` answer `403` for everyone.
- A per-token request-rate limit and a per-file size limit are configurable.
- The admin token can `PROPFIND` and `GET`; contributors cannot.
