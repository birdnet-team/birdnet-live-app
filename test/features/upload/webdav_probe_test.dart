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
  const folder = 'Stefan';
  const registration = {'deviceId': 'dev-1234', 'name': folder};

  JoinRequest request({
    String url = 'https://cloud.example.org/public.php/webdav/',
    String username = 'token',
    String secret = 'pw',
    JoinLinkSource source = JoinLinkSource.joinLink,
  }) =>
      JoinRequest(url: url, username: username, secret: secret, source: source);

  Future<ProbeResult> run(_FakeServer server, JoinRequest req) =>
      WebDavProbe(client: server.client)
          .run(req, folder: folder, registration: registration);

  group('WebDavProbe', () {
    test('passes a write-only server and writes the registration', () async {
      final server = _FakeServer({
        'OPTIONS /public.php/webdav/': 200,
        'MKCOL /public.php/webdav/.birdnet-live/': 201,
        'PUT /public.php/webdav/.birdnet-live/$folder.json': 201,
        'HEAD /public.php/webdav/.birdnet-live/$folder.json': 403,
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
      expect(put.body, contains('dev-1234'));
      expect(put.url.path, '/public.php/webdav/.birdnet-live/Stefan.json');
    });

    test('the registration file name is percent-encoded', () async {
      final server = _FakeServer({
        'OPTIONS *': 200,
        'MKCOL *': 201,
        'PUT *': 201,
        'PROPFIND *': 403,
      });

      final result = await WebDavProbe(client: server.client).run(
        request(url: 'https://dav.example.org/drop/'),
        folder: 'Team A #2',
        registration: registration,
      );

      expect(result.ok, isTrue);
      expect(
        server.first('PUT')!.url.toString(),
        'https://dav.example.org/drop/.birdnet-live/Team%20A%20%232.json',
      );
    });

    test('falls back to flat names when MKCOL is refused', () async {
      final server = _FakeServer({
        'OPTIONS /drop/': 200,
        'MKCOL /drop/.birdnet-live/': 403,
        'PUT /drop/.birdnet-live__$folder.json': 201,
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
        'MKCOL /dav/.birdnet-live/': 405,
        'PUT /dav/.birdnet-live/$folder.json': 204,
        'PROPFIND /dav/': 207,
      });

      final result = await run(
        server,
        request(url: 'https://x.example.org/dav/'),
      );

      expect(result.ok, isTrue);
      expect(result.warnings, contains(ProbeWarning.canReadRemote));
    });

    test('warns about a listable Nextcloud share without a password', () async {
      final server = _FakeServer({
        'OPTIONS *': 200,
        'MKCOL *': 201,
        'PUT *': 201,
        'HEAD *': 200,
        'PROPFIND *': 207,
      });

      final result = await run(
        server,
        request(secret: '', source: JoinLinkSource.nextcloudShare),
      );

      expect(result.ok, isTrue);
      expect(result.warnings, {
        ProbeWarning.canReadRemote,
        ProbeWarning.shareWithoutPassword,
      });
    });

    test('a File Drop without a password is taken as deliberate', () async {
      final server = _FakeServer({
        'OPTIONS *': 405,
        'MKCOL *': 201,
        'PUT *': 201,
        'HEAD *': 405,
        'PROPFIND *': 405,
      });

      final result = await run(
        server,
        request(secret: '', source: JoinLinkSource.nextcloudShare),
      );

      expect(result.ok, isTrue);
      expect(result.warnings, isEmpty);
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
        'PUT /.birdnet-live/$folder.json': 405,
        'PUT /remote.php/dav/files/alice/.birdnet-live/$folder.json': 201,
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

    test('a share link falls back to the legacy public endpoint', () async {
      // Nextcloud before 28: no public.php/dav, only public.php/webdav.
      final server = _FakeServer({
        'OPTIONS /public.php/dav/files/tok12345/': 404,
        'OPTIONS /public.php/webdav/': 405,
        'MKCOL /public.php/webdav/.birdnet-live/': 201,
        'PUT /public.php/webdav/.birdnet-live/$folder.json': 201,
        'HEAD *': 405,
        'PROPFIND *': 405,
      });

      final result = await run(
        server,
        request(
          url: 'https://cloud.example.org/public.php/dav/files/tok12345/',
          username: 'tok12345',
          secret: '',
          source: JoinLinkSource.nextcloudShare,
        ),
      );

      expect(result.ok, isTrue);
      expect(
        result.resolvedUrl,
        'https://cloud.example.org/public.php/webdav/',
      );
      expect(result.flatLayout, isFalse);
    });

    test('a share link also reaches the ownCloud Infinite Scale endpoint', () async {
      final server = _FakeServer({
        'OPTIONS /nc/public.php/dav/files/tok12345/': 404,
        'OPTIONS /nc/public.php/webdav/': 200,
        'MKCOL /nc/public.php/webdav/.birdnet-live/': 201,
        'PUT /nc/public.php/webdav/.birdnet-live/$folder.json': 409,
        'OPTIONS /nc/remote.php/dav/public-files/tok12345/': 200,
        'MKCOL /nc/remote.php/dav/public-files/tok12345/.birdnet-live/': 201,
        'PUT /nc/remote.php/dav/public-files/tok12345/.birdnet-live/$folder.json':
            201,
        'PROPFIND *': 403,
      });

      final result = await run(
        server,
        request(
          url: 'https://host.example.org/nc/public.php/dav/files/tok12345/',
          username: 'tok12345',
          source: JoinLinkSource.nextcloudShare,
        ),
      );

      expect(result.ok, isTrue);
      expect(
        result.resolvedUrl,
        'https://host.example.org/nc/remote.php/dav/public-files/tok12345/',
      );
    });

    test(
      'a Nextcloud 33 File Drop passes on the public dav endpoint',
      () async {
        // Observed on Nextcloud 33.0.9: OPTIONS, HEAD, PROPFIND, GET, DELETE
        // all 405 ("Only PUT, MKCOL and MOVE are allowed on files drop"),
        // MKCOL 201 even for an existing folder, PUT 201.
        final server = _FakeServer({
          'OPTIONS *': 405,
          'MKCOL *': 201,
          'PUT *': 201,
          'HEAD *': 405,
          'PROPFIND *': 405,
        });

        final result = await run(
          server,
          request(
            url: 'https://cloud.example.org/public.php/dav/files/tok12345/',
            username: 'tok12345',
            secret: '',
            source: JoinLinkSource.nextcloudShare,
          ),
        );

        expect(result.ok, isTrue);
        expect(result.flatLayout, isFalse);
        expect(result.warnings, isEmpty);
        expect(
          server.requests.map((r) => r.url.path).toSet(),
          everyElement(startsWith('/public.php/dav/files/tok12345/')),
        );
      },
    );

    test(
      'MKCOL 405 on a share that cannot list means an old File Drop',
      () async {
        final server = _FakeServer({
          'OPTIONS *': 200,
          'MKCOL *': 405,
          'PUT *': 201,
          'PROPFIND *': 405,
        });

        final result = await run(
          server,
          request(
            url: 'https://cloud.example.org/public.php/webdav/',
            source: JoinLinkSource.nextcloudShare,
          ),
        );

        expect(result.ok, isTrue);
        expect(result.flatLayout, isTrue);
        expect(
          server.first('PUT')!.url.path,
          startsWith('/public.php/webdav/.birdnet-live__$folder.'),
        );
      },
    );

    test('MKCOL 405 on a share that can list keeps folders', () async {
      final server = _FakeServer({
        'OPTIONS *': 200,
        'MKCOL *': 405,
        'PUT *': 201,
        'PROPFIND *': 207,
      });

      final result = await run(
        server,
        request(
          url: 'https://cloud.example.org/public.php/webdav/',
          source: JoinLinkSource.nextcloudShare,
        ),
      );

      expect(result.ok, isTrue);
      expect(result.flatLayout, isFalse);
      expect(result.warnings, contains(ProbeWarning.canReadRemote));
    });

    test(
      'a join link to a legacy share endpoint moves to the new one',
      () async {
        // A join link built by an older generator, used against Nextcloud 33.
        final server = _FakeServer({
          'OPTIONS *': 405,
          'MKCOL *': 201,
          'PUT /public.php/webdav/.birdnet-live/$folder.json': 409,
          'PUT /public.php/dav/files/tok12345/.birdnet-live/$folder.json': 201,
          'HEAD *': 405,
          'PROPFIND *': 405,
        });
        final parsed = JoinLinkParser.parse(
          'https://example.org/join#v=1&kind=webdav'
          '&url=https://cloud.example.org/public.php/webdav/&user=tok12345',
        )!;
        expect(parsed.source, JoinLinkSource.nextcloudShare);

        final result = await run(server, parsed);

        expect(result.ok, isTrue);
        expect(
          result.resolvedUrl,
          'https://cloud.example.org/public.php/dav/files/tok12345/',
        );
        expect(result.warnings, isEmpty);
      },
    );

    test('a join link is probed as given, without discovery', () async {
      final server = _FakeServer({
        'OPTIONS *': 200,
        'MKCOL *': 201,
        'PUT *': 409,
      });

      final result = await run(
        server,
        request(url: 'https://cloud.example.org/public.php/webdav/'),
      );

      expect(result.ok, isFalse);
      expect(result.failure, ProbeFailure.notFound);
      expect(
        server.requests.map((r) => r.url.path).toSet(),
        everyElement(startsWith('/public.php/webdav/')),
      );
    });

    test('follows one redirect from OPTIONS to the real collection', () async {
      final server = _FakeServer({
        'OPTIONS /.well-known/webdav': 301,
        'OPTIONS /remote.php/dav/': 200,
        'MKCOL /remote.php/dav/.birdnet-live/': 201,
        'PUT /remote.php/dav/.birdnet-live/$folder.json': 201,
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
          .run(request(), folder: folder, registration: registration);
      final r2 = await WebDavProbe(client: refused)
          .run(request(), folder: folder, registration: registration);

      expect(r1.failure, ProbeFailure.hostNotFound);
      expect(r2.failure, ProbeFailure.connectionFailed);
    });
  });

  group('WebDavProbe re-test of a saved destination', () {
    test(
      'knownFlatLayout skips MKCOL and registers under the flat name',
      () async {
        final server = _FakeServer({
          'OPTIONS *': 200,
          'MKCOL *': 405,
          'PUT /drop/.birdnet-live__$folder.json': 201,
          'PROPFIND *': 405,
        });

        final result = await WebDavProbe(client: server.client).run(
          request(url: 'https://dav.example.org/drop/'),
          folder: folder,
          registration: registration,
          knownFlatLayout: true,
        );

        expect(result.ok, isTrue);
        expect(result.flatLayout, isTrue);
        expect(server.first('MKCOL'), isNull);
      },
    );

    test(
      'a share with no token anywhere gets no discovery candidates',
      () async {
        final server = _FakeServer({
          'OPTIONS *': 200,
          'MKCOL *': 201,
          'PUT *': 409,
        });

        final result = await run(
          server,
          request(
            url: 'https://cloud.example.org/public.php/webdav/',
            username: '',
            secret: '',
            source: JoinLinkSource.nextcloudShare,
          ),
        );

        expect(result.ok, isFalse);
        expect(
          server.requests.map((r) => r.url.path).toSet(),
          everyElement(startsWith('/public.php/webdav/')),
        );
      },
    );
  });

  group('WebDavProbe.reachability', () {
    Future<ProbeFailure?> check(int status) =>
        WebDavProbe(client: _FakeServer({'OPTIONS *': status}).client)
            .reachability('https://x.example.org/dav/', const {});

    test('maps stated refusals and stays silent otherwise', () async {
      expect(await check(401), ProbeFailure.unauthorized);
      expect(await check(403), ProbeFailure.uploadForbidden);
      expect(await check(404), ProbeFailure.notFound);
      expect(await check(410), ProbeFailure.notFound);
      expect(await check(200), isNull);
      expect(await check(405), isNull);
      expect(await check(500), isNull);
    });

    test('network trouble is inconclusive, TLS trouble is not', () async {
      final offline = MockClient((_) async {
        throw const SocketException('Network is unreachable');
      });
      final tls = MockClient((_) async {
        throw const HandshakeException('bad certificate');
      });
      expect(
        await WebDavProbe(client: offline)
            .reachability('https://x.example.org/', const {}),
        isNull,
      );
      expect(
        await WebDavProbe(client: tls)
            .reachability('https://x.example.org/', const {}),
        ProbeFailure.tlsFailure,
      );
    });
  });

  group('WebDavProbe.shareEndpointCandidates', () {
    test('derives the legacy and oCIS endpoints under the same prefix', () {
      expect(
        WebDavProbe.shareEndpointCandidates(
          'https://host.example.org/nc/public.php/dav/files/tok/',
          'tok',
        ),
        [
          'https://host.example.org/nc/public.php/dav/files/tok/',
          'https://host.example.org/nc/public.php/webdav/',
          'https://host.example.org/nc/remote.php/dav/public-files/tok/',
        ],
      );
      expect(
        WebDavProbe.shareEndpointCandidates(
          'https://cloud.example.org:8443/public.php/dav/files/tok/',
          'tok',
        ),
        [
          'https://cloud.example.org:8443/public.php/dav/files/tok/',
          'https://cloud.example.org:8443/public.php/webdav/',
          'https://cloud.example.org:8443/remote.php/dav/public-files/tok/',
        ],
      );
      expect(
        WebDavProbe.shareEndpointCandidates('https://x.example.org/dav/', 't'),
        isEmpty,
      );
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
