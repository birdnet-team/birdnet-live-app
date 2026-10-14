// =============================================================================
// Link Launcher — Safe external URL launching with user-visible fallback
// =============================================================================
//
// Wraps `url_launcher` so call sites don't have to repeat the same boilerplate
// (try/catch + SnackBar + clipboard copy). The previous pattern of
// `if (await canLaunchUrl(uri)) launchUrl(uri)` silently no-ops on Android 11+
// when the manifest's `<queries>` block doesn't list `ACTION_VIEW` for the
// scheme — the symptom seen in issue #34 on a Pixel 9 Pro. Two changes
// together fix it:
//
//   1. `AndroidManifest.xml` declares `<intent>` queries for http/https/mailto
//      so Android grants visibility to browsers and mail apps.
//   2. We drop the `canLaunchUrl` probe entirely and just call `launchUrl`
//      inside try/catch. If it throws (e.g. no browser installed at all), we
//      copy the URL to the clipboard and show a SnackBar telling the user.
//
// ### Usage
//
// ```dart
// await openExternalUrl(context, 'https://example.org/');
// ```
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';

/// Opens [url] in an external app (browser, mail client, …).
///
/// On failure the URL is copied to the clipboard and a SnackBar is shown via
/// the nearest [ScaffoldMessenger]. Pass [context] so we can surface that
/// fallback; if the widget is unmounted by the time the launch fails the
/// SnackBar is silently skipped.
///
/// [inApp] opens the page in Chrome Custom Tabs (Android) / an
/// SFSafariViewController sheet (iOS) instead of a separate browser app.
/// Both share cookies/login state with the system browser, but stay in the
/// caller's own task stack — so the back button or close control returns
/// directly to this app. Defaults to false to preserve existing behavior at
/// other call sites.
Future<void> openExternalUrl(
  BuildContext context,
  String url, {
  bool inApp = false,
}) async {
  final uri = Uri.parse(url);
  try {
    final ok = await launchUrl(
      uri,
      mode: inApp ? LaunchMode.inAppBrowserView : LaunchMode.externalApplication,
    );
    if (ok) return;
    // launchUrl returned false — fall through to the failure path.
    throw PlatformException(
      code: 'launch_failed',
      message: 'launchUrl returned false',
    );
  } catch (_) {
    // Clipboard access doesn't need a BuildContext; do that first so we still
    // hand the user a working URL even if the widget tree was torn down
    // between the failed launch and this fallback.
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.linkOpenFailedCopied),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
