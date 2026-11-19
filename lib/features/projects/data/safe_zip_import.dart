import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Imports without escaping [target] or overwriting existing files.
/// The complete archive is checked before any files are created.
Future<void> importProjectZip(Directory target, List<int> bytes) async {
  // Some archive versions coalesce duplicate names and ignore verify: true.
  final rawNames = <String>{};
  final decoder = ZipDecoder();
  final archive = decoder.decodeBytes(
    bytes,
    verify: true,
    callback: (file) {
      if (!rawNames.add(file.name)) {
        throw const FormatException('ZIP contém caminhos duplicados.');
      }
    },
  );
  if (decoder.directory.filePosition < 0 ||
      decoder.directory.fileHeaders.length !=
          decoder.directory.totalCentralDirectoryEntries) {
    throw const FormatException('ZIP inválido ou incompleto.');
  }
  final root = p.normalize(p.absolute(target.path));
  if (await FileSystemEntity.type(root, followLinks: false) !=
      FileSystemEntityType.directory) {
    throw const FileSystemException('Destino do ZIP não é uma pasta real.');
  }
  final entries = <({ArchiveFile file, String path, bool isFile})>[];
  final seen = <String, bool>{};

  for (final file in archive) {
    final name = file.name.replaceAll('\\', '/');
    final parts = name.split('/');
    if (name.isEmpty ||
        name.startsWith('/') ||
        RegExp(r'^[A-Za-z]:').hasMatch(name) ||
        parts.contains('..')) {
      throw const FormatException('ZIP contém caminho inválido.');
    }
    final out = p.normalize(p.join(root, name));
    if (!p.isWithin(root, out)) {
      throw const FormatException('ZIP contém caminho fora do projeto.');
    }
    // Unix ZIP modes can encode symbolic links or special files.
    final type = file.mode & 0xF000;
    if (type != 0 && type != 0x8000 && type != 0x4000) {
      throw const FormatException('ZIP contém link ou arquivo especial.');
    }
    // archive 4.0.7 can classify Unix directories with permission-only
    // modes as files even when their names end in a slash.
    final isFile = file.isFile && !name.endsWith('/');
    if (seen.containsKey(out)) {
      throw const FormatException('ZIP contém caminhos duplicados.');
    }
    if (isFile) {
      final content = file.content;
      if (content.length != file.size ||
          (file.crc32 != null && getCrc32(content) != file.crc32)) {
        throw const FormatException('ZIP contém arquivo corrompido.');
      }
    }
    seen[out] = isFile;
    entries.add((file: file, path: out, isFile: isFile));
  }

  for (final entry in entries) {
    var path = entry.path;
    while (path != root) {
      final existing = await FileSystemEntity.type(path, followLinks: false);
      if (existing == FileSystemEntityType.link ||
          (path == entry.path &&
              entry.isFile &&
              existing != FileSystemEntityType.notFound) ||
          (path != entry.path &&
              existing != FileSystemEntityType.notFound &&
              existing != FileSystemEntityType.directory) ||
          (path == entry.path &&
              !entry.isFile &&
              existing != FileSystemEntityType.notFound &&
              existing != FileSystemEntityType.directory) ||
          (path != entry.path && seen[path] == true)) {
        throw const FileSystemException(
          'ZIP conflita com arquivo existente ou link.',
        );
      }
      path = p.dirname(path);
    }
  }

  for (final entry in entries) {
    if (entry.isFile) {
      final out = File(entry.path);
      await out.parent.create(recursive: true);
      await out.create(exclusive: true);
      await out.writeAsBytes(entry.file.content);
    } else {
      await Directory(entry.path).create(recursive: true);
    }
  }
}
