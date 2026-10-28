# BirdNET Live drop server

A write-only WebDAV endpoint that collects session uploads from BirdNET Live
(Settings › Export & Sync › Upload destinations, issue #284). Standard library
Python 3.11+, one file, no database. Contributors can create folders and write
files under their own folder of one project and nothing else; an admin token
can list and read. Nothing is ever overwritten or deleted over HTTP.

You do not need this server to collect uploads: a Nextcloud or ownCloud
**File Drop** share behaves the same way and the app converts its share link
automatically. Run this when you have no Nextcloud, want per-contributor
tokens you can revoke, or want the `collect` command's CSV output.

## Quick start

```bash
cd tools/webdav_drop_server
python drop_server.py init --root ./data --base-url https://drop.example.org
python drop_server.py create-project spring2027 --name "Spring Survey 2027"
python drop_server.py invite spring2027 --label "Team A"      # prints the join link + QR
python drop_server.py serve --host 127.0.0.1 --port 8080       # behind a TLS proxy
python drop_server.py collect spring2027 --out ./spring2027    # sessions.csv, detections.csv, species_summary.csv
```

`init` prints the admin secret once; store it. Every `invite` prints a join
link that carries the contributor's secret in the URL fragment, which browsers
never send to a web host. **Treat the link and its QR code like a password:**
hand them to contributors directly, do not post them, and `revoke` a token
when a link leaks. Install `segno` (`pip install segno`) for a terminal QR and
`--png` output; without it the link alone is printed.

Contributors paste the link (or scan the QR with their camera) in the app,
which runs a connection test and registers the device before saving.

## Protocol

The app and `conformance.py` speak the same subset of WebDAV:

| Method | Contributor | Admin | Notes |
| --- | --- | --- | --- |
| `OPTIONS` | yes | yes | `DAV: 1`, `Allow` lists the permitted methods |
| `MKCOL` | yes | yes | 201 created, 405 already exists, 409 parent missing |
| `PUT` | yes | yes | 201 created, **412 if the path exists** (immutable), 413 over `max_file_mb` |
| `HEAD` | yes | yes | 200 / 404 |
| `PROPFIND` | 403 | 207 | depth 0 or 1, minimal multistatus |
| `GET` | 403 | 200 | |
| `DELETE`, `MOVE`, `COPY`, `PROPPATCH` | 403 | 403 | never over HTTP |

Authentication is HTTP Basic: user name = token id, password = secret. The
server stores only salted SHA-256 hashes and compares them in constant time.
Each token is bound to one project; its requests land under
`<root>/<project>/<token id>/`, whatever path the client sends, and `..`,
backslashes, and odd characters are refused. A per-token rate limit
(`rate_per_minute`, default 600) answers 429 when exceeded.

Layout written by the app:

```
<root>/<project>/<token id>/
  _joined/<deviceId>-<stamp>.json               one per connection test
  <deviceId>/<sessionUuid>/v<version>/session.json   the JSON export, always
  <deviceId>/<sessionUuid>/v<version>/<bundle>       what Share would produce (ZIP or single file)
  <deviceId>/<sessionUuid>/v<version>/_complete.json sizes + SHA-256; written last
```

`collect` only reads folders that hold `_complete.json`, takes the highest
version per session UUID, and merges `session.json` records into CSV files.
`--bundles` also copies every share bundle next to them.

## Deployment

Keep the server on `127.0.0.1` and put a TLS reverse proxy in front. The app
refuses plain HTTP outside private networks.

Caddy:

```
drop.example.org {
    reverse_proxy 127.0.0.1:8080
    request_body { max_size 600MB }
}
```

nginx:

```
server {
    listen 443 ssl;
    server_name drop.example.org;
    client_max_body_size 600m;
    location / { proxy_pass http://127.0.0.1:8080; proxy_request_buffering off; }
}
```

For a quick LAN test without a proxy, `serve --certfile cert.pem --keyfile key.pem`
enables TLS directly, and `--allow-plain-http` silences the warning for a
loopback test with `adb reverse`.

Run as a service user that owns `root` and the config file only. Back up the
data directory; the config file holds nothing secret beyond hashes.

## Checking any WebDAV server

```bash
python conformance.py https://cloud.example.org/public.php/webdav/ --user SHARE_TOKEN --secret SHARE_PASSWORD
```

prints one line per step and warns when the credential can list, read, or
delete, which means it is not write-only. Exit code 0 means the app's
"Test connection" would pass.

## Tests

```bash
python -I tools/webdav_drop_server/tests/test_drop_server.py
```
