// =============================================================================
// Join Link — turn whatever the user pasted into a destination to probe
// =============================================================================
//
// Contributors never configure WebDAV by hand. The parser accepts three
// inputs and resolves each into a [JoinRequest]:
//
//  1. A BirdNET join link: a URL whose fragment (preferred, because a fragment
//     is never sent to the web host) or query carries the parameters `kind`,
//     `url`, `user`, `secret`, `name`, `audio`, and `wifi`. The custom
//     `birdnetlive://join` scheme is accepted as well. A join link whose URL
//     is a Nextcloud/ownCloud public share endpoint is treated like case 2,
//     so the same endpoint fallbacks and the no-password warning apply.
//  2. A Nextcloud or ownCloud share link, which is converted to the share's
//     public WebDAV endpoint with the share token as the user name. The
//     probe also tries the older public endpoints (see
//     WebDavProbe.shareEndpointCandidates) when the server lacks this one.
//  3. A plain WebDAV collection URL, optionally with a user name and secret
//     typed into the advanced fields.
//
// Parsing is pure; the network probe (webdav_probe.dart) verifies the result.
// =============================================================================

/// How the request was obtained; drives probe warnings and autodiscovery.
enum JoinLinkSource { joinLink, nextcloudShare, webdavUrl }

/// What the probe and the join sheet work from.
class JoinRequest {
  const JoinRequest({
    required this.url,
    this.username = '',
    this.secret = '',
    this.name,
    this.includeAudio,
    this.wifiOnly,
    required this.source,
  });

  /// Collection URL, normalized to end in a slash.
  final String url;
  final String username;
  final String secret;

  /// Suggested destination name from the join link, if any.
  final String? name;

  /// Project defaults carried by the join link; null when unspecified.
  final bool? includeAudio;
  final bool? wifiOnly;

  final JoinLinkSource source;

  JoinRequest copyWith({String? url, String? username, String? secret}) {
    return JoinRequest(
      url: url ?? this.url,
      username: username ?? this.username,
      secret: secret ?? this.secret,
      name: name,
      includeAudio: includeAudio,
      wifiOnly: wifiOnly,
      source: source,
    );
  }

  @override
  String toString() => 'JoinRequest($source, $url, user=$username)';
}

/// Parses pasted or scanned text into a [JoinRequest].
abstract final class JoinLinkParser {
  static const String customScheme = 'birdnetlive';
  static const String customHost = 'join';

  /// Landing page that carries join links on the docs site. The app link
  /// filters on Android and iOS claim this path; a browser that opens it
  /// instead offers the custom-scheme form.
  static const String landingPage =
      'https://birdnet-team.github.io/birdnet-live-app/join';

