import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:birdnet_live/features/upload/join_link.dart';
import 'package:birdnet_live/features/upload/webdav_probe.dart';

/// A scripted WebDAV server: returns the status for `METHOD path`, 404 for
/// anything unscripted, and records every request.
class _FakeServer {
  _FakeServer(this.routes);

  final Map<String, int> routes;
  final List<http.Request> requests = [];
  final Map<String, Map<String, String>> responseHeaders = {};

  http.Client get client => MockClient((request) async {
    requests.add(request);
    final key = '${request.method} ${request.url.path}';
    var status = routes[key];
    if (status == null) {
      for (final entry in routes.entries) {
        if (entry.key.endsWith('*') &&
            key.startsWith(entry.key.substring(0, entry.key.length - 1))) {
          status = entry.value;
          break;
        }
      }
    }
    status ??= 404;
    return http.Response('', status, headers: responseHeaders[key] ?? {});
  });

  http.Request? first(String method) {
    for (final r in requests) {
      if (r.method == method) return r;
    }
    return null;
  }
}

void main() {
  const deviceId = 'dev-1234';
  const registration = {'deviceId': deviceId};

  JoinRequest request({
    String url = 'https://cloud.example.org/public.php/webdav/',
    String username = 'token',
    String secret = 'pw',
    JoinLinkSource source = JoinLinkSource.joinLink,
  }) =>
      JoinRequest(url: url, username: username, secret: secret, source: source);

  Future<ProbeResult> run(_FakeServer server, JoinRequest req) =>
      WebDavProbe(client: server.client)
          .run(req, deviceId: deviceId, registration: registration);

  group('WebDavProbe', () {
    test('passes a write-only server and writes the registration', () async {
      final server = _FakeServer({
        'OPTIONS /public.php/webdav/': 200,
        'MKCOL /public.php/webdav/_joined/': 201,
        'PUT /public.php/webdav/_joined/$deviceId-*': 201,
        'HEAD /public.php/webdav/_joined/$deviceId-*': 403,
        'PROPFIND /public.php/webdav/': 403,
      });

      final result = await run(server, request());

      expect(result.ok, isTrue);
      expect(result.warnings, isEmpty);
      expect(result.flatLayout, isFalse);
      expect(
        result.resolvedUrl,
        'https://cloud.example.org/public.php/webdav/',
      );
      final put = server.first('PUT')!;
      expect(put.headers['Authorization'], startsWith('Basic '));
      expect(put.headers['Content-Type'], contains('application/json'));
      expect(put.body, contains(deviceId));
      expect(
        put.url.path,
        matches(
          RegExp(
            r'^/public\.php/webdav/_joined/' +
                deviceId +
                r'-\d{8}T\d{6}Z\.json$',
          ),
        ),
      );
    });

    test('falls back to flat names when MKCOL is refused', () async {
      final server = _FakeServer({
        'OPTIONS /drop/': 200,
        'MKCOL /drop/_joined/': 403,
        'PUT /drop/_joined__$deviceId-*': 201,
        'PROPFIND /drop/': 405,
      });

      final result = await run(
        server,
        request(url: 'https://dav.example.org/drop/'),
      );

      expect(result.ok, isTrue);
      expect(result.flatLayout, isTrue);
    });

    test('warns when the credential can list the collection', () async {
      final server = _FakeServer({
        'OPTIONS /dav/': 200,
        'MKCOL /dav/_joined/': 405,
        'PUT /dav/_joined/$deviceId-*': 204,
        'PROPFIND /dav/': 207,
      });

      final result = await run(
        server,
        request(url: 'https://x.example.org/dav/'),
      );

      expect(result.ok, isTrue);
      expect(result.warnings, contains(ProbeWarning.canReadRemote));
    });

    test('warns about a Nextcloud share without a password', () async {
      final server = _FakeServer({
        'OPTIONS *': 200,
        'MKCOL *': 201,
        'PUT *': 201,
        'HEAD *': 200,
        'PROPFIND *': 403,
      });

      final result = await run(
        server,
        request(secret: '', source: JoinLinkSource.nextcloudShare),
      );

      expect(result.ok, isTrue);
      expect(result.warnings, contains(ProbeWarning.shareWithoutPassword));
    });

    test('maps 401 to unauthorized before uploading anything', () async {
      final server = _FakeServer({'OPTIONS *': 401});

      final result = await run(server, request());

      expect(result.ok, isFalse);
      expect(result.failure, ProbeFailure.unauthorized);
      expect(result.statusCode, 401);
      expect(server.first('PUT'), isNull);
    });

    test('maps 403 on PUT to uploadForbidden and 507 to quota', () async {
      final forbidden = _FakeServer({
        'OPTIONS *': 200,
        'MKCOL *': 201,
        'PUT *': 403,
      });
      expect(
        (await run(forbidden, request())).failure,
        ProbeFailure.uploadForbidden,
      );

      final full = _FakeServer({'OPTIONS *': 200, 'MKCOL *': 507});
      expect((await run(full, request())).failure, ProbeFailure.quotaExceeded);
    });

    test(
      'an immutable server answering 412 on the record still passes',
      () async {
        final server = _FakeServer({
          'OPTIONS *': 200,
          'MKCOL *': 405,
          'PUT *': 412,
          'PROPFIND *': 403,
        });

        final result = await run(server, request());

        expect(result.ok, isTrue);
      },
    );

    test('a web page URL that refuses PUT reads as notWebDav', () async {
      final server = _FakeServer({
        'OPTIONS *': 200,
        'MKCOL *': 405,
        'PUT *': 405,
      });

      final result = await run(server, request());

      expect(result.failure, ProbeFailure.notWebDav);
    });

    test('discovers the Nextcloud files endpoint for a bare URL', () async {
      final server = _FakeServer({
        'OPTIONS *': 200,
        'MKCOL *': 405,
        'PUT /_joined/$deviceId-*': 405,
        'PUT /remote.php/dav/files/alice/_joined/$deviceId-*': 201,
        'PROPFIND *': 403,
      });

      final result = await run(
        server,
        request(
          url: 'https://cloud.example.org/',
          username: 'alice',
          source: JoinLinkSource.webdavUrl,
        ),
      );

      expect(result.ok, isTrue);
      expect(
        result.resolvedUrl,
        'https://cloud.example.org/remote.php/dav/files/alice/',
      );
    });

    test('follows one redirect from OPTIONS to the real collection', () async {
      final server = _FakeServer({
        'OPTIONS /.well-known/webdav': 301,
        'OPTIONS /remote.php/dav/': 200,
        'MKCOL /remote.php/dav/_joined/': 201,
        'PUT /remote.php/dav/_joined/$deviceId-*': 201,
        'PROPFIND /remote.php/dav/': 403,
      });
      server.responseHeaders['OPTIONS /.well-known/webdav'] = {
        'location': '/remote.php/dav/',
      };

      final result = await run(
        server,
        request(url: 'https://cloud.example.org/.well-known/webdav'),
      );

      expect(result.ok, isTrue);
      expect(result.resolvedUrl, 'https://cloud.example.org/remote.php/dav/');
    });

    test('refuses plain HTTP to a public host without a request', () async {
      final server = _FakeServer({'OPTIONS *': 200});

      final result = await run(
        server,
        request(url: 'http://cloud.example.org/dav/'),
      );

      expect(result.failure, ProbeFailure.insecureHttp);
      expect(server.requests, isEmpty);
    });

    test('tolerates plain HTTP on the LAN with a warning', () async {
      final server = _FakeServer({
        'OPTIONS *': 200,
        'MKCOL *': 201,
        'PUT *': 201,
        'PROPFIND *': 403,
      });

      final result = await run(
        server,
        request(url: 'http://192.168.1.20/dav/'),
      );

      expect(result.ok, isTrue);
      expect(result.warnings, contains(ProbeWarning.insecureLan));
    });

    test('maps socket errors to hostNotFound or connectionFailed', () async {
      final lookup = MockClient((_) async {
        throw const SocketException(
          'Failed host lookup: nope.example.org',
          osError: OSError('', 11001),
        );
      });
      final refused = MockClient((_) async {
        throw const SocketException('Connection refused');
      });

      final r1 = await WebDavProbe(client: lookup)
          .run(request(), deviceId: deviceId, registration: registration);
      final r2 = await WebDavProbe(client: refused)
          .run(request(), deviceId: deviceId, registration: registration);

      expect(r1.failure, ProbeFailure.hostNotFound);
      expect(r2.failure, ProbeFailure.connectionFailed);
    });
  });

  group('WebDavProbe.isLanHost', () {
    test('recognizes private and loopback addresses', () {
      expect(WebDavProbe.isLanHost('localhost'), isTrue);
      expect(WebDavProbe.isLanHost('nas.local'), isTrue);
      expect(WebDavProbe.isLanHost('10.1.2.3'), isTrue);
      expect(WebDavProbe.isLanHost('172.20.0.1'), isTrue);
      expect(WebDavProbe.isLanHost('192.168.0.9'), isTrue);
      expect(WebDavProbe.isLanHost('127.0.0.1'), isTrue);
      expect(WebDavProbe.isLanHost('fd12::1'), isTrue);
    });

    test('rejects public addresses', () {
      expect(WebDavProbe.isLanHost('cloud.example.org'), isFalse);
      expect(WebDavProbe.isLanHost('8.8.8.8'), isFalse);
      expect(WebDavProbe.isLanHost('172.32.0.1'), isFalse);
    });
  });
}
