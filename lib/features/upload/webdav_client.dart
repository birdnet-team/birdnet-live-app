// =============================================================================
// WebDAV Client — the three verbs an upload needs
// =============================================================================
//
// MKCOL to create a folder, PUT to write a file, HEAD to check one. Files are
// streamed from disk so a long recording never sits in memory. Every call
// returns the HTTP status; the caller decides what a status means, because a
// 412 is fine for an immutable drop server but not for a probe.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

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

  static Map<String, String> basicAuth(String username, String secret) {
    if (username.isEmpty && secret.isEmpty) return const {};
    return {
      'Authorization':
          'Basic ${base64Encode(utf8.encode('$username:$secret'))}',
    };
  }

  Future<int> mkcol(Uri uri, Map<String, String> auth) =>
      _simple('MKCOL', uri, auth);

  Future<int> head(Uri uri, Map<String, String> auth) =>
      _simple('HEAD', uri, auth);

  Future<int> putBytes(
    Uri uri,
    Map<String, String> auth,
    List<int> body, {
    String contentType = 'application/octet-stream',
  }) async {
    final request = http.Request('PUT', uri)
      ..followRedirects = false
      ..headers.addAll(auth)
      ..headers['User-Agent'] = userAgent
      ..headers['Content-Type'] = contentType
      ..bodyBytes = body;
    return _send(request, timeout);
  }

  /// Streams [file] to [uri]. The timeout allows roughly 50 KB/s plus a
  /// minute, so a slow cellular link is not cut off halfway.
  Future<int> putFile(
    Uri uri,
    Map<String, String> auth,
    File file, {
    String contentType = 'application/octet-stream',
  }) async {
    final length = await file.length();
    final request = http.StreamedRequest('PUT', uri)
      ..followRedirects = false
      ..headers.addAll(auth)
      ..headers['User-Agent'] = userAgent
      ..headers['Content-Type'] = contentType
      ..contentLength = length;
    unawaited(
      file
          .openRead()
          .pipe(request.sink)
          .catchError((Object error) => request.sink.addError(error)),
    );
    final budget = Duration(seconds: 60 + length ~/ (50 * 1024));
    return _send(request, budget > timeout ? budget : timeout);
  }

  Future<int> _simple(String method, Uri uri, Map<String, String> auth) {
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers.addAll(auth)
      ..headers['User-Agent'] = userAgent;
    return _send(request, timeout);
  }

  Future<int> _send(http.BaseRequest request, Duration budget) async {
    final response = await _client.send(request).timeout(budget);
    await response.stream.drain<void>().timeout(timeout);
    return response.statusCode;
  }
}
