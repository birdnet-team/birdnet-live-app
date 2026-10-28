import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/upload/join_link.dart';

void main() {
  group('JoinLinkParser.parse', () {
    test('reads a join link from the fragment', () {
      final request = JoinLinkParser.parse(
        'https://example.org/join#v=1&kind=webdav&name=Spring%20Survey'
        '&url=https://cloud.example.org/public.php/webdav/&user=abc&secret=pw'
        '&audio=0&wifi=1',
      )!;
      expect(request.source, JoinLinkSource.joinLink);
      expect(request.url, 'https://cloud.example.org/public.php/webdav/');
      expect(request.username, 'abc');
      expect(request.secret, 'pw');
      expect(request.name, 'Spring Survey');
      expect(request.includeAudio, isFalse);
      expect(request.wifiOnly, isTrue);
    });

    test('falls back to query parameters and the custom scheme', () {
      final request = JoinLinkParser.parse(
        'birdnetlive://join?kind=webdav&url=https://dav.example.org/drop&user=u',
      )!;
      expect(request.source, JoinLinkSource.joinLink);
      expect(request.url, 'https://dav.example.org/drop/');
      expect(request.username, 'u');
      expect(request.secret, '');
      expect(request.name, isNull);
      expect(request.includeAudio, isNull);
    });

    test('rejects a join link of an unknown kind', () {
      expect(
        JoinLinkParser.parse(
          'https://example.org/join#kind=s3&url=https://x.example.org/',
        ),
        isNull,
      );
    });

    test('converts a Nextcloud share link to its public WebDAV endpoint', () {
      final request = JoinLinkParser.parse(
        'https://cloud.example.org/s/AbC123xyz',
        secret: 'share-pw',
      )!;
      expect(request.source, JoinLinkSource.nextcloudShare);
      expect(request.url, 'https://cloud.example.org/public.php/webdav/');
      expect(request.username, 'AbC123xyz');
      expect(request.secret, 'share-pw');
    });

    test('keeps a sub-directory install prefix and drops index.php', () {
      final request = JoinLinkParser.parse(
        'https://host.example.org/nextcloud/index.php/s/TOKEN?dir=/x',
      )!;
      expect(
        request.url,
        'https://host.example.org/nextcloud/public.php/webdav/',
      );
      expect(request.username, 'TOKEN');
    });

    test('treats anything else as a WebDAV URL and normalizes it', () {
      final request = JoinLinkParser.parse(
        'dav.example.org/remote.php/dav/files/alice',
        username: ' alice ',
        secret: 'app-pw',
      )!;
      expect(request.source, JoinLinkSource.webdavUrl);
      expect(
        request.url,
        'https://dav.example.org/remote.php/dav/files/alice/',
      );
      expect(request.username, 'alice');
      expect(request.secret, 'app-pw');
    });

    test('returns null for empty or hostless input', () {
      expect(JoinLinkParser.parse('   '), isNull);
      expect(JoinLinkParser.parse('https://'), isNull);
      expect(JoinLinkParser.parse('mailto:someone@example.org'), isNull);
    });
  });

  test('normalizeCollectionUrl adds https and a trailing slash', () {
    expect(
      JoinLinkParser.normalizeCollectionUrl('example.org/dav?x=1#frag'),
      'https://example.org/dav/',
    );
    expect(
      JoinLinkParser.normalizeCollectionUrl('http://10.0.0.2'),
      'http://10.0.0.2/',
    );
  });
}
