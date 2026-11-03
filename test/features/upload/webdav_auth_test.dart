import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:birdnet_live/features/upload/webdav_auth.dart';

void main() {
  // Reference values computed independently with Python's hashlib for
  // user "Mufasa", realm "http-auth@example.org", password "Circle of
  // Life", GET /dir/index.html, the nonce and cnonce below, nc=1, qop=auth.
  const nonce = '7ypf/xlj9XXwfDPEoM4URrv/xwf94BcCAzFZH4GiTo0v';
  const cnonce = 'f2/wE4q74E6j5TVgcwcSGRJjG1IqPc3Ofbhu9cbY3YA=';
  const md5Response = '5122027ec8a8ad7e7ce72b1cafd7490f';
  const sha256Response =
      '8f1c96e9263b7936b79c74d8a72cd9e5fb9428d9e76f769e4d947d3d6cfa754f';

  Map<String, String> params(String authorization) {
    expect(authorization, startsWith('Digest '));
    final out = <String, String>{};
    for (final m in RegExp(
      r'(\w+)=(?:"((?:[^"\\]|\\.)*)"|([^,]+))',
    ).allMatches(authorization.substring(7))) {
      out[m.group(1)!] = (m.group(2) ?? m.group(3)!).replaceAll(r'\"', '"');
    }
    return out;
  }

  group('DigestChallenge', () {
    test('parses a Digest challenge next to a Basic one', () {
      final c = DigestChallenge.parse(
        'Basic realm="Breadth", Digest realm="http-auth@example.org", '
        'qop="auth, auth-int", algorithm=MD5, nonce="$nonce", '
        'opaque="FQhe/qaU925kfnzjCev0ciny7QMkPqMAFRtzCUYo5tdS", stale=FALSE',
      )!;
      expect(c.realm, 'http-auth@example.org');
      expect(c.nonce, nonce);
      expect(c.algorithm, 'MD5');
      expect(c.qop, 'auth');
      expect(c.opaque, 'FQhe/qaU925kfnzjCev0ciny7QMkPqMAFRtzCUYo5tdS');
      expect(c.stale, isFalse);
    });

    test('prefers SHA-256 when both are offered', () {
      final c = DigestChallenge.parse(
        'Digest realm="r", nonce="a", algorithm=MD5, qop="auth", '
        'Digest realm="r", nonce="b", algorithm=SHA-256, qop="auth"',
      )!;
      expect(c.algorithm, 'SHA-256');
      expect(c.nonce, 'b');
    });

    test('ignores challenges it cannot answer', () {
      expect(DigestChallenge.parse('Basic realm="x"'), isNull);
      expect(
        DigestChallenge.parse('Digest realm="r", nonce="n", qop="auth-int"'),
        isNull,
      );
      expect(
        DigestChallenge.parse(
          'Digest realm="r", nonce="n", algorithm=SHA-512-256, qop="auth"',
        ),
        isNull,
      );
      expect(DigestChallenge.parse('Digest realm="r"'), isNull);
    });

    test('computes the RFC 7616 response for MD5 and SHA-256', () {
      for (final (algorithm, expected) in [
        ('MD5', md5Response),
        ('SHA-256', sha256Response),
      ]) {
        final c = DigestChallenge(
          realm: 'http-auth@example.org',
          nonce: nonce,
          algorithm: algorithm,
          qop: 'auth',
          opaque: 'FQhe/qaU925kfnzjCev0ciny7QMkPqMAFRtzCUYo5tdS',
        );
        final p = params(
          c.authorization(
            username: 'Mufasa',
            password: 'Circle of Life',
            method: 'GET',
            uri: Uri.parse('https://example.org/dir/index.html'),
            nonceCount: 1,
            cnonce: cnonce,
          ),
        );
        expect(p['response'], expected, reason: algorithm);
        expect(p['username'], 'Mufasa');
        expect(p['uri'], '/dir/index.html');
        expect(p['nc'], '00000001');
        expect(p['qop'], 'auth');
        expect(p['algorithm'], algorithm);
        expect(p['opaque'], 'FQhe/qaU925kfnzjCev0ciny7QMkPqMAFRtzCUYo5tdS');
      }
    });

    test('RFC 2069 form without qop omits nc and cnonce', () {
      const c = DigestChallenge(
        realm: 'r',
        nonce: 'n',
        algorithm: 'MD5',
        qop: null,
      );
      final p = params(
        c.authorization(
          username: 'u',
          password: 'p',
          method: 'PUT',
          uri: Uri.parse('https://h/a%20b/x.zip?v=1'),
          nonceCount: 3,
          cnonce: 'c',
        ),
      );
      expect(p.containsKey('nc'), isFalse);
      expect(p.containsKey('cnonce'), isFalse);
      expect(p['uri'], '/a%20b/x.zip?v=1');
    });

    test('escapes quotes and backslashes in quoted values', () {
      const c = DigestChallenge(
        realm: r'say "hi"\now',
        nonce: 'n',
        algorithm: 'MD5',
        qop: 'auth',
      );
      final header = c.authorization(
        username: 'a"b',
        password: 'p',
        method: 'GET',
        uri: Uri.parse('https://h/'),
        nonceCount: 1,
        cnonce: 'c',
      );
      expect(header, contains(r'username="a\"b"'));
      expect(header, contains(r'realm="say \"hi\"\\now"'));
    });
  });

  group('WebDavAuth', () {
    test('sends Basic until challenged, then Digest with a growing nc', () {
      final auth = WebDavAuth('alice', 'secret', cnonce: () => 'c');
      final uri = Uri.parse('https://h/dav/');
      expect(
        auth.headers('OPTIONS', uri)['Authorization'],
        'Basic ${base64Encode(utf8.encode('alice:secret'))}',
      );
      final challenged = auth.acceptChallenge(
        http.Response(
          '',
          401,
          headers: {
            'www-authenticate':
                'Digest realm="r", nonce="n1", algorithm=MD5, qop="auth"',
          },
        ),
      );
      expect(challenged, isTrue);
      expect(
        params(auth.headers('OPTIONS', uri)['Authorization']!)['nc'],
        '00000001',
      );
      expect(
        params(auth.headers('MKCOL', uri)['Authorization']!)['nc'],
        '00000002',
      );
    });

    test('a repeated 401 for the same nonce means wrong password', () {
      final auth = WebDavAuth('alice', 'wrong');
      final response = http.Response(
        '',
        401,
        headers: {'www-authenticate': 'Digest realm="r", nonce="n1"'},
      );
      expect(auth.acceptChallenge(response), isTrue);
      auth.headers('GET', Uri.parse('https://h/'));
      expect(auth.acceptChallenge(response), isFalse);
    });

    test('a stale nonce is refreshed once', () {
      final auth = WebDavAuth('alice', 'secret');
      auth.acceptChallenge(
        http.Response(
          '',
          401,
          headers: {'www-authenticate': 'Digest realm="r", nonce="n1"'},
        ),
      );
      final refreshed = auth.acceptChallenge(
        http.Response(
          '',
          401,
          headers: {
            'www-authenticate': 'Digest realm="r", nonce="n2", stale=true',
          },
        ),
      );
      expect(refreshed, isTrue);
      expect(auth.challenge!.nonce, 'n2');
    });

    test('no credentials means no header and no challenge handling', () {
      final auth = WebDavAuth.none();
      expect(auth.headers('GET', Uri.parse('https://h/')), isEmpty);
      expect(
        auth.acceptChallenge(
          http.Response(
            '',
            401,
            headers: {'www-authenticate': 'Digest realm="r", nonce="n"'},
          ),
        ),
        isFalse,
      );
    });
  });

  group('sendWithAuth', () {
    test('answers a Digest challenge once and authenticates preemptively', () async {
      final seen = <String>[];
      final client = MockClient((request) async {
        final header = request.headers['Authorization'] ?? '';
        seen.add(header.split(' ').first);
        if (!header.startsWith('Digest ')) {
          return http.Response(
            '',
            401,
            headers: {
              'www-authenticate':
                  'Digest realm="r", nonce="n1", algorithm=SHA-256, qop="auth"',
            },
          );
        }
        return http.Response('', 201, request: request);
      });
      final auth = WebDavAuth('alice', 'secret');
      final uri = Uri.parse('https://h/dav/x');
      http.BaseRequest build(Uri u) => http.Request('PUT', u);

      final first = await sendWithAuth(
        client,
        auth,
        uri,
        build,
        timeout: const Duration(seconds: 5),
      );
      final second = await sendWithAuth(
        client,
        auth,
        uri,
        build,
        timeout: const Duration(seconds: 5),
      );

      expect(first.statusCode, 201);
      expect(second.statusCode, 201);
      // Basic, then Digest for the retry, then Digest straight away.
      expect(seen, ['Basic', 'Digest', 'Digest']);
    });

    test('a wrong password under Digest ends as 401 after one retry', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response(
          '',
          401,
          headers: {'www-authenticate': 'Digest realm="r", nonce="n1"'},
        );
      });
      final response = await sendWithAuth(
        client,
        WebDavAuth('alice', 'wrong'),
        Uri.parse('https://h/'),
        (u) => http.Request('OPTIONS', u),
        timeout: const Duration(seconds: 5),
      );
      expect(response.statusCode, 401);
      expect(calls, 2);
    });

    test('follows one redirect for any method and keeps the body', () async {
      final bodies = <String, String>{};
      final client = MockClient((request) async {
        if (request.url.path == '/old/x.zip') {
          return http.Response(
            '',
            307,
            headers: {'location': '/new/x.zip'},
            request: request,
          );
        }
        bodies[request.url.path] = request.body;
        return http.Response('', 201, request: request);
      });
      final response = await sendWithAuth(
        client,
        WebDavAuth.none(),
        Uri.parse('https://h/old/x.zip'),
        (u) => http.Request('PUT', u)..body = 'payload',
        timeout: const Duration(seconds: 5),
      );
      expect(response.statusCode, 201);
      expect(response.request!.url.path, '/new/x.zip');
      expect(bodies, {'/new/x.zip': 'payload'});
    });

    test('a redirect loop stops after one hop', () async {
      final client = MockClient(
        (request) async => http.Response(
          '',
          301,
          headers: {'location': '${request.url}/'},
          request: request,
        ),
      );
      final response = await sendWithAuth(
        client,
        WebDavAuth.none(),
        Uri.parse('https://h/a'),
        (u) => http.Request('MKCOL', u),
        timeout: const Duration(seconds: 5),
      );
      expect(response.statusCode, 301);
    });
  });
}
