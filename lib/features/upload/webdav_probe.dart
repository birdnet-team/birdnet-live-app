// =============================================================================
// WebDAV Probe — verify a destination before it is saved
// =============================================================================
//
// Nothing is persisted until this probe passes. It performs the same round
// trip an upload will later need, in the order an upload makes it:
//
//   OPTIONS <url>                         reachability, TLS, credentials
//   MKCOL   <url>_joined/                 may the credential create folders?
//   PUT     <url>_joined/<deviceId>.json  may it upload? (also registers the
//                                         device with the project lead)
//   HEAD    the file just written         informational only
//   PROPFIND <url> (depth 1)              over-privilege check: a write-only
//                                         credential must NOT be able to list
//
// A refused MKCOL is not a failure: the destination is marked `flatLayout`
// and uploads encode the folder path into file names instead. Every failure
// maps to one [ProbeFailure] so the join sheet can show one sentence and one
// fix. `tools/webdav_drop_server/conformance.py` runs the identical sequence.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'join_link.dart';

/// Why a probe failed; each value has one user-facing sentence.
enum ProbeFailure {
  invalidUrl,
  insecureHttp,
  hostNotFound,
  tlsFailure,
  connectionFailed,
  timeout,
  unauthorized,
  notWebDav,
  uploadForbidden,
  notFound,
  quotaExceeded,
  serverError,
}

/// Non-fatal findings the user should see before saving.
enum ProbeWarning {
  /// The credential could list the collection, so it may read others' data.
  canReadRemote,

  /// A Nextcloud/ownCloud share accepted uploads without a password.
  shareWithoutPassword,

  /// Plain HTTP to a LAN address; tolerated, but flagged.
  insecureLan,
}

/// Outcome of [WebDavProbe.run].
class ProbeResult {
  const ProbeResult._({
    required this.ok,
    required this.resolvedUrl,
    this.failure,
    this.statusCode,
    this.warnings = const {},
    this.flatLayout = false,
  });

  const ProbeResult.success({
    required String resolvedUrl,
    Set<ProbeWarning> warnings = const {},
    bool flatLayout = false,
  }) : this._(
         ok: true,
         resolvedUrl: resolvedUrl,
         warnings: warnings,
         flatLayout: flatLayout,
       );

  const ProbeResult.failed(
    ProbeFailure failure, {
    required String resolvedUrl,
    int? statusCode,
  }) : this._(
         ok: false,
         resolvedUrl: resolvedUrl,
         failure: failure,
         statusCode: statusCode,
       );

  final bool ok;

  /// The collection URL that answered; differs from the request when a
  /// redirect or autodiscovery found the real endpoint.
  final String resolvedUrl;
  final ProbeFailure? failure;
  final int? statusCode;
  final Set<ProbeWarning> warnings;
  final bool flatLayout;

  @override
  String toString() => ok
      ? 'ProbeResult.ok($resolvedUrl, warnings=$warnings, flat=$flatLayout)'
      : 'ProbeResult.failed($failure, $statusCode, $resolvedUrl)';
}

/// Runs the pre-save round trip against a WebDAV collection.
class WebDavProbe {
  WebDavProbe({http.Client? client, this.timeout = const Duration(seconds: 20)})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  /// Folder (or flat-name prefix) that holds device registrations.
  static const String joinedFolder = '_joined';

  /// Separator used in place of `/` when the server refuses folders.
  static const String flatSeparator = '__';

  /// Probes [request]. [registration] is written as the device's join record.
  ///
  /// For a plain URL the probe also tries the usual WebDAV locations when the
  /// typed one does not answer like a WebDAV server.
  Future<ProbeResult> run(
    JoinRequest request, {
    required String deviceId,
    required Map<String, Object?> registration,
  }) async {
    final candidates = <String>[request.url];
    final first = await _probeUrl(
      request,
      request.url,
      deviceId: deviceId,
      registration: registration,
    );
    if (first.ok ||
        request.source != JoinLinkSource.webdavUrl ||
        !_worthDiscovering(first.failure)) {
      return first;
    }
    for (final candidate in _discoveryCandidates(request)) {
      if (candidates.contains(candidate)) continue;
      candidates.add(candidate);
      final result = await _probeUrl(
        request,
        candidate,
        deviceId: deviceId,
        registration: registration,
      );
      if (result.ok) return result;
    }
    return first;
  }

  bool _worthDiscovering(ProbeFailure? failure) =>
      failure == ProbeFailure.notWebDav ||
      failure == ProbeFailure.notFound ||
      failure == ProbeFailure.uploadForbidden;

