#!/usr/bin/env python3
"""Probe a WebDAV endpoint the way BirdNET Live's "Test connection" does.

    python conformance.py https://cloud.example.org/public.php/webdav/ --user TOKEN --secret PW

Runs OPTIONS, MKCOL `_joined/`, PUT a registration record, HEAD it, then
PROPFIND and GET on the root. Exit code 0 means the app would accept the
destination; warnings name over-privileged credentials. Standard library only.
"""

from __future__ import annotations

import argparse
import base64
import http.client
import json
import ssl
import sys
import urllib.parse
from datetime import datetime, timezone

OK_PUT = {200, 201, 204, 412}


def request(url: str, method: str, auth: str, body: bytes = b"", headers: dict | None = None, timeout=20):
    parts = urllib.parse.urlsplit(url)
    conn_cls = http.client.HTTPSConnection if parts.scheme == "https" else http.client.HTTPConnection
    kwargs = {"timeout": timeout}
    if parts.scheme == "https":
        kwargs["context"] = ssl.create_default_context()
    conn = conn_cls(parts.hostname, parts.port, **kwargs)
    path = parts.path or "/"
    if parts.query:
        path += "?" + parts.query
    hdrs = {"User-Agent": "BirdNET-Live-conformance", "Content-Length": str(len(body))}
    if auth:
        hdrs["Authorization"] = auth
    hdrs.update(headers or {})
    conn.request(method, path, body=body, headers=hdrs)
    response = conn.getresponse()
    data = response.read()
    conn.close()
    return response.status, data


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("url", help="collection URL, ending in a slash")
    parser.add_argument("--user", default="")
    parser.add_argument("--secret", default="")
    parser.add_argument("--device-id", default="conformance")
    args = parser.parse_args(argv)

    base = args.url if args.url.endswith("/") else args.url + "/"
    auth = ""
    if args.user or args.secret:
        auth = "Basic " + base64.b64encode(f"{args.user}:{args.secret}".encode()).decode()
    failures = 0
    warnings = 0

    def report(level: str, text: str) -> None:
        nonlocal failures, warnings
        if level == "FAIL":
            failures += 1
        elif level == "WARN":
            warnings += 1
        print(f"[{level}] {text}")

    status, _ = request(base, "OPTIONS", auth)
    report("PASS" if status < 400 else "FAIL", f"OPTIONS {base} -> {status}")
    if status == 401:
        report("FAIL", "credentials rejected; nothing else can be checked")
        return 1

    status, _ = request(base + "_joined/", "MKCOL", auth)
    if status in (201, 405):
        report("PASS", f"MKCOL _joined/ -> {status} (folders allowed)")
        flat = False
    elif status in (403, 409, 400, 501):
        report("WARN", f"MKCOL _joined/ -> {status}; the app falls back to flat file names")
        flat = True
    else:
        report("FAIL", f"MKCOL _joined/ -> {status}")
        flat = True

    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    name = f"{args.device_id}-{stamp}.json"
    target = base + (f"_joined__{name}" if flat else f"_joined/{name}")
    record = json.dumps({"deviceId": args.device_id, "joinedAt": stamp, "app": "conformance"}).encode()
    status, _ = request(target, "PUT", auth, record, {"Content-Type": "application/json"})
    report("PASS" if status in OK_PUT else "FAIL", f"PUT registration -> {status}")

    status, _ = request(target, "HEAD", auth)
    report("PASS" if status < 500 else "WARN", f"HEAD registration -> {status} (informational)")

    body = b'<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>'
    status, _ = request(base, "PROPFIND", auth, body, {"Depth": "1", "Content-Type": "application/xml"})
    if status in (207, 200):
        report("WARN", f"PROPFIND -> {status}: this credential can LIST the collection (not write-only)")
    else:
        report("PASS", f"PROPFIND -> {status} (listing refused)")

    status, _ = request(base, "GET", auth)
    if status == 200:
        report("WARN", "GET root -> 200: this credential can READ (not write-only)")
    else:
        report("PASS", f"GET root -> {status} (reading refused)")

    status, _ = request(target, "DELETE", auth)
    if status in (200, 204):
        report("WARN", "DELETE -> succeeded: this credential can delete uploads")
    else:
        report("PASS", f"DELETE -> {status} (deleting refused)")

    print()
    print(f"{failures} failure(s), {warnings} warning(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
