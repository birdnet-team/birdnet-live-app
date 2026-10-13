import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:birdnet_live/features/history/services/export_zip_writer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// Observe where the encoder reads its entries without relying on timing or
// adding a test hook to the production writer.
class _ObservedArchive extends Archive {
  _ObservedArchive(this.onRead);

  final SendPort onRead;

  @override
  Iterator<ArchiveFile> get iterator {
    onRead.send(Isolate.current.controlPort);
    return super.iterator;
  }
}

void main() {
  late Directory tempDir;
  late String outputPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('export_zip_writer_test_');
    outputPath = p.join(tempDir.path, 'export.zip');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('compresses file and document entries in a separate isolate', () async {
    final onRead = ReceivePort();
    addTearDown(onRead.close);
    final workerPort = onRead.first;
    final contents = _ObservedArchive(onRead.sendPort);
    final document = utf8.encode('Scientific Name,Score\nTurdus merula,0.95\n');
    contents.addFile(ArchiveFile('session.csv', document.length, document));
    final recording = Uint8List(2 * 1024 * 1024);
    for (var i = 0; i < recording.length; i++) {
      recording[i] = i % 251;
    }
    final source = File(p.join(tempDir.path, 'recording.wav'));
    await source.writeAsBytes(recording);

    await writeExportZip(
      outputPath: outputPath,
      files: {'audio/session.wav': source.path},
      contents: contents,
    );

    expect(await workerPort, isNot(Isolate.current.controlPort));
    final archive = ZipDecoder().decodeBytes(
      await File(outputPath).readAsBytes(),
      verify: true,
    );
    expect(archive.map((entry) => entry.name), [
      'audio/session.wav',
      'session.csv',
    ]);
    expect(archive.first.content, recording);
    expect(archive.last.content, document);
    expect(await source.readAsBytes(), recording);
  });

  test('propagates file errors and removes the incomplete ZIP', () async {
    await expectLater(
      writeExportZip(
        outputPath: outputPath,
        files: {'missing.wav': p.join(tempDir.path, 'missing.wav')},
        contents: Archive(),
      ),
      throwsA(isA<FileSystemException>()),
    );

    expect(File(outputPath).existsSync(), isFalse);
    // Also checks that a failed worker releases its output file handle.
    await File(outputPath).writeAsString('retry');
    expect(await File(outputPath).readAsString(), 'retry');
  });
}