  /// Builds the link another device scans or pastes to join [url] with the
  /// same credential. The secret travels in the fragment, which browsers
  /// never send to the landing page's host.
  static String build({
    required String url,
    required String username,
    required String secret,
    String? name,
    bool? includeAudio,
    bool? wifiOnly,
  }) {
    final params = <String, String>{
      'v': '1',
      'kind': 'webdav',
      if (name != null && name.isNotEmpty) 'name': name,
      'url': url,
      if (username.isNotEmpty) 'user': username,
      if (secret.isNotEmpty) 'secret': secret,
      if (includeAudio != null) 'audio': includeAudio ? '1' : '0',
      if (wifiOnly != null) 'wifi': wifiOnly ? '1' : '0',
    };
    final query = params.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}='
              '${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    return '$landingPage#$query';
  }

  /// Returns null when [input] is not a usable URL. [username] and [secret]
  /// come from the advanced fields and only apply to inputs that carry no
  /// credential of their own.
  static JoinRequest? parse(
    String input, {
    String username = '',
    String secret = '',
  }) {
    final text = input.trim();
    if (text.isEmpty) return null;

    final uri = Uri.tryParse(_withScheme(text));
    if (uri == null || uri.host.isEmpty) return null;

    // A join link is recognized by its parameters; an unsupported kind must
    // not fall through and be probed as a plain URL.
    final joinParams = _joinParams(uri);
    if (joinParams != null) return _parseJoinLink(joinParams);

    final share = _parseShareLink(uri, secret: secret);
    if (share != null) return share;

    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    // `https://user:pass@host/dav/` works as a probe target because dart:io
    // sends the credentials, but the URL would then be stored and shown in
    // plain text. Move them into the credential fields instead.
    var user = username.trim();
    var pass = secret;
    if (uri.userInfo.isNotEmpty) {
      final colon = uri.userInfo.indexOf(':');
      final embeddedUser = Uri.decodeComponent(
        colon < 0 ? uri.userInfo : uri.userInfo.substring(0, colon),
      );
      final embeddedPass = colon < 0
          ? ''
          : Uri.decodeComponent(uri.userInfo.substring(colon + 1));
      if (user.isEmpty) user = embeddedUser;
      if (pass.isEmpty) pass = embeddedPass;
    }
    return JoinRequest(
      url: normalizeCollectionUrl(uri.toString()),
      username: user,
      secret: pass,
      source: JoinLinkSource.webdavUrl,
    );
  }

  /// Ensures a scheme (https) and a trailing slash, dropping query/fragment.
  static String normalizeCollectionUrl(String url) {
    final uri = Uri.parse(_withScheme(url.trim()));
    final path = uri.path.isEmpty
        ? '/'
        : uri.path.endsWith('/')
        ? uri.path
        : '${uri.path}/';
    return _collection(uri, path).toString();
  }

  /// [base] with [path] and without query or fragment. `Uri.replace` keeps
  /// both when handed null, so the URI is rebuilt instead.
  static Uri _collection(Uri base, String path) => Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: path,
  );

  static final RegExp _schemePrefix = RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*:');

  static String _withScheme(String text) {
    if (_schemePrefix.hasMatch(text)) return text;
    return 'https://$text';
  }

  /// The join-link parameters of [uri], or null when it carries none.
  static Map<String, String>? _joinParams(Uri uri) {
    final isCustom = uri.scheme == customScheme && uri.host == customHost;
    if (!isCustom && uri.scheme != 'https' && uri.scheme != 'http') {
      return null;
    }
    if (uri.fragment.isNotEmpty) {
      final params = Uri.splitQueryString(uri.fragment);
      if (params.containsKey('url')) return params;
    }
    if (uri.queryParameters.containsKey('url')) return uri.queryParameters;
    return isCustom ? const {} : null;
  }

  static JoinRequest? _parseJoinLink(Map<String, String> params) {
    final target = params['url'];
    if (target == null || target.isEmpty) return null;
    final kind = params['kind'] ?? 'webdav';
    if (kind != 'webdav') return null;
    final targetUri = Uri.tryParse(target);
    if (targetUri == null ||
        targetUri.host.isEmpty ||
        (targetUri.scheme != 'https' && targetUri.scheme != 'http')) {
      return null;
    }
    final name = params['name']?.trim();
    final url = normalizeCollectionUrl(target);
    final shareToken = publicShareToken(url);
    var username = params['user']?.trim() ?? '';
    if (username.isEmpty && shareToken != null) username = shareToken;
    return JoinRequest(
      url: url,
      username: username,
      secret: params['secret'] ?? '',
      name: name == null || name.isEmpty ? null : name,
      includeAudio: _flag(params['audio']),
      wifiOnly: _flag(params['wifi']),
      source: shareToken != null
          ? JoinLinkSource.nextcloudShare
          : JoinLinkSource.joinLink,
    );
  }

  /// The share token named by a Nextcloud/ownCloud public endpoint URL
  /// (`public.php/dav/files/<token>/`, `remote.php/dav/public-files/<token>/`),
  /// the empty string for the legacy `public.php/webdav/` form, which carries
  /// the token as the Basic-auth user name instead, or null for any other
  /// URL.
  static String? publicShareToken(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final s = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    for (var i = 0; i < s.length; i++) {
      if (s[i] == 'public.php' && i + 1 < s.length) {
        if (s[i + 1] == 'webdav' && i + 2 == s.length) return '';
        if (s[i + 1] == 'dav' &&
            i + 3 < s.length &&
            s[i + 2] == 'files' &&
            i + 4 == s.length &&
            _shareToken.hasMatch(s[i + 3])) {
          return s[i + 3];
        }
      }
      if (s[i] == 'remote.php' &&
          i + 3 < s.length &&
          s[i + 1] == 'dav' &&
          s[i + 2] == 'public-files' &&
          i + 4 == s.length &&
          _shareToken.hasMatch(s[i + 3])) {
        return s[i + 3];
      }
    }
    return null;
  }

  /// Nextcloud and ownCloud share tokens: letters and digits, 8 or more.
  static final RegExp _shareToken = RegExp(r'^[A-Za-z0-9]{8,}$');

  /// `https://host[/prefix]/s/<token>` or `.../index.php/s/<token>`, with
  /// nothing after the token. A WebDAV folder that happens to be called `s`
  /// (`https://dav.example.org/s/birds/`) is left alone.
  ///
  /// The result points at `public.php/dav/files/<token>/`, the public
  /// endpoint Nextcloud 28+ serves. Its predecessor `public.php/webdav/` is
  /// still answered by current Nextcloud but refuses every PUT into a File
  /// Drop since Nextcloud 33 ("Files cannot be created in non-existent
  /// collections"), so it is only a probe fallback for older servers.
  static JoinRequest? _parseShareLink(Uri uri, {required String secret}) {
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final shareIndex = segments.lastIndexOf('s');
    if (shareIndex < 0 || shareIndex + 2 != segments.length) return null;
    final token = segments[shareIndex + 1];
    if (!_shareToken.hasMatch(token)) return null;
    var prefix = segments.sublist(0, shareIndex);
    if (prefix.isNotEmpty && prefix.last == 'index.php') {
      prefix = prefix.sublist(0, prefix.length - 1);
    }
    final path =
        '/${[...prefix, 'public.php', 'dav', 'files', token].join('/')}/';
    return JoinRequest(
      url: _collection(uri, path).toString(),
      username: token,
      secret: secret,
      source: JoinLinkSource.nextcloudShare,
    );
  }

  static bool? _flag(String? value) {
    switch (value) {
      case '1':
      case 'true':
      case 'yes':
        return true;
      case '0':
      case 'false':
      case 'no':
        return false;
      default:
        return null;
    }
  }
}
