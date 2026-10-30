// =============================================================================
// Upload Destination — one place sessions can be uploaded to
// =============================================================================
//
// A destination ("hook") is a write-only WebDAV endpoint a project lead handed
// the user, typically a Nextcloud File Drop share or the reference drop
// server from tools/webdav_drop_server. Several can be configured side by
// side; the Share dialog lets the user pick which ones a session goes to.
//
// The secret (share password or token) is deliberately not part of this
// model. It lives in the platform keychain under [secretKey] (see
// secret_store.dart), so the destination list can be written to a plain JSON
// file and never leaks a credential into logs or exports.
//
// See https://github.com/birdnet-team/birdnet-live-app/issues/284.
// =============================================================================

/// Transport a destination speaks. Only WebDAV exists; the enum keeps the
/// stored JSON forward compatible.
enum UploadDestinationKind { webdav }

/// A configured upload destination, without its secret.
class UploadDestination {
  UploadDestination({
    required this.id,
    required this.name,
    this.kind = UploadDestinationKind.webdav,
    required this.url,
    required this.username,
    this.wifiOnly = true,
    this.autoUploadAru = false,
    this.autoUploadAll = false,
    this.flatLayout = false,
    this.canReadRemote = false,
    this.shareWithoutPassword = false,
    required DateTime createdAt,
    DateTime? lastUploadAt,
  }) : createdAt = createdAt.toUtc(),
       lastUploadAt = lastUploadAt?.toUtc();

  /// Stable identity of this destination on this device (a UUID).
  final String id;

  /// User-editable label, prefilled from the join link's project name.
  final String name;

  final UploadDestinationKind kind;

  /// Collection URL uploads go to, always ending in a slash.
  final String url;

  /// Basic-auth user name; the share token for a Nextcloud File Drop.
  final String username;

  /// Upload only while on Wi-Fi (or a wired connection).
  final bool wifiOnly;

  /// Enqueue every finalized ARU session for this destination automatically.
  final bool autoUploadAru;

  /// Enqueue every finalized session of any type for this destination
  /// automatically; covers [autoUploadAru].
  final bool autoUploadAll;

  /// The server refused MKCOL during the probe, so uploads encode the folder
  /// path into flat file names instead of creating per-session folders.
  final bool flatLayout;

  /// The probe could list the remote collection with this credential, so it
  /// may be able to read other contributors' data. Kept so Settings can keep
  /// showing the warning the user accepted when joining.
  final bool canReadRemote;

  /// A Nextcloud/ownCloud share that accepted uploads with no password.
  final bool shareWithoutPassword;

  final DateTime createdAt;
  final DateTime? lastUploadAt;

  /// Keychain entry that holds this destination's secret.
  String get secretKey => 'upload_destination_$id';

  /// Host name for compact display, falling back to the raw URL.
  String get host {
    final uri = Uri.tryParse(url);
    final host = uri?.host;
    return host == null || host.isEmpty ? url : host;
  }

  UploadDestination copyWith({
    String? name,
    String? url,
    String? username,
    bool? wifiOnly,
    bool? autoUploadAru,
    bool? autoUploadAll,
    bool? flatLayout,
    bool? canReadRemote,
    bool? shareWithoutPassword,
    DateTime? lastUploadAt,
  }) {
    return UploadDestination(
      id: id,
      name: name ?? this.name,
      kind: kind,
      url: url ?? this.url,
      username: username ?? this.username,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      autoUploadAru: autoUploadAru ?? this.autoUploadAru,
      autoUploadAll: autoUploadAll ?? this.autoUploadAll,
      flatLayout: flatLayout ?? this.flatLayout,
      canReadRemote: canReadRemote ?? this.canReadRemote,
      shareWithoutPassword: shareWithoutPassword ?? this.shareWithoutPassword,
      createdAt: createdAt,
      lastUploadAt: lastUploadAt ?? this.lastUploadAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'url': url,
    'username': username,
    'wifiOnly': wifiOnly,
    'autoUploadAru': autoUploadAru,
    'autoUploadAll': autoUploadAll,
    if (flatLayout) 'flatLayout': true,
    if (canReadRemote) 'canReadRemote': true,
    if (shareWithoutPassword) 'shareWithoutPassword': true,
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (lastUploadAt != null)
      'lastUploadAt': lastUploadAt!.toUtc().toIso8601String(),
  };

  factory UploadDestination.fromJson(Map<String, dynamic> json) {
    return UploadDestination(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      kind: UploadDestinationKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => UploadDestinationKind.webdav,
      ),
      url: json['url'] as String,
      username: json['username'] as String? ?? '',
      wifiOnly: json['wifiOnly'] as bool? ?? true,
      autoUploadAru: json['autoUploadAru'] as bool? ?? false,
      autoUploadAll: json['autoUploadAll'] as bool? ?? false,
      flatLayout: json['flatLayout'] as bool? ?? false,
      canReadRemote: json['canReadRemote'] as bool? ?? false,
      shareWithoutPassword: json['shareWithoutPassword'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      lastUploadAt: json['lastUploadAt'] != null
          ? DateTime.tryParse(json['lastUploadAt'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UploadDestination &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.url == url &&
      other.username == username &&
      other.wifiOnly == wifiOnly &&
      other.autoUploadAru == autoUploadAru &&
      other.autoUploadAll == autoUploadAll &&
      other.flatLayout == flatLayout &&
      other.canReadRemote == canReadRemote &&
      other.shareWithoutPassword == shareWithoutPassword &&
      other.createdAt == createdAt &&
      other.lastUploadAt == lastUploadAt;

  @override
  int get hashCode => Object.hash(id, name, url, username, lastUploadAt);

  @override
  String toString() => 'UploadDestination($name, $host)';
}
