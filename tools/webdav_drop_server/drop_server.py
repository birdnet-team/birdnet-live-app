#!/usr/bin/env python3
"""BirdNET Live drop server: a write-only WebDAV endpoint for session uploads.

Standard library only. Contributors get a token that can create folders and
write files under their own folder of one project and nothing else; an admin
token can list and read. Nothing is ever overwritten or deleted over HTTP.

    python drop_server.py init --root ./data --base-url https://drop.example.org
    python drop_server.py create-project spring2027 --name "Spring Survey 2027"
    python drop_server.py invite spring2027 --label "Team A"
    python drop_server.py serve --port 8080
    python drop_server.py collect spring2027 --out ./spring2027-export

See README.md next to this file for deployment behind a TLS reverse proxy and
the exact protocol the app speaks (issue #284).
"""

from __future__ import annotations

import argparse
import base64
import csv
import hashlib
import hmac
import json
import os
import re
import secrets
import shutil
import ssl
import sys
import threading
import time
import urllib.parse
import uuid
import zipfile
from collections import defaultdict, deque
from xml.sax.saxutils import escape as xml_escape
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

CONTRIBUTOR_METHODS = ("OPTIONS", "MKCOL", "PUT", "HEAD")
ADMIN_METHODS = CONTRIBUTOR_METHODS + ("PROPFIND", "GET")
ADMIN_ID = "admin"
DEFAULT_CONFIG = "drop_config.json"
JOIN_LINK_BASE = "https://birdnet-team.github.io/birdnet-live-app/join"
# A leading dot is allowed for the app's hidden `.birdnet-live` folder; `.`
# and `..` themselves are refused separately.
SEGMENT_RE = re.compile(r"^[A-Za-z0-9_.][A-Za-z0-9._#@()\[\]+=,& -]{0,254}$")
SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,62}$")


# ── Config ───────────────────────────────────────────────────────────────────


def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_config(path: Path) -> dict:
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def save_config(path: Path, config: dict) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(config, indent=2), encoding="utf-8")
    os.replace(tmp, path)


def hash_secret(salt: str, secret: str) -> str:
    return hashlib.sha256((salt + ":" + secret).encode("utf-8")).hexdigest()


def new_secret() -> str:
    return secrets.token_urlsafe(24)


def verify(config: dict, project: dict | None, token_id: str, secret: str) -> str | None:
    """Returns 'admin', 'contributor', or None."""
    salt = config["salt"]
    digest = hash_secret(salt, secret)
    if token_id == ADMIN_ID:
        if hmac.compare_digest(digest, config.get("admin_token_hash", "")):
            return "admin"
        return None
    if project is None:
        return None
    token = project.get("tokens", {}).get(token_id)
    if token is None or token.get("revoked"):
        return None
    expires = token.get("expires")
    if expires and expires < now_iso():
        return None
    if hmac.compare_digest(digest, token.get("hash", "")):
        return "contributor"
    return None


# ── Server ───────────────────────────────────────────────────────────────────


class RateLimiter:
    def __init__(self, per_minute: int) -> None:
        self.per_minute = per_minute
        self._hits: dict[str, deque] = defaultdict(deque)
        self._lock = threading.Lock()

    def allow(self, key: str) -> bool:
        now = time.monotonic()
        with self._lock:
            hits = self._hits[key]
            while hits and hits[0] < now - 60:
                hits.popleft()
            if len(hits) >= self.per_minute:
                return False
            hits.append(now)
            return True


class DropServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, address, config: dict, config_path: Path | None = None):
        super().__init__(address, DropHandler)
        self.config = config
        self.config_path = config_path
        self.config_mtime = config_path.stat().st_mtime_ns if config_path and config_path.exists() else None
        self.root = Path(config["root"]).resolve()
        self.max_bytes = int(config.get("max_file_mb", 512)) * 1024 * 1024
        self.limiter = RateLimiter(int(config.get("rate_per_minute", 600)))
        # Unauthenticated requests are throttled per client address so a
        # guesser burns its own budget, not a contributor's.
        self.ip_limiter = RateLimiter(int(config.get("rate_per_minute", 600)))
        self._reload_lock = threading.Lock()

    def refresh_config(self) -> None:
        """Picks up `invite` / `revoke` edits without a restart."""
        path = self.config_path
        if path is None:
            return
        try:
            mtime = path.stat().st_mtime_ns
        except OSError:
            return
        if mtime == self.config_mtime:
            return
        with self._reload_lock:
            if mtime == self.config_mtime:
                return
            try:
                self.config = load_config(path)
                self.config_mtime = mtime
            except (OSError, ValueError):
                pass  # a half-written file; keep the last good config

    def project(self, slug: str) -> dict | None:
        return self.config.get("projects", {}).get(slug)


class DropHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "BirdNET-Drop/1.0"
    server: DropServer

    # Silence the default stderr logging; we log one line per request below.
    def log_message(self, fmt, *args):  # noqa: D401
        return

    def _log(self, status: int, who: str) -> None:
        sys.stdout.write(f"{now_iso()} {self.client_address[0]} {who} {self.command} {self.path} -> {status}\n")
        sys.stdout.flush()

    def _reply(self, status: int, body: bytes = b"", headers: dict | None = None, who: str = "-") -> None:
        self.send_response(status)
        for key, value in (headers or {}).items():
            self.send_header(key, value)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body and self.command != "HEAD":
            self.wfile.write(body)
        self._log(status, who)

    def _drain(self) -> None:
        length = int(self.headers.get("Content-Length") or 0)
        while length > 0:
            chunk = self.rfile.read(min(length, 65536))
            if not chunk:
                break
            length -= len(chunk)

    def _deny(self) -> None:
        length = int(self.headers.get("Content-Length") or 0)
        if length > 65536:
            self.close_connection = True
        else:
            self._drain()
        self._reply(401, headers={"WWW-Authenticate": 'Basic realm="BirdNET drop"'})

    def _credentials(self) -> tuple[str, str] | None:
        header = self.headers.get("Authorization", "")
        if not header.startswith("Basic "):
            return None
        try:
            raw = base64.b64decode(header[6:].strip()).decode("utf-8")
        except (ValueError, UnicodeDecodeError):
            return None
        user, _, secret = raw.partition(":")
        return user, secret

    def _route(self):
        """Resolves the request to (role, project slug, token id, local path).

        Returns None after replying with an error.
        """
        self.server.refresh_config()
        if not self.server.ip_limiter.allow(self.client_address[0]):
            self.close_connection = True
            self._reply(429)
            return None
        url = urllib.parse.urlsplit(self.path)
        segments = [urllib.parse.unquote(s) for s in url.path.split("/") if s]
        if not segments:
            self._drain()
            self._reply(404)
            return None
        slug, rest = segments[0], segments[1:]
        project = self.server.project(slug)
        creds = self._credentials()
        if creds is None:
            self._deny()
            return None
        token_id, secret = creds
        role = verify(self.server.config, project, token_id, secret)
        if role is None or project is None:
            self._deny()
            return None
        if not self.server.limiter.allow(f"{slug}/{token_id}"):
            self._drain()
            self._reply(429, who=token_id)
            return None
        for segment in rest:
            if segment in (".", "..") or not SEGMENT_RE.match(segment) or "\\" in segment:
                self._drain()
                self._reply(403, who=token_id)
                return None
        # Contributors live under their token's folder; admins see the project.
        base = self.server.root / slug
        if role == "contributor":
            base = base / token_id
            base.mkdir(parents=True, exist_ok=True)
        local = base.joinpath(*rest) if rest else base
        try:
            local.resolve().relative_to(base.resolve())
        except ValueError:
            self._drain()
            self._reply(403, who=token_id)
            return None
        self._segments = [slug, *rest]
        return role, slug, token_id, local, bool(url.path.endswith("/"))

    # ── Methods ──────────────────────────────────────────────────────────

    def do_OPTIONS(self):
        routed = self._route()
        if routed is None:
            return
        role, _, token_id, _, _ = routed
        self._drain()
        allow = ", ".join(ADMIN_METHODS if role == "admin" else CONTRIBUTOR_METHODS)
        self._reply(200, headers={"DAV": "1", "Allow": allow}, who=token_id)

    def do_MKCOL(self):
        routed = self._route()
        if routed is None:
            return
        _, _, token_id, local, _ = routed
        self._drain()
        if local.exists():
            self._reply(405, who=token_id)
            return
        if not local.parent.exists():
            self._reply(409, who=token_id)
            return
        local.mkdir()
        self._reply(201, who=token_id)

    def do_PUT(self):
        routed = self._route()
        if routed is None:
            return
        _, _, token_id, local, is_dir = routed
        if "chunked" in self.headers.get("Transfer-Encoding", "").lower() or not self.headers.get("Content-Length"):
            self.close_connection = True
            self._reply(411, who=token_id)
            return
        length = int(self.headers.get("Content-Length") or 0)
        if is_dir or local == self.server.root or local.parent == self.server.root:
            self._drain()
            self._reply(403, who=token_id)
            return
        if length > self.server.max_bytes:
            self._drain()
            self._reply(413, who=token_id)
            return
        if local.is_dir():
            self._drain()
            self._reply(409, who=token_id)
            return
        local.parent.mkdir(parents=True, exist_ok=True)
        # Each upload streams into its own temp file and is published with an
        # atomic rename, so a reader never sees a half-written file and two
        # uploads of one path cannot interleave: the last one to finish wins.
        # A contributor may replace their own files; that is how the app
        # re-uploads a session after an edit.
        existed = local.exists()
        tmp = local.with_name(f".{local.name}.{uuid.uuid4().hex}.part")
        remaining = length
        try:
            with tmp.open("wb") as out:
                while remaining > 0:
                    chunk = self.rfile.read(min(remaining, 1 << 20))
                    if not chunk:
                        raise ConnectionError("client closed early")
                    out.write(chunk)
                    remaining -= len(chunk)
            os.replace(tmp, local)
        except (ConnectionError, OSError):
            tmp.unlink(missing_ok=True)
            self.close_connection = True
            self._reply(500, who=token_id)
            return
        self._reply(204 if existed else 201, who=token_id)

    def do_HEAD(self):
        routed = self._route()
        if routed is None:
            return
        _, _, token_id, local, _ = routed
        if local.is_file():
            self._reply(200, headers={"Content-Length-Hint": str(local.stat().st_size)}, who=token_id)
        elif local.is_dir():
            self._reply(200, who=token_id)
        else:
            self._reply(404, who=token_id)

    def do_GET(self):
        routed = self._route()
        if routed is None:
            return
        role, _, token_id, local, _ = routed
        if role != "admin":
            self._reply(403, who=token_id)
            return
        if not local.is_file():
            self._reply(404, who=token_id)
            return
        self._reply(200, local.read_bytes(), {"Content-Type": "application/octet-stream"}, who=token_id)

    def do_PROPFIND(self):
        routed = self._route()
        if routed is None:
            return
        role, _, token_id, local, _ = routed
        self._drain()
        if role != "admin":
            self._reply(403, who=token_id)
            return
        if not local.exists():
            self._reply(404, who=token_id)
            return
        depth = self.headers.get("Depth", "1")
        entries = [local]
        if depth != "0" and local.is_dir():
            entries.extend(sorted(local.iterdir()))
        base_path = "/" + "/".join(urllib.parse.quote(s, safe="") for s in self._segments)
        parts = ['<?xml version="1.0" encoding="utf-8"?>', '<d:multistatus xmlns:d="DAV:">']
        for entry in entries:
            rel = "" if entry == local else "/" + urllib.parse.quote(entry.name, safe="")
            href = xml_escape(base_path + rel + ("/" if entry.is_dir() else ""))
            kind = "<d:collection/>" if entry.is_dir() else ""
            size = "" if entry.is_dir() else f"<d:getcontentlength>{entry.stat().st_size}</d:getcontentlength>"
            parts.append(
                f"<d:response><d:href>{href}</d:href><d:propstat><d:prop>"
                f"<d:resourcetype>{kind}</d:resourcetype>{size}</d:prop>"
                "<d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>"
            )
        parts.append("</d:multistatus>")
        self._reply(207, "".join(parts).encode("utf-8"), {"Content-Type": "application/xml; charset=utf-8"}, who=token_id)

    def _refuse(self):
        routed = self._route()
        if routed is None:
            return
        _, _, token_id, _, _ = routed
        self._drain()
        self._reply(403, who=token_id)

    do_DELETE = _refuse
    do_MOVE = _refuse
    do_COPY = _refuse
    do_PROPPATCH = _refuse
    do_POST = _refuse
    do_LOCK = _refuse
    do_UNLOCK = _refuse