  List<String> _discoveryCandidates(JoinRequest request) {
    final uri = Uri.parse(request.url);
    final origin = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: '/',
    );
    final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    final list = <String>[];
    if (request.username.isNotEmpty) {
      // Nextcloud/ownCloud per-user files endpoint.
      final user = Uri.encodeComponent(request.username);
      list.add(
        origin.replace(path: '${path}remote.php/dav/files/$user/').toString(),
      );
      if (path != '/') {
        list.add(
          origin.replace(path: '/remote.php/dav/files/$user/').toString(),
        );
      }
    }
    list.add(origin.replace(path: '${path}dav/').toString());
    list.add(origin.replace(path: '/.well-known/webdav').toString());
    return list;
  }

  Future<ProbeResult> _probeUrl(
    JoinRequest request,
    String url, {
    required String deviceId,
    required Map<String, Object?> registration,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return ProbeResult.failed(ProbeFailure.invalidUrl, resolvedUrl: url);
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return ProbeResult.failed(ProbeFailure.invalidUrl, resolvedUrl: url);
    }
    final warnings = <ProbeWarning>{};
    if (uri.scheme == 'http') {
      if (!isLanHost(uri.host)) {
        return ProbeResult.failed(ProbeFailure.insecureHttp, resolvedUrl: url);
      }
      warnings.add(ProbeWarning.insecureLan);
    }
    final auth = _authHeader(request);

    try {
      // 1. OPTIONS: reachability, certificate, credentials. Follow one
      //    redirect so a missing trailing slash or a .well-known entry lands
      //    on the real collection.
      var base = uri;
      var options = await _send('OPTIONS', base, auth);
      if (_isRedirect(options.statusCode)) {
        final location = options.headers['location'];
        if (location != null) {
          base = Uri.parse(
            JoinLinkParser.normalizeCollectionUrl(
              base.resolve(location).toString(),
            ),
          );
          options = await _send('OPTIONS', base, auth);
        }
      }
      final resolved = base.toString();
      final early = _failureFor(options.statusCode, step: _Step.options);
      if (early != null) {
        return ProbeResult.failed(
          early,
          resolvedUrl: resolved,
          statusCode: options.statusCode,
        );
      }

      // 2. MKCOL: may we create folders? 405 means it already exists.
      var flatLayout = false;
      final folder = base.resolve('$joinedFolder/');
      final mkcol = await _send('MKCOL', folder, auth);
      switch (mkcol.statusCode) {
        case 201:
        case 405:
          break;
        case 401:
          return ProbeResult.failed(
            ProbeFailure.unauthorized,
            resolvedUrl: resolved,
            statusCode: 401,
          );
        case 507:
          return ProbeResult.failed(
            ProbeFailure.quotaExceeded,
            resolvedUrl: resolved,
            statusCode: 507,
          );
        case 404:
          return ProbeResult.failed(
            ProbeFailure.notFound,
            resolvedUrl: resolved,
            statusCode: 404,
          );
        default:
          if (mkcol.statusCode >= 500) {
            return ProbeResult.failed(
              ProbeFailure.serverError,
              resolvedUrl: resolved,
              statusCode: mkcol.statusCode,
            );
          }
          flatLayout = true;
      }

      // 3. PUT the registration record. The name carries a timestamp so a
      //    re-test or re-join on an immutable server (412 on overwrite) still
      //    writes a fresh record, and the lead can see when the device was
      //    last seen.
      final fileName = '$deviceId-${registrationStamp(DateTime.now())}.json';
      final target = flatLayout
          ? base.resolve('$joinedFolder$flatSeparator$fileName')
          : folder.resolve(fileName);
      final put = await _send(
        'PUT',
        target,
        auth,
        body: utf8.encode(jsonEncode(registration)),
        contentType: 'application/json',
      );
      final putFailure = _failureFor(put.statusCode, step: _Step.put);
      if (putFailure != null) {
        return ProbeResult.failed(
          putFailure,
          resolvedUrl: resolved,
          statusCode: put.statusCode,
        );
      }

      // 4. HEAD: informational. Write-only servers may refuse it.
      await _send('HEAD', target, auth);

      // 5. Over-privilege check. A contributor credential should not be able
      //    to list the collection. 207 means it can.
      final propfind = await _send(
        'PROPFIND',
        base,
        auth,
        body: utf8.encode(
          '<?xml version="1.0"?><d:propfind xmlns:d="DAV:">'
          '<d:prop><d:resourcetype/></d:prop></d:propfind>',
        ),
        contentType: 'application/xml',
        headers: const {'Depth': '1'},
      );
      if (propfind.statusCode == 207 || propfind.statusCode == 200) {
        warnings.add(ProbeWarning.canReadRemote);
      }
      if (request.source == JoinLinkSource.nextcloudShare &&
          request.secret.isEmpty) {
        warnings.add(ProbeWarning.shareWithoutPassword);
      }
      return ProbeResult.success(
        resolvedUrl: resolved,
        warnings: warnings,
        flatLayout: flatLayout,
      );
    } on TimeoutException {
      return ProbeResult.failed(ProbeFailure.timeout, resolvedUrl: url);
    } on HandshakeException {
      return ProbeResult.failed(ProbeFailure.tlsFailure, resolvedUrl: url);
    } on TlsException {
      return ProbeResult.failed(ProbeFailure.tlsFailure, resolvedUrl: url);
    } on SocketException catch (e) {
      final code = e.osError?.errorCode;
      final lookupFailed =
          e.message.contains('Failed host lookup') ||
          code == 11001 || // Windows WSAHOST_NOT_FOUND
          code == -2 || // Linux/Android EAI_NONAME
          code == 8; // macOS/iOS EAI_NONAME
      return ProbeResult.failed(
        lookupFailed
            ? ProbeFailure.hostNotFound
            : ProbeFailure.connectionFailed,
        resolvedUrl: url,
      );
    } on http.ClientException {
      return ProbeResult.failed(
        ProbeFailure.connectionFailed,
        resolvedUrl: url,
      );
    }
  }

  ProbeFailure? _failureFor(int status, {required _Step step}) {
    switch (status) {
      case 401:
        return ProbeFailure.unauthorized;
      case 507:
        return ProbeFailure.quotaExceeded;
    }
    if (status >= 500) return ProbeFailure.serverError;
    if (step == _Step.options) {
      // Many servers answer OPTIONS loosely; only hard failures count here.
      return status == 404 ? ProbeFailure.notFound : null;
    }
    switch (status) {
      case 200:
      case 201:
      case 204:
        return null;
      case 412:
        // No If-* header is sent, so 412 can only be an immutable server
        // refusing to overwrite: the record exists, which is fine.
        return null;
      case 403:
        return ProbeFailure.uploadForbidden;
      case 404:
      case 409:
        return ProbeFailure.notFound;
      case 405:
      case 400:
      case 501:
        return ProbeFailure.notWebDav;
      default:
        return status >= 200 && status < 300 ? null : ProbeFailure.notWebDav;
    }
  }

  bool _isRedirect(int status) =>
      status == 301 || status == 302 || status == 307 || status == 308;

  Map<String, String> _authHeader(JoinRequest request) {
    if (request.username.isEmpty && request.secret.isEmpty) return const {};
    final token = base64Encode(
      utf8.encode('${request.username}:${request.secret}'),
    );
    return {'Authorization': 'Basic $token'};
  }

  Future<http.StreamedResponse> _send(
    String method,
    Uri uri,
    Map<String, String> auth, {
    List<int>? body,
    String? contentType,
    Map<String, String> headers = const {},
  }) async {
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers.addAll(auth)
      ..headers.addAll(headers)
      ..headers['User-Agent'] = 'BirdNET-Live';
    if (body != null) {
      request.bodyBytes = body;
      if (contentType != null) request.headers['Content-Type'] = contentType;
    }
    final response = await _client.send(request).timeout(timeout);
    // Drain so the connection can be reused.
    await response.stream.drain<void>().timeout(timeout);
    return response;
  }

  /// Compact UTC stamp for file names: `20261028T092319Z`.
  static String registrationStamp(DateTime time) {
    final t = time.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}T'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}Z';
  }

  /// True for addresses where plain HTTP is tolerated with a warning.
  static bool isLanHost(String host) {
    final h = host.toLowerCase();
    if (h == 'localhost' || h.endsWith('.local') || h.endsWith('.lan')) {
      return true;
    }
    final address = InternetAddress.tryParse(
      h.replaceAll(RegExp(r'[\[\]]'), ''),
    );
    if (address == null) return false;
    if (address.isLoopback || address.isLinkLocal) return true;
    final b = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      return b[0] == 10 ||
          (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
          (b[0] == 192 && b[1] == 168);
    }
    // fc00::/7 unique local addresses.
    return (b[0] & 0xfe) == 0xfc;
  }
}

enum _Step { options, put }
