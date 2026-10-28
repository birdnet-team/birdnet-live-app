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
//     `birdnetlive://join` scheme is accepted as well.
//  2. A Nextcloud or ownCloud share link, which is converted to the share's
//     public WebDAV endpoint with the share token as the user name.
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
    return JoinRequest(
      url: normalizeCollectionUrl(uri.toString()),
      username: username.trim(),
      secret: secret,
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
    userInfo: base.userInfo.isEmpty ? null : base.userInfo,
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
    return JoinRequest(
      url: normalizeCollectionUrl(target),
      username: params['user']?.trim() ?? '',
      secret: params['secret'] ?? '',
      name: name == null || name.isEmpty ? null : name,
      includeAudio: _flag(params['audio']),
      wifiOnly: _flag(params['wifi']),
      source: JoinLinkSource.joinLink,
    );
  }

  /// `https://host[/prefix]/s/<token>` or `.../index.php/s/<token>`.
  static JoinRequest? _parseShareLink(Uri uri, {required String secret}) {
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final shareIndex = segments.indexOf('s');
    if (shareIndex < 0 || shareIndex + 1 >= segments.length) return null;
    final token = segments[shareIndex + 1];
    if (token.isEmpty) return null;
    var prefix = segments.sublist(0, shareIndex);
    if (prefix.isNotEmpty && prefix.last == 'index.php') {
      prefix = prefix.sublist(0, prefix.length - 1);
    }
    final path = '/${[...prefix, 'public.php', 'webdav'].join('/')}/';
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
