import 'dart:ui' show Rect;

import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

/// Builds the share payload for [filePath].
///
/// [sharePositionOrigin] anchors the iPad popover; omitting it makes the
/// iOS plugin refuse to present the sheet. Callers should pass the rect of
/// the widget the user tapped — see `shareOriginFrom` in
/// `shared/utils/share_origin.dart`.
ShareParams shareParamsForFile(
  String filePath, {
  String? text,
  String? subject,
  Rect? sharePositionOrigin,
}) {
  final name = _basenameForAnyPath(filePath);
  return ShareParams(
    files: [XFile(filePath, mimeType: mimeTypeForSharedPath(filePath))],
    fileNameOverrides: [name],
    text: text,
    subject: subject,
    title: name,
    sharePositionOrigin: sharePositionOrigin,
  );
}

String mimeTypeForSharedPath(String path) {
  switch (p.extension(path).toLowerCase()) {
    case '.wav':
      return 'audio/wav';
    case '.flac':
      return 'audio/flac';
    case '.m4a':
      return 'audio/mp4';
    case '.aac':
      return 'audio/aac';
    case '.mp3':
      return 'audio/mpeg';
    case '.ogg':
    case '.oga':
      return 'audio/ogg';
    case '.zip':
      return 'application/zip';
    case '.json':
      return 'application/json';
    case '.csv':
      return 'text/csv';
    case '.gpx':
      return 'application/gpx+xml';
    case '.html':
    case '.htm':
      return 'text/html';
    case '.txt':
      return 'text/plain';
    default:
      return 'application/octet-stream';
  }
}

String _basenameForAnyPath(String filePath) {
  final normalized = filePath.replaceAll('\\', '/');
  return normalized.substring(normalized.lastIndexOf('/') + 1);
}
