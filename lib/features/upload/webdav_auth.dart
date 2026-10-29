// =============================================================================
// WebDAV Auth — Basic by default, Digest when the server asks for it
// =============================================================================
//
// Every request first carries Basic credentials, which is what Nextcloud,
// ownCloud, the drop server, and most cloud WebDAV endpoints expect. A server
// that answers 401 with a `WWW-Authenticate: Digest …` challenge (Apache and
// nginx setups, some NAS boxes) gets the request again with a Digest
// response (RFC 7616: MD5 or SHA-256, `qop=auth`, plus the old RFC 2069 form
// without qop). The challenge is kept, so later requests on the same
// [WebDavAuth] authenticate preemptively with a growing nonce count, and a
// `stale=true` answer refreshes the nonce once without bothering the user.
//
// [sendWithAuth] is the one place that performs the retry, and also follows a
// single redirect for every method, so a server that answers PUT or MKCOL
// with 301/307 (an alias host, a canonical path) is not reported as broken.
// =============================================================================

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Credentials for one destination plus the Digest state learned from it.
class WebDavAuth {
  WebDavAuth(this.username, this.secret, {String Function()? cnonce})
    : _cnonce = cnonce ?? _randomCnonce;

  /// No credentials at all (an open server or a token carried in the URL).
  WebDavAuth.none() : this('', '');

  final String username;
  final String secret;
  final String Function() _cnonce;

  DigestChallenge? _challenge;
  int _nonceCount = 0;

  bool get isEmpty => username.isEmpty && secret.isEmpty;

  /// The Digest challenge currently answered, if any.
  DigestChallenge? get challenge => _challenge;

  /// Request headers for [method] on [uri]: Digest when a challenge is known,
  /// Basic otherwise, nothing when there are no credentials.
  Map<String, String> headers(String method, Uri uri) {
    if (isEmpty) return const {};
    final challenge = _challenge;
    if (challenge == null) {
      return {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$username:$secret'))}',
      };
    }
    _nonceCount++;
    return {
      'Authorization': challenge.authorization(
        username: username,
        password: secret,
        method: method,
        uri: uri,
        nonceCount: _nonceCount,
        cnonce: _cnonce(),
      ),
    };
  }

  /// Learns the Digest challenge in a 401 [response]. Returns true when the
  /// request should be sent again: a usable challenge that was not answered
  /// yet, or a fresh nonce after the server declared the old one stale.
  bool acceptChallenge(http.BaseResponse response) {
    if (isEmpty || response.statusCode != 401) return false;
    final header = response.headers['www-authenticate'];
    if (header == null) return false;
    final challenge = DigestChallenge.parse(header);
    if (challenge == null) return false;
    final previous = _challenge;
    if (previous != null && !challenge.stale) {
      // Same nonce answered already and refused: the password is wrong.
      if (previous.nonce == challenge.nonce) return false;
    }
    _challenge = challenge;
    _nonceCount = 0;
    return true;
  }

  static String _randomCnonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }
}

/// One `Digest` challenge from a `WWW-Authenticate` header.
class DigestChallenge {
  const DigestChallenge({
    required this.realm,
    required this.nonce,
    required this.algorithm,
    required this.qop,
    this.opaque,
    this.stale = false,
  });

  final String realm;
  final String nonce;

  /// `MD5`, `MD5-sess`, `SHA-256`, or `SHA-256-sess`, as the server named it.
  final String algorithm;

  /// `auth`, or null for the RFC 2069 form without quality of protection.
  final String? qop;
  final String? opaque;
  final bool stale;

  /// Parses [header], which may carry several challenges (`Basic …, Digest
  /// …, Digest …`) since clients join repeated headers with commas. Returns
  /// the Digest challenge this client can answer, preferring SHA-256 over
  /// MD5, or null when there is none.
  static DigestChallenge? parse(String header) {
    DigestChallenge? best;
    for (final params in _digestChallenges(header)) {
      final nonce = params['nonce'];
      final realm = params['realm'];
      if (nonce == null || realm == null) continue;
      final algorithm = params['algorithm'] ?? 'MD5';
      if (!_supportedAlgorithms.contains(algorithm.toUpperCase())) continue;
      final qopList = (params['qop'] ?? '')
          .split(',')
          .map((q) => q.trim().toLowerCase())
          .where((q) => q.isNotEmpty)
          .toSet();
      String? qop;
      if (qopList.isEmpty) {
        qop = null;
      } else if (qopList.contains('auth')) {
        qop = 'auth';
      } else {
        continue; // auth-int only: not supported
      }
      final candidate = DigestChallenge(
        realm: realm,
        nonce: nonce,
        algorithm: algorithm,
        qop: qop,
        opaque: params['opaque'],
        stale: (params['stale'] ?? '').toLowerCase() == 'true',
      );
      if (best == null ||
          (!best.algorithm.toUpperCase().startsWith('SHA-256') &&
              candidate.algorithm.toUpperCase().startsWith('SHA-256'))) {
        best = candidate;
      }
    }
    return best;
  }

