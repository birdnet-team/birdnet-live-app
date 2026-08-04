// =============================================================================
// dev/build_release.dart
// =============================================================================
//
// One-shot release build helper. Run from the project root with:
//
//     dart dev/build_release.dart --since <last-play-version>
//
// `--since` is the version currently live on Google Play. We do not ship every
// tagged version to the Play Store — releases go out roughly weekly — so a
// release usually covers several CHANGELOG entries, and only the person cutting
// it knows where the last upload landed. There is no reliable way to infer it
// from the repo, so it must be passed explicitly.
//
// Examples:
//
//     dart dev/build_release.dart --since 1.0.1     # build + stage + notes
//     dart dev/build_release.dart --since 1.0.1 --notes-only
//
// What it does:
//   1. Reads the current version from `pubspec.yaml` (the single source
//      of truth).
//   2. Runs signed AAB and APK release builds using the configured Android
//      keystore; the AAB is obfuscated and writes split debug symbols.
//   3. Verifies both artifacts exist (the javac obsolete-options warning
//      makes the exit code unreliable on Windows).
//   4. Copies the AAB, APK, 512 px AppGallery icon, ProGuard mapping file,
//      and obfuscation symbols folder into `release/V<version>/`.
//   5. Writes two notes files into `release/V<version>/`:
//        • `release_notes.txt`        — the deliverable, one short block per
//          locale, for pasting into Play Console.
//        • `release_notes.source.txt` — reference only. Every CHANGELOG bullet
//          between `--since` and the current version, grouped by version, so
//          the one-line summary can be written from the full picture.
//      Translation per locale is still a manual step.
//
// The script is intentionally read-only outside `release/` and
// `build/`. It never edits source, never bumps the version, and never
// pushes anywhere.
//
// Requires the Flutter SDK on PATH.
// =============================================================================

import 'dart:io';

/// Play Console locales the app ships notes for. `en-US` is written separately
/// as the source text every other locale is translated from; any locale missing
/// on Play Console falls back to it.
const List<String> kReleaseLocales = [
  'de-DE',
  'cs-CZ',
  'es-ES',
  'fr-FR',
  'it-IT',
  'nl-NL',
  'nb-NO',
  'pl-PL',
  'pt-PT',
  'ru-RU',
  'zh-CN',
];

/// Play Console's per-locale limit is 500 characters; leave a little headroom
/// so a translation that runs longer than the English still fits.
const int kNotesCharBudget = 480;

