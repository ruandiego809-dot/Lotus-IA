import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotus_ai/features/projects/data/safe_zip_import.dart';
import 'package:path/path.dart' as p;

List<int> zipFiles(Map<String, String> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    final bytes = entry.value.codeUnits;
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return ZipEncoder().encode(archive);
}

void main() {
  late Directory temp;
  late Directory target;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('lotus-zip-test-');
    target = await Directory(p.join(temp.path, 'project')).create();
  });
  tearDown(() async => temp.delete(recursive: true));

  test('imports nested files', () async {
    await importProjectZip(target, zipFiles({'src/main.txt': 'hello'}));
    expect(
      await File(p.join(target.path, 'src', 'main.txt')).readAsString(),
      'hello',
    );
  });

  test('imports explicit directory entries with nested files', () async {
    final archive = Archive()
      ..addFile(ArchiveFile.directory('src/'))
      ..addFile(ArchiveFile.string('src/main.txt', 'hello'));
    await importProjectZip(target, ZipEncoder().encode(archive));
    expect(
      await File(p.join(target.path, 'src', 'main.txt')).readAsString(),
      'hello',
    );
  });

  test('rejects corrupt content before writing any entries', () async {
    final archive = Archive()
      ..addFile(ArchiveFile.noCompress('safe.txt', 4, 'safe'.codeUnits))
      ..addFile(ArchiveFile.noCompress('bad.txt', 8, 'corrupt!'.codeUnits));
    final bytes = ZipEncoder().encode(archive);
    final needle = 'corrupt!'.codeUnits;
    final index = List.generate(bytes.length - needle.length + 1, (i) => i)
        .firstWhere(
          (i) => List.generate(
            needle.length,
            (j) => j,
          ).every((j) => bytes[i + j] == needle[j]),
        );
    bytes[index] ^= 1;
    await expectLater(importProjectZip(target, bytes), throwsFormatException);
    expect(await File(p.join(target.path, 'safe.txt')).exists(), isFalse);
    expect(await File(p.join(target.path, 'bad.txt')).exists(), isFalse);
  });

  test('rejects a file that is not a ZIP', () async {
    await expectLater(
      importProjectZip(target, 'not a zip'.codeUnits),
      throwsA(isA<Exception>()),
    );
    expect(await target.list().isEmpty, isTrue);
  });

  test('rejects a symlink as the destination root', () async {
    if (Platform.isWindows) return;
    final link = Link(p.join(temp.path, 'target-link'));
    await link.create(target.path);
    await expectLater(
      importProjectZip(Directory(link.path), zipFiles({'new.txt': 'data'})),
      throwsA(isA<FileSystemException>()),
    );
    expect(await File(p.join(target.path, 'new.txt')).exists(), isFalse);
  });

  test('rejects traversal before writing any entries', () async {
    final bytes = zipFiles({'safe.txt': 'ok', '../outside.txt': 'bad'});
    await expectLater(importProjectZip(target, bytes), throwsFormatException);
    expect(await File(p.join(target.path, 'safe.txt')).exists(), isFalse);
    expect(await File(p.join(temp.path, 'outside.txt')).exists(), isFalse);
  });

  test('rejects absolute and Windows-style traversal', () async {
    for (final name in [
      '/absolute.txt',
      r'..\outside.txt',
      r'C:\outside.txt',
    ]) {
      await expectLater(
        importProjectZip(target, zipFiles({name: 'bad'})),
        throwsFormatException,
      );
    }
  });

  test('does not overwrite a project file', () async {
    final existing = File(p.join(target.path, 'existing.txt'));
    await existing.writeAsString('original');
    await expectLater(
      importProjectZip(
        target,
        zipFiles({'new.txt': 'new', 'existing.txt': 'changed'}),
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await existing.readAsString(), 'original');
    expect(await File(p.join(target.path, 'new.txt')).exists(), isFalse);
  });

  test('rejects existing symlink parents', () async {
    if (Platform.isWindows) return;
    await Link(p.join(target.path, 'linked')).create(temp.path);
    await expectLater(
      importProjectZip(target, zipFiles({'linked/outside.txt': 'bad'})),
      throwsA(isA<FileSystemException>()),
    );
    expect(await File(p.join(temp.path, 'outside.txt')).exists(), isFalse);
  });
}
