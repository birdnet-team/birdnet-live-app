// =============================================================================
// OpenStreetMap Tile Layer — Shared safe network tile configuration
// =============================================================================
//
// Centralizes the app's OpenStreetMap tile configuration so every map uses the
// same provider, disk cache and tile error behavior.
//
// Caching is handled by flutter_map's own [BuiltInMapCachingProvider] (added in
// flutter_map 8.0 and enabled by default on [NetworkTileProvider]). It stores
// tiles on disk, revalidates them with `If-None-Match` / `If-Modified-Since`,
// bounds the cache by *bytes* rather than object count, and — crucially —
// pairs with [NetworkTileProvider.abortObsoleteRequests] so tiles that scroll
// out of view mid-flight are cancelled instead of downloaded for nothing. That
// keeps us gentle on the public OSM tile service, which asks for exactly that.
//
// Freshness: OSM serves tiles with a short `Cache-Control: max-age` (hours to
// days). Honoring it literally means a tile older than that forces a network
// round trip before it can be drawn — so a cached-but-stale tile renders blank
// when the signal drops mid-survey, which is the one moment offline tiles
// matter. [kOsmTileFreshAge] overrides the header so a tile on disk is drawn
// immediately, without touching the network, for as long as it is plausibly
// still accurate. OSM raster content changes slowly, and Settings → "clear
// app data" wipes the cache for anyone who wants a hard refresh.
//
// Tile error behavior: failed downloads degrade to blank tiles instead of
// surfacing Flutter error screens to the user.
// =============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';

const String kOpenStreetMapUrlTemplate =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

const String kOpenStreetMapUserAgent = AppConstants.networkUserAgent;

/// How long a cached tile is treated as fresh, overriding the server's
/// `Cache-Control` header. See the freshness note in the file header.
const Duration kOsmTileFreshAge = Duration(days: 180);

/// Byte ceiling for the on-disk tile cache. Enforced by flutter_map's size
/// reducer, which runs in the background when the cache is created. ~200 MB is
/// roughly 6–7k tiles at the ~30 KB average, similar in size to the bundled
/// species image set.
const int kOsmTileCacheMaxBytes = 200 * 1024 * 1024;

Map<String, String> _openStreetMapTileHeaders() => {
  'User-Agent': kOpenStreetMapUserAgent,
};

// ---------------------------------------------------------------------------
// Shared, long-lived HTTP client
// ---------------------------------------------------------------------------
//
// [buildOpenStreetMapTileLayer] is called from `build()` on every map screen,
// so a new [NetworkTileProvider] is created on every rebuild. Providers are
// cheap, but the HTTP client they create is not — and `TileLayer` only
// disposes the provider it is holding at unmount, so per-build clients would
// pile up unclosed. We therefore own the client here and pass it in:
// [NetworkTileProvider] only closes clients it created itself, so its
// `dispose()` becomes a safe no-op and the connection pool is shared across
// every map in the app.
//
// [RetryClient] mirrors NetworkTileProvider's own default, so a single blip
// doesn't blank a tile until the user pans away and back.
// ---------------------------------------------------------------------------

http.Client? _sharedHttpClient;

http.Client _osmHttpClient() =>
    _sharedHttpClient ??= RetryClient(http.Client());

// ---------------------------------------------------------------------------
// Caching provider
// ---------------------------------------------------------------------------
//
// `getOrCreateInstance` only honors its configuration when no instance exists
// yet, and [NetworkTileImageProvider] silently creates a default one on the
// first uncached tile. We therefore always route through this accessor so our
// configuration is the one that wins.
// ---------------------------------------------------------------------------

BuiltInMapCachingProvider? _cachingProvider;

/// The app's configured on-disk OSM tile cache.
BuiltInMapCachingProvider osmTileCachingProvider() =>
    _cachingProvider ??= BuiltInMapCachingProvider.getOrCreateInstance(
      maxCacheSize: kOsmTileCacheMaxBytes,
      overrideFreshAge: kOsmTileFreshAge,
    );

TileLayer buildOpenStreetMapTileLayer() {
  return TileLayer(
    urlTemplate: kOpenStreetMapUrlTemplate,
    userAgentPackageName: AppConstants.packageName,
    tileProvider: NetworkTileProvider(
      headers: _openStreetMapTileHeaders(),
      httpClient: _osmHttpClient(),
      cachingProvider: osmTileCachingProvider(),
      silenceExceptions: true,
    ),
    evictErrorTileStrategy: EvictErrorTileStrategy.notVisible,
  );
}

// ---------------------------------------------------------------------------
// Public prefetch helpers
// ---------------------------------------------------------------------------
//
// `prefetchOsmTile(url)` is retained for a future tile source that explicitly
// allows offline prefetching. The public OpenStreetMap tile service does not
// allow bulk, offline, or pre-seeded downloads, so this helper must not be
// exposed in user-visible flows while [kOpenStreetMapUrlTemplate] points at
// `tile.openstreetmap.org`.
//
// Returns the size of the cached tile in bytes (best-effort; 0 on failure).
// Network errors are swallowed because the caller is typically iterating
// thousands of tiles and a few bad ones shouldn't abort the whole batch.
// ---------------------------------------------------------------------------

Future<int> prefetchOsmTile(String url) async {
  final cache = osmTileCachingProvider();
  if (!cache.isSupported) return 0;

  // Already on disk and still fresh — don't spend a request on it.
  try {
    final cached = await cache.getTile(url);
    if (cached != null && !cached.metadata.isStale) return cached.bytes.length;
  } catch (_) {
    // Missing or corrupt; fall through and fetch a fresh copy.
  }

  try {
    final response = await _osmHttpClient().get(
      Uri.parse(url),
      headers: _openStreetMapTileHeaders(),
    );
    if (response.statusCode != HttpStatus.ok) return 0;
    final bytes = response.bodyBytes;
    if (bytes.isEmpty) return 0;
    await cache.putTile(
      url: url,
      metadata: CachedMapTileMetadata.fromHttpHeaders(response.headers),
      bytes: bytes,
    );
    return bytes.length;
  } catch (_) {
    return 0;
  }
}

/// Clears all cached OpenStreetMap tiles from the app's dedicated tile cache.
///
/// Destroying the provider also resets flutter_map's internal singleton, so the
/// next map build recreates it (with our configuration) via
/// [osmTileCachingProvider].
Future<void> clearOpenStreetMapTileCache() async {
  final cache = _cachingProvider;
  _cachingProvider = null;
  if (cache == null) return;
  await cache.destroy(deleteCache: true);
}

// ---------------------------------------------------------------------------
// Legacy cache cleanup
// ---------------------------------------------------------------------------
//
// Up to 0.19.3 tiles were cached via `flutter_cache_manager` under
// `<temp>/osm_tile_cache`. That store is no longer read or written; without an
// explicit purge it would sit on the user's device indefinitely, holding up to
// a few hundred MB. Best-effort and safe to call repeatedly.
// ---------------------------------------------------------------------------

Future<void> purgeLegacyOsmTileCache() async {
  const legacyCacheKey = 'osm_tile_cache';
  try {
    final tempDir = await getTemporaryDirectory();
    final dir = Directory(p.join(tempDir.path, legacyCacheKey));
    if (await dir.exists()) await dir.delete(recursive: true);
  } catch (_) {
    // Nothing to do — the OS reclaims the cache directory eventually.
  }
  try {
    final supportDir = await getApplicationSupportDirectory();
    final index = File(p.join(supportDir.path, '$legacyCacheKey.json'));
    if (await index.exists()) await index.delete();
  } catch (_) {
    // Index file is a few KB; not worth reporting.
  }
}