Future<void> main(List<String> args) async {
  if (args.contains('-h') || args.contains('--help')) {
    stdout.writeln(_usage);
    return;
  }

  final root = Directory.current;
  stdout.writeln('BirdNET Live release build — root: ${root.path}');

  final version = _readVersion(root);
  stdout.writeln('Version from pubspec: $version');

  final since = _readSince(args);
  final notesOnly = args.contains('--notes-only');

  final changes = _collectChanges(root, since: since, current: version);
  if (changes.isEmpty) {
    stderr.writeln(
      'WARNING: no CHANGELOG entries found after $since (up to $version). '
      'Check that --since names the version actually live on Play.',
    );
  } else {
    stdout.writeln(
      'Covering ${changes.length} release(s) since $since: '
      '${changes.map((c) => c.version).join(', ')}',
    );
  }

  final outDir = Directory('${root.path}/release/V$version');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  if (!notesOnly) {
    await _runFlutterBuild([
      'build',
      'appbundle',
      '--release',
      '--obfuscate',
      '--split-debug-info=build/symbols/V$version',
    ]);

    final aabSrc = File(
      '${root.path}/build/app/outputs/bundle/release/app-release.aab',
    );
    if (!aabSrc.existsSync()) {
      stderr.writeln('ERROR: AAB not found at ${aabSrc.path}');
      stderr.writeln(
        'The build probably failed. Re-run `flutter build appbundle '
        '--release --obfuscate --split-debug-info=build/symbols/V$version` '
        'manually and check the output.',
      );
      exit(2);
    }

    final aabDst = File('${outDir.path}/BirdNET_Live_V$version.aab');
    aabSrc.copySync(aabDst.path);
    stdout.writeln('Copied AAB → ${aabDst.path}');

    await _runFlutterBuild(['build', 'apk', '--release']);

    final apkSrc = File(
      '${root.path}/build/app/outputs/flutter-apk/app-release.apk',
    );
    if (!apkSrc.existsSync()) {
      stderr.writeln('ERROR: APK not found at ${apkSrc.path}');
      exit(2);
    }
    final apkDst = File('${outDir.path}/BirdNET_Live_V$version.apk');
    apkSrc.copySync(apkDst.path);
    stdout.writeln('Copied APK → ${apkDst.path}');

    final iconDst = File('${outDir.path}/BirdNET_Live_V${version}_icon_512.png');
    await _createAppGalleryIcon(root, iconDst);
    stdout.writeln('Created 512 px AppGallery icon → ${iconDst.path}');

    final mappingSrc = File(
      '${root.path}/build/app/outputs/mapping/release/mapping.txt',
    );
    if (mappingSrc.existsSync()) {
      final mappingDst = File('${outDir.path}/mapping.txt');
      mappingSrc.copySync(mappingDst.path);
      stdout.writeln('Copied mapping → ${mappingDst.path}');
    } else {
      stderr.writeln('WARNING: mapping.txt not found — skipping');
    }

    final symbolsSrc = Directory('${root.path}/build/symbols/V$version');
    if (symbolsSrc.existsSync()) {
      final symbolsDst = Directory('${outDir.path}/symbols');
      if (symbolsDst.existsSync()) symbolsDst.deleteSync(recursive: true);
      _copyDirectory(symbolsSrc, symbolsDst);
      stdout.writeln('Copied symbols → ${symbolsDst.path}');
    } else {
      stderr.writeln(
        'WARNING: ${symbolsSrc.path} not found — skipping symbols',
      );
    }
  }

  // Reference material is always rewritten — it is derived from the CHANGELOG
  // and never hand-edited, so there is nothing to lose.
  final source = File('${outDir.path}/release_notes.source.txt');
  source.writeAsStringSync(_sourceNotes(since, version, changes));
  stdout.writeln('Wrote changelog digest → ${source.path}');

  // The deliverable is only stubbed when absent, so a hand-written or
  // translated file is never clobbered by a rebuild.
  final notes = File('${outDir.path}/release_notes.txt');
  if (!notes.existsSync()) {
    notes.writeAsStringSync(_stubReleaseNotes(since, version));
    stdout.writeln('Stubbed release notes → ${notes.path}');
    stdout.writeln(
      '  → write the one-line en-US summary using ${source.path},\n'
      '    then translate it into the other ${kReleaseLocales.length} locales.',
    );
  } else {
    stdout.writeln(
      'Release notes already exist at ${notes.path} — left untouched.',
    );
  }

  stdout.writeln('\nDone. Artifacts in ${outDir.path}');
  stdout.writeln('Next: see docs/developer/releasing.md for the upload steps.');
}

const String _usage = '''
Usage: dart dev/build_release.dart --since <version> [--notes-only]

  --since <version>   The version currently live on Google Play, e.g. 1.0.1.
                      Required: we release to Play roughly weekly, so a single
                      upload usually spans several CHANGELOG entries and only
                      you know which one is live.
  --notes-only        Regenerate the notes files without rebuilding the bundle.
  -h, --help          Show this message.

Requires the Flutter SDK on PATH.
''';

/// One CHANGELOG version block.
class _VersionChanges {
  _VersionChanges(this.version, this.date, this.bullets);
  final String version;
  final String? date;
  final List<String> bullets;
}

