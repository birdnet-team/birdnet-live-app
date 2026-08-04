// =============================================================================
// Share Sheet — iPad anchor rect + failure reporting
// =============================================================================
//
// Two pieces of plumbing every `SharePlus.instance.share` call in the app
// needs:
//
//   • [shareOriginFrom] — on iPad the share sheet is a popover that anchors
//     to a source rectangle. `share_plus` forwards
//     `ShareParams.sharePositionOrigin` to the iOS
//     `UIPopoverPresentationController.sourceRect`; when it is missing or
//     empty the plugin rejects the call outright (13.1.x) or falls back to
//     the screen centre (13.3+). Callers pass the rect of the widget the
//     user actually tapped.
//
//   • [reportShareFailure] — share entry points are fire-and-forget
//     callbacks, so a `PlatformException` from the native sheet used to
//     become an unhandled async error that release builds drop on the
//     floor. That is what made the iPad rejection look like a dead button.
// =============================================================================

import 'package:flutter/material.dart';

import 'package:birdnet_live/l10n/app_localizations.dart';

/// A share action that needs the anchor rect of the control that
/// triggered it. Widgets that own the control compute the rect with
/// [shareOriginFrom] and hand it to the host, which forwards it as
/// `ShareParams.sharePositionOrigin`.
typedef ShareFromOriginCallback = void Function(Rect origin);

/// Global rect of [context]'s render box, in logical pixels.
///
/// Falls back to a 1x1 rect at the centre of the view when the context has
/// no laid-out render object. The result is never empty and always inside
/// the source view's coordinate space — the iOS plugin rejects both.
Rect shareOriginFrom(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is RenderBox &&
      renderObject.attached &&
      renderObject.hasSize) {
    final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    if (!rect.isEmpty) return rect;
  }
  final size = MediaQuery.sizeOf(context);
  return Rect.fromCenter(
    center: Offset(size.width / 2, size.height / 2),
    width: 1,
    height: 1,
  );
}

/// Awaits [share] and surfaces a snack bar when the platform rejects it,
/// so a share that cannot be presented never again looks like a no-op.
Future<void> reportShareFailure(
  BuildContext context,
  Future<Object?> share,
) async {
  try {
    await share;
  } catch (error, stackTrace) {
    debugPrint('Share sheet failed: $error\n$stackTrace');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.shareSheetFailed)),
    );
  }
}