  static const Set<String> _supportedAlgorithms = {
    'MD5',
    'MD5-SESS',
    'SHA-256',
    'SHA-256-SESS',
  };

  /// The `Authorization` header value answering this challenge.
  String authorization({
    required String username,
    required String password,
    required String method,
    required Uri uri,
    required int nonceCount,
    required String cnonce,
  }) {
    final target = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
    final nc = nonceCount.toRadixString(16).padLeft(8, '0');
    var ha1 = _hash('$username:$realm:$password');
    if (algorithm.toUpperCase().endsWith('-SESS')) {
      ha1 = _hash('$ha1:$nonce:$cnonce');
    }
    final ha2 = _hash('$method:$target');
    final response = qop == null
        ? _hash('$ha1:$nonce:$ha2')
        : _hash('$ha1:$nonce:$nc:$cnonce:$qop:$ha2');
    final parts = <String>[
      'username="${_quote(username)}"',
      'realm="${_quote(realm)}"',
      'nonce="${_quote(nonce)}"',
      'uri="${_quote(target)}"',
      'response="$response"',
      'algorithm=$algorithm',
      if (qop != null) 'qop=$qop',
      if (qop != null) 'nc=$nc',
      if (qop != null) 'cnonce="${_quote(cnonce)}"',
      if (opaque != null) 'opaque="${_quote(opaque!)}"',
    ];
    return 'Digest ${parts.join(', ')}';
  }

  String _hash(String input) {
    final bytes = utf8.encode(input);
    return algorithm.toUpperCase().startsWith('SHA-256')
        ? sha256.convert(bytes).toString()
        : md5.convert(bytes).toString();
  }

  static String _quote(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

  /// Splits a `WWW-Authenticate` value into the parameter maps of its Digest
  /// challenges. A bare token (no `=`) starts a new challenge scheme.
  static List<Map<String, String>> _digestChallenges(String header) {
    final result = <Map<String, String>>[];
    Map<String, String>? current;
    var i = 0;
    final n = header.length;
    while (i < n) {
      // Skip separators.
      while (i < n &&
          (header[i] == ',' || header[i] == ' ' || header[i] == '\t')) {
        i++;
      }
      if (i >= n) break;
      // Read a token up to '=', ',', or whitespace.
      final start = i;
      while (i < n && !'=, \t'.contains(header[i])) {
        i++;
      }
      final token = header.substring(start, i);
      // Whitespace between token and '=' is tolerated.
      var j = i;
      while (j < n && (header[j] == ' ' || header[j] == '\t')) {
        j++;
      }
      if (j < n && header[j] == '=') {
        i = j + 1;
        String value;
        if (i < n && header[i] == '"') {
          i++;
          final buffer = StringBuffer();
          while (i < n && header[i] != '"') {
            if (header[i] == r'\' && i + 1 < n) i++;
            buffer.write(header[i]);
            i++;
          }
          i++; // closing quote
          value = buffer.toString();
        } else {
          final vStart = i;
          while (i < n && header[i] != ',') {
            i++;
          }
          value = header.substring(vStart, i).trim();
        }
        current?[token.toLowerCase()] = value;
      } else {
        // A scheme name such as "Basic" or "Digest".
        if (token.toLowerCase() == 'digest') {
          current = <String, String>{};
          result.add(current);
        } else {
          current = null;
        }
        i = j;
      }
    }
    return result;
  }
}

/// Sends the request [build] produces, answering one Digest challenge and
/// following one redirect. [build] is called for every attempt with the URI
/// to use, because `package:http` requests are single use; a streamed body
/// must therefore be re-created by the builder.
Future<http.StreamedResponse> sendWithAuth(
  http.Client client,
  WebDavAuth auth,
  Uri uri,
  http.BaseRequest Function(Uri uri) build, {
  required Duration timeout,
}) async {
  var target = uri;
  var challenged = false;
  var redirected = false;
  while (true) {
    final request = build(target)..followRedirects = false;
    request.headers.addAll(auth.headers(request.method, target));
    final response = await client.send(request).timeout(timeout);
    if (!challenged && auth.acceptChallenge(response)) {
      challenged = true;
      await response.stream.drain<void>().timeout(timeout);
      continue;
    }
    final location = response.headers['location'];
    if (!redirected && location != null && _isRedirect(response.statusCode)) {
      redirected = true;
      target = target.resolve(location);
      await response.stream.drain<void>().timeout(timeout);
      continue;
    }
    return response;
  }
}

bool _isRedirect(int status) =>
    status == 301 || status == 302 || status == 307 || status == 308;