String _readSince(List<String> args) {
  String? value;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--since' && i + 1 < args.length) {
      value = args[i + 1];
      break;
    }
    if (args[i].startsWith('--since=')) {
      value = args[i].substring('--since='.length);
      break;
    }
  }
  if (value == null) {
    stderr.writeln(
      'ERROR: --since is required.\n\n'
      'Pass the version currently live on Google Play so the notes cover '
      'everything shipped since then, e.g.\n\n'
      '    dart dev/build_release.dart --since 1.0.1\n',
    );
    exit(64); // EX_USAGE
  }
  if (!RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+$').hasMatch(value)) {
    stderr.writeln('ERROR: --since must look like 1.0.1, got "$value"');
    exit(64);
  }
  return value;
}

String _readVersion(Directory root) {
  final lines = File('${root.path}/pubspec.yaml').readAsLinesSync();
  for (final line in lines) {
    final m = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$',
    ).firstMatch(line);
    if (m != null) return m.group(1)!;
  }
  stderr.writeln('ERROR: could not find `version:` in pubspec.yaml');
  exit(1);
}

/// Semver-ish compare. Returns <0, 0, >0.
int _compareVersions(String a, String b) {
  final pa = a.split('.').map(int.parse).toList();
  final pb = b.split('.').map(int.parse).toList();
  for (var i = 0; i < 3; i++) {
    final d = pa[i] - pb[i];
    if (d != 0) return d;
  }
  return 0;
}

/// Every CHANGELOG block with `since < version <= current`, newest first.
///
/// `## [Unreleased]` is skipped: Keep a Changelog keeps that heading around
/// permanently and it is normally empty at release time.
List<_VersionChanges> _collectChanges(
  Directory root, {
  required String since,
  required String current,
}) {
  final changelog = File('${root.path}/CHANGELOG.md');
  if (!changelog.existsSync()) return const [];

  final out = <_VersionChanges>[];
  _VersionChanges? open;

  for (final line in changelog.readAsLinesSync()) {
    if (line.startsWith('## ')) {
      open = null;
      final m = RegExp(
        r'^##\s*\[?([0-9]+\.[0-9]+\.[0-9]+)\]?(?:\s*-\s*(\S+))?',
      ).firstMatch(line);
      if (m == null) continue; // [Unreleased] or anything unversioned.
      final v = m.group(1)!;
      if (_compareVersions(v, since) <= 0) continue;
      if (_compareVersions(v, current) > 0) continue;
      open = _VersionChanges(v, m.group(2), []);
      out.add(open);
      continue;
    }
    if (open != null && line.trimLeft().startsWith('- ')) {
      open.bullets.add(line.trim().substring(1).trim());
    }
  }
  return out;
}

/// Reference digest. Never uploaded — it exists so whoever writes the one-line
/// summary can see everything the upload actually covers.
String _sourceNotes(
  String since,
  String current,
  List<_VersionChanges> changes,
) {
  final b =
      StringBuffer()
        ..writeln('REFERENCE ONLY — do not paste this into Play Console.')
        ..writeln()
        ..writeln('Everything shipping in this upload: after $since, '
            'through $current.')
        ..writeln();

  if (changes.isEmpty) {
    b.writeln('(No CHANGELOG entries found in that range.)');
    return b.toString();
  }

  for (final c in changes) {
    b.writeln('## ${c.version}${c.date == null ? '' : ' — ${c.date}'}');
    for (final bullet in c.bullets) {
      b.writeln('  - $bullet');
    }
    b.writeln();
  }
  return b.toString();
}

