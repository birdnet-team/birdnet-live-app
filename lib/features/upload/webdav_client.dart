// =============================================================================
// WebDAV Client — the three verbs an upload needs
// =============================================================================
//
// MKCOL to create a folder, PUT to write a file, HEAD to check one. Files are
// streamed from disk so a long recording never sits in memory. Every call
// returns the HTTP status; the caller decides what a status means, because a
// 412 is fine for an immutable drop server but not for a probe. Credentials
// and the Digest handshake live in [WebDavAuth]; one redirect per request is
// followed by [sendWithAuth].
// =============================================================================

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'webdav_auth.dart';

class WebDavClient {
  WebDavClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  final http.Client _client;

  /// Timeout for header-only and small-body requests. File uploads scale
  /// theirs with the file size.
  final Duration timeout;

  static const String userAgent = 'BirdNET-Live';

  Future<int> mkcol(Uri uri, WebDavAuth auth) => _simple('MKCOL', uri, auth);

  Future<int> head(Uri uri, WebDavAuth auth) => _simple('HEAD', uri, auth);

  /// Streams [file] to [uri]. The timeout allows roughly 50 KB/s plus a
  /// minute, so a slow cellular link is not cut off halfway. A Digest
  /// challenge or a redirect re-opens the file for the second attempt.
  Future<int> putFile(
    Uri uri,
    WebDavAuth auth,
    File file, {
    String contentType = 'application/octet-stream',
  }) async {
    final length = await file.length();
    final budget = Duration(seconds: 60 + length ~/ (50 * 1024));
    return _send(uri, auth, budget > timeout ? budget : timeout, (target) {
      final request = http.StreamedRequest('PUT', target)
        ..headers['User-Agent'] = userAgent
        ..headers['Content-Type'] = contentType
        ..contentLength = length;
      unawaited(
        file
            .openRead()
            .pipe(request.sink)
            .catchError((Object error) => request.sink.addError(error)),
      );
      return request;
    });
  }

  Future<int> _simple(String method, Uri uri, WebDavAuth auth) => _send(
    uri,
    auth,
    timeout,
    (target) => http.Request(method, target)..headers['User-Agent'] = userAgent,
  );

  Future<int> _send(
    Uri uri,
    WebDavAuth auth,
    Duration budget,
    http.BaseRequest Function(Uri uri) build,
  ) async {
    final response = await sendWithAuth(
      _client,
      auth,
      uri,
      build,
      timeout: budget,
    );
    await response.stream.drain<void>().timeout(timeout);
    return response.statusCode;
  }
}