def make_server(config: dict, host: str, port: int, config_path: Path | None = None,
                certfile: str | None = None, keyfile: str | None = None) -> DropServer:
    server = DropServer((host, port), config, config_path)
    if certfile:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(certfile, keyfile)
        server.socket = context.wrap_socket(server.socket, server_side=True)
    return server


# ── CLI commands ─────────────────────────────────────────────────────────────


def cmd_init(args) -> int:
    path = Path(args.config)
    if path.exists() and not args.force:
        print(f"{path} exists; use --force to overwrite", file=sys.stderr)
        return 1
    admin_secret = new_secret()
    salt = secrets.token_hex(16)
    config = {
        "root": args.root,
        "base_url": args.base_url.rstrip("/"),
        "salt": salt,
        "admin_token_hash": hash_secret(salt, admin_secret),
        "max_file_mb": 512,
        "rate_per_minute": 600,
        "projects": {},
    }
    Path(args.root).mkdir(parents=True, exist_ok=True)
    save_config(path, config)
    print(f"Config written to {path}")
    print(f"Admin user name: {ADMIN_ID}")
    print(f"Admin secret (shown once, store it safely): {admin_secret}")
    return 0


def cmd_create_project(args) -> int:
    if not SLUG_RE.match(args.slug):
        print("slug must be lowercase letters, digits, and dashes", file=sys.stderr)
        return 1
    path = Path(args.config)
    config = load_config(path)
    projects = config.setdefault("projects", {})
    if args.slug in projects:
        print("project exists", file=sys.stderr)
        return 1
    projects[args.slug] = {"name": args.name or args.slug, "created": now_iso(), "tokens": {}}
    (Path(config["root"]) / args.slug).mkdir(parents=True, exist_ok=True)
    save_config(path, config)
    print(f"Project '{args.slug}' created. WebDAV URL: {config['base_url']}/{args.slug}/")
    return 0


def join_link(config: dict, slug: str, token_id: str, secret: str, *, audio: bool, wifi: bool) -> str:
    project = config["projects"][slug]
    params = {
        "v": "1",
        "kind": "webdav",
        "name": project.get("name", slug),
        "url": f"{config['base_url']}/{slug}/",
        "user": token_id,
        "secret": secret,
        "audio": "1" if audio else "0",
        "wifi": "1" if wifi else "0",
    }
    return JOIN_LINK_BASE + "#" + urllib.parse.urlencode(params)


def print_qr(text: str) -> None:
    try:
        import segno  # type: ignore

        segno.make(text, error="m").terminal(compact=True)
        return
    except ImportError:
        pass
    try:
        import qrcode  # type: ignore

        qr = qrcode.QRCode(border=1)
        qr.add_data(text)
        qr.print_ascii(invert=True)
        return
    except ImportError:
        print("(install 'segno' or 'qrcode' to print a QR code here)")


