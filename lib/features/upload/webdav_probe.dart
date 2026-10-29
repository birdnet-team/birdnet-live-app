// =============================================================================
// WebDAV Probe — verify a destination before it is saved
// =============================================================================
//
// Nothing is persisted until this probe passes. It performs the same round
// trip an upload will later need, in the order an upload makes it:
//
//   OPTIONS <url>                           reachability, TLS, credentials
//   MKCOL   <url>.birdnet-live/             may the credential create folders?
//   PROPFIND <url> (depth 1)                over-privilege check: a write-only
//                                           credential must NOT be able to list
//   PUT     <url>.birdnet-live/<code>.json  may it upload? (also registers
//                                           the device with the project lead;
//                                           the dot hides the folder in
//                                           Nextcloud's default file list)
//   HEAD    the file just written           informational only
//
// A refused MKCOL is not a failure: the destination is marked `flatLayout`
// and uploads encode the folder path into file names instead. Every failure
// maps to one [ProbeFailure] so the join sheet can show one sentence and one
// fix. `tools/webdav_drop_server/conformance.py` runs the identical sequence.
//
// Servers differ in small ways the probe absorbs rather than reports:
// OPTIONS may answer 405 (Nextcloud public shares), MKCOL may answer 201 for
// a folder that already exists (Nextcloud File Drop) or 405 for one that
// does (Apache, nginx, SabreDAV), and an old File Drop answers 405 to every
// MKCOL because it only takes files. When the typed or derived URL does not
// behave like a WebDAV collection, the usual alternative endpoints of the
// same host are tried before giving up.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'join_link.dart';
import 'upload_naming.dart';

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

  /// A Nextcloud/ownCloud share that can be listed accepted uploads without
  /// a password, so anyone holding the link can read every contribution. A
  /// password-less File Drop is not flagged: it cannot be read, and leaving
  /// the password off is the lead's call.
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
  static const String joinedFolder = uploadRegistrationFolder;

  /// Separator used in place of `/` when the server refuses folders.
  static const String flatSeparator = uploadFlatSeparator;

  /// Probes [request]. [registration] is written as the device's join record
  /// under the name of [folder], the device code uploads will use as folder.
  ///
  /// For a plain URL the probe also tries the usual WebDAV locations when the
  /// typed one does not answer like a WebDAV server; for a share link it
  /// tries the older public endpoints. A join link names its endpoint
  /// explicitly and is probed as given.
  ///
  /// [knownFlatLayout] re-tests a saved destination the way its uploads run:
  /// the MKCOL step is skipped and the registration uses the flat name, so a
  /// server that refuses folders is not reported as broken.
  Future<ProbeResult> run(
    JoinRequest request, {
    required String folder,
    required Map<String, Object?> registration,
    bool knownFlatLayout = false,
  }) async {
    final candidates = <String>[request.url];
    final first = await _probeUrl(
      request,
      request.url,
      folder: folder,
      registration: registration,
      knownFlatLayout: knownFlatLayout,
    );
    if (first.ok ||
        request.source == JoinLinkSource.joinLink ||
        !_worthDiscovering(first.failure)) {
      return first;
    }
    for (final candidate in _discoveryCandidates(request)) {
      if (candidates.contains(candidate)) continue;
      candidates.add(candidate);
      final result = await _probeUrl(
        request,
        candidate,
        folder: folder,
        registration: registration,
        knownFlatLayout: knownFlatLayout,
      );
      if (result.ok) return result;
    }
    return first;
  }

  /// A quick, silent check whether uploads to [url] would fail for a reason
  /// the server states: one OPTIONS request. Returns the failure when the
  /// server answers 401, 403, 404, or 410, or the TLS handshake fails, and
  /// null when the destination looks usable or the result is inconclusive
  /// (no network, timeout, unknown host), because the user may simply be
  /// offline and will be told so when the upload runs.
  Future<ProbeFailure?> reachability(
    String url,
    Map<String, String> auth, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return ProbeFailure.invalidUrl;
    try {
      final response = await _send('OPTIONS', uri, auth).timeout(timeout);
      switch (response.statusCode) {
        case 401:
          return ProbeFailure.unauthorized;
        case 403:
          return ProbeFailure.uploadForbidden;
        case 404:
        case 410:
          return ProbeFailure.notFound;
        default:
          return null;
      }
    } on HandshakeException {
      return ProbeFailure.tlsFailure;
    } on TlsException {
      return ProbeFailure.tlsFailure;
    } catch (_) {
      return null;
    }
  }

  bool _worthDiscovering(ProbeFailure? failure) =>
      failure == ProbeFailure.notWebDav ||
      failure == ProbeFailure.notFound ||
      failure == ProbeFailure.uploadForbidden;

  List<String> _discoveryCandidates(JoinRequest request) {
    if (request.source == JoinLinkSource.nextcloudShare) {
      // The token named by the URL wins; a legacy `public.php/webdav/` URL
      // names none, so the Basic-auth user name must carry it.
      final inUrl = JoinLinkParser.publicShareToken(request.url) ?? '';
      final token = inUrl.isNotEmpty ? inUrl : request.username;
      if (token.isEmpty) return const [];
      return shareEndpointCandidates(request.url, token);
    }
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
    // Legacy Nextcloud/ownCloud per-user endpoint, still served everywhere.
    list.add(origin.replace(path: '${path}remote.php/webdav/').toString());
    list.add(origin.replace(path: '${path}dav/').toString());
    list.add(origin.replace(path: '/.well-known/webdav').toString());
    return list;
  }

  /// Public endpoints a Nextcloud/ownCloud share token can be used at, under
  /// the same install prefix as [url]; the caller skips the one it already
  /// tried. In order:
  ///
  ///  * `public.php/dav/files/<token>/`: Nextcloud 28 and later, and the
  ///    only one of the three Nextcloud 33 accepts uploads at for a File Drop.
  ///  * `public.php/webdav/` with the token as the Basic-auth user name:
  ///    Nextcloud before 28 and ownCloud 10.
  ///  * `remote.php/dav/public-files/<token>/`: ownCloud Infinite Scale.
  static List<String> shareEndpointCandidates(String url, String token) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    var cut = segments.indexOf('public.php');
    if (cut < 0) cut = segments.indexOf('remote.php');
    if (cut < 0) return const [];
    final prefix = segments.sublist(0, cut).join('/');
    final base = prefix.isEmpty ? '/' : '/$prefix/';
    final origin = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: '/',
    );
    final encoded = Uri.encodeComponent(token);
    return [
      origin.replace(path: '${base}public.php/dav/files/$encoded/').toString(),
      origin.replace(path: '${base}public.php/webdav/').toString(),
      origin
          .replace(path: '${base}remote.php/dav/public-files/$encoded/')
          .toString(),
    ];
  }

  Future<ProbeResult> _probeUrl(
    JoinRequest request,
    String url, {
    required String folder,
    required Map<String, Object?> registration,
    bool knownFlatLayout = false,
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

      // 2. MKCOL: may we create folders? 405 usually means it already
      //    exists, but a Nextcloud/ownCloud File Drop from before folder
      //    support answers 405 to every MKCOL ("Only PUT is allowed on files
      //    drop"). A share that can list (step 3) is a read-write share where
      //    405 keeps its usual meaning; a share that cannot is such a drop.
      var flatLayout = knownFlatLayout;
      var mkcolAmbiguous = false;
      final registrationFolder = base.resolve('$joinedFolder/');
      final mkcol = knownFlatLayout
          ? null
          : await _send('MKCOL', registrationFolder, auth);
      switch (mkcol?.statusCode) {
        case null:
          break;
        case 200:
        case 201:
        case 204:
          break;
        case 405:
          mkcolAmbiguous = request.source == JoinLinkSource.nextcloudShare;
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
          if (mkcol!.statusCode >= 500) {
            return ProbeResult.failed(
              ProbeFailure.serverError,
              resolvedUrl: resolved,
              statusCode: mkcol.statusCode,
            );
          }
          flatLayout = true;
      }

      // 3. Over-privilege check. A contributor credential should not be able
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
      final canList = propfind.statusCode == 207 || propfind.statusCode == 200;
      if (canList) warnings.add(ProbeWarning.canReadRemote);
      if (mkcolAmbiguous && !canList) flatLayout = true;

      // 4. PUT the registration record under the device code, so the lead
      //    can match it to the upload folder. A re-test replaces it; an
      //    immutable server answers 412, which counts as written.
      final fileName = '${Uri.encodeComponent(folder)}.json';
      final target = flatLayout
          ? base.resolve('$joinedFolder$flatSeparator$fileName')
          : registrationFolder.resolve(fileName);
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

      // 5. HEAD: informational. Write-only servers may refuse it.
      await _send('HEAD', target, auth);

      if (request.source == JoinLinkSource.nextcloudShare &&
          request.secret.isEmpty &&
          canList) {
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
      case 423: // locked
      case 429: // rate limited
        return ProbeFailure.serverError;
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
