"""Unit tests for drop_server.py: run with `python -I -m unittest discover tools/webdav_drop_server/tests`."""

from __future__ import annotations

import base64
import http.client
import json
import os
import sys
import tempfile
import threading
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import drop_server  # noqa: E402


class DropServerTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name) / "data"
        self.config_path = Path(self.tmp.name) / "drop_config.json"
        rc = drop_server.main(["--config", str(self.config_path), "init", "--root", str(root),
                               "--base-url", "https://drop.example.org"])
        self.assertEqual(rc, 0)
        rc = drop_server.main(["--config", str(self.config_path), "create-project", "spring", "--name", "Spring"])
        self.assertEqual(rc, 0)
        config = drop_server.load_config(self.config_path)
        # Mint a contributor token directly so the secret is known to the test.
        self.secret = "contributor-secret"
        self.token_id = "c-test"
        config["projects"]["spring"]["tokens"][self.token_id] = {
            "hash": drop_server.hash_secret(config["salt"], self.secret), "label": "t", "revoked": False,
        }
        self.admin_secret = "admin-secret"
        config["admin_token_hash"] = drop_server.hash_secret(config["salt"], self.admin_secret)
        config["rate_per_minute"] = 1000
        drop_server.save_config(self.config_path, config)
        self.config = config
        self.server = drop_server.make_server(config, "127.0.0.1", 0, self.config_path)
        self.port = self.server.server_address[1]
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.tmp.cleanup()

    def call(self, method, path, body=b"", user=None, secret=None, headers=None):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=10)
        hdrs = {"Content-Length": str(len(body))}
        user = self.token_id if user is None else user
        secret = self.secret if secret is None else secret
        if user:
            hdrs["Authorization"] = "Basic " + base64.b64encode(f"{user}:{secret}".encode()).decode()
        hdrs.update(headers or {})
        conn.request(method, path, body=body, headers=hdrs)
        response = conn.getresponse()
        data = response.read()
        conn.close()
        return response.status, data

    def test_contributor_round_trip_matches_the_app(self):
        self.assertEqual(self.call("OPTIONS", "/spring/")[0], 200)
        self.assertEqual(self.call("MKCOL", "/spring/_joined/")[0], 201)
        self.assertEqual(self.call("MKCOL", "/spring/_joined/")[0], 405)
        status, _ = self.call("PUT", "/spring/_joined/dev-1.json", b'{"deviceId":"dev-1"}')
        self.assertEqual(status, 201)
        self.assertEqual(self.call("HEAD", "/spring/_joined/dev-1.json")[0], 200)
        # Immutable: a second PUT on the same path is refused, bytes untouched.
        self.assertEqual(self.call("PUT", "/spring/_joined/dev-1.json", b"x")[0], 412)
        stored = Path(self.config["root"]) / "spring" / self.token_id / "_joined" / "dev-1.json"
        self.assertEqual(stored.read_bytes(), b'{"deviceId":"dev-1"}')
        # Write-only: listing, reading, deleting are refused.
        self.assertEqual(self.call("PROPFIND", "/spring/", headers={"Depth": "1"})[0], 403)
        self.assertEqual(self.call("GET", "/spring/_joined/dev-1.json")[0], 403)
        self.assertEqual(self.call("DELETE", "/spring/_joined/dev-1.json")[0], 403)

    def test_paths_are_confined_to_the_token_folder(self):
        self.assertEqual(self.call("PUT", "/spring/../other/x.json", b"x")[0], 403)
        self.assertEqual(self.call("PUT", "/spring/%2e%2e/x.json", b"x")[0], 403)
        self.assertEqual(self.call("PUT", "/spring/a/..%5cx.json", b"x")[0], 403)
        self.assertEqual(self.call("MKCOL", "/spring/")[0], 405)
        self.assertEqual(self.call("PUT", "/spring/", b"x")[0], 403)
        # Another project with the same token: refused.
        self.assertEqual(self.call("OPTIONS", "/autumn/")[0], 401)

    def test_bad_or_revoked_credentials_are_refused(self):
        self.assertEqual(self.call("OPTIONS", "/spring/", secret="wrong")[0], 401)
        self.assertEqual(self.call("OPTIONS", "/spring/", user="", secret="")[0], 401)
        rc = drop_server.main(["--config", str(self.config_path), "revoke", "spring", self.token_id])
        self.assertEqual(rc, 0)
        self.server.config = drop_server.load_config(self.config_path)
        self.assertEqual(self.call("OPTIONS", "/spring/")[0], 401)

    def test_admin_can_list_and_read(self):
        self.call("MKCOL", "/spring/_joined/")
        self.call("PUT", "/spring/_joined/dev-1.json", b"{}")
        status, body = self.call("PROPFIND", "/spring/", user="admin", secret=self.admin_secret,
                                 headers={"Depth": "1"})
        self.assertEqual(status, 207)
        self.assertIn(b"c-test", body)
        status, body = self.call("GET", f"/spring/{self.token_id}/_joined/dev-1.json",
                                 user="admin", secret=self.admin_secret)
        self.assertEqual(status, 200)
        self.assertEqual(body, b"{}")
        self.assertEqual(self.call("PUT", "/spring/x.json", b"x", user="admin", secret="nope")[0], 401)

    def test_size_limit(self):
        self.server.max_bytes = 10
        self.assertEqual(self.call("PUT", "/spring/big.bin", b"x" * 11)[0], 413)
        self.assertEqual(self.call("PUT", "/spring/small.bin", b"x" * 10)[0], 201)

    def test_invite_prints_a_join_link_and_collect_merges_uploads(self):
        import io
        from contextlib import redirect_stdout

        out = io.StringIO()
        with redirect_stdout(out):
            rc = drop_server.main(["--config", str(self.config_path), "invite", "spring", "--label", "Team A",
                                   "--no-qr"])
        self.assertEqual(rc, 0)
        link = [line for line in out.getvalue().splitlines() if line.startswith("https://")][0]
        self.assertIn("#v=1&kind=webdav&name=Spring&url=https%3A%2F%2Fdrop.example.org%2Fspring%2F&user=c-", link)
        self.assertIn("&secret=", link)
        self.assertIn("&wifi=1", link)
        # The secret is stored hashed only.
        config = drop_server.load_config(self.config_path)
        token_id = link.split("user=")[1].split("&")[0]
        self.assertNotIn(link.split("secret=")[1].split("&")[0], json.dumps(config))
        self.assertIn(token_id, config["projects"]["spring"]["tokens"])

        # Two uploads of one session: collect keeps the latest complete version.
        record_v1 = {"session": "Live #1", "type": "live", "startTime": "2026-10-28T08:00:00Z",
                     "detections": [{"commonName": "Eurasian Wren", "scientificName": "Troglodytes troglodytes",
                                     "confidence": 0.9, "timestamp": "2026-10-28T08:01:00Z"}]}
        record_v2 = dict(record_v1, detections=record_v1["detections"] * 2)
        for version, record in ((1, record_v1), (2, record_v2)):
            base = f"/spring/dev-1/uuid-1/v{version}/"
            for folder in ("/spring/dev-1/", "/spring/dev-1/uuid-1/", base):
                self.call("MKCOL", folder)
            self.assertEqual(self.call("PUT", base + "session.json", json.dumps(record).encode())[0], 201)
            self.assertEqual(self.call("PUT", base + "bundle.zip", b"zip")[0], 201)
            self.assertEqual(self.call("PUT", base + "_complete.json",
                                       json.dumps({"uploadedAt": f"2026-10-28T09:0{version}:00Z",
                                                   "appVersion": "1.2.1"}).encode())[0], 201)
        # An unfinished upload (no marker) is ignored.
        self.call("MKCOL", "/spring/dev-1/uuid-2/")
        self.call("MKCOL", "/spring/dev-1/uuid-2/v1/")
        self.call("PUT", "/spring/dev-1/uuid-2/v1/session.json", b"{}")

        out_dir = Path(self.tmp.name) / "export"
        stats = drop_server.collect(Path(self.config["root"]) / "spring", out_dir)
        self.assertEqual(stats, {"sessions": 1, "detections": 2, "species": 1})
        sessions = (out_dir / "sessions.csv").read_text(encoding="utf-8").splitlines()
        self.assertEqual(len(sessions), 2)
        self.assertIn("uuid-1,Live #1,live", sessions[1])
        self.assertIn(",2,", sessions[1])  # version 2 won
        summary = (out_dir / "species_summary.csv").read_text(encoding="utf-8").splitlines()
        self.assertEqual(summary[1], "Troglodytes troglodytes,Eurasian Wren,2,1")


if __name__ == "__main__":
    unittest.main()