def cmd_invite(args) -> int:
    path = Path(args.config)
    config = load_config(path)
    project = config.get("projects", {}).get(args.slug)
    if project is None:
        print("no such project", file=sys.stderr)
        return 1
    token_id = "c-" + secrets.token_hex(4)
    secret = new_secret()
    project.setdefault("tokens", {})[token_id] = {
        "hash": hash_secret(config["salt"], secret),
        "label": args.label or "",
        "created": now_iso(),
        "expires": args.expires,
        "revoked": False,
    }
    save_config(path, config)
    link = join_link(config, args.slug, token_id, secret, audio=args.audio, wifi=args.wifi)
    print(f"Token {token_id} ({args.label or 'no label'}) for project '{args.slug}'.")
    print("Join link (treat it like a password; the secret is only shown now):")
    print(link)
    print()
    if not args.no_qr:
        print_qr(link)
    if args.png:
        try:
            import segno  # type: ignore

            segno.make(link, error="m").save(args.png, scale=6)
            print(f"QR saved to {args.png}")
        except ImportError:
            print("(install 'segno' to write a PNG)")
    return 0


def cmd_revoke(args) -> int:
    path = Path(args.config)
    config = load_config(path)
    token = config.get("projects", {}).get(args.slug, {}).get("tokens", {}).get(args.token_id)
    if token is None:
        print("no such token", file=sys.stderr)
        return 1
    token["revoked"] = True
    token["revoked_at"] = now_iso()
    save_config(path, config)
    print(f"Token {args.token_id} revoked; its uploads stay on disk.")
    return 0


def cmd_list(args) -> int:
    config = load_config(Path(args.config))
    for slug, project in config.get("projects", {}).items():
        if args.slug and slug != args.slug:
            continue
        print(f"{slug}: {project.get('name', slug)}  ({config['base_url']}/{slug}/)")
        for token_id, token in project.get("tokens", {}).items():
            state = "revoked" if token.get("revoked") else "active"
            print(f"  {token_id}  {state:8}  {token.get('label', '')}  created {token.get('created', '?')}")
    return 0


# ── collect ──────────────────────────────────────────────────────────────────


def _upload_bundles(project_dir: Path):
    """Yields (token_id, device_code, zip_path, record) for every readable upload.

    The app writes one ZIP per session under `<token>/<device code>/` and puts
    the session's JSON export inside it. A ZIP that does not open or holds no
    JSON record is still being written or was not made by the app and is
    skipped.
    """
    for zip_path in sorted(project_dir.glob("*/*/*.zip")):
        if zip_path.name.startswith("."):
            continue
        folder = zip_path.parent
        token_dir = folder.parent
        record = _session_record(zip_path)
        if record is None:
            continue
        yield token_dir.name, folder.name, zip_path, record


def _session_record(zip_path: Path) -> dict | None:
    try:
        with zipfile.ZipFile(zip_path) as bundle:
            if bundle.testzip() is not None:
                return None
            for name in bundle.namelist():
                if "/" in name or not name.endswith(".json") or name.endswith(".metadata.json"):
                    continue
                try:
                    record = json.loads(bundle.read(name).decode("utf-8"))
                except (ValueError, UnicodeDecodeError):
                    continue
                if isinstance(record, dict) and "uuid" in record and "detections" in record:
                    return record
    except (zipfile.BadZipFile, OSError):
        return None
    return None


def _participants(project_dir: Path) -> dict[tuple[str, str], str]:
    """(token id, device code) -> participant identifier from the registration files."""
    found = {}
    for path in project_dir.glob("*/.birdnet-live/*.json"):
        try:
            record = json.loads(path.read_text(encoding="utf-8"))
        except (ValueError, OSError):
            continue
        participant = record.get("participant") if isinstance(record, dict) else None
        if participant:
            found[(path.parent.parent.name, path.stem)] = str(participant)
    return found