/// The deliverable. One high-level line per locale — not a bullet dump.
///
/// Play Console shows these to users browsing the store listing, so the useful
/// content is "what is different for me", not a per-version changelog. The
/// en-US block is left as a TODO on purpose: condensing several releases into
/// one honest sentence is a judgement call, and auto-generated filler is worse
/// than nothing (the previous version of this script silently shipped
/// "Stability and polish improvements." on every release).
String _stubReleaseNotes(String since, String current) {
  final headline =
      'TODO: one line describing what changed for users between '
      '$since and $current (max $kNotesCharBudget chars). '
      'See release_notes.source.txt.';

  final stub =
      StringBuffer()
        ..writeln('<en-US>')
        ..writeln(headline)
        ..writeln('</en-US>')
        ..writeln();
  for (final loc in kReleaseLocales) {
    stub
      ..writeln('<$loc>')
      ..writeln('TODO: translate the en-US block above for $loc.')
      ..writeln('</$loc>')
      ..writeln();
  }
  return stub.toString();
}

Future<void> _runFlutterBuild(List<String> args) async {
  stdout.writeln('Running: flutter ${args.join(' ')}');
  // Inherit stdio so the user sees progress live. Don't trust exit code
  // — javac's obsolete-options warnings make it unreliable on Windows.
  Process process;
  try {
    process = await Process.start(
      Platform.isWindows ? 'flutter.bat' : 'flutter',
      args,
      runInShell: true,
      mode: ProcessStartMode.inheritStdio,
    );
  } on ProcessException catch (e) {
    stderr.writeln(
      'ERROR: could not start Flutter (${e.message}).\n'
      'The Flutter SDK must be on PATH — `flutter --version` should work in '
      'the same shell you run this script from.',
    );
    exit(127);
  }
  final code = await process.exitCode;
  if (code != 0) {
    stdout.writeln(
      '`flutter ${args.join(' ')}` exited with code $code — checking '
      'whether the expected artifact landed anyway (javac warnings can '
      'poison the exit code on Windows even when the build succeeded).',
    );
  }
}

Future<void> _createAppGalleryIcon(Directory root, File destination) async {
  final background = File('${root.path}/assets/images/app-icon-background.png');
  final foreground = File('${root.path}/assets/images/app-icon-foreground.png');
  if (!background.existsSync() || !foreground.existsSync()) {
    stderr.writeln('ERROR: AppGallery icon source layers are missing.');
    exit(2);
  }

  if (!Platform.isWindows) {
    stderr.writeln('ERROR: AppGallery icon generation currently requires Windows.');
    exit(2);
  }

  final result = await Process.run('powershell.exe', [
    '-NoProfile',
    '-Command',
    r'Add-Type -AssemblyName System.Drawing; '
        r'$background = [System.Drawing.Image]::FromFile($args[0]); '
        r'$foreground = [System.Drawing.Image]::FromFile($args[1]); '
        r'$icon = New-Object System.Drawing.Bitmap 512, 512; '
        r'$graphics = [System.Drawing.Graphics]::FromImage($icon); '
        r'$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic; '
        r'$graphics.DrawImage($background, 0, 0, 512, 512); '
        r'$graphics.DrawImage($foreground, 0, 0, 512, 512); '
        r'$icon.Save($args[2], [System.Drawing.Imaging.ImageFormat]::Png); '
        r'$graphics.Dispose(); $icon.Dispose(); $foreground.Dispose(); $background.Dispose()',
    background.path,
    foreground.path,
    destination.path,
  ]);
  if (result.exitCode != 0 || !destination.existsSync()) {
    stderr.writeln('ERROR: could not create 512 px AppGallery icon.');
    if (result.stderr.toString().isNotEmpty) stderr.writeln(result.stderr);
    exit(2);
  }
}

void _copyDirectory(Directory src, Directory dst) {
  if (!dst.existsSync()) dst.createSync(recursive: true);
  for (final entity in src.listSync(recursive: false)) {
    final name = entity.path.split(Platform.pathSeparator).last;
    if (entity is File) {
      entity.copySync('${dst.path}/$name');
    } else if (entity is Directory) {
      _copyDirectory(entity, Directory('${dst.path}/$name'));
    }
  }
}
