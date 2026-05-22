/// Reads the version from pubspec.yaml and updates all files that contain
/// a hardcoded version string (e.g. the README and docs badges).
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
  final display = full.split('+').first; // e.g. "0.1.27"

  var updated = 0;

  // README.md — shields.io badge
  final readme = File('README.md');
  if (readme.existsSync()) {
    final original = readme.readAsStringSync();
    final badgePattern = RegExp(r'badge/version-[^-]+-orange');
    if (!badgePattern.hasMatch(original)) {
      stderr.writeln('README.md version badge not found.');
      exit(1);
    }
    final replaced = original.replaceAllMapped(
      badgePattern,
      (_) => 'badge/version-$display-orange',
    );
    if (replaced != original) {
      readme.writeAsStringSync(replaced);
      updated++;
      stdout.writeln('  README.md badge → $display');
    }
  } else {
    stderr.writeln('README.md not found.');
    exit(1);
  }

  // MkDocs home pages — shields.io latest release badge.
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
  for (final file in docsHomeFiles) {
    final original = file.readAsStringSync();
    if (!docsBadgePattern.hasMatch(original)) {
      continue;
    }
    final replaced = original.replaceAllMapped(
      docsBadgePattern,
      (_) => 'badge/latest-v$display-orange',
    );
    if (replaced != original) {
      file.writeAsStringSync(replaced);
      updated++;
      stdout.writeln('  ${file.path} latest badge → v$display');
    }
  }

  if (updated == 0) {
    stdout.writeln('All files already up to date ($display).');
  } else {
    stdout.writeln('Synced $updated file(s) to version $display.');
  }
}