def collect(project_dir: Path, out_dir: Path) -> dict:
    participants = _participants(project_dir)
    # One row per session UUID; a re-uploaded session keeps its newest file.
    latest: dict[str, tuple] = {}
    for token_id, folder, zip_path, record in _upload_bundles(project_dir):
        uuid_ = str(record.get("uuid", ""))
        if not uuid_:
            continue
        mtime = zip_path.stat().st_mtime
        current = latest.get(uuid_)
        if current is None or mtime > current[3]:
            latest[uuid_] = (token_id, folder, zip_path, mtime, record)

    out_dir.mkdir(parents=True, exist_ok=True)
    session_rows, detection_rows = [], []
    species: dict[tuple, dict] = {}
    for session_uuid, (token_id, folder, zip_path, mtime, record) in sorted(latest.items()):
        detections = record.get("detections") or []
        uploaded_at = datetime.fromtimestamp(mtime, tz=timezone.utc).isoformat(timespec="seconds")
        meta = record.get("meta") or {}
        # The record's own metadata wins; the registration file fills in for
        # uploads made before a participant was entered.
        participant = meta.get("participant") or participants.get((token_id, folder), "")
        session_rows.append({
            "sessionUuid": session_uuid,
            "session": record.get("session", ""),
            "type": record.get("type", "live"),
            "startTime": record.get("startTime", ""),
            "endTime": record.get("endTime", ""),
            "detections": len(detections),
            "latitude": record.get("latitude", ""),
            "longitude": record.get("longitude", ""),
            "locationName": record.get("locationName", ""),
            "observerName": record.get("observerName", ""),
            "contributor": token_id,
            "deviceCode": folder,
            "participant": participant,
            "uploadedAt": uploaded_at,
            "appVersion": meta.get("appVersion", ""),
            "file": str(zip_path.relative_to(project_dir)).replace(os.sep, "/"),
        })
        seen_in_session = set()
        for d in detections:
            key = (d.get("scientificName", ""), d.get("commonName", ""))
            entry = species.setdefault(key, {"detections": 0, "sessions": 0})
            entry["detections"] += 1
            if key not in seen_in_session:
                entry["sessions"] += 1
                seen_in_session.add(key)
            detection_rows.append({
                "sessionUuid": session_uuid,
                "timestamp": d.get("timestamp", ""),
                "beginTimeSec": d.get("beginTimeSec", ""),
                "commonName": d.get("commonName", ""),
                "scientificName": d.get("scientificName", ""),
                "confidence": d.get("confidence", ""),
                "latitude": d.get("latitude", ""),
                "longitude": d.get("longitude", ""),
                "reviewStatus": d.get("reviewStatus", ""),
                "source": d.get("source", ""),
                "contributor": token_id,
            })

    def guard(value):
        # Spreadsheets execute cells that start like formulas; contributor
        # text (observer names, notes) must not be able to do that.
        if isinstance(value, str) and value[:1] in ("=", "+", "-", "@", "\t", "\r"):
            return "'" + value
        return value

    def write(name: str, rows: list[dict], fields: list[str]) -> None:
        with (out_dir / name).open("w", newline="", encoding="utf-8") as fh:
            writer = csv.DictWriter(fh, fieldnames=fields)
            writer.writeheader()
            writer.writerows({k: guard(v) for k, v in row.items()} for row in rows)

    write("sessions.csv", session_rows, list(session_rows[0].keys()) if session_rows else [
        "sessionUuid", "session", "type", "startTime", "endTime", "detections", "latitude", "longitude",
        "locationName", "observerName", "contributor", "deviceCode", "participant", "uploadedAt", "appVersion", "file"])
    write("detections.csv", detection_rows, [
        "sessionUuid", "timestamp", "beginTimeSec", "commonName", "scientificName", "confidence",
        "latitude", "longitude", "reviewStatus", "source", "contributor"])
    summary = [
        {"scientificName": k[0], "commonName": k[1], "detections": v["detections"], "sessions": v["sessions"]}
        for k, v in sorted(species.items(), key=lambda kv: -kv[1]["detections"])
    ]
    write("species_summary.csv", summary, ["scientificName", "commonName", "detections", "sessions"])
    return {"sessions": len(session_rows), "detections": len(detection_rows), "species": len(summary)}


