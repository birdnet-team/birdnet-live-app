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
        self.assertEqual(self.call("MKCOL", "/spring/.birdnet-live/")[0], 201)
        self.assertEqual(self.call("MKCOL", "/spring/.birdnet-live/")[0], 405)
        status, _ = self.call("PUT", "/spring/.birdnet-live/Stefan.json", b'{"deviceId":"dev-1"}')
        self.assertEqual(status, 201)
        self.assertEqual(self.call("HEAD", "/spring/.birdnet-live/Stefan.json")[0], 200)
        # A contributor may replace their own file: 204, new bytes.
        self.assertEqual(self.call("PUT", "/spring/.birdnet-live/Stefan.json", b"x")[0], 204)
        stored = Path(self.config["root"]) / "spring" / self.token_id / ".birdnet-live" / "Stefan.json"
        self.assertEqual(stored.read_bytes(), b"x")
        # Write-only: listing, reading, deleting are refused.
        self.assertEqual(self.call("PROPFIND", "/spring/", headers={"Depth": "1"})[0], 403)
        self.assertEqual(self.call("GET", "/spring/.birdnet-live/Stefan.json")[0], 403)
        self.assertEqual(self.call("DELETE", "/spring/.birdnet-live/Stefan.json")[0], 403)

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
        # The running server notices the edited config by itself.
        self.assertEqual(self.call("OPTIONS", "/spring/")[0], 401)

    def test_admin_can_list_and_read(self):
        self.call("MKCOL", "/spring/.birdnet-live/")
        self.call("PUT", "/spring/.birdnet-live/dev-1.json", b"{}")
        status, body = self.call("PROPFIND", "/spring/", user="admin", secret=self.admin_secret,
                                 headers={"Depth": "1"})
        self.assertEqual(status, 207)
        self.assertIn(b"c-test", body)
        status, body = self.call("GET", f"/spring/{self.token_id}/.birdnet-live/dev-1.json",
                                 user="admin", secret=self.admin_secret)
        self.assertEqual(status, 200)
        self.assertEqual(body, b"{}")
        self.assertEqual(self.call("PUT", "/spring/x.json", b"x", user="admin", secret="nope")[0], 401)

    def test_put_needs_a_content_length(self):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=10)
        auth = "Basic " + base64.b64encode(f"{self.token_id}:{self.secret}".encode()).decode()
        conn.putrequest("PUT", "/spring/chunked.bin")
        conn.putheader("Authorization", auth)
        conn.putheader("Transfer-Encoding", "chunked")
        conn.endheaders()
        conn.send(b"3\r\nabc\r\n0\r\n\r\n")
        self.assertEqual(conn.getresponse().status, 411)
        conn.close()

    def test_concurrent_puts_publish_one_whole_body(self):
        body_a, body_b = b"a" * 200000, b"b" * 200000
        results = []

        def put(body):
            results.append(self.call("PUT", "/spring/race.bin", body)[0])

        threads = [threading.Thread(target=put, args=(b,)) for b in (body_a, body_b)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        # Both succeed; whether the second sees 201 or 204 depends on timing.
        self.assertTrue(all(status in (201, 204) for status in results), results)
        stored = (Path(self.config["root"]) / "spring" / self.token_id / "race.bin").read_bytes()
        self.assertIn(stored, (body_a, body_b))
        leftovers = list((Path(self.config["root"]) / "spring" / self.token_id).glob(".race.bin.*"))
        self.assertEqual(leftovers, [])

    def test_propfind_escapes_hrefs(self):
        self.call("MKCOL", "/spring/a&b/")
        status, body = self.call("PROPFIND", f"/spring/{self.token_id}/", user="admin", secret=self.admin_secret,
                                 headers={"Depth": "1"})
        self.assertEqual(status, 207)
        self.assertIn(b"a%26b/", body)
        self.assertNotIn(b"a&b", body)

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

        # Two uploads of one session replace the ZIP; collect reads the record
        # inside the newest one.
        import io
        import zipfile

        def bundle(record):
            buffer = io.BytesIO()
            with zipfile.ZipFile(buffer, "w") as z:
                z.writestr("BirdNET_Live_2026-10-28_08-00-00_#1.json", json.dumps(record))
                z.writestr("BirdNET_Live_2026-10-28_08-00-00_#1.csv", "a,b\n")
            return buffer.getvalue()

        record_v1 = {"uuid": "uuid-1", "session": "Live #1", "type": "live",
                     "startTime": "2026-10-28T08:00:00Z", "meta": {"appVersion": "1.2.1"},
                     "detections": [{"commonName": "Eurasian Wren", "scientificName": "Troglodytes troglodytes",
                                     "confidence": 0.9, "timestamp": "2026-10-28T08:01:00Z"}]}
        record_v2 = dict(record_v1, detections=record_v1["detections"] * 2)
        self.call("MKCOL", "/spring/4ee91c8f/")
        path = "/spring/4ee91c8f/BirdNET_Live_2026-10-28_08-00-00_%231.zip"
        self.assertEqual(self.call("PUT", path, bundle(record_v1))[0], 201)
        self.assertEqual(self.call("PUT", path, bundle(record_v2))[0], 204)
        # A half-written or foreign ZIP is ignored.
        self.call("PUT", "/spring/4ee91c8f/broken.zip", b"not a zip")
        # The registration file names the participant behind the device code.
        self.call("MKCOL", "/spring/.birdnet-live/")
        self.call("PUT", "/spring/.birdnet-live/4ee91c8f.json",
                  json.dumps({"deviceCode": "4ee91c8f", "participant": "Stefan"}).encode())

        out_dir = Path(self.tmp.name) / "export"
        stats = drop_server.collect(Path(self.config["root"]) / "spring", out_dir)
        self.assertEqual(stats, {"sessions": 1, "detections": 2, "species": 1})
        sessions = (out_dir / "sessions.csv").read_text(encoding="utf-8").splitlines()
        self.assertEqual(len(sessions), 2)
        self.assertIn("uuid-1,Live #1,live", sessions[1])
        self.assertIn(",4ee91c8f,Stefan,", sessions[1])
        self.assertIn("4ee91c8f/BirdNET_Live_2026-10-28_08-00-00_#1.zip", sessions[1])
        summary = (out_dir / "species_summary.csv").read_text(encoding="utf-8").splitlines()
        self.assertEqual(summary[1], "Troglodytes troglodytes,Eurasian Wren,2,1")


if __name__ == "__main__":
    unittest.main()
