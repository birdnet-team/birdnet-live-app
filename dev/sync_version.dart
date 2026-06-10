/// Reads the version from pubspec.yaml and updates files that mirror it:
/// README/docs badges, docs badge alt text, release-guide examples, and local
/// Android Flutter version fields.
///
/// Usage:  dart dev/sync_version.dart
///
/// The single source of truth is `pubspec.yaml`'s `version:` field.
library;

import 'dart:io';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final match = RegExp(r'version:\s*(\S+)').firstMatch(pubspec);
  if (match == null) {
    stderr.writeln('Could not find version in pubspec.yaml');
    exit(1);
  }

  // Version string like "0.1.27+27" — strip the build number for display.
  final full = match.group(1)!;
  final versionParts = full.split('+');
  final display = versionParts.first; // e.g. "0.1.27"
  final buildNumber = versionParts.length > 1 ? versionParts[1] : null;

  var updated = 0;

  // README.md — shields.io badge
  updated += _replaceRequired(
    File('README.md'),
    RegExp(r'badge/version-[^-]+-orange'),
    'badge/version-$display-orange',
    label: 'README.md badge',
    success: 'README.md badge → $display',
  );

  // MkDocs home pages — shields.io latest release badge and matching alt text.
  final docsHomeFiles =
      Directory('docs')
          .listSync()
          .whereType<File>()
          .where(
            (file) => RegExp(r'index(\.[a-z]{2})?\.md$').hasMatch(file.path),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final docsBadgePattern = RegExp(r'badge/latest-v[^-]+-orange');
  final docsBadgeAltPattern = RegExp(r'Latest release: v\d+\.\d+\.\d+');
  for (final file in docsHomeFiles) {
    final original = file.readAsStringSync();
    if (!docsBadgePattern.hasMatch(original)) {
      continue;
    }
    final replaced = original
        .replaceAllMapped(
          docsBadgePattern,
          (_) => 'badge/latest-v$display-orange',
        )
        .replaceAllMapped(
          docsBadgeAltPattern,
          (_) => 'Latest release: v$display',
        );
    if (replaced != original) {
      file.writeAsStringSync(replaced);
      updated++;
      stdout.writeln('  ${file.path} latest badge → v$display');
    }
  }

  // Developer release docs — version example snippets.
  final releaseGuideFiles =
      Directory('docs/developer')
          .listSync()
          .whereType<File>()
          .where(
            (file) =>
                RegExp(r'releasing(\.[a-z]{2})?\.md$').hasMatch(file.path),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final releaseVersionPattern = RegExp(r'version:\s*\d+\.\d+\.\d+\+\d+');
  for (final file in releaseGuideFiles) {
    final changed = _replaceOptional(
      file,
      (original) => original.replaceAllMapped(
        releaseVersionPattern,
        (_) => 'version: $full',
      ),
    );
    if (changed) {
      updated++;
      stdout.writeln('  ${file.path} release example → $full');
    }
  }

  // android/local.properties is local/generated, so update it when present but
  // do not require it on machines that have not configured Android yet.
  final androidLocalProperties = File('android/local.properties');
  if (androidLocalProperties.existsSync()) {
    final changed = _replaceOptional(androidLocalProperties, (original) {
      var replaced = original.replaceAllMapped(
        RegExp(r'^flutter\.versionName=.*$', multiLine: true),
        (_) => 'flutter.versionName=$display',
      );
      if (buildNumber != null) {
        replaced = replaced.replaceAllMapped(
          RegExp(r'^flutter\.versionCode=.*$', multiLine: true),
          (_) => 'flutter.versionCode=$buildNumber',
        );
      }
      return replaced;
    });
    if (changed) {
      updated++;
      stdout.writeln('  android/local.properties Flutter version → $full');
    }
  }

  if (updated == 0) {
    stdout.writeln('All files already up to date ($display).');
  } else {
    stdout.writeln('Synced $updated file(s) to version $display.');
  }
}

int _replaceRequired(
  File file,
  RegExp pattern,
  String replacement, {
  required String label,
  required String success,
}) {
  if (!file.existsSync()) {
    stderr.writeln('${file.path} not found.');
    exit(1);
  }

  final original = file.readAsStringSync();
  if (!pattern.hasMatch(original)) {
    stderr.writeln('$label not found.');
    exit(1);
  }

  final replaced = original.replaceAllMapped(pattern, (_) => replacement);
  if (replaced == original) return 0;

  file.writeAsStringSync(replaced);
  stdout.writeln('  $success');
  return 1;
}

bool _replaceOptional(File file, String Function(String original) replace) {
  if (!file.existsSync()) return false;
  final original = file.readAsStringSync();
  final replaced = replace(original);
  if (replaced == original) return false;
  file.writeAsStringSync(replaced);
  return true;
}