def cmd_collect(args) -> int:
    config = load_config(Path(args.config))
    project_dir = Path(config["root"]) / args.slug
    if not project_dir.is_dir():
        print("no uploads for that project yet", file=sys.stderr)
        return 1
    stats = collect(project_dir, Path(args.out))
    print(f"{stats['sessions']} sessions, {stats['detections']} detections, {stats['species']} species -> {args.out}")
    if args.bundles:
        dest = Path(args.out) / "bundles"
        dest.mkdir(exist_ok=True)
        for token_id, folder, zip_path, _ in _upload_bundles(project_dir):
            target = dest / f"{folder}_{zip_path.name}"
            if target.exists():
                target = dest / f"{token_id}_{folder}_{zip_path.name}"
            shutil.copy2(zip_path, target)
        print(f"share bundles copied to {dest}")
    return 0


def cmd_serve(args) -> int:
    path = Path(args.config)
    config = load_config(path)
    server = make_server(config, args.host, args.port, path, args.certfile, args.keyfile)
    scheme = "https" if args.certfile else "http"
    print(f"BirdNET drop server on {scheme}://{args.host}:{args.port}/  root={config['root']}")
    if not args.certfile and not args.allow_plain_http:
        print("Plain HTTP: put this behind a TLS reverse proxy (see README) or pass --certfile/--keyfile.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--config", default=DEFAULT_CONFIG, help="config file (default: drop_config.json)")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("init", help="create a config file and the admin token")
    p.add_argument("--root", default="./data")
    p.add_argument("--base-url", required=True, help="public URL contributors reach, e.g. https://drop.example.org")
    p.add_argument("--force", action="store_true")
    p.set_defaults(func=cmd_init)

    p = sub.add_parser("create-project", help="add a project")
    p.add_argument("slug")
    p.add_argument("--name")
    p.set_defaults(func=cmd_create_project)

    p = sub.add_parser("invite", help="mint a contributor token and print its join link")
    p.add_argument("slug")
    p.add_argument("--label", help="who this token is for")
    p.add_argument("--expires", help="ISO date-time after which the token stops working")
    p.add_argument("--audio", action="store_true", help="suggest including audio")
    p.add_argument("--wifi", action="store_true", default=True, help="suggest Wi-Fi only (default)")
    p.add_argument("--no-wifi", dest="wifi", action="store_false")
    p.add_argument("--no-qr", action="store_true")
    p.add_argument("--png", help="also write the QR code to this PNG (needs 'segno')")
    p.set_defaults(func=cmd_invite)

    p = sub.add_parser("revoke", help="stop a token")
    p.add_argument("slug")
    p.add_argument("token_id")
    p.set_defaults(func=cmd_revoke)

    p = sub.add_parser("list", help="projects and tokens")
    p.add_argument("slug", nargs="?")
    p.set_defaults(func=cmd_list)

    p = sub.add_parser("collect", help="merge finished uploads into CSV files")
    p.add_argument("slug")
    p.add_argument("--out", required=True)
    p.add_argument("--bundles", action="store_true", help="also copy every share bundle")
    p.set_defaults(func=cmd_collect)

    p = sub.add_parser("serve", help="run the server")
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=8080)
    p.add_argument("--certfile")
    p.add_argument("--keyfile")
    p.add_argument("--allow-plain-http", action="store_true")
    p.set_defaults(func=cmd_serve)
    return parser


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
